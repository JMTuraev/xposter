import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../../widgets/ui.dart';
import '../../services/printer_ui.dart';
import 'kassa_controller.dart';

/// ☰ «Функции» modal — guruhlangan ro'yxat (prototip funcGroups).
void showFunctionsSheet(BuildContext context, KassaController ctrl) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet))),
    builder: (ctx) {
      Widget row(String emoji, String label, {Color color = AppColors.text, required bool top, required VoidCallback onTap}) => GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(border: top ? const Border(top: BorderSide(color: AppColors.border)) : null),
              child: Row(children: [
                Container(width: 34, height: 34, alignment: Alignment.center, decoration: BoxDecoration(color: color == AppColors.danger ? AppColors.dangerSoft : AppColors.bgSecondary, borderRadius: BorderRadius.circular(10)), child: Text(emoji, style: const TextStyle(fontSize: 16))),
                const SizedBox(width: 12),
                Expanded(child: Text(label, style: AppTheme.sans(size: 14.5, weight: FontWeight.w500, color: color))),
                const Icon(Icons.chevron_right, size: 17, color: AppColors.textTertiary),
              ]),
            ),
          );

      Widget group(String title, List<Widget> rows) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 7), child: Text(title.toUpperCase(), style: AppTheme.sans(size: 11, weight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 0.8))),
            Container(
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
              clipBehavior: Clip.antiAlias,
              child: Column(children: rows),
            ),
          ]);

      void toastStore(String label) {
        Navigator.pop(ctx);
        showToast(context, '«$label» — во вкладке «Склад» внизу экрана', color: AppColors.textSecondary, bg: AppColors.bgSecondary, icon: Icons.inventory_2_outlined);
      }

      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 34 + MediaQuery.of(ctx).viewPadding.bottom),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: AppColors.borderStrong, borderRadius: BorderRadius.circular(999)), margin: const EdgeInsets.only(bottom: 16))),
          Text('Функции', style: AppTheme.serif(size: 20, weight: FontWeight.w700)),
          const SizedBox(height: 14),
          group('Приложения', [
            row('📋', 'Инвентаризация', top: false, onTap: () => toastStore('Инвентаризация')),
            row('🚚', 'Поставка', top: true, onTap: () => toastStore('Поставка')),
            row('📸', 'Накладная с фото AI', top: true, onTap: () { Navigator.pop(ctx); showToast(context, 'Накладная с фото — установите Postie AI в «Приложениях»', color: AppColors.accentHover, bg: AppColors.accentSoft, icon: Icons.auto_awesome); }),
          ]),
          const SizedBox(height: 14),
          // Y-10: Kassa smenasini ochish/yopish (ilgari Android'da UI umuman yo'q
          // edi — Финансы «Функции → Открыть смену» ga yo'naltirardi, lekin tugma
          // mavjud emasdi; smena hech qachon ochilmasdi, Z-otchet ishlamasdi).
          group('Кассовая смена', [
            if (ctrl.app.currentShift == null)
              row('🟢', 'Открыть смену', top: false, onTap: () {
                ctrl.app.openShift();
                Navigator.pop(ctx);
                showToast(context, 'Смена открыта', color: AppColors.success, bg: AppColors.bgSecondary, icon: Icons.play_circle_outline);
              })
            else
              row('🔴', 'Закрыть смену (Z-отчёт)', color: AppColors.danger, top: false, onTap: () {
                Navigator.pop(ctx);
                _closeShiftDialog(context, ctrl);
              }),
          ]),
          const SizedBox(height: 14),
          group('Оборудование', [
            row('🖨', 'Устройства (Wi-Fi принтер)', top: false, onTap: () { Navigator.pop(ctx); showPrinterPicker(context); }),
            row('💰', 'Открыть денежный ящик', top: true, onTap: () { Navigator.pop(ctx); showToast(context, 'Денежный ящик открыт'); }),
          ]),
          const SizedBox(height: 14),
          group('Другое', [
            row('📊', 'Составить отчёт', top: false, onTap: () { Navigator.pop(ctx); _reportSheet(context, ctrl); }),
            row('↕️', 'Режим сортировки', top: true, onTap: () { Navigator.pop(ctx); showToast(context, 'Режим сортировки включён (имитация)', color: AppColors.textSecondary, bg: AppColors.bgSecondary, icon: Icons.swap_vert); }),
            row('🧹', 'Очистить кеш', top: true, onTap: () { Navigator.pop(ctx); showToast(context, 'Кеш очищен — данные актуальны'); }),
            row('🚪', 'Выйти из аккаунта', color: AppColors.danger, top: true, onTap: () { Navigator.pop(ctx); ctrl.lock(); }),
          ]),
        ]),
      );
    },
  );
}

/// Y-10: Smenani yopish dialogi — fakt naqdni kiritib Z-otchet yaratadi.
void _closeShiftDialog(BuildContext context, KassaController ctrl) {
  final app = ctrl.app;
  final ctl = TextEditingController(text: app.cashBoxBalance.toString());
  showDialog(
    context: context,
    builder: (d) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Закрытие смены', style: AppTheme.serif(size: 18, weight: FontWeight.w700)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Ожидается в кассе: ${sum(app.cashBoxBalance)}', style: AppTheme.sans(size: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 12),
        Text('ФАКТИЧЕСКИ ПОСЧИТАНО', style: AppTheme.sans(size: 11, weight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 0.8)),
        const SizedBox(height: 6),
        TextField(
          controller: ctl,
          keyboardType: TextInputType.number,
          style: AppTheme.sans(size: 15),
          decoration: InputDecoration(
            isDense: true, filled: true, fillColor: AppColors.bgSecondary,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.btn), borderSide: const BorderSide(color: AppColors.borderStrong)),
          ),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: Text('Отмена', style: AppTheme.sans(color: AppColors.textSecondary))),
        TextButton(
          onPressed: () {
            final counted = int.tryParse(ctl.text.replaceAll(RegExp(r'[^0-9-]'), '')) ?? app.cashBoxBalance;
            final s = app.closeShift(counted: counted);
            Navigator.pop(d);
            if (s != null) {
              final diff = s.diff;
              showToast(context, diff == 0 ? 'Смена закрыта — расхождений нет' : 'Смена закрыта. Расхождение: ${sum(diff)}',
                  color: diff == 0 ? AppColors.success : AppColors.danger, bg: AppColors.bgSecondary, icon: Icons.check_circle_outline);
            }
          },
          child: Text('Закрыть смену', style: AppTheme.sans(weight: FontWeight.w700, color: AppColors.danger)),
        ),
      ],
    ),
  );
}

/// X-отчёт за период — sana/vaqt/kassir + «по товарам» + «Сформировать».
void _reportSheet(BuildContext context, KassaController ctrl) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet))),
    builder: (ctx) {
      bool byItems = true;
      return StatefulBuilder(builder: (ctx, setSheet) {
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 34 + MediaQuery.of(ctx).viewPadding.bottom),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: AppColors.borderStrong, borderRadius: BorderRadius.circular(999)), margin: const EdgeInsets.only(bottom: 16))),
            Text('X-отчёт за период', style: AppTheme.serif(size: 20, weight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Смена не закрывается — отчёт информационный', style: AppTheme.sans(size: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _fakeField('С ДАТЫ', 'Сегодня')),
              const SizedBox(width: 10),
              SizedBox(width: 104, child: _fakeField('ВРЕМЯ', '09:00')),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _fakeField('ПО ДАТУ', 'Сегодня')),
              const SizedBox(width: 10),
              SizedBox(width: 104, child: _fakeField('ВРЕМЯ', _nowT())),
            ]),
            const SizedBox(height: 10),
            _fakeField('КАССИР', 'Все кассиры'),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => setSheet(() => byItems = !byItems),
              child: Row(children: [
                Expanded(child: Text('Продажи по товарам', style: AppTheme.sans(size: 14, weight: FontWeight.w600))),
                Container(
                  width: 40, height: 24,
                  decoration: BoxDecoration(color: byItems ? AppColors.success : AppColors.borderStrong, borderRadius: BorderRadius.circular(999)),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 180),
                    alignment: byItems ? Alignment.centerRight : Alignment.centerLeft,
                    child: Padding(padding: const EdgeInsets.all(2), child: Container(width: 20, height: 20, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () { Navigator.pop(ctx); _xReport(context, ctrl, byItems); },
              child: Container(height: 48, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(AppRadius.btn)), child: Text('Сформировать', style: AppTheme.sans(size: 14.5, weight: FontWeight.w600, color: Colors.white))),
            ),
          ]),
        );
      });
    },
  );
}

/// X-отчёт natijasi (prototip posX).
void _xReport(BuildContext context, KassaController ctrl, bool byItems) {
  final app = ctrl.app;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet))),
    builder: (ctx) => SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 34 + MediaQuery.of(ctx).viewPadding.bottom),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: AppColors.borderStrong, borderRadius: BorderRadius.circular(999)), margin: const EdgeInsets.only(bottom: 16))),
        Text('X-отчёт', style: AppTheme.serif(size: 20, weight: FontWeight.w700)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.card), border: Border.all(color: AppColors.border)),
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Сегодня, 09:00 — ${_nowT()}', style: AppTheme.sans(size: 12, color: AppColors.textTertiary)),
            Text('Кассир: Все кассиры', style: AppTheme.sans(size: 12.5, color: AppColors.textSecondary)),
            const Divider(height: 24, color: AppColors.border),
            Text('Выручка', style: AppTheme.sans(size: 12.5, color: AppColors.textSecondary)),
            const SizedBox(height: 3),
            Text(sum(app.salesToday['revenue'] as int), style: AppTheme.serif(size: 27, weight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _stat('Чеки', '${app.salesToday['checks']}')),
              Expanded(child: _stat('Средний чек', sum(app.salesToday['avgCheck'] as int))),
            ]),
            const SizedBox(height: 10),
            _stat('Прибыль', sum(app.salesToday['profit'] as int)),
            const Divider(height: 24, color: AppColors.border),
            _payRow('💵 Наличными', sum(app.paymentMethods['Наличные'] ?? 0)),
            const SizedBox(height: 7),
            _payRow('💳 Карточкой', sum(app.paymentMethods['Карточка'] ?? 0)),
            const SizedBox(height: 7),
            _payRow('💎 Бонусами', sum(app.paymentMethods['Бонусы'] ?? 0)),
          ]),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () { Navigator.pop(ctx); showToast(context, 'X-отчёт отправлен на печать', color: AppColors.textSecondary, bg: AppColors.bgSecondary, icon: Icons.print); },
          child: Container(height: 48, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.btn), border: Border.all(color: AppColors.borderStrong)), child: Text('🖨 Печать', style: AppTheme.sans(size: 14.5, weight: FontWeight.w600))),
        ),
      ]),
    ),
  );
}

String _nowT() {
  final d = DateTime.now();
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

Widget _fakeField(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppTheme.sans(size: 11, weight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 0.8)),
      const SizedBox(height: 6),
      Container(
        height: 44, alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.btn), border: Border.all(color: AppColors.borderStrong)),
        child: Text(value, style: AppTheme.sans(size: 13.5)),
      ),
    ]);

Widget _stat(String k, String v) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(k, style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary)),
      const SizedBox(height: 1),
      Text(v, style: AppTheme.sans(size: 14.5, weight: FontWeight.w700)),
    ]);

Widget _payRow(String k, String v) => Row(children: [
      Text(k, style: AppTheme.sans(size: 13, color: AppColors.textSecondary)),
      const Spacer(),
      Text(v, style: AppTheme.sans(size: 13, weight: FontWeight.w700)),
    ]);
