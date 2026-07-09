import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore kolleksiya yo'llari (BACKEND-TAYYORGARLIK.md §9, §12.3).
///
/// Struktura (multi-tenant):
///   owners/{ownerUid}
///   cafes/{cafeId}
///   cafes/{cafeId}/employees/{uid}
///   cafes/{cafeId}/{categories|products|ingredients|suppliers|clientGroups|
///                   clients|accounts|financeCategories|transactions|receipts|
///                   supplies|wastes|inventories|processings|promotions|
///                   halls|tables|storages|stats}
class Db {
  Db(this.fs);
  final FirebaseFirestore fs;

  CollectionReference<Map<String, dynamic>> get owners => fs.collection('owners');
  DocumentReference<Map<String, dynamic>> owner(String uid) => owners.doc(uid);

  CollectionReference<Map<String, dynamic>> get cafes => fs.collection('cafes');
  DocumentReference<Map<String, dynamic>> cafe(String cafeId) => cafes.doc(cafeId);

  /// «Код заведения» → cafeId (xodim kirishi; ochiq o'qiladi).
  CollectionReference<Map<String, dynamic>> get cafeCodes => fs.collection('cafeCodes');

  CollectionReference<Map<String, dynamic>> sub(String cafeId, String name) =>
      cafe(cafeId).collection(name);

  // Qulaylik uchun nomli getterlar.
  CollectionReference<Map<String, dynamic>> employees(String c) => sub(c, 'employees');
  CollectionReference<Map<String, dynamic>> categories(String c) => sub(c, 'categories');
  CollectionReference<Map<String, dynamic>> products(String c) => sub(c, 'products');
  CollectionReference<Map<String, dynamic>> ingredients(String c) => sub(c, 'ingredients');
  CollectionReference<Map<String, dynamic>> suppliers(String c) => sub(c, 'suppliers');
  CollectionReference<Map<String, dynamic>> clientGroups(String c) => sub(c, 'clientGroups');
  CollectionReference<Map<String, dynamic>> clients(String c) => sub(c, 'clients');
  CollectionReference<Map<String, dynamic>> accounts(String c) => sub(c, 'accounts');
  CollectionReference<Map<String, dynamic>> transactions(String c) => sub(c, 'transactions');
  CollectionReference<Map<String, dynamic>> receipts(String c) => sub(c, 'receipts');
  CollectionReference<Map<String, dynamic>> supplies(String c) => sub(c, 'supplies');
  CollectionReference<Map<String, dynamic>> wastes(String c) => sub(c, 'wastes');
  CollectionReference<Map<String, dynamic>> inventories(String c) => sub(c, 'inventories');
  CollectionReference<Map<String, dynamic>> processings(String c) => sub(c, 'processings');
  CollectionReference<Map<String, dynamic>> promotions(String c) => sub(c, 'promotions');
  CollectionReference<Map<String, dynamic>> halls(String c) => sub(c, 'halls');
  CollectionReference<Map<String, dynamic>> tables(String c) => sub(c, 'tables');
  CollectionReference<Map<String, dynamic>> storages(String c) => sub(c, 'storages');
  CollectionReference<Map<String, dynamic>> stats(String c) => sub(c, 'stats');
}
