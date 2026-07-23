import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../models.dart';
import '../../state/app_state.dart';

/// Bitta chek (parallel cheklar uchun).
class CheckDoc {
  final int number;
  final List<OrderLine> lines = [];
  Client? client;
  String? comment; // chekka izoh (prototip: check.comment)
  DateTime openedAt = DateTime.now(); // restore'da Firestore'dan tiklanadi
  // ── Zal xizmati ──
  String orderType = 'В заведении'; // В заведении | Навынос
  int? hallId;   // qaysi zal
  int? tableId;  // qaysi stol (null → stolsiz / навынос)
  int guests = 0; // mehmonlar soni
  /// Stol ochilgan vaqt. Android'da ijara hisobi yo'q, lekin maydon sxema
  /// simmetriyasi uchun SHART (BACKEND.md Qoida 2): Windows'da ochilgan chekni
  /// android tahrirlasa `seatedAt` yo'qolib, ijara taymeri nolga tushardi.
  DateTime? seatedAt;
  // ── Firestore sinxron (cafes/{id}/openChecks) ──
  String? docId; // hujjat kaliti (auto-ID); null = hali saqlanmagan
  int rev = 0;   // shu yozuvchining versiya hisoblagichi (o'z echo'mizni tanish uchun)
  /// Serverdan kelgan xom clientId. Bootstrap race himoyasi: openChecks
  /// snapshot'i `clients`dan OLDIN kelsa `client` obyektga bog'lanmaydi;
  /// bu maydonsiz keyingi flush `clientId: null` yozib mijozni (va
  /// chegirmasini) chekdan doimiy uzib qo'yardi.
  int? restoredClientId;
  CheckDoc(this.number);

  bool get isDineIn => orderType == 'В заведении';

  int get subtotal => lines.fold(0, (s, l) => s + l.total);
  int get costTotal => lines.fold(0, (s, l) => s + (l.product.cost * l.qty).round());

  /// Faqat `noDiscount == false` pozitsiyalar chegirmaga kiradi (prototip: checkCalc).
  int get discountableSubtotal =>
      lines.where((l) => !l.product.noDiscount).fold(0, (s, l) => s + l.total);

  int discountPctFor(AppState app) {
    final c = client;
    if (c == null) return 0;
    final g = app.clientGroups.where((g) => g.name == c.group).toList();
    return g.isEmpty ? 0 : g.first.percent;
  }

  int discountAmountFor(AppState app) =>
      (discountableSubtotal * discountPctFor(app) / 100).round();

  /// Servis foizi — faqat zalda (стол tanlangan) va sozlamada > 0 bo'lsa.
  int serviceFeePctFor(AppState app) =>
      (isDineIn && tableId != null && app.serviceFeePct > 0) ? app.serviceFeePct : 0;

  int serviceAmountFor(AppState app) =>
      ((subtotal - discountAmountFor(app)) * serviceFeePctFor(app) / 100).round();

  int dueFor(AppState app) =>
      subtotal - discountAmountFor(app) + serviceAmountFor(app);
  int get profitBase => costTotal;
}

// ─────────────────── Ochiq chek ↔ Firestore Map (sxema: BACKEND.md Qoida 2) ───────────────────
// DIQQAT: bu sxema `xposterwin` dagi nusxa bilan AYNAN bir xil bo'lishi shart.

/// CheckDoc → Map. Meta maydonlar (`rev`, `device`, `updatedAt`) bu yerga
/// KIRMAYDI — ular saqlash paytida qo'shiladi; shu tufayli jsonEncode natijasi
/// «lokal tahrir bormi?» (dirty) taqqoslashi uchun barqaror.
Map<String, dynamic> openCheckToMap(CheckDoc c) => {
      'number': c.number,
      'orderType': c.orderType,
      'hallId': c.hallId,
      'tableId': c.tableId,
      'guests': c.guests,
      'openedAtIso': c.openedAt.toIso8601String(),
      'seatedAtIso': c.seatedAt?.toIso8601String(),
      // `restoredClientId` fallback: clients hali yuklanmagan bo'lsa ham
      // serverdagi bog'lanish yo'qolmaydi.
      'clientId': c.client?.id ?? c.restoredClientId,
      'comment': c.comment,
      'lines': [
        for (final l in c.lines)
          {
            'productId': l.product.id,
            // Snapshot maydonlar: mahsulot keyin o'chirilsa ham chek o'qiladi.
            'name': l.product.name,
            'price': l.product.price,
            'cost': l.product.cost,
            'qty': l.qty,
            'modification': l.modification,
            'comment': l.comment,
          }
      ],
    };

/// Map ma'lumotini mavjud CheckDoc ustiga qo'llash (lines to'liq almashadi).
void applyOpenCheckMap(CheckDoc c, Map<String, dynamic> m, AppState app) {
  c.orderType = m['orderType'] as String? ?? 'В заведении';
  c.hallId = (m['hallId'] as num?)?.toInt();
  c.tableId = (m['tableId'] as num?)?.toInt();
  c.guests = (m['guests'] as num?)?.toInt() ?? 0;
  c.openedAt = DateTime.tryParse(m['openedAtIso'] as String? ?? '') ?? c.openedAt;
  final seated = m['seatedAtIso'] as String?;
  c.seatedAt = seated == null ? null : DateTime.tryParse(seated);
  c.comment = m['comment'] as String?;
  final clientId = (m['clientId'] as num?)?.toInt();
  c.restoredClientId = clientId; // xom qiymat saqlanadi (clients kech kelsa ham)
  if (clientId == null) {
    c.client = null;
  } else {
    final cl = app.clients.where((x) => x.id == clientId).toList();
    c.client = cl.isEmpty ? null : cl.first;
  }
  c.lines.clear();
  final lines = m['lines'];
  if (lines is List) {
    for (final raw in lines) {
      if (raw is! Map) continue;
      final lm = Map<String, dynamic>.from(raw);
      final pid = (lm['productId'] as num?)?.toInt() ?? -1;
      final match = app.products.where((p) => p.id == pid).toList();
      final product = match.isNotEmpty
          ? match.first
          : Product(
              id: pid,
              name: lm['name'] as String? ?? '—',
              categoryId: 0,
              type: 'product',
              workshop: null,
              price: (lm['price'] as num?)?.toInt() ?? 0,
              cost: (lm['cost'] as num?)?.toInt() ?? 0,
              photo: '🧾',
            );
      c.lines.add(OrderLine(
        product,
        qty: (lm['qty'] as num?)?.toDouble() ?? 1,
        comment: lm['comment'] as String?,
        modification: lm['modification'] as String?,
      ));
    }
  }
}

/// Map → yangi CheckDoc (boshqa qurilmada/oldingi seansda ochilgan chek).
CheckDoc openCheckFromMap(Map<String, dynamic> m, AppState app, String docId) {
  final c = CheckDoc((m['number'] as num?)?.toInt() ?? 1);
  c.docId = docId;
  c.rev = (m['rev'] as num?)?.toInt() ?? 0;
  applyOpenCheckMap(c, m, app);
  return c;
}

/// Kassa holati: PIN, foydalanuvchi, parallel cheklar.
class KassaController extends ChangeNotifier {
  final AppState app;
  Employee? user; // joriy kassir — app.session'dan olinadi
  KassaController(this.app) {
    user = app.session;
    _syncNextOrder(); // chek raqami arxivdan davom etadi (1 dan qayta boshlanmaydi!)
    // Ochiq cheklar Firestore'dan tiklanadi (restart/qulash/boshqa qurilma).
    app.addListener(_onAppChanged);
    _lastSeenRemoteRev = app.openChecksRev;
    _mergeRemote(notify: false);
  }

  final List<CheckDoc> checks = [CheckDoc(1)];
  int activeIndex = 0;
  int _nextNumber = 2;
  int nextOrder = 1; // arxiv cheklari №1 dan boshlanadi

  // ─────────────── Ochiq cheklar sinxroni (cafes/{id}/openChecks) ───────────────
  //
  // Yozish: har mutatsiya notifyListeners() dan o'tadi → 400 ms debounce →
  // o'zgargan cheklar to'liq set() bilan yoziladi (rev+device meta bilan).
  // O'qish: repository listener'i app.openCheckDocs ni yangilaydi →
  // _onAppChanged → _mergeRemote lokal ro'yxat bilan birlashtiradi.
  // Konflikt: lokal saqlanmagan tahrir bo'lsa remote qo'llanmaydi (keyingi
  // flush baribir yozadi — last-write-wins, POS uchun yetarli).

  final Map<String, String> _lastSavedJson = {}; // docId → oxirgi yozilgan/qo'llangan holat
  final Set<String> _locallyDeleted = {};        // biz o'chirganlar (kech kelgan snapshot qaytarmasin)
  Timer? _saveTimer;
  int _lastSeenRemoteRev = -1;
  bool _disposed = false;

  @override
  void notifyListeners() {
    super.notifyListeners();
    _scheduleSave();
  }

  @override
  void dispose() {
    _disposed = true;
    _saveTimer?.cancel();
    app.removeListener(_onAppChanged);
    super.dispose();
  }

  void _onAppChanged() {
    if (_disposed) return;
    if (app.openChecksRev != _lastSeenRemoteRev) {
      _lastSeenRemoteRev = app.openChecksRev;
      _mergeRemote();
    }
    // Bootstrap race: openChecks snapshot'i `clients`dan oldin kelgan bo'lsa,
    // mijozlar yuklangach chekka qayta bog'laymiz (clientId yo'qolmagan).
    var resolved = false;
    for (final c in checks) {
      if (c.client == null && c.restoredClientId != null) {
        final cl = app.clients.where((x) => x.id == c.restoredClientId).toList();
        if (cl.isNotEmpty) {
          c.client = cl.first;
          resolved = true;
        }
      }
    }
    if (resolved) notifyListeners();
  }

  bool _persistWorthy(CheckDoc c) =>
      c.lines.isNotEmpty ||
      c.tableId != null ||
      c.client != null ||
      (c.comment?.isNotEmpty ?? false);

  void _scheduleSave() {
    if (_disposed || !app.repo.ready) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), _flushSaves);
  }

  /// O'zgargan cheklarni Firestore'ga yozish (oflaynda SDK navbatiga tushadi).
  void _flushSaves() {
    if (_disposed || !app.repo.ready) return;
    for (final c in List<CheckDoc>.from(checks)) {
      if (!_persistWorthy(c)) {
        // Avval saqlangan, endi bo'shagan chek — serverdan ham o'chadi.
        if (c.docId != null && _lastSavedJson.containsKey(c.docId)) _deleteRemote(c);
        continue;
      }
      c.docId ??= app.repo.newOpenCheckId();
      final id = c.docId;
      if (id == null) continue;
      final json = jsonEncode(openCheckToMap(c));
      if (_lastSavedJson[id] == json) continue; // o'zgarmagan
      c.rev += 1;
      _lastSavedJson[id] = json;
      _locallyDeleted.remove(id);
      app.repo
          .saveOpenCheckRaw(id, {...openCheckToMap(c), 'rev': c.rev, 'device': app.deviceId})
          .catchError((e) => debugPrint('openCheck save failed: $e'));
    }
  }

  /// To'langan/yopilgan chekni serverdan o'chirish.
  void _deleteRemote(CheckDoc c) {
    final id = c.docId;
    if (id == null) return;
    _lastSavedJson.remove(id);
    _locallyDeleted.add(id);
    // Chek hali ro'yxatda qolayotgan bo'lsa (bo'shatilgan aktiv chek holati),
    // docId'ni uzamiz — aks holda keyingi snapshot (hujjat yo'q) uni
    // _mergeRemote 1-bosqichida ro'yxatdan olib tashlab, kassirning aktiv
    // chekini yangi raqamli chek bilan almashtirib yuborardi.
    c.docId = null;
    c.rev = 0;
    if (app.repo.ready) {
      app.repo.deleteOpenCheck(id).catchError((e) => debugPrint('openCheck delete failed: $e'));
    }
  }

  /// Firestore snapshot'ini lokal `checks` bilan birlashtirish.
  void _mergeRemote({bool notify = true}) {
    if (!app.openChecksLoaded) return;
    final remote = <String, Map<String, dynamic>>{
      for (final m in app.openCheckDocs) m['_docId'] as String: m,
    };
    var changed = false;
    final activeDoc = checks.isEmpty ? null : checks[activeIndex.clamp(0, checks.length - 1)];

    // 1) Serverdan yo'qolganlar (boshqa qurilmada to'langan/yopilgan).
    //    Firestore lokal keshi o'z yozuvimizni snapshot'da darhol ko'rsatadi,
    //    shuning uchun «yozdim-u hali serverga bormadi» holati bu yerga tushmaydi.
    for (var i = checks.length - 1; i >= 0; i--) {
      final c = checks[i];
      final id = c.docId;
      if (id == null || remote.containsKey(id)) continue;
      checks.removeAt(i);
      _lastSavedJson.remove(id);
      _locallyDeleted.remove(id);
      changed = true;
    }

    // 2) Serverdagi hujjatlar: yangisini qo'shish / o'zgarganini qo'llash.
    for (final e in remote.entries) {
      if (_locallyDeleted.contains(e.key)) continue; // o'chirish echo'sini kutyapmiz
      final m = e.value;
      final idx = checks.indexWhere((c) => c.docId == e.key);
      if (idx < 0) {
        final c = openCheckFromMap(m, app, e.key);
        _lastSavedJson[e.key] = jsonEncode(openCheckToMap(c));
        checks.add(c);
        if (c.number >= _nextNumber) _nextNumber = c.number + 1;
        changed = true;
      } else {
        final c = checks[idx];
        final fromSelf = m['device'] == app.deviceId;
        final remoteRev = (m['rev'] as num?)?.toInt() ?? 0;
        if (fromSelf && remoteRev >= c.rev) continue; // o'z yozuvimiz echo'si
        if (fromSelf) continue; // eski echo — lokal yangiroq
        // Boshqa qurilma tahriri: lokalda saqlanmagan o'zgarish bo'lsa tegmaymiz.
        final localJson = jsonEncode(openCheckToMap(c));
        if (_lastSavedJson[e.key] != localJson) continue; // dirty — lokal ustun
        applyOpenCheckMap(c, m, app);
        c.rev = remoteRev;
        _lastSavedJson[e.key] = jsonEncode(openCheckToMap(c));
        changed = true;
      }
    }

    if (!changed) return;

    // 3) Bootstrap bo'sh cheki: remote'dan cheklar kelgach, foydalanuvchi
    //    ishlatmayotgan docId'siz bo'sh chekni olib tashlaymiz (aktivga tegmaymiz).
    if (checks.length > 1) {
      checks.removeWhere((c) =>
          c.docId == null && !_persistWorthy(c) && !identical(c, activeDoc));
    }
    if (checks.isEmpty) checks.add(CheckDoc(_nextNumber++));

    // 4) Aktiv chekni identity bo'yicha tiklash.
    final ai = activeDoc == null ? -1 : checks.indexWhere((c) => identical(c, activeDoc));
    activeIndex = (ai >= 0 ? ai : 0).clamp(0, checks.length - 1);

    if (notify) notifyListeners();
  }

  /// Arxivdagi eng katta chek raqamidan davom etish (restart/boshqa qurilma).
  void _syncNextOrder() {
    var maxId = 0;
    for (final r in app.receiptsArchive) {
      if (r.id > maxId) maxId = r.id;
    }
    if (nextOrder <= maxId) nextOrder = maxId + 1;
  }

  CheckDoc get active => checks[activeIndex];

  /// Tashqaridan holatni yangilash uchun.
  void refresh() => notifyListeners();

  // ── Chek hisob-kitobi (prototip checkCalc) ──
  int get subtotal => active.subtotal;
  int get discountPct => active.discountPctFor(app);
  int get discountAmount => active.discountAmountFor(app);
  int get due => active.dueFor(app);

  // ── PIN ──
  String? tryLogin(String pin) {
    // `e.active` SHART: ishdan bo'shatilgan xodim ham kassaga kirib ketardi
    // (loginByPin da tekshiruv bor edi, bu yerda yo'q edi).
    // matchesPin: pinHash+salt bo'lsa hash, aks holda legacy ochiq matn.
    final emp = app.employees.where((e) => e.matchesPin(pin) && e.active).toList();
    if (emp.isEmpty) return null;
    user = emp.first;
    app.currentUser = emp.first;
    app.notify();
    notifyListeners();
    return emp.first.name;
  }

  void lock() {
    user = null;
    notifyListeners();
  }

  // ── Chek amallari ──
  void addProduct(Product p, {String? modification}) {
    final existing = active.lines.where((l) => l.product.id == p.id && l.modification == modification).toList();
    if (existing.isNotEmpty) {
      existing.first.qty += 1;
    } else {
      active.lines.add(OrderLine(p, modification: modification));
    }
    notifyListeners();
  }

  void changeQty(OrderLine line, double delta) {
    line.qty += delta;
    if (line.qty <= 0) active.lines.remove(line);
    notifyListeners();
  }

  void setQty(OrderLine line, double q) {
    line.qty = q;
    if (line.qty <= 0) active.lines.remove(line);
    notifyListeners();
  }

  void removeLine(OrderLine line) {
    active.lines.remove(line);
    notifyListeners();
  }

  void setLineComment(OrderLine line, String c) {
    line.comment = c.isEmpty ? null : c;
    notifyListeners();
  }

  void clearActive() {
    active.lines.clear();
    active.client = null;
    active.restoredClientId = null; // aks holda flush eski mijozni qaytarib yozardi
    active.comment = null;
    notifyListeners();
  }

  void attachClient(Client c) {
    active.client = c;
    active.restoredClientId = c.id;
    notifyListeners();
  }

  void detachClient() {
    active.client = null;
    active.restoredClientId = null; // aks holda flush eski mijozni qaytarib yozardi
    notifyListeners();
  }

  void newCheck() {
    checks.add(CheckDoc(_nextNumber++));
    activeIndex = checks.length - 1;
    notifyListeners();
  }

  int get nextCheckNumber => _nextNumber;

  // ── Zal / stol ──
  /// Stol tanlash: shu stolda ochiq chek bo'lsa — unga o'tamiz, aks holda biriktiramiz.
  void openTable({required int hallId, required int tableId, required int guests}) {
    final idx = checks.indexWhere((c) => c.tableId == tableId);
    if (idx >= 0) {
      activeIndex = idx;
      checks[idx].guests = guests;
    } else {
      if (active.lines.isNotEmpty || active.tableId != null) newCheck();
      active.orderType = 'В заведении';
      active.hallId = hallId;
      active.tableId = tableId;
      active.guests = guests;
      // Windows bilan simmetriya: ijara taymeri stol ochilgan paytdan boshlanadi
      // (android'da hisob ko'rsatilmaydi, lekin Windows kassasi shu vaqtga tayanadi).
      active.seatedAt = DateTime.now();
    }
    notifyListeners();
  }

  /// «Навынос» — stolsiz buyurtma.
  void startTakeaway() {
    if (active.lines.isNotEmpty || active.tableId != null) newCheck();
    active.orderType = 'Навынос';
    active.hallId = null;
    active.tableId = null;
    active.guests = 0;
    active.seatedAt = null;
    notifyListeners();
  }

  /// Stol band (biror ochiq chekka biriktirilgan)mi?
  bool isTableOccupied(int tableId) => checks.any((c) => c.tableId == tableId);

  /// Stoldagi ochiq chek summasi (band bo'lsa).
  int tableDue(int tableId) {
    final c = checks.where((c) => c.tableId == tableId).toList();
    return c.isEmpty ? 0 : c.first.dueFor(app);
  }

  void switchCheck(int i) {
    if (checks.isEmpty) return;
    // Eskirgan indeks (masalan, boshqa qurilma chekni yopib ro'yxat qisqargan
    // payt) RangeError bermasin — windows'dagi bilan bir xil himoya.
    activeIndex = i.clamp(0, checks.length - 1);
    notifyListeners();
  }

  /// Bonus limiti: min(mavjud bonus, chekning yarmi) (prototip payAssign).
  int bonusCapFor(CheckDoc doc, int alreadyBonus) {
    final c = doc.client;
    if (c == null) return 0;
    final byBonus = c.bonus - alreadyBonus;
    final byMax = (doc.dueFor(app) * app.maxBonusPayPct / 100).floor() - alreadyBonus;
    final cap = byBonus < byMax ? byBonus : byMax;
    return cap < 0 ? 0 : cap;
  }

  /// Y-7: oxirgi to'langan chek — aynan shu CheckDoc ikki marta to'lanmasin
  /// (double-tap / re-fire). Cross-device (ikki qurilma bir chekni bir vaqtda)
  /// uchun server-side kerak — Windows'da client runTransaction ishlamaydi.
  CheckDoc? _lastPaidDoc;

  /// To'lov yakunlangach: arxivga, statistika, chekni tozalash.
  /// [parts]: cash/card/cert/bonus summalar. [change]: qaytim.
  void completePayment({
    required Map<String, int> parts,
    required int change,
    required String paymentLabel,
    required int subtotalAmt,
    required int discountPctAmt,
    required int discountAmt,
    required int totalDue,
  }) {
    final doc = active;
    // Y-7: bo'sh yoki aynan shu chek qayta to'lanmasin (double-tap/re-fire himoyasi).
    if (doc.lines.isEmpty || identical(_lastPaidDoc, doc)) return;
    _lastPaidDoc = doc;
    _syncNextOrder(); // parallel qurilma/eski sessiya raqami bilan to'qnashmasin
    final cashApplied = (parts['cash'] ?? 0) - change;
    final cardApplied = (parts['card'] ?? 0) + (parts['cert'] ?? 0); // O-1: karta+sertifikat → безнал
    final itemsStr = doc.lines
        .map((l) => '${l.product.name} ×${l.qty % 1 == 0 ? l.qty.toInt() : qtyStr(l.qty)}')
        .join(', ');
    final profit = totalDue - doc.costTotal;
    final receipt = Receipt(
      id: nextOrder,
      time: _now(),
      waiter: user?.name ?? 'Кассир',
      sum: totalDue,
      payment: paymentLabel,
      items: itemsStr,
      profit: profit,
      // To'lov qismlari (№7) — X/Z-otchet aralash to'lovni to'g'ri taqsimlaydi.
      // Android'da sertifikat karta bilan birga hisoblanadi (mavjud siyosat).
      payCash: cashApplied,
      payCard: (parts['card'] ?? 0) + (parts['cert'] ?? 0),
      payBonus: parts['bonus'] ?? 0,
      payDebt: parts['debt'] ?? 0,
    );
    app.receiptsArchive.insert(0, receipt);
    nextOrder += 1;

    // Statistika (prototip finishPay bilan bir xil taqsimot)
    app.salesToday['revenue'] = (app.salesToday['revenue'] as int) + totalDue;
    app.salesToday['profit'] = (app.salesToday['profit'] as int) + profit;
    app.salesToday['checks'] = (app.salesToday['checks'] as int) + 1;
    app.salesToday['visitors'] = (app.salesToday['visitors'] as int) + 1;
    app.salesToday['avgCheck'] =
        ((app.salesToday['revenue'] as int) / (app.salesToday['checks'] as int)).round();
    app.paymentMethods['Наличные'] = (app.paymentMethods['Наличные'] ?? 0) + cashApplied;
    app.paymentMethods['Карточка'] =
        (app.paymentMethods['Карточка'] ?? 0) + (parts['card'] ?? 0) + (parts['cert'] ?? 0);
    app.paymentMethods['Бонусы'] = (app.paymentMethods['Бонусы'] ?? 0) + (parts['bonus'] ?? 0);
    // Ochiq smena ko'rsatkichlari (Z-otchet) — HOLAT-17: avval android savdosi
    // smenani umuman oshirmasdi, Windows Z-otcheti kam ko'rsatardi.
    app.shiftAddSale(
      revenue: totalDue,
      profit: profit,
      cash: cashApplied,
      card: (parts['card'] ?? 0) + (parts['cert'] ?? 0),
      bonus: parts['bonus'] ?? 0,
      debt: parts['debt'] ?? 0,
    );
    // «Популярные товары» (Главная/Статистика) — real savdolardan yig'iladi.
    for (final l in doc.lines) {
      final existing = app.topProducts.where((t) => t['name'] == l.product.name).toList();
      if (existing.isNotEmpty) {
        existing.first['count'] = (existing.first['count'] as int) + l.qty.round();
        existing.first['sum'] = (existing.first['sum'] as int) + l.total;
      } else {
        app.topProducts.add({'name': l.product.name, 'emoji': l.product.photo, 'count': l.qty.round(), 'sum': l.total});
      }
    }
    app.topProducts.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    // Naqd — kassa yashigiga
    final cashBox = app.accounts.where((a) => a.name == 'Денежный ящик').toList();
    if (cashBox.isNotEmpty) cashBox.first.balance += cashApplied;
    // O-1: karta — безнал (bank) hisobiga (ilgari balans yangilanmasdi, «Счета»da 0 turardi).
    if (cardApplied > 0) {
      final bank = app.accounts.where((a) => a.type == 'Безналичный счет').toList();
      if (bank.isNotEmpty) bank.first.balance += cardApplied;
    }
    // Kassir statistikasi (Статистика → Сотрудники)
    if (user != null) {
      user!.revenue += totalDue;
      user!.checks += 1;
    }
    // Bonus sarflandi — mijoz balansidan
    final bonusUsed = parts['bonus'] ?? 0;
    if (doc.client != null && bonusUsed > 0) doc.client!.bonus -= bonusUsed;
    // Bonus ishlab topildi — xariddan qaytadi (loyallik dasturi)
    if (doc.client != null && app.bonusEarnPct > 0) {
      doc.client!.bonus += (totalDue * app.bonusEarnPct / 100).round();
    }
    // Retsept bo'yicha ombor qoldig'ini kamaytirish (тех.карта → ingredientlar)
    app.consumeStockForSale(doc.lines);
    // Mijoz — jami xaridlar summasi (Маркетинг karta / Статистика)
    if (doc.client != null) doc.client!.totalSpent += totalDue;
    // Vaqt qatorlari (Статистика/Главная grafiklari real savdolardan to'ladi)
    final now = DateTime.now();
    app.byHour[now.hour] += totalDue;
    const wk = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final wkKey = wk[(now.weekday - 1).clamp(0, 6).toInt()];
    app.byWeekday[wkKey] = (app.byWeekday[wkKey] ?? 0) + totalDue;
    final dayVals = app.chartSeries['day']!['values'] as List<int>;
    dayVals[(now.hour - 9).clamp(0, dayVals.length - 1).toInt()] += totalDue;
    (app.chartSeries['week']!['values'] as List<int>)[6] += totalDue;
    (app.chartSeries['month']!['values'] as List<int>)[29] += totalDue;
    // Backend (§5): sotuvni Firestore'ga atomik yozish (write-through).
    app.persistSale(
      receipt: receipt,
      cashApplied: cashApplied,
      cardApplied: cardApplied,
      lines: doc.lines,
      client: doc.client,
      bonusSpent: bonusUsed,
      bonusEarned: (doc.client != null && app.bonusEarnPct > 0)
          ? (totalDue * app.bonusEarnPct / 100).round()
          : 0,
    );
    app.notify();

    // Chekni yakunlash: agar ko'p chek bo'lsa — olib tashlash, aks holda 1-chekka reset.
    checks.removeAt(activeIndex);
    _deleteRemote(doc); // to'landi — ochiq cheklar kolleksiyasidan o'chadi
    if (checks.isEmpty) {
      checks.add(CheckDoc(1));
      _nextNumber = 2;
    }
    activeIndex = 0;
    notifyListeners();
  }

  /// «Закрыть без оплаты» — chekni to'lovsiz yopish.
  /// №5 (HOLAT-17): endi audit izi qoladi — `voidedChecks` jurnaliga kim,
  /// qachon, qaysi stol va qancha summani to'lovsiz yopgani yoziladi
  /// (klassik POS firibgarlik vektori edi: hech qanday iz qolmasdi).
  void closeWithoutPay() {
    final doc = active;
    if (app.repo.ready && _persistWorthy(doc)) {
      app.repo.saveVoidedCheck({
        ...openCheckToMap(doc),
        'sum': doc.dueFor(app),
        'employeeUid': user?.uid ?? app.session?.uid,
        'employeeName': user?.name ?? app.session?.name ?? '',
        'device': app.deviceId,
      }).catchError((e) => debugPrint('voidedCheck save failed: $e'));
    }
    checks.removeAt(activeIndex);
    _deleteRemote(doc); // yopildi — serverdan ham o'chadi
    if (checks.isEmpty) checks.add(CheckDoc(1));
    activeIndex = 0;
    notifyListeners();
  }

  String qtyStr(double q) => q.toString().replaceAll('.', ',');

  String _now() {
    final d = DateTime.now();
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
