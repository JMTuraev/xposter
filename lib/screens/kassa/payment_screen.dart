import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme.dart';
import '../../state/app_state.dart';
import '../../utils/format.dart';
import '../../widgets/ui.dart';
import 'kassa_controller.dart';
import '../../services/printer_service.dart';
import '../../services/printer_ui.dart';

class PaymentScreen extends StatefulWidget {
  final KassaController ctrl;
  const PaymentScreen({super.key, required this.ctrl});
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> with SingleTickerProviderStateMixin {
  late int _due;
  late int _subtotal;
  late int _discountPct;
  late int _discount;
  final Map<String, int> _parts = {'cash': 0, 'card': 0, 'cert': 0, 'bonus': 0};
  String _entered = ''; // klaviaturada terilgan xom summa (vergul mumkin)
  bool _print = true;
  late final AnimationController _shake;

  @override
  void initState() {
    super.initState();
    final doc = widget.ctrl.active;
    _due = doc.dueFor(widget.ctrl.app);
    _subtotal = doc.subtotal;
    _discountPct = doc.discountPctFor(widget.ctrl.app);
    _discount = doc.discountAmountFor(widget.ctrl.app);
    _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    // Printer sozlanmagan bo'lsa — «Напечатать чек» default o'chiq
    // (birinchi foydalanuvchi to'lovdan keyin printer xatosiga urilmasin).
    PrinterService.instance.savedIp().then((ip) {
      if (mounted && ip == null) setState(() => _print = false);
    });
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  int get _paid => _parts.values.fold(0, (s, v) => s + v);
  int get _remaining => (_due - _paid).clamp(0, 1 << 31);
  int get _change => (_paid - _due).clamp(0, 1 << 31);

  // Terilgan summa (butun songa yaxlitlab)
  int get _enteredNum {
    if (_entered.isEmpty) return 0;
    final norm = _entered.replaceAll(',', '.');
    return (double.tryParse(norm) ?? 0).round();
  }

  String get _enteredDisplay {
    if (_entered.isEmpty) return '0';
    final seg = _entered.split(',');
    final intPart = int.tryParse(seg[0].isEmpty ? '0' : seg[0]) ?? 0;
    var out = groupNum(intPart);
    if (seg.length > 1) out = '$out,${seg[1]}';
    return out;
  }

  int get _quickBase => _remaining > 0 ? _remaining : _due;
  int get _quickRound => ((_quickBase / 10000).ceil()) * 10000;

  void _key(String k) {
    setState(() {
      if (k == '⌫') {
        _entered = _entered.isEmpty ? '' : _entered.substring(0, _entered.length - 1);
      } else if (k == ',') {
        if (!_entered.contains(',')) _entered = (_entered.isEmpty ? '0' : _entered) + ',';
      } else {
        if (_entered.replaceAll(',', '').length >= 9) return;
        _entered = _entered == '0' ? k : _entered + k;
      }
    });
  }

  /// Usulga summa biriktirish (prototip payAssign).
  void _assign(String m) {
    final already = _parts[m] ?? 0;
    int amt = _enteredNum != 0 ? _enteredNum : _remaining;
    if (m != 'cash') amt = amt < _remaining ? amt : _remaining;
    if (m == 'bonus') {
      final c = widget.ctrl.active.client;
      if (c == null || c.bonus <= 0) {
        showToast(context, 'Прикрепите клиента с бонусами', color: AppColors.textSecondary, bg: AppColors.bgSecondary, icon: Icons.info_outline);
        return;
      }
      final cap = widget.ctrl.bonusCapFor(widget.ctrl.active, already);
      if (amt > cap) amt = cap;
    }
    if (amt <= 0) {
      showToast(context, _remaining == 0 ? 'Сумма уже внесена полностью' : 'Недоступно', color: AppColors.textSecondary, bg: AppColors.bgSecondary, icon: Icons.info_outline);
      return;
    }
    setState(() {
      _parts[m] = already + amt;
      _entered = '';
    });
  }

  void _clear(String m) => setState(() => _parts[m] = 0);

  void _submit() {
    if (_paid == 0) {
      _shake.forward(from: 0);
      return;
    }
    if (_paid < _due) {
      _shake.forward(from: 0);
      showToast(context, 'Осталось внести ${sum(_due - _paid)}', color: AppColors.warning, bg: AppColors.warningSoft, icon: Icons.warning_amber_rounded);
      return;
    }
    final label = _paymentLabel();
    final doc = widget.ctrl.active;
    final svcPct = doc.serviceFeePctFor(widget.ctrl.app);
    final svcAmt = doc.serviceAmountFor(widget.ctrl.app);
    final snapshotLines = doc.lines
        .map((l) => _RcLine(
              name: l.product.name + (l.modification != null ? ' (${l.modification})' : ''),
              qtyLine: '×${qty(l.qty)} × ${groupNum(l.product.price)}',
              sumStr: groupNum(l.total),
            ))
        .toList();
    final client = doc.client?.name;
    final change = _change;
    final payLines = <_PayLine>[];
    const labels = {'cash': 'Наличными', 'card': 'Карточкой', 'cert': 'Сертификатом', 'bonus': 'Бонусами'};
    // Chekda naqd — mijoz BERGAN (внесено) summa, pastda «Сдача» alohida qator.
    // Shunda payLines yig'indisi − Сдача = ИТОГО va chek ichki ziddiyatsiz bo'ladi.
    // (Kassa yashigiga esa completePayment faqat sof summani qo'shadi.)
    for (final k in ['cash', 'card', 'cert', 'bonus']) {
      final v = _parts[k] ?? 0;
      if (v > 0) payLines.add(_PayLine(labels[k]!, groupNum(v)));
    }
    // Real chek uchun ma'lumot — completePayment chekni tozalashidan OLDIN yig'amiz.
    final rcNo = widget.ctrl.nextOrder;
    final receiptData = ReceiptData(
      venue: widget.ctrl.app.company['name'] as String,
      address: widget.ctrl.app.company['address'] as String?,
      checkNo: '№$rcNo',
      cashier: widget.ctrl.user?.name ?? 'Кассир',
      dateTime: _fmtDateTime(DateTime.now()),
      items: doc.lines
          .map((l) => ReceiptLine(
                name: l.product.name + (l.modification != null ? ' (${l.modification})' : ''),
                qty: l.qty,
                price: l.product.price,
              ))
          .toList(),
      subtotal: _subtotal,
      discountLabel: _discountPct > 0 ? 'Скидка $_discountPct%' : null,
      discountAmount: _discount,
      serviceLabel: svcPct > 0 ? 'Обслуживание $svcPct%' : null,
      serviceAmount: svcAmt,
      total: _due,
      paymentLabel: label,
    );
    widget.ctrl.completePayment(
      parts: Map<String, int>.from(_parts),
      change: change,
      paymentLabel: label,
      subtotalAmt: _subtotal,
      discountPctAmt: _discountPct,
      discountAmt: _discount,
      totalDue: _due,
    );
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ReceiptView(
      lines: snapshotLines,
      subtotal: _subtotal,
      discountPct: _discountPct,
      discount: _discount,
      serviceLabel: svcPct > 0 ? 'Обслуживание $svcPct%' : null,
      serviceAmount: svcAmt,
      total: _due,
      payLines: payLines,
      change: change,
      cashier: widget.ctrl.user?.name ?? '',
      client: client,
      openT: _fmtTime(doc.openedAt),
      closeT: _fmtTime(DateTime.now()),
      number: widget.ctrl.nextOrder - 1,
      receipt: receiptData,
      autoPrint: _print, // «Напечатать чек» yoqilgan bo'lsa — avtomatik chop etadi
    )));
  }

  String _paymentLabel() {
    const labels = {'cash': 'Наличными', 'card': 'Карточкой', 'cert': 'Сертификатом', 'bonus': 'Бонусами'};
    final parts = <String>[];
    for (final k in ['cash', 'card', 'cert', 'bonus']) {
      if ((_parts[k] ?? 0) > 0) parts.add(labels[k]!);
    }
    return parts.isEmpty ? '—' : parts.join(' + ');
  }

  String _fmtTime(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _fmtDateTime(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(children: [
          // ── Sarlavha ──
          SizedBox(
            height: 46,
            child: Stack(alignment: Alignment.center, children: [
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.chevron_left, size: 22, color: AppColors.accentHover),
                      Text('Отменить', style: AppTheme.sans(size: 14, weight: FontWeight.w600, color: AppColors.accentHover)),
                    ]),
                  ),
                ),
              ),
              Text('Чек №${widget.ctrl.active.number}', style: AppTheme.sans(size: 16, weight: FontWeight.w600)),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, 2, 16, 18 + MediaQuery.of(context).viewPadding.bottom),
              children: [
                // ── К оплате karta ──
                Container(
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.card), border: Border.all(color: AppColors.border)),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('К оплате', style: AppTheme.sans(size: 13, weight: FontWeight.w500, color: AppColors.textSecondary)),
                      const Spacer(),
                      Text(sum(_due), style: AppTheme.serif(size: 27, weight: FontWeight.w700)),
                    ]),
                    if (_paid > 0 && _remaining > 0) _dashRow('Осталось внести', sum(_remaining), AppColors.warning),
                    if (_change > 0) _dashRow('Сдача', sum(_change), AppColors.success),
                  ]),
                ),
                const SizedBox(height: 10),
                // ── Terilgan summa + tez tugmalar + numpad ──
                Container(
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.card), border: Border.all(color: AppColors.border)),
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(children: [
                    Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.fromLTRB(4, 2, 4, 8),
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
                      child: Text(_enteredDisplay, style: AppTheme.serif(size: 30, weight: FontWeight.w700, color: _entered.isEmpty ? AppColors.textTertiary : AppColors.text)),
                    ),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: _quickChip(groupNum(_quickBase), () => setState(() => _entered = _quickBase.toString()))),
                      if (_quickRound != _quickBase && _quickBase > 0) ...[
                        const SizedBox(width: 7),
                        Expanded(child: _quickChip(groupNum(_quickRound), () => setState(() => _entered = _quickRound.toString()))),
                      ],
                      const SizedBox(width: 7),
                      SizedBox(
                        width: 46, height: 40,
                        child: GestureDetector(
                          onTap: () => showToast(context, 'Внешняя клавиатура не подключена', color: AppColors.textSecondary, bg: AppColors.bgSecondary, icon: Icons.keyboard_outlined),
                          child: Container(alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.bgSecondary, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.keyboard_outlined, size: 18, color: AppColors.textSecondary)),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    _Numpad(onKey: _key),
                  ]),
                ),
                const SizedBox(height: 10),
                // ── To'lov usullari (nal/karta) ──
                AnimatedBuilder(
                  animation: _shake,
                  builder: (_, child) {
                    final err = _paid < _due;
                    final dx = (_shake.isAnimating && err) ? (8 * (1 - _shake.value)) * ((_shake.value * 8).floor().isEven ? 1 : -1) : 0.0;
                    return Transform.translate(offset: Offset(dx, 0), child: child);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(color: _shake.isAnimating ? AppColors.danger : AppColors.border, width: 1.5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(children: [
                      _payRow('💵', 'Наличными', 'cash', top: false),
                      _payRow('💳', 'Карточкой', 'card', top: true),
                    ]),
                  ),
                ),
                const SizedBox(height: 10),
                // ── Сертификат + Бонусы ──
                Row(children: [
                  Expanded(child: _altBtn('🎟', (_parts['cert'] ?? 0) > 0 ? 'Сертификат: ${groupNum(_parts['cert']!)}  ✕' : 'Сертификатом', (_parts['cert'] ?? 0) > 0 ? AppColors.accentHover : AppColors.text, () => (_parts['cert'] ?? 0) > 0 ? _clear('cert') : _assign('cert'))),
                  const SizedBox(width: 8),
                  Expanded(child: _bonusBtn()),
                ]),
                const SizedBox(height: 6),
                Text(_bonusHint(), textAlign: TextAlign.center, style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary)),
                const SizedBox(height: 12),
                // ── Print toggle ──
                GestureDetector(
                  onTap: () => setState(() => _print = !_print),
                  child: Container(
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.card), border: Border.all(color: AppColors.border)),
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Row(children: [
                      Expanded(child: Text('🖨 Напечатать чек', style: AppTheme.sans(size: 14, weight: FontWeight.w600))),
                      _Toggle(on: _print),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                // ── Оплатить ──
                GestureDetector(
                  onTap: _submit,
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(AppRadius.btn)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('Оплатить', style: AppTheme.sans(size: 15, weight: FontWeight.w700, color: Colors.white)),
                      const SizedBox(width: 10),
                      Text(sum(_due), style: AppTheme.serif(size: 16, weight: FontWeight.w700, color: Colors.white)),
                    ]),
                  ),
                ),
                GestureDetector(
                  onTap: _closeNoPay,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text('Закрыть без оплаты', textAlign: TextAlign.center, style: AppTheme.sans(size: 13.5, weight: FontWeight.w600, color: AppColors.danger)),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _dashRow(String label, String value, Color valColor) => Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.only(top: 8),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
        child: Row(children: [
          Text(label, style: AppTheme.sans(size: 13, color: AppColors.textSecondary)),
          const Spacer(),
          Text(value, style: AppTheme.sans(size: 13, weight: FontWeight.w700, color: valColor)),
        ]),
      );

  Widget _quickChip(String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: AppColors.bgSecondary, borderRadius: BorderRadius.circular(10)),
          child: Text(label, style: AppTheme.sans(size: 13, weight: FontWeight.w700)),
        ),
      );

  Widget _payRow(String icon, String label, String key, {required bool top}) {
    final amt = _parts[key] ?? 0;
    return GestureDetector(
      onTap: () => _assign(key),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(border: top ? const Border(top: BorderSide(color: AppColors.border)) : null),
        child: Row(children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 11),
          Expanded(child: Text(label, style: AppTheme.sans(size: 14.5, weight: FontWeight.w600))),
          if (amt > 0) ...[
            Text(groupNum(amt), style: AppTheme.sans(size: 14.5, weight: FontWeight.w700)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _clear(key),
              child: Container(width: 24, height: 24, alignment: Alignment.center, decoration: const BoxDecoration(color: AppColors.bgSecondary, shape: BoxShape.circle), child: const Icon(Icons.close, size: 12, color: AppColors.textSecondary)),
            ),
          ] else
            const Icon(Icons.chevron_right, size: 18, color: AppColors.textTertiary),
        ]),
      ),
    );
  }

  Widget _altBtn(String icon, String label, Color color, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.btn), border: Border.all(color: AppColors.borderStrong)),
          child: Text('$icon $label', style: AppTheme.sans(size: 13, weight: FontWeight.w600, color: color)),
        ),
      );

  Widget _bonusBtn() {
    final c = widget.ctrl.active.client;
    final has = (c != null && c.bonus > 0) || (_parts['bonus'] ?? 0) > 0;
    final label = (_parts['bonus'] ?? 0) > 0 ? 'Бонусы: ${groupNum(_parts['bonus']!)}  ✕' : 'Бонусами';
    final color = (_parts['bonus'] ?? 0) > 0 ? AppColors.accentHover : AppColors.text;
    return Opacity(
      opacity: has ? 1 : 0.45,
      child: GestureDetector(
        onTap: () => (_parts['bonus'] ?? 0) > 0 ? _clear('bonus') : _assign('bonus'),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.btn), border: Border.all(color: AppColors.borderStrong)),
          child: Text('💎 $label', style: AppTheme.sans(size: 13, weight: FontWeight.w600, color: color)),
        ),
      ),
    );
  }

  String _bonusHint() {
    final c = widget.ctrl.active.client;
    if (c == null) return 'Бонусы доступны при прикреплённом клиенте';
    final avail = (c.bonus - (_parts['bonus'] ?? 0)).clamp(0, 1 << 31);
    if (c.bonus > 0 || (_parts['bonus'] ?? 0) > 0) {
      return 'Бонусы: доступно ${groupNum(avail)} · оплата до 50% чека';
    }
    return 'У клиента нет бонусов';
  }

  void _closeNoPay() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
        top: false,
        child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 34),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 5, decoration: BoxDecoration(color: AppColors.borderStrong, borderRadius: BorderRadius.circular(999)), margin: const EdgeInsets.only(bottom: 16)),
          const Text('🚫', style: TextStyle(fontSize: 38)),
          const SizedBox(height: 6),
          Text('Закрыть без оплаты?', style: AppTheme.serif(size: 20, weight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Чек №${widget.ctrl.active.number} будет закрыт, позиции не будут оплачены. Действие необратимо.', textAlign: TextAlign.center, style: AppTheme.sans(size: 13.5, height: 1.5, color: AppColors.textSecondary)),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: () {
              Navigator.pop(ctx);
              widget.ctrl.closeWithoutPay();
              Navigator.pop(context);
              showToast(context, 'Чек закрыт без оплаты', color: AppColors.danger, bg: AppColors.dangerSoft, icon: Icons.block);
            },
            child: Container(height: 48, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: BorderRadius.circular(AppRadius.btn)), child: Text('Закрыть без оплаты', style: AppTheme.sans(size: 15, weight: FontWeight.w600, color: AppColors.danger))),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => Navigator.pop(ctx),
            child: Container(height: 48, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.btn), border: Border.all(color: AppColors.borderStrong)), child: Text('Отмена', style: AppTheme.sans(size: 15, weight: FontWeight.w600))),
          ),
        ]),
      ),
      ),
      ),
    );
  }
}

class _Numpad extends StatelessWidget {
  final ValueChanged<String> onKey;
  const _Numpad({required this.onKey});
  @override
  Widget build(BuildContext context) {
    Widget k(String label, {Widget? child}) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: GestureDetector(
              onTap: () => onKey(label),
              child: Container(
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
                child: child ?? Text(label, style: AppTheme.sans(size: 18, weight: FontWeight.w600)),
              ),
            ),
          ),
        );
    Widget row(List<Widget> ch) => Row(children: ch);
    return Column(children: [
      row([k('1'), k('2'), k('3')]),
      row([k('4'), k('5'), k('6')]),
      row([k('7'), k('8'), k('9')]),
      row([k(','), k('0'), k('⌫', child: const Icon(Icons.backspace_outlined, size: 20, color: AppColors.textSecondary))]),
    ]);
  }
}

class _Toggle extends StatelessWidget {
  final bool on;
  const _Toggle({required this.on});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40, height: 24,
      decoration: BoxDecoration(color: on ? AppColors.success : AppColors.borderStrong, borderRadius: BorderRadius.circular(999)),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 180),
        alignment: on ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Container(width: 20, height: 20, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x40141413), blurRadius: 3, offset: Offset(0, 1))])),
        ),
      ),
    );
  }
}

class _RcLine {
  final String name;
  final String qtyLine;
  final String sumStr;
  _RcLine({required this.name, required this.qtyLine, required this.sumStr});
}

class _PayLine {
  final String label;
  final String value;
  _PayLine(this.label, this.value);
}

/// To'lovdan keyin — bumazhniy chek ko'rinishi (prototip posReceipt).
class ReceiptView extends StatefulWidget {
  final List<_RcLine> lines;
  final int subtotal;
  final int discountPct;
  final int discount;
  final int serviceAmount;
  final String? serviceLabel;
  final int total;
  final List<_PayLine> payLines;
  final int change;
  final String cashier;
  final String? client;
  final String openT;
  final String closeT;
  final int number;
  final ReceiptData receipt; // real ESC/POS print uchun ma'lumot
  final bool autoPrint;      // «Напечатать чек» yoqilgan bo'lsa — avtomatik
  const ReceiptView({super.key, required this.lines, required this.subtotal, required this.discountPct, required this.discount, this.serviceAmount = 0, this.serviceLabel, required this.total, required this.payLines, required this.change, required this.cashier, required this.client, required this.openT, required this.closeT, required this.number, required this.receipt, this.autoPrint = false});

  @override
  State<ReceiptView> createState() => _ReceiptViewState();
}

class _ReceiptViewState extends State<ReceiptView> {
  @override
  void initState() {
    super.initState();
    // «Напечатать чек» yoqilgan bo'lsa — ekran ochilishi bilan avtomatik chop etamiz.
    if (widget.autoPrint) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ensurePrinterAndPrint(context, widget.receipt);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Widget maydonlariga qisqa aliaslar — quyidagi build kodi o'zgarmaydi.
    final lines = widget.lines;
    final discountPct = widget.discountPct;
    final discount = widget.discount;
    final total = widget.total;
    final payLines = widget.payLines;
    final change = widget.change;
    final cashier = widget.cashier;
    final client = widget.client;
    final openT = widget.openT;
    final closeT = widget.closeT;
    final number = widget.number;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(children: [
          SizedBox(
            height: 46,
            child: Center(child: Text('Оплачено ✓', style: AppTheme.sans(size: 16, weight: FontWeight.w700, color: AppColors.success))),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 2, 22, 18),
              children: [
                Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border), boxShadow: const [BoxShadow(color: Color(0x12141413), blurRadius: 22, offset: Offset(0, 8))]),
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                  child: Column(children: [
                    Center(child: Column(children: [
                      Text('${context.read<AppState>().company['name']}', style: AppTheme.serif(size: 17, weight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        (context.read<AppState>().company['address'] as String? ?? '').isEmpty
                            ? 'Касса №1'
                            : '${context.read<AppState>().company['address']} · Касса №1',
                        style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary),
                      ),
                    ])),
                    _dashed(),
                    _kv('Чек', '№$number'),
                    _kv('Кассир', cashier),
                    _kv('Открыт', openT),
                    _kv('Закрыт', closeT),
                    if (client != null) _kv('Клиент', client),
                    _dashed(),
                    ...lines.map((l) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(l.name, style: AppTheme.sans(size: 12.5, weight: FontWeight.w600)),
                              Text(l.qtyLine, style: AppTheme.sans(size: 11, color: AppColors.textTertiary)),
                            ])),
                            Text(l.sumStr, style: AppTheme.sans(size: 12.5, weight: FontWeight.w600)),
                          ]),
                        )),
                    if (discount > 0)
                      Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
                        Text('Скидка $discountPct%', style: AppTheme.sans(size: 12.5, weight: FontWeight.w600, color: AppColors.success)),
                        const Spacer(),
                        Text('−${groupNum(discount)}', style: AppTheme.sans(size: 12.5, weight: FontWeight.w600, color: AppColors.success)),
                      ])),
                    if (widget.serviceAmount > 0)
                      Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
                        Text(widget.serviceLabel ?? 'Обслуживание', style: AppTheme.sans(size: 12.5, weight: FontWeight.w600, color: AppColors.textSecondary)),
                        const Spacer(),
                        Text('+${groupNum(widget.serviceAmount)}', style: AppTheme.sans(size: 12.5, weight: FontWeight.w600, color: AppColors.textSecondary)),
                      ])),
                    _dashed(),
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('ИТОГО', style: AppTheme.sans(size: 13, weight: FontWeight.w700)),
                      const Spacer(),
                      Text(sum(total), style: AppTheme.serif(size: 21, weight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 6),
                    ...payLines.map((p) => Padding(padding: const EdgeInsets.symmetric(vertical: 1.5), child: Row(children: [
                      Text(p.label, style: AppTheme.sans(size: 12, color: AppColors.textSecondary)),
                      const Spacer(),
                      Text(p.value, style: AppTheme.sans(size: 12, color: AppColors.textSecondary)),
                    ]))),
                    if (change > 0) Padding(padding: const EdgeInsets.symmetric(vertical: 1.5), child: Row(children: [
                      Text('Сдача', style: AppTheme.sans(size: 12, color: AppColors.textSecondary)),
                      const Spacer(),
                      Text(groupNum(change), style: AppTheme.sans(size: 12, color: AppColors.textSecondary)),
                    ])),
                    _dashed(),
                    Center(child: Text('Спасибо! Рахмат! 🙏', style: AppTheme.sans(size: 12.5, color: AppColors.textSecondary))),
                  ]),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(height: 48, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(AppRadius.btn)), child: Text('Новый чек', style: AppTheme.sans(size: 14.5, weight: FontWeight.w600, color: Colors.white))),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: GestureDetector(
                    onTap: () => ensurePrinterAndPrint(context, widget.receipt),
                    child: Container(height: 48, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.btn), border: Border.all(color: AppColors.borderStrong)), child: Text('🖨 Печать', style: AppTheme.sans(size: 14.5, weight: FontWeight.w600))),
                  )),
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Text(k, style: AppTheme.sans(size: 12, color: AppColors.textSecondary)),
          const Spacer(),
          Text(v, style: AppTheme.sans(size: 12, weight: FontWeight.w500)),
        ]),
      );

  Widget _dashed() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: LayoutBuilder(builder: (_, c) {
          final count = (c.maxWidth / 7).floor();
          return Text('- ' * count, maxLines: 1, overflow: TextOverflow.clip, style: AppTheme.sans(size: 12, color: AppColors.borderStrong));
        }),
      );
}
