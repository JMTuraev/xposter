/// Raqam formatlash: `2 480 000` (probel minglik ajratgich).
String groupNum(num value, {int decimals = 0}) {
  final neg = value < 0;
  final v = value.abs();
  final fixed = v.toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final intPart = parts[0];
  final buf = StringBuffer();
  for (int i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(' ');
    buf.write(intPart[i]);
  }
  var out = buf.toString();
  if (decimals > 0) out = '$out,${parts[1]}';
  return neg ? '−$out' : out;
}

/// Summa + valyuta: `2 480 000 сум` (prototip: kichik harf, uzilmas probel).
String sum(num value, {int decimals = 0}) =>
    '${groupNum(value, decimals: decimals)} сум';

/// Belgili summa: `+2 350 000 СУМ` / `−500 000 СУМ`.
String signedSum(num value) {
  final s = sum(value.abs());
  if (value > 0) return '+$s';
  if (value < 0) return '−$s';
  return s;
}

/// Miqdor (kg/l uchun kasrli): `19,7` yoki `46`.
String qty(num value) {
  if (value == value.roundToDouble()) return groupNum(value);
  return groupNum(value, decimals: value.toString().split('.')[1].length.clamp(1, 3));
}

// ── Ruscha sana (prototip: toLocaleDateString ru-RU) ──
const _ruWeekdayFull = ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'];
const _ruMonthGen = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
// getDay(): 0=Вс. Flutter weekday: 1=Пн..7=Вс.
const _ruWeekdayShort = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
const _ruMonthShort = ['янв', 'фев', 'мар', 'апр', 'мая', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];

/// `Воскресенье, 5 июля` — hafta kuni + kun + oy (bosh harf katta).
String ruDateLong(DateTime d) => '${_ruWeekdayFull[d.weekday - 1]}, ${d.day} ${_ruMonthGen[d.month - 1]}';

/// `Пн` — grafik uchun hafta kuni qisqartmasi.
String ruWeekdayShort(DateTime d) => _ruWeekdayShort[d.weekday - 1];

/// `5 июл` — grafik uchun kun + oy qisqartmasi.
String ruDayMonthShort(DateTime d) => '${d.day} ${_ruMonthShort[d.month - 1]}';

/// Ruscha plural: `1 день / 2 дня / 5 дней`.
String ruDays(int n) {
  final a = n % 10, b = n % 100;
  if (a == 1 && b != 11) return '$n день';
  if (a >= 2 && a <= 4 && (b < 10 || b >= 20)) return '$n дня';
  return '$n дней';
}
