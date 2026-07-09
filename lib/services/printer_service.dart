import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/format.dart';

/// Topilgan printer (mDNS nomi bilan yoki oddiy IP).
class PrinterDevice {
  final String ip;
  final int port;
  final String name;   // mDNS'dan model nomi yoki «Принтер»
  final String source; // 'mdns' | 'scan' | 'manual'
  const PrinterDevice({required this.ip, this.port = 9100, this.name = 'Принтер', this.source = 'scan'});

  @override
  bool operator ==(Object o) => o is PrinterDevice && o.ip == ip;
  @override
  int get hashCode => ip.hashCode;
}

/// Chekning bitta qatori (mahsulot).
class ReceiptLine {
  final String name;
  final double qty;
  final int price; // dona narxi
  ReceiptLine({required this.name, required this.qty, required this.price});
  int get total => (price * qty).round();
}

/// Chop etiladigan chek ma'lumotlari (UI'dan uzilgan — sof data).
class ReceiptData {
  final String venue;
  final String? address;
  final String checkNo;
  final String cashier;
  final String dateTime;
  final List<ReceiptLine> items;
  final int subtotal;
  final String? discountLabel;
  final int discountAmount;
  final String? serviceLabel;
  final int serviceAmount;
  final int total;
  final String paymentLabel;
  final String footer;

  ReceiptData({
    required this.venue,
    this.address,
    required this.checkNo,
    required this.cashier,
    required this.dateTime,
    required this.items,
    required this.subtotal,
    this.discountLabel,
    this.discountAmount = 0,
    this.serviceLabel,
    this.serviceAmount = 0,
    required this.total,
    required this.paymentLabel,
    this.footer = 'Рахмат! Спасибо!',
  });
}

/// WiFi termal printer (ESC/POS) xizmati: discovery + chek generatsiya + TCP socket.
/// Drayver KERAK EMAS — to'g'ridan-to'g'ri 9100-portga yoziladi.
class PrinterService {
  PrinterService._();
  static final PrinterService instance = PrinterService._();

  static const int kPort = 9100;
  static const String _kIpKey = 'printer_ip';
  static const String _kPaperKey = 'printer_paper_mm';

  /// Android MulticastLock kanali (mDNS uchun; iOS'da e'tiborsiz qoladi).
  static const MethodChannel _multicast = MethodChannel('xposter/printer_multicast');
  Future<void> _acquireMulticast() async {
    try { await _multicast.invokeMethod('acquire'); } catch (_) {}
  }
  Future<void> _releaseMulticast() async {
    try { await _multicast.invokeMethod('release'); } catch (_) {}
  }

  // ─────────────────────── Saqlash ───────────────────────
  Future<String?> savedIp() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kIpKey);
  }

  Future<int> savedPaperMm() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_kPaperKey) ?? 80;
  }

  Future<void> savePrinter(String ip, {int paperMm = 80}) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kIpKey, ip);
    await p.setInt(_kPaperKey, paperMm);
  }

  Future<void> clearPrinter() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kIpKey);
  }

  // ─────────────────────── Discovery ───────────────────────

  /// Termal/tarmoq printerlari e'lon qiladigan mDNS servis turlari.
  static const _mdnsServices = <String>[
    '_pdl-datastream._tcp.local', // RAW / JetDirect (port 9100) — ESC/POS termal
    '_printer._tcp.local',        // LPR/LPD
    '_ipp._tcp.local',            // IPP (ko'p tarmoq printerlari)
  ];

  Future<String?> _deviceIp() async {
    try {
      final ip = await NetworkInfo().getWifiIP();
      if (ip != null && ip.contains('.') && !ip.startsWith('0.') && !ip.startsWith('127.')) return ip;
    } catch (_) {}
    try {
      final ifaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
      // Avval WiFi/simsiz interfeyslarni afzal ko'ramiz.
      for (final pref in [true, false]) {
        for (final iface in ifaces) {
          final isWifi = iface.name.toLowerCase().contains(RegExp(r'wlan|wifi|wl'));
          if (isWifi != pref) continue;
          for (final addr in iface.addresses) {
            final a = addr.address;
            if (a.startsWith('192.168.') || a.startsWith('10.') || a.startsWith('172.')) return a;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Bitta hostni 9100-portda tekshiradi (TCP connect).
  Future<bool> _probe(String host, {Duration timeout = const Duration(milliseconds: 600)}) async {
    Socket? s;
    try {
      s = await Socket.connect(host, kPort, timeout: timeout);
      return true;
    } catch (_) {
      return false;
    } finally {
      s?.destroy();
    }
  }

  /// ── mDNS/Bonjour orqali printer qidirish (eng ishonchli va tez) ──
  /// Printerlar o'zini shu orqali e'lon qiladi — subnet skaneriga qaraganda
  /// ancha tez va aniq. `timeout` ichida topilganini qaytaradi.
  Future<List<PrinterDevice>> _discoverMdns({Duration timeout = const Duration(seconds: 4)}) async {
    final out = <String, PrinterDevice>{};
    MDnsClient? client;
    await _acquireMulticast(); // Android: WiFi multicast'ni ochamiz (busiz mDNS jim)
    try {
      client = MDnsClient(rawDatagramSocketFactory:
          (dynamic host, int port, {bool? reuseAddress, bool? reusePort, int? ttl}) {
        return RawDatagramSocket.bind(host, port, reuseAddress: true, reusePort: false, ttl: ttl ?? 255);
      });
      await client.start();
      final deadline = DateTime.now().add(timeout);

      for (final svc in _mdnsServices) {
        if (DateTime.now().isAfter(deadline)) break;
        try {
          await for (final ptr in client
              .lookup<PtrResourceRecord>(ResourceRecordQuery.serverPointer(svc))
              .timeout(const Duration(milliseconds: 1400), onTimeout: (sink) => sink.close())) {
            // Servis nomidan model nomini ajratamiz ("EPSON TM-T20._pdl...local" → "EPSON TM-T20").
            final label = ptr.domainName.split('.').first.replaceAll(RegExp(r'\\032'), ' ').trim();
            await for (final srv in client
                .lookup<SrvResourceRecord>(ResourceRecordQuery.service(ptr.domainName))
                .timeout(const Duration(milliseconds: 900), onTimeout: (sink) => sink.close())) {
              await for (final a in client
                  .lookup<IPAddressResourceRecord>(ResourceRecordQuery.addressIPv4(srv.target))
                  .timeout(const Duration(milliseconds: 900), onTimeout: (sink) => sink.close())) {
                final ip = a.address.address;
                // IPP/LPR standart portlari bo'lsa ham, ESC/POS uchun 9100'ni ishlatamiz.
                out[ip] = PrinterDevice(ip: ip, name: label.isEmpty ? 'Принтер' : label, source: 'mdns');
              }
            }
          }
        } catch (_) {/* bitta servis turi topilmasa — davom */}
      }
    } catch (_) {/* mDNS umuman ishlamasa — skanerga tayanamiz */}
    finally {
      client?.stop();
      await _releaseMulticast();
    }
    return out.values.toList();
  }

  /// ── Subnet (/24) skaneri: bardoshli, cheklangan parallellik bilan ──
  /// 254 ta socketni BIR VAQTDA emas, ~40 talik to'plamlarda ochamiz —
  /// aks holda Android socket limitiga urилиб ko'p printer «topilmay» qolardi.
  Future<List<PrinterDevice>> _discoverScan({
    required String prefix,
    void Function(double progress)? onProgress,
  }) async {
    const batch = 40;
    final found = <PrinterDevice>[];
    var done = 0;
    for (var start = 1; start <= 254; start += batch) {
      final end = (start + batch - 1).clamp(1, 254);
      final futures = <Future<void>>[];
      for (var i = start; i <= end; i++) {
        final host = '$prefix.$i';
        futures.add(_probe(host).then((ok) {
          if (ok) found.add(PrinterDevice(ip: host, source: 'scan'));
        }).whenComplete(() {
          done++;
          onProgress?.call(done / 254);
        }));
      }
      await Future.wait(futures);
    }
    found.sort((a, b) => int.parse(a.ip.split('.').last).compareTo(int.parse(b.ip.split('.').last)));
    return found;
  }

  /// Printerlarni topadi: avval mDNS (tez+aniq), keyin subnet skaneri (zaxira).
  /// Ikkalasidan kelgan natijalar birlashtiriladi (mDNS nomi ustun turadi).
  Future<List<PrinterDevice>> discover({void Function(double progress)? onProgress}) async {
    final ip = await _deviceIp();
    if (ip == null) {
      throw const PrinterException(
          'Wi-Fi tarmog\'i aniqlanmadi. Qurilma Wi-Fi\'ga ulanganini tekshiring (mobil internet emas).');
    }
    final prefix = ip.substring(0, ip.lastIndexOf('.'));

    // 1) mDNS — birinchi 4 soniyada progress'ni 0→30% qilib ko'rsatamiz.
    onProgress?.call(0.02);
    final mdns = await _discoverMdns();
    onProgress?.call(0.30);

    // 2) Subnet skaneri — 30→100%.
    final scan = await _discoverScan(
      prefix: prefix,
      onProgress: (p) => onProgress?.call(0.30 + p * 0.70),
    );

    // Birlashtirish: mDNS nomli natijalar ustun (Map IP bo'yicha).
    final merged = <String, PrinterDevice>{};
    for (final d in scan) {
      merged[d.ip] = d;
    }
    for (final d in mdns) {
      merged[d.ip] = d; // mDNS versiyasi nomli — ustiga yozadi
    }
    final list = merged.values.toList()
      ..sort((a, b) {
        // mDNS-tasdiqlanganlar birinchi, keyin IP tartibi.
        if ((a.source == 'mdns') != (b.source == 'mdns')) return a.source == 'mdns' ? -1 : 1;
        return int.parse(a.ip.split('.').last).compareTo(int.parse(b.ip.split('.').last));
      });
    onProgress?.call(1.0);
    return list;
  }

  // ─────────────────────── Print ───────────────────────

  /// Chek baytlari. Avval Generator (CP866, kirill), agar yiqilsa —
  /// kafolatli lotin (translit) raw zaxira. Hech qachon exception tashlamaydi.
  Future<List<int>> _buildReceiptBytes(ReceiptData d, int paperMm) async {
    try {
      return await _buildViaGenerator(d, paperMm);
    } catch (_) {
      return _buildRawReceipt(d, paperMm); // zaxira — lotin transliteratsiya
    }
  }

  /// Asosiy yo'l: esc_pos_utils_plus Generator + CP866 (kirill).
  /// Matn CP866'ga tozalanadi («»→", emoji olib tashlanadi).
  Future<List<int>> _buildViaGenerator(ReceiptData d, int paperMm) async {
    final profile = await CapabilityProfile.load();
    final gen = Generator(paperMm == 58 ? PaperSize.mm58 : PaperSize.mm80, profile);
    final bytes = <int>[];
    bytes.addAll(gen.reset()); // ESC @ init
    bytes.addAll(gen.setGlobalCodeTable('CP866'));

    const cp = PosStyles(codeTable: 'CP866');
    const cpRight = PosStyles(codeTable: 'CP866', align: PosAlign.right);
    const cpCenter = PosStyles(codeTable: 'CP866', align: PosAlign.center);
    const cpBig = PosStyles(codeTable: 'CP866', align: PosAlign.center, height: PosTextSize.size2, width: PosTextSize.size2, bold: true);
    const cpTotal = PosStyles(codeTable: 'CP866', bold: true, height: PosTextSize.size2, width: PosTextSize.size2);
    const cpTotalR = PosStyles(codeTable: 'CP866', align: PosAlign.right, bold: true, height: PosTextSize.size2, width: PosTextSize.size2);
    String s(String x) => _cp866Safe(x);

    bytes.addAll(gen.text(s(d.venue), styles: cpBig));
    if (d.address != null && d.address!.isNotEmpty) bytes.addAll(gen.text(s(d.address!), styles: cpCenter));
    bytes.addAll(gen.hr());
    bytes.addAll(gen.row([
      PosColumn(text: s('Чек ${d.checkNo}'), width: 6, styles: cp),
      PosColumn(text: s(d.dateTime), width: 6, styles: cpRight),
    ]));
    bytes.addAll(gen.text(s('Кассир: ${d.cashier}'), styles: cp));
    bytes.addAll(gen.hr());
    for (final it in d.items) {
      bytes.addAll(gen.text(s(it.name), styles: cp));
      final q = it.qty % 1 == 0 ? it.qty.toInt().toString() : it.qty.toString().replaceAll('.', ',');
      bytes.addAll(gen.row([
        PosColumn(text: '  $q x ${groupNum(it.price)}', width: 7, styles: cp),
        PosColumn(text: groupNum(it.total), width: 5, styles: cpRight),
      ]));
    }
    bytes.addAll(gen.hr());
    bytes.addAll(gen.row([
      PosColumn(text: s('Подытог'), width: 7, styles: cp),
      PosColumn(text: s(sum(d.subtotal)), width: 5, styles: cpRight),
    ]));
    if (d.discountAmount > 0) {
      bytes.addAll(gen.row([
        PosColumn(text: s(d.discountLabel ?? 'Скидка'), width: 7, styles: cp),
        PosColumn(text: s('-${sum(d.discountAmount)}'), width: 5, styles: cpRight),
      ]));
    }
    if (d.serviceAmount > 0) {
      bytes.addAll(gen.row([
        PosColumn(text: s(d.serviceLabel ?? 'Обслуживание'), width: 7, styles: cp),
        PosColumn(text: s('+${sum(d.serviceAmount)}'), width: 5, styles: cpRight),
      ]));
    }
    bytes.addAll(gen.row([
      PosColumn(text: s('ИТОГО'), width: 6, styles: cpTotal),
      PosColumn(text: s(sum(d.total)), width: 6, styles: cpTotalR),
    ]));
    bytes.addAll(gen.text(s('Оплата: ${d.paymentLabel}'), styles: cp));
    bytes.addAll(gen.hr(ch: '='));
    bytes.addAll(gen.feed(1));
    bytes.addAll(gen.text(s(d.footer), styles: cpCenter));
    bytes.addAll(gen.feed(2));
    bytes.addAll(gen.cut());
    return bytes;
  }

  /// Zaxira yo'l: profilsiz, sof ASCII (kirill → lotin translit). Har doim ishlaydi.
  List<int> _buildRawReceipt(ReceiptData d, int paperMm) {
    final w = paperMm == 58 ? 32 : 42; // qatordagi belgilar soni
    const esc = 0x1B, gs = 0x1D;
    final b = <int>[];
    List<int> a(String x) => _translit(x).codeUnits;
    void ln(String x) { b.addAll(a(x)); b.add(0x0A); }
    void center(bool on) => b.addAll([esc, 0x61, on ? 0x01 : 0x00]);
    void bold(bool on) => b.addAll([esc, 0x45, on ? 0x01 : 0x00]);
    // Ikki ustunli qator: chap + o'ng, w kenglikka moslab
    void row2(String l, String r) {
      l = _translit(l); r = _translit(r);
      final space = w - l.length - r.length;
      final line = space > 0 ? l + ' ' * space + r : '$l $r';
      b.addAll(line.codeUnits); b.add(0x0A);
    }

    b.addAll([esc, 0x40]); // init
    center(true); bold(true); ln(d.venue); bold(false);
    if (d.address != null && d.address!.isNotEmpty) ln(d.address!);
    center(false);
    ln('-' * w);
    row2('Chek ${d.checkNo}', d.dateTime);
    ln('Kassir: ${d.cashier}');
    ln('-' * w);
    for (final it in d.items) {
      ln(it.name);
      final q = it.qty % 1 == 0 ? it.qty.toInt().toString() : it.qty.toString().replaceAll('.', ',');
      row2('  $q x ${groupNum(it.price)}', groupNum(it.total));
    }
    ln('-' * w);
    row2('Podytog', sum(d.subtotal));
    if (d.discountAmount > 0) row2(d.discountLabel ?? 'Skidka', '-${sum(d.discountAmount)}');
    if (d.serviceAmount > 0) row2(d.serviceLabel ?? 'Obsluzhivanie', '+${sum(d.serviceAmount)}');
    bold(true); row2('ITOGO', sum(d.total)); bold(false);
    ln('Oplata: ${d.paymentLabel}');
    ln('=' * w);
    b.add(0x0A);
    center(true); ln(d.footer); center(false);
    b.addAll([esc, 0x64, 0x03]); // feed 3
    b.addAll([gs, 0x56, 0x00]); // cut
    return b;
  }

  /// Printer bilan ulanishni tekshiradi (chop qilmasdan) — qo'lda IP kiritilganda.
  Future<bool> verifyConnection(String host, {Duration timeout = const Duration(seconds: 2)}) {
    return _probe(host, timeout: timeout);
  }

  Future<void> _send(String host, List<int> bytes, {Duration timeout = const Duration(seconds: 6)}) async {
    // WiFi beqaror bo'lishi mumkin — bir marta qayta urinamiz.
    SocketException? lastErr;
    for (var attempt = 0; attempt < 2; attempt++) {
      Socket? socket;
      try {
        socket = await Socket.connect(host, kPort, timeout: timeout);
        socket.add(bytes);
        await socket.flush();
        await Future.delayed(const Duration(milliseconds: 450));
        return; // muvaffaqiyat
      } on SocketException catch (e) {
        lastErr = e;
        await Future.delayed(const Duration(milliseconds: 350));
      } finally {
        await socket?.close();
        socket?.destroy();
      }
    }
    throw PrinterException('Printerga ulanib bo\'lmadi ($host): ${lastErr?.message ?? 'timeout'}');
  }

  Future<void> printReceipt(String host, ReceiptData data, {int? paperMm}) async {
    final mm = paperMm ?? await savedPaperMm();
    final bytes = await _buildReceiptBytes(data, mm);
    await _send(host, bytes);
  }

  Future<void> printReceiptToSaved(ReceiptData data) async {
    final ip = await savedIp();
    if (ip == null) throw const PrinterException('Printer tanlanmagan.');
    await printReceipt(ip, data);
  }

  /// Test chek — sof ASCII/raw (profil va kod-jadvalga bog'liq EMAS).
  Future<void> printTest(String host, {int? paperMm}) async {
    await _send(host, _rawTestBytes());
  }

  List<int> _rawTestBytes() {
    const esc = 0x1B, gs = 0x1D;
    final b = <int>[];
    b.addAll([esc, 0x40]);
    b.addAll([esc, 0x61, 0x01]);
    b.addAll('Xposter\n'.codeUnits);
    b.addAll('TEST / TEKSHIRUV\n'.codeUnits);
    b.addAll([esc, 0x61, 0x00]);
    b.addAll('------------------------------\n'.codeUnits);
    b.addAll('Plov              35 000\n'.codeUnits);
    b.addAll('Choy               5 000\n'.codeUnits);
    b.addAll('Lepyoshka          4 000\n'.codeUnits);
    b.addAll('------------------------------\n'.codeUnits);
    b.addAll([esc, 0x45, 0x01]);
    b.addAll('JAMI              44 000\n'.codeUnits);
    b.addAll([esc, 0x45, 0x00]);
    b.addAll('\nRahmat! Thank you!\n'.codeUnits);
    b.addAll([esc, 0x64, 0x04]);
    b.addAll([gs, 0x56, 0x00]);
    return b;
  }

  Future<void> printRaw(String host, List<int> bytes) => _send(host, bytes);
}

// ─────────────── Matn yordamchilari ───────────────

/// CP866'ga xavfsiz: tipografik belgilarni almashtiradi, kodlanmaydiganini olib tashlaydi.
String _cp866Safe(String s) {
  final buf = StringBuffer();
  for (final r in s.runes) {
    if (r == 0x00AB || r == 0x00BB || r == 0x201C || r == 0x201D || r == 0x201E || r == 0x00A7) { buf.write('"'); continue; }
    if (r == 0x2018 || r == 0x2019) { buf.write("'"); continue; }
    if (r == 0x2013 || r == 0x2014 || r == 0x2212) { buf.write('-'); continue; }
    if (r == 0x2026) { buf.write('...'); continue; }
    if (r == 0x00A0) { buf.write(' '); continue; }
    if (r == 0x2116) { buf.write('N'); continue; } // №
    // ASCII, Cyrillic (А..я), Ё/ё — qoldiramiz
    if ((r >= 0x20 && r <= 0x7E) || (r >= 0x0410 && r <= 0x044F) || r == 0x0401 || r == 0x0451) {
      buf.writeCharCode(r);
    }
    // qolgani (emoji va h.k.) — tashlab yuboriladi
  }
  return buf.toString();
}

const Map<String, String> _kTranslit = {
  'А': 'A', 'Б': 'B', 'В': 'V', 'Г': 'G', 'Д': 'D', 'Е': 'E', 'Ё': 'E', 'Ж': 'Zh', 'З': 'Z', 'И': 'I',
  'Й': 'Y', 'К': 'K', 'Л': 'L', 'М': 'M', 'Н': 'N', 'О': 'O', 'П': 'P', 'Р': 'R', 'С': 'S', 'Т': 'T',
  'У': 'U', 'Ф': 'F', 'Х': 'Kh', 'Ц': 'Ts', 'Ч': 'Ch', 'Ш': 'Sh', 'Щ': 'Sch', 'Ъ': '', 'Ы': 'Y', 'Ь': '',
  'Э': 'E', 'Ю': 'Yu', 'Я': 'Ya',
  'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e', 'ё': 'e', 'ж': 'zh', 'з': 'z', 'и': 'i',
  'й': 'y', 'к': 'k', 'л': 'l', 'м': 'm', 'н': 'n', 'о': 'o', 'п': 'p', 'р': 'r', 'с': 's', 'т': 't',
  'у': 'u', 'ф': 'f', 'х': 'kh', 'ц': 'ts', 'ч': 'ch', 'ш': 'sh', 'щ': 'sch', 'ъ': '', 'ы': 'y', 'ь': '',
  'э': 'e', 'ю': 'yu', 'я': 'ya',
  '«': '"', '»': '"', '№': 'N', ' ': ' ',
};

/// Kirill → lotin transliteratsiya (zaxira chek uchun; har qanday printerda ishlaydi).
String _translit(String s) {
  final buf = StringBuffer();
  for (final ch in s.split('')) {
    if (_kTranslit.containsKey(ch)) {
      buf.write(_kTranslit[ch]);
    } else if (ch.codeUnitAt(0) >= 0x20 && ch.codeUnitAt(0) <= 0x7E) {
      buf.write(ch); // ASCII
    }
    // qolgani (emoji va h.k.) — tashlab yuboriladi
  }
  return buf.toString();
}

/// Printer bilan bog'liq xatolar uchun.
class PrinterException implements Exception {
  final String message;
  const PrinterException(this.message);
  @override
  String toString() => message;
}
