import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/ui.dart';

class HomeScreen extends StatefulWidget {
  final ValueChanged<int> onNavigate;
  const HomeScreen({super.key, required this.onNavigate});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _period = 'week'; // day | week | month
  int? _sel; // grafikda tanlangan nuqta

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final today = app.salesToday;
    final lowItems = app.ingredients.where((i) => i.low).toList();
    final venue = app.company['name'] as String;

    return Column(
      children: [
        // ── App-bar: joy nomi + qo'ng'iroq ──
        SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsets.only(left: 20, right: 16),
            child: Row(children: [
              Expanded(
                child: Text(venue,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.sans(size: 17, weight: FontWeight.w600, letterSpacing: -0.2)),
              ),
              _BellButton(onTap: () => _openNotifications(context, app, lowItems)),
            ]),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
            children: [
              // ── Salomlashuv ──
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 2),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Салом, ${(app.currentUser.name).split(' ').first} 👋',
                      style: AppTheme.serif(size: 26, weight: FontWeight.w700).copyWith(letterSpacing: -0.3)),
                  const SizedBox(height: 3),
                  Text(ruDateLong(DateTime.now()),
                      style: AppTheme.sans(size: 13.5, color: AppColors.textSecondary)),
                ]),
              ),
              const SizedBox(height: 12),

              if (app.onboardingVisible) ...[
                _OnboardingCard(onNavigate: widget.onNavigate),
                const SizedBox(height: 12),
              ],

              // ── Karta «Выручка сегодня» ──
              _RevenueTodayCard(today: today),
              const SizedBox(height: 12),

              // ── Grafik «Выручка» ──
              _ChartCard(
                period: _period,
                sel: _sel,
                series: app.chartSeries,
                onPeriod: (p) => setState(() { _period = p; _sel = null; }),
                onSelect: (i) => setState(() => _sel = i),
              ),
              const SizedBox(height: 12),

              // ── Методы оплаты ──
              _PaymentMethodsCard(methods: app.paymentMethods),
              const SizedBox(height: 12),

              // ── Популярные товары (savdo bo'lgach ko'rinadi) ──
              if (app.topProducts.isNotEmpty) ...[
                _TopProductsCard(items: app.topProducts),
                const SizedBox(height: 12),
              ],

              // ── Открытые заказы (bo'lsa ko'rinadi) ──
              if (app.openOrders.isNotEmpty)
                _OpenOrdersCard(orders: app.openOrders, onOpen: () => widget.onNavigate(1)),

              // ── Ниже лимита ──
              if (lowItems.isNotEmpty) ...[
                const SizedBox(height: 12),
                _LowStockCard(
                  item: lowItems.first,
                  extra: lowItems.length - 1,
                  onTap: () { app.skladOpenLowFilter = true; widget.onNavigate(3); },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _openNotifications(BuildContext context, AppState app, List lowItems) {
    final order = app.openOrders.isNotEmpty ? app.openOrders.first : null;
    showAppSheet(
      context,
      title: 'Уведомления',
      builder: (ctx) => Column(
        children: [
          if (lowItems.isNotEmpty)
            _NotifRow(
              emoji: '⚠️', bg: AppColors.warningSoft,
              title: '${lowItems.first.name} ниже лимита',
              desc: 'Осталось ${qty(lowItems.first.stock)} ${lowItems.first.unit} при лимите ${qty(lowItems.first.limit)} ${lowItems.first.unit}',
              time: '12 мин',
            ),
          if (order != null)
            _NotifRow(
              emoji: '🧾', bg: AppColors.bgSecondary,
              title: 'Заказ ${order.number} открыт ${order.openMinutes} мин',
              desc: '${order.type}${order.table != null ? ' · ${order.table}' : ''} · ${sum(order.sum)}',
              time: '${order.openMinutes} мин',
            ),
          if (app.trialDaysLeft != null)
            _NotifRow(
              emoji: '⏳', bg: AppColors.accentSoft,
              title: 'Пробный период до ${app.trialEndsAtLabel}',
              desc: 'Осталось ${ruDays(app.trialDaysLeft!)} — подключите тариф',
              time: 'сегодня',
            ),
          if (lowItems.isEmpty && order == null && app.trialDaysLeft == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text('Пока нет уведомлений', style: AppTheme.sans(size: 13.5, color: AppColors.textTertiary)),
            ),
        ],
      ),
    );
  }
}

class _BellButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BellButton({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Stack(alignment: Alignment.center, children: [
          const Text('🔔', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
          Positioned(
            top: 8, right: 9,
            child: Container(
              width: 7, height: 7,
              decoration: BoxDecoration(
                color: AppColors.danger,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 1.5),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _NotifRow extends StatelessWidget {
  final String emoji, title, desc, time;
  final Color bg;
  const _NotifRow({required this.emoji, required this.bg, required this.title, required this.desc, required this.time});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(11)),
          alignment: Alignment.center,
          child: Text(emoji, style: const TextStyle(fontSize: 18)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: AppTheme.sans(size: 14, weight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(desc, style: AppTheme.sans(size: 12.5, color: AppColors.textSecondary)),
        ])),
        const SizedBox(width: 8),
        Text(time, style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary)),
      ]),
    );
  }
}

// ═══════════════ Onboarding «Начало работы» ═══════════════
class _OnboardingCard extends StatelessWidget {
  final ValueChanged<int> onNavigate;
  const _OnboardingCard({required this.onNavigate});
  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final steps = [
      (done: app.products.isNotEmpty, text: 'Создайте позицию меню', tab: 2),
      (done: (app.salesToday['checks'] as int) > 0, text: 'Протестируйте продажу', tab: 1),
      (done: false, text: 'Взгляните на отчёты', tab: 4),
    ];
    final doneCount = steps.where((s) => s.done).length;
    final progress = doneCount / steps.length;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(15, 13, 8, 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Начало работы · $doneCount из ${steps.length}', style: AppTheme.sans(size: 14.5, weight: FontWeight.w700)),
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress, minHeight: 5,
                  backgroundColor: AppColors.bgSecondary,
                  valueColor: const AlwaysStoppedAnimation(AppColors.success),
                ),
              ),
            ])),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: app.hideOnboarding,
              child: const SizedBox(width: 24, height: 24, child: Icon(Icons.close, size: 15, color: AppColors.textTertiary)),
            ),
          ]),
        ),
        ...List.generate(steps.length, (i) {
          final s = steps[i];
          return InkWell(
            onTap: () => onNavigate(s.tab),
            child: Container(
              decoration: BoxDecoration(border: Border(top: BorderSide(color: i == 0 ? Colors.transparent : AppColors.border))),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              child: Row(children: [
                Container(
                  width: 21, height: 21,
                  decoration: BoxDecoration(
                    color: s.done ? AppColors.success : AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: s.done ? AppColors.success : AppColors.borderStrong, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: s.done ? const Text('✓', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)) : null,
                ),
                const SizedBox(width: 11),
                Expanded(child: Text(s.text, style: AppTheme.sans(
                  size: 13.5, weight: FontWeight.w500,
                  color: s.done ? AppColors.textTertiary : AppColors.text,
                ).copyWith(decoration: s.done ? TextDecoration.lineThrough : null))),
                const Text('›', style: TextStyle(fontSize: 15, color: AppColors.textTertiary)),
              ]),
            ),
          );
        }),
      ]),
    );
  }
}

// ═══════════════ «Выручка сегодня» ═══════════════
class _RevenueTodayCard extends StatelessWidget {
  final Map<String, dynamic> today;
  const _RevenueTodayCard({required this.today});
  @override
  Widget build(BuildContext context) {
    final growth = today['growth'] as Map<String, dynamic>;
    final rev = today['revenue'] as int;
    final revPct = growth['revenue'] as int;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
        boxShadow: kSoftShadow,
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Выручка сегодня', style: AppTheme.sans(size: 13, weight: FontWeight.w500, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Flexible(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: groupNum(rev), style: AppTheme.serif(size: 32, weight: FontWeight.w700).copyWith(letterSpacing: -0.4, height: 1)),
                TextSpan(text: ' сум', style: AppTheme.sans(size: 16, weight: FontWeight.w400, color: AppColors.textTertiary)),
              ]),
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 10),
          _PctChip(revPct),
        ]),
        Container(height: 1, color: AppColors.border, margin: const EdgeInsets.only(top: 14, bottom: 12)),
        Row(children: [
          Expanded(child: _KpiCell('Прибыль', sum(today['profit'] as int))),
          const SizedBox(width: 16),
          Expanded(child: _KpiCell('Чеки', '${today['checks']}')),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _KpiCell('Посетители', '${today['visitors']}')),
          const SizedBox(width: 16),
          Expanded(child: _KpiCell('Средний чек', sum(today['avgCheck'] as int))),
        ]),
      ]),
    );
  }
}

class _PctChip extends StatelessWidget {
  final int pct;
  const _PctChip(this.pct);
  @override
  Widget build(BuildContext context) {
    final up = pct >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: up ? AppColors.successSoft : AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text('${up ? '+' : '−'}${pct.abs()}%', style: AppTheme.sans(size: 12, weight: FontWeight.w700, color: up ? AppColors.success : AppColors.danger)),
    );
  }
}

class _KpiCell extends StatelessWidget {
  final String label, value;
  const _KpiCell(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppTheme.sans(size: 12, color: AppColors.textTertiary)),
      const SizedBox(height: 2),
      Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(size: 15.5, weight: FontWeight.w600)),
    ]);
  }
}

// ═══════════════ Grafik «Выручка» ═══════════════
class _ChartCard extends StatelessWidget {
  final String period;
  final int? sel;
  final Map<String, Map<String, dynamic>> series;
  final ValueChanged<String> onPeriod;
  final ValueChanged<int> onSelect;
  const _ChartCard({required this.period, required this.sel, required this.series, required this.onPeriod, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final s = series[period]!;
    final values = (s['values'] as List).map((e) => (e as num).toDouble()).toList();
    final total = values.fold<double>(0, (a, b) => a + b);
    final labels = (s['labels'] as List?)?.cast<String>();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
        boxShadow: kSoftShadow,
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Выручка', style: AppTheme.sans(size: 15, weight: FontWeight.w600)),
          const Spacer(),
          _PeriodSegment(period: period, onPeriod: onPeriod),
        ]),
        const SizedBox(height: 4),
        Text('${s['title']} · ${sum(total.round())}', style: AppTheme.sans(size: 12.5, color: AppColors.textTertiary)),
        const SizedBox(height: 10),
        SizedBox(
          height: 148,
          child: LayoutBuilder(builder: (ctx, box) {
            final selIdx = (sel == null || sel! >= values.length) ? values.length - 1 : sel!;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) {
                final w = box.maxWidth;
                const px = 8.0;
                final n = values.length;
                final rel = ((d.localPosition.dx - px) / ((w - 2 * px) / (n - 1))).round();
                onSelect(rel.clamp(0, n - 1));
              },
              child: CustomPaint(
                size: Size(box.maxWidth, 148),
                painter: _ChartPainter(values: values, period: period, sel: selIdx, labels: labels),
              ),
            );
          }),
        ),
      ]),
    );
  }
}

class _PeriodSegment extends StatelessWidget {
  final String period;
  final ValueChanged<String> onPeriod;
  const _PeriodSegment({required this.period, required this.onPeriod});
  @override
  Widget build(BuildContext context) {
    const opts = [('day', 'День'), ('week', 'Неделя'), ('month', 'Месяц')];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: AppColors.bgSecondary, borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: opts.map((o) {
        final active = o.$1 == period;
        return GestureDetector(
          onTap: () => onPeriod(o.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              color: active ? AppColors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: active ? AppColors.border : Colors.transparent),
              boxShadow: active ? const [BoxShadow(color: Color(0x12141413), blurRadius: 2, offset: Offset(0, 1))] : null,
            ),
            child: Text(o.$2, style: AppTheme.sans(size: 12, weight: FontWeight.w600, color: active ? AppColors.text : AppColors.textSecondary)),
          ),
        );
      }).toList()),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<double> values;
  final String period;
  final int sel;
  final List<String>? labels;
  _ChartPainter({required this.values, required this.period, required this.sel, required this.labels});

  @override
  void paint(Canvas canvas, Size size) {
    final n = values.length;
    if (n == 0) return;
    const px = 8.0;
    final chartH = size.height - 16; // pastda tick uchun joy
    final top = chartH * 34 / 132;
    final base = chartH * 118 / 132;
    final hi0 = values.reduce(math.max), lo0 = values.reduce(math.min);
    final spread = math.max(1.0, hi0 - lo0);
    final lo = lo0 - spread * 0.35, hi = hi0 + spread * 0.14;
    double xAt(int i) => px + i * (size.width - 2 * px) / (n - 1);
    double yAt(int i) => base - ((values[i] - lo) / (hi - lo)) * (base - top);
    final pts = List.generate(n, (i) => Offset(xAt(i), yAt(i)));

    // Setka
    final gridDash = Paint()..color = AppColors.border..strokeWidth = 1;
    final gridSolid = Paint()..color = AppColors.border..strokeWidth = 1;
    for (final yf in [34.0, 76.0]) {
      final y = chartH * yf / 132;
      _dashLine(canvas, Offset(px, y), Offset(size.width - px, y), gridDash);
    }
    canvas.drawLine(Offset(px, base), Offset(size.width - px, base), gridSolid);

    // Silliq yo'l (Catmull-Rom → bezier)
    final path = _smoothPath(pts, base);
    // To'ldirish
    final area = Path.from(path)
      ..lineTo(pts.last.dx, base)
      ..lineTo(pts.first.dx, base)
      ..close();
    canvas.drawPath(area, Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [Color(0x33D97757), Color(0x00D97757)],
    ).createShader(Rect.fromLTWH(0, 0, size.width, chartH)));
    // Chiziq
    canvas.drawPath(path, Paint()
      ..color = AppColors.accent..style = PaintingStyle.stroke
      ..strokeWidth = 2.5..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);

    // Tanlangan nuqta chizig'i
    final selP = pts[sel];
    _dashLine(canvas, Offset(selP.dx, selP.dy + 9), Offset(selP.dx, base),
        Paint()..color = AppColors.borderStrong..strokeWidth = 1.5);

    // Nuqtalar
    if (n <= 12) {
      for (int i = 0; i < n; i++) {
        canvas.drawCircle(pts[i], 5.5, Paint()..color = i == sel ? AppColors.accent : AppColors.surface);
        canvas.drawCircle(pts[i], 5.5, Paint()..color = AppColors.accent..style = PaintingStyle.stroke..strokeWidth = 2);
      }
    } else {
      canvas.drawCircle(selP, 5.5, Paint()..color = AppColors.accent);
      canvas.drawCircle(selP, 5.5, Paint()..color = AppColors.surface..style = PaintingStyle.stroke..strokeWidth = 2);
    }

    // Bubble (tanlangan qiymat)
    _drawBubble(canvas, size, selP, sum(values[sel].round()), _subLabel(sel, n));

    // X-o'q teglari
    _drawTicks(canvas, size, chartH, n, xAt);
  }

  String _subLabel(int i, int n) {
    final now = DateTime.now();
    if (period == 'day') return labels != null && i < labels!.length ? labels![i] : '';
    if (i == n - 1) return 'Сегодня';
    final d = now.subtract(Duration(days: n - 1 - i));
    return period == 'week' ? '${ruWeekdayShort(d)}, ${ruDayMonthShort(d)}' : ruDayMonthShort(d);
  }

  void _drawTicks(Canvas canvas, Size size, double chartH, int n, double Function(int) xAt) {
    final now = DateTime.now();
    List<int> idx;
    if (period == 'day') {
      idx = [0, 3, 6, 9, 11];
    } else if (period == 'week') {
      idx = List.generate(n, (i) => i);
    } else {
      idx = [0, 7, 14, 21, 29];
    }
    for (int k = 0; k < idx.length; k++) {
      final i = idx[k];
      if (i >= n) continue;
      final d = now.subtract(Duration(days: n - 1 - i));
      final label = period == 'day'
          ? (labels != null && i < labels!.length ? labels![i] : '')
          : (period == 'week' ? ruWeekdayShort(d) : ruDayMonthShort(d));
      final tp = TextPainter(
        text: TextSpan(text: label, style: AppTheme.sans(size: 10.5, color: AppColors.textTertiary)),
        textDirection: TextDirection.ltr,
      )..layout();
      double dx = xAt(i) - tp.width / 2;
      if (k == 0) dx = xAt(i);
      if (k == idx.length - 1) dx = size.width - tp.width;
      tp.paint(canvas, Offset(dx.clamp(0, size.width - tp.width), size.height - 13));
    }
  }

  void _drawBubble(Canvas canvas, Size size, Offset p, String text, String sub) {
    final tp1 = TextPainter(text: TextSpan(text: text, style: AppTheme.sans(size: 12, weight: FontWeight.w600, color: Colors.white)), textDirection: TextDirection.ltr)..layout();
    final tp2 = TextPainter(text: TextSpan(text: sub, style: AppTheme.sans(size: 10.5, color: Colors.white.withOpacity(0.75))), textDirection: TextDirection.ltr)..layout();
    final w = math.max(tp1.width, tp2.width) + 20;
    final h = tp1.height + tp2.height + 13;
    double left = (p.dx - w / 2).clamp(0.0, size.width - w);
    double topY = p.dy - 11 - h;
    if (topY < 0) topY = p.dy + 12;
    final rect = RRect.fromRectAndRadius(Rect.fromLTWH(left, topY, w, h), const Radius.circular(9));
    canvas.drawRRect(rect, Paint()..color = AppColors.text);
    tp1.paint(canvas, Offset(left + (w - tp1.width) / 2, topY + 5));
    tp2.paint(canvas, Offset(left + (w - tp2.width) / 2, topY + 6 + tp1.height));
  }

  Path _smoothPath(List<Offset> p, double base) {
    final path = Path()..moveTo(p[0].dx, p[0].dy);
    for (int i = 0; i < p.length - 1; i++) {
      final p0 = p[math.max(0, i - 1)], p1 = p[i], p2 = p[i + 1], p3 = p[math.min(p.length - 1, i + 2)];
      final c1y = math.min(base, p1.dy + (p2.dy - p0.dy) / 6);
      final c2y = math.min(base, p2.dy - (p3.dy - p1.dy) / 6);
      path.cubicTo(p1.dx + (p2.dx - p1.dx) / 3, c1y, p2.dx - (p2.dx - p1.dx) / 3, c2y, p2.dx, p2.dy);
    }
    return path;
  }

  void _dashLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 3.0, gap = 4.0;
    final total = (b - a).distance;
    final dir = (b - a) / total;
    double d = 0;
    while (d < total) {
      final s = a + dir * d;
      final e = a + dir * math.min(d + dash, total);
      canvas.drawLine(s, e, paint);
      d += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) => old.values != values || old.sel != sel || old.period != period;
}

// ═══════════════ Методы оплаты ═══════════════
class _PaymentMethodsCard extends StatelessWidget {
  final Map<String, int> methods;
  const _PaymentMethodsCard({required this.methods});
  @override
  Widget build(BuildContext context) {
    final total = methods.values.fold<int>(0, (a, b) => a + b);
    const colors = {'Наличные': AppColors.success, 'Карточка': AppColors.accent, 'Бонусы': AppColors.warning};
    return _WhiteCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Методы оплаты', style: AppTheme.sans(size: 15, weight: FontWeight.w600)),
        const SizedBox(height: 12),
        ...methods.entries.map((e) {
          // Haqiqiy foiz — matnda; bar uchun esa ko'rinish minimumi (2%).
          final realPct = total == 0 ? 0 : (e.value / total * 100).round();
          final barPct = e.value == 0 ? 0 : math.max(2, realPct);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text.rich(TextSpan(children: [
                  TextSpan(text: e.key, style: AppTheme.sans(size: 13, weight: FontWeight.w500, color: AppColors.textSecondary)),
                  TextSpan(text: ' · $realPct%', style: AppTheme.sans(size: 13, weight: FontWeight.w400, color: AppColors.textTertiary)),
                ])),
                const Spacer(),
                Text(sum(e.value), style: AppTheme.sans(size: 13.5, weight: FontWeight.w600)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: barPct / 100, minHeight: 6,
                  backgroundColor: AppColors.bgSecondary,
                  valueColor: AlwaysStoppedAnimation(colors[e.key] ?? AppColors.accent),
                ),
              ),
            ]),
          );
        }),
      ]),
    );
  }
}

// ═══════════════ Популярные товары ═══════════════
class _TopProductsCard extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const _TopProductsCard({required this.items});
  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Популярные товары', style: AppTheme.sans(size: 15, weight: FontWeight.w600)),
        const SizedBox(height: 4),
        ...List.generate(items.length, (i) {
          final p = items[i];
          return Container(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: i == 0 ? Colors.transparent : AppColors.border))),
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(children: [
              SizedBox(width: 14, child: Text('${i + 1}', textAlign: TextAlign.center, style: AppTheme.sans(size: 12, weight: FontWeight.w600, color: AppColors.textTertiary))),
              const SizedBox(width: 12),
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(color: AppColors.bgSecondary, borderRadius: BorderRadius.circular(11)),
                alignment: Alignment.center,
                child: Text(p['emoji'] as String? ?? '🍽️', style: const TextStyle(fontSize: 19)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p['name'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(size: 14, weight: FontWeight.w600)),
                const SizedBox(height: 1),
                Text('×${p['count']} за сегодня', style: AppTheme.sans(size: 12, color: AppColors.textTertiary)),
              ])),
              const SizedBox(width: 8),
              Text(sum(p['sum'] as int? ?? 0), style: AppTheme.sans(size: 13.5, weight: FontWeight.w600)),
            ]),
          );
        }),
      ]),
    );
  }
}

// ═══════════════ Открытые заказы ═══════════════
class _OpenOrdersCard extends StatelessWidget {
  final List orders;
  final VoidCallback onOpen;
  const _OpenOrdersCard({required this.orders, required this.onOpen});
  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Открытые заказы', style: AppTheme.sans(size: 15, weight: FontWeight.w600)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(999)),
            child: Text('${orders.length}', style: AppTheme.sans(size: 11.5, weight: FontWeight.w700, color: AppColors.accentHover)),
          ),
        ]),
        const SizedBox(height: 4),
        ...List.generate(orders.length, (i) {
          final o = orders[i];
          final mins = o.openMinutes as int;
          final warn = mins >= 5;
          final sub = '${o.type}${o.table != null ? ' · ${o.table}' : ''}';
          return InkWell(
            onTap: onOpen,
            child: Container(
              decoration: BoxDecoration(border: Border(top: BorderSide(color: i == 0 ? Colors.transparent : AppColors.border))),
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: AppColors.bgSecondary, borderRadius: BorderRadius.circular(12)),
                  alignment: Alignment.center,
                  child: Text(o.type == 'Навынос' ? '🥡' : '🍽️', style: const TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Заказ ${o.number}', style: AppTheme.sans(size: 14, weight: FontWeight.w600)),
                  const SizedBox(height: 1),
                  Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(size: 12.5, color: AppColors.textSecondary)),
                ])),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(sum(o.sum as int), style: AppTheme.sans(size: 13.5, weight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: warn ? AppColors.warningSoft : AppColors.bgSecondary, borderRadius: BorderRadius.circular(999)),
                    child: Text('$mins мин', style: AppTheme.sans(size: 11, weight: FontWeight.w600, color: warn ? AppColors.warning : AppColors.textSecondary)),
                  ),
                ]),
              ]),
            ),
          );
        }),
      ]),
    );
  }
}

// ═══════════════ Ниже лимита ═══════════════
class _LowStockCard extends StatelessWidget {
  final dynamic item;
  final int extra;
  final VoidCallback onTap;
  const _LowStockCard({required this.item, required this.extra, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final desc = 'Осталось ${qty(item.stock)} ${item.unit} при лимите ${qty(item.limit)} ${item.unit}'
        '${extra > 0 ? ' · ещё $extra' : ''} — проверьте склад';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.warningSoft,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: const Color(0xFFEFE0C4)),
        ),
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        child: Row(children: [
          const Text('⚠️', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${item.name} ниже лимита', style: AppTheme.sans(size: 14, weight: FontWeight.w600)),
            const SizedBox(height: 1),
            Text(desc, style: AppTheme.sans(size: 12.5, color: AppColors.textSecondary)),
          ])),
          const SizedBox(width: 8),
          const Text('›', style: TextStyle(fontSize: 16, color: AppColors.textTertiary)),
        ]),
      ),
    );
  }
}

// Umumiy oq karta (soya bilan).
class _WhiteCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _WhiteCard({required this.child, required this.padding});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
        boxShadow: kSoftShadow,
      ),
      child: child,
    );
  }
}
