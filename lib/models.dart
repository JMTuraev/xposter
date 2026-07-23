import 'utils/pin_hash.dart';

class Category {
  final int id;
  String name;
  int color; // tanlangan rang (endi tahrirlash mumkin)
  bool hidden;
  Category({required this.id, required this.name, required this.color, this.hidden = false});
}

class Modification {
  String name;
  Modification(this.name);
}

/// Tех.карта retsept qatori — real ingredientga bog'lanadi (sotuvda hisobdan chiqadi).
class RecipeItem {
  final int ingredientId;
  double brutto; // brutto (g/ml) — bitta portsiyaga
  double netto;  // netto (g/ml)
  RecipeItem({required this.ingredientId, required this.brutto, required this.netto});
}

class Product {
  final int id;
  String name;
  int categoryId;
  String type; // dish | product | prepack (полуфабрикат)
  String? workshop; // Кухня | Бар | null
  int price;
  int cost;
  String photo; // emoji (rasm yo'q bo'lsa fallback)
  String? imagePath; // real rasm fayli yo'li (image_picker); null → emoji ko'rsatiladi
  List<Modification>? modifications;
  List<RecipeItem>? recipe; // тех.карта tarkibi (null/bo'sh → oddiy tovar)
  bool noDiscount;
  bool byWeight;
  String? barcode; // shtrix-kod — xposterwin (Windows kassa) bilan umumiy maydon

  Product({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.type,
    required this.workshop,
    required this.price,
    required this.cost,
    required this.photo,
    this.imagePath,
    this.modifications,
    this.recipe,
    this.noDiscount = false,
    this.byWeight = false,
    this.barcode,
  });

  int get markup => cost == 0 ? 0 : (((price - cost) / cost) * 100).round();
  bool get hasImage => imagePath != null && imagePath!.isNotEmpty;
}

class Ingredient {
  final int id;
  String name;
  String unit; // кг | л | шт
  double stock;
  int costPerUnit;
  double limit;
  Ingredient({
    required this.id,
    required this.name,
    required this.unit,
    required this.stock,
    required this.costPerUnit,
    required this.limit,
  });
  bool get low => stock < limit;
  int get stockValue => (stock * costPerUnit).round();
}

class Supplier {
  final int id;
  String name;
  String phone;
  int suppliesCount;
  int suppliesSum;
  int debt;
  Supplier({
    required this.id,
    required this.name,
    required this.phone,
    this.suppliesCount = 0,
    this.suppliesSum = 0,
    this.debt = 0,
  });
}

class Employee {
  final int id;
  String name;
  String role;
  /// FAQAT legacy/tranzit: yangi PIN'lar `pinHash`+`pinSalt` da saqlanadi,
  /// serverga ochiq matn YOZILMAYDI. Migratsiyagacha eski hujjatlarda
  /// to'lgan bo'lishi mumkin (tekshiruv `matchesPin` orqali).
  String pin;
  String phone;
  String? login;
  String? lastLogin;
  int revenue;
  int checks;
  // ── Backend (BACKEND-TAYYORGARLIK.md §12) ──
  String? uid;      // Firebase Auth UID (employee doc id = uid)
  bool active;      // owner enable/disable (false → kira/ishlata olmaydi)
  // ── PIN hash (HOLAT-16, utils/pin_hash.dart bilan) ──
  String? pinSalt;
  String? pinHash;
  Employee({
    required this.id,
    required this.name,
    required this.role,
    required this.pin,
    required this.phone,
    this.login,
    this.lastLogin,
    this.revenue = 0,
    this.checks = 0,
    this.uid,
    this.active = true,
    this.pinSalt,
    this.pinHash,
  });

  /// Xodimda umuman PIN o'rnatilganmi (hash yoki legacy ochiq matn).
  bool get hasPin => (pinHash != null && pinHash!.isNotEmpty) || pin.isNotEmpty;

  /// Kiritilgan PIN shu xodimnikimi. Hash bo'lsa — hash solishtiriladi,
  /// bo'lmasa legacy ochiq matn (migratsiyagacha bo'lgan hujjatlar).
  bool matchesPin(String candidate) {
    if (candidate.isEmpty) return false;
    final h = pinHash, s = pinSalt;
    if (h != null && h.isNotEmpty && s != null && s.isNotEmpty) {
      return hashPin(s, candidate) == h;
    }
    return pin.isNotEmpty && pin == candidate;
  }

  /// Yangi PIN o'rnatish: salt+hash yoziladi, ochiq matn tozalanadi.
  void setPin(String newPin) {
    pinSalt = newPinSalt();
    pinHash = hashPin(pinSalt!, newPin);
    pin = '';
  }
  String get initials {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
    return name.isNotEmpty ? name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase() : '?';
  }
}

class ClientGroup {
  final int id;
  String name;
  String type; // скидочная | бонусная
  int percent;
  ClientGroup({required this.id, required this.name, required this.type, required this.percent});
}

class Client {
  final int id;
  String name;
  String phone;
  String group;
  String card;
  int totalSpent;
  int bonus;
  String? birthday;
  String? gender;
  String? email;
  String? comment;
  String? address;
  /// Mijozning qarzi («В долг» to'lovi). Windows POS (xposterwin) yozadi —
  /// bu yerda ham bo'lishi SHART, aks holda android'da mijozni tahrirlash
  /// `saveClient` ning to'liq `set()` i bilan qarzni O'CHIRIB yuboradi.
  int debt;
  Client({
    required this.id,
    required this.name,
    required this.phone,
    required this.group,
    required this.card,
    this.totalSpent = 0,
    this.bonus = 0,
    this.birthday,
    this.gender,
    this.email,
    this.comment,
    this.address,
    this.debt = 0,
  });
  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

class Account {
  final int id;
  String name;
  String type; // Наличные | Безналичный счет
  int balance;
  Account({required this.id, required this.name, required this.type, required this.balance});
}

class TxItem {
  final int id; // ketma-ket/displey raqami (Firestore hujjat kaliti EMAS)
  String date;
  String type; // расход | доход | перевод
  String category;
  String comment;
  int amount; // musbat/manfiy
  String account;
  /// Firestore hujjat kaliti (auto-ID). K2 tuzatishi: parallel savdoda
  /// `id` (lokal max+1) to'qnashsa ham har yozuv o'z docId'siga tushadi —
  /// moliya jurnalidan hech bir tranzaksiya yo'qolmaydi.
  String? docId;
  TxItem({
    required this.id,
    required this.date,
    required this.type,
    required this.category,
    required this.comment,
    required this.amount,
    required this.account,
    this.docId,
  });
}

class OrderLine {
  final Product product;
  double qty;
  String? comment;
  String? modification;
  OrderLine(this.product, {this.qty = 1, this.comment, this.modification});
  int get total => (product.price * qty).round();
}

class OpenOrder {
  final int id;
  String number;
  String type; // В заведении | Навынос
  String? table;
  int openMinutes;
  int sum;
  List<Map<String, dynamic>> items; // {name, qty}
  OpenOrder({
    required this.id,
    required this.number,
    required this.type,
    this.table,
    required this.openMinutes,
    required this.sum,
    required this.items,
  });
}

class Receipt {
  final int id; // ko'rsatiladigan chek raqami («Чек №N») — UNIKAL EMAS!
  String time;
  String waiter;
  int sum;
  String payment;
  String items;
  int profit;
  String status; // Закрыт | Возврат
  DateTime? createdAt; // server vaqti (restartda statistikani tiklash uchun)

  /// Firestore hujjat kaliti (auto-ID). `id` endi faqat ko'rsatish uchun:
  /// ikki qurilma bir vaqtda sotsa `id` to'qnashishi mumkin, lekin docId har xil —
  /// savdo ustma-ust yozilib yo'qolmaydi. Eski cheklar (docId = raqam) listener'da
  /// to'ldiriladi; faqat hali serverga yozilmagan yangi chekda null bo'ladi.
  String? docId;

  /// To'lov qismlari (№7, HOLAT-17): aralash to'lovda statistika to'g'ri
  /// taqsimlansin. `null` = eski chek (qismlar yozilmagan) — recompute label
  /// bo'yicha eski evristikaga tushadi.
  int? payCash;  // naqd (qaytim ayrilgan sof summa)
  int? payCard;  // karta (+sertifikat)
  int? payBonus;
  int? payDebt;
  /// Y-4: vozvratni TO'LIQ teskari qilish uchun sotuvda saqlanadi.
  int? clientId;        // mijoz (bonus/totalSpent/debt teskarisi uchun)
  int? bonusEarned;     // xariddan berilgan bonus (vozvratда bekor qilinadi)
  List<Map<String, dynamic>>? stockConsumed; // [{'id':int,'amt':num}] — sklad qaytishi
  Receipt({
    required this.id,
    required this.time,
    required this.waiter,
    required this.sum,
    required this.payment,
    required this.items,
    required this.profit,
    this.status = 'Закрыт',
    this.createdAt,
    this.docId,
    this.payCash,
    this.payCard,
    this.payBonus,
    this.payDebt,
    this.clientId,
    this.bonusEarned,
    this.stockConsumed,
  });
}

class Supply {
  final int id;
  String date;
  String supplier;
  String storage;
  String items;
  int sum;
  int debt;
  String status;
  Supply({
    required this.id,
    required this.date,
    required this.supplier,
    required this.storage,
    required this.items,
    required this.sum,
    required this.debt,
    required this.status,
  });
}

/// Zal (зал) — stollar guruhi.
class Hall {
  final int id;
  String name;
  Hall({required this.id, required this.name});
}

/// Stol (стол) — zalga tegishli, o'rin soni (sig'imi) bilan.
class RestTable {
  final int id;
  int hallId;
  String name;   // «Стол 1» yoki «VIP-1»
  int seats;     // necha kishilik o'rin
  /// Soatlik ijara tarifi (sum/soat, 0 = oddiy stol). Windows POS yozadi —
  /// bu yerda ham saqlanishi shart, aks holda android'da stolni tahrirlash
  /// tarifni o'chirib yuboradi.
  int hourlyRate;
  RestTable({required this.id, required this.hallId, required this.name, this.seats = 4, this.hourlyRate = 0});
}

/// Kafe (заведение) — multi-tenant birlik (BACKEND-TAYYORGARLIK.md §12).
/// Bitta owner → ko'p kafe. Har kafe alohida obuna (per-kafe $29/oy).
class Cafe {
  final String id;      // Firestore docId
  String ownerUid;      // egasi (Firebase Auth uid)
  String name;
  String spot;
  String address;
  String? code;         // 6 raqamli «Код заведения» — xodim kirishi uchun
  String currency;      // СУМ
  String timezone;      // Asia/Samarkand
  String? trialEndsAt;
  int serviceFeePct;
  int bonusEarnPct;
  int welcomeBonus;
  int maxBonusPayPct;
  bool cashShiftsEnabled;
  String subscriptionStatus; // active | past_due | canceled | trial
  String? nextBilling;
  // ── Obuna muddatlari (FAQAT SERVER yozadi; rules mijoz yozuvini muzlatadi) ──
  DateTime? paidUntil;   // to'langan muddat oxiri (admin/webhook uzaytiradi)
  DateTime? trialUntil;  // sinov muddati oxiri (migratsiya/admin)
  DateTime? createdAt;   // kafe yaratilgan SERVER vaqti; sinov = createdAt + 7 kun
  Cafe({
    required this.id,
    required this.ownerUid,
    required this.name,
    this.spot = '',
    this.address = '',
    this.code,
    this.currency = 'СУМ',
    this.timezone = 'Asia/Samarkand',
    this.trialEndsAt,
    this.serviceFeePct = 0,
    this.bonusEarnPct = 5,
    this.welcomeBonus = 0,
    this.maxBonusPayPct = 50,
    this.cashShiftsEnabled = true,
    this.subscriptionStatus = 'trial',
    this.nextBilling,
    this.paidUntil,
    this.trialUntil,
    this.createdAt,
  });
  bool get billingActive =>
      subscriptionStatus == 'active' || subscriptionStatus == 'trial';
}

/// Kassa smenasi (HOLAT-17: xposterwin'dan ko'chirildi — sxema BIR XIL bo'lishi
/// SHART, BACKEND.md Qoida 2). `cafes/{id}/shifts/{id}` hujjati.
class Shift {
  final int id;
  final DateTime openedAt;
  final String openedBy;
  final int openingCash; // smena ochilgandagi yashiq qoldig'i

  DateTime? closedAt;
  String? closedBy;
  int countedCash = 0;  // yopishda sanab chiqilgan naqd (fakt)
  int expectedCash = 0; // yopishda kutilgan naqd (hisob)

  // Smena davomida yig'iladigan ko'rsatkichlar
  int revenue = 0;
  int profit = 0;
  int checks = 0;
  int cash = 0;   // naqd qabul qilingan (qaytim ayrilgan)
  int card = 0;
  int bonus = 0;
  int debt = 0;       // qarzga sotilgan
  int debtRepaid = 0; // qarz qaytarilgan (naqd kirim)

  Shift({
    required this.id,
    required this.openedAt,
    required this.openedBy,
    required this.openingCash,
  });

  bool get isOpen => closedAt == null;
  int get diff => countedCash - expectedCash;
  int get avgCheck => checks > 0 ? (revenue / checks).round() : 0;

  /// «3 ч 15 мин» — smena davomiyligi.
  String durationLabel([DateTime? now]) {
    final end = closedAt ?? now ?? DateTime.now();
    final m = end.difference(openedAt).inMinutes;
    final h = m ~/ 60;
    return h > 0 ? '$h ч ${m % 60} мин' : '$m мин';
  }
}

/// Rol identifikatorlari va RBAC yordamchilari.
/// Guide §3 ruscha rol nomlaridan foydalanadi; owner/manager/cashier — moslik.
class Roles {
  static const owner = 'Владелец';
  static const manager = 'Управляющий';
  static const hallAdmin = 'Администратор зала';
  static const waiter = 'Официант';
  static const cook = 'Повар';
  static const marketer = 'Маркетолог';

  static const all = [owner, manager, hallAdmin, waiter, cook, marketer];

  /// Sodda guruh (owner/manager/cashier) — Security Rules va tashqi API uchun.
  /// owner → owner; manager → manager; qolganlari → staff (cashier darajasi).
  static String group(String role) {
    if (role == owner) return 'owner';
    if (role == manager) return 'manager';
    return 'staff';
  }
}
