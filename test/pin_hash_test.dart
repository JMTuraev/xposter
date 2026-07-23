import 'package:flutter_test/flutter_test.dart';
import 'package:buxoro_pos/utils/pin_hash.dart';

void main() {
  // Etalon vektor python (hashlib) bilan hisoblangan; node migratsiya skripti
  // (_pinmig.js SELFTEST) ham aynan shu qiymatni chiqarishi SHART.
  test('hashPin node/python bilan bit-ba-bit mos', () {
    expect(
      hashPin('00', '1234'),
      'e63dfc79a012848f9559b045b5eea96ca00689925e702f4ffc2e186ce9f1eae6',
    );
  });

  test('salt har xil bo\'lsa hash har xil', () {
    expect(hashPin('aa', '1234') == hashPin('bb', '1234'), isFalse);
  });

  test('newPinSalt 32 belgi hex va takrorlanmas', () {
    final a = newPinSalt(), b = newPinSalt();
    expect(a.length, 32);
    expect(RegExp(r'^[0-9a-f]+$').hasMatch(a), isTrue);
    expect(a == b, isFalse);
  });
}
