import 'package:flutter/foundation.dart';
import '../../models.dart';
import '../../state/app_state.dart';

/// Bitta chek (parallel cheklar uchun).
class CheckDoc {
  final int number;
  final List<OrderLine> lines = [];
  Client? client;
  String? comment; // chekka izoh (prototip: check.comment)
  final DateTime openedAt = DateTime.now();
  // ── Zal xizmati ──
  String orderType = 'В заведении'; // В заведении | Навынос
  int? hallId;   // qaysi zal
  int? tableId;  // qaysi stol (null → stolsiz / навынос)
  int guests = 0; // mehmonlar soni
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

/// Kassa holati: PIN, foydalanuvchi, parallel cheklar.
class KassaController extends ChangeNotifier {
  final AppState app;
  Employee? user; // joriy kassir — app.session'dan olinadi
  KassaController(this.app) {
    user = app.session;
    _syncNextOrder(); // chek raqami arxivdan davom etadi (1 dan qayta boshlanmaydi!)
  }

  final List<CheckDoc> checks = [CheckDoc(1)];
  int activeIndex = 0;
  int _nextNumber = 2;
  int nextOrder = 1; // arxiv cheklari №1 dan boshlanadi

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
    final emp = app.employees.where((e) => e.pin == pin).toList();
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
    active.comment = null;
    notifyListeners();
  }

  void attachClient(Client c) {
    active.client = c;
    notifyListeners();
  }

  void detachClient() {
    active.client = null;
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
    activeIndex = i;
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
    _syncNextOrder(); // parallel qurilma/eski sessiya raqami bilan to'qnashmasin
    final cashApplied = (parts['cash'] ?? 0) - change;
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
    if (checks.isEmpty) {
      checks.add(CheckDoc(1));
      _nextNumber = 2;
    }
    activeIndex = 0;
    notifyListeners();
  }

  /// «Закрыть без оплаты» — chekni to'lovsiz yopish.
  void closeWithoutPay() {
    checks.removeAt(activeIndex);
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
