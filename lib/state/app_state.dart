import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../data/repository.dart';
import '../data/serializers.dart' show shiftToMap;

/// Butun ilovaning holati va mock ma'lumotlar (mock-data.json bo'yicha).
/// Backend YO'Q — barchasi xotirada, real interaktivlik.
class AppState extends ChangeNotifier {
  // ── Kompaniya (login'dan keyin Firestore'dagi kafe ma'lumoti bilan almashadi) ──
  final company = {
    'name': 'Моё заведение',
    'spot': '',
    'address': '',
    'currency': 'СУМ',
    'timezone': 'Asia/Samarkand',
    'trialEndsAt': '',
    'accountId': 0,
  };

  bool trialBannerVisible = true;
  bool onboardingVisible = true;
  bool cashShiftsEnabled = true; // Настройки: Кассовые смены
  bool skladOpenLowFilter = false; // Bosh sahifadan «ниже лимита» ga o'tish

  // ── Ochiq cheklar (Firestore `openChecks` — stollardagi buyurtmalar) ──
  /// Xom snapshot (har Map ichida '_docId'). KassaController birlashtiradi.
  final List<Map<String, dynamic>> openCheckDocs = [];
  /// Birinchi snapshot keldimi (kelmaguncha lokal chek O'CHIRILMAYDI).
  bool openChecksLoaded = false;
  /// Har snapshot'da oshadi — KassaController shu orqali yangilikni sezadi.
  int openChecksRev = 0;
  /// Shu ishga tushirishning qurilma belgisi — o'z yozuvimizning aks-sadosini
  /// (echo) boshqa qurilmaning tahriridan ajratish uchun.
  final String deviceId =
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${identityHashCode(Object()).toRadixString(36)}';

  // ── Kategoriyalar (boshlang'ich holat — bo'sh, foydalanuvchi o'zi kiritadi) ──
  final List<Category> categories = [];

  // ── Mahsulotlar (bo'sh — Меню orqali kiritiladi) ──
  final List<Product> products = [];

  // ── Ingredientlar (bo'sh — Меню/Склад orqali kiritiladi) ──
  final List<Ingredient> ingredients = [];

  final List<Map<String, dynamic>> storages = [
    {'id': 1, 'name': 'Основной склад', 'sum': 0},
  ];

  List<String> get storageNames => storages.map((s) => s['name'] as String).toList();

  void addStorage(String name) {
    final s = {'id': _nextId(storages.map((s) => s['id'] as int)), 'name': name, 'sum': 0};
    storages.add(s);
    if (repo.ready) repo.saveStorageRaw(s);
    notifyListeners();
  }

  final List<Supplier> suppliers = [];

  // Xodimlar Firestore'dan yuklanadi (login'dan keyin listener to'ldiradi).
  final List<Employee> employees = [];

  final List<String> roles = ['Владелец', 'Управляющий', 'Администратор зала', 'Официант', 'Повар', 'Маркетолог'];

  /// Rol → ruxsatlar (RBAC). 'all' — to'liq huquq.
  static const Map<String, Set<String>> rolePermissions = {
    'Владелец': {'all'},
    'Управляющий': {'home', 'kassa', 'halls', 'stats', 'finance', 'marketing', 'menu', 'sklad', 'employees', 'settings', 'apps', 'subscription'},
    // O-9: 'menu' olib tashlandi — server (canMenu) Администратор зала'ga menyu
    // yozishni bermaydi; UI'da ko'rsatib jim ishlamaslik yaratmaslik uchun.
    'Администратор зала': {'home', 'kassa', 'halls', 'stats', 'sklad'},
    'Официант': {'home', 'kassa', 'halls'},
    'Повар': {'home', 'menu', 'sklad'},
    'Маркетолог': {'home', 'stats', 'marketing'},
  };

  /// Joriy foydalanuvchi shu huquqqa egami?
  bool can(String perm) {
    final p = rolePermissions[currentUser.role] ?? const {'home'};
    return p.contains('all') || p.contains(perm);
  }

  // ── Zallar va stollar (Firestore'dan; yangi kafe uchun provision seed qiladi) ──
  final List<Hall> halls = [];
  final List<RestTable> tables = [];

  List<RestTable> tablesIn(int hallId) => tables.where((t) => t.hallId == hallId).toList();

  int serviceFeePct = 0; // Процент за обслуживание (0 = не использовать)
  void setServiceFeePct(int v) {
    serviceFeePct = v;
    if (repo.ready) repo.updateCafe({'serviceFeePct': v});
    notifyListeners();
  }

  // ── Loyallik (bonus dasturi) sozlamalari — kassaga real ta'sir qiladi ──
  int bonusEarnPct = 5;    // xariddan qancha % bonus qaytadi
  int welcomeBonus = 0;    // yangi mijozga xush kelibsiz bonusi
  int maxBonusPayPct = 50; // chekning necha %ini bonus bilan to'lash mumkin
  void setLoyalty({int? earn, int? welcome, int? maxPay}) {
    if (earn != null) bonusEarnPct = earn;
    if (welcome != null) welcomeBonus = welcome;
    if (maxPay != null) maxBonusPayPct = maxPay;
    if (repo.ready) {
      repo.updateCafe({'loyalty': {'earnPct': bonusEarnPct, 'welcome': welcomeBonus, 'maxPayPct': maxBonusPayPct}});
    }
    notifyListeners();
  }

  void addHall(String name) {
    final h = Hall(id: _nextId(halls.map((h) => h.id)), name: name);
    halls.add(h);
    if (repo.ready) repo.saveHall(h);
    notifyListeners();
  }
  void renameHall(Hall h, String name) { h.name = name; if (repo.ready) repo.saveHall(h); notifyListeners(); }
  void removeHall(int id) {
    halls.removeWhere((h) => h.id == id);
    final removed = tables.where((t) => t.hallId == id).toList();
    tables.removeWhere((t) => t.hallId == id);
    if (repo.ready) {
      repo.deleteHall(id);
      for (final t in removed) { repo.deleteTable(t.id); }
    }
    notifyListeners();
  }
  void addTable(int hallId, String name, int seats) {
    final t = RestTable(id: _nextId(tables.map((t) => t.id)), hallId: hallId, name: name, seats: seats);
    tables.add(t);
    if (repo.ready) repo.saveTable(t);
    notifyListeners();
  }
  void updateTable(RestTable t, {String? name, int? seats, int? hallId}) {
    if (name != null) t.name = name;
    if (seats != null) t.seats = seats;
    if (hallId != null) t.hallId = hallId;
    if (repo.ready) repo.saveTable(t);
    notifyListeners();
  }
  void removeTable(int id) { tables.removeWhere((t) => t.id == id); if (repo.ready) repo.deleteTable(id); notifyListeners(); }

  final List<ClientGroup> clientGroups = [
    ClientGroup(id: 1, name: 'Новые клиенты', type: 'скидочная', percent: 0),
    ClientGroup(id: 2, name: 'Постоянные', type: 'скидочная', percent: 5),
    ClientGroup(id: 3, name: 'VIP', type: 'бонусная', percent: 10),
  ];

  final List<Client> clients = [];

  final List<Account> accounts = [
    Account(id: 1, name: 'Денежный ящик', type: 'Наличные', balance: 0),
    Account(id: 2, name: 'Расчетный счет', type: 'Безналичный счет', balance: 0),
  ];

  // ── Kassa smenasi (HOLAT-17: xposterwin'dan ko'chirildi) ──
  Shift? currentShift;
  final List<Shift> shiftsArchive = [];

  int get cashBoxBalance {
    final box = accounts.where((a) => a.name == 'Денежный ящик').toList();
    return box.isEmpty ? 0 : box.first.balance;
  }

  int newShiftId() {
    final ids = [...shiftsArchive.map((s) => s.id), if (currentShift != null) currentShift!.id];
    return _nextId(ids);
  }

  /// Smenani ochish. [openingCash] — yashiqdagi boshlang'ich naqd (odatda joriy qoldiq).
  Shift openShift({int? openingCash}) {
    if (currentShift != null) return currentShift!;
    final s = Shift(
      id: newShiftId(),
      openedAt: DateTime.now(),
      openedBy: currentUser.name,
      openingCash: openingCash ?? cashBoxBalance,
    );
    currentShift = s;
    if (repo.ready) repo.saveShiftRaw(shiftToMap(s)).catchError((_) {});
    notifyListeners();
    return s;
  }

  /// Smenani yopish: kutilgan naqd = yashiqning joriy qoldig'i, [counted] — fakt.
  /// Farq bo'lsa «Кассовые смены» toifasida tranzaksiya yaratiladi (qoldiq faktga tenglashadi).
  Shift? closeShift({required int counted}) {
    final s = currentShift;
    if (s == null) return null;
    s.expectedCash = cashBoxBalance;
    s.countedCash = counted;
    s.closedAt = DateTime.now();
    s.closedBy = currentUser.name;

    final d = s.diff;
    if (d != 0) {
      final now = DateTime.now();
      addTransaction(TxItem(
        id: newTxId(),
        date: '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')} '
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
        type: d > 0 ? 'доход' : 'расход',
        category: 'Кассовые смены',
        comment: 'Расхождение при закрытии смены №${s.id}',
        amount: d,
        account: 'Денежный ящик',
      ));
    }
    shiftsArchive.insert(0, s);
    currentShift = null;
    if (repo.ready) repo.saveShiftRaw(shiftToMap(s)).catchError((_) {});
    notifyListeners();
    return s;
  }

  /// Sotuv ko'rsatkichlarini joriy smenaga qo'shish (completePayment'dan).
  /// Firestore rejimida `increment` bilan yoziladi — smena boshqa qurilmada ham
  /// jonli yangilanadi (listener: repository._listenShifts).
  void shiftAddSale({required int revenue, required int profit, required int cash,
      required int card, required int bonus, required int debt}) {
    final s = currentShift;
    if (s == null) return;
    s.revenue += revenue;
    s.profit += profit;
    s.checks += 1;
    s.cash += cash;
    s.card += card;
    s.bonus += bonus;
    s.debt += debt;
    if (repo.ready) {
      repo.addShiftSale(s.id,
          revenue: revenue, profit: profit, cash: cash,
          card: card, bonus: bonus, debt: debt).catchError((_) {});
    }
  }

  /// Y-4: vozvratда smena ko'rsatkichlarini teskari (shiftAddSale simmetrigi).
  void shiftReverseSale({required int revenue, required int profit, required int cash,
      required int card, required int bonus, required int debt}) {
    final s = currentShift;
    if (s == null) return;
    s.revenue -= revenue;
    s.profit -= profit;
    s.checks -= 1;
    s.cash -= cash;
    s.card -= card;
    s.bonus -= bonus;
    s.debt -= debt;
    if (repo.ready) {
      repo.addShiftSale(s.id,
          revenue: -revenue, profit: -profit, cash: -cash,
          card: -card, bonus: -bonus, debt: -debt).catchError((_) {});
    }
  }

  /// Qarz naqd qaytarilganda — smena naqd kirimiga qo'shiladi.
  void shiftAddDebtRepaid(int amount) {
    final s = currentShift;
    if (s == null) return;
    s.debtRepaid += amount;
    if (repo.ready) repo.addShiftDebtRepaid(s.id, amount).catchError((_) {});
  }

  final List<String> financeCategories = [
    'Продажи', 'Аренда', 'Зарплата', 'Поставки', 'Коммунальные платежи', 'Маркетинг',
    'Хозяйственные расходы', 'Банковские услуги и комиссии', 'Кассовые смены', 'Прочие доходы',
  ];

  final List<TxItem> transactions = [];

  // ── Statistika (nol holat — real savdolar bilan to'ladi) ──
  final Map<String, dynamic> salesToday = {
    'revenue': 0, 'profit': 0, 'checks': 0, 'visitors': 0, 'avgCheck': 0,
    'growth': {'revenue': 0, 'profit': 0, 'checks': 0, 'visitors': 0, 'avgCheck': 0},
  };

  final List<int> byHour = List<int>.filled(24, 0);

  final Map<String, int> byWeekday = {
    'Пн': 0, 'Вт': 0, 'Ср': 0, 'Чт': 0, 'Пт': 0, 'Сб': 0, 'Вс': 0,
  };

  // «Долг» — xposterwin «В долг» to'lovini yozadi; bu yerda ham bo'lmasa
  // qarzga sotilgan cheklar to'lov usullari bo'yicha hisobotdan tushib qolardi.
  final Map<String, int> paymentMethods = {'Наличные': 0, 'Карточка': 0, 'Бонусы': 0, 'Долг': 0};

  final List<Map<String, dynamic>> topProducts = [];

  /// Grafik seriyalari (nol holat).
  final Map<String, Map<String, dynamic>> chartSeries = {
    'day': {
      'title': 'Сегодня',
      'labels': ['9:00', '10:00', '11:00', '12:00', '13:00', '14:00', '15:00', '16:00', '17:00', '18:00', '19:00', '20:00'],
      'values': List<int>.filled(12, 0),
    },
    'week': {'title': 'За 7 дней', 'values': List<int>.filled(7, 0)},
    'month': {'title': 'За 30 дней', 'values': List<int>.filled(30, 0)},
  };

  final List<Map<String, dynamic>> abc = [];

  final List<OpenOrder> openOrders = [];

  final List<Receipt> receiptsArchive = [];

  final List<Supply> supplies = [];

  final List<Map<String, dynamic>> wastes = [];

  final List<Map<String, dynamic>> inventoryChecks = [];

  // ── Переработки (qayta ishlash): bir ingredientdan boshqasiga ──
  final List<Map<String, dynamic>> processings = [];
  void addProcessing({required Ingredient from, required double fromQty, required Ingredient to, required double toQty, required String date}) {
    final fromOld = from.stock;
    from.stock = (from.stock - fromQty) < 0 ? 0 : from.stock - fromQty;
    to.stock += toQty;
    final p = {'date': date, 'from': from.name, 'fromQty': fromQty, 'fromUnit': from.unit, 'to': to.name, 'toQty': toQty, 'toUnit': to.unit};
    processings.insert(0, p);
    if (repo.ready) {
      // K3: qoldiqni delta (increment) bilan — parallel sotuvni bosmaydi.
      repo.adjustIngredientStock(from.id, from.stock - fromOld);
      repo.adjustIngredientStock(to.id, toQty);
      repo.saveProcessingRaw(Map<String, dynamic>.from(p));
    }
    notifyListeners();
  }

  final List<Map<String, dynamic>> promotionsList = [];

  /// Aksiya qo'shish/yangilash — Firestore write-through bilan.
  void addPromotion(Map<String, dynamic> p) {
    final id = _nextId(promotionsList.map((x) => (x['id'] as num?)?.toInt() ?? 0));
    final rec = {...p, 'id': id};
    promotionsList.add(rec);
    if (repo.ready) repo.savePromotionRaw(rec);
    notifyListeners();
  }

  void updatePromotionAt(int index, Map<String, dynamic> p) {
    if (index < 0 || index >= promotionsList.length) return;
    final id = (promotionsList[index]['id'] as num?)?.toInt() ??
        _nextId(promotionsList.map((x) => (x['id'] as num?)?.toInt() ?? 0));
    final rec = {...p, 'id': id};
    promotionsList[index] = rec;
    if (repo.ready) repo.savePromotionRaw(rec);
    notifyListeners();
  }

  /// Inventarizatsiya hujjatini saqlash (write-through).
  void addInventoryCheck(Map<String, dynamic> inv) {
    inventoryChecks.insert(0, inv);
    if (repo.ready) repo.saveInventoryRaw(Map<String, dynamic>.from(inv));
    notifyListeners();
  }

  final subscription = {
    'invoice': 'INV-567053', 'dueDate': '09.07.2026', 'amount': '59,00 \$',
    'plan': 'Mini / 1 заведение', 'trialDaysLeft': 5,
  };

  /// BILLING O'CHIRILGAN (2026-07-23, foydalanuvchi qarori): trial/obuna banneri
  /// va cheklovi ko'rsatilmaydi. null → hech qanday banner. Billing qaytadan
  /// kerak bo'lganda quyidagi asl mantiqni tiklang.
  int? get trialDaysLeft => null;
  // int? get trialDaysLeft {
  //   final end = DateTime.tryParse(company['trialEndsAt'] as String? ?? '');
  //   if (end == null) return null;
  //   final now = DateTime.now();
  //   final d = end.difference(DateTime(now.year, now.month, now.day)).inDays;
  //   return d < 0 ? 0 : d;
  // }

  /// Trial tugash sanasi, ruscha formatda («9 июля»); noma'lum bo'lsa null.
  String? get trialEndsAtLabel {
    final end = DateTime.tryParse(company['trialEndsAt'] as String? ?? '');
    if (end == null) return null;
    const months = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
    return '${end.day} ${months[end.month - 1]}';
  }

  // ── Autentifikatsiya (Firebase Auth + Firestore repository) ──
  final AuthService _auth = AuthService();
  late final FirestoreRepository repo = FirestoreRepository(this);

  Employee? session;
  bool get isAuthed => session != null;
  static final Employee _guestOwner =
      Employee(id: 0, name: 'Owner', role: Roles.owner, pin: '', phone: '');
  Employee get currentUser => session ?? (employees.isNotEmpty ? employees.first : _guestOwner);
  set currentUser(Employee e) => session = e; // POS PIN almashinuvi bilan moslik

  String? currentCafeId;
  final List<Cafe> cafes = [];
  /// Owner egalik qiladigan barcha restoranlar (almashtirgich uchun).
  final List<Cafe> myCafes = [];
  /// Restoran yaratish/almashtirish jarayoni (UI spinner uchun).
  bool switchingCafe = false;
  String? authError;    // oxirgi auth xatosi (UI toast uchun)
  bool authBusy = false;
  /// Ilova ochilganda saqlangan sessiya tiklanayotgan payt (splash ko'rsatiladi).
  late bool bootstrapping = _auth.currentUser != null;
  bool get ownerEmailVerified => _auth.isEmailVerified;

  /// Kassa qulflangan holat: Firebase sessiya bor, lekin operator chiqqan —
  /// PIN bilan qayta kirish mumkin.
  bool get isLocked => session == null && currentCafeId != null;

  Future<void> resendEmailVerification() => _auth.sendEmailVerification();

  /// Ilova ochilganda avvalgi Firebase sessiyani tiklaydi (main'dan chaqiriladi).
  Future<void> restoreSession() async {
    final u = _auth.currentUser;
    if (u == null) {
      bootstrapping = false;
      notifyListeners();
      return;
    }
    try {
      await _bootstrapForUid(u.uid, u.email);
    } catch (_) {
      // Tarmoq yo'q va h.k. — login ekraniga qaytamiz, sessiya saqlanadi.
      authError = 'Не удалось загрузить данные. Проверьте соединение.';
    } finally {
      bootstrapping = false;
      notifyListeners();
    }
  }

  Future<void> _bootstrapForUid(String uid, String? email) async {
    final ctx = await repo.resolveContext(uid, emailFallback: email);
    if (ctx == null) {
      authError = 'Кафе не найдено или доступ отключён';
      await _auth.signOut();
      notifyListeners();
      return;
    }
    currentCafeId = ctx.cafeId;
    session = ctx.me;
    await repo.bootstrap(ctx.cafeId);
    // Push: qurilma kafe topic'iga (owner bo'lsa owner-topic'iga ham) obuna.
    NotificationService.instance
        .subscribeForCafe(ctx.cafeId, isOwner: ctx.isOwner)
        .catchError((_) {});
    session!.lastLogin = 'сейчас';
    // Oxirgi kirishni xodim hujjatiga yozamiz (merge — PIN saqlanadi).
    final sUid = session!.uid;
    if (sUid != null) {
      final now = DateTime.now();
      final label =
          '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      repo.touchLastLogin(sUid, label).catchError((_) {});
    }
    // Owner bo'lsa — restoranlar ro'yxatini fon rejimida yuklaymiz (almashtirgich uchun).
    if (ctx.isOwner) loadMyCafes();
    notifyListeners();
  }

  // ── Multi-restoran (bir owner → bir nechta restoran) ──

  /// Joriy foydalanuvchi restoran boshqara oladimi (faqat owner).
  bool get canManageVenues => session != null && currentUser.role == Roles.owner && session!.uid != null;

  /// Owner egalik qiladigan restoranlar ro'yxatini yuklaydi (almashtirgich uchun).
  Future<void> loadMyCafes() async {
    if (!canManageVenues) { myCafes.clear(); return; }
    try {
      final list = await repo.ownerCafes(session!.uid!);
      myCafes
        ..clear()
        ..addAll(list);
      myCafes.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      notifyListeners();
    } catch (_) {}
  }

  /// Yangi restoran ochadi va darhol unga o'tadi. Yangi cafeId (yoki null xatoda).
  Future<String?> createRestaurant(String name) async {
    if (!canManageVenues) { authError = 'Только владелец может создать заведение'; return null; }
    if (name.trim().isEmpty) { authError = 'Введите название заведения'; return null; }
    switchingCafe = true; authError = null; notifyListeners();
    try {
      final uid = session!.uid!;
      final email = session!.login ?? (company['email'] as String? ?? '');
      final newId = await repo.createCafeForOwner(
        uid: uid, ownerName: session!.name, email: email, cafeName: name.trim(),
      );
      await _switchToCafe(newId, uid);
      await loadMyCafes();
      return newId;
    } catch (_) {
      authError = 'Не удалось создать заведение. Проверьте соединение.';
      return null;
    } finally {
      switchingCafe = false; notifyListeners();
    }
  }

  /// Boshqa restoranga almashish (owner). true → muvaffaqiyat.
  Future<bool> switchCafe(String cafeId) async {
    if (!canManageVenues || cafeId == currentCafeId) return false;
    switchingCafe = true; authError = null; notifyListeners();
    try {
      final uid = session!.uid!;
      await repo.setOwnerCurrentCafe(uid, cafeId);
      await _switchToCafe(cafeId, uid);
      return true;
    } catch (_) {
      authError = 'Не удалось переключить заведение. Проверьте соединение.';
      return false;
    } finally {
      switchingCafe = false; notifyListeners();
    }
  }

  /// Listener'larni to'xtatib, mahalliy ma'lumotni tozalab, yangi cafega bootstrap.
  Future<void> _switchToCafe(String cafeId, String uid) async {
    await NotificationService.instance.unsubscribeAll();
    await repo.dispose();
    _clearCafeData();
    currentCafeId = cafeId;
    notifyListeners();
    await repo.bootstrap(cafeId);
    // session (owner) yangi cafedagi employee bilan _listenEmployees orqali qayta bog'lanadi.
    NotificationService.instance.subscribeForCafe(cafeId, isOwner: true).catchError((_) {});
    notifyListeners();
  }

  /// Cafe almashganda barcha mahalliy kolleksiyalarni tozalaydi (eski restoran
  /// ma'lumoti yangi bootstrap kelguncha ko'rinib turmasin).
  void _clearCafeData() {
    for (final l in <List>[
      categories, products, ingredients, suppliers, clientGroups, clients,
      accounts, transactions, receiptsArchive, supplies, halls, tables,
      employees, wastes, processings, inventoryChecks, promotionsList,
      openOrders, storages,
    ]) {
      l.clear();
    }
    recomputeStatsFromReceipts(); // stats nolga qaytadi (receiptsArchive bo'sh)
  }

  /// Owner email/parol bilan kirish. null → xato (authError'da sabab).
  Future<String?> loginByEmail(String email, String password) async {
    if (email.trim().isEmpty || password.isEmpty) {
      authError = 'Введите логин и пароль';
      notifyListeners();
      return null;
    }
    authBusy = true; authError = null; notifyListeners();
    try {
      final cred = await _auth.signInOwner(email, password);
      final u = cred.user;
      if (u == null) { authError = 'Ошибка входа'; return null; }
      await _bootstrapForUid(u.uid, email);
      return session?.name;
    } on FirebaseAuthException catch (e) {
      authError = _mapAuthError(e);
      return null;
    } catch (_) {
      authError = 'Не удалось загрузить данные. Проверьте соединение.';
      return null;
    } finally {
      authBusy = false; notifyListeners();
    }
  }

  /// Xodim: login + «Код заведения» (6 raqam) + parol bilan kiradi.
  /// Kod cafeCodes orqali cafeId ga aylantiriladi.
  Future<String?> loginByStaffCode(String login, String code, String password) async {
    if (login.trim().isEmpty || code.trim().isEmpty || password.isEmpty) {
      authError = 'Заполните логин, код заведения и пароль';
      notifyListeners();
      return null;
    }
    authBusy = true; authError = null; notifyListeners();
    try {
      final cafeId = await repo.cafeIdByCode(code);
      if (cafeId == null) {
        authError = 'Заведение с кодом $code не найдено';
        return null;
      }
      final cred = await _auth.signInEmployee(login, cafeId, password);
      final u = cred.user;
      if (u == null) { authError = 'Ошибка входа'; return null; }
      await _bootstrapForUid(u.uid, login);
      return session?.name;
    } on FirebaseAuthException catch (e) {
      authError = _mapAuthError(e);
      return null;
    } catch (_) {
      authError = 'Не удалось загрузить данные. Проверьте соединение.';
      return null;
    } finally {
      authBusy = false; notifyListeners();
    }
  }

  /// Xodim owner bergan login/parol bilan kiradi (cafeId bilan) — §12.
  Future<String?> loginByStaff(String login, String cafeId, String password) async {
    authBusy = true; authError = null; notifyListeners();
    try {
      final cred = await _auth.signInEmployee(login, cafeId, password);
      final u = cred.user;
      if (u == null) { authError = 'Ошибка входа'; return null; }
      await _bootstrapForUid(u.uid, login);
      return session?.name;
    } on FirebaseAuthException catch (e) {
      authError = _mapAuthError(e);
      return null;
    } catch (_) {
      authError = 'Не удалось загрузить данные. Проверьте соединение.';
      return null;
    } finally {
      authBusy = false; notifyListeners();
    }
  }

  /// PIN bo'yicha tez almashinuv (POS): Firebase sessiyasi saqlanadi, faqat
  /// joriy operator (session) o'zgaradi. Kafe allaqachon yuklangan bo'lishi kerak.
  String? loginByPin(String pin) {
    // PIN faqat Firebase orqali kirilgan (kafe yuklangan) qurilmada ishlaydi.
    if (currentCafeId == null) { authError = 'Сначала войдите по e-mail'; return null; }
    final e = employees.where((e) => e.matchesPin(pin) && e.active).toList();
    if (e.isEmpty) return null;
    session = e.first;
    e.first.lastLogin = 'сейчас';
    final uid = e.first.uid;
    if (uid != null && repo.ready) {
      final now = DateTime.now();
      final label =
          '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      repo.touchLastLogin(uid, label).catchError((_) {});
    }
    notifyListeners();
    return e.first.name;
  }

  Future<void> logout() async {
    await NotificationService.instance.unsubscribeAll();
    await repo.dispose();
    await _auth.signOut();
    session = null;
    currentCafeId = null;
    notifyListeners();
  }

  /// Akkauntni butunlay o'chirish (Google Play "Удалить аккаунт" talabi).
  /// null → muvaffaqiyat (foydalanuvchi Login ekraniga qaytadi), aks holda
  /// xato matni. Owner uchun BUTUN kafe(lar) va ma'lumot o'chadi — qaytarib
  /// bo'lmaydi. Serverda (Cloud Function) bajariladi.
  Future<String?> deleteAccount() async {
    if (authBusy) return null;
    authBusy = true; authError = null; notifyListeners();
    try {
      await NotificationService.instance.unsubscribeAll().catchError((_) {});
      await repo.deleteAccount();          // server: Firestore + Auth o'chirish
      await repo.dispose();                // listenerlarni yopamiz
      await _auth.signOut().catchError((_) {}); // user allaqachon o'chgan bo'lishi mumkin
      _clearCafeData();
      session = null;
      currentCafeId = null;
      myCafes.clear();
      return null;
    } on FirebaseFunctionsException catch (e) {
      return e.message ?? 'Не удалось удалить аккаунт';
    } catch (_) {
      return 'Не удалось удалить аккаунт. Проверьте соединение.';
    } finally {
      authBusy = false; notifyListeners();
    }
  }

  /// Kassani qulflash: Firebase sessiya va ma'lumotlar saqlanadi,
  /// faqat operator chiqadi — PIN bilan qaytish mumkin (Login ekranida).
  void lock() {
    session = null;
    notifyListeners();
  }

  /// Parolni tiklash xati. null → muvaffaqiyat, aks holda xato matni.
  Future<String?> resetPassword(String email) async {
    if (email.trim().isEmpty) return 'Введите e-mail';
    try {
      await _auth.sendPasswordReset(email);
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapAuthError(e);
    } catch (_) {
      return 'Нет соединения с сетью';
    }
  }

  /// Owner ro'yxatdan o'tishi: Firebase user + owner/cafe provisioning.
  Future<String?> register({
    required String company,
    required String owner,
    required String email,
    required String password,
    String pin = '0000',
  }) async {
    if (company.trim().isEmpty || owner.trim().isEmpty || email.trim().isEmpty || password.length < 6) {
      authError = 'Заполните поля (пароль ≥ 6 символов)';
      notifyListeners();
      return null;
    }
    authBusy = true; authError = null; notifyListeners();
    try {
      final cred = await _auth.registerOwner(email, password);
      final uid = cred.user!.uid;
      final cafeId = await repo.provisionOwnerAndCafe(
        uid: uid, ownerName: owner, email: email, cafeName: company,
        ownerPin: pin.length == 4 ? pin : '0000',
      );
      currentCafeId = cafeId;
      await _bootstrapForUid(uid, email);
      return session?.name;
    } on FirebaseAuthException catch (e) {
      authError = _mapAuthError(e);
      return null;
    } catch (_) {
      authError = 'Не удалось создать заведение. Проверьте соединение.';
      return null;
    } finally {
      authBusy = false; notifyListeners();
    }
  }

  /// Kafe konfiguratsiyasini AppState'ga qo'llaydi (repository yuklaganda).
  void applyCafe(Cafe c) {
    cafes
      ..removeWhere((x) => x.id == c.id)
      ..add(c);
    company['name'] = c.name;
    company['code'] = c.code ?? '';
    if (c.spot.isNotEmpty) company['spot'] = c.spot;
    if (c.address.isNotEmpty) company['address'] = c.address;
    company['currency'] = c.currency;
    company['timezone'] = c.timezone;
    if (c.trialEndsAt != null) company['trialEndsAt'] = c.trialEndsAt!;
    serviceFeePct = c.serviceFeePct;
    bonusEarnPct = c.bonusEarnPct;
    welcomeBonus = c.welcomeBonus;
    maxBonusPayPct = c.maxBonusPayPct;
    cashShiftsEnabled = c.cashShiftsEnabled;
  }

  // ── Owner: xodim boshqaruvi (§12.4 — Cloud Functions orqali) ──
  Future<void> createEmployee({required String login, required String password,
      required String name, required String role, String phone = '', String pin = ''}) =>
      repo.createEmployee(login: login, password: password, name: name, role: role, phone: phone, pin: pin);
  Future<void> setEmployeeActive(String uid, bool active) => repo.setEmployeeActive(uid, active);
  Future<void> deleteEmployee(String uid) => repo.deleteEmployee(uid);

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email': return 'Неверный e-mail';
      case 'user-disabled': return 'Учётная запись отключена';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential': return 'Неверный логин или пароль';
      case 'email-already-in-use': return 'E-mail уже зарегистрирован';
      case 'weak-password': return 'Слишком простой пароль';
      case 'network-request-failed': return 'Нет соединения с сетью';
      default: return e.message ?? 'Ошибка авторизации';
    }
  }

  // ── Yordamchilar ──
  static final Category _noCategory = Category(id: 0, name: 'Без категории', color: 0xFF9C9A92);
  Category categoryById(int id) =>
      categories.isEmpty ? _noCategory : categories.firstWhere((c) => c.id == id, orElse: () => _noCategory);
  int _nextId(Iterable<int> ids) => (ids.isEmpty ? 0 : ids.reduce((a, b) => a > b ? a : b)) + 1;

  // ── Mutatsiyalar ──
  void hideTrialBanner() { trialBannerVisible = false; notifyListeners(); }
  void hideOnboarding() { onboardingVisible = false; notifyListeners(); }

  void addClient(Client c) {
    if (welcomeBonus > 0 && c.bonus == 0) c.bonus += welcomeBonus; // xush kelibsiz bonusi
    clients.add(c);
    if (repo.ready) repo.saveClient(c);
    notifyListeners();
  }
  int newClientId() => _nextId(clients.map((c) => c.id));

  /// Mavjud mijozni yangilagach — Firestore'ga yozish (masalan bonus/tahrir).
  void saveClient(Client c) { if (repo.ready) repo.saveClient(c); notifyListeners(); }

  void addTransaction(TxItem t) {
    transactions.insert(0, t);
    final acc = accounts.firstWhere((a) => a.name == t.account, orElse: () => accounts.first);
    acc.balance += t.amount;
    // K3: balansni delta (increment) bilan yozamiz, absolyut saveAccount emas.
    if (repo.ready) { repo.saveTransaction(t); repo.adjustAccountBalance(acc.id, t.amount); }
    notifyListeners();
  }
  int newTxId() => _nextId(transactions.map((t) => t.id));

  void addProduct(Product p) { products.add(p); if (repo.ready) repo.saveProduct(p); notifyListeners(); }
  void saveProduct(Product p) { if (repo.ready) repo.saveProduct(p); notifyListeners(); }
  void removeProduct(int id) { products.removeWhere((p) => p.id == id); if (repo.ready) repo.deleteProduct(id); notifyListeners(); }
  int newProductId() => _nextId(products.map((p) => p.id));

  void addIngredient(Ingredient i) { ingredients.add(i); if (repo.ready) repo.saveIngredient(i); notifyListeners(); }
  void saveIngredient(Ingredient i) { if (repo.ready) repo.saveIngredient(i); notifyListeners(); }
  void removeIngredient(int id) { ingredients.removeWhere((i) => i.id == id); if (repo.ready) repo.deleteIngredient(id); notifyListeners(); }
  int newIngredientId() => _nextId(ingredients.map((i) => i.id));

  void removeClient(int id) { clients.removeWhere((c) => c.id == id); if (repo.ready) repo.deleteClient(id); notifyListeners(); }

  /// Supply'ni qoldiq/hisob o'zgarishisiz saqlash (tayyor hujjat, masalan
  /// menyudan tez prixod) — Firestore write-through bilan.
  void addSupplyRaw(Supply s) {
    supplies.insert(0, s);
    if (repo.ready) repo.saveSupply(s);
    notifyListeners();
  }

  void addCategory(Category c) { categories.add(c); if (repo.ready) repo.saveCategory(c); notifyListeners(); }
  void saveCategory(Category c) { if (repo.ready) repo.saveCategory(c); notifyListeners(); }
  void removeCategory(int id) { categories.removeWhere((c) => c.id == id); if (repo.ready) repo.deleteCategory(id); notifyListeners(); }
  int newCategoryId() => _nextId(categories.map((c) => c.id));

  void addSupplier(Supplier s) { suppliers.add(s); if (repo.ready) repo.saveSupplier(s); notifyListeners(); }
  int newSupplierId() => _nextId(suppliers.map((s) => s.id));

  void addClientGroup(ClientGroup g) { clientGroups.add(g); if (repo.ready) repo.saveClientGroup(g); notifyListeners(); }
  int newClientGroupId() => _nextId(clientGroups.map((g) => g.id));

  void addAccount(Account a) { accounts.add(a); if (repo.ready) repo.saveAccount(a); notifyListeners(); }
  int newAccountId() => _nextId(accounts.map((a) => a.id));

  /// Sozlamalar ekranining qolgan bo'limlari (Общие/Администрирование/Заказы/
  /// Доставка/Безопасность/Чек) — cafe hujjatida `uiSettings` sifatida saqlanadi.
  Map<String, dynamic> uiSettings = {};
  void saveUiSettings(Map<String, dynamic> patch) {
    uiSettings.addAll(patch);
    if (repo.ready) repo.updateCafe({'uiSettings': uiSettings});
    notifyListeners();
  }

  /// Kompaniya nomi/manzilini yangilash — Firestore'ga ham yoziladi.
  void setCompany({String? name, String? address}) {
    if (name != null && name.trim().isNotEmpty) company['name'] = name.trim();
    if (address != null) company['address'] = address.trim();
    if (repo.ready) {
      repo.updateCafe({
        'name': company['name'],
        'address': company['address'],
      });
    }
    notifyListeners();
  }

  void setCashShifts(bool v) {
    cashShiftsEnabled = v;
    if (repo.ready) repo.updateCafe({'cashShiftsEnabled': v});
    notifyListeners();
  }

  int newSupplyId() => _nextId(supplies.map((s) => s.id));

  /// Postavka — qoldiqni oshiradi. [payments] berilsa — tanlangan hisoblardan yechiladi,
  /// aks holda (eski xatti-harakat) to'liq to'langan bo'lsa bank hisobidan.
  void addSupply(Supply s, List<({Ingredient ing, double qty})> lines,
      {List<({String account, int amount})>? payments}) {
    supplies.insert(0, s);
    for (final l in lines) {
      l.ing.stock += l.qty;
    }
    // K3: hisob balanslarini delta bilan yozamiz (absolyut `saveAccount` emas).
    final Map<int, num> accDeltas = {};
    if (payments != null && payments.isNotEmpty) {
      for (final p in payments) {
        final norm = p.account.replaceAll('ё', 'е').toLowerCase();
        final acc = accounts.where((a) => a.name.replaceAll('ё', 'е').toLowerCase() == norm).toList();
        if (acc.isNotEmpty) {
          acc.first.balance -= p.amount;
          accDeltas[acc.first.id] = (accDeltas[acc.first.id] ?? 0) - p.amount;
        }
      }
    } else if (s.debt == 0) {
      final acc = accounts.firstWhere((a) => a.type == 'Безналичный счет', orElse: () => accounts.first);
      acc.balance -= s.sum;
      accDeltas[acc.id] = (accDeltas[acc.id] ?? 0) - s.sum;
    }
    // Qarz bo'lsa — postavshchik balansiga yoziladi.
    if (s.debt > 0) {
      final sup = suppliers.where((x) => x.name == s.supplier).toList();
      if (sup.isNotEmpty) { sup.first.debt += s.debt; if (repo.ready) repo.saveSupplier(sup.first); }
    }
    if (repo.ready) {
      repo.saveSupply(s);
      // K3: qoldiq va balans DELTA bilan (increment) — parallel sotuvni bosmaydi.
      for (final l in lines) { repo.adjustIngredientStock(l.ing.id, l.qty); }
      accDeltas.forEach((id, d) => repo.adjustAccountBalance(id, d));
    }
    notifyListeners();
  }

  /// Spisaniye — qoldiqni kamaytiradi.
  void writeOff(List<({Ingredient ing, double qty})> lines) {
    for (final l in lines) {
      final old = l.ing.stock;
      l.ing.stock = (l.ing.stock - l.qty).clamp(0, double.infinity);
      // K3: qoldiqni delta (increment) bilan yozamiz.
      if (repo.ready) repo.adjustIngredientStock(l.ing.id, l.ing.stock - old);
    }
    notifyListeners();
  }

  /// Sotuvda tех.карта retsepti bo'yicha ingredient qoldig'ini avtomatik kamaytirish.
  /// (г → кг/л; birlik «шт» bo'lsa — bevosita.) Poster'ning «живой склад» xatti-harakati.
  void consumeStockForSale(List<OrderLine> lines) {
    for (final l in lines) {
      final rec = l.product.recipe;
      if (rec == null || rec.isEmpty) continue;
      for (final ri in rec) {
        final match = ingredients.where((i) => i.id == ri.ingredientId).toList();
        if (match.isEmpty) continue;
        final ing = match.first;
        final perPortion = ing.unit == 'шт' ? ri.brutto : ri.brutto / 1000;
        final v = ing.stock - perPortion * l.qty;
        ing.stock = v < 0 ? 0 : v;
      }
    }
    // notify — completePayment o'zi chaqiradi
  }

  int get storageValue => ingredients.fold<int>(0, (s, i) => s + i.stockValue);

  /// Statistikani receiptsArchive'dan qayta hisoblash — ilova qayta ochilganda
  /// «Выручка сегодня 0» bo'lib qolmasligi uchun (Firestore'dan kelgan cheklar).
  void recomputeStatsFromReceipts() {
    salesToday['revenue'] = 0;
    salesToday['profit'] = 0;
    salesToday['checks'] = 0;
    salesToday['visitors'] = 0;
    salesToday['avgCheck'] = 0;
    for (var i = 0; i < byHour.length; i++) { byHour[i] = 0; }
    byWeekday.updateAll((_, __) => 0);
    paymentMethods.updateAll((_, __) => 0);
    topProducts.clear();
    final dayVals = chartSeries['day']!['values'] as List<int>;
    final weekVals = chartSeries['week']!['values'] as List<int>;
    final monthVals = chartSeries['month']!['values'] as List<int>;
    for (var i = 0; i < dayVals.length; i++) { dayVals[i] = 0; }
    for (var i = 0; i < weekVals.length; i++) { weekVals[i] = 0; }
    for (var i = 0; i < monthVals.length; i++) { monthVals[i] = 0; }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    const wk = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

    for (final r in receiptsArchive) {
      if (r.status == 'Возврат') continue;
      final c = r.createdAt ?? now; // pending server timestamp → hozir
      final day = DateTime(c.year, c.month, c.day);
      final daysAgo = today.difference(day).inDays;
      if (daysAgo < 0 || daysAgo > 29) continue;
      if (daysAgo == 0) {
        salesToday['revenue'] = (salesToday['revenue'] as int) + r.sum;
        salesToday['profit'] = (salesToday['profit'] as int) + r.profit;
        salesToday['checks'] = (salesToday['checks'] as int) + 1;
        salesToday['visitors'] = (salesToday['visitors'] as int) + 1;
        byHour[c.hour] += r.sum;
        dayVals[(c.hour - 9).clamp(0, dayVals.length - 1).toInt()] += r.sum;
        // To'lov usuli (№7, HOLAT-17): yangi cheklarda aniq qismlar bor —
        // aralash to'lov to'g'ri taqsimlanadi. Eski cheklar (payCash == null)
        // uchun label evristikasi qoladi (butun summa birinchi mos usulga).
        if (r.payCash != null) {
          paymentMethods['Наличные'] = (paymentMethods['Наличные'] ?? 0) + (r.payCash ?? 0);
          paymentMethods['Карточка'] = (paymentMethods['Карточка'] ?? 0) + (r.payCard ?? 0);
          paymentMethods['Бонусы'] = (paymentMethods['Бонусы'] ?? 0) + (r.payBonus ?? 0);
          paymentMethods['Долг'] = (paymentMethods['Долг'] ?? 0) + (r.payDebt ?? 0);
        } else {
          final p = r.payment;
          if (p.contains('Налич')) {
            paymentMethods['Наличные'] = (paymentMethods['Наличные'] ?? 0) + r.sum;
          } else if (p.contains('Карт') || p.contains('Серт')) {
            paymentMethods['Карточка'] = (paymentMethods['Карточка'] ?? 0) + r.sum;
          } else if (p.contains('Бонус')) {
            paymentMethods['Бонусы'] = (paymentMethods['Бонусы'] ?? 0) + r.sum;
          } else if (p.contains('олг')) { // «В долг» / «Долг» (xposterwin yozadi)
            paymentMethods['Долг'] = (paymentMethods['Долг'] ?? 0) + r.sum;
          }
        }
        // Популярные товары — "Name ×N, Name2 ×M" satridan
        for (final part in r.items.split(', ')) {
          final m = RegExp(r'^(.*) ×([\d.,]+)$').firstMatch(part.trim());
          if (m == null) continue;
          final name = m.group(1)!;
          final cnt = (double.tryParse(m.group(2)!.replaceAll(',', '.')) ?? 1).round();
          final existing = topProducts.where((t) => t['name'] == name).toList();
          if (existing.isNotEmpty) {
            existing.first['count'] = (existing.first['count'] as int) + cnt;
          } else {
            final prod = products.where((p) => p.name == name).toList();
            topProducts.add({
              'name': name,
              'emoji': prod.isNotEmpty ? prod.first.photo : '🍽️',
              'count': cnt,
              'sum': 0,
            });
          }
        }
      }
      if (daysAgo < 7) {
        byWeekday[wk[(c.weekday - 1).clamp(0, 6).toInt()]] =
            (byWeekday[wk[(c.weekday - 1).clamp(0, 6).toInt()]] ?? 0) + r.sum;
        weekVals[6 - daysAgo] += r.sum;
      }
      monthVals[29 - daysAgo] += r.sum;
    }
    final checks = salesToday['checks'] as int;
    salesToday['avgCheck'] = checks > 0 ? ((salesToday['revenue'] as int) / checks).round() : 0;
    topProducts.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
  }

  /// Sotuvni Firestore'ga atomik yozish (§5). In-memory yangilash allaqachon
  /// bo'lgan; bu — write-through (transaction). Listener'lar server qiymatini
  /// qaytaradi (optimistik yangilanish → authoritative sync).
  void persistSale({
    required Receipt receipt,
    required int cashApplied,
    int cardApplied = 0,
    required List<OrderLine> lines,
    Client? client,
    int bonusSpent = 0,
    int bonusEarned = 0,
  }) {
    if (!repo.ready) return;
    final deltas = <({int ingredientId, double amount})>[];
    for (final l in lines) {
      final rec = l.product.recipe;
      if (rec == null || rec.isEmpty) continue;
      for (final ri in rec) {
        final match = ingredients.where((i) => i.id == ri.ingredientId).toList();
        if (match.isEmpty) continue;
        final ing = match.first;
        final perPortion = ing.unit == 'шт' ? ri.brutto : ri.brutto / 1000;
        deltas.add((ingredientId: ing.id, amount: perPortion * l.qty));
      }
    }
    // Y-4: vozvratni to'liq teskari qilish uchun kerakli ma'lumotni chekka yozamiz.
    receipt.clientId = client?.id;
    receipt.bonusEarned = bonusEarned;
    receipt.stockConsumed = deltas.map((d) => {'id': d.ingredientId, 'amt': d.amount}).toList();
    repo.completePayment(
      receipt: receipt,
      cashAmount: cashApplied,
      cardAmount: cardApplied,
      employeeUid: session?.uid,
      clientId: client?.id,
      bonusSpent: bonusSpent,
      bonusEarned: bonusEarned,
      stockDeltas: deltas,
    ).catchError((e) {
      // Tranzaksiya o'tmasa — hech bo'lmaganda chekning o'zini saqlaymiz
      // (savdo yo'qolmasin); xato debug jurnalga.
      debugPrint('persistSale transaction failed: $e');
      repo.saveReceipt(receipt);
    });
    // Финансы → Транзакции ro'yxatiga sotuvni yozamiz (balansga TEGMAYMIZ —
    // uni completePayment atomik yangilaydi; addTransaction ishlatilmaydi).
    final now = DateTime.now();
    final saleTx = TxItem(
      id: newTxId(),
      date:
          '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      type: 'доход',
      category: 'Продажи',
      comment: 'Чек №${receipt.id} · ${receipt.payment}',
      amount: receipt.sum,
      account: cashApplied > 0 ? 'Денежный ящик' : 'Расчетный счет',
    );
    transactions.insert(0, saleTx);
    repo.saveTransaction(saleTx);
  }

  /// Chekni Firestore'ga yozish (masalan vozvrat status o'zgarishi).
  void saveReceipt(Receipt r) { if (repo.ready) repo.saveReceipt(r); notifyListeners(); }

  /// Y-4/Y-6: chekni TO'LIQ teskari qiladi (completePayment simmetrigi):
  /// statistika, to'lov usullari, kassa yashigi (payCash), kassir, smena,
  /// mijoz bonus/totalSpent/debt va SKLAD qoldig'i. Grafiklar ham teskari.
  void refundSale(Receipt r) {
    // Statistika
    salesToday['revenue'] = (salesToday['revenue'] as int) - r.sum;
    salesToday['profit'] = (salesToday['profit'] as int) - r.profit;
    salesToday['checks'] = (salesToday['checks'] as int) - 1;
    final ch = salesToday['checks'] as int;
    salesToday['avgCheck'] = ch > 0 ? ((salesToday['revenue'] as int) / ch).round() : 0;
    // To'lov usullari + kassa yashigi (KR-3: faqat naqd ulush chiqadi)
    final cashPart = r.payCash ?? (r.payment.contains('Налич') ? r.sum : 0);
    final cardPart = r.payCard ?? ((r.payment.contains('Карт') || r.payment.contains('Сертиф')) ? r.sum : 0);
    final bonusPart = r.payBonus ?? 0;
    if (cashPart > 0) {
      paymentMethods['Наличные'] = (paymentMethods['Наличные'] ?? 0) - cashPart;
      final box = accounts.where((a) => a.name == 'Денежный ящик').toList();
      if (box.isNotEmpty) {
        box.first.balance -= cashPart;
        if (repo.ready) repo.adjustAccountBalance(box.first.id, -cashPart);
      }
    }
    if (cardPart > 0) {
      paymentMethods['Карточка'] = (paymentMethods['Карточка'] ?? 0) - cardPart;
      // O-1: karta vozvrati bank hisobidan qaytadi.
      final bank = accounts.where((a) => a.type == 'Безналичный счет').toList();
      if (bank.isNotEmpty) {
        bank.first.balance -= cardPart;
        if (repo.ready) repo.adjustAccountBalance(bank.first.id, -cardPart);
      }
    }
    if (bonusPart > 0) paymentMethods['Бонусы'] = (paymentMethods['Бонусы'] ?? 0) - bonusPart;
    // Kassir (chekда uid yo'q — nom bo'yicha)
    final emp = employees.where((e) => e.name == r.waiter).toList();
    if (emp.isNotEmpty) {
      emp.first.revenue -= r.sum;
      emp.first.checks -= 1;
      if (repo.ready) repo.saveEmployee(emp.first);
    }
    // Smena teskari
    shiftReverseSale(revenue: r.sum, profit: r.profit, cash: cashPart, card: cardPart, bonus: bonusPart, debt: r.payDebt ?? 0);
    // Mijoz: sarflangan bonus qaytadi, topilgan bonus bekor, totalSpent/debt kamayadi
    if (r.clientId != null) {
      final bonusDelta = bonusPart - (r.bonusEarned ?? 0);
      final cl = clients.where((c) => c.id == r.clientId).toList();
      if (cl.isNotEmpty) {
        cl.first.bonus += bonusDelta;
        cl.first.totalSpent -= r.sum;
        cl.first.debt -= (r.payDebt ?? 0);
      }
      if (repo.ready) repo.adjustClient(r.clientId!, bonusDelta: bonusDelta, totalSpentDelta: -r.sum, debtDelta: -(r.payDebt ?? 0));
    }
    // Sklad qaytadi (increment)
    if (r.stockConsumed != null) {
      for (final d in r.stockConsumed!) {
        final id = (d['id'] as num).toInt();
        final amt = (d['amt'] as num).toDouble();
        final ing = ingredients.where((i) => i.id == id).toList();
        if (ing.isNotEmpty) ing.first.stock += amt;
        if (repo.ready) repo.adjustIngredientStock(id, amt);
      }
    }
    // Grafiklar (soddalashtirilgan teskari)
    int dec(int cur) => (cur - r.sum) < 0 ? 0 : cur - r.sum;
    final rh = int.tryParse(r.time.split(':').first) ?? DateTime.now().hour;
    if (rh >= 0 && rh < 24) byHour[rh] = dec(byHour[rh]);
    const wk = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final wkKey = wk[(DateTime.now().weekday - 1).clamp(0, 6).toInt()];
    byWeekday[wkKey] = dec(byWeekday[wkKey] ?? 0);
    final dv = chartSeries['day']!['values'] as List<int>;
    final di = (rh - 9).clamp(0, dv.length - 1).toInt();
    dv[di] = dec(dv[di]);
    (chartSeries['week']!['values'] as List<int>)[6] = dec((chartSeries['week']!['values'] as List<int>)[6]);
    (chartSeries['month']!['values'] as List<int>)[29] = dec((chartSeries['month']!['values'] as List<int>)[29]);
    notifyListeners();
  }

  /// Sotuv yakunlangach — statistikani va qoldiqlarni yangilash (soddalashtirilgan).
  void completeSale({required int total, required int profit, required String payment}) {
    salesToday['revenue'] = (salesToday['revenue'] as int) + total;
    salesToday['profit'] = (salesToday['profit'] as int) + profit;
    salesToday['checks'] = (salesToday['checks'] as int) + 1;
    salesToday['visitors'] = (salesToday['visitors'] as int) + 1;
    salesToday['avgCheck'] = ((salesToday['revenue'] as int) / (salesToday['checks'] as int)).round();
    // Kassa naqd hisobiga qo'shish. `firstWhere` orElse'siz edi: hisob
    // o'chirilgan/nomi o'zgargan bo'lsa StateError bilan release'da qulardi.
    if (payment.contains('Налич')) {
      final box = accounts.where((a) => a.name == 'Денежный ящик').toList();
      if (box.isNotEmpty) box.first.balance += total;
    }
    notifyListeners();
  }

  void notify() => notifyListeners();
}
