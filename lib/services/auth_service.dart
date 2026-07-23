import 'package:firebase_auth/firebase_auth.dart';

/// Firebase Authentication qatlami (BACKEND-TAYYORGARLIK.md §6, §12).
///
/// - Owner: email + parol (email tasdiqlash bilan).
/// - Xodim: owner bergan login/parol → sintetik email
///   ({login}@{cafeId}.buxoropos.app) orqali Firebase Auth.
/// - PIN: POS'da tez almashinuv uchun (lokal, AppState'da) — bu qatlamda emas.
class AuthService {
  AuthService([FirebaseAuth? auth]) : _auth = auth ?? FirebaseAuth.instance;
  final FirebaseAuth _auth;

  User? get currentUser => _auth.currentUser;
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Xodim login'ini Firebase Auth uchun sintetik email'ga aylantiradi.
  static String employeeEmail(String login, String cafeId) {
    final safe = login.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9._-]'), '');
    return '$safe@$cafeId.buxoropos.app';
  }

  // ── Owner ──

  /// Owner ro'yxatdan o'tadi va tasdiqlash xatini oladi.
  Future<UserCredential> registerOwner(String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await cred.user?.sendEmailVerification();
    return cred;
  }

  Future<UserCredential> signInOwner(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
  }

  Future<void> sendEmailVerification() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  Future<void> reload() => _auth.currentUser?.reload() ?? Future.value();

  // ── Xodim ──

  /// Xodim owner bergan login/parol bilan kiradi (cafeId bo'yicha).
  Future<UserCredential> signInEmployee(String login, String cafeId, String password) {
    return _auth.signInWithEmailAndPassword(
      email: employeeEmail(login, cafeId),
      password: password,
    );
  }

  /// Xodim o'z parolini o'zgartiradi (§12.4).
  Future<void> updatePassword(String newPassword) async {
    await _auth.currentUser?.updatePassword(newPassword);
  }

  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// SERVER vaqti (taxminan, ±soniyalar): ID token majburan yangilanganda
  /// Firebase qaytargan `issuedAtTime`. Lokal soat buzilgan bo'lsa ham server
  /// o'z vaqtini beradi — obuna gate shu bilan to'g'rilanadi.
  Future<DateTime?> fetchServerTime() async {
    try {
      final u = _auth.currentUser;
      if (u == null) return null;
      final r = await u.getIdTokenResult(true);
      return r.issuedAtTime;
    } catch (_) {
      return null;
    }
  }

  Future<void> signOut() => _auth.signOut();
}
