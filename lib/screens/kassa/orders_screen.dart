import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../models.dart';
import '../../utils/format.dart';
import '../../widgets/ui.dart';
import 'kassa_controller.dart';
import 'payment_screen.dart';

class OrdersScreen extends StatefulWidget {
  final KassaController ctrl;
  final int initialTab; // 0 Заказы, 1 Архив
  const OrdersScreen({super.key, required this.ctrl, this.initialTab = 0});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late int _tab;
  int _filter = 0; // архив filtri
  String _q = '';

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.ctrl.app;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 14, 2),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(width: 38, height: 38, alignment: Alignment.center, child: const Text('‹', style: TextStyle(fontSize: 22, color: AppColors.accentHover))),
              ),
              Text('Заказы', style: AppTheme.sans(size: 17, weight: FontWeight.w700)),
              const Spacer(),
              GestureDetector(
                onTap: () { widget.ctrl.newCheck(); Navigator.pop(context); showToast(context, 'Создан чек №${widget.ctrl.active.number}'); },
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(10)),
                  child: Text('＋ Новый заказ', style: AppTheme.sans(size: 12.5, weight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ]),
          ),
          // Tabs
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Container(
              decoration: BoxDecoration(color: AppColors.bgSecondary, borderRadius: BorderRadius.circular(11)),
              padding: const EdgeInsets.all(3),
              child: Row(children: [
                Expanded(child: _tabBtn('Заказы${app.openOrders.isNotEmpty ? ' · ${app.openOrders.length}' : ''}', 0)),
                const SizedBox(width: 3),
                Expanded(child: _tabBtn('Архив чеков', 1)),
              ]),
            ),
          ),
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: SizedBox(
              height: 38,
              child: TextField(
                onChanged: (v) => setState(() => _q = v),
                style: AppTheme.sans(size: 13.5),
                decoration: InputDecoration(
                  hintText: _tab == 0 ? 'Поиск по заказам…' : 'Поиск по № чека…',
                  isDense: true, filled: true, fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  hintStyle: AppTheme.sans(size: 13.5, color: AppColors.textTertiary),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accent, width: 2)),
                ),
              ),
            ),
          ),
          Expanded(child: _tab == 0 ? _orders(app) : _archive(app)),
        ]),
      ),
    );
  }

  Widget _tabBtn(String label, int i) {
    final active = _tab == i;
    return GestureDetector(
      onTap: () => setState(() { _tab = i; _q = ''; }),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(color: active ? AppColors.surface : Colors.transparent, borderRadius: BorderRadius.circular(9), border: Border.all(color: active ? AppColors.border : Colors.transparent)),
        child: Text(label, style: AppTheme.sans(size: 13, weight: FontWeight.w600, color: active ? AppColors.text : AppColors.textSecondary)),
      ),
    );
  }

  Widget _orders(app) {
    final q = _q.trim().toLowerCase();
    final list = app.openOrders.where((o) => q.isEmpty || o.number.contains(q) || (o.table ?? '').toLowerCase().contains(q) || o.type.toLowerCase().contains(q)).toList();
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('✅', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text('Нет открытых заказов', textAlign: TextAlign.center, style: AppTheme.serif(size: 19, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Создайте новый заказ или примите гостей — всё оплачено', textAlign: TextAlign.center, style: AppTheme.sans(size: 13, height: 1.4, color: AppColors.textSecondary)),
        ]),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final OpenOrder o = list[i];
        final over = o.openMinutes > 5;
        return Container(
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.card), border: Border.all(color: AppColors.border)),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: over ? AppColors.warningSoft : AppColors.bgSecondary, borderRadius: BorderRadius.circular(8)),
                child: Text('${o.openMinutes.toString().padLeft(2, '0')}:00', style: AppTheme.sans(size: 12.5, weight: FontWeight.w700, color: over ? AppColors.warning : AppColors.textSecondary)),
              ),
              const SizedBox(width: 9),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(o.number, style: AppTheme.sans(size: 14.5, weight: FontWeight.w700)),
                Text('${o.type}${o.table != null ? ' · ${o.table}' : ''}'.toUpperCase(), style: AppTheme.sans(size: 10.5, weight: FontWeight.w600, color: AppColors.textTertiary, letterSpacing: 0.6)),
              ])),
              Text(sum(o.sum), style: AppTheme.sans(size: 14.5, weight: FontWeight.w700)),
            ]),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _payOrder(app, o),
              child: Container(
                height: 40, alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.successSoft, borderRadius: BorderRadius.circular(10)),
                child: Text('Перейти к оплате ›', style: AppTheme.sans(size: 13, weight: FontWeight.w700, color: AppColors.success)),
              ),
            ),
          ]),
        );
      },
    );
  }

  void _payOrder(app, OpenOrder o) {
    widget.ctrl.clearActive();
    for (final it in o.items) {
      final matches = app.products.where((p) => p.name == it['name']).toList();
      if (matches.isEmpty) continue; // tovar menyudan o'chirilgan bo'lishi mumkin
      widget.ctrl.active.lines.add(OrderLine(matches.first, qty: (it['qty'] as num).toDouble()));
    }
    if (widget.ctrl.active.lines.isEmpty) {
      showToast(context, 'Позиции заказа не найдены в меню', color: AppColors.warning, bg: AppColors.warningSoft, icon: Icons.warning_amber_rounded);
      return;
    }
    // Buyurtma chekka o'tdi — ochiq buyurtmalardan olib tashlanadi.
    app.openOrders.remove(o);
    app.notify();
    widget.ctrl.refresh();
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentScreen(ctrl: widget.ctrl)));
  }

  Widget _archive(app) {
    const chips = ['Все', 'Наличными', 'Карточкой', 'Возвраты'];
    final q = _q.trim().toLowerCase();
    List<Receipt> list = List<Receipt>.from(app.receiptsArchive);
    if (_filter == 1) list = list.where((r) => r.status != 'Возврат' && r.payment.contains('Налич')).toList();
    if (_filter == 2) list = list.where((r) => r.status != 'Возврат' && (r.payment.contains('Карт') || r.payment.contains('Сертиф'))).toList();
    if (_filter == 3) list = list.where((r) => r.status == 'Возврат').toList();
    if (q.isNotEmpty) list = list.where((r) => r.id.toString().contains(q)).toList();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
        child: SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: chips.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) {
              if (i == chips.length) {
                return GestureDetector(
                  onTap: () => showToast(context, 'Показаны чеки за сегодня — история по дням в «Ещё → Статистика»', color: AppColors.textSecondary, bg: AppColors.bgSecondary, icon: Icons.calendar_today_outlined),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(999), border: Border.all(color: AppColors.border)),
                    child: Text('Сегодня ▾', style: AppTheme.sans(size: 12, weight: FontWeight.w600, color: AppColors.textSecondary)),
                  ),
                );
              }
              final active = i == _filter;
              return GestureDetector(
                onTap: () => setState(() => _filter = i),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: active ? AppColors.posDark : AppColors.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: active ? AppColors.posDark : AppColors.border),
                  ),
                  child: Text(chips[i], style: AppTheme.sans(size: 12, weight: FontWeight.w600, color: active ? Colors.white : AppColors.textSecondary)),
                ),
              );
            },
          ),
        ),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
          children: [
            Container(
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.card), border: Border.all(color: AppColors.border)),
              clipBehavior: Clip.antiAlias,
              child: Column(children: [
                for (int i = 0; i < list.length; i++) _archRow(list[i], i == 0),
              ]),
            ),
            const SizedBox(height: 10),
            Center(child: Text('Показано ${list.length} из ${app.receiptsArchive.length} чеков за сегодня', style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary))),
          ],
        ),
      ),
    ]);
  }

  Widget _archRow(Receipt r, bool first) {
    final refund = r.status == 'Возврат';
    return GestureDetector(
      onTap: () => _receiptDetail(r),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(border: first ? null : const Border(top: BorderSide(color: AppColors.border))),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('№${r.id}', style: AppTheme.sans(size: 13.5, weight: FontWeight.w700)),
              Text(' · ${r.time}', style: AppTheme.sans(size: 13.5, color: AppColors.textTertiary)),
            ]),
            Text(r.payment, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary)),
          ])),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(sum(r.sum), style: AppTheme.sans(size: 13.5, weight: FontWeight.w700)),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: refund ? AppColors.dangerSoft : AppColors.successSoft, borderRadius: BorderRadius.circular(999)),
              child: Text(refund ? 'Возврат' : 'Проведён', style: AppTheme.sans(size: 10.5, weight: FontWeight.w700, color: refund ? AppColors.danger : AppColors.success)),
            ),
          ]),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, size: 16, color: AppColors.textTertiary),
        ]),
      ),
    );
  }

  void _receiptDetail(Receipt r) {
    final refund = r.status == 'Возврат';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 34 + MediaQuery.of(ctx).viewPadding.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: AppColors.borderStrong, borderRadius: BorderRadius.circular(999)), margin: const EdgeInsets.only(bottom: 16))),
            Row(children: [
              Text('Чек №${r.id}', style: AppTheme.serif(size: 20, weight: FontWeight.w700)),
              const SizedBox(width: 10),
              Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3), decoration: BoxDecoration(color: refund ? AppColors.dangerSoft : AppColors.successSoft, borderRadius: BorderRadius.circular(999)), child: Text(refund ? 'Возврат' : 'Проведён', style: AppTheme.sans(size: 11, weight: FontWeight.w700, color: refund ? AppColors.danger : AppColors.success))),
            ]),
            const SizedBox(height: 12),
            _kv('Кассир', r.waiter),
            _kv('Открыт — закрыт', r.time),
            _kv('Оплата', r.payment),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: Text(r.items, style: AppTheme.sans(size: 13, weight: FontWeight.w600))),
                  ]),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.only(top: 9),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.borderStrong, style: BorderStyle.solid))),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('ИТОГО', style: AppTheme.sans(size: 12.5, weight: FontWeight.w700)),
                    const Spacer(),
                    Text(sum(r.sum), style: AppTheme.serif(size: 18, weight: FontWeight.w700)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () { Navigator.pop(ctx); showToast(context, 'Чек отправлен на печать (демо)', color: AppColors.textSecondary, bg: AppColors.bgSecondary, icon: Icons.print); },
                child: Container(height: 48, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.btn), border: Border.all(color: AppColors.borderStrong)), child: Text('🧾 Показать чек', style: AppTheme.sans(size: 14, weight: FontWeight.w600))),
              )),
              if (!refund) ...[
                const SizedBox(width: 8),
                Expanded(child: GestureDetector(
                  onTap: () { Navigator.pop(ctx); _confirmRefund(r); },
                  child: Container(height: 48, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: BorderRadius.circular(AppRadius.btn)), child: Text('↩️ Возврат', style: AppTheme.sans(size: 14, weight: FontWeight.w600, color: AppColors.danger))),
                )),
              ],
            ]),
          ]),
        ),
      ),
    );
  }

  void _confirmRefund(Receipt r) {
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
          const Text('↩️', style: TextStyle(fontSize: 38)),
          const SizedBox(height: 6),
          Text('Оформить возврат?', style: AppTheme.serif(size: 20, weight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Чек №${r.id} на ${sum(r.sum)} будет проведён как возврат. Выручка и статистика уменьшатся.', textAlign: TextAlign.center, style: AppTheme.sans(size: 13.5, height: 1.5, color: AppColors.textSecondary)),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: () {
              Navigator.pop(ctx);
              final app = widget.ctrl.app;
              app.salesToday['revenue'] = (app.salesToday['revenue'] as int) - r.sum;
              app.salesToday['profit'] = (app.salesToday['profit'] as int) - r.profit;
              app.salesToday['checks'] = (app.salesToday['checks'] as int) - 1;
              // To'lov usuli / kassa yashigi / kassir statistikasini teskari (yaxlitlik)
              if (r.payment.contains('Налич')) {
                app.paymentMethods['Наличные'] = (app.paymentMethods['Наличные'] ?? 0) - r.sum;
                final box = app.accounts.where((a) => a.name == 'Денежный ящик').toList();
                if (box.isNotEmpty) {
                  box.first.balance -= r.sum;
                  if (app.repo.ready) app.repo.saveAccount(box.first);
                }
              } else if (r.payment.contains('Карт') || r.payment.contains('Сертиф')) {
                app.paymentMethods['Карточка'] = (app.paymentMethods['Карточка'] ?? 0) - r.sum;
              }
              final emp = app.employees.where((e) => e.name == r.waiter).toList();
              if (emp.isNotEmpty) {
                emp.first.revenue -= r.sum;
                emp.first.checks -= 1;
                if (app.repo.ready) app.repo.saveEmployee(emp.first);
              }
              // Grafik/vaqt qatorlarini ham teskari (completePayment bilan simmetrik)
              int dec(int cur) => (cur - r.sum) < 0 ? 0 : cur - r.sum;
              final rh = int.tryParse(r.time.split(':').first) ?? DateTime.now().hour;
              if (rh >= 0 && rh < 24) app.byHour[rh] = dec(app.byHour[rh]);
              const wk = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
              final wkKey = wk[(DateTime.now().weekday - 1).clamp(0, 6).toInt()];
              app.byWeekday[wkKey] = dec(app.byWeekday[wkKey] ?? 0);
              final dv = app.chartSeries['day']!['values'] as List<int>;
              final di = (rh - 9).clamp(0, dv.length - 1).toInt();
              dv[di] = dec(dv[di]);
              final wv = app.chartSeries['week']!['values'] as List<int>;
              wv[6] = dec(wv[6]);
              final mv = app.chartSeries['month']!['values'] as List<int>;
              mv[29] = dec(mv[29]);
              // Средний чек — qayta hisoblansin
              final ch = app.salesToday['checks'] as int;
              app.salesToday['avgCheck'] = ch > 0 ? ((app.salesToday['revenue'] as int) / ch).round() : 0;
              // Arxivda statusni «Возврат» ga o'zgartirish (+ Firestore write-through)
              final idx = app.receiptsArchive.indexWhere((x) => identical(x, r));
              if (idx >= 0) {
                final refunded = Receipt(id: r.id, time: r.time, waiter: r.waiter, sum: r.sum, payment: r.payment, items: r.items, profit: r.profit, status: 'Возврат', createdAt: r.createdAt);
                app.receiptsArchive[idx] = refunded;
                app.saveReceipt(refunded);
              }
              // Финансы → Транзакции: vozvratni ham yozamiz (balansga tegmasdan —
              // u yuqorida to'g'irlab bo'lindi).
              final rn = DateTime.now();
              final refundTx = TxItem(
                id: app.newTxId(),
                date: '${rn.day.toString().padLeft(2, '0')}.${rn.month.toString().padLeft(2, '0')} ${rn.hour.toString().padLeft(2, '0')}:${rn.minute.toString().padLeft(2, '0')}',
                type: 'расход',
                category: 'Продажи',
                comment: 'Возврат по чеку №${r.id}',
                amount: -r.sum,
                account: r.payment.contains('Налич') ? 'Денежный ящик' : 'Расчетный счет',
              );
              app.transactions.insert(0, refundTx);
              if (app.repo.ready) app.repo.saveTransaction(refundTx);
              app.notify();
              setState(() {});
              showToast(context, 'Возврат по чеку №${r.id} оформлен', color: AppColors.danger, bg: AppColors.dangerSoft, icon: Icons.undo);
            },
            child: Container(height: 48, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: BorderRadius.circular(AppRadius.btn)), child: Text('Оформить возврат', style: AppTheme.sans(size: 15, weight: FontWeight.w600, color: AppColors.danger))),
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

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k, style: AppTheme.sans(size: 12.5, color: AppColors.textSecondary)),
          const Spacer(),
          Flexible(child: Text(v, textAlign: TextAlign.right, style: AppTheme.sans(size: 12.5, weight: FontWeight.w500))),
        ]),
      );
}
