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
  String pin;
  String phone;
  String? login;
  String? lastLogin;
  int revenue;
  int checks;
  // ── Backend (BACKEND-TAYYORGARLIK.md §12) ──
  String? uid;      // Firebase Auth UID (employee doc id = uid)
  bool active;      // owner enable/disable (false → kira/ishlata olmaydi)
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
  });
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
  final int id;
  String date;
  String type; // расход | доход | перевод
  String category;
  String comment;
  int amount; // musbat/manfiy
  String account;
  TxItem({
    required this.id,
    required this.date,
    required this.type,
    required this.category,
    required this.comment,
    required this.amount,
    required this.account,
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
  final int id;
  String time;
  String waiter;
  int sum;
  String payment;
  String items;
  int profit;
  String status; // Закрыт | Возврат
  DateTime? createdAt; // server vaqti (restartda statistikani tiklash uchun)
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
  RestTable({required this.id, required this.hallId, required this.name, this.seats = 4});
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
  });
  bool get billingActive =>
      subscriptionStatus == 'active' || subscriptionStatus == 'trial';
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
