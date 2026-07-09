import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme.dart';
import '../../state/app_state.dart';
import '../../models.dart';
import '../../utils/format.dart';
import '../../widgets/ui.dart';
import 'supply_form.dart';

/// Sklad qoldiq birligi (ingredient yoki tovar) — prototip `stockUnits`.
class _Unit {
  final String kind; // ing | prod
  final String emoji;
  final String name;
  final String unit;
  double qty;
  final double limit;
  final int cost; // сум за ед.
  _Unit({required this.kind, required this.emoji, required this.name, required this.unit, required this.qty, required this.limit, required this.cost});
  bool get low => qty < limit;
  int get value => (qty * cost).round();
}

class SkladScreen extends StatefulWidget {
  const SkladScreen({super.key});
  @override
  State<SkladScreen> createState() => _SkladScreenState();
}

class _SkladScreenState extends State<SkladScreen> {
  String _tab = 'balance'; // balance | supplies | wo | inv | sup
  String _filter = 'all'; // all | ing | prod | low

  static const _tabs = [
    ['balance', 'Остатки'],
    ['supplies', 'Поставки'],
    ['wo', 'Списания'],
    ['proc', 'Переработки'],
    ['inv', 'Инвентаризации'],
    ['sup', 'Поставщики'],
  ];

  // Товар-остатки (bo'sh — Остатки → ＋ → Товар orqali kiritiladi).
  final List<Map<String, dynamic>> _prodStock = [];

  List<_Unit> _units(AppState app) => [
    ...app.ingredients.map((i) => _Unit(kind: 'ing', emoji: _ingEmoji(i.name), name: i.name, unit: i.unit, qty: i.stock, limit: i.limit, cost: i.costPerUnit)),
    ..._prodStock.map((p) => _Unit(kind: 'prod', emoji: p['emoji'] as String, name: p['name'] as String, unit: p['unit'] as String, qty: p['qty'] as double, limit: p['limit'] as double, cost: p['cost'] as int)),
  ];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (app.skladOpenLowFilter) {
      _tab = 'balance';
      _filter = 'low';
      app.skladOpenLowFilter = false;
    }
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          _SkladAppBar(title: 'Склад', onBell: () => _openNotifications(app)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: Row(children: [
              Expanded(child: _TabChips(tabs: _tabs, selected: _tab, onSelected: (t) => setState(() => _tab = t))),
              const SizedBox(width: 8),
              _AddSquare(onTap: () => _add(app)),
            ]),
          ),
          Expanded(child: _body(app)),
        ]),
      ),
    );
  }

  void _add(AppState app) {
    switch (_tab) {
      case 'balance': _addStockSheet(app); break;
      case 'supplies': showSupplyForm(context, app); break;
      case 'wo': _writeOffForm(app); break;
      case 'proc': _procForm(app); break;
      case 'inv': _inventoryForm(app); break;
      case 'sup': _supplierForm(app, null); break;
    }
  }

  // ── «＋» на Остатках: nima qo'shamiz? ──
  void _addStockSheet(AppState app) {
    showAppSheet(context, title: 'Добавить', builder: (ctx) => Column(children: [
      _actionRow(ctx, '🧺', 'Ингредиент', 'Сырьё для тех. карт — рис, мясо, овощи…', () => _newItemForm(app, isProduct: false)),
      _actionRow(ctx, '📦', 'Товар', 'Готовый товар для продажи — напитки, лепёшка…', () => _newItemForm(app, isProduct: true)),
      _actionRow(ctx, '🚚', 'Поставка', 'Приход от поставщика — пополнит остатки', () => showSupplyForm(context, app)),
      _actionRow(ctx, '🏬', 'Новый склад', 'Отдельное место хранения', () => _newStorageForm(app)),
      const SizedBox(height: 8),
    ]));
  }

  Widget _actionRow(BuildContext ctx, String emoji, String title, String sub, VoidCallback onTap) {
    return InkWell(
      onTap: () { Navigator.pop(ctx); onTap(); },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(children: [
          Container(width: 40, height: 40, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.bgSecondary, borderRadius: BorderRadius.circular(12)), child: Text(emoji, style: const TextStyle(fontSize: 18))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: AppTheme.sans(size: 14.5, weight: FontWeight.w600)),
            Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary)),
          ])),
          const Icon(Icons.chevron_right, size: 17, color: AppColors.textTertiary),
        ]),
      ),
    );
  }

  // ── Yangi ingredient/tovar (Остатки dan) ──
  void _newItemForm(AppState app, {required bool isProduct}) {
    final name = TextEditingController();
    final qtyCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final limitCtrl = TextEditingController();
    String unit = isProduct ? 'шт' : 'кг';
    String wh = app.storageNames.first;
    int categoryId = app.categories.isNotEmpty ? app.categories.last.id : 1;
    showAppSheet(context, title: isProduct ? 'Новый товар' : 'Новый ингредиент', builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LabeledField(label: 'Название *', controller: name, hint: isProduct ? 'Например: Сок яблочный 1 л' : 'Например: Нут'),
      const SizedBox(height: 12),
      _sub('Единица измерения'),
      _chipRow(const ['шт', 'кг', 'л'], unit, (v) => setS(() => unit = v)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: LabeledField(label: 'Количество', controller: qtyCtrl, hint: '0', keyboardType: TextInputType.number)),
        const SizedBox(width: 8),
        Expanded(child: LabeledField(label: 'Закупка, сум/ед.', controller: costCtrl, hint: '0', keyboardType: TextInputType.number)),
      ]),
      const SizedBox(height: 12),
      LabeledField(label: 'Лимит — мин. остаток для ⚠️ предупреждения', controller: limitCtrl, hint: 'Например: 2', keyboardType: TextInputType.number),
      if (isProduct) ...[
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: LabeledField(label: 'Цена продажи, сум', controller: priceCtrl, hint: '0', keyboardType: TextInputType.number)),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sub('Категория'),
            _dropdown(app.categoryById(categoryId).name, app.categories.map((c) => c.name).toList(), (v) => setS(() => categoryId = app.categories.firstWhere((c) => c.name == v).id)),
          ])),
        ]),
      ],
      const SizedBox(height: 12),
      _sub('Склад'),
      _dropdown(wh, app.storageNames, (v) => setS(() => wh = v)),
      const SizedBox(height: 4),
      Text('Если указать количество — автоматически создастся поставка «Начальные остатки»', style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary)),
      const SizedBox(height: 18),
      PrimaryButton('Сохранить', onPressed: () {
        if (name.text.trim().isEmpty) { showToast(ctx, 'Введите название', color: AppColors.danger, bg: AppColors.dangerSoft, icon: Icons.error_outline); return; }
        final q = double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? 0;
        final cost = int.tryParse(costCtrl.text) ?? 0;
        final lim = double.tryParse(limitCtrl.text.replaceAll(',', '.')) ?? 0;
        final nm = name.text.trim();
        if (isProduct) {
          app.addProduct(Product(id: app.newProductId(), name: nm, categoryId: categoryId, type: 'product', workshop: null, price: int.tryParse(priceCtrl.text) ?? 0, cost: cost, photo: '📦'));
          setState(() => _prodStock.add({'emoji': '📦', 'name': nm, 'unit': unit, 'qty': q, 'limit': lim, 'cost': cost}));
        } else {
          app.addIngredient(Ingredient(id: app.newIngredientId(), name: nm, unit: unit, stock: q, costPerUnit: cost, limit: lim));
        }
        if (q > 0) {
          app.addSupplyRaw(Supply(
            id: app.newSupplyId(), date: _today(), supplier: 'Начальные остатки', storage: wh,
            items: '$nm ×${qty(q)}', sum: (q * cost).round(), debt: 0, status: 'Проведена',
          ));
        }
        app.notify();
        Navigator.pop(ctx);
        showToast(context, isProduct ? 'Товар добавлен — он на Остатках и в Меню' : 'Ингредиент добавлен');
      }),
      const SizedBox(height: 8),
    ])));
  }

  // ── Yangi sklad ──
  void _newStorageForm(AppState app) {
    final name = TextEditingController();
    showAppSheet(context, title: 'Новый склад', builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LabeledField(label: 'Название *', controller: name, hint: 'Например: Склад кондитерки'),
      const SizedBox(height: 4),
      Text('Склад появится в формах поставок, списаний и инвентаризаций', style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary)),
      const SizedBox(height: 18),
      PrimaryButton('Сохранить', onPressed: () {
        if (name.text.trim().isEmpty) { showToast(ctx, 'Введите название', color: AppColors.danger, bg: AppColors.dangerSoft, icon: Icons.error_outline); return; }
        app.addStorage(name.text.trim());
        Navigator.pop(ctx);
        showToast(context, 'Склад «${name.text.trim()}» добавлен');
      }),
      const SizedBox(height: 8),
    ]));
  }

  Widget _body(AppState app) {
    switch (_tab) {
      case 'balance': return _balance(app);
      case 'supplies': return _supplies(app);
      case 'wo': return _writeOffs(app);
      case 'proc': return _processings(app);
      case 'inv': return _inventories(app);
      case 'sup': return _suppliers(app);
      default: return const SizedBox();
    }
  }

  // ── Остатки ──
  Widget _balance(AppState app) {
    final units = _units(app);
    final lows = units.where((u) => u.low).toList();
    final total = units.fold<int>(0, (s, u) => s + u.value);
    List<_Unit> list;
    switch (_filter) {
      case 'ing': list = units.where((u) => u.kind == 'ing').toList(); break;
      case 'prod': list = units.where((u) => u.kind == 'prod').toList(); break;
      case 'low': list = lows; break;
      default: list = units;
    }
    const filters = [['all', 'Все'], ['ing', 'Ингредиенты'], ['prod', 'Товары'], ['low', '⚠ Ниже лимита']];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
      children: [
        // Стоимость склада
        Container(
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.card), border: Border.all(color: AppColors.border), boxShadow: kSoftShadow),
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Стоимость склада', style: AppTheme.sans(size: 13, weight: FontWeight.w500, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            RichText(text: TextSpan(children: [
              TextSpan(text: groupNum(total), style: AppTheme.serif(size: 27, weight: FontWeight.w700)),
              TextSpan(text: ' сум', style: AppTheme.serif(size: 15, weight: FontWeight.w400, color: AppColors.textTertiary)),
            ])),
            if (lows.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                decoration: BoxDecoration(color: AppColors.warningSoft, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFEFE0C4))),
                child: Row(children: [
                  const Text('⚠️', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${lows.length} ${_plural(lows.length, "позиция", "позиции", "позиций")} ниже лимита — пополните запасы', style: AppTheme.sans(size: 12, color: AppColors.textSecondary))),
                ]),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 10),
        // Filtr chiplari
        SizedBox(
          height: 30,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) {
              final active = filters[i][0] == _filter;
              return GestureDetector(
                onTap: () => setState(() => _filter = filters[i][0]),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: active ? AppColors.posDark : AppColors.surface, borderRadius: BorderRadius.circular(999), border: Border.all(color: active ? AppColors.posDark : AppColors.border)),
                  child: Text(filters[i][1], style: AppTheme.sans(size: 12, weight: FontWeight.w600, color: active ? Colors.white : AppColors.textSecondary)),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        if (list.isEmpty)
          _listCard([
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('✅', style: TextStyle(fontSize: 30)),
                const SizedBox(height: 8),
                Text('Здесь пусто', style: AppTheme.sans(size: 13.5, weight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text('По выбранному фильтру позиций нет', textAlign: TextAlign.center, style: AppTheme.sans(size: 12, color: AppColors.textSecondary)),
              ])),
            ),
          ])
        else
          _listCard([
            for (int i = 0; i < list.length; i++) _balRow(app, list[i], first: i == 0),
          ]),
      ],
    );
  }

  Widget _balRow(AppState app, _Unit u, {required bool first}) {
    return InkWell(
      onTap: () => _stockDetail(app, u),
      child: Container(
        decoration: BoxDecoration(border: first ? null : const Border(top: BorderSide(color: AppColors.border))),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        child: Row(children: [
          Container(width: 34, height: 34, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.bgSecondary, borderRadius: BorderRadius.circular(10)), child: Text(u.emoji, style: const TextStyle(fontSize: 16))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(u.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(size: 13.5, weight: FontWeight.w600)),
            Text('${u.kind == "ing" ? "Ингредиент" : "Товар"} · лимит ${qty(u.limit)} ${u.unit}', style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${qty(u.qty)} ${u.unit}', style: AppTheme.sans(size: 13, weight: FontWeight.w700, color: u.low ? AppColors.danger : AppColors.text)),
            Text('${groupNum(u.value)} сум', style: AppTheme.sans(size: 11, color: AppColors.textTertiary)),
          ]),
          const SizedBox(width: 8),
          const Text('›', style: TextStyle(fontSize: 16, color: AppColors.textTertiary)),
        ]),
      ),
    );
  }

  // ── Поставки ──
  Widget _supplies(AppState app) {
    if (app.supplies.isEmpty) {
      return const EmptyState(emoji: '🚚', title: 'Поставок пока нет', subtitle: 'Добавьте первую поставку по ＋ сверху — остатки склада увеличатся.');
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
      itemCount: app.supplies.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final s = app.supplies[i];
        return InkWell(
          onTap: () => _supplyDetail(app, s),
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Container(
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.card), border: Border.all(color: AppColors.border), boxShadow: kSoftShadow),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                RichText(text: TextSpan(children: [
                  TextSpan(text: '№${s.id} ', style: AppTheme.sans(size: 14, weight: FontWeight.w700)),
                  TextSpan(text: '· ${s.date}', style: AppTheme.sans(size: 14, weight: FontWeight.w500, color: AppColors.textTertiary)),
                ])),
                const Spacer(),
                s.debt > 0 ? StatusBadge.danger('Долг ${groupNum(s.debt)}') : StatusBadge.success('Оплачена'),
              ]),
              const SizedBox(height: 5),
              Text('${s.supplier} → ${s.storage}', style: AppTheme.sans(size: 12.5, color: AppColors.textSecondary)),
              const SizedBox(height: 3),
              Text(s.items, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary)),
              const SizedBox(height: 7),
              const Divider(color: AppColors.border, height: 1),
              const SizedBox(height: 8),
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text('Сумма поставки', style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary)),
                const Spacer(),
                Text(sum(s.sum), style: AppTheme.sans(size: 14, weight: FontWeight.w700)),
              ]),
            ]),
          ),
        );
      },
    );
  }

  // ── Списания ──
  Widget _writeOffs(AppState app) {
    if (app.wastes.isEmpty) {
      return const EmptyState(emoji: '🗑️', title: 'Нет списаний', subtitle: 'Добавьте списание порчи или боя.');
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
      children: [
        _listCard([
          for (int i = 0; i < app.wastes.length; i++) _woRow(app.wastes[i], first: i == 0),
        ]),
      ],
    );
  }

  Widget _woRow(Map<String, dynamic> w, {required bool first}) {
    final reason = w['reason'] as String;
    final danger = reason == 'Порча' || reason == 'Бой' || reason == 'Бой/брак' || reason == 'Кража';
    return Container(
      decoration: BoxDecoration(border: first ? null : const Border(top: BorderSide(color: AppColors.border))),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(w['date'] as String, style: AppTheme.sans(size: 13, weight: FontWeight.w700)),
          const SizedBox(width: 8),
          danger ? StatusBadge.danger(reason) : StatusBadge.warning(reason),
          const Spacer(),
          Text('−${groupNum(w['sum'] as int)}', style: AppTheme.sans(size: 13.5, weight: FontWeight.w700)),
        ]),
        const SizedBox(height: 4),
        Text(w['items'] as String, style: AppTheme.sans(size: 12.5, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text('${w['employee']}${(w['comment'] as String?)?.isNotEmpty == true ? ' · ${w['comment']}' : ''}', style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary)),
      ]),
    );
  }

  // ── Инвентаризации ──
  Widget _inventories(AppState app) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
      children: [
        _listCard([
          if (app.inventoryChecks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              child: Center(child: Text('Инвентаризаций пока нет — создайте по ＋ сверху', style: AppTheme.sans(size: 12.5, color: AppColors.textTertiary))),
            )
          else
            for (int i = 0; i < app.inventoryChecks.length; i++) _invRow(app, app.inventoryChecks[i], first: i == 0),
        ]),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Text('Черновик можно открыть и продолжить подсчёт', textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary)),
        ),
      ],
    );
  }

  Widget _invRow(AppState app, Map<String, dynamic> v, {required bool first}) {
    final result = v['result'] as int;
    final draft = (v['status'] as String) == 'Черновик';
    return InkWell(
      onTap: draft ? () => _inventoryForm(app) : null,
      child: Container(
      decoration: BoxDecoration(border: first ? null : const Border(top: BorderSide(color: AppColors.border))),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('№${v['id']} · ${v['storage']}', style: AppTheme.sans(size: 13.5, weight: FontWeight.w700)),
          Text('${v['date']} · ${v['type']}', style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(result == 0 ? '±0' : (result > 0 ? '+${groupNum(result)}' : '−${groupNum(result.abs())}'), style: AppTheme.sans(size: 13.5, weight: FontWeight.w700, color: result < 0 ? AppColors.danger : (result > 0 ? AppColors.success : AppColors.textSecondary))),
          const SizedBox(height: 2),
          draft ? StatusBadge.warning('Черновик') : StatusBadge.success('Проведена'),
        ]),
        if (draft) ...[const SizedBox(width: 8), const Text('›', style: TextStyle(fontSize: 16, color: AppColors.textTertiary))],
      ]),
      ),
    );
  }

  // ── Поставщики ──
  Widget _suppliers(AppState app) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
      children: [
        _listCard([
          if (app.suppliers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              child: Center(child: Text('Добавьте первого поставщика по ＋ сверху', style: AppTheme.sans(size: 12.5, color: AppColors.textTertiary))),
            )
          else
            for (int i = 0; i < app.suppliers.length; i++) _supplierRow(app, app.suppliers[i], first: i == 0),
        ]),
      ],
    );
  }

  Widget _supplierRow(AppState app, Supplier s, {required bool first}) {
    return InkWell(
      onTap: () => _supplierForm(app, s),
      child: Container(
        decoration: BoxDecoration(border: first ? null : const Border(top: BorderSide(color: AppColors.border))),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        child: Row(children: [
          Container(width: 38, height: 38, alignment: Alignment.center, decoration: const BoxDecoration(color: AppColors.bgSecondary, shape: BoxShape.circle), child: const Text('🚚', style: TextStyle(fontSize: 17))),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(size: 13.5, weight: FontWeight.w600)),
            Text('${s.phone} · ${s.suppliesCount} ${_plural(s.suppliesCount, "поставка", "поставки", "поставок")} · ${sum(s.suppliesSum)}', style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary)),
            if (s.debt > 0) Text('Долг ${sum(s.debt)}', style: AppTheme.sans(size: 11.5, weight: FontWeight.w700, color: AppColors.danger)),
          ])),
          const SizedBox(width: 8),
          const Text('›', style: TextStyle(fontSize: 16, color: AppColors.textTertiary)),
        ]),
      ),
    );
  }

  // ── Остаток detali sheet ──
  void _stockDetail(AppState app, _Unit u) {
    showAppSheet(context, title: u.name, builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(u.kind == 'ing' ? 'Ингредиент' : 'Товар', style: AppTheme.sans(size: 12, color: AppColors.textTertiary)),
      const SizedBox(height: 12),
      Row(children: [
        _statTile('Остаток', '${qty(u.qty)} ${u.unit}', color: u.low ? AppColors.danger : AppColors.text),
        _statTile('Лимит', '${qty(u.limit)} ${u.unit}'),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        _statTile('Цена за ед.', '${groupNum(u.cost)} сум'),
        _statTile('Стоимость', sum(u.value)),
      ]),
      const SizedBox(height: 8),
    ]));
  }

  Widget _statTile(String label, String value, {Color color = AppColors.text}) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: AppTheme.sans(size: 11, color: AppColors.textTertiary)),
    const SizedBox(height: 2),
    Text(value, style: AppTheme.sans(size: 15, weight: FontWeight.w700, color: color)),
  ]));

  // ── Поставка detali sheet ──
  void _supplyDetail(AppState app, Supply s) {
    showAppSheet(context, title: 'Поставка №${s.id}', builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${s.date} · ${s.supplier} · ${s.storage}', style: AppTheme.sans(size: 12.5, color: AppColors.textSecondary)),
      const SizedBox(height: 12),
      Text(s.items, style: AppTheme.sans(size: 13.5)),
      const SizedBox(height: 14),
      if (s.debt > 0) Row(children: [
        Text('Долг', style: AppTheme.sans(size: 13, color: AppColors.danger, weight: FontWeight.w600)),
        const Spacer(),
        Text(sum(s.debt), style: AppTheme.sans(size: 14, weight: FontWeight.w700, color: AppColors.danger)),
      ]),
      const SizedBox(height: 6),
      Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Text('Сумма поставки', style: AppTheme.sans(size: 13, color: AppColors.textSecondary)),
        const Spacer(),
        Text(sum(s.sum), style: AppTheme.serif(size: 17, weight: FontWeight.w700)),
      ]),
      const SizedBox(height: 8),
    ]));
  }

  // ── Списание formasi ──
  void _writeOffForm(AppState app) {
    if (app.ingredients.isEmpty) {
      showToast(context, 'Списывать нечего — сначала добавьте ингредиенты (＋ на Остатках)', color: AppColors.warning, bg: AppColors.warningSoft, icon: Icons.egg_outlined);
      return;
    }
    String wh = app.storageNames.first;
    String reason = 'Порча';
    final comment = TextEditingController();
    Ingredient sel = app.ingredients.first;
    final qtyCtrl = TextEditingController();
    showAppSheet(context, title: 'Новое списание', builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sub('Склад'),
      _dropdown(wh, app.storageNames, (v) => setS(() => wh = v)),
      const SizedBox(height: 12),
      _sub('Причина'),
      _chipRow(const ['Порча', 'Бой', 'Кража', 'Угощение', 'Другое'], reason, (v) => setS(() => reason = v)),
      const SizedBox(height: 14),
      Text('Позиции', style: AppTheme.sans(size: 14, weight: FontWeight.w700)),
      const SizedBox(height: 9),
      _dropdown(sel.name, app.ingredients.map((e) => e.name).toList(), (v) => setS(() => sel = app.ingredients.firstWhere((e) => e.name == v))),
      const SizedBox(height: 8),
      LabeledField(label: 'Количество (${sel.unit})', controller: qtyCtrl, keyboardType: TextInputType.number),
      const SizedBox(height: 12),
      _sub('Комментарий'),
      LabeledField(label: '', controller: comment, hint: 'Например: разбили при разгрузке'),
      const SizedBox(height: 20),
      PrimaryButton('Списать', onPressed: () {
        final q = double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? 0;
        if (q <= 0) { showToast(ctx, 'Введите количество', color: AppColors.danger, bg: AppColors.dangerSoft, icon: Icons.error_outline); return; }
        app.writeOff([(ing: sel, qty: q)]);
        final waste = {'date': _today(), 'storage': wh, 'items': '${sel.name} ×${qty(q)}', 'sum': (q * sel.costPerUnit).round(), 'employee': app.currentUser.name, 'reason': reason, 'comment': comment.text.trim()};
        app.wastes.insert(0, waste);
        if (app.repo.ready) app.repo.saveWasteRaw(Map<String, dynamic>.from(waste));
        app.notify();
        Navigator.pop(ctx);
        showToast(context, 'Списание сохранено — остатки уменьшены', color: AppColors.danger, bg: AppColors.dangerSoft, icon: Icons.delete_outline);
      }),
      const SizedBox(height: 8),
    ])));
  }

  // ── Переработка ro'yxati ──
  Widget _processings(AppState app) {
    if (app.processings.isEmpty) {
      return const EmptyState(emoji: '🔄', title: 'Нет переработок', subtitle: 'Переработка превращает один ингредиент в другой (например, тушу — в разделанное мясо): расход одного, приход другого.');
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
      children: [
        _listCard([
          for (int i = 0; i < app.processings.length; i++) _procRow(app.processings[i], first: i == 0),
        ]),
      ],
    );
  }

  Widget _procRow(Map<String, dynamic> p, {required bool first}) {
    return Container(
      decoration: BoxDecoration(border: first ? null : const Border(top: BorderSide(color: AppColors.border))),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${p['from']} → ${p['to']}', style: AppTheme.sans(size: 13, weight: FontWeight.w600)),
          Text('${p['date']}', style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('−${qty(p['fromQty'] as double)} ${p['fromUnit']}', style: AppTheme.sans(size: 12, weight: FontWeight.w600, color: AppColors.danger)),
          Text('+${qty(p['toQty'] as double)} ${p['toUnit']}', style: AppTheme.sans(size: 12, weight: FontWeight.w600, color: AppColors.success)),
        ]),
      ]),
    );
  }

  // ── Переработка formasi ──
  void _procForm(AppState app) {
    if (app.ingredients.length < 2) {
      showToast(context, 'Нужно минимум 2 ингредиента для переработки', color: AppColors.warning, bg: AppColors.warningSoft, icon: Icons.info_outline);
      return;
    }
    Ingredient from = app.ingredients.first;
    Ingredient to = app.ingredients[1];
    final fromQty = TextEditingController();
    final toQty = TextEditingController();
    showAppSheet(context, title: 'Новая переработка', builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sub('Из чего (расход)'),
      _dropdown(from.name, app.ingredients.map((e) => e.name).toList(), (v) => setS(() => from = app.ingredients.firstWhere((e) => e.name == v))),
      const SizedBox(height: 8),
      LabeledField(label: 'Количество (${from.unit})', controller: fromQty, keyboardType: TextInputType.number),
      const SizedBox(height: 14),
      _sub('Во что (приход)'),
      _dropdown(to.name, app.ingredients.map((e) => e.name).toList(), (v) => setS(() => to = app.ingredients.firstWhere((e) => e.name == v))),
      const SizedBox(height: 8),
      LabeledField(label: 'Количество на выходе (${to.unit})', controller: toQty, keyboardType: TextInputType.number),
      const SizedBox(height: 20),
      PrimaryButton('Переработать', onPressed: () {
        final fq = double.tryParse(fromQty.text.replaceAll(',', '.')) ?? 0;
        final tq = double.tryParse(toQty.text.replaceAll(',', '.')) ?? 0;
        if (from.id == to.id) { showToast(ctx, 'Выберите разные ингредиенты', color: AppColors.warning, bg: AppColors.warningSoft, icon: Icons.info_outline); return; }
        if (fq <= 0 || tq <= 0) { showToast(ctx, 'Введите количества', color: AppColors.danger, bg: AppColors.dangerSoft, icon: Icons.error_outline); return; }
        app.addProcessing(from: from, fromQty: fq, to: to, toQty: tq, date: _today());
        Navigator.pop(ctx);
        showToast(context, 'Переработка проведена — остатки обновлены', icon: Icons.sync_alt);
      }),
      const SizedBox(height: 8),
    ])));
  }

  // ── Инвентаризация formasi ──
  void _inventoryForm(AppState app) {
    if (app.ingredients.isEmpty) {
      showToast(context, 'Инвентаризация недоступна — на складе нет позиций', color: AppColors.warning, bg: AppColors.warningSoft, icon: Icons.inventory_2_outlined);
      return;
    }
    String wh = app.storageNames.first;
    final facts = <String, TextEditingController>{for (final i in app.ingredients) i.name: TextEditingController()};
    showAppSheet(context, title: 'Новая инвентаризация', builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
      int result = 0;
      for (final i in app.ingredients) {
        final f = facts[i.name]!.text.trim();
        if (f.isEmpty) continue;
        final fv = double.tryParse(f.replaceAll(',', '.')) ?? i.stock;
        result += ((fv - i.stock) * i.costPerUnit).round();
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sub('Склад'),
        _dropdown(wh, app.storageNames, (v) => setS(() => wh = v)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _colHead('Продукт', TextAlign.left)),
          SizedBox(width: 48, child: _colHead('Учёт', TextAlign.right)),
          SizedBox(width: 60, child: _colHead('Факт', TextAlign.right)),
          SizedBox(width: 52, child: _colHead('Разн.', TextAlign.right)),
        ]),
        const SizedBox(height: 5),
        for (final i in app.ingredients) _invFormRow(i, facts[i.name]!, () => setS(() {})),
        const SizedBox(height: 10),
        const Divider(color: AppColors.borderStrong, height: 1),
        const SizedBox(height: 8),
        Align(alignment: Alignment.centerRight, child: Text(result == 0 ? 'Расхождений нет' : (result < 0 ? 'Недостача ${sum(result.abs())}' : 'Излишек ${sum(result)}'), style: AppTheme.sans(size: 13.5, weight: FontWeight.w700, color: result < 0 ? AppColors.danger : (result > 0 ? AppColors.success : AppColors.textSecondary)))),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: SecondaryButton('Черновик', expand: true, onPressed: () {
            app.addInventoryCheck({'id': app.inventoryChecks.length + 1, 'storage': wh, 'date': _today(), 'type': 'Полная', 'result': result, 'status': 'Черновик'});
            Navigator.pop(ctx);
            showToast(context, 'Инвентаризация сохранена как черновик', icon: Icons.save_outlined);
          })),
          const SizedBox(width: 8),
          Expanded(child: PrimaryButton('Провести', color: AppColors.success, onPressed: () {
            for (final i in app.ingredients) {
              final f = facts[i.name]!.text.trim();
              if (f.isEmpty) continue;
              i.stock = double.tryParse(f.replaceAll(',', '.')) ?? i.stock;
              app.saveIngredient(i); // skorrektirlangan qoldiq Firestore'ga
            }
            app.addInventoryCheck({'id': app.inventoryChecks.length + 1, 'storage': wh, 'date': _today(), 'type': 'Полная', 'result': result, 'status': 'Проведена'});
            Navigator.pop(ctx);
            showToast(context, 'Инвентаризация проведена — остатки скорректированы', icon: Icons.assignment_turned_in_outlined);
          })),
        ]),
        const SizedBox(height: 8),
      ]);
    }));
  }

  Widget _invFormRow(Ingredient i, TextEditingController fact, VoidCallback onChanged) {
    final f = fact.text.trim();
    final diff = f.isEmpty ? null : (double.tryParse(f.replaceAll(',', '.')) ?? i.stock) - i.stock;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(child: Text(i.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(size: 12, weight: FontWeight.w600))),
        SizedBox(width: 48, child: Text(qty(i.stock), textAlign: TextAlign.right, style: AppTheme.sans(size: 12, color: AppColors.textSecondary))),
        const SizedBox(width: 6),
        SizedBox(width: 56, child: SizedBox(height: 34, child: TextField(
          controller: fact,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.right,
          onChanged: (_) => onChanged(),
          style: AppTheme.sans(size: 12),
          decoration: InputDecoration(hintText: '—', hintStyle: AppTheme.sans(size: 12, color: AppColors.textTertiary), isDense: true, filled: true, fillColor: AppColors.surface, contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.borderStrong)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.borderStrong)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.accent, width: 1.5))),
        ))),
        const SizedBox(width: 6),
        SizedBox(width: 52, child: Text(diff == null ? '—' : (diff > 0 ? '+${qty(diff)}' : (diff < 0 ? '−${qty(diff.abs())}' : '0')), textAlign: TextAlign.right, style: AppTheme.sans(size: 12, weight: FontWeight.w700, color: diff == null ? AppColors.textTertiary : (diff < 0 ? AppColors.danger : (diff > 0 ? AppColors.success : AppColors.textTertiary))))),
      ]),
    );
  }

  // ── Поставщик formasi ──
  void _supplierForm(AppState app, Supplier? existing) {
    final name = TextEditingController(text: existing?.name ?? '');
    final phone = TextEditingController(text: existing?.phone ?? '+998 ');
    final address = TextEditingController();
    final comment = TextEditingController();
    showAppSheet(context, title: existing == null ? 'Новый поставщик' : 'Поставщик', builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LabeledField(label: 'Название *', controller: name, hint: 'Например: Агро Базар'),
      const SizedBox(height: 12),
      LabeledField(label: 'Телефон', controller: phone, keyboardType: TextInputType.phone),
      const SizedBox(height: 12),
      LabeledField(label: 'Адрес', controller: address),
      const SizedBox(height: 12),
      LabeledField(label: 'Комментарий', controller: comment, maxLines: 2),
      const SizedBox(height: 20),
      PrimaryButton('Сохранить', onPressed: () {
        if (name.text.trim().isEmpty) { showToast(ctx, 'Введите название', color: AppColors.danger, bg: AppColors.dangerSoft, icon: Icons.error_outline); return; }
        if (existing != null) {
          existing.name = name.text.trim();
          existing.phone = phone.text.trim();
          if (app.repo.ready) app.repo.saveSupplier(existing);
          app.notify();
        } else {
          app.addSupplier(Supplier(id: app.newSupplierId(), name: name.text.trim(), phone: phone.text.trim()));
        }
        Navigator.pop(ctx);
        showToast(context, 'Поставщик сохранён');
      }),
      const SizedBox(height: 8),
    ]));
  }

  void _openNotifications(AppState app) {
    final lows = _units(app).where((u) => u.low).toList();
    showAppSheet(context, title: 'Уведомления', builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (lows.isNotEmpty)
        Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 36, height: 36, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.warningSoft, borderRadius: BorderRadius.circular(10)), child: const Text('⚠️', style: TextStyle(fontSize: 17))),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${lows.first.name} ниже лимита', style: AppTheme.sans(size: 13.5, weight: FontWeight.w600)),
            Text('Осталось ${qty(lows.first.qty)} ${lows.first.unit} при лимите ${qty(lows.first.limit)} ${lows.first.unit}', style: AppTheme.sans(size: 12, color: AppColors.textSecondary, height: 1.3)),
          ])),
          Text('12 мин', style: AppTheme.sans(size: 11, color: AppColors.textTertiary)),
        ]))
      else
        Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Center(child: Text('Новых уведомлений нет', style: AppTheme.sans(size: 13.5, color: AppColors.textSecondary)))),
      const SizedBox(height: 8),
    ]));
  }

  // ── Umumiy widgetlar/helperlar ──
  Widget _listCard(List<Widget> children) => Container(
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.card), border: Border.all(color: AppColors.border), boxShadow: kSoftShadow),
    clipBehavior: Clip.antiAlias,
    child: Column(children: children),
  );

  Widget _sub(String t) => Padding(padding: const EdgeInsets.only(bottom: 5), child: Text(t.toUpperCase(), style: AppTheme.sans(size: 10.5, weight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 0.5)));

  Widget _colHead(String t, TextAlign align) => Text(t.toUpperCase(), textAlign: align, style: AppTheme.sans(size: 9.5, weight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 0.4));

  Widget _chipRow(List<String> opts, String selected, ValueChanged<String> onSelected) => Wrap(spacing: 6, runSpacing: 6, children: opts.map((o) {
    final active = o == selected;
    return GestureDetector(
      onTap: () => onSelected(o),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: active ? AppColors.posDark : AppColors.surface, borderRadius: BorderRadius.circular(999), border: Border.all(color: active ? AppColors.posDark : AppColors.border)),
        child: Text(o, style: AppTheme.sans(size: 12, weight: FontWeight.w600, color: active ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }).toList());

  Widget _dropdown(String value, List<String> options, ValueChanged<String> onChanged) {
    final safe = options.contains(value) ? value : options.first;
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.borderStrong)),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(
        value: safe, isExpanded: true,
        icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
        style: AppTheme.sans(size: 13, color: AppColors.text),
        items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
        onChanged: (v) { if (v != null) onChanged(v); },
      )),
    );
  }

  String _today() {
    final d = DateTime.now();
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
  }

  String _plural(int n, String one, String few, String many) {
    final m10 = n % 10, m100 = n % 100;
    if (m10 == 1 && m100 != 11) return one;
    if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return few;
    return many;
  }
}

const Map<String, String> _kIngEmoji = {
  'Рис лазер': '🍚', 'Рис девзира': '🍚',
  'Морковь жёлтая': '🥕', 'Морковь': '🥕',
  'Говядина': '🥩', 'Баранина': '🍖', 'Курица': '🍗',
  'Лук репчатый': '🧅',
  'Масло растительное': '🛢️', 'Масло хлопковое': '🛢️',
  'Чай чёрный (сухой)': '🍵', 'Чай листовой': '🍵',
  'Мука': '🌾', 'Помидоры': '🍅', 'Огурцы': '🥒', 'Картофель': '🥔',
  'Кока-Кола 0,5 (бут)': '🥤', 'Кофе зерновой': '☕', 'Кофе зерновой ': '☕',
  'Сахар': '🧂', 'Соль': '🧂', 'Специи для плова': '🧂', 'Лапша для лагмана': '🍜',
};

String _ingEmoji(String name) => _kIngEmoji[name] ?? '📦';

// ── Chip qatori (POS-dark tanlangan) ──
class _TabChips extends StatelessWidget {
  final List<List<String>> tabs;
  final String selected;
  final ValueChanged<String> onSelected;
  const _TabChips({required this.tabs, required this.selected, required this.onSelected});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final active = tabs[i][0] == selected;
          return GestureDetector(
            onTap: () => onSelected(tabs[i][0]),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(color: active ? AppColors.posDark : AppColors.surface, borderRadius: BorderRadius.circular(999), border: Border.all(color: active ? AppColors.posDark : AppColors.border)),
              child: Text(tabs[i][1], style: AppTheme.sans(size: 12.5, weight: FontWeight.w600, color: active ? Colors.white : AppColors.textSecondary)),
            ),
          );
        },
      ),
    );
  }
}

class _AddSquare extends StatelessWidget {
  final VoidCallback onTap;
  const _AddSquare({required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36, height: 36, alignment: Alignment.center,
      decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(10)),
      child: const Text('＋', style: TextStyle(fontSize: 19, color: Colors.white)),
    ),
  );
}

class _SkladAppBar extends StatelessWidget {
  final String title;
  final VoidCallback onBell;
  const _SkladAppBar({required this.title, required this.onBell});
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: Padding(
      padding: const EdgeInsets.only(left: 20, right: 16),
      child: Row(children: [
        Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(size: 17, weight: FontWeight.w600, letterSpacing: -0.2))),
        _SkladBell(onTap: onBell),
      ]),
    ),
  );
}

class _SkladBell extends StatelessWidget {
  final VoidCallback onTap;
  const _SkladBell({required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 38, height: 38,
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Stack(alignment: Alignment.center, children: [
        const Text('🔔', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
        Positioned(top: 8, right: 9, child: Container(width: 7, height: 7, decoration: BoxDecoration(color: AppColors.danger, shape: BoxShape.circle, border: Border.all(color: AppColors.surface, width: 1.5)))),
      ]),
    ),
  );
}
