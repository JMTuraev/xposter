import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models.dart';
import '../state/app_state.dart';
import 'firestore_refs.dart';
import 'serializers.dart';

/// Foydalanuvchi konteksti — login'dan keyin rol va kafe aniqlanadi.
class UserContext {
  final String uid;
  final bool isOwner;
  final String cafeId;
  final Employee me; // session uchun (rol bilan)
  UserContext({required this.uid, required this.isOwner, required this.cafeId, required this.me});
}

/// AppState ↔ Firestore sync qatlami (BACKEND-TAYYORGARLIK.md §11).
///
/// Strategiya (§1): AppState saqlanadi. Bu qatlam (a) login'da kafe ma'lumotini
/// yuklaydi, (b) har mutatsiyada write-through qiladi, (c) listener'lar bilan
/// AppState'ni yangilaydi. UI kodi o'zgarmaydi — u baribir AppState'ni o'qiydi.
class FirestoreRepository {
  FirestoreRepository(this.app, {FirebaseFirestore? firestore, FirebaseFunctions? functions})
      : db = Db(firestore ?? FirebaseFirestore.instance),
        _fns = functions ?? FirebaseFunctions.instance;

  final AppState app;
  final Db db;
  final FirebaseFunctions _fns;

  String? cafeId;
  final List<StreamSubscription> _subs = [];

  // ─────────────────────────── Kontekst / rol ───────────────────────────

  /// UID bo'yicha owner yoki xodimligini aniqlaydi, kafe va rolni topadi.
  Future<UserContext?> resolveContext(String uid, {String? emailFallback}) async {
    // 1) Owner?
    final ownerDoc = await db.owner(uid).get();
    if (ownerDoc.exists) {
      // Tez yo'l: owner hujjatida cafeId saqlanadi (query kerak emas).
      String? cafeId = ownerDoc.data()?['cafeId'] as String?;
      if (cafeId == null) {
        final cafesQ = await db.cafes.where('ownerUid', isEqualTo: uid).limit(1).get();
        if (cafesQ.docs.isEmpty) return null; // owner bor, lekin kafe yo'q
        cafeId = cafesQ.docs.first.id;
        // Self-heal: keyingi login'lar query'siz ishlashi uchun yozib qo'yamiz.
        try { await db.owner(uid).set({'cafeId': cafeId}, SetOptions(merge: true)); } catch (_) {}
      }
      final me = Employee(
        id: 0,
        name: (ownerDoc.data()?['name'] as String?) ?? 'Owner',
        role: Roles.owner,
        pin: '',
        phone: '',
        login: emailFallback ?? (ownerDoc.data()?['email'] as String?),
        uid: uid,
        active: true,
      );
      return UserContext(uid: uid, isOwner: true, cafeId: cafeId, me: me);
    }
    // 2) Xodim? (collectionGroup bo'yicha uid = docId)
    final empQ = await db.fs.collectionGroup('employees').where('uid', isEqualTo: uid).limit(1).get();
    if (empQ.docs.isNotEmpty) {
      final doc = empQ.docs.first;
      final me = employeeFromMap(doc.data());
      me.uid = uid;
      // parent: cafes/{cafeId}/employees/{uid}
      final cafeId = doc.reference.parent.parent!.id;
      if (!me.active) return null; // disable qilingan — kira olmaydi
      return UserContext(uid: uid, isOwner: false, cafeId: cafeId, me: me);
    }
    return null;
  }

  // ─────────────────────────── Bootstrap / listeners ───────────────────────────

  /// Kafe konfiguratsiyasi + barcha kolleksiyalarni yuklaydi va listener ulaydi.
  /// Asosiy kolleksiyalarning BIRINCHI snapshot'i kelguncha kutadi (7s limit) —
  /// shunda splash'dan keyin UI darhol to'liq ma'lumot bilan ochiladi.
  Future<void> bootstrap(String cafeId) async {
    this.cafeId = cafeId;
    await _loadCafeConfig(cafeId);
    final first = <Future<void>>[
      _listen<Category>(db.categories(cafeId), categoryFromMap, app.categories),
      _listen<Product>(db.products(cafeId), productFromMap, app.products),
      _listen<Ingredient>(db.ingredients(cafeId), ingredientFromMap, app.ingredients),
      _listen<Supplier>(db.suppliers(cafeId), supplierFromMap, app.suppliers),
      _listen<ClientGroup>(db.clientGroups(cafeId), clientGroupFromMap, app.clientGroups),
      _listen<Client>(db.clients(cafeId), clientFromMap, app.clients),
      _listen<Account>(db.accounts(cafeId), accountFromMap, app.accounts),
      _listen<TxItem>(db.transactions(cafeId), txFromMap, app.transactions, orderByDesc: 'id'),
      _listen<Receipt>(db.receipts(cafeId), receiptFromMap, app.receiptsArchive,
          orderByDesc: 'id', onUpdate: app.recomputeStatsFromReceipts),
      _listen<Supply>(db.supplies(cafeId), supplyFromMap, app.supplies, orderByDesc: 'id'),
      _listen<Hall>(db.halls(cafeId), hallFromMap, app.halls),
      _listen<RestTable>(db.tables(cafeId), tableFromMap, app.tables),
      _listenEmployees(cafeId),
      _listenStorages(cafeId),
      _listenRawList(db.wastes(cafeId), app.wastes),
      _listenRawList(db.processings(cafeId), app.processings),
      _listenRawList(db.inventories(cafeId), app.inventoryChecks, orderField: 'id'),
      _listenRawList(db.promotions(cafeId), app.promotionsList, orderField: 'id', descending: false),
    ];
    await Future.wait(first).timeout(const Duration(seconds: 7), onTimeout: () => []);
    app.notify();
  }

  Future<void> _loadCafeConfig(String cafeId) async {
    final snap = await db.cafe(cafeId).get();
    if (!snap.exists) return;
    final cafe = cafeFromMap(cafeId, snap.data()!);
    // Self-heal: eski kafelarda «Код заведения» bo'lmasa — yaratamiz
    // (faqat owner sessiyasida yozish huquqi bor; xodimda jim o'tamiz).
    if (cafe.code == null || cafe.code!.isEmpty) {
      try {
        cafe.code = await _assignCafeCode(cafeId);
      } catch (_) {}
    }
    app.applyCafe(cafe);
    // Sozlamalar ekranining saqlangan qiymatlari (bo'lmasa — bo'sh).
    final ui = snap.data()!['uiSettings'];
    app.uiSettings = ui is Map ? Map<String, dynamic>.from(ui) : {};
  }

  /// Unikal 6 raqamli kod yaratib, cafeCodes/{code} va cafe.code ga yozadi.
  Future<String> _assignCafeCode(String cafeId) async {
    for (var attempt = 0; attempt < 8; attempt++) {
      final code = (100000 +
              (DateTime.now().microsecondsSinceEpoch + attempt * 7919) % 900000)
          .toString();
      final ref = db.cafeCodes.doc(code);
      final exists = (await ref.get()).exists;
      if (exists) continue;
      await ref.set({'cafeId': cafeId});
      await db.cafe(cafeId).set({'code': code}, SetOptions(merge: true));
      return code;
    }
    throw StateError('cafe code topilmadi');
  }

  /// «Код заведения» → cafeId. Topilmasa null. (Auth'siz ham o'qiladi.)
  Future<String?> cafeIdByCode(String code) async {
    final snap = await db.cafeCodes.doc(code.trim()).get();
    return snap.data()?['cafeId'] as String?;
  }

  /// Generic listener: kolleksiyani AppState ro'yxatiga ko'chiradi (replace-all).
  /// Qaytgan Future — birinchi snapshot kelganda (yoki xatoda) tugaydi.
  Future<void> _listen<T>(
    Query<Map<String, dynamic>> col,
    T Function(Map<String, dynamic>) fromMap,
    List<T> target, {
    String? orderByDesc,
    void Function()? onUpdate,
  }) {
    Query<Map<String, dynamic>> q = col;
    if (orderByDesc != null) q = q.orderBy(orderByDesc, descending: true);
    final first = Completer<void>();
    _subs.add(q.snapshots().listen((snap) {
      target
        ..clear()
        ..addAll(snap.docs.map((d) => fromMap(d.data())));
      onUpdate?.call();
      app.notify();
      if (!first.isCompleted) first.complete();
    }, onError: (_) {
      if (!first.isCompleted) first.complete();
    }));
    return first.future;
  }

  Future<void> _listenEmployees(String cafeId) {
    final first = Completer<void>();
    _subs.add(db.employees(cafeId).snapshots().listen((snap) {
      app.employees
        ..clear()
        ..addAll(snap.docs.map((d) {
          final e = employeeFromMap(d.data());
          e.uid = d.id;
          return e;
        }));
      // session identifikatorini saqlash (replace-all'dan keyin uid bo'yicha qayta bog'lash).
      final sUid = app.session?.uid;
      if (sUid != null) {
        final match = app.employees.where((e) => e.uid == sUid).toList();
        if (match.isNotEmpty) app.session = match.first;
      }
      app.notify();
      if (!first.isCompleted) first.complete();
    }, onError: (_) {
      if (!first.isCompleted) first.complete();
    }));
    return first.future;
  }

  Future<void> _listenStorages(String cafeId) {
    final first = Completer<void>();
    _subs.add(db.storages(cafeId).orderBy('id').snapshots().listen((snap) {
      if (!first.isCompleted) first.complete();
      if (snap.docs.isEmpty) return; // seed hali kelmagan bo'lsa — mahalliy default qoladi
      app.storages
        ..clear()
        ..addAll(snap.docs.map((d) => Map<String, dynamic>.from(d.data())));
      app.notify();
    }, onError: (_) {
      if (!first.isCompleted) first.complete();
    }));
    return first.future;
  }

  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    cafeId = null;
  }

  // ─────────────────────────── Write-through (CRUD) ───────────────────────────

  String? get _c => cafeId;
  bool get ready => _c != null;

  Future<void> saveCategory(Category c) async {
    if (_c == null) return;
    await db.categories(_c!).doc(c.id.toString()).set(categoryToMap(c));
  }

  Future<void> deleteCategory(int id) async {
    if (_c == null) return;
    await db.categories(_c!).doc(id.toString()).delete();
  }

  Future<void> saveProduct(Product p) async {
    if (_c == null) return;
    await db.products(_c!).doc(p.id.toString()).set(productToMap(p));
  }

  Future<void> deleteProduct(int id) async {
    if (_c == null) return;
    await db.products(_c!).doc(id.toString()).delete();
  }

  Future<void> saveIngredient(Ingredient i) async {
    if (_c == null) return;
    await db.ingredients(_c!).doc(i.id.toString()).set(ingredientToMap(i));
  }

  Future<void> deleteIngredient(int id) async {
    if (_c == null) return;
    await db.ingredients(_c!).doc(id.toString()).delete();
  }

  Future<void> deleteClient(int id) async {
    if (_c == null) return;
    await db.clients(_c!).doc(id.toString()).delete();
  }

  Future<void> saveSupplier(Supplier s) async {
    if (_c == null) return;
    await db.suppliers(_c!).doc(s.id.toString()).set(supplierToMap(s));
  }

  Future<void> saveClientGroup(ClientGroup g) async {
    if (_c == null) return;
    await db.clientGroups(_c!).doc(g.id.toString()).set(clientGroupToMap(g));
  }

  Future<void> saveClient(Client c) async {
    if (_c == null) return;
    await db.clients(_c!).doc(c.id.toString()).set(clientToMap(c));
  }

  Future<void> saveAccount(Account a) async {
    if (_c == null) return;
    await db.accounts(_c!).doc(a.id.toString()).set(accountToMap(a));
  }

  Future<void> saveTransaction(TxItem t) async {
    if (_c == null) return;
    // createdAt — vaqt bo'yicha moliyaviy hisobotlar/agregatsiya uchun (§4).
    await db.transactions(_c!).doc(t.id.toString()).set(
      {...txToMap(t), 'createdAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  Future<void> saveReceipt(Receipt r) async {
    if (_c == null) return;
    await db.receipts(_c!).doc(r.id.toString()).set(
      {...receiptToMap(r), 'createdAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  Future<void> saveSupply(Supply s) async {
    if (_c == null) return;
    await db.supplies(_c!).doc(s.id.toString()).set(supplyToMap(s));
  }

  Future<void> saveHall(Hall h) async {
    if (_c == null) return;
    await db.halls(_c!).doc(h.id.toString()).set(hallToMap(h));
  }

  Future<void> deleteHall(int id) async {
    if (_c == null) return;
    await db.halls(_c!).doc(id.toString()).delete();
  }

  Future<void> saveTable(RestTable t) async {
    if (_c == null) return;
    await db.tables(_c!).doc(t.id.toString()).set(tableToMap(t));
  }

  Future<void> deleteTable(int id) async {
    if (_c == null) return;
    await db.tables(_c!).doc(id.toString()).delete();
  }

  Future<void> saveEmployee(Employee e) async {
    if (_c == null || e.uid == null) return;
    await db.employees(_c!).doc(e.uid!).set(employeeToMap(e));
  }

  /// Kafe config maydonlarini yangilash (serviceFee, loyalty, cashShifts, ...).
  Future<void> updateCafe(Map<String, dynamic> patch) async {
    if (_c == null) return;
    await db.cafe(_c!).set(patch, SetOptions(merge: true));
  }

  Future<void> saveStorageRaw(Map<String, dynamic> s) async {
    if (_c == null) return;
    await db.storages(_c!).doc(s['id'].toString()).set(s);
  }

  Future<void> saveProcessingRaw(Map<String, dynamic> p) async {
    if (_c == null) return;
    await db.processings(_c!).add({...p, 'createdAt': FieldValue.serverTimestamp()});
  }

  Future<void> saveWasteRaw(Map<String, dynamic> w) async {
    if (_c == null) return;
    await db.wastes(_c!).add({...w, 'createdAt': FieldValue.serverTimestamp()});
  }

  /// Raw (Map) kolleksiya listener'i — wastes/processings/inventories/promotions
  /// restartdan keyin ham ko'rinsin.
  Future<void> _listenRawList(
    CollectionReference<Map<String, dynamic>> col,
    List<Map<String, dynamic>> target, {
    String orderField = 'createdAt',
    bool descending = true,
  }) {
    final first = Completer<void>();
    _subs.add(col.orderBy(orderField, descending: descending).snapshots().listen((snap) {
      target
        ..clear()
        ..addAll(snap.docs.map((d) => Map<String, dynamic>.from(d.data())..remove('createdAt')));
      app.notify();
      if (!first.isCompleted) first.complete();
    }, onError: (_) {
      if (!first.isCompleted) first.complete();
    }));
    return first.future;
  }

  /// Aksiya (id maydoni bilan) — doc id = id.
  Future<void> savePromotionRaw(Map<String, dynamic> p) async {
    if (_c == null) return;
    await db.promotions(_c!).doc(p['id'].toString()).set(
        {...p, 'createdAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }

  /// Inventarizatsiya (id maydoni bilan) — doc id = id.
  Future<void> saveInventoryRaw(Map<String, dynamic> inv) async {
    if (_c == null) return;
    await db.inventories(_c!).doc(inv['id'].toString()).set(
        {...inv, 'createdAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }

  /// Oxirgi kirish vaqtini xodim hujjatiga yozish (PIN saqlanib qoladi — merge).
  Future<void> touchLastLogin(String uid, String label) async {
    if (_c == null) return;
    await db.employees(_c!).doc(uid).set({'lastLogin': label}, SetOptions(merge: true));
  }

  // ─────────────────────────── Owner amallari (Cloud Functions) ───────────────────────────

  /// Owner yangi xodim yaratadi (Admin SDK — Cloud Function orqali, §12.4).
  /// Client SDK createUser owner sessiyasini almashtiradi, shuning uchun callable.
  Future<void> createEmployee({
    required String login,
    required String password,
    required String name,
    required String role,
    String phone = '',
    String pin = '',
  }) async {
    if (_c == null) return;
    final callable = _fns.httpsCallable('createEmployee');
    await callable.call({
      'cafeId': _c,
      'login': login,
      'password': password,
      'name': name,
      'role': role,
      'phone': phone,
      'pin': pin,
    });
  }

  /// Xodimni enable/disable qiladi (§12.4).
  Future<void> setEmployeeActive(String uid, bool active) async {
    final callable = _fns.httpsCallable('setEmployeeActive');
    await callable.call({'cafeId': _c, 'uid': uid, 'active': active});
  }

  /// Xodimni o'chiradi (auth + doc).
  Future<void> deleteEmployee(String uid) async {
    final callable = _fns.httpsCallable('deleteEmployee');
    await callable.call({'cafeId': _c, 'uid': uid});
  }

  // ─────────────────────────── Provisioning (yangi owner) ───────────────────────────

  /// Yangi owner ro'yxatdan o'tganda: owner doc + birinchi cafe (seed) yaratiladi.
  /// cafeId qaytariladi.
  Future<String> provisionOwnerAndCafe({
    required String uid,
    required String ownerName,
    required String email,
    required String cafeName,
    String ownerPin = '0000',
  }) async {
    final cafeId = await _seedCafe(
        uid: uid, ownerName: ownerName, email: email, cafeName: cafeName, ownerPin: ownerPin);
    await db.owner(uid).set({
      'email': email,
      'name': ownerName,
      'cafeId': cafeId, // login'da query o'rniga to'g'ridan-to'g'ri ishlatiladi (= joriy cafe)
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return cafeId;
  }

  /// Mavjud owner uchun YANA BIR cafe (restoran) ochadi va uni joriy qiladi.
  /// Owner doc allaqachon bor — faqat yangi cafe seed qilinadi + cafeId yangilanadi.
  Future<String> createCafeForOwner({
    required String uid,
    required String ownerName,
    required String email,
    required String cafeName,
    String ownerPin = '0000',
  }) async {
    final cafeId = await _seedCafe(
        uid: uid, ownerName: ownerName, email: email, cafeName: cafeName, ownerPin: ownerPin);
    await setOwnerCurrentCafe(uid, cafeId);
    return cafeId;
  }

  /// Owner doc'ida joriy (oxirgi tanlangan) cafeId ni belgilaydi — keyingi
  /// login shu restorandan ochiladi.
  Future<void> setOwnerCurrentCafe(String uid, String cafeId) async {
    try {
      await db.owner(uid).set({'cafeId': cafeId}, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Owner egalik qiladigan BARCHA restoranlar (almashtirgich/picker uchun).
  Future<List<Cafe>> ownerCafes(String uid) async {
    final q = await db.cafes.where('ownerUid', isEqualTo: uid).get();
    return q.docs.map((d) => cafeFromMap(d.id, d.data())).toList();
  }

  /// Bitta cafe hujjati + owner-employee + standart hisoblar/guruhlar/sklad/zal
  /// seed qilinadi. cafeId qaytariladi. (provision va createCafeForOwner uchun umumiy.)
  Future<String> _seedCafe({
    required String uid,
    required String ownerName,
    required String email,
    required String cafeName,
    String ownerPin = '0000',
  }) async {
    final cafeRef = db.cafes.doc();
    final cafeId = cafeRef.id;
    final trialEnds = DateTime.now().add(const Duration(days: 14)).toIso8601String().substring(0, 10);
    await cafeRef.set(cafeToMap(Cafe(
      id: cafeId,
      ownerUid: uid,
      name: cafeName,
      spot: '$cafeName — Центр',
      trialEndsAt: trialEnds,
      subscriptionStatus: 'trial',
    )));
    // Owner ham employees ichida (POS PIN almashinuvi uchun) — har cafeda o'z uid'i bilan.
    await db.employees(cafeId).doc(uid).set(employeeToMap(Employee(
      id: 1, name: ownerName, role: Roles.owner, pin: ownerPin, phone: '',
      login: email, uid: uid, active: true,
    )));
    // Standart hisoblar / guruhlar / sklad.
    final batch = db.fs.batch();
    batch.set(db.accounts(cafeId).doc('1'),
        accountToMap(Account(id: 1, name: 'Денежный ящик', type: 'Наличные', balance: 0)));
    batch.set(db.accounts(cafeId).doc('2'),
        accountToMap(Account(id: 2, name: 'Расчетный счет', type: 'Безналичный счет', balance: 0)));
    batch.set(db.clientGroups(cafeId).doc('1'),
        clientGroupToMap(ClientGroup(id: 1, name: 'Новые клиенты', type: 'скидочная', percent: 0)));
    batch.set(db.clientGroups(cafeId).doc('2'),
        clientGroupToMap(ClientGroup(id: 2, name: 'Постоянные', type: 'скидочная', percent: 5)));
    batch.set(db.clientGroups(cafeId).doc('3'),
        clientGroupToMap(ClientGroup(id: 3, name: 'VIP', type: 'бонусная', percent: 10)));
    batch.set(db.storages(cafeId).doc('1'), {'id': 1, 'name': 'Основной склад', 'sum': 0});
    // Default zal + 4 stol — kassa zal xaritasi bo'sh bo'lib qolmasin.
    batch.set(db.halls(cafeId).doc('1'), hallToMap(Hall(id: 1, name: 'Основной зал')));
    for (var i = 1; i <= 4; i++) {
      batch.set(db.tables(cafeId).doc('$i'),
          tableToMap(RestTable(id: i, hallId: 1, name: 'Стол $i', seats: 4)));
    }
    await batch.commit();
    // «Код заведения» — xodimlar kirishi uchun (xato bo'lsa keyin self-heal).
    try { await _assignCafeCode(cafeId); } catch (_) {}
    return cafeId;
  }

  /// Boshqa restoranga o'tish: joriy listener'larni to'xtatib, yangi cafega
  /// bootstrap qiladi. (AppState collectionlarni oldindan tozalaydi.)
  Future<void> switchTo(String cafeId) async {
    await dispose();
    await bootstrap(cafeId);
  }

  // ─────────────────────────── §5: atomik to'lov (transaction) ───────────────────────────

  /// completePayment ni Firestore transaction bilan atomik qiladi (§5):
  /// receipt + account.balance + employee stats + client bonus + ingredient stock.
  /// (Hosila statistika §4 — Cloud Function `dailyAggregate` bilan.)
  Future<void> completePayment({
    required Receipt receipt,
    required int cashAmount,
    String? employeeUid,
    int? clientId,
    int bonusSpent = 0,
    int bonusEarned = 0,
    List<({int ingredientId, double amount})> stockDeltas = const [],
  }) async {
    if (_c == null) return;
    final c = _c!;
    // MUHIM: Firestore tranzaksiyasida BARCHA o'qishlar yozuvlardan OLDIN
    // bo'lishi shart — aks holda butun tranzaksiya bekor bo'ladi (assert).
    await db.fs.runTransaction((tx) async {
      // ── 1-bosqich: o'qishlar ──
      final cashRef = db.accounts(c).doc('1'); // Денежный ящик (seed id=1)
      DocumentSnapshot<Map<String, dynamic>>? cashSnap;
      if (cashAmount != 0) cashSnap = await tx.get(cashRef);

      final eRef = employeeUid != null ? db.employees(c).doc(employeeUid) : null;
      DocumentSnapshot<Map<String, dynamic>>? eSnap;
      if (eRef != null) eSnap = await tx.get(eRef);

      final cliRef = clientId != null ? db.clients(c).doc(clientId.toString()) : null;
      DocumentSnapshot<Map<String, dynamic>>? cliSnap;
      if (cliRef != null) cliSnap = await tx.get(cliRef);

      final iRefs = <({DocumentReference<Map<String, dynamic>> ref, double amount})>[];
      final iSnaps = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final d in stockDeltas) {
        final ref = db.ingredients(c).doc(d.ingredientId.toString());
        iRefs.add((ref: ref, amount: d.amount));
        iSnaps.add(await tx.get(ref));
      }

      // ── 2-bosqich: yozuvlar ──
      // Receipt (createdAt — §4 kunlik agregatsiya uchun)
      tx.set(db.receipts(c).doc(receipt.id.toString()),
          {...receiptToMap(receipt), 'createdAt': FieldValue.serverTimestamp()});
      // Kassa (Денежный ящик) balansi
      if (cashSnap != null) {
        final bal = (cashSnap.data()?['balance'] as num?)?.toInt() ?? 0;
        tx.update(cashRef, {'balance': bal + cashAmount});
      }
      // Xodim (kassir) statistikasi
      if (eSnap != null && eSnap.exists) {
        tx.update(eRef!, {
          'revenue': ((eSnap.data()?['revenue'] as num?)?.toInt() ?? 0) + receipt.sum,
          'checks': ((eSnap.data()?['checks'] as num?)?.toInt() ?? 0) + 1,
        });
      }
      // Mijoz bonus/totalSpent
      if (cliSnap != null && cliSnap.exists) {
        final bonus = (cliSnap.data()?['bonus'] as num?)?.toInt() ?? 0;
        final spent = (cliSnap.data()?['totalSpent'] as num?)?.toInt() ?? 0;
        tx.update(cliRef!, {
          'bonus': bonus - bonusSpent + bonusEarned,
          'totalSpent': spent + receipt.sum,
        });
      }
      // Ingredient qoldig'i (retsept bo'yicha)
      for (var i = 0; i < iRefs.length; i++) {
        final snap = iSnaps[i];
        if (snap.exists) {
          final st = (snap.data()?['stock'] as num?)?.toDouble() ?? 0;
          final v = st - iRefs[i].amount;
          tx.update(iRefs[i].ref, {'stock': v < 0 ? 0 : v});
        }
      }
    });
  }
}
