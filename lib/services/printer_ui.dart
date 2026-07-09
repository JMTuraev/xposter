import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'printer_service.dart';

/// Chekni chop etadi. Saqlangan printer bo'lsa — to'g'ridan-to'g'ri (loading + SnackBar),
/// bo'lmasa — printer qidiruv oynasini ochadi va tanlangach shu chekni chiqaradi.
Future<void> ensurePrinterAndPrint(BuildContext context, ReceiptData data) async {
  final saved = await PrinterService.instance.savedIp();
  if (!context.mounted) return;
  if (saved == null) {
    await showPrinterPicker(context, printAfterSelect: data);
  } else {
    await _printWithFeedback(context, saved, data);
  }
}

/// Loading indikatori → real print → natija SnackBar.
Future<void> _printWithFeedback(BuildContext context, String ip, ReceiptData data) async {
  _showLoader(context, 'Печать чека...');
  try {
    await PrinterService.instance.printReceipt(ip, data);
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    if (context.mounted) showToast(context, 'Чек напечатан 🖨', icon: Icons.check_circle);
  } catch (e) {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    if (context.mounted) {
      showToast(context, 'Ошибка печати: $e',
          color: AppColors.danger, bg: AppColors.dangerSoft, icon: Icons.error_outline);
    }
  }
}

Future<void> _testWithFeedback(BuildContext context, String ip, int paperMm) async {
  _showLoader(context, 'Печать теста...');
  try {
    await PrinterService.instance.printTest(ip, paperMm: paperMm);
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    if (context.mounted) showToast(context, 'Тестовый чек отправлен 🖨', icon: Icons.check_circle);
  } catch (e) {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    if (context.mounted) {
      showToast(context, 'Ошибка: $e', color: AppColors.danger, bg: AppColors.dangerSoft, icon: Icons.error_outline);
    }
  }
}

void _showLoader(BuildContext context, String text) {
  showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black26,
    builder: (_) => Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), boxShadow: kSoftShadow),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.accent)),
          const SizedBox(width: 14),
          Text(text, style: AppTheme.sans(size: 14, weight: FontWeight.w500)),
        ]),
      ),
    ),
  );
}

/// IP manzil to'g'ri formatdami (x.x.x.x, har biri 0..255).
bool _looksLikeIp(String s) {
  final parts = s.split('.');
  if (parts.length != 4) return false;
  for (final p in parts) {
    final n = int.tryParse(p);
    if (n == null || n < 0 || n > 255) return false;
  }
  return true;
}

/// Printer qidiruv/tanlash oynasi (pastdan chiqadigan sheet).
/// [printAfterSelect] berilsa — printer tanlangach shu chek darhol chop etiladi.
Future<void> showPrinterPicker(BuildContext context, {ReceiptData? printAfterSelect}) async {
  final svc = PrinterService.instance;
  String? savedIp = await svc.savedIp();
  int paperMm = await svc.savedPaperMm();
  if (!context.mounted) return;
  final ipCtrl = TextEditingController(text: savedIp ?? '');

  List<PrinterDevice> found = [];
  bool scanning = false;
  bool scannedOnce = false;
  double progress = 0;
  int lastPct = -1; // progress'ni throttle qilish uchun

  await showAppSheet(context, title: 'Wi-Fi принтер', builder: (sheetCtx) {
    return StatefulBuilder(builder: (ctx, setS) {
      Future<void> scan() async {
        setS(() { scanning = true; found = []; progress = 0; lastPct = -1; });
        try {
          final list = await svc.discover(onProgress: (p) {
            final pct = (p * 100).round();
            if (pct != lastPct && ctx.mounted) {
              lastPct = pct;
              setS(() => progress = p);
            }
          });
          if (ctx.mounted) setS(() { found = list; scanning = false; scannedOnce = true; });
          if (list.isEmpty && ctx.mounted) {
            showToast(ctx, 'Принтеры не найдены. Проверьте: принтер включён и в той же Wi-Fi сети, что и устройство.',
                color: AppColors.warning, bg: AppColors.warningSoft, icon: Icons.info_outline);
          }
        } catch (e) {
          if (ctx.mounted) setS(() { scanning = false; scannedOnce = true; });
          if (ctx.mounted) showToast(ctx, '$e', color: AppColors.danger, bg: AppColors.dangerSoft, icon: Icons.error_outline);
        }
      }

      Future<void> selectPrinter(String ip) async {
        await svc.savePrinter(ip, paperMm: paperMm);
        if (!ctx.mounted) return;
        if (printAfterSelect != null) {
          Navigator.of(sheetCtx).pop(); // oynani yopamiz
          if (context.mounted) await _printWithFeedback(context, ip, printAfterSelect);
        } else {
          showToast(ctx, 'Принтер сохранён: $ip', icon: Icons.check_circle);
          setS(() => savedIp = ip); // «сохранённый» holatini yangilash
        }
      }

      final currentSaved = savedIp;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Нажмите «Найти принтеры» — приложение само обнаружит принтер в вашей Wi-Fi сети (по имени через Bonjour, затем сканирует сеть на порт 9100). Вводить IP вручную не нужно.',
            style: AppTheme.sans(size: 12.5, color: AppColors.textSecondary, height: 1.35)),
        const SizedBox(height: 14),

        // ── Qog'oz kengligi ──
        Text('Ширина бумаги', style: AppTheme.sans(size: 12, weight: FontWeight.w600, color: AppColors.textTertiary)),
        const SizedBox(height: 6),
        Row(children: [58, 80].map((mm) {
          final active = paperMm == mm;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setS(() => paperMm = mm),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? AppColors.accent : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: active ? AppColors.accent : AppColors.border),
                ),
                child: Text('$mm мм', style: AppTheme.sans(size: 13, weight: FontWeight.w600, color: active ? Colors.white : AppColors.textSecondary)),
              ),
            ),
          );
        }).toList()),
        const SizedBox(height: 16),

        // ── Qidirish tugmasi ──
        PrimaryButton(
          scanning ? 'Поиск... ${(progress * 100).round()}%' : 'Найти принтеры',
          icon: scanning ? null : Icons.search,
          onPressed: scanning ? null : scan,
        ),
        if (scanning) ...[
          const SizedBox(height: 10),
          ClipRRect(borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: progress, minHeight: 5, backgroundColor: AppColors.bgSecondary, valueColor: const AlwaysStoppedAnimation(AppColors.accent))),
        ],
        const SizedBox(height: 14),

        // ── Qo'lda IP kiritish (discovery topmasa yoki noto'g'ri qurilma topsa) ──
        Text('Или введите IP принтера вручную', style: AppTheme.sans(size: 12, weight: FontWeight.w600, color: AppColors.textTertiary)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: TextField(
            controller: ipCtrl,
            keyboardType: TextInputType.number,
            style: AppTheme.sans(size: 14),
            decoration: InputDecoration(
              hintText: '192.168.1.100',
              isDense: true,
              filled: true, fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              hintStyle: AppTheme.sans(size: 14, color: AppColors.textTertiary),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.input), borderSide: const BorderSide(color: AppColors.borderStrong)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.input), borderSide: const BorderSide(color: AppColors.borderStrong)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.input), borderSide: const BorderSide(color: AppColors.accent, width: 2)),
            ),
          )),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () async {
              final ip = ipCtrl.text.trim();
              if (!_looksLikeIp(ip)) {
                showToast(ctx, 'Неверный IP. Пример: 192.168.1.100', color: AppColors.danger, bg: AppColors.dangerSoft, icon: Icons.error_outline);
                return;
              }
              // Saqlashdan oldin ulanishni tekshiramiz — yanglish IP saqlanmasin.
              _showLoader(context, 'Проверка связи...');
              final ok = await svc.verifyConnection(ip);
              if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
              if (!ok) {
                if (ctx.mounted) showToast(ctx, 'Принтер по адресу $ip не отвечает (порт 9100). Проверьте IP и сеть.',
                    color: AppColors.danger, bg: AppColors.dangerSoft, icon: Icons.error_outline);
                return;
              }
              selectPrinter(ip);
            },
            child: Container(height: 44, padding: const EdgeInsets.symmetric(horizontal: 16), alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(AppRadius.btn)), child: Text('Подключить', style: AppTheme.sans(size: 13.5, weight: FontWeight.w600, color: Colors.white))),
          ),
        ]),
        const SizedBox(height: 6),
        Text('IP принтера можно узнать на его чеке самодиагностики (зажать «Feed» при включении) или в роутере.',
            style: AppTheme.sans(size: 11, color: AppColors.textTertiary, height: 1.3)),
        const SizedBox(height: 14),

        // ── Topilgan printerlar ──
        if (found.isNotEmpty) ...[
          Text('Найдено (${found.length})', style: AppTheme.sans(size: 12, weight: FontWeight.w600, color: AppColors.textTertiary)),
          const SizedBox(height: 6),
          ...found.map((dev) {
            final isSaved = dev.ip == currentSaved;
            final byMdns = dev.source == 'mdns';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => selectPrinter(dev.ip),
                borderRadius: BorderRadius.circular(AppRadius.btn),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.btn),
                    border: Border.all(color: isSaved ? AppColors.accent : AppColors.border),
                  ),
                  child: Row(children: [
                    const Text('🖨', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Flexible(child: Text(dev.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(size: 14, weight: FontWeight.w600))),
                        if (byMdns) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(color: AppColors.successSoft, borderRadius: BorderRadius.circular(999)),
                            child: Text('распознан', style: AppTheme.sans(size: 9.5, weight: FontWeight.w700, color: AppColors.success)),
                          ),
                        ],
                      ]),
                      Text('${dev.ip} : ${dev.port}', style: AppTheme.sans(size: 12, color: AppColors.textTertiary)),
                    ])),
                    if (isSaved)
                      const Icon(Icons.check_circle, size: 20, color: AppColors.accent)
                    else
                      Text(printAfterSelect != null ? 'Печать' : 'Выбрать', style: AppTheme.sans(size: 13, weight: FontWeight.w600, color: AppColors.accentHover)),
                  ]),
                ),
              ),
            );
          }),
          const SizedBox(height: 6),
        ] else if (scannedOnce && !scanning) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: AppColors.warningSoft, borderRadius: BorderRadius.circular(AppRadius.btn)),
            child: Row(children: [
              const Text('🔍', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 10),
              Expanded(child: Text('Принтер не найден. Проверьте, что он включён и в той же Wi-Fi сети. Можно ввести IP вручную ниже.',
                  style: AppTheme.sans(size: 12, color: AppColors.textSecondary, height: 1.35))),
            ]),
          ),
          const SizedBox(height: 6),
        ],

        // ── Saqlangan printer + test ──
        if (currentSaved != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: AppColors.successSoft, borderRadius: BorderRadius.circular(AppRadius.btn)),
            child: Row(children: [
              const Icon(Icons.check_circle, size: 18, color: AppColors.success),
              const SizedBox(width: 10),
              Expanded(child: Text('Сохранён: $currentSaved', style: AppTheme.sans(size: 13, weight: FontWeight.w600, color: AppColors.success))),
            ]),
          ),
          const SizedBox(height: 10),
          SecondaryButton('Тест печати', icon: Icons.print, expand: true, onPressed: () => _testWithFeedback(context, currentSaved, paperMm)),
        ],
      ]);
    });
  });
}
