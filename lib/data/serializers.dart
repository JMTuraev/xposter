import 'package:cloud_firestore/cloud_firestore.dart';
import '../models.dart';

/// Model ↔ Firestore Map konvertatsiya (BACKEND-TAYYORGARLIK.md §2).
/// Har model docId sifatida `id.toString()` ishlatadi; `id` maydoni ham saqlanadi.

// ── Category ──
Map<String, dynamic> categoryToMap(Category c) =>
    {'id': c.id, 'name': c.name, 'color': c.color, 'hidden': c.hidden};

Category categoryFromMap(Map<String, dynamic> m) => Category(
      id: (m['id'] as num).toInt(),
      name: m['name'] as String? ?? '',
      color: (m['color'] as num?)?.toInt() ?? 0xFF9C9A92,
      hidden: m['hidden'] as bool? ?? false,
    );

// ── Modification / RecipeItem ──
Map<String, dynamic> modificationToMap(Modification m) => {'name': m.name};
Modification modificationFromMap(Map<String, dynamic> m) =>
    Modification(m['name'] as String? ?? '');

Map<String, dynamic> recipeItemToMap(RecipeItem r) =>
    {'ingredientId': r.ingredientId, 'brutto': r.brutto, 'netto': r.netto};
RecipeItem recipeItemFromMap(Map<String, dynamic> m) => RecipeItem(
      ingredientId: (m['ingredientId'] as num).toInt(),
      brutto: (m['brutto'] as num?)?.toDouble() ?? 0,
      netto: (m['netto'] as num?)?.toDouble() ?? 0,
    );

// ── Product ──
Map<String, dynamic> productToMap(Product p) => {
      'id': p.id,
      'name': p.name,
      'categoryId': p.categoryId,
      'type': p.type,
      'workshop': p.workshop,
      'price': p.price,
      'cost': p.cost,
      'photo': p.photo,
      'imagePath': p.imagePath,
      'modifications': p.modifications?.map(modificationToMap).toList(),
      'recipe': p.recipe?.map(recipeItemToMap).toList(),
      'noDiscount': p.noDiscount,
      'byWeight': p.byWeight,
      'barcode': p.barcode,
    };

Product productFromMap(Map<String, dynamic> m) => Product(
      id: (m['id'] as num).toInt(),
      name: m['name'] as String? ?? '',
      categoryId: (m['categoryId'] as num?)?.toInt() ?? 0,
      type: m['type'] as String? ?? 'product',
      workshop: m['workshop'] as String?,
      price: (m['price'] as num?)?.toInt() ?? 0,
      cost: (m['cost'] as num?)?.toInt() ?? 0,
      photo: m['photo'] as String? ?? '📦',
      imagePath: m['imagePath'] as String?,
      modifications: (m['modifications'] as List?)
          ?.map((e) => modificationFromMap(Map<String, dynamic>.from(e)))
          .toList(),
      recipe: (m['recipe'] as List?)
          ?.map((e) => recipeItemFromMap(Map<String, dynamic>.from(e)))
          .toList(),
      noDiscount: m['noDiscount'] as bool? ?? false,
      byWeight: m['byWeight'] as bool? ?? false,
      // Windows kassa (xposterwin) yozadigan maydon — android uni saqlab qoladi.
      barcode: (m['barcode'] as String?)?.trim().isEmpty ?? true ? null : (m['barcode'] as String).trim(),
    );

// ── Ingredient ──
Map<String, dynamic> ingredientToMap(Ingredient i) => {
      'id': i.id,
      'name': i.name,
      'unit': i.unit,
      'stock': i.stock,
      'costPerUnit': i.costPerUnit,
      'limit': i.limit,
    };

Ingredient ingredientFromMap(Map<String, dynamic> m) => Ingredient(
      id: (m['id'] as num).toInt(),
      name: m['name'] as String? ?? '',
      unit: m['unit'] as String? ?? 'шт',
      stock: (m['stock'] as num?)?.toDouble() ?? 0,
      costPerUnit: (m['costPerUnit'] as num?)?.toInt() ?? 0,
      limit: (m['limit'] as num?)?.toDouble() ?? 0,
    );

// ── Supplier ──
Map<String, dynamic> supplierToMap(Supplier s) => {
      'id': s.id,
      'name': s.name,
      'phone': s.phone,
      'suppliesCount': s.suppliesCount,
      'suppliesSum': s.suppliesSum,
      'debt': s.debt,
    };

Supplier supplierFromMap(Map<String, dynamic> m) => Supplier(
      id: (m['id'] as num).toInt(),
      name: m['name'] as String? ?? '',
      phone: m['phone'] as String? ?? '',
      suppliesCount: (m['suppliesCount'] as num?)?.toInt() ?? 0,
      suppliesSum: (m['suppliesSum'] as num?)?.toInt() ?? 0,
      debt: (m['debt'] as num?)?.toInt() ?? 0,
    );

// ── Employee ──
// DIQQAT (HOLAT-16): PIN ochiq matnda YOZILMAYDI. Hash o'rnatilgan xodimda
// 'pin' doim '' bo'lib yoziladi; legacy (hali migratsiya qilinmagan) hujjatda
// pinHash yo'q bo'lsa eski ochiq matn saqlanib qoladi — tahrirlashda
// setPin() uni hash'ga o'tkazadi.
Map<String, dynamic> employeeToMap(Employee e) => {
      'id': e.id,
      'name': e.name,
      'role': e.role,
      'pin': (e.pinHash != null && e.pinHash!.isNotEmpty) ? '' : e.pin,
      'pinSalt': e.pinSalt,
      'pinHash': e.pinHash,
      'phone': e.phone,
      'login': e.login,
      'lastLogin': e.lastLogin,
      'revenue': e.revenue,
      'checks': e.checks,
      'uid': e.uid,
      'active': e.active,
    };

Employee employeeFromMap(Map<String, dynamic> m) => Employee(
      id: (m['id'] as num?)?.toInt() ?? 0,
      name: m['name'] as String? ?? '',
      role: m['role'] as String? ?? Roles.waiter,
      pin: m['pin'] as String? ?? '',
      phone: m['phone'] as String? ?? '',
      login: m['login'] as String?,
      lastLogin: m['lastLogin'] as String?,
      revenue: (m['revenue'] as num?)?.toInt() ?? 0,
      checks: (m['checks'] as num?)?.toInt() ?? 0,
      uid: m['uid'] as String?,
      active: m['active'] as bool? ?? true,
      pinSalt: m['pinSalt'] as String?,
      pinHash: m['pinHash'] as String?,
    );

// ── ClientGroup ──
Map<String, dynamic> clientGroupToMap(ClientGroup g) =>
    {'id': g.id, 'name': g.name, 'type': g.type, 'percent': g.percent};
ClientGroup clientGroupFromMap(Map<String, dynamic> m) => ClientGroup(
      id: (m['id'] as num).toInt(),
      name: m['name'] as String? ?? '',
      type: m['type'] as String? ?? 'скидочная',
      percent: (m['percent'] as num?)?.toInt() ?? 0,
    );

// ── Client ──
Map<String, dynamic> clientToMap(Client c) => {
      'id': c.id,
      'name': c.name,
      'phone': c.phone,
      'group': c.group,
      'card': c.card,
      'totalSpent': c.totalSpent,
      'bonus': c.bonus,
      'birthday': c.birthday,
      'gender': c.gender,
      'email': c.email,
      'comment': c.comment,
      'address': c.address,
      'debt': c.debt, // xposterwin bilan umumiy maydon (BACKEND.md Qoida 2)
    };

Client clientFromMap(Map<String, dynamic> m) => Client(
      id: (m['id'] as num).toInt(),
      name: m['name'] as String? ?? '',
      phone: m['phone'] as String? ?? '',
      group: m['group'] as String? ?? '',
      card: m['card'] as String? ?? '',
      totalSpent: (m['totalSpent'] as num?)?.toInt() ?? 0,
      bonus: (m['bonus'] as num?)?.toInt() ?? 0,
      birthday: m['birthday'] as String?,
      gender: m['gender'] as String?,
      email: m['email'] as String?,
      comment: m['comment'] as String?,
      address: m['address'] as String?,
      debt: (m['debt'] as num?)?.toInt() ?? 0,
    );

// ── Account ──
Map<String, dynamic> accountToMap(Account a) =>
    {'id': a.id, 'name': a.name, 'type': a.type, 'balance': a.balance};
Account accountFromMap(Map<String, dynamic> m) => Account(
      id: (m['id'] as num).toInt(),
      name: m['name'] as String? ?? '',
      type: m['type'] as String? ?? 'Наличные',
      balance: (m['balance'] as num?)?.toInt() ?? 0,
    );

// ── TxItem ──
Map<String, dynamic> txToMap(TxItem t) => {
      'id': t.id,
      'date': t.date,
      'type': t.type,
      'category': t.category,
      'comment': t.comment,
      'amount': t.amount,
      'account': t.account,
    };
TxItem txFromMap(Map<String, dynamic> m) => TxItem(
      id: (m['id'] as num).toInt(),
      date: m['date'] as String? ?? '',
      type: m['type'] as String? ?? 'расход',
      category: m['category'] as String? ?? '',
      comment: m['comment'] as String? ?? '',
      amount: (m['amount'] as num?)?.toInt() ?? 0,
      account: m['account'] as String? ?? '',
    );

// ── Receipt ──
Map<String, dynamic> receiptToMap(Receipt r) => {
      'id': r.id,
      'time': r.time,
      'waiter': r.waiter,
      'sum': r.sum,
      'payment': r.payment,
      'items': r.items,
      'profit': r.profit,
      'status': r.status,
      // To'lov qismlari (№7) — aralash to'lov statistikasi uchun.
      'payCash': r.payCash,
      'payCard': r.payCard,
      'payBonus': r.payBonus,
      'payDebt': r.payDebt,
      // Y-4: vozvratni to'liq teskari qilish uchun.
      'clientId': r.clientId,
      'bonusEarned': r.bonusEarned,
      'stockConsumed': r.stockConsumed,
    };
Receipt receiptFromMap(Map<String, dynamic> m) => Receipt(
      id: (m['id'] as num).toInt(),
      time: m['time'] as String? ?? '',
      waiter: m['waiter'] as String? ?? '',
      sum: (m['sum'] as num?)?.toInt() ?? 0,
      payment: m['payment'] as String? ?? '',
      items: m['items'] as String? ?? '',
      profit: (m['profit'] as num?)?.toInt() ?? 0,
      status: m['status'] as String? ?? 'Закрыт',
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      payCash: (m['payCash'] as num?)?.toInt(),
      payCard: (m['payCard'] as num?)?.toInt(),
      payBonus: (m['payBonus'] as num?)?.toInt(),
      payDebt: (m['payDebt'] as num?)?.toInt(),
      clientId: (m['clientId'] as num?)?.toInt(),
      bonusEarned: (m['bonusEarned'] as num?)?.toInt(),
      stockConsumed: (m['stockConsumed'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );

// ── Shift (kassa smenasi) ── (HOLAT-17: xposterwin bilan AYNAN bir xil)
Map<String, dynamic> shiftToMap(Shift s) => {
      'id': s.id,
      'openedAt': s.openedAt.toIso8601String(),
      'openedBy': s.openedBy,
      'openingCash': s.openingCash,
      'closedAt': s.closedAt?.toIso8601String(),
      'closedBy': s.closedBy,
      'countedCash': s.countedCash,
      'expectedCash': s.expectedCash,
      'revenue': s.revenue,
      'profit': s.profit,
      'checks': s.checks,
      'cash': s.cash,
      'card': s.card,
      'bonus': s.bonus,
      'debt': s.debt,
      'debtRepaid': s.debtRepaid,
    };

Shift shiftFromMap(Map<String, dynamic> m) {
  final s = Shift(
    id: (m['id'] as num?)?.toInt() ?? 1,
    openedAt: DateTime.tryParse(m['openedAt'] as String? ?? '') ?? DateTime.now(),
    openedBy: m['openedBy'] as String? ?? '',
    openingCash: (m['openingCash'] as num?)?.toInt() ?? 0,
  );
  s.closedAt = DateTime.tryParse(m['closedAt'] as String? ?? '');
  s.closedBy = m['closedBy'] as String?;
  s.countedCash = (m['countedCash'] as num?)?.toInt() ?? 0;
  s.expectedCash = (m['expectedCash'] as num?)?.toInt() ?? 0;
  s.revenue = (m['revenue'] as num?)?.toInt() ?? 0;
  s.profit = (m['profit'] as num?)?.toInt() ?? 0;
  s.checks = (m['checks'] as num?)?.toInt() ?? 0;
  s.cash = (m['cash'] as num?)?.toInt() ?? 0;
  s.card = (m['card'] as num?)?.toInt() ?? 0;
  s.bonus = (m['bonus'] as num?)?.toInt() ?? 0;
  s.debt = (m['debt'] as num?)?.toInt() ?? 0;
  s.debtRepaid = (m['debtRepaid'] as num?)?.toInt() ?? 0;
  return s;
}

// ── Supply ──
Map<String, dynamic> supplyToMap(Supply s) => {
      'id': s.id,
      'date': s.date,
      'supplier': s.supplier,
      'storage': s.storage,
      'items': s.items,
      'sum': s.sum,
      'debt': s.debt,
      'status': s.status,
    };
Supply supplyFromMap(Map<String, dynamic> m) => Supply(
      id: (m['id'] as num).toInt(),
      date: m['date'] as String? ?? '',
      supplier: m['supplier'] as String? ?? '',
      storage: m['storage'] as String? ?? '',
      items: m['items'] as String? ?? '',
      sum: (m['sum'] as num?)?.toInt() ?? 0,
      debt: (m['debt'] as num?)?.toInt() ?? 0,
      status: m['status'] as String? ?? '',
    );

// ── Hall / RestTable ──
Map<String, dynamic> hallToMap(Hall h) => {'id': h.id, 'name': h.name};
Hall hallFromMap(Map<String, dynamic> m) =>
    Hall(id: (m['id'] as num).toInt(), name: m['name'] as String? ?? '');

Map<String, dynamic> tableToMap(RestTable t) =>
    {'id': t.id, 'hallId': t.hallId, 'name': t.name, 'seats': t.seats, 'hourlyRate': t.hourlyRate};
RestTable tableFromMap(Map<String, dynamic> m) => RestTable(
      id: (m['id'] as num).toInt(),
      hallId: (m['hallId'] as num?)?.toInt() ?? 0,
      name: m['name'] as String? ?? '',
      seats: (m['seats'] as num?)?.toInt() ?? 4,
      hourlyRate: (m['hourlyRate'] as num?)?.toInt() ?? 0,
    );

// ── Cafe (config doc) ──
Map<String, dynamic> cafeToMap(Cafe c) => {
      'ownerUid': c.ownerUid,
      'name': c.name,
      'spot': c.spot,
      'address': c.address,
      'code': c.code,
      'currency': c.currency,
      'timezone': c.timezone,
      'trialEndsAt': c.trialEndsAt,
      'serviceFeePct': c.serviceFeePct,
      'loyalty': {
        'earnPct': c.bonusEarnPct,
        'welcome': c.welcomeBonus,
        'maxPayPct': c.maxBonusPayPct,
      },
      'cashShiftsEnabled': c.cashShiftsEnabled,
      'subscription': {
        'status': c.subscriptionStatus,
        'nextBilling': c.nextBilling,
      },
    };

Cafe cafeFromMap(String id, Map<String, dynamic> m) {
  final loyalty = (m['loyalty'] as Map?)?.cast<String, dynamic>() ?? const {};
  final sub = (m['subscription'] as Map?)?.cast<String, dynamic>() ?? const {};
  return Cafe(
    id: id,
    ownerUid: m['ownerUid'] as String? ?? '',
    name: m['name'] as String? ?? '',
    spot: m['spot'] as String? ?? '',
    address: m['address'] as String? ?? '',
    code: m['code'] as String?,
    currency: m['currency'] as String? ?? 'СУМ',
    timezone: m['timezone'] as String? ?? 'Asia/Samarkand',
    trialEndsAt: m['trialEndsAt'] as String?,
    serviceFeePct: (m['serviceFeePct'] as num?)?.toInt() ?? 0,
    bonusEarnPct: (loyalty['earnPct'] as num?)?.toInt() ?? 5,
    welcomeBonus: (loyalty['welcome'] as num?)?.toInt() ?? 0,
    maxBonusPayPct: (loyalty['maxPayPct'] as num?)?.toInt() ?? 50,
    cashShiftsEnabled: m['cashShiftsEnabled'] as bool? ?? true,
    subscriptionStatus: sub['status'] as String? ?? 'trial',
    nextBilling: sub['nextBilling'] as String?,
  );
}
