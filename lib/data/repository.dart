import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../utils/pin_hash.dart';
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
      // MUHIM (HOLAT-16 audit): owner uchun `me` ni SINTEZ QILMAYMIZ —
      // haqiqiy employees/{uid} hujjatini o'qiymiz (provision uni yaratadi).
      // Sintez qilinganda pin/pinHash bo'sh, id=0, revenue=0 bo'lardi va
      // profil tahriri (`saveEmployee` to'liq set) owner'ning PIN hash'i va
      // statistikasini o'chirib yuborardi.
      Employee me;
      Map<String, dynamic>? empData;
      try {
        empData = (await db.employees(cafeId).doc(uid).get()).data();
      } catch (_) {}
      if (empData != null) {
        me = employeeFromMap(empData)..uid = uid;
      } else {
        me = Employee(
          id: 0,
          name: (ownerDoc.data()?['name'] as String?) ?? 'Owner',
          role: Roles.owner,
          pin: '',
          phone: '',
          login: emailFallback ?? (ownerDoc.data()?['email'] as String?),
          uid: uid,
          active: true,
        );
      }
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
      _listen<TxItem>(db.transactions(cafeId), txFromMap, app.transactions,
          orderByDesc: 'id', setId: (t, id) => t.docId = id),
      _listenReceipts(cafeId),
      _listen<Supply>(db.supplies(cafeId), supplyFromMap, app.supplies, orderByDesc: 'id'),
      _listen<Hall>(db.halls(cafeId), hallFromMap, app.halls),
      _listen<RestTable>(db.tables(cafeId), tableFromMap, app.tables),
      _listenEmployees(cafeId),
      _listenStorages(cafeId),
      _listenOpenChecks(cafeId),
      _listenShifts(cafeId),
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
    // JONLI kuzatuv: paidUntil/trialUntil o'zgarsa obuna bloki darhol
    // ko'tariladi/tushadi (masalan, to'lovdan keyin admin muddatni uzaytirsa).
    _subs.add(db.cafe(cafeId).snapshots().listen((s) {
      final d = s.data();
      if (d == null) return;
      app.applyCafe(cafeFromMap(cafeId, d));
      app.notify();
    }, onError: (_) {}));
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
    void Function(T, String)? setId,
  }) {
    Query<Map<String, dynamic>> q = col;
    if (orderByDesc != null) q = q.orderBy(orderByDesc, descending: true);
    final first = Completer<void>();
    _subs.add(q.snapshots().listen((snap) {
      target
        ..clear()
        ..addAll(snap.docs.map((d) {
          final item = fromMap(d.data());
          if (setId != null) setId(item, d.id);
          return item;
        }));
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

  /// Chek arxivi. Generic `_listen` dan farqi: har chekka Firestore hujjat
  /// kalitini (`docId`) biriktiradi. Yangi cheklar auto-ID bilan yoziladi —
  /// vozvrat/qayta yozish doim docId orqali boradi, `id` (ko'rsatiladigan raqam)
  /// to'qnashsa ham hujjatlar ustma-ust tushmaydi.
  Future<void> _listenReceipts(String cafeId) {
    final first = Completer<void>();
    _subs.add(db.receipts(cafeId).orderBy('id', descending: true).snapshots().listen((snap) {
      app.receiptsArchive
        ..clear()
        ..addAll(snap.docs.map((d) {
          final r = receiptFromMap(d.data());
          r.docId = d.id;
          return r;
        }));
      app.recomputeStatsFromReceipts();
      app.notify();
      if (!first.isCompleted) first.complete();
    }, onError: (_) {
      if (!first.isCompleted) first.complete();
    }));
    return first.future;
  }

  /// Ochiq cheklar (stollardagi buyurtmalar). Xom Map ro'yxati AppState'da
  /// saqlanadi; KassaController uni o'z `checks` ro'yxati bilan birlashtiradi.
  /// docId `_docId` kaliti bilan qo'shib qo'yiladi.
  Future<void> _listenOpenChecks(String cafeId) {
    final first = Completer<void>();
    _subs.add(db.openChecks(cafeId).snapshots().listen((snap) {
      app.openCheckDocs
        ..clear()
        ..addAll(snap.docs.map((d) => {...d.data(), '_docId': d.id}));
      app.openChecksLoaded = true;
      app.openChecksRev++;
      app.notify();
      if (!first.isCompleted) first.complete();
    }, onError: (_) {
      if (!first.isCompleted) first.complete();
    }));
    return first.future;
  }

  /// Kassa smenalari: ochiq smena + yopilganlar arxivi (HOLAT-17,
  /// xposterwin'dagi bilan bir xil). Shu listener tufayli Windows'da ochilgan
  /// smena android'da ham ko'rinadi va android savdosi Z-otchetga tushadi.
  Future<void> _listenShifts(String cafeId) {
    final first = Completer<void>();
    _subs.add(db.shifts(cafeId).orderBy('id', descending: true).snapshots().listen((snap) {
      final all = snap.docs.map((d) => shiftFromMap(d.data())).toList();
      app.shiftsArchive
        ..clear()
        ..addAll(all.where((s) => !s.isOpen));
      final open = all.where((s) => s.isOpen).toList();
      app.currentShift = open.isEmpty ? null : open.first;
      app.notify();
      if (!first.isCompleted) first.complete();
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
    // Ochiq cheklar boshqa kafega «ergashib» ketmasin.
    app.openCheckDocs.clear();
    app.openChecksLoaded = false;
    app.openChecksRev++;
    // Smena holati ham eski kafedan qolmasin.
    app.currentShift = null;
    app.shiftsArchive.clear();
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

  /// Rasm (bytes) ni Firebase Storage'ga yuklaydi va download URL qaytaradi.
  /// `putData` bytes bilan ishlaydi — web'da ham, native'da ham (dart:io kerak
  /// emas). URL Firestore'ga yozilganda IKKALA ilova (Android+Windows) uni
  /// `Image.network` bilan ko'rsatadi — ilgari lokal fayl yo'li saqlanardi va
  /// boshqa qurilmада ko'rinmasdi. null = yuklanmadi (fallback: lokal yo'l).
  Future<String?> uploadImageBytes(Uint8List bytes) async {
    if (_c == null) return null;
    try {
      final ref = FirebaseStorage.instance
          .ref('cafes/$_c/products/${DateTime.now().microsecondsSinceEpoch}.jpg');
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      return await ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  Future<void> saveIngredient(Ingredient i) async {
    if (_c == null) return;
    await db.ingredients(_c!).doc(i.id.toString()).set(ingredientToMap(i));
  }

  /// K3: qoldiqni DELTA bilan (increment) yozadi — postavka(+)/spisaniye(-)/
  /// pererabotka/vozvrat. Absolyut `saveIngredient` faqat inventarizatsiya
  /// (recount, kafe yopiq) va ingredient tahriri uchun.
  Future<void> adjustIngredientStock(int id, num delta) async {
    if (_c == null || delta == 0) return;
    await db.ingredients(_c!).doc(id.toString()).set(
        {'stock': FieldValue.increment(delta)}, SetOptions(merge: true));
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

  /// Y-4: mijoz bonus/totalSpent/debt ni DELTA (increment) bilan yozadi — vozvrat.
  /// Absolyut `saveClient` concurrent sotuv increment'ini bosmasin.
  Future<void> adjustClient(int id, {int bonusDelta = 0, int totalSpentDelta = 0, int debtDelta = 0}) async {
    if (_c == null) return;
    final data = <String, dynamic>{};
    if (bonusDelta != 0) data['bonus'] = FieldValue.increment(bonusDelta);
    if (totalSpentDelta != 0) data['totalSpent'] = FieldValue.increment(totalSpentDelta);
    if (debtDelta != 0) data['debt'] = FieldValue.increment(debtDelta);
    if (data.isEmpty) return;
    await db.clients(_c!).doc(id.toString()).set(data, SetOptions(merge: true));
  }

  Future<void> saveAccount(Account a) async {
    if (_c == null) return;
    await db.accounts(_c!).doc(a.id.toString()).set(accountToMap(a));
  }

  /// K3: balansni DELTA bilan (FieldValue.increment) yozadi — absolyut `set`
  /// concurrent sotuvni bosib ketmasin (lost update). `saveAccount` faqat
  /// hisob yaratish/nomlash uchun; balans o'zgarishi doim shu yo'l bilan.
  Future<void> adjustAccountBalance(int id, num delta) async {
    if (_c == null || delta == 0) return;
    await db.accounts(_c!).doc(id.toString()).set(
        {'balance': FieldValue.increment(delta)}, SetOptions(merge: true));
  }

  Future<void> saveTransaction(TxItem t) async {
    if (_c == null) return;
    // K2: hujjat kaliti = auto-ID (receipts kabi). Ilgari `doc(t.id)` edi —
    // ikki qurilma bir xil lokal `id` hisoblab bitta hujjatni ustma-ust
    // yozardi va bitta savdo moliya jurnalidan yo'qolardi. Endi har yozuv
    // o'z docId'siga tushadi.
    final ref = t.docId != null ? db.transactions(_c!).doc(t.docId) : db.transactions(_c!).doc();
    t.docId = ref.id;
    // createdAt — vaqt bo'yicha moliyaviy hisobotlar/agregatsiya uchun (§4).
    await ref.set(
      {...txToMap(t), 'createdAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  Future<void> saveReceipt(Receipt r) async {
    if (_c == null) return;
    // Yangi cheklar auto-ID bilan yoziladi; eski (migratsiyagacha) cheklarda
    // docId listener'dan raqamli string bo'lib keladi — ikkalasi ham shu yo'ldan.
    final ref = r.docId != null ? db.receipts(_c!).doc(r.docId) : db.receipts(_c!).doc();
    r.docId = ref.id;
    await ref.set(
      {...receiptToMap(r), 'createdAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  // ─────────────────────────── Ochiq cheklar (openChecks) ───────────────────────────

  /// Yangi ochiq chek uchun Firestore auto-ID (lokal, tarmoqsiz yaratiladi).
  String? newOpenCheckId() => _c == null ? null : db.openChecks(_c!).doc().id;

  /// Ochiq chekni to'liq yozish (write-through, debounce KassaController'da).
  /// `set` merge'siz — pozitsiya o'chirilgani ham aks etsin.
  Future<void> saveOpenCheckRaw(String docId, Map<String, dynamic> data) async {
    if (_c == null) return;
    await db.openChecks(_c!).doc(docId)
        .set({...data, 'updatedAt': FieldValue.serverTimestamp()});
  }

  /// To'langan / bekor qilingan chekni o'chirish.
  Future<void> deleteOpenCheck(String docId) async {
    if (_c == null) return;
    await db.openChecks(_c!).doc(docId).delete();
  }

  /// «Закрыть без оплаты» audit izi (№5) — o'zgarmas jurnal, auto-ID.
  /// Rules faqat create'ga ruxsat beradi: kassir yozadi, hech kim o'zgartirmaydi.
  Future<void> saveVoidedCheck(Map<String, dynamic> data) async {
    if (_c == null) return;
    await db.voidedChecks(_c!).add({...data, 'voidedAt': FieldValue.serverTimestamp()});
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

  /// Kafe hujjatini SERVERDAN majburan o'qiydi — blok ekranidagi
  /// «Проверить оплату» (kesh emas, aynan server holati kerak).
  Future<void> refreshCafeFromServer() async {
    if (_c == null) return;
    final snap = await db.cafe(_c!).get(const GetOptions(source: Source.server));
    final d = snap.data();
    if (d == null) return;
    app.applyCafe(cafeFromMap(_c!, d));
    app.notify();
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

  /// Kassa smenasi (id maydoni bilan) — doc id = id. Ochish va yopishda yoziladi.
  /// (HOLAT-17: xposterwin bilan bir xil.)
  Future<void> saveShiftRaw(Map<String, dynamic> s) async {
    if (_c == null) return;
    await db.shifts(_c!).doc(s['id'].toString()).set(s, SetOptions(merge: true));
  }

  /// Har sotuvda ochiq smena ko'rsatkichlarini oshirish.
  /// `increment` ishlatiladi (absolyut qiymat emas) — bir smenada ikki kassa
  /// bir vaqtda sotsa ham hech bir chek yo'qolmaydi (last-write-wins bo'lmaydi).
  Future<void> addShiftSale(
    int shiftId, {
    required int revenue,
    required int profit,
    required int cash,
    required int card,
    required int bonus,
    required int debt,
  }) async {
    if (_c == null) return;
    await db.shifts(_c!).doc(shiftId.toString()).set({
      'revenue': FieldValue.increment(revenue),
      'profit': FieldValue.increment(profit),
      'checks': FieldValue.increment(1),
      'cash': FieldValue.increment(cash),
      'card': FieldValue.increment(card),
      'bonus': FieldValue.increment(bonus),
      'debt': FieldValue.increment(debt),
    }, SetOptions(merge: true));
  }

  /// Qarz naqd qaytarilganda — ochiq smenaning naqd kirimi (increment).
  Future<void> addShiftDebtRepaid(int shiftId, int amount) async {
    if (_c == null) return;
    await db.shifts(_c!).doc(shiftId.toString()).set(
      {'debtRepaid': FieldValue.increment(amount)},
      SetOptions(merge: true),
    );
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
    // PIN serverga OCHIQ MATNDA YUBORILMAYDI — client hash'lab beradi
    // (functions/index.js pinHash/pinSalt ni hujjatga yozadi, pin: '').
    final salt = pin.isEmpty ? null : newPinSalt();
    await callable.call({
      'cafeId': _c,
      'login': login,
      'password': password,
      'name': name,
      'role': role,
      'phone': phone,
      'pinSalt': salt,
      'pinHash': salt == null ? null : hashPin(salt, pin),
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

  /// Foydalanuvchi O'Z akkauntini va barcha ma'lumotini o'chiradi
  /// (Google Play "Account deletion" talabi). Owner → butun kafe(lar);
  /// xodim → faqat o'zi. cafeId server tomonda uid orqali aniqlanadi.
  Future<void> deleteAccount() async {
    final callable = _fns.httpsCallable('deleteAccount');
    await callable.call(<String, dynamic>{});
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
    // Sinov endi 7 KUN va SERVER vaqtidan (`createdAt` = serverTimestamp;
    // rules `createdAt == request.time` talab qiladi) — kalendar firibi o'tmaydi.
    final trialEnds = DateTime.now().add(const Duration(days: 7)).toIso8601String().substring(0, 10);
    await cafeRef.set({
      ...cafeToMap(Cafe(
        id: cafeId,
        ownerUid: uid,
        name: cafeName,
        spot: '$cafeName — Центр',
        trialEndsAt: trialEnds,
        subscriptionStatus: 'trial',
      )),
      'createdAt': FieldValue.serverTimestamp(),
    });
    // Owner ham employees ichida (POS PIN almashinuvi uchun) — har cafeda o'z uid'i bilan.
    // PIN darhol hash'lanadi (HOLAT-16).
    final ownerEmp = Employee(
      id: 1, name: ownerName, role: Roles.owner, pin: '', phone: '',
      login: email, uid: uid, active: true,
    )..setPin(ownerPin);
    await db.employees(cafeId).doc(uid).set(employeeToMap(ownerEmp));
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

  /// To'lovni Firestore'ga ATOMIK yozadi (§5):
  /// receipt + account.balance + employee stats + client bonus/qarz + ingredient stock.
  ///
  /// `runTransaction` EMAS, `WriteBatch` + `FieldValue.increment` ishlatiladi:
  ///   • **Oflayn ishlaydi** — `runTransaction` serverni talab qiladi, internet
  ///     uzilganda savdo umuman yozilmasdan qolardi (faqat chek fallback'da saqlanardi).
  ///   • Windows POS (xposterwin) bilan bir xil kod yo'li — u yerda `runTransaction`
  ///     Flutter engine'ini qulatadi (platform-kanal thread-safe emas).
  ///   • Delta yozuv (`increment`) ikki qurilma bir vaqtda sotganda ham to'g'ri
  ///     yig'iladi; absolyut qiymatda oxirgi yozuv oldingisini yeb qo'yardi.
  ///
  /// Hujjat mavjudligini `app` ro'yxatlaridan bilamiz — `set(merge:true)` bo'sh
  /// hujjat yaratib qo'ymaydi.
  Future<void> completePayment({
    required Receipt receipt,
    required int cashAmount,
    int cardAmount = 0,
    String? employeeUid,
    int? clientId,
    int bonusSpent = 0,
    int bonusEarned = 0,
    int debtAdded = 0,
    List<({int ingredientId, double amount})> stockDeltas = const [],
  }) async {
    if (_c == null) return;
    final c = _c!;
    final batch = db.fs.batch();

    // Receipt — AUTO-ID hujjat. Avval doc kaliti `receipt.id` edi: ikki qurilma
    // bir vaqtda sotsa ikkalasi ham `receipts/{N}` ga yozib, bitta TO'LANGAN
    // savdo yo'qolardi. Endi kalit auto-ID, `id` esa faqat ko'rsatiladigan raqam.
    final rRef = receipt.docId != null
        ? db.receipts(c).doc(receipt.docId)
        : db.receipts(c).doc();
    receipt.docId = rRef.id;
    batch.set(rRef, {...receiptToMap(receipt), 'createdAt': FieldValue.serverTimestamp()});

    // Mavjudlik tekshiruvi shart: hujjat yo'q bo'lsa `merge` uni faqat
    // `{balance: N}` bilan yaratardi va `accountFromMap` listener ichida qulardi.
    if (cashAmount != 0 && app.accounts.any((a) => a.id == 1)) {
      batch.set(db.accounts(c).doc('1'),
          {'balance': FieldValue.increment(cashAmount)}, SetOptions(merge: true));
    }
    // O-1: karta (безнал) savdosi bank hisobi balansiga tushsin (ilgari faqat
    // naqd yozilardi — «Счета»da bank qoldig'i 0 turib, jurnal bilan zid edi).
    if (cardAmount != 0) {
      final bank = app.accounts.where((a) => a.type == 'Безналичный счет').toList();
      if (bank.isNotEmpty) {
        batch.set(db.accounts(c).doc(bank.first.id.toString()),
            {'balance': FieldValue.increment(cardAmount)}, SetOptions(merge: true));
      }
    }

    if (employeeUid != null && app.employees.any((e) => e.uid == employeeUid)) {
      batch.set(db.employees(c).doc(employeeUid), {
        'revenue': FieldValue.increment(receipt.sum),
        'checks': FieldValue.increment(1),
      }, SetOptions(merge: true));
    }

    if (clientId != null && app.clients.any((x) => x.id == clientId)) {
      final bonusDelta = bonusEarned - bonusSpent;
      batch.set(db.clients(c).doc(clientId.toString()), {
        'totalSpent': FieldValue.increment(receipt.sum),
        if (bonusDelta != 0) 'bonus': FieldValue.increment(bonusDelta),
        if (debtAdded != 0) 'debt': FieldValue.increment(debtAdded),
      }, SetOptions(merge: true));
    }

    // Manfiy qoldiq nolga qirqilmaydi — yetishmovchilikni ko'rsatadi.
    for (final d in stockDeltas) {
      if (!app.ingredients.any((i) => i.id == d.ingredientId)) continue;
      batch.set(db.ingredients(c).doc(d.ingredientId.toString()),
          {'stock': FieldValue.increment(-d.amount)}, SetOptions(merge: true));
    }

    await batch.commit();
  }
}
