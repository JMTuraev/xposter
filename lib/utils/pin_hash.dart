import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// PIN hash (HOLAT-16). Sxema: `employees/{uid}.pinHash` + `pinSalt`.
///
/// ⚠️ BU FAYL IKKALA LOYIHADA AYNAN BIR XIL (BACKEND.md Qoida 2) va
/// `buxoro_pos/functions/index.js` hamda migratsiya skriptidagi node
/// implementatsiyasi bilan BIT-BA-BIT mos bo'lishi SHART:
///   h = sha256(utf8("<salt>:<pin>"))
///   999 marta: h = sha256(h)
///   pinHash = hex(h)
///
/// Nega client-side tekshiruv: kassa oflayn ham ochilishi kerak, PIN ekrani
/// barcha xodimlarni lokal solishtiradi. Qabul qilingan cheklov: a'zo
/// pinHash'ni o'qiy oladi va 4 xonali PIN maydonini oflayn brute-force
/// qilishi nazariy mumkin — lekin bu ochiq matndan beqiyos yaxshi
/// (1000 iteratsiya arzon urinishlarni ham sekinlashtiradi).
///
/// PIN'ni salt bilan hash'lash (1000 × SHA-256).
String hashPin(String salt, String pin) {
  var d = sha256.convert(utf8.encode('$salt:$pin')).bytes;
  for (var i = 1; i < 1000; i++) {
    d = sha256.convert(d).bytes;
  }
  return d.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Yangi tasodifiy salt (16 bayt, hex).
String newPinSalt() {
  final r = Random.secure();
  return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}
