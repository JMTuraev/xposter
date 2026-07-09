import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme.dart';
import '../../state/app_state.dart';
import '../../models.dart';
import '../../utils/format.dart';
import '../../widgets/ui.dart';
import '../shared/client_form.dart';

/// Маркетинг — Poster analogi. Prototip (isMkt bloki) bilan 1:1.
/// 5 tab: Клиенты, Группы, Лояльность, Акции, Исключения + aksiya muharriri (mkPRF).
class MarketingScreen extends StatefulWidget {
  const MarketingScreen({super.key});
  @override
  State<MarketingScreen> createState() => _MarketingScreenState();
}

class _LoyaltyRule {
  String sum;
  String to;
  _LoyaltyRule(this.sum, this.to);
}

class _MarketingScreenState extends State<MarketingScreen> {
  // clients / groups / loyal / promos / excl
  String _tab = 'clients';
  String _q = '';
  String _groupF = 'all';

  // Aksiya muharriri: agar ochiq bo'lsa (list o'rniga), _prf != null.
  Map<String, dynamic>? _prf; // null => list

  // Lokal loyallik qoidalari (app_state'da model yo'q).
  final List<_LoyaltyRule> _bRules = [
    _LoyaltyRule('500 000', 'Постоянные'),
    _LoyaltyRule('3 000 000', 'VIP'),
  ];
  final List<_LoyaltyRule> _dRules = [
    _LoyaltyRule('500 000', 'Постоянные'),
    _LoyaltyRule('3 000 000', 'VIP'),
  ];
  final _lyBMax = TextEditingController(text: '50');
  final _lyBWelcome = TextEditingController(text: '0');
  final _lyBEarn = TextEditingController(text: '5');
  final _lyDDefault = TextEditingController(text: '0');
  bool _loyInit = false;

  // Исключения — lokal holat (app_state'da model yo'q).
  final List<String> _exCats = [];
  final List<String> _exItems = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loyInit) {
      final app = context.read<AppState>();
      _lyBMax.text = app.maxBonusPayPct.toString();
      _lyBWelcome.text = app.welcomeBonus.toString();
      _lyBEarn.text = app.bonusEarnPct.toString();
      _loyInit = true;
    }
  }

  @override
  void dispose() {
    _lyBMax.dispose();
    _lyBWelcome.dispose();
    _lyBEarn.dispose();
    _lyDDefault.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(children: [
          _appBar(),
          Expanded(
            child: _prf != null
                ? _promoEditor(app)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
                    children: [
                      _topRow(app),
                      const SizedBox(height: 10),
                      ..._tabBody(app),
                    ],
                  ),
          ),
        ]),
      ),
    );
  }

  // ── App-bar: ‹ Ещё · Маркетинг ─────────────────────────────────
  Widget _appBar() {
    return SizedBox(
      height: 52,
      child: Stack(alignment: Alignment.center, children: [
        Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).maybePop(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('‹', style: TextStyle(fontSize: 20, color: AppColors.accentHover, height: 1)),
                const SizedBox(width: 3),
                Text('Ещё', style: AppTheme.sans(size: 14.5, weight: FontWeight.w600, color: AppColors.accentHover)),
              ]),
            ),
          ),
        ),
        Text('Маркетинг', style: AppTheme.sans(size: 17, weight: FontWeight.w600)),
      ]),
    );
  }

  // ── Yuqori qator: 5 chip + ＋ tugma ────────────────────────────
  Widget _topRow(AppState app) {
    const chips = [
      ['clients', 'Клиенты'],
      ['groups', 'Группы'],
      ['loyal', 'Лояльность'],
      ['promos', 'Акции'],
      ['excl', 'Исключения'],
    ];
    final showAdd = _tab == 'clients' || _tab == 'groups' || _tab == 'promos';
    return Row(children: [
      Expanded(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            for (int i = 0; i < chips.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              _chip(chips[i][1], _tab == chips[i][0], () => setState(() { _tab = chips[i][0]; })),
            ],
          ]),
        ),
      ),
      if (showAdd) ...[
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => _addTap(app),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(10)),
            child: const Text('＋', style: TextStyle(fontSize: 19, color: Colors.white, height: 1)),
          ),
        ),
      ],
    ]);
  }

  Widget _chip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.posDark : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: active ? AppColors.posDark : AppColors.border),
        ),
        child: Text(label, style: AppTheme.sans(size: 12.5, weight: FontWeight.w600, color: active ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }

  void _addTap(AppState app) {
    if (_tab == 'clients') {
      showClientForm(context, app, onSaved: (_) => setState(() {}));
    } else if (_tab == 'groups') {
      _groupSheet(app, null);
    } else if (_tab == 'promos') {
      _openPromo(null);
    }
  }

  List<Widget> _tabBody(AppState app) {
    switch (_tab) {
      case 'clients':
        return _clients(app);
      case 'groups':
        return _groups(app);
      case 'loyal':
        return _loyalty(app);
      case 'promos':
        return _promos(app);
      case 'excl':
        return _exclusions(app);
      default:
        return const [];
    }
  }

  // ════════════════════ КЛИЕНТЫ ════════════════════════════════
  List<Widget> _clients(AppState app) {
    final q = _q.trim().toLowerCase();
    final list = app.clients.where((c) {
      final okQ = q.isEmpty || c.name.toLowerCase().contains(q) || c.phone.contains(q);
      final okG = _groupF == 'all' || c.group == _groupF;
      return okQ && okG;
    }).toList();

    return [
      Row(children: [
        Expanded(
          child: SizedBox(
            height: 38,
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              style: AppTheme.sans(size: 13.5),
              decoration: InputDecoration(
                hintText: 'Поиск по имени или телефону…',
                hintStyle: AppTheme.sans(size: 13.5, color: AppColors.textTertiary),
                isDense: true,
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accent, width: 2)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _softChip(
          label: _groupF == 'all' ? 'Группа' : _groupF,
          trailing: '▾',
          onTap: () => _groupFilterSheet(app),
        ),
        const SizedBox(width: 8),
        _softChip(label: '↓ Импорт', onTap: () => showToast(context, 'Импорт из Excel и iiko появится после подключения', color: AppColors.textSecondary, bg: AppColors.bgSecondary, icon: Icons.download_outlined)),
      ]),
      const SizedBox(height: 10),
      if (list.isEmpty)
        Container(
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.card), border: Border.all(color: AppColors.border)),
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          alignment: Alignment.center,
          child: Text('Клиенты не найдены', style: AppTheme.sans(size: 12.5, color: AppColors.textTertiary)),
        )
      else
        Container(
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.card), border: Border.all(color: AppColors.border)),
          child: Column(children: [
            for (int i = 0; i < list.length; i++) _clientRow(app, list[i], i > 0),
          ]),
        ),
    ];
  }

  Widget _clientRow(AppState app, Client c, bool topBorder) {
    final badge = _groupBadge(c.group);
    return InkWell(
      onTap: () => _clientCard(app, c),
      child: Container(
        decoration: BoxDecoration(border: topBorder ? const Border(top: BorderSide(color: AppColors.border)) : null),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.bgSecondary, shape: BoxShape.circle),
            child: Text(c.initials, style: AppTheme.sans(size: 13, weight: FontWeight.w700, color: AppColors.textSecondary)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(size: 13.5, weight: FontWeight.w600)),
              const SizedBox(height: 1),
              Text(c.phone, style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary)),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _pill(c.group, badge.$1, badge.$2),
            const SizedBox(height: 3),
            Text('${groupNum(c.totalSpent)} сум', style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary)),
          ]),
          const SizedBox(width: 6),
          const Text('›', style: TextStyle(fontSize: 16, color: AppColors.textTertiary)),
        ]),
      ),
    );
  }

  // Mijoz-kartochkasi (bottom sheet).
  void _clientCard(AppState app, Client c) {
    final badge = _groupBadge(c.group);
    final disc = _groupPercent(app, c.group);
    final birthThisMonth = _isBirthThisMonth(c.birthday);
    showAppSheet(context, title: c.name, builder: (ctx) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.bgSecondary, shape: BoxShape.circle),
            child: Text(c.initials, style: AppTheme.sans(size: 17, weight: FontWeight.w700, color: AppColors.textSecondary)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.name, style: AppTheme.sans(size: 16, weight: FontWeight.w700)),
              const SizedBox(height: 4),
              _pill(c.group, badge.$1, badge.$2),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        _kv('Телефон', c.phone),
        _kv('E-mail', c.email ?? '—'),
        if (c.address != null && c.address!.isNotEmpty) _kv('Адрес', c.address!),
        _kv('Скидка', '$disc%'),
        _kv('Бонусы', sum(c.bonus)),
        _kv('Потрачено', sum(c.totalSpent)),
        _kv('День рождения', c.birthday == null ? '—' : (birthThisMonth ? '🎂 ${c.birthday}' : c.birthday!)),
        const SizedBox(height: 14),
        Text('ПОКУПКИ', style: AppTheme.sans(size: 11, weight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 0.8)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.bgSecondary, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: c.totalSpent > 0
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Всего покупок на ${sum(c.totalSpent)}', style: AppTheme.sans(size: 13.5, weight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Накоплено бонусов: ${sum(c.bonus)}', style: AppTheme.sans(size: 12, color: AppColors.textSecondary)),
                ])
              : Text('Покупок пока нет', style: AppTheme.sans(size: 13, color: AppColors.textSecondary)),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: SecondaryButton('Редактировать', expand: true, onPressed: () {
              Navigator.pop(ctx);
              showClientForm(context, app, existing: c, onSaved: (_) => setState(() {}));
            }),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: PrimaryButton('Удалить', color: AppColors.danger, onPressed: () => _confirmDeleteClient(app, c, ctx)),
          ),
        ]),
        const SizedBox(height: 8),
      ]);
    });
  }

  void _confirmDeleteClient(AppState app, Client c, BuildContext sheetCtx) {
    showDialog(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: Text('Удалить клиента?', style: AppTheme.sans(size: 17, weight: FontWeight.w700)),
        content: Text('«${c.name}» и его бонусы будут удалены. Действие необратимо.', style: AppTheme.sans(size: 14, color: AppColors.textSecondary, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx), child: Text('Отмена', style: AppTheme.sans(size: 14, weight: FontWeight.w600, color: AppColors.textSecondary))),
          TextButton(
            onPressed: () {
              Navigator.pop(dctx);
              app.removeClient(c.id);
              Navigator.pop(sheetCtx);
              showToast(context, 'Клиент удалён', color: AppColors.danger, bg: AppColors.dangerSoft, icon: Icons.delete_outline);
              setState(() {});
            },
            child: Text('Удалить', style: AppTheme.sans(size: 14, weight: FontWeight.w700, color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  void _groupFilterSheet(AppState app) {
    final rows = <(String, String)>[('all', 'Все группы')];
    for (final g in app.clientGroups) {
      rows.add((g.name, g.name));
    }
    showAppSheet(context, title: 'Группа', builder: (ctx) {
      return Column(children: [
        for (int i = 0; i < rows.length; i++)
          InkWell(
            onTap: () {
              setState(() => _groupF = rows[i].$1);
              Navigator.pop(ctx);
            },
            child: Container(
              decoration: BoxDecoration(border: i > 0 ? const Border(top: BorderSide(color: AppColors.border)) : null),
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Row(children: [
                Expanded(child: Text(rows[i].$2, style: AppTheme.sans(size: 14, weight: FontWeight.w500))),
                if (_groupF == rows[i].$1) const Icon(Icons.check, size: 18, color: AppColors.accent),
              ]),
            ),
          ),
      ]);
    });
  }

  // ════════════════════ ГРУППЫ ══════════════════════════════════
  List<Widget> _groups(AppState app) {
    return [
      Container(
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.card), border: Border.all(color: AppColors.border)),
        child: Column(children: [
          for (int i = 0; i < app.clientGroups.length; i++) _groupRow(app, app.clientGroups[i], i > 0),
        ]),
      ),
      const SizedBox(height: 10),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text('Скидочная группа даёт скидку от чека, бонусная — копит баллы', textAlign: TextAlign.center, style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary)),
      ),
    ];
  }

  Widget _groupRow(AppState app, ClientGroup g, bool topBorder) {
    final typeStr = g.type == 'скидочная' || g.type == 'disc' ? 'Скидочная' : 'Бонусная';
    return InkWell(
      onTap: () => _groupSheet(app, g),
      child: Container(
        decoration: BoxDecoration(border: topBorder ? const Border(top: BorderSide(color: AppColors.border)) : null),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(g.name, style: AppTheme.sans(size: 13.5, weight: FontWeight.w600)),
              const SizedBox(height: 1),
              Text(typeStr, style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary)),
            ]),
          ),
          const SizedBox(width: 8),
          Text('${g.percent}%', style: AppTheme.sans(size: 14, weight: FontWeight.w700)),
          const SizedBox(width: 6),
          const Text('›', style: TextStyle(fontSize: 16, color: AppColors.textTertiary)),
        ]),
      ),
    );
  }

  // Guruh yaratish/tahrirlash sheet.
  void _groupSheet(AppState app, ClientGroup? existing) {
    final name = TextEditingController(text: existing?.name ?? '');
    final percent = TextEditingController(text: existing != null ? existing.percent.toString() : '5');
    String type = existing?.type ?? 'скидочная';
    bool err = false;
    showAppSheet(context, title: existing == null ? 'Новая группа' : 'Группа', builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setS) {
        final bonus = type == 'бонусная' || type == 'bonus';
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _fieldLabel('Название'),
          _sheetInput(name, hint: 'Например: Гости кухни', errorBorder: err),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _radioBox(!bonus, 'Скидочная', () => setS(() => type = 'скидочная'))),
            const SizedBox(width: 8),
            Expanded(child: _radioBox(bonus, 'Бонусная', () => setS(() => type = 'бонусная'))),
          ]),
          const SizedBox(height: 12),
          _fieldLabel(bonus ? 'Процент бонусов от чека' : 'Скидка от суммы чека, %'),
          _sheetInput(percent, keyboardType: TextInputType.number, align: TextAlign.right),
          const SizedBox(height: 18),
          PrimaryButton('Сохранить', onPressed: () {
            if (name.text.trim().isEmpty) {
              setS(() => err = true);
              return;
            }
            final pct = int.tryParse(percent.text.trim()) ?? 0;
            if (existing != null) {
              existing.name = name.text.trim();
              existing.type = type;
              existing.percent = pct;
              if (app.repo.ready) app.repo.saveClientGroup(existing);
              app.notify();
            } else {
              app.addClientGroup(ClientGroup(id: app.newClientGroupId(), name: name.text.trim(), type: type, percent: pct));
            }
            Navigator.pop(ctx);
            showToast(context, 'Группа сохранена');
            setState(() {});
          }),
          const SizedBox(height: 8),
        ]);
      });
    });
  }

  // ════════════════════ ЛОЯЛЬНОСТЬ ═════════════════════════════
  List<Widget> _loyalty(AppState app) {
    final groupOpts = app.clientGroups.map((g) => g.name).toList();
    return [
      _bonusCard(groupOpts),
      const SizedBox(height: 10),
      _discountCard(groupOpts),
    ];
  }

  Widget _bonusCard(List<String> groupOpts) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('💎 Бонусная система', style: AppTheme.sans(size: 14.5, weight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text('Применяется на Кассе: клиент получает % от покупки бонусами и может оплачивать ими до макс. %.', style: AppTheme.sans(size: 11.5, height: 1.4, color: AppColors.textTertiary)),
        const SizedBox(height: 11),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _loyInput('Бонус за покупку, %', _lyBEarn)),
          const SizedBox(width: 8),
          Expanded(child: _loyInput('Макс. % оплаты бонусами', _lyBMax)),
        ]),
        const SizedBox(height: 8),
        _loyInput('Приветственный бонус, сум', _lyBWelcome),
        const SizedBox(height: 12),
        _rulesHeader(),
        const SizedBox(height: 7),
        _rulesList(_bRules, groupOpts),
        const SizedBox(height: 8),
        _addRuleLink(() => setState(() => _bRules.add(_LoyaltyRule('', groupOpts.isNotEmpty ? groupOpts.first : '')))),
        const SizedBox(height: 11),
        PrimaryButton('Сохранить', onPressed: () {
          final app = context.read<AppState>();
          app.setLoyalty(
            earn: int.tryParse(_lyBEarn.text.trim()),
            maxPay: int.tryParse(_lyBMax.text.trim()),
            welcome: int.tryParse(_lyBWelcome.text.replaceAll(' ', '').replaceAll(RegExp(r'[^0-9]'), '').trim()),
          );
          showToast(context, 'Бонусная система сохранена — применяется на Кассе');
        }),
      ]),
    );
  }

  Widget _discountCard(List<String> groupOpts) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('🏷️ Скидочная система', style: AppTheme.sans(size: 14.5, weight: FontWeight.w700)),
        const SizedBox(height: 11),
        _loyInput('Скидка по умолчанию, %', _lyDDefault),
        const SizedBox(height: 12),
        _rulesHeader(),
        const SizedBox(height: 7),
        _rulesList(_dRules, groupOpts),
        const SizedBox(height: 8),
        _addRuleLink(() => setState(() => _dRules.add(_LoyaltyRule('', groupOpts.isNotEmpty ? groupOpts.first : '')))),
        const SizedBox(height: 11),
        PrimaryButton('Сохранить', onPressed: () => showToast(context, 'Скидочная система сохранена')),
      ]),
    );
  }

  Widget _rulesHeader() => Text('ПЕРЕХОД МЕЖДУ ГРУППАМИ', style: AppTheme.sans(size: 10.5, weight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 0.5));

  Widget _rulesList(List<_LoyaltyRule> rules, List<String> groupOpts) {
    return Column(children: [
      for (int i = 0; i < rules.length; i++) ...[
        if (i > 0) const SizedBox(height: 6),
        Row(children: [
          Text('от', style: AppTheme.sans(size: 12.5, color: AppColors.textSecondary)),
          const SizedBox(width: 6),
          Expanded(
            child: SizedBox(
              height: 38,
              child: TextField(
                controller: TextEditingController(text: rules[i].sum)..selection = TextSelection.collapsed(offset: rules[i].sum.length),
                onChanged: (v) => rules[i].sum = v,
                textAlign: TextAlign.right,
                style: AppTheme.sans(size: 12.5),
                decoration: _strongInputDeco(),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text('→', style: AppTheme.sans(size: 12.5, color: AppColors.textSecondary)),
          const SizedBox(width: 6),
          SizedBox(
            width: 124,
            height: 38,
            child: _ruleDropdown(rules[i].to, groupOpts, (v) => setState(() => rules[i].to = v)),
          ),
        ]),
      ],
    ]);
  }

  Widget _ruleDropdown(String value, List<String> opts, ValueChanged<String> onChanged) {
    final safe = opts.contains(value) ? value : (opts.isNotEmpty ? opts.first : value);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(9), border: Border.all(color: AppColors.borderStrong)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: opts.isEmpty ? null : safe,
          isExpanded: true,
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textSecondary),
          style: AppTheme.sans(size: 12.5, color: AppColors.text),
          items: opts.map((g) => DropdownMenuItem(value: g, child: Text(g, maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ),
    );
  }

  Widget _addRuleLink(VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('＋', style: TextStyle(fontSize: 15, color: AppColors.accentHover)),
          const SizedBox(width: 6),
          Text('Добавить', style: AppTheme.sans(size: 12.5, weight: FontWeight.w600, color: AppColors.accentHover)),
        ]),
      );

  Widget _loyInput(String label, TextEditingController c) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(), style: AppTheme.sans(size: 10.5, weight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 0.5)),
      const SizedBox(height: 5),
      SizedBox(
        height: 42,
        child: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.right,
          style: AppTheme.sans(size: 13.5),
          decoration: _strongInputDeco(),
        ),
      ),
    ]);
  }

  // ════════════════════ АКЦИИ ═══════════════════════════════════
  List<Widget> _promos(AppState app) {
    if (app.promotionsList.isEmpty) {
      return [
        Container(
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.card), border: Border.all(color: AppColors.border)),
          padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
          child: Column(children: [
            const Text('🎉', style: TextStyle(fontSize: 34)),
            const SizedBox(height: 10),
            Text('Акций пока нет', style: AppTheme.sans(size: 14.5, weight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Создайте первую акцию по кнопке ＋ сверху', textAlign: TextAlign.center, style: AppTheme.sans(size: 12.5, color: AppColors.textSecondary)),
          ]),
        ),
      ];
    }
    final rows = <Widget>[];
    for (int i = 0; i < app.promotionsList.length; i++) {
      final p = app.promotionsList[i];
      final active = p['active'] == true;
      rows.add(Padding(
        padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
        child: AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          onTap: () => _openPromo(i),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text((p['name'] ?? '') as String, style: AppTheme.sans(size: 14, weight: FontWeight.w700))),
              const SizedBox(width: 8),
              active
                  ? _pill('Активна', AppColors.success, AppColors.successSoft)
                  : _pill('Выключена', AppColors.textSecondary, AppColors.bgSecondary),
            ]),
            const SizedBox(height: 5),
            Text('${p['dateStart']} – ${p['dateEnd']} · ${p['condition']}', style: AppTheme.sans(size: 12, color: AppColors.textSecondary)),
          ]),
        ),
      ));
    }
    return rows;
  }

  // Aksiya muharririni ochish. index==null => yangi.
  void _openPromo(int? index) {
    final app = context.read<AppState>();
    if (index == null) {
      _prf = {
        'index': null,
        'name': '',
        'from': '2026-07-01',
        'to': '2026-07-31',
        'days': <String>['Пн', 'Вт', 'Ср', 'Чт', 'Пт'],
        'tFrom': '15:00',
        'tTo': '18:00',
        'cond': 'items', // items | sum
        'condItems': '',
        'condSum': '',
        'res': 'disc', // disc | bonus | gift
        'resPct': '10',
        'resGift': '',
        'bonusOn': false,
        'active': true,
        'err': false,
      };
    } else {
      final p = app.promotionsList[index];
      // app_state Map faqat name/dateStart/dateEnd/condition/active saqlaydi;
      // qolgan maydonlarni condition dan tiklab bo'lmaydi — default bilan to'ldiramiz.
      _prf = {
        'index': index,
        'name': (p['name'] ?? '') as String,
        'from': (p['dateStart'] ?? '2026-07-01') as String,
        'to': (p['dateEnd'] ?? '2026-07-31') as String,
        'days': <String>['Пн', 'Вт', 'Ср', 'Чт', 'Пт'],
        'tFrom': '15:00',
        'tTo': '18:00',
        'cond': 'items',
        'condItems': (p['condition'] ?? '') as String,
        'condSum': '',
        'res': 'disc',
        'resPct': '10',
        'resGift': '',
        'bonusOn': false,
        'active': p['active'] == true,
        'err': false,
      };
    }
    setState(() {});
  }

  Widget _promoEditor(AppState app) {
    final prf = _prf!;
    final isNew = prf['index'] == null;
    final nameCtrl = TextEditingController(text: prf['name'] as String)..selection = TextSelection.collapsed(offset: (prf['name'] as String).length);
    final fromCtrl = TextEditingController(text: prf['from'] as String);
    final toCtrl = TextEditingController(text: prf['to'] as String);
    final tFromCtrl = TextEditingController(text: prf['tFrom'] as String);
    final tToCtrl = TextEditingController(text: prf['tTo'] as String);
    final itemsCtrl = TextEditingController(text: prf['condItems'] as String)..selection = TextSelection.collapsed(offset: (prf['condItems'] as String).length);
    final sumCtrl = TextEditingController(text: prf['condSum'] as String)..selection = TextSelection.collapsed(offset: (prf['condSum'] as String).length);
    final pctCtrl = TextEditingController(text: prf['resPct'] as String)..selection = TextSelection.collapsed(offset: (prf['resPct'] as String).length);
    final giftCtrl = TextEditingController(text: prf['resGift'] as String)..selection = TextSelection.collapsed(offset: (prf['resGift'] as String).length);

    return StatefulBuilder(builder: (ctx, setP) {
      final cond = prf['cond'] as String;
      final res = prf['res'] as String;
      final days = prf['days'] as List<String>;
      final err = prf['err'] == true;
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
        children: [
          // Header ‹ title
          Transform.translate(
            offset: const Offset(-8, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () => setState(() => _prf = null),
                child: Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  child: const Text('‹', style: TextStyle(fontSize: 22, color: AppColors.accentHover)),
                ),
              ),
              Text(isNew ? 'Новая акция' : 'Акция', style: AppTheme.sans(size: 17, weight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 8),
          // Card 1 — детали
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _fieldLabel('Название *'),
              SizedBox(
                height: 44,
                child: TextField(
                  controller: nameCtrl,
                  onChanged: (v) { prf['name'] = v; if (err) setP(() => prf['err'] = false); },
                  style: AppTheme.sans(size: 13.5),
                  decoration: InputDecoration(
                    hintText: 'Например: Счастливые часы',
                    hintStyle: AppTheme.sans(size: 13.5, color: AppColors.textTertiary),
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.btn), borderSide: BorderSide(color: err ? AppColors.danger : AppColors.borderStrong, width: 1.5)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.btn), borderSide: BorderSide(color: err ? AppColors.danger : AppColors.borderStrong, width: 1.5)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.btn), borderSide: BorderSide(color: err ? AppColors.danger : AppColors.accent, width: 1.5)),
                  ),
                ),
              ),
              const SizedBox(height: 11),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _smallField('С даты', fromCtrl, (v) => prf['from'] = v)),
                const SizedBox(width: 8),
                Expanded(child: _smallField('По дату', toCtrl, (v) => prf['to'] = v)),
              ]),
              const SizedBox(height: 11),
              Text('ДНИ НЕДЕЛИ', style: AppTheme.sans(size: 10.5, weight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 0.5)),
              const SizedBox(height: 6),
              Wrap(spacing: 5, runSpacing: 5, children: [
                for (final d in const ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'])
                  _dayPill(d, days.contains(d), () => setP(() {
                        if (days.contains(d)) {
                          days.remove(d);
                        } else {
                          days.add(d);
                        }
                      })),
              ]),
              const SizedBox(height: 11),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _smallField('С', tFromCtrl, (v) => prf['tFrom'] = v)),
                const SizedBox(width: 8),
                Expanded(child: _smallField('До', tToCtrl, (v) => prf['tTo'] = v)),
              ]),
            ]),
          ),
          const SizedBox(height: 8),
          // Card 2 — условие
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Условие', style: AppTheme.sans(size: 14, weight: FontWeight.w700)),
              const SizedBox(height: 10),
              _radioRow(cond == 'items', 'При покупке товаров', () => setP(() => prf['cond'] = 'items')),
              if (cond == 'items') ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(left: 32),
                  child: _editorInput(itemsCtrl, hint: 'Товары через запятую', onChanged: (v) => prf['condItems'] = v),
                ),
              ],
              const SizedBox(height: 10),
              _radioRow(cond == 'sum', 'При сумме чека от', () => setP(() => prf['cond'] = 'sum')),
              if (cond == 'sum') ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(left: 32),
                  child: _editorInput(sumCtrl, hint: 'Сумма, сум', keyboardType: TextInputType.number, align: TextAlign.right, onChanged: (v) => prf['condSum'] = v),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 8),
          // Card 3 — результат
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Результат', style: AppTheme.sans(size: 14, weight: FontWeight.w700)),
              const SizedBox(height: 10),
              _radioRow(res == 'disc', 'Скидка %', () => setP(() => prf['res'] = 'disc')),
              if (res == 'disc') ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(left: 32),
                  child: SizedBox(
                    width: 110,
                    child: _editorInput(pctCtrl, keyboardType: TextInputType.number, align: TextAlign.right, onChanged: (v) => prf['resPct'] = v),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              _radioRow(res == 'bonus', 'Бонусы ×2', () => setP(() => prf['res'] = 'bonus')),
              const SizedBox(height: 10),
              _radioRow(res == 'gift', 'Подарочный товар', () => setP(() => prf['res'] = 'gift')),
              if (res == 'gift') ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(left: 32),
                  child: _editorInput(giftCtrl, hint: 'Например: Чай чёрный', onChanged: (v) => prf['resGift'] = v),
                ),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.only(top: 10),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border, style: BorderStyle.solid))),
                child: Row(children: [
                  Expanded(child: Text('Начислять бонусы по акции', style: AppTheme.sans(size: 13, weight: FontWeight.w600))),
                  _toggle(prf['bonusOn'] == true, () => setP(() => prf['bonusOn'] = !(prf['bonusOn'] == true))),
                ]),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: Text('Акция активна', style: AppTheme.sans(size: 13, weight: FontWeight.w600))),
                _toggle(prf['active'] == true, () => setP(() => prf['active'] = !(prf['active'] == true))),
              ]),
            ]),
          ),
          const SizedBox(height: 14),
          PrimaryButton('Сохранить', onPressed: () {
            final nm = (prf['name'] as String).trim();
            if (nm.isEmpty) {
              setP(() => prf['err'] = true);
              return;
            }
            _savePromo(app);
          }),
          const SizedBox(height: 6),
        ],
      );
    });
  }

  void _savePromo(AppState app) {
    final prf = _prf!;
    final days = prf['days'] as List<String>;
    final cond = prf['cond'] as String;
    // condition satrini shakllantirish (kunlar + vaqt yoki summa/tovarlar).
    String sched;
    if (days.length == 7) {
      sched = 'Ежедневно';
    } else if (days.length == 5 && days.contains('Пн') && days.contains('Вт') && days.contains('Ср') && days.contains('Чт') && days.contains('Пт')) {
      sched = 'Пн-Пт';
    } else {
      sched = days.join('-');
    }
    final timePart = '${prf['tFrom']} до ${prf['tTo']}';
    String condStr;
    if (cond == 'sum') {
      final s = (prf['condSum'] as String).trim();
      condStr = s.isEmpty ? '$sched с $timePart' : 'Чек от $s сум · $sched';
    } else {
      final it = (prf['condItems'] as String).trim();
      condStr = it.isEmpty ? '$sched с $timePart' : '$it · $sched';
    }

    final record = {
      'name': (prf['name'] as String).trim(),
      'dateStart': prf['from'],
      'dateEnd': prf['to'],
      'condition': condStr,
      'active': prf['active'] == true,
    };

    final index = prf['index'] as int?;
    if (index == null) {
      app.addPromotion(record);
    } else {
      app.updatePromotionAt(index, record);
    }
    setState(() => _prf = null);
    showToast(context, 'Акция сохранена');
  }

  // ════════════════════ ИСКЛЮЧЕНИЯ ═════════════════════════════
  List<Widget> _exclusions(AppState app) {
    return [
      Container(
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.card), border: Border.all(color: AppColors.border)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Text('На исключения не действуют скидки групп и оплата бонусами. Акции применяются как обычно.', style: AppTheme.sans(size: 12, color: AppColors.textSecondary, height: 1.5)),
      ),
      const SizedBox(height: 10),
      _exSection(
        title: 'КАТЕГОРИИ-ИСКЛЮЧЕНИЯ',
        items: _exCats,
        addLabel: '＋ Добавить категорию',
        onAdd: () => _exclPickSheet(app, isCats: true),
        onDel: (n) => setState(() => _exCats.remove(n)),
      ),
      const SizedBox(height: 10),
      _exSection(
        title: 'ТОВАРЫ-ИСКЛЮЧЕНИЯ',
        items: _exItems,
        addLabel: '＋ Добавить товар',
        onAdd: () => _exclPickSheet(app, isCats: false),
        onDel: (n) => setState(() => _exItems.remove(n)),
      ),
    ];
  }

  Widget _exSection({
    required String title,
    required List<String> items,
    required String addLabel,
    required VoidCallback onAdd,
    required ValueChanged<String> onDel,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 2, 4, 7),
        child: Text(title, style: AppTheme.sans(size: 11, weight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 0.9)),
      ),
      if (items.isNotEmpty)
        Container(
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.card), border: Border.all(color: AppColors.border)),
          child: Column(children: [
            for (int i = 0; i < items.length; i++)
              Container(
                decoration: BoxDecoration(border: i > 0 ? const Border(top: BorderSide(color: AppColors.border)) : null),
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                child: Row(children: [
                  Expanded(child: Text(items[i], style: AppTheme.sans(size: 13.5, weight: FontWeight.w600))),
                  GestureDetector(
                    onTap: () => onDel(items[i]),
                    child: Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: AppColors.bgSecondary, shape: BoxShape.circle),
                      child: const Text('✕', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                    ),
                  ),
                ]),
              ),
          ]),
        ),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: onAdd,
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.btn),
            border: Border.all(color: AppColors.borderStrong, style: BorderStyle.solid),
          ),
          child: Text(addLabel, style: AppTheme.sans(size: 13, weight: FontWeight.w600, color: AppColors.accentHover)),
        ),
      ),
    ]);
  }

  void _exclPickSheet(AppState app, {required bool isCats}) {
    final List<String> options = isCats
        ? app.categories.map((c) => c.name).where((n) => !_exCats.contains(n)).toList()
        : app.products.map((p) => p.name).where((n) => !_exItems.contains(n)).toList();
    showAppSheet(context, title: isCats ? 'Категория-исключение' : 'Товар-исключение', builder: (ctx) {
      if (options.isEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(child: Text('Всё уже добавлено', style: AppTheme.sans(size: 13, color: AppColors.textTertiary))),
        );
      }
      return Column(children: [
        for (int i = 0; i < options.length; i++)
          InkWell(
            onTap: () {
              setState(() => (isCats ? _exCats : _exItems).add(options[i]));
              Navigator.pop(ctx);
              showToast(context, 'Исключение добавлено');
            },
            child: Container(
              decoration: BoxDecoration(border: i > 0 ? const Border(top: BorderSide(color: AppColors.border)) : null),
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Row(children: [
                Expanded(child: Text(options[i], style: AppTheme.sans(size: 14, weight: FontWeight.w500))),
                const Icon(Icons.add, size: 18, color: AppColors.accent),
              ]),
            ),
          ),
      ]);
    });
  }

  // ════════════════════ ЯРДАМЧИ ВИДЖЕТЛАР ══════════════════════
  Widget _softChip({required String label, String? trailing, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: AppTheme.sans(size: 12.5, weight: FontWeight.w600, color: AppColors.textSecondary)),
          if (trailing != null) ...[
            const SizedBox(width: 5),
            Text(trailing, style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
          ],
        ]),
      ),
    );
  }

  Widget _pill(String text, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
        child: Text(text, style: AppTheme.sans(size: 10.5, weight: FontWeight.w700, color: fg)),
      );

  // Guruh nomiga qarab badge rangi (VIP→accent, Постоянные→success, else neutral).
  (Color, Color) _groupBadge(String group) {
    if (group == 'VIP') return (AppColors.accentHover, AppColors.accentSoft);
    if (group == 'Постоянные') return (AppColors.success, AppColors.successSoft);
    return (AppColors.textSecondary, AppColors.bgSecondary);
  }

  int _groupPercent(AppState app, String group) {
    final g = app.clientGroups.where((g) => g.name == group);
    return g.isEmpty ? 0 : g.first.percent;
  }

  // birthday «14.03.1992» — bu oyda tug'ilganmi?
  bool _isBirthThisMonth(String? birthday) {
    if (birthday == null || birthday.isEmpty) return false;
    final parts = birthday.split('.');
    if (parts.length < 2) return false;
    final m = int.tryParse(parts[1]);
    return m != null && m == DateTime.now().month;
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 120, child: Text(k, style: AppTheme.sans(size: 13, color: AppColors.textSecondary))),
          Expanded(child: Text(v, style: AppTheme.sans(size: 13, weight: FontWeight.w500))),
        ]),
      );

  Widget _fieldLabel(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t.toUpperCase(), style: AppTheme.sans(size: 11, weight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 0.8)),
      );

  InputDecoration _strongInputDeco() => InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: AppColors.borderStrong)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: AppColors.borderStrong)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
      );

  Widget _sheetInput(TextEditingController c, {String? hint, TextInputType? keyboardType, TextAlign align = TextAlign.left, bool errorBorder = false}) {
    return SizedBox(
      height: 44,
      child: TextField(
        controller: c,
        keyboardType: keyboardType,
        textAlign: align,
        style: AppTheme.sans(size: 13.5),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTheme.sans(size: 13.5, color: AppColors.textTertiary),
          isDense: true,
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.btn), borderSide: BorderSide(color: errorBorder ? AppColors.danger : AppColors.borderStrong)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.btn), borderSide: BorderSide(color: errorBorder ? AppColors.danger : AppColors.borderStrong)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.btn), borderSide: BorderSide(color: errorBorder ? AppColors.danger : AppColors.accent, width: 1.5)),
        ),
      ),
    );
  }

  Widget _smallField(String label, TextEditingController c, ValueChanged<String> onChanged) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(), style: AppTheme.sans(size: 10.5, weight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 0.5)),
      const SizedBox(height: 5),
      SizedBox(
        height: 42,
        child: TextField(
          controller: c,
          onChanged: onChanged,
          style: AppTheme.sans(size: 13),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderStrong)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderStrong)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
          ),
        ),
      ),
    ]);
  }

  Widget _editorInput(TextEditingController c, {String? hint, TextInputType? keyboardType, TextAlign align = TextAlign.left, required ValueChanged<String> onChanged}) {
    return SizedBox(
      height: 42,
      child: TextField(
        controller: c,
        keyboardType: keyboardType,
        textAlign: align,
        onChanged: onChanged,
        style: AppTheme.sans(size: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTheme.sans(size: 13, color: AppColors.textTertiary),
          isDense: true,
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderStrong)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderStrong)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
        ),
      ),
    );
  }

  // Radio (guruh sheet uchun — accentSoft box uslubi).
  Widget _radioBox(bool active, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.accentSoft : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.btn),
          border: Border.all(color: active ? AppColors.accent : AppColors.borderStrong),
        ),
        child: Text(label, style: AppTheme.sans(size: 14, weight: active ? FontWeight.w600 : FontWeight.w400, color: active ? AppColors.accentHover : AppColors.text)),
      ),
    );
  }

  // Radio (aksiya muharriri uchun — aylana + nuqta).
  Widget _radioRow(bool active, String label, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: active ? AppColors.accent : AppColors.borderStrong, width: 1.5),
          ),
          child: Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(shape: BoxShape.circle, color: active ? AppColors.accent : Colors.transparent),
          ),
        ),
        const SizedBox(width: 10),
        Text(label, style: AppTheme.sans(size: 13.5, weight: FontWeight.w600)),
      ]),
    );
  }

  Widget _dayPill(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.posDark : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: active ? AppColors.posDark : AppColors.border),
        ),
        child: Text(label, style: AppTheme.sans(size: 12, weight: FontWeight.w600, color: active ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }

  Widget _toggle(bool on, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 40,
        height: 24,
        decoration: BoxDecoration(color: on ? AppColors.accent : AppColors.borderStrong, borderRadius: BorderRadius.circular(AppRadius.pill)),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x40141413), blurRadius: 3, offset: Offset(0, 1))]),
            ),
          ),
        ),
      ),
    );
  }
}
