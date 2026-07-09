import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme.dart';
import '../../state/app_state.dart';
import '../../models.dart';
import '../../utils/format.dart';
import '../../widgets/ui.dart';

/// Статистика (Poster «Статистика») — 8 sub-tabs, prototip 1:1.
/// Продажи / Чеки / Товары / Категории / Сотрудники / ABC / Оплаты / Отзывы.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  // Sub-tab: sales/checks/items/cats/emp/abc/pays/rev
  String _tab = 'sales';
  // Период: today/week/month
  String _period = 'today';
  // Чеки filtrlari
  String _waiter = 'all';
  String _pay = 'all';
  // Товары sort: qty/rev/profit
  String _sort = 'qty';

  static const _chips = [
    ['sales', 'Продажи'],
    ['clients', 'Клиенты'],
    ['checks', 'Чеки'],
    ['items', 'Товары'],
    ['cats', 'Категории'],
    ['shops', 'Цехи'],
    ['emp', 'Сотрудники'],
    ['abc', 'ABC'],
    ['pays', 'Оплаты'],
    ['tax', 'Налоги'],
    ['rev', 'Отзывы'],
  ];

  // (_hourVals / _dayVals nol-massivlari olib tashlandi — grafiklar endi faqat
  //  AppState'dagi haqiqiy ma'lumot bilan ishlaydi.)
  static const _dayLabels = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final showPeriod = !['checks', 'rev', 'clients', 'shops', 'tax'].contains(_tab);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _statsAppBar(context),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
        children: [
          _chipRow(),
          if (showPeriod) ...[
            const SizedBox(height: 10),
            _periodControl(),
          ],
          const SizedBox(height: 10),
          ..._tabBody(app),
        ],
      ),
    );
  }

  // ─────────────────────── App-bar («‹ Ещё» + центр «Статистика») ───────────────────────
  PreferredSizeWidget _statsAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      toolbarHeight: 48,
      title: Stack(
        alignment: Alignment.center,
        children: [
          // Centered title
          Center(
            child: Text('Статистика', style: AppTheme.sans(size: 17, weight: FontWeight.w600)),
          ),
          // Back «‹ Ещё» on the left
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(8),
                splashColor: AppColors.accentSoft,
                highlightColor: AppColors.accentSoft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('‹', style: AppTheme.sans(size: 20, weight: FontWeight.w500, color: AppColors.accentHover)),
                      const SizedBox(width: 3),
                      Text('Ещё', style: AppTheme.sans(size: 14.5, weight: FontWeight.w600, color: AppColors.accentHover)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────── Chip row (8 chips) ───────────────────────
  Widget _chipRow() {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final id = _chips[i][0];
          final active = _tab == id;
          return GestureDetector(
            onTap: () => setState(() => _tab = id),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(
                color: active ? AppColors.posDark : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: active ? AppColors.posDark : AppColors.border),
              ),
              child: Text(
                _chips[i][1],
                style: AppTheme.sans(
                  size: 12.5,
                  weight: FontWeight.w600,
                  color: active ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────── Период control (segmented) ───────────────────────
  Widget _periodControl() {
    const items = [
      ['today', 'Сегодня'],
      ['week', 'Неделя'],
      ['month', 'Месяц'],
    ];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(11),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _period = items[i][0]),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: _period == items[i][0] ? AppColors.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: _period == items[i][0] ? AppColors.border : Colors.transparent,
                    ),
                    boxShadow: _period == items[i][0] ? kSoftShadow : null,
                  ),
                  child: Text(
                    items[i][1],
                    style: AppTheme.sans(
                      size: 12.5,
                      weight: FontWeight.w600,
                      color: _period == items[i][0] ? AppColors.text : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────── Body dispatcher ───────────────────────
  List<Widget> _tabBody(AppState app) {
    switch (_tab) {
      case 'sales':
        return _salesBody(app);
      case 'clients':
        return _clientsBody(app);
      case 'checks':
        return _checksBody(app);
      case 'items':
        return _itemsBody(app);
      case 'cats':
        return _catsBody(app);
      case 'shops':
        return _shopsBody(app);
      case 'emp':
        return _empBody(app);
      case 'abc':
        return _abcBody(app);
      case 'pays':
        return _paysBody(app);
      case 'tax':
        return _taxBody(app);
      case 'rev':
        return _revBody();
      default:
        return const [SizedBox()];
    }
  }

  // ════════════════════════ ПРОДАЖИ ════════════════════════
  List<Widget> _salesBody(AppState app) {
    final t = app.salesToday;
    final baseRev = t['revenue'] as int; // 2 480 000
    final baseProfit = t['profit'] as int; // 1 315 000
    final baseChecks = t['checks'] as int; // 38
    final baseVisitors = t['visitors'] as int; // 52

    int revenue, profit, checks, visitors;
    if (_period == 'today') {
      revenue = baseRev;
      profit = baseProfit;
      checks = baseChecks;
      visitors = baseVisitors;
    } else {
      // Real seriyalar (kassa savdolaridan to'ladi), nol-holatda 0.
      final weekSum = (app.chartSeries['week']!['values'] as List<int>).reduce((a, b) => a + b);
      final monthSum = (app.chartSeries['month']!['values'] as List<int>).reduce((a, b) => a + b);
      final s = _period == 'week' ? weekSum : monthSum;
      revenue = s;
      if (baseRev > 0) {
        profit = (baseProfit * s / baseRev).round();
        checks = (baseChecks * s / baseRev).round();
        visitors = (baseVisitors * s / baseRev).round();
      } else {
        profit = 0;
        checks = 0;
        visitors = 0;
      }
    }
    final avg = checks == 0 ? 0 : (revenue / checks).round();

    return [
      // (a) KPI card
      _surfaceCard(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Выручка', style: AppTheme.sans(size: 13, weight: FontWeight.w500, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text.rich(TextSpan(
              children: [
                TextSpan(text: groupNum(revenue), style: AppTheme.serif(size: 30, weight: FontWeight.w700)),
                TextSpan(text: ' сум', style: AppTheme.sans(size: 15, weight: FontWeight.w400, color: AppColors.textTertiary)),
              ],
            )),
            Container(height: 1, color: AppColors.border, margin: const EdgeInsets.fromLTRB(0, 13, 0, 11)),
            Row(children: [
              Expanded(child: _miniStat('Прибыль', groupNum(profit))),
              const SizedBox(width: 16),
              Expanded(child: _miniStat('Чеки', '$checks')),
            ]),
            const SizedBox(height: 11),
            Row(children: [
              Expanded(child: _miniStat('Средний чек', groupNum(avg))),
              const SizedBox(width: 16),
              Expanded(child: _miniStat('Гости', '$visitors')),
            ]),
          ],
        ),
      ),
      const SizedBox(height: 10),
      // (b) По времени — 24 thin bars
      _surfaceCard(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('По времени', style: AppTheme.sans(size: 14.5, weight: FontWeight.w600)),
            const SizedBox(height: 12),
            _hourHistogram(app.byHour),
          ],
        ),
      ),
      const SizedBox(height: 10),
      // (c) По дням недели — birlik (сум/тыс/млн) maksimumga qarab tanlanadi.
      // Ilgari doim «млн сум» edi: kichik kafeda 10 000 сум → «0,0» ko'rinardi.
      _surfaceCard(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 12),
        child: Builder(builder: (_) {
          final dayVals = _dayLabels.map((d) => app.byWeekday[d] ?? 0).toList();
          final dayMax = dayVals.fold<int>(0, (a, b) => a > b ? a : b);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(TextSpan(children: [
                TextSpan(text: 'По дням недели', style: AppTheme.sans(size: 14.5, weight: FontWeight.w600)),
                TextSpan(text: ' · ${_unitLabel(dayMax)}', style: AppTheme.sans(size: 11.5, weight: FontWeight.w500, color: AppColors.textTertiary)),
              ])),
              const SizedBox(height: 12),
              _dayHistogram(dayVals),
            ],
          );
        }),
      ),
    ];
  }

  Widget _miniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.sans(size: 12, color: AppColors.textTertiary)),
        const SizedBox(height: 2),
        Text(value, style: AppTheme.sans(size: 15, weight: FontWeight.w600)),
      ],
    );
  }

  Widget _hourHistogram(List<int> source) {
    final _hourVals = source;
    final hMax0 = _hourVals.reduce((a, b) => a > b ? a : b);
    final hMax = hMax0 == 0 ? 1 : hMax0;
    return Column(
      children: [
        SizedBox(
          height: 76,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (int i = 0; i < _hourVals.length; i++) ...[
                if (i > 0) const SizedBox(width: 2.5),
                Expanded(
                  child: Container(
                    height: (_hourVals[i] / hMax * 72).clamp(2, 72).toDouble(),
                    decoration: BoxDecoration(
                      color: _hourVals[i] == hMax
                          ? AppColors.accent
                          : (_hourVals[i] > 0 ? const Color(0xFFE8C4B4) : AppColors.bgSecondary),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (int i = 0; i < _hourVals.length; i++) ...[
              if (i > 0) const SizedBox(width: 2.5),
              Expanded(
                child: Text(
                  i % 3 == 0 ? '$i' : '',
                  textAlign: TextAlign.center,
                  style: AppTheme.sans(size: 8.5, color: AppColors.textTertiary),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// Maksimumga qarab o'lchov birligi: сум → тыс сум → млн сум.
  static String _unitLabel(int max) =>
      max >= 1000000 ? 'млн сум' : (max >= 1000 ? 'тыс сум' : 'сум');

  /// Ustun tepasidagi son uchun bo'luvchi (birlik bilan mos).
  static int _unitDiv(int max) => max >= 1000000 ? 1000000 : (max >= 1000 ? 1000 : 1);

  Widget _dayHistogram(List<int> source) {
    final dayVals = source;
    final dMax0 = dayVals.reduce((a, b) => a > b ? a : b);
    final dMax = dMax0 == 0 ? 1 : dMax0;
    final div = _unitDiv(dMax0);
    return Column(
      children: [
        SizedBox(
          height: 92,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (int i = 0; i < dayVals.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        div == 1
                            ? '${dayVals[i]}'
                            : (dayVals[i] / div).toStringAsFixed(1).replaceAll('.', ','),
                        style: AppTheme.sans(size: 9.5, weight: FontWeight.w600, color: AppColors.textTertiary),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        width: double.infinity,
                        height: (dayVals[i] / dMax * 72).clamp(4, 72).toDouble(),
                        decoration: BoxDecoration(
                          color: dayVals[i] == dMax ? AppColors.accent : const Color(0xFFE8C4B4),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            for (int i = 0; i < _dayLabels.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _dayLabels[i],
                  textAlign: TextAlign.center,
                  style: AppTheme.sans(size: 10, weight: FontWeight.w600, color: AppColors.textSecondary),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  // ════════════════════════ ЧЕКИ ════════════════════════
  List<Widget> _checksBody(AppState app) {
    const waiterChips = [
      ['all', 'Все'],
      ['Жафар', 'Жафар'],
      ['Азиз', 'Азиз'],
      ['Малика', 'Малика'],
    ];
    const payChips = [
      ['all', 'Все оплаты'],
      ['Налич', '💵 Нал'],
      ['Карт', '💳 Карта'],
      ['Бонус', '💎 Бонусы'],
    ];

    final rows = app.receiptsArchive.where((r) {
      final okWaiter = _waiter == 'all' || r.waiter.contains(_waiter);
      final okPay = _pay == 'all' || r.payment.contains(_pay);
      return okWaiter && okPay;
    }).toList();

    return [
      _pillFilterRow(
        waiterChips,
        _waiter,
        (id) => setState(() => _waiter = id),
      ),
      const SizedBox(height: 6),
      _pillFilterRow(
        payChips,
        _pay,
        (id) => setState(() => _pay = id),
      ),
      const SizedBox(height: 10),
      _surfaceCard(
        padding: EdgeInsets.zero,
        child: rows.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                child: Text(
                  'По выбранным фильтрам чеков нет',
                  textAlign: TextAlign.center,
                  style: AppTheme.sans(size: 12.5, color: AppColors.textTertiary),
                ),
              )
            : Column(
                children: [
                  for (int i = 0; i < rows.length; i++) _checkRow(rows[i], top: i > 0),
                ],
              ),
      ),
    ];
  }

  Widget _checkRow(Receipt r, {required bool top}) {
    final refund = r.status == 'Возврат';
    return InkWell(
      onTap: () => showToast(context, 'Чек №${r.id}',
          color: AppColors.textSecondary, bg: AppColors.bgSecondary, icon: Icons.receipt_long),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          border: Border(top: top ? const BorderSide(color: AppColors.border) : BorderSide.none),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(TextSpan(children: [
                    TextSpan(text: '№${r.id} ', style: AppTheme.sans(size: 13.5, weight: FontWeight.w700)),
                    TextSpan(text: '· ${r.time}', style: AppTheme.sans(size: 13.5, weight: FontWeight.w500, color: AppColors.textTertiary)),
                  ])),
                  const SizedBox(height: 1),
                  Text(r.waiter, style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text.rich(TextSpan(children: [
                  TextSpan(text: groupNum(r.sum), style: AppTheme.sans(size: 13.5, weight: FontWeight.w700)),
                  const TextSpan(text: '  '),
                  TextSpan(text: '+${groupNum(r.profit < 0 ? 0 : r.profit)}', style: AppTheme.sans(size: 11, weight: FontWeight.w600, color: AppColors.success)),
                ])),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: refund ? AppColors.dangerSoft : AppColors.successSoft,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    refund ? 'Возврат' : 'Проведён',
                    style: AppTheme.sans(size: 10.5, weight: FontWeight.w700, color: refund ? AppColors.danger : AppColors.success),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 6),
            Text('›', style: AppTheme.sans(size: 15, color: AppColors.textTertiary)),
          ],
        ),
      ),
    );
  }

  // ════════════════════════ ТОВАРЫ ════════════════════════
  List<Widget> _itemsBody(AppState app) {
    // topProducts + products (narx/tannarx) → выручка/прибыль.
    final rows = app.topProducts.map((p) {
      final name = p['name'] as String;
      final prod = _matchProduct(app, name);
      final count = p['count'] as int;
      final price = prod?.price ?? 0;
      final cost = prod?.cost ?? 0;
      return _ItemAgg(
        emoji: p['emoji'] as String,
        name: name,
        count: count,
        rev: price * count,
        profit: (price - cost) * count,
      );
    }).toList();

    // Sort
    rows.sort((a, b) {
      switch (_sort) {
        case 'rev':
          return b.rev.compareTo(a.rev);
        case 'profit':
          return b.profit.compareTo(a.profit);
        default:
          return b.count.compareTo(a.count);
      }
    });

    const sortCols = [
      ['qty', 'Кол-во'],
      ['rev', 'Выручка'],
      ['profit', 'Прибыль'],
    ];

    if (rows.isEmpty) {
      return [
        _surfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: Text('Пока нет продаж — проведите первый чек на Кассе', textAlign: TextAlign.center, style: AppTheme.sans(size: 12.5, color: AppColors.textTertiary)),
        ),
      ];
    }

    return [
      _surfaceCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            // Header grid
            Container(
              padding: const EdgeInsets.fromLTRB(13, 10, 13, 8),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
              child: Row(
                children: [
                  Expanded(child: _colHead('Товар', TextAlign.left)),
                  for (final c in sortCols)
                    SizedBox(
                      width: c[0] == 'qty' ? 58 : (c[0] == 'rev' ? 76 : 72),
                      child: GestureDetector(
                        onTap: () => setState(() => _sort = c[0]),
                        behavior: HitTestBehavior.opaque,
                        child: Text(
                          (_sort == c[0] ? '↓ ' : '') + c[1],
                          textAlign: TextAlign.right,
                          style: AppTheme.sans(
                            size: 10,
                            weight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: _sort == c[0] ? AppColors.accentHover : AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            for (int i = 0; i < rows.length; i++) _itemRow(rows[i], top: i > 0),
          ],
        ),
      ),
      const SizedBox(height: 8),
      _footNote('Тапните по заголовку колонки, чтобы отсортировать'),
    ];
  }

  Widget _itemRow(_ItemAgg r, {required bool top}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: top ? const BorderSide(color: AppColors.border) : BorderSide.none),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${r.emoji} ${r.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.sans(size: 12.5, weight: FontWeight.w600),
            ),
          ),
          SizedBox(width: 58, child: Text('×${r.count}', textAlign: TextAlign.right, style: AppTheme.sans(size: 12.5, color: AppColors.textSecondary))),
          SizedBox(width: 76, child: Text(groupNum(r.rev), textAlign: TextAlign.right, style: AppTheme.sans(size: 12.5, weight: FontWeight.w600))),
          SizedBox(width: 72, child: Text(groupNum(r.profit), textAlign: TextAlign.right, style: AppTheme.sans(size: 12.5, weight: FontWeight.w600, color: AppColors.success))),
        ],
      ),
    );
  }

  // ════════════════════════ КАТЕГОРИИ ════════════════════════
  List<Widget> _catsBody(AppState app) {
    // Har kategoriya bo'yicha sotilgan tovarlar: qty, revenue, cost → food-cost.
    final Map<int, _CatAgg> catMap = {};
    for (final p in app.topProducts) {
      final prod = _matchProduct(app, p['name'] as String);
      if (prod == null) continue;
      final count = p['count'] as int;
      final agg = catMap.putIfAbsent(prod.categoryId, () => _CatAgg());
      agg.qty += count;
      agg.rev += prod.price * count;
      agg.cost += prod.cost * count;
    }

    final cats = app.categories.where((c) => catMap.containsKey(c.id)).toList();

    if (cats.isEmpty) {
      return [
        _surfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: Text('Пока нет продаж по категориям', textAlign: TextAlign.center, style: AppTheme.sans(size: 12.5, color: AppColors.textTertiary)),
        ),
      ];
    }

    return [
      _surfaceCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (int i = 0; i < cats.length; i++) _catRow(app, cats[i], catMap[cats[i].id]!, top: i > 0),
          ],
        ),
      ),
      const SizedBox(height: 8),
      _footNote('Food cost — доля себестоимости в выручке: до 30% — норма, выше 40% — пересмотрите цены', padH: 14),
    ];
  }

  Widget _catRow(AppState app, Category c, _CatAgg d, {required bool top}) {
    final fc = d.rev == 0 ? 0 : (d.cost / d.rev * 100).round();
    final color = fc < 30 ? AppColors.success : (fc <= 40 ? AppColors.warning : AppColors.danger);
    final bg = fc < 30 ? AppColors.successSoft : (fc <= 40 ? AppColors.warningSoft : AppColors.dangerSoft);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        border: Border(top: top ? const BorderSide(color: AppColors.border) : BorderSide.none),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.bgSecondary, borderRadius: BorderRadius.circular(10)),
            child: Text(_catEmoji(c), style: const TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.name, style: AppTheme.sans(size: 13, weight: FontWeight.w600)),
                const SizedBox(height: 1),
                Text('×${d.qty} · ${groupNum(d.rev)} сум', style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
            child: Text('FC $fc%', style: AppTheme.sans(size: 11, weight: FontWeight.w700, color: color)),
          ),
        ],
      ),
    );
  }

  // ════════════════════════ СОТРУДНИКИ ════════════════════════
  List<Widget> _empBody(AppState app) {
    // Real xodimlar ro'yxati (revenue/checks — savdo bilan to'ladi).
    final rows = app.employees
        .map((e) => _EmpAgg(name: e.name, rev: e.revenue, ch: e.checks))
        .toList()
      ..sort((a, b) => b.rev.compareTo(a.rev));
    final best = rows.isNotEmpty && rows.first.rev > 0 ? rows.first : null;

    return [
      if (best != null) ...[
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.accentSoft,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: const Color(0xFFEBCDBE)),
          ),
          child: Row(
            children: [
              const Text('🏆', style: TextStyle(fontSize: 30)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ЛУЧШИЙ СОТРУДНИК',
                        style: AppTheme.sans(size: 11, weight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.accentHover)),
                    const SizedBox(height: 2),
                    Text(best.name, style: AppTheme.sans(size: 15, weight: FontWeight.w700)),
                    const SizedBox(height: 1),
                    Text('Выручка — ${sum(best.rev)}', style: AppTheme.sans(size: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
      _surfaceCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (int i = 0; i < rows.length; i++) _empRow(rows[i], top: i > 0),
          ],
        ),
      ),
      if (rows.every((r) => r.rev == 0)) ...[
        const SizedBox(height: 8),
        _footNote('Выручка появится после первых продаж на Кассе'),
      ],
    ];
  }

  Widget _empRow(_EmpAgg e, {required bool top}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        border: Border(top: top ? const BorderSide(color: AppColors.border) : BorderSide.none),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.bgSecondary, shape: BoxShape.circle),
            child: Text(_initials(e.name), style: AppTheme.sans(size: 13, weight: FontWeight.w700, color: AppColors.textSecondary)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.name, style: AppTheme.sans(size: 13.5, weight: FontWeight.w600)),
                const SizedBox(height: 1),
                Text('${e.ch} ${_plural(e.ch, 'чек', 'чека', 'чеков')} · средний ${sum(e.ch == 0 ? 0 : (e.rev / e.ch).round())}',
                    style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary)),
              ],
            ),
          ),
          Text(groupNum(e.rev), style: AppTheme.sans(size: 13.5, weight: FontWeight.w700)),
        ],
      ),
    );
  }

  // ════════════════════════ ABC ════════════════════════
  List<Widget> _abcBody(AppState app) {
    if (app.abc.isEmpty) {
      return [
        _surfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: Text('ABC-анализ появится после накопления продаж', textAlign: TextAlign.center, style: AppTheme.sans(size: 12.5, color: AppColors.textTertiary)),
        ),
      ];
    }
    return [
      _surfaceCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(13, 10, 13, 8),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
              child: Row(
                children: [
                  Expanded(child: _colHead('Товар', TextAlign.left)),
                  SizedBox(width: 52, child: _colHead('Прод.', TextAlign.right)),
                  SizedBox(width: 56, child: _colHead('Выручка', TextAlign.right)),
                  SizedBox(width: 56, child: _colHead('Прибыль', TextAlign.right)),
                  const SizedBox(width: 30),
                ],
              ),
            ),
            for (int i = 0; i < app.abc.length; i++) _abcRow(app.abc[i], top: i > 0),
          ],
        ),
      ),
      const SizedBox(height: 10),
      // Explainer
      _surfaceCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Text.rich(
          TextSpan(
            style: AppTheme.sans(size: 12, height: 1.55, color: AppColors.textSecondary),
            children: [
              TextSpan(text: 'A', style: AppTheme.sans(size: 12, weight: FontWeight.w700, color: AppColors.success)),
              const TextSpan(text: ' — локомотивы: дают 80% выручки, держите в наличии. '),
              TextSpan(text: 'B', style: AppTheme.sans(size: 12, weight: FontWeight.w700, color: AppColors.warning)),
              const TextSpan(text: ' — середина: можно продвигать. '),
              TextSpan(text: 'C', style: AppTheme.sans(size: 12, weight: FontWeight.w700, color: AppColors.danger)),
              const TextSpan(text: ' — кандидаты на замену или пересмотр цены.'),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _abcRow(Map<String, dynamic> r, {required bool top}) {
    final g = r['group'] as String;
    final color = g == 'A' ? AppColors.success : (g == 'B' ? AppColors.warning : AppColors.danger);
    final bg = g == 'A' ? AppColors.successSoft : (g == 'B' ? AppColors.warningSoft : AppColors.dangerSoft);
    String pct(dynamic v) => '${(v as num).round()}%';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        border: Border(top: top ? const BorderSide(color: AppColors.border) : BorderSide.none),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(r['name'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(size: 12.5, weight: FontWeight.w600)),
          ),
          SizedBox(width: 52, child: Text(pct(r['salesPct']), textAlign: TextAlign.right, style: AppTheme.sans(size: 12, color: AppColors.textSecondary))),
          SizedBox(width: 56, child: Text(pct(r['revenuePct']), textAlign: TextAlign.right, style: AppTheme.sans(size: 12, color: AppColors.textSecondary))),
          SizedBox(width: 56, child: Text(pct(r['profitPct']), textAlign: TextAlign.right, style: AppTheme.sans(size: 12, color: AppColors.textSecondary))),
          SizedBox(
            width: 30,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
                child: Text(g, style: AppTheme.sans(size: 11.5, weight: FontWeight.w800, color: color)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════ ОПЛАТЫ ════════════════════════
  List<Widget> _paysBody(AppState app) {
    final rows = <_PayRow>[];
    // Oldingi 6 kun — HAQIQIY cheklardan (receiptsArchive) hisoblanadi.
    // Ilgari bu yerda hardcode nol massiv va soxta 60%/40% naqd/karta bo'linishi
    // ishlatilardi — hisobot o'ylab topilgan raqamlarni ko'rsatardi.
    final now = DateTime.now();
    for (int i = 6; i >= 1; i--) {
      final d = DateTime(now.year, now.month, now.day - i);
      int checks = 0, cash = 0, card = 0, total = 0;
      for (final r in app.receiptsArchive) {
        final c = r.createdAt;
        if (c == null || r.status == 'Возврат') continue;
        if (c.year != d.year || c.month != d.month || c.day != d.day) continue;
        checks++;
        total += r.sum;
        // Aralash to'lovda (masalan «Наличными + Карточкой») summalar chekda
        // saqlanmagan — shuning uchun faqat bitta usulli cheklar taqsimlanadi.
        final mixed = r.payment.contains('+');
        if (!mixed && r.payment.contains('Наличными')) cash += r.sum;
        if (!mixed && r.payment.contains('Карточкой')) card += r.sum;
      }
      rows.add(_PayRow(
        day: '${ruWeekdayShort(d)}, ${ruDayMonthShort(d)}',
        checks: checks,
        cash: cash,
        card: card,
        total: total,
        bold: false,
      ));
    }
    // Today (bold)
    rows.add(_PayRow(
      day: 'Сегодня',
      checks: app.salesToday['checks'] as int,
      cash: app.paymentMethods['Наличные'] ?? 0,
      card: app.paymentMethods['Карточка'] ?? 0,
      total: app.salesToday['revenue'] as int,
      bold: true,
    ));

    return [
      _surfaceCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(13, 10, 13, 8),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
              child: Row(
                children: [
                  Expanded(child: _colHead('День', TextAlign.left)),
                  SizedBox(width: 40, child: _colHead('Чеки', TextAlign.right)),
                  SizedBox(width: 72, child: _colHead('💵 Нал', TextAlign.right)),
                  SizedBox(width: 72, child: _colHead('💳 Карта', TextAlign.right)),
                  SizedBox(width: 76, child: _colHead('Всего', TextAlign.right)),
                ],
              ),
            ),
            for (int i = 0; i < rows.length; i++) _payRow(rows[i], top: i > 0),
          ],
        ),
      ),
    ];
  }

  Widget _payRow(_PayRow r, {required bool top}) {
    final w = r.bold ? FontWeight.w700 : FontWeight.w500;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: top ? const BorderSide(color: AppColors.border) : BorderSide.none),
      ),
      child: Row(
        children: [
          Expanded(child: Text(r.day, style: AppTheme.sans(size: 12, weight: w))),
          SizedBox(width: 40, child: Text('${r.checks}', textAlign: TextAlign.right, style: AppTheme.sans(size: 12, weight: w, color: AppColors.textSecondary))),
          SizedBox(width: 72, child: Text(groupNum(r.cash), textAlign: TextAlign.right, style: AppTheme.sans(size: 11.5, weight: w))),
          SizedBox(width: 72, child: Text(groupNum(r.card), textAlign: TextAlign.right, style: AppTheme.sans(size: 11.5, weight: w))),
          SizedBox(width: 76, child: Text(groupNum(r.total), textAlign: TextAlign.right, style: AppTheme.sans(size: 12, weight: w))),
        ],
      ),
    );
  }

  // ════════════════════════ ОТЗЫВЫ ════════════════════════
  List<Widget> _revBody() {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 70, 24, 20),
        child: Column(
          children: [
            Container(
              width: 96,
              height: 96,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: AppColors.bgSecondary, shape: BoxShape.circle),
              child: const Text('💬', style: TextStyle(fontSize: 42)),
            ),
            const SizedBox(height: 18),
            Text('Отзывов пока нет', textAlign: TextAlign.center, style: AppTheme.serif(size: 21, weight: FontWeight.w700)),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 270),
              child: Text(
                'Подключите QR-меню — гости смогут оставлять отзывы прямо со стола, а вы увидите их здесь.',
                textAlign: TextAlign.center,
                style: AppTheme.sans(size: 13.5, height: 1.55, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              'Попробовать',
              expand: false,
              onPressed: () => showToast(
                context,
                'Установите Xposter QR: Ещё → Приложения',
                color: AppColors.accentHover,
                bg: AppColors.accentSoft,
                icon: Icons.qr_code,
              ),
            ),
          ],
        ),
      ),
    ];
  }

  // ════════════════════════ КЛИЕНТЫ ════════════════════════
  List<Widget> _clientsBody(AppState app) {
    final rows = List<Client>.from(app.clients)..sort((a, b) => b.totalSpent.compareTo(a.totalSpent));
    if (rows.isEmpty) {
      return [
        _surfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: Text('Клиентов пока нет — добавьте в разделе «Маркетинг»', textAlign: TextAlign.center, style: AppTheme.sans(size: 12.5, color: AppColors.textTertiary)),
        ),
      ];
    }
    return [
      _surfaceCard(
        padding: EdgeInsets.zero,
        child: Column(children: [
          Container(
            padding: const EdgeInsets.fromLTRB(13, 10, 13, 8),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
            child: Row(children: [
              Expanded(child: _colHead('Клиент', TextAlign.left)),
              SizedBox(width: 92, child: _colHead('Покупки', TextAlign.right)),
              SizedBox(width: 66, child: _colHead('Бонусы', TextAlign.right)),
            ]),
          ),
          for (int i = 0; i < rows.length; i++) _clientStatRow(rows[i], top: i > 0),
        ]),
      ),
      const SizedBox(height: 8),
      _footNote('«Покупки» — сумма всех оплаченных чеков клиента (растёт при продаже на Кассе)'),
    ];
  }

  Widget _clientStatRow(Client c, {required bool top}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(border: Border(top: top ? const BorderSide(color: AppColors.border) : BorderSide.none)),
      child: Row(children: [
        Container(width: 34, height: 34, alignment: Alignment.center, decoration: const BoxDecoration(color: AppColors.bgSecondary, shape: BoxShape.circle), child: Text(c.initials, style: AppTheme.sans(size: 12, weight: FontWeight.w700, color: AppColors.textSecondary))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(size: 13, weight: FontWeight.w600)),
          Text('${c.group} · ${c.phone}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(size: 11, color: AppColors.textTertiary)),
        ])),
        SizedBox(width: 92, child: Text(groupNum(c.totalSpent), textAlign: TextAlign.right, style: AppTheme.sans(size: 12.5, weight: FontWeight.w700))),
        SizedBox(width: 66, child: Text(groupNum(c.bonus), textAlign: TextAlign.right, style: AppTheme.sans(size: 12, color: AppColors.accentHover))),
      ]),
    );
  }

  // ════════════════════════ ЦЕХИ ════════════════════════
  List<Widget> _shopsBody(AppState app) {
    final Map<String, _CatAgg> byShop = {};
    for (final p in app.topProducts) {
      final prod = _matchProduct(app, p['name'] as String);
      final count = p['count'] as int;
      final ws = (prod?.workshop == null || prod!.workshop!.isEmpty) ? 'Без цеха' : prod.workshop!;
      final agg = byShop.putIfAbsent(ws, () => _CatAgg());
      agg.qty += count;
      agg.rev += (prod?.price ?? 0) * count;
      agg.cost += (prod?.cost ?? 0) * count;
    }
    if (byShop.isEmpty) {
      return [
        _surfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: Text('Пока нет продаж по цехам', textAlign: TextAlign.center, style: AppTheme.sans(size: 12.5, color: AppColors.textTertiary)),
        ),
      ];
    }
    final entries = byShop.entries.toList()..sort((a, b) => b.value.rev.compareTo(a.value.rev));
    return [
      _surfaceCard(
        padding: EdgeInsets.zero,
        child: Column(children: [
          Container(
            padding: const EdgeInsets.fromLTRB(13, 10, 13, 8),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
            child: Row(children: [
              Expanded(child: _colHead('Цех', TextAlign.left)),
              SizedBox(width: 48, child: _colHead('Кол-во', TextAlign.right)),
              SizedBox(width: 84, child: _colHead('Выручка', TextAlign.right)),
              SizedBox(width: 76, child: _colHead('Прибыль', TextAlign.right)),
            ]),
          ),
          for (int i = 0; i < entries.length; i++) _shopRow(entries[i].key, entries[i].value, top: i > 0),
        ]),
      ),
    ];
  }

  Widget _shopRow(String name, _CatAgg d, {required bool top}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(border: Border(top: top ? const BorderSide(color: AppColors.border) : BorderSide.none)),
      child: Row(children: [
        Container(width: 34, height: 34, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.bgSecondary, borderRadius: BorderRadius.circular(10)), child: Text(name == 'Бар' ? '🍹' : (name == 'Кухня' ? '🍳' : '🏭'), style: const TextStyle(fontSize: 15))),
        const SizedBox(width: 10),
        Expanded(child: Text(name, style: AppTheme.sans(size: 13, weight: FontWeight.w600))),
        SizedBox(width: 48, child: Text('×${d.qty}', textAlign: TextAlign.right, style: AppTheme.sans(size: 12.5, color: AppColors.textSecondary))),
        SizedBox(width: 84, child: Text(groupNum(d.rev), textAlign: TextAlign.right, style: AppTheme.sans(size: 12.5, weight: FontWeight.w600))),
        SizedBox(width: 76, child: Text(groupNum(d.rev - d.cost), textAlign: TextAlign.right, style: AppTheme.sans(size: 12.5, weight: FontWeight.w600, color: AppColors.success))),
      ]),
    );
  }

  // ════════════════════════ НАЛОГИ ════════════════════════
  List<Widget> _taxBody(AppState app) {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 50, 24, 20),
        child: Column(children: [
          Container(width: 88, height: 88, alignment: Alignment.center, decoration: const BoxDecoration(color: AppColors.bgSecondary, shape: BoxShape.circle), child: const Text('🧾', style: TextStyle(fontSize: 38))),
          const SizedBox(height: 16),
          Text('Налоги не настроены', textAlign: TextAlign.center, style: AppTheme.serif(size: 20, weight: FontWeight.w700)),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text('В демо-версии налоговые ставки не заданы, поэтому налог не рассчитывается. После настройки ставок здесь появится разбивка по чекам.', textAlign: TextAlign.center, style: AppTheme.sans(size: 13, height: 1.5, color: AppColors.textSecondary)),
          ),
        ]),
      ),
    ];
  }

  // ─────────────────────── Umumiy yordamchilar ───────────────────────
  Widget _surfaceCard({required Widget child, required EdgeInsetsGeometry padding}) {
    return Container(
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
        boxShadow: kSoftShadow,
      ),
      child: child,
    );
  }

  Widget _pillFilterRow(List<List<String>> items, String selected, ValueChanged<String> onTap) {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final id = items[i][0];
          final active = selected == id;
          return GestureDetector(
            onTap: () => onTap(id),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: active ? AppColors.posDark : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: active ? AppColors.posDark : AppColors.border),
              ),
              child: Text(
                items[i][1],
                style: AppTheme.sans(size: 12, weight: FontWeight.w600, color: active ? Colors.white : AppColors.textSecondary),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _colHead(String label, TextAlign align) => Text(
        label,
        textAlign: align,
        style: AppTheme.sans(size: 10, weight: FontWeight.w700, letterSpacing: 0.4, color: AppColors.textTertiary),
      );

  Widget _footNote(String text, {double padH = 0}) => Padding(
        padding: EdgeInsets.symmetric(horizontal: padH),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary),
        ),
      );

  // topProducts nomini products bilan moslash (nom aniq mos kelmasa — contains fallback).
  Product? _matchProduct(AppState app, String name) {
    for (final p in app.products) {
      if (p.name == name) return p;
    }
    for (final p in app.products) {
      if (p.name.startsWith(name) || name.startsWith(p.name) || p.name.contains(name) || name.contains(p.name)) return p;
    }
    return null;
  }

  String _catEmoji(Category c) {
    switch (c.id) {
      case 1:
        return '🍚';
      case 2:
        return '🍢';
      case 3:
        return '🥗';
      case 4:
        return '🥧';
      case 5:
        return '🫖';
      case 6:
        return '🥤';
      default:
        return '🍽️';
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
    return name.isNotEmpty ? name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase() : '?';
  }

  String _plural(int n, String one, String few, String many) {
    final mod10 = n % 10, mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return one;
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) return few;
    return many;
  }
}

// ─────────────────────── Yordamchi model klasslar ───────────────────────
class _ItemAgg {
  final String emoji, name;
  final int count, rev, profit;
  _ItemAgg({required this.emoji, required this.name, required this.count, required this.rev, required this.profit});
}

class _CatAgg {
  int qty = 0, rev = 0, cost = 0;
}

class _EmpAgg {
  final String name;
  final int rev, ch;
  _EmpAgg({required this.name, required this.rev, required this.ch});
}

class _PayRow {
  final String day;
  final int checks, cash, card, total;
  final bool bold;
  _PayRow({required this.day, required this.checks, required this.cash, required this.card, required this.total, required this.bold});
}
