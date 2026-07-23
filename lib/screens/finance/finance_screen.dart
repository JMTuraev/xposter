import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme.dart';
import '../../state/app_state.dart';
import '../../models.dart';
import '../../utils/format.dart';
import '../../widgets/ui.dart';

/// Финансы — Poster POS analogi. Prototip (isFin bloki) bilan 1:1.
/// Chip-lar: Транзакции · Счета · Кассовые смены · P&L · Категории.
class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});
  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  int _tab = 0; // 0 tx · 1 acc · 2 shifts · 3 pl · 4 cats · 5 cashflow · 6 salary
  static const _chips = ['Транзакции', 'Счета', 'Кассовые смены', 'P&L', 'Категории', 'Cash flow', 'Зарплата'];

  // Filtrlar (Транзакции)
  String _catF = 'all';
  String _accF = 'all';

  // P&L banner
  // Kategoriyalar uchun lokal toggle holati (app_state da flag yo'q — REPORT).
  // Standart: hamma uchun onPos=true, inPL=true; foydalanuvchi o'zgartira oladi.
  final Map<String, bool> _catOnPos = {};
  final Map<String, bool> _catInPL = {};
  // Lokal qo'shilgan kategoriyalar (Название + type) — app_state string ro'yxatiga yozilmaydi.
  final List<Map<String, String>> _localCats = [];

  // Kategoriya → emoji (prototipdagi kabi).
  static const _catEmoji = {
    'Продажи': '💰',
    'Продукты': '🥕',
    'Аренда': '🏠',
    'Зарплата': '👥',
    'Коммунальные': '💡',
    'Коммунальные платежи': '💡',
    'Маркетинг': '📣',
    'Прочее': '📎',
    'Перевод': '⇄',
  };

  String _emojiFor(String cat) {
    if (_catEmoji.containsKey(cat)) return _catEmoji[cat]!;
    if (cat.contains('доход')) return '💰';
    if (cat.contains('смен')) return '💰';
    if (cat.contains('Поставк')) return '🥕';
    return '📎';
  }

  bool _isIncomeCat(String cat) => cat.contains('доход');

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 52,
            child: Stack(
              children: [
                // Chapda «‹ Ещё»
                Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('‹', style: AppTheme.sans(size: 20, color: AppColors.accentHover)),
                          const SizedBox(width: 3),
                          Text('Ещё', style: AppTheme.sans(size: 14.5, weight: FontWeight.w600, color: AppColors.accentHover)),
                        ],
                      ),
                    ),
                  ),
                ),
                // Markazda sarlavha
                Center(
                  child: Text('Финансы', style: AppTheme.sans(size: 17, weight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
        children: [
          _chipRow(),
          const SizedBox(height: 10),
          ..._tabBody(app),
        ],
      ),
    );
  }

  // ── Chip qatori ──
  Widget _chipRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: List.generate(_chips.length, (i) {
          final active = _tab == i;
          return Padding(
            padding: EdgeInsets.only(right: i < _chips.length - 1 ? 6 : 0),
            child: GestureDetector(
              onTap: () => setState(() => _tab = i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? AppColors.posDark : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: active ? AppColors.posDark : AppColors.border),
                ),
                child: Text(
                  _chips[i],
                  style: AppTheme.sans(
                    size: 12.5,
                    weight: FontWeight.w600,
                    color: active ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  List<Widget> _tabBody(AppState app) {
    switch (_tab) {
      case 0:
        return _transactions(app);
      case 1:
        return _accounts(app);
      case 2:
        return _shifts(app);
      case 3:
        return _pnl(app);
      case 4:
        return _categories(app);
      case 5:
        return _cashflow(app);
      case 6:
        return _salary(app);
      default:
        return const [SizedBox()];
    }
  }

  // ═══════════════ Cash flow ═══════════════
  List<Widget> _cashflow(AppState app) {
    final inflow = <String, int>{};
    final outflow = <String, int>{};
    for (final t in app.transactions) {
      if (t.amount >= 0) {
        inflow[t.category] = (inflow[t.category] ?? 0) + t.amount;
      } else {
        outflow[t.category] = (outflow[t.category] ?? 0) + t.amount.abs();
      }
    }
    final totalIn = inflow.values.fold<int>(0, (s, v) => s + v);
    final totalOut = outflow.values.fold<int>(0, (s, v) => s + v);
    final balance = app.accounts.fold<int>(0, (s, a) => s + a.balance);

    Widget group(String title, Map<String, int> data, Color color, String sign) {
      final entries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      return Container(
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.card), border: Border.all(color: AppColors.border)),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
            child: Text(title, style: AppTheme.sans(size: 13, weight: FontWeight.w700)),
          ),
          if (entries.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 18), child: Text('Пусто', style: AppTheme.sans(size: 12, color: AppColors.textTertiary)))
          else
            for (int i = 0; i < entries.length; i++)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(border: Border(top: i == 0 ? BorderSide.none : const BorderSide(color: AppColors.border))),
                child: Row(children: [
                  Text(_emojiFor(entries[i].key), style: const TextStyle(fontSize: 15)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(entries[i].key, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(size: 13, weight: FontWeight.w500))),
                  Text('$sign${groupNum(entries[i].value)}', style: AppTheme.sans(size: 13, weight: FontWeight.w700, color: color)),
                ]),
              ),
        ]),
      );
    }

    return [
      Row(children: [
        Expanded(child: _summaryCard('Поступления', '+${groupNum(totalIn)}', AppColors.success)),
        const SizedBox(width: 8),
        Expanded(child: _summaryCard('Выбытия', '−${groupNum(totalOut)}', AppColors.danger)),
      ]),
      const SizedBox(height: 10),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
        decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(AppRadius.card), border: Border.all(color: const Color(0xFFEBCDBE))),
        child: Row(children: [
          Text('Чистый поток', style: AppTheme.sans(size: 13.5, weight: FontWeight.w600)),
          const Spacer(),
          Text('${totalIn - totalOut >= 0 ? '+' : '−'}${groupNum((totalIn - totalOut).abs())}', style: AppTheme.serif(size: 18, weight: FontWeight.w700, color: totalIn - totalOut >= 0 ? AppColors.success : AppColors.danger)),
        ]),
      ),
      const SizedBox(height: 10),
      group('Поступления по категориям', inflow, AppColors.success, '+'),
      const SizedBox(height: 10),
      group('Выбытия по категориям', outflow, AppColors.danger, '−'),
      const SizedBox(height: 10),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.card), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          Text('Остаток на счетах', style: AppTheme.sans(size: 13.5, weight: FontWeight.w600)),
          const Spacer(),
          Text(sum(balance), style: AppTheme.serif(size: 17, weight: FontWeight.w700)),
        ]),
      ),
    ];
  }

  // ═══════════════ Зарплата ═══════════════
  List<Widget> _salary(AppState app) {
    final byRole = <String, int>{};
    for (final e in app.employees) {
      byRole[e.role] = (byRole[e.role] ?? 0) + 1;
    }
    final roles = byRole.entries.toList();
    return [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(color: AppColors.warningSoft, borderRadius: BorderRadius.circular(AppRadius.card), border: Border.all(color: const Color(0xFFEFE0C4))),
        child: Text('Ставки и учёт смен ещё не настроены — итоговая зарплата появится после их указания. Ниже — штат по должностям.', style: AppTheme.sans(size: 12.5, height: 1.45, color: AppColors.textSecondary)),
      ),
      const SizedBox(height: 10),
      Container(
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.card), border: Border.all(color: AppColors.border)),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
            child: Row(children: [
              Expanded(child: Text('ДОЛЖНОСТЬ', style: AppTheme.sans(size: 10, weight: FontWeight.w700, letterSpacing: 0.4, color: AppColors.textTertiary))),
              Text('СОТРУДНИКОВ', style: AppTheme.sans(size: 10, weight: FontWeight.w700, letterSpacing: 0.4, color: AppColors.textTertiary)),
            ]),
          ),
          for (int i = 0; i < roles.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(border: Border(top: i == 0 ? BorderSide.none : const BorderSide(color: AppColors.border))),
              child: Row(children: [
                Expanded(child: Text(roles[i].key, style: AppTheme.sans(size: 13, weight: FontWeight.w600))),
                Text('${roles[i].value}', style: AppTheme.sans(size: 13, weight: FontWeight.w700)),
              ]),
            ),
        ]),
      ),
    ];
  }

  // ═══════════════ Транзакции ═══════════════
  List<Widget> _transactions(AppState app) {
    final income = app.transactions.where((t) => t.type == 'доход').fold<int>(0, (s, t) => s + t.amount.abs());
    final expense = app.transactions.where((t) => t.type == 'расход').fold<int>(0, (s, t) => s + t.amount.abs());
    final net = income - expense;

    // Filtrlar
    final catOpts = ['all', ...app.financeCategories];
    final accOpts = ['all', ...app.accounts.map((a) => a.name)];
    if (!catOpts.contains(_catF)) _catF = 'all';
    if (!accOpts.contains(_accF)) _accF = 'all';

    final filtered = app.transactions.where((t) {
      final catOk = _catF == 'all' || t.category == _catF;
      final accOk = _accF == 'all' || t.account == _accF;
      return catOk && accOk;
    }).toList();

    // Sana bo'yicha guruhlash
    final groups = <String, List<TxItem>>{};
    final order = <String>[];
    for (final t in filtered) {
      final title = _groupTitle(t.date);
      if (!groups.containsKey(title)) {
        groups[title] = [];
        order.add(title);
      }
      groups[title]!.add(t);
    }

    return [
      // Summary kartalar
      Row(children: [
        Expanded(child: _summaryCard('Доход', '+${groupNum(income)}', AppColors.success)),
        const SizedBox(width: 8),
        Expanded(child: _summaryCard('Расход', '−${groupNum(expense)}', AppColors.danger)),
      ]),
      const SizedBox(height: 10),
      // Filtr dropdownlari
      Row(children: [
        Expanded(child: _filterDropdown(
          value: _catF,
          items: catOpts,
          labelFor: (v) => v == 'all' ? 'Все категории' : v,
          onChanged: (v) => setState(() => _catF = v),
        )),
        const SizedBox(width: 7),
        Expanded(child: _filterDropdown(
          value: _accF,
          items: accOpts,
          labelFor: (v) => v == 'all' ? 'Все счета' : v,
          onChanged: (v) => setState(() => _accF = v),
        )),
      ]),
      const SizedBox(height: 10),
      // Tugmalar
      Row(children: [
        Expanded(child: _outlinedAction('Импорт с AI ✨', () => _aiImport(app))),
        const SizedBox(width: 8),
        Expanded(child: _accentAction('＋ Транзакция', () => _addTx(app))),
      ]),
      const SizedBox(height: 10),
      // Guruhlar
      for (final title in order) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 2, 4, 7),
          child: Text(
            title.toUpperCase(),
            style: AppTheme.sans(size: 11, weight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 0.9),
          ),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (int i = 0; i < groups[title]!.length; i++) _txRow(app, groups[title]![i], i > 0),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
      if (filtered.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
          child: Text(
            'По выбранным фильтрам транзакций нет',
            textAlign: TextAlign.center,
            style: AppTheme.sans(size: 12.5, color: AppColors.textTertiary),
          ),
        ),
      // ИТОГО ЗА ПЕРИОД
      AppCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('ИТОГО ЗА ПЕРИОД', style: AppTheme.sans(size: 12.5, weight: FontWeight.w700)),
            Text(
              '${net < 0 ? '−' : '+'}${groupNum(net.abs())}',
              style: AppTheme.serif(size: 17, weight: FontWeight.w700, color: net < 0 ? AppColors.danger : AppColors.success),
            ),
          ],
        ),
      ),
    ];
  }

  String _groupTitle(String date) {
    // app_state sanalari: 'DD.MM HH:MM' ko'rinishida. Bosh 'DD.MM' ni ajratamiz.
    final now = DateTime.now();
    final dm = date.trim().split(' ').first; // 'DD.MM'
    final parts = dm.split('.');
    if (parts.length >= 2) {
      final d = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (d != null && m != null) {
        final today = DateTime(now.year, now.month, now.day);
        if (d == today.day && m == today.month) return 'Сегодня';
        final y = today.subtract(const Duration(days: 1));
        if (d == y.day && m == y.month) return 'Вчера';
        return dm;
      }
    }
    return dm;
  }

  Widget _summaryCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
        boxShadow: kSoftShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary)),
          const SizedBox(height: 3),
          Text(value, style: AppTheme.sans(size: 16, weight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _txRow(AppState app, TxItem t, bool topBorder) {
    final isExpense = t.type == 'расход';
    final isTransfer = t.type == 'перевод';
    final prefix = isExpense ? '−' : (isTransfer ? '⇄ ' : '+');
    final color = isExpense ? AppColors.danger : (isTransfer ? AppColors.textSecondary : AppColors.success);
    final title = t.comment.isNotEmpty ? t.comment : t.category;
    return Container(
      decoration: BoxDecoration(
        border: topBorder ? const Border(top: BorderSide(color: AppColors.border)) : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.bgSecondary, borderRadius: BorderRadius.circular(10)),
            child: Text(_emojiFor(t.category), style: const TextStyle(fontSize: 15)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(size: 13, weight: FontWeight.w600)),
                const SizedBox(height: 1),
                Text('${t.category} · ${t.account}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('$prefix${groupNum(t.amount.abs())}', style: AppTheme.sans(size: 13.5, weight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  // ═══════════════ Счета ═══════════════
  List<Widget> _accounts(AppState app) {
    final total = app.accounts.fold<int>(0, (s, a) => s + a.balance);
    return [
      Container(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.border),
          boxShadow: kSoftShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Всего на счетах', style: AppTheme.sans(size: 13, weight: FontWeight.w500, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            RichText(
              text: TextSpan(
                text: groupNum(total),
                style: AppTheme.serif(size: 28, weight: FontWeight.w700),
                children: [
                  TextSpan(text: ' сум', style: AppTheme.serif(size: 15, weight: FontWeight.w400, color: AppColors.textTertiary)),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      for (final a in app.accounts) ...[
        _accountCard(a),
        const SizedBox(height: 8),
      ],
      const SizedBox(height: 2),
      _dashedAction('＋ Добавить счёт', () => _addAccount(app)),
    ];
  }

  String _accountEmoji(Account a) {
    if (a.name.contains('Сейф')) return '🔐';
    if (a.type == 'Наличные' || a.name.contains('ящик') || a.name.contains('Денежн')) return '💵';
    return '🏦';
  }

  Widget _accountCard(Account a) {
    final neg = a.balance < 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
        boxShadow: kSoftShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.bgSecondary, borderRadius: BorderRadius.circular(12)),
            child: Text(_accountEmoji(a), style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(a.name, style: AppTheme.sans(size: 14, weight: FontWeight.w600))),
          const SizedBox(width: 8),
          Text(sum(a.balance), style: AppTheme.sans(size: 15, weight: FontWeight.w700, color: neg ? AppColors.danger : AppColors.text)),
        ],
      ),
    );
  }

  // ═══════════════ Кассовые смены ═══════════════
  List<Widget> _shifts(AppState app) {
    if (!app.cashShiftsEnabled) {
      return [
        const SizedBox(height: 30),
        EmptyState(
          emoji: '🔒',
          title: 'Учёт кассовых смен отключён',
          subtitle: 'Включите переключатель «Кассовые смены» в Настройках.',
          cta: 'Включить',
          onCta: () => app.setCashShifts(true),
        ),
      ];
    }
    // HOLAT-17: soxta (hardcoded) smenalar olib tashlandi — endi real
    // `app.currentShift` / `app.shiftsArchive` (Firestore `shifts` listener'i).
    final cur = app.currentShift;
    if (cur == null && app.shiftsArchive.isEmpty) {
      return [
        const SizedBox(height: 30),
        const EmptyState(
          emoji: '🕐',
          title: 'Смен пока нет',
          subtitle: 'Смена открывается на кассе (Функции → «Открыть смену»). '
              'Продажи с этого устройства попадут в открытую смену автоматически.',
        ),
      ];
    }
    final out = <Widget>[];
    if (cur != null) {
      out.addAll([
        _shiftCard(
          no: 'Смена №${cur.id}',
          badge: StatusBadge.warning('Открыта'),
          sub: 'Открыл(а) ${cur.openedBy} · ${_dtLabel(cur.openedAt)} · ${cur.durationLabel()}',
          line1L: 'Начало смены',
          line1V: groupNum(cur.openingCash),
          line2L: 'Выручка · чеки',
          line2V: '${groupNum(cur.revenue)} · ${cur.checks}',
          line2Color: AppColors.text,
          onTap: () => _shiftDetail(app, cur),
        ),
        const SizedBox(height: 8),
      ]);
    }
    for (final s in app.shiftsArchive.take(20)) {
      final d = s.diff;
      out.addAll([
        _shiftCard(
          no: 'Смена №${s.id}',
          badge: StatusBadge.success('Закрыта'),
          sub: '${s.closedBy ?? s.openedBy} · ${_dtLabel(s.openedAt)}'
              '${s.closedAt != null ? ' — ${_dtLabel(s.closedAt!)}' : ''}',
          line1L: 'Выручка · чеки',
          line1V: '${groupNum(s.revenue)} · ${s.checks}',
          line2L: 'Разница',
          line2V: d == 0 ? '0 ✓' : '${d > 0 ? '+' : '−'}${groupNum(d.abs())}',
          line2Color: d == 0 ? AppColors.success : AppColors.danger,
          onTap: () => _shiftDetail(app, s),
        ),
        const SizedBox(height: 8),
      ]);
    }
    return out;
  }

  String _dtLabel(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
  }

  Widget _shiftCard({
    required String no,
    required Widget badge,
    required String sub,
    required String line1L,
    required String line1V,
    required String line2L,
    required String line2V,
    required Color line2Color,
    required VoidCallback onTap,
  }) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(no, style: AppTheme.sans(size: 14.5, weight: FontWeight.w700)),
            const SizedBox(width: 8),
            badge,
            const Spacer(),
            Text('›', style: AppTheme.sans(size: 15, color: AppColors.textTertiary)),
          ]),
          const SizedBox(height: 3),
          Text(sub, style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary)),
          const SizedBox(height: 9),
          const _DashedDivider(),
          const SizedBox(height: 9),
          Row(children: [
            Expanded(child: _shiftMetric(line1L, line1V, AppColors.text)),
            const SizedBox(width: 10),
            Expanded(child: _shiftMetric(line2L, line2V, line2Color)),
          ]),
        ],
      ),
    );
  }

  Widget _shiftMetric(String label, String value, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTheme.sans(size: 11, color: AppColors.textTertiary)),
          const SizedBox(height: 2),
          Text(value, style: AppTheme.sans(size: 13.5, weight: FontWeight.w700, color: color)),
        ],
      );

  void _shiftDetail(AppState app, Shift s) {
    // Real smena tafsiloti (HOLAT-17) — Windows Z-otchet bilan bir manba.
    final open = s.isOpen;
    final rows = <List<String>>[
      ['Открыл(а)', s.openedBy],
      if (open)
        ['Начало смены', _dtLabel(s.openedAt)]
      else
        ['Открыта — закрыта', '${_dtLabel(s.openedAt)} — ${s.closedAt != null ? _dtLabel(s.closedAt!) : '—'}'],
      ['Наличных на старте', sum(s.openingCash)],
      ['Выручка', sum(s.revenue)],
      ['Чеки · средний чек', '${s.checks} · ${sum(s.avgCheck)}'],
      ['Наличными', sum(s.cash)],
      ['Карточкой', sum(s.card)],
      if (s.bonus > 0) ['Бонусами', sum(s.bonus)],
      if (s.debt > 0) ['В долг', sum(s.debt)],
      if (s.debtRepaid > 0) ['Погашено долгов', sum(s.debtRepaid)],
      if (open)
        ['Сейчас в кассе', sum(app.cashBoxBalance)]
      else ...[
        ['Ожидалось в кассе', sum(s.expectedCash)],
        ['Фактически', sum(s.countedCash)],
        ['Разница', s.diff == 0 ? '0 ✓' : '${s.diff > 0 ? '+' : '−'}${sum(s.diff.abs())}'],
      ],
    ];
    final title = 'Смена №${s.id}';
    showAppSheet(
      context,
      title: title,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                for (int i = 0; i < rows.length; i++)
                  Container(
                    decoration: BoxDecoration(
                      border: i > 0 ? const Border(top: BorderSide(color: AppColors.border)) : null,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(rows[i][0], style: AppTheme.sans(size: 13, color: AppColors.textSecondary)),
                        Text(rows[i][1], style: AppTheme.sans(size: 13.5, weight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ═══════════════ P&L ═══════════════
  // HOLAT-17: demo raqamlar olib tashlandi — joriy va o'tgan oy REAL
  // ma'lumotdan hisoblanadi: savdo/tannarx — receiptsArchive (createdAt),
  // xarajatlar — transactions (kategoriya bo'yicha).
  List<Widget> _pnl(AppState app) {
    final now = DateTime.now();
    final curY = now.year, curM = now.month;
    final prevDate = DateTime(now.year, now.month - 1);
    final prevY = prevDate.year, prevM = prevDate.month;
    const monthsRu = ['Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
      'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'];

    // Savdo va tannarx — cheklardan.
    int salesCur = 0, salesPrev = 0, costCur = 0, costPrev = 0;
    for (final r in app.receiptsArchive) {
      if (r.status == 'Возврат') continue;
      final c = r.createdAt;
      if (c == null) continue;
      if (c.year == curY && c.month == curM) {
        salesCur += r.sum;
        costCur += r.sum - r.profit;
      } else if (c.year == prevY && c.month == prevM) {
        salesPrev += r.sum;
        costPrev += r.sum - r.profit;
      }
    }

    // Xarajatlar — tranzaksiyalardan, kategoriya bo'yicha ('Продажи' chiqariladi —
    // u yuqorida cheklardan olinadi, ikki marta sanalmasin).
    final expCur = <String, int>{}, expPrev = <String, int>{};
    for (final t in app.transactions) {
      if (t.category == 'Продажи') continue;
      if (t.amount >= 0) continue; // faqat xarajat qatorlari
      final mm = int.tryParse(t.date.split(' ').first.split('.').elementAt(1)) ?? 0;
      if (mm == curM) {
        expCur[t.category] = (expCur[t.category] ?? 0) + t.amount;
      } else if (mm == prevM) {
        expPrev[t.category] = (expPrev[t.category] ?? 0) + t.amount;
      }
    }
    final expCats = {...expCur.keys, ...expPrev.keys}.toList()..sort();
    final expTotCur = expCur.values.fold(0, (s, v) => s + v);
    final expTotPrev = expPrev.values.fold(0, (s, v) => s + v);

    if (salesCur == 0 && salesPrev == 0 && expCats.isEmpty) {
      return [
        const SizedBox(height: 30),
        const EmptyState(
          emoji: '📊',
          title: 'Пока нет данных для P&L',
          subtitle: 'Отчёт строится из ваших продаж и расходов за текущий и прошлый месяц.',
        ),
      ];
    }

    final marginPrev = salesPrev - costPrev, marginCur = salesCur - costCur;
    final rows = <_PlRow>[
      _PlRow.header('Доходы'),
      _PlRow.data('Продажи', salesPrev, salesCur),
      _PlRow.data('Себестоимость', -costPrev, -costCur),
      _PlRow.data('Маржа', marginPrev, marginCur, bold: true),
      if (expCats.isNotEmpty) _PlRow.header('Расходы'),
      for (final cat in expCats)
        _PlRow.data(cat, expPrev[cat] ?? 0, expCur[cat] ?? 0),
      _PlRow.data('Операционная прибыль',
          marginPrev + expTotPrev, marginCur + expTotCur, bold: true),
    ];

    final junBase = salesPrev == 0 ? 1 : salesPrev; // 0 ga bo'linmaslik
    final julBase = salesCur == 0 ? 1 : salesCur;
    final prevName = monthsRu[prevM - 1];
    final curName = monthsRu[curM - 1];

    String pct(int v, int base) => v == 0 ? '—' : '${(v.abs() / base * 100).round()}%';
    String money(int v) => (v < 0 ? '−' : '') + groupNum(v.abs());

    // Insight — food cost dinamikasi (faqat ma'lumot bo'lsa).
    final fcPrev = salesPrev > 0 ? (costPrev / salesPrev * 100).round() : null;
    final fcCur = salesCur > 0 ? (costCur / salesCur * 100).round() : null;

    return [
      // Jadval
      AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            // Header
            Container(
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
              padding: const EdgeInsets.fromLTRB(14, 11, 14, 9),
              child: Row(
                children: [
                  const Expanded(child: SizedBox()),
                  SizedBox(width: 92, child: Text(prevName, textAlign: TextAlign.right, style: AppTheme.sans(size: 10, weight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 0.4))),
                  SizedBox(width: 92, child: Text(curName, textAlign: TextAlign.right, style: AppTheme.sans(size: 10, weight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 0.4))),
                ],
              ),
            ),
            for (final r in rows)
              if (r.isHeader)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                    child: Text(r.label.toUpperCase(), style: AppTheme.sans(size: 10.5, weight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 0.75)),
                  ),
                )
              else
                Container(
                  color: r.bold ? AppColors.bg : Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: Text(r.label, style: AppTheme.sans(size: 12.5, weight: r.bold ? FontWeight.w700 : FontWeight.w500))),
                      SizedBox(
                        width: 92,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(money(r.jun), style: AppTheme.sans(size: 12, weight: r.bold ? FontWeight.w700 : FontWeight.w500)),
                            Text(pct(r.jun, junBase), style: AppTheme.sans(size: 10, color: AppColors.textTertiary)),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 92,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              money(r.jul),
                              style: AppTheme.sans(size: 12, weight: r.bold ? FontWeight.w700 : FontWeight.w500, color: (r.bold && r.jul < 0) ? AppColors.danger : AppColors.text),
                            ),
                            Text(pct(r.jul, julBase), style: AppTheme.sans(size: 10, color: AppColors.textTertiary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      // Insight — real food cost dinamikasi (ma'lumot bo'lsagina).
      if (fcCur != null)
        AppCard(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('📈', style: TextStyle(fontSize: 19)),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fcPrev == null
                          ? 'Себестоимость: $fcCur% от продаж'
                          : 'Себестоимость: $fcPrev% → $fcCur%',
                      style: AppTheme.sans(size: 13, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Считается из тех. карт проданных блюд. Если доля растёт — проверьте закупочные цены и порции в тех. картах.',
                      style: AppTheme.sans(size: 12, height: 1.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
    ];
  }

  // ═══════════════ Категории ═══════════════
  List<Widget> _categories(AppState app) {
    final names = [...app.financeCategories, ..._localCats.map((c) => c['name']!)];
    return [
      AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (int i = 0; i < names.length; i++) _catRow(names[i], i > 0, isIncome: _catTypeIsIncome(names[i])),
          ],
        ),
      ),
      const SizedBox(height: 10),
      _dashedAction('＋ Добавить категорию', () => _addCategory(app)),
    ];
  }

  bool _catTypeIsIncome(String name) {
    final local = _localCats.firstWhere((c) => c['name'] == name, orElse: () => const {});
    if (local.isNotEmpty) return local['type'] == 'income';
    return _isIncomeCat(name);
  }

  Widget _catRow(String name, bool topBorder, {required bool isIncome}) {
    final onPos = _catOnPos[name] ?? true;
    final inPL = _catInPL[name] ?? true;
    return Container(
      decoration: BoxDecoration(
        border: topBorder ? const Border(top: BorderSide(color: AppColors.border)) : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.bgSecondary, borderRadius: BorderRadius.circular(10)),
            child: Text(_emojiFor(name), style: const TextStyle(fontSize: 15)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTheme.sans(size: 13, weight: FontWeight.w600)),
                const SizedBox(height: 1),
                Text(
                  isIncome ? 'Доход' : 'Расход',
                  style: AppTheme.sans(size: 11, weight: FontWeight.w600, color: isIncome ? AppColors.success : AppColors.textTertiary),
                ),
              ],
            ),
          ),
          _miniToggle('НА КАССЕ', onPos, () => setState(() => _catOnPos[name] = !onPos)),
          const SizedBox(width: 10),
          _miniToggle('В P&L', inPL, () => setState(() => _catInPL[name] = !inPL)),
        ],
      ),
    );
  }

  Widget _miniToggle(String label, bool on, VoidCallback onTap) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppTheme.sans(size: 9, weight: FontWeight.w700, color: AppColors.textTertiary)),
        const SizedBox(height: 3),
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 34,
            height: 20,
            decoration: BoxDecoration(
              color: on ? AppColors.success : AppColors.borderStrong,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 180),
                  top: 2,
                  left: on ? 16 : 2,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: const [BoxShadow(color: Color(0x40141413), blurRadius: 3, offset: Offset(0, 1))],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════ Umumiy UI qismlar ═══════════════
  Widget _filterDropdown({
    required String value,
    required List<String> items,
    required String Function(String) labelFor,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textSecondary),
          style: AppTheme.sans(size: 12.5, color: AppColors.text),
          items: items.map((o) => DropdownMenuItem(value: o, child: Text(labelFor(o), overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ),
    );
  }

  Widget _outlinedAction(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.btn),
          border: Border.all(color: AppColors.borderStrong),
        ),
        child: Text(label, style: AppTheme.sans(size: 13, weight: FontWeight.w600)),
      ),
    );
  }

  Widget _accentAction(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(AppRadius.btn),
        ),
        child: Text(label, style: AppTheme.sans(size: 13, weight: FontWeight.w600, color: Colors.white)),
      ),
    );
  }

  Widget _dashedAction(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedBorderPainter(color: AppColors.borderStrong, radius: AppRadius.btn),
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.btn)),
          child: Text(label, style: AppTheme.sans(size: 13.5, weight: FontWeight.w600, color: AppColors.accentHover)),
        ),
      ),
    );
  }

  // ═══════════════ Sheet-lar / amallar ═══════════════
  void _addTx(AppState app) {
    String type = 'расход'; // расход | доход | перевод
    final amount = TextEditingController();
    final comment = TextEditingController();
    bool err = false;
    String account = app.accounts.first.name;
    String toAccount = app.accounts.length > 1 ? app.accounts[1].name : app.accounts.first.name;
    String category = app.financeCategories.first;
    final accNames = app.accounts.map((a) => a.name).toList();

    showAppSheet(context, title: 'Добавить транзакцию', builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
      final isTransfer = type == 'перевод';
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Segmented
        Row(children: [
          for (final e in const [['расход', 'Расход'], ['доход', 'Доход'], ['перевод', 'Перевод']])
            Expanded(child: Padding(
              padding: EdgeInsets.only(right: e[0] != 'перевод' ? 8 : 0),
              child: _segItem(e[1], type == e[0], () => setS(() => type = e[0])),
            )),
        ]),
        const SizedBox(height: 14),
        _sumField('Сумма', amount, err, (v) => setS(() {})),
        const SizedBox(height: 12),
        if (isTransfer) ...[
          _sheetDropdown('Со счёта', account, accNames, (v) => setS(() => account = v)),
          const SizedBox(height: 12),
          _sheetDropdown('На счёт', toAccount, accNames, (v) => setS(() => toAccount = v)),
        ] else ...[
          _sheetDropdown('Счёт', account, accNames, (v) => setS(() => account = v)),
          const SizedBox(height: 12),
          _sheetDropdown('Категория', category, app.financeCategories, (v) => setS(() => category = v)),
        ],
        const SizedBox(height: 12),
        LabeledField(label: 'Комментарий', controller: comment, maxLines: 2),
        const SizedBox(height: 20),
        PrimaryButton('Сохранить', onPressed: () {
          final v = int.tryParse(amount.text.replaceAll(' ', '')) ?? 0;
          if (v <= 0) {
            setS(() => err = true);
            showToast(ctx, 'Введите сумму', color: AppColors.danger, bg: AppColors.dangerSoft, icon: Icons.error_outline);
            return;
          }
          if (isTransfer) {
            if (account == toAccount) {
              showToast(ctx, 'Выберите два разных счёта', color: AppColors.danger, bg: AppColors.dangerSoft, icon: Icons.error_outline);
              return;
            }
            final from = app.accounts.firstWhere((a) => a.name == account);
            final to = app.accounts.firstWhere((a) => a.name == toAccount);
            from.balance -= v;
            to.balance += v;
            final tx = TxItem(
              id: app.newTxId(),
              date: _todayStr(),
              type: 'перевод',
              category: 'Перевод',
              comment: comment.text.isNotEmpty ? comment.text : '$account → $toAccount',
              amount: v,
              account: account,
            );
            app.transactions.insert(0, tx);
            if (app.repo.ready) {
              app.repo.saveTransaction(tx);
              // K3: ko'chirishni delta bilan — biri o'tib biri o'tmasa ham
              // absolyut yozuv concurrent sotuvni bosmaydi.
              app.repo.adjustAccountBalance(from.id, -v);
              app.repo.adjustAccountBalance(to.id, v);
            }
            app.notify();
            Navigator.pop(ctx);
            showToast(context, 'Перевод выполнен — балансы обновлены');
          } else {
            final isExpense = type == 'расход';
            app.addTransaction(TxItem(
              id: app.newTxId(),
              date: _todayStr(),
              type: type,
              category: category,
              comment: comment.text,
              amount: isExpense ? -v : v,
              account: account,
            ));
            Navigator.pop(ctx);
            showToast(context, 'Транзакция добавлена');
          }
        }),
        const SizedBox(height: 8),
      ]);
    }));
  }

  void _aiImport(AppState app) {
    showAppSheet(context, title: 'Импорт с AI ✨', builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Загрузите выписку — Postie AI разнесёт транзакции по категориям.', style: AppTheme.sans(size: 14, height: 1.4, color: AppColors.textSecondary)),
      const SizedBox(height: 20),
      PrimaryButton('Загрузить выписку', icon: Icons.upload_file, onPressed: () {
        Navigator.pop(ctx);
        showToast(context, 'AI разбирает выписку…', color: AppColors.textSecondary, bg: AppColors.bgSecondary, icon: Icons.hourglass_top);
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          app.addTransaction(TxItem(
            id: app.newTxId(),
            date: _todayStr(),
            type: 'расход',
            category: 'Прочее',
            comment: 'Хозтовары · из выписки',
            amount: -85000,
            account: 'Денежный ящик',
          ));
          app.addTransaction(TxItem(
            id: app.newTxId(),
            date: _todayStr(),
            type: 'доход',
            category: 'Прочие доходы',
            comment: 'Возврат от поставщика · из выписки',
            amount: 120000,
            account: 'Расчетный счет',
          ));
          showToast(context, 'AI добавил 2 транзакции из выписки', color: AppColors.accentHover, bg: AppColors.accentSoft, icon: Icons.auto_awesome);
        });
      }),
      const SizedBox(height: 8),
    ]));
  }

  void _addAccount(AppState app) {
    final name = TextEditingController();
    String accType = 'Наличные';
    showAppSheet(context, title: 'Новый счёт', builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LabeledField(label: 'Название', controller: name),
      const SizedBox(height: 12),
      _sheetDropdown('Тип', accType, const ['Наличные', 'Безналичный счет'], (v) => setS(() => accType = v)),
      const SizedBox(height: 20),
      PrimaryButton('Добавить', onPressed: () {
        if (name.text.trim().isEmpty) return;
        app.addAccount(Account(id: app.newAccountId(), name: name.text.trim(), type: accType, balance: 0));
        Navigator.pop(ctx);
        showToast(context, 'Счёт добавлен');
      }),
      const SizedBox(height: 8),
    ])));
  }

  void _addCategory(AppState app) {
    final name = TextEditingController();
    String catType = 'expense'; // expense | income
    showAppSheet(context, title: 'Новая категория', builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LabeledField(label: 'Название', controller: name),
      const SizedBox(height: 12),
      Row(children: [
        for (final e in const [['expense', 'Расход'], ['income', 'Доход']])
          Expanded(child: Padding(
            padding: EdgeInsets.only(right: e[0] == 'expense' ? 8 : 0),
            child: _segItem(e[1], catType == e[0], () => setS(() => catType = e[0])),
          )),
      ]),
      const SizedBox(height: 20),
      PrimaryButton('Добавить', onPressed: () {
        final n = name.text.trim();
        if (n.isEmpty) return;
        setState(() {
          _localCats.add({'name': n, 'type': catType});
          _catOnPos[n] = true;
          _catInPL[n] = true;
        });
        Navigator.pop(ctx);
        showToast(context, 'Категория добавлена');
      }),
      const SizedBox(height: 8),
    ])));
  }

  String _todayStr() {
    final n = DateTime.now();
    return '${n.day.toString().padLeft(2, '0')}.${n.month.toString().padLeft(2, '0')} ${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
  }

  Widget _segItem(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.btn),
          border: Border.all(color: active ? AppColors.border : Colors.transparent),
        ),
        child: Text(label, style: AppTheme.sans(size: 13, weight: FontWeight.w600, color: active ? AppColors.text : AppColors.textSecondary)),
      ),
    );
  }

  Widget _sumField(String label, TextEditingController c, bool err, ValueChanged<String> onChanged) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppTheme.sans(size: 13, color: AppColors.textSecondary)),
      const SizedBox(height: 6),
      TextField(
        controller: c,
        keyboardType: TextInputType.number,
        onChanged: onChanged,
        style: AppTheme.sans(size: 15),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.input), borderSide: BorderSide(color: err ? AppColors.danger : AppColors.borderStrong)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.input), borderSide: BorderSide(color: err ? AppColors.danger : AppColors.borderStrong)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.input), borderSide: BorderSide(color: err ? AppColors.danger : AppColors.accent, width: 2)),
        ),
      ),
    ]);
  }

  Widget _sheetDropdown(String label, String value, List<String> options, ValueChanged<String> onChanged) {
    final safe = options.contains(value) ? value : (options.isNotEmpty ? options.first : value);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppTheme.sans(size: 13, color: AppColors.textSecondary)),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.input), border: Border.all(color: AppColors.borderStrong)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: safe,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
            style: AppTheme.sans(size: 15, color: AppColors.text),
            items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
            onChanged: (v) { if (v != null) onChanged(v); },
          ),
        ),
      ),
    ]);
  }
}

// ── P&L qator modeli ──
class _PlRow {
  final String label;
  final int jun;
  final int jul;
  final bool bold;
  final bool isHeader;
  const _PlRow._(this.label, this.jun, this.jul, this.bold, this.isHeader);
  factory _PlRow.header(String label) => _PlRow._(label, 0, 0, false, true);
  factory _PlRow.data(String label, int jun, int jul, {bool bold = false}) => _PlRow._(label, jun, jul, bold, false);
}

// ── Punktir ajratgich (kassa smenasi kartasi ichida) ──
class _DashedDivider extends StatelessWidget {
  const _DashedDivider();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      width: double.infinity,
      child: CustomPaint(painter: _DashedLinePainter(color: AppColors.border)),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dash = 4.0, gap = 3.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dash, 0), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Punktir ramka (dashed tugmalar uchun) ──
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  _DashedBorderPainter({required this.color, required this.radius});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    final path = Path()..addRRect(rrect);
    const dash = 5.0, gap = 4.0;
    for (final metric in path.computeMetrics()) {
      double dist = 0;
      while (dist < metric.length) {
        final len = (dist + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(dist, len), paint);
        dist += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
