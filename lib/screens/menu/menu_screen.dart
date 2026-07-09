import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme.dart';
import '../../state/app_state.dart';
import '../../models.dart';
import '../../utils/format.dart';
import '../../widgets/ui.dart';
import 'product_form.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});
  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  String _tab = 'items'; // items | tech | ing | cats | shops
  int? _catFilter; // null = barchasi
  String _q = '';
  int? _expanded; // ochilgan tex-karta product id
  final _searchCtrl = TextEditingController();
  // Цехи — prototip: Бар, Кухня (бегунок печатается на принтере цеха)
  final List<Map<String, dynamic>> _shops = [
    {'name': 'Бар', 'runner': true},
    {'name': 'Кухня', 'runner': true},
  ];

  static const _tabs = [
    ['items', 'Товары'],
    ['tech', 'Тех. карты'],
    ['ing', 'Ингредиенты'],
    ['cats', 'Категории'],
    ['shops', 'Цехи'],
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          _MenuAppBar(title: 'Меню', onBell: () => _openNotifications(app)),
          // ── Chip qatori + «＋» tugma ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: Row(children: [
              Expanded(child: _TabChips(tabs: _tabs, selected: _tab, onSelected: (t) => setState(() { _tab = t; _catFilter = null; _q = ''; _expanded = null; _searchCtrl.clear(); }))),
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
    // Hali kategoriya yo'q bo'lsa — tovar/tex-karta o'rniga avval kategoriya
    // yaratishga o'tkazamiz (aks holda «Сначала создайте категорию» tupik chiqadi).
    if ((_tab == 'items' || _tab == 'tech') && app.categories.isEmpty) {
      setState(() => _tab = 'cats');
      _editCategory(app, null);
      return;
    }
    switch (_tab) {
      case 'items': showProductForm(context, app); break;
      case 'tech': showProductForm(context, app, techCard: true); break;
      case 'ing': _addIngredient(app); break;
      case 'cats': _editCategory(app, null); break;
      case 'shops': _addWorkshop(app); break;
    }
  }

  Widget _body(AppState app) {
    switch (_tab) {
      case 'items': return _products(app);
      case 'tech': return _techCards(app);
      case 'ing': return _ingredients(app);
      case 'cats': return _categories(app);
      case 'shops': return _workshops(app);
      default: return const SizedBox();
    }
  }

  // ── Товары ──
  Widget _products(AppState app) {
    final q = _q.trim().toLowerCase();
    var list = app.products.where((p) => p.type == 'product').where((p) =>
        (q.isEmpty || p.name.toLowerCase().contains(q)) &&
        (_catFilter == null || p.categoryId == _catFilter)).toList();
    final catLabel = _catFilter == null ? 'Категория' : app.categoryById(_catFilter!).name;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
      children: [
        // Поиск + категория-чип
        Row(children: [
          Expanded(
            child: SizedBox(
              height: 38,
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _q = v),
                style: AppTheme.sans(size: 13.5),
                decoration: InputDecoration(
                  hintText: 'Поиск по товарам…',
                  hintStyle: AppTheme.sans(size: 13.5, color: AppColors.textTertiary),
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _pickCategoryFilter(app),
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _catFilter == null ? AppColors.surface : AppColors.accentSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(catLabel, style: AppTheme.sans(size: 12.5, weight: FontWeight.w600, color: _catFilter == null ? AppColors.textSecondary : AppColors.accentHover)),
                const SizedBox(width: 5),
                Icon(Icons.keyboard_arrow_down, size: 14, color: _catFilter == null ? AppColors.textSecondary : AppColors.accentHover),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        if (list.isEmpty)
          _listCard([
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              // Umuman tovar yo'q (birinchi kirish) ≠ qidiruv natijasiz.
              child: Center(
                child: app.products.isEmpty && _q.trim().isEmpty && _catFilter == null
                    ? Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text('🍽️', style: TextStyle(fontSize: 30)),
                        const SizedBox(height: 8),
                        Text('В меню пока пусто', style: AppTheme.sans(size: 13.5, weight: FontWeight.w600)),
                        const SizedBox(height: 3),
                        Text('Нажмите + сверху и добавьте первый товар',
                            textAlign: TextAlign.center,
                            style: AppTheme.sans(size: 12, color: AppColors.textSecondary)),
                      ])
                    : const _NothingFound(),
              ),
            ),
          ])
        else
          _listCard([
            for (int i = 0; i < list.length; i++) _productRow(app, list[i], first: i == 0),
          ]),
      ],
    );
  }

  Widget _productRow(AppState app, Product p, {required bool first}) {
    final markup = p.markup;
    final tags = <String>[
      app.categoryById(p.categoryId).name,
      if (p.byWeight) 'весовой',
      if (p.noDiscount) 'без скидок',
    ].join(' · ');
    return InkWell(
      onTap: () => _entMenuSheet(app, product: p),
      child: Container(
        decoration: BoxDecoration(border: first ? null : const Border(top: BorderSide(color: AppColors.border))),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        child: Row(children: [
          ProductThumb(imagePath: p.imagePath, emoji: p.photo),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(size: 13.5, weight: FontWeight.w600)),
            Text(tags, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary)),
          ])),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            RichText(text: TextSpan(children: [
              TextSpan(text: '${groupNum(p.cost)} → ', style: AppTheme.sans(size: 13, weight: FontWeight.w500, color: AppColors.textTertiary)),
              TextSpan(text: groupNum(p.price), style: AppTheme.sans(size: 13, weight: FontWeight.w700)),
            ])),
            Text('+$markup%', style: AppTheme.sans(size: 11, color: AppColors.textTertiary)),
          ]),
          const SizedBox(width: 6),
          const Text('⋯', style: TextStyle(fontSize: 17, color: AppColors.textTertiary)),
        ]),
      ),
    );
  }

  // ── Тех. карты ──
  Widget _techCards(AppState app) {
    final dishes = app.products.where((p) => p.type == 'dish').toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
      children: [
        _listCard([
          if (dishes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              child: Center(child: Text('Тех. карт пока нет — добавьте по ＋ сверху', style: AppTheme.sans(size: 12.5, color: AppColors.textTertiary))),
            )
          else
            for (int i = 0; i < dishes.length; i++) _techRow(app, dishes[i], first: i == 0),
        ]),
      ],
    );
  }

  Widget _techRow(AppState app, Product p, {required bool first}) {
    final markup = p.markup;
    final low = markup < 100;
    final open = _expanded == p.id;
    final recipe = _recipeOf(app, p);
    final out = recipe.fold<num>(0, (s, r) => s + (r['net'] as num));
    return Container(
      decoration: BoxDecoration(border: first ? null : const Border(top: BorderSide(color: AppColors.border))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: () => _entMenuSheet(app, product: p),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(13, 11, 13, 4),
            child: Row(children: [
              ProductThumb(imagePath: p.imagePath, emoji: p.photo),
              const SizedBox(width: 11),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(size: 13.5, weight: FontWeight.w600)),
                Text('Выход ${qty(out)} г · ${app.categoryById(p.categoryId).name}', style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary)),
              ])),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                RichText(text: TextSpan(children: [
                  TextSpan(text: '${groupNum(p.cost)} → ', style: AppTheme.sans(size: 13, weight: FontWeight.w500, color: AppColors.textTertiary)),
                  TextSpan(text: groupNum(p.price), style: AppTheme.sans(size: 13, weight: FontWeight.w700)),
                ])),
                Text('+$markup%', style: AppTheme.sans(size: 11, weight: low ? FontWeight.w700 : FontWeight.w500, color: low ? AppColors.warning : AppColors.textTertiary)),
              ]),
              const SizedBox(width: 6),
              const Text('⋯', style: TextStyle(fontSize: 17, color: AppColors.textTertiary)),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(62, 2, 13, 9),
          child: GestureDetector(
            onTap: () => setState(() => _expanded = open ? null : p.id),
            child: Text(open ? 'Скрыть состав ⌄' : 'Состав ⌃', style: AppTheme.sans(size: 11.5, weight: FontWeight.w600, color: AppColors.accentHover)),
          ),
        ),
        if (open)
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(color: AppColors.bg, border: Border(top: BorderSide(color: AppColors.border, style: BorderStyle.solid))),
            padding: const EdgeInsets.fromLTRB(14, 7, 14, 9),
            child: recipe.isEmpty
                ? Text('Состав тех. карты не заполнен.', style: AppTheme.sans(size: 12, color: AppColors.textTertiary))
                : Column(children: [
                    for (final r in recipe)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3.5),
                        child: Row(children: [
                          Expanded(child: Text(r['name'] as String, style: AppTheme.sans(size: 12, color: AppColors.textSecondary))),
                          SizedBox(width: 62, child: Text('${qty(r['brutto'] as num)} г', textAlign: TextAlign.right, style: AppTheme.sans(size: 12, color: AppColors.textTertiary))),
                          SizedBox(width: 78, child: Text(sum(r['cost'] as num), textAlign: TextAlign.right, style: AppTheme.sans(size: 12, weight: FontWeight.w600))),
                        ]),
                      ),
                  ]),
          ),
      ]),
    );
  }

  // ── Ингредиенты ──
  Widget _ingredients(AppState app) {
    final total = app.ingredients.fold<int>(0, (s, i) => s + i.stockValue);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
      children: [
        _listCard([
          for (int i = 0; i < app.ingredients.length; i++) _ingRow(app, app.ingredients[i], first: i == 0),
          // Итого-полоса
          Container(
            decoration: const BoxDecoration(color: AppColors.bg, border: Border(top: BorderSide(color: AppColors.border))),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text('ИТОГО НА СКЛАДЕ', style: AppTheme.sans(size: 12.5, weight: FontWeight.w700)),
              const Spacer(),
              Text(sum(total), style: AppTheme.serif(size: 16, weight: FontWeight.w700)),
            ]),
          ),
        ]),
      ],
    );
  }

  Widget _ingRow(AppState app, Ingredient ing, {required bool first}) {
    final low = ing.low;
    final val = ing.stockValue;
    return InkWell(
      onTap: () => _entMenuSheet(app, ingredient: ing),
      child: Container(
        decoration: BoxDecoration(border: first ? null : const Border(top: BorderSide(color: AppColors.border))),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(ing.name, style: AppTheme.sans(size: 13.5, weight: FontWeight.w600))),
              if (low) const Padding(padding: EdgeInsets.only(left: 5), child: Text('⚠️', style: TextStyle(fontSize: 11))),
            ]),
            Text('${groupNum(ing.costPerUnit)} сум/${ing.unit}', style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${qty(ing.stock)} ${ing.unit}', style: AppTheme.sans(size: 13, weight: FontWeight.w700, color: low ? AppColors.danger : AppColors.text)),
            Text('${groupNum(val)} сум', style: AppTheme.sans(size: 11, color: AppColors.textTertiary)),
          ]),
          const SizedBox(width: 8),
          const Text('›', style: TextStyle(fontSize: 16, color: AppColors.textTertiary)),
        ]),
      ),
    );
  }

  // ── Категории ──
  Widget _categories(AppState app) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
      children: [
        _listCard([
          if (app.categories.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              child: Center(child: Text('Создайте первую категорию по ＋ сверху — например «Основные блюда»', textAlign: TextAlign.center, style: AppTheme.sans(size: 12.5, color: AppColors.textTertiary))),
            )
          else
            for (int i = 0; i < app.categories.length; i++) _catRow(app, app.categories[i], first: i == 0),
        ]),
      ],
    );
  }

  Widget _catRow(AppState app, Category c, {required bool first}) {
    final cnt = app.products.where((p) => p.categoryId == c.id).length;
    return Container(
      decoration: BoxDecoration(border: first ? null : const Border(top: BorderSide(color: AppColors.border))),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 32, height: 32, alignment: Alignment.center, decoration: BoxDecoration(color: Color(c.color).withOpacity(0.16), borderRadius: BorderRadius.circular(9), border: Border.all(color: Color(c.color).withOpacity(0.55))), child: Text(_catEmoji(c.name), style: const TextStyle(fontSize: 16))),
          const SizedBox(width: 10),
          Expanded(child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 7, runSpacing: 2, children: [
            Text(c.name, style: AppTheme.sans(size: 13.5, weight: FontWeight.w600, color: c.hidden ? AppColors.textTertiary : AppColors.text)),
            if (c.hidden)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: AppColors.bgSecondary, borderRadius: BorderRadius.circular(999)),
                child: Text('скрыта · не на кассе', style: AppTheme.sans(size: 10, weight: FontWeight.w600, color: AppColors.textTertiary)),
              ),
          ])),
          Text('$cnt поз.', style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary)),
        ]),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 42),
          child: Row(children: [
            _catBtn('Ред.', () => _editCategory(app, c)),
            const SizedBox(width: 6),
            _catBtn(c.hidden ? 'Показать' : 'Скрыть', () { setState(() => c.hidden = !c.hidden); app.saveCategory(c); }),
            const SizedBox(width: 6),
            _catBtn('Удалить', () => _confirm('Удалить категорию?', '«${c.name}» будет удалена. Действие необратимо.', () {
              setState(() => app.removeCategory(c.id));
              showToast(context, 'Категория удалена', color: AppColors.danger, bg: AppColors.dangerSoft, icon: Icons.delete_outline);
            }), danger: true),
          ]),
        ),
      ]),
    );
  }

  Widget _catBtn(String label, VoidCallback onTap, {bool danger = false}) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: danger ? const Color(0xFFEBC7C2) : AppColors.borderStrong),
      ),
      child: Text(label, style: AppTheme.sans(size: 11.5, weight: FontWeight.w600, color: danger ? AppColors.danger : AppColors.text)),
    ),
  );

  // ── Цехи ──
  Widget _workshops(AppState app) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
      children: [
        _listCard([
          for (int i = 0; i < _shops.length; i++) _shopRow(app, _shops[i], first: i == 0),
        ]),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 6, 20, 0),
          child: Text('Бегунок печатается на принтере цеха при отправке заказа', textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary)),
        ),
      ],
    );
  }

  Widget _shopRow(AppState app, Map<String, dynamic> sh, {required bool first}) {
    return Container(
      decoration: BoxDecoration(border: first ? null : const Border(top: BorderSide(color: AppColors.border))),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(sh['name'] as String, style: AppTheme.sans(size: 14, weight: FontWeight.w600)),
          Text('Печатать бегунки на цех', style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary)),
        ])),
        _Toggle(value: sh['runner'] as bool, onChanged: (v) { setState(() => sh['runner'] = v); app.notify(); }),
      ]),
    );
  }

  // ── Umumiy: konteyner-karta ──
  Widget _listCard(List<Widget> children) => Container(
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.card), border: Border.all(color: AppColors.border), boxShadow: kSoftShadow),
    clipBehavior: Clip.antiAlias,
    child: Column(children: children),
  );

  Widget _emojiTile(String e) => Container(width: 38, height: 38, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.bgSecondary, borderRadius: BorderRadius.circular(11)), child: Text(e, style: const TextStyle(fontSize: 19)));

  // ── Kategoriya filtri sheet ──
  void _pickCategoryFilter(AppState app) {
    showAppSheet(context, title: 'Категория', builder: (ctx) {
      final rows = <Widget>[
        _pickRow('Все категории', _catFilter == null, () { setState(() => _catFilter = null); Navigator.pop(ctx); }),
        for (final c in app.categories)
          _pickRow(c.name, _catFilter == c.id, () { setState(() => _catFilter = c.id); Navigator.pop(ctx); }),
      ];
      return Column(children: rows);
    });
  }

  Widget _pickRow(String label, bool selected, VoidCallback onTap) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(children: [
        Expanded(child: Text(label, style: AppTheme.sans(size: 15, weight: selected ? FontWeight.w600 : FontWeight.w400))),
        if (selected) const Icon(Icons.check, size: 18, color: AppColors.accent),
      ]),
    ),
  );

  // ── «⋯» tovar/tex-karta/ingredient uchun harakatlar sheet ──
  void _entMenuSheet(AppState app, {Product? product, Ingredient? ingredient}) {
    final title = product != null ? '${product.photo} ${product.name}' : (ingredient?.name ?? '');
    showAppSheet(context, title: title, builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _sheetAction('Редактировать', Icons.edit_outlined, () {
        Navigator.pop(ctx);
        if (product != null) {
          showProductForm(context, app, existing: product, techCard: product.type == 'dish');
        } else {
          _addIngredient(app, existing: ingredient);
        }
      }),
      if (product != null)
        _sheetAction('Дублировать', Icons.copy_outlined, () {
          Navigator.pop(ctx);
          app.addProduct(Product(id: app.newProductId(), name: '${product.name} (копия)', categoryId: product.categoryId, type: product.type, workshop: product.workshop, price: product.price, cost: product.cost, photo: product.photo, imagePath: product.imagePath, byWeight: product.byWeight, noDiscount: product.noDiscount, modifications: product.modifications, recipe: product.recipe));
          showToast(context, 'Дубликат создан');
        }),
      _sheetAction('Удалить', Icons.delete_outline, () {
        Navigator.pop(ctx);
        _confirm(
          product != null ? 'Удалить товар?' : 'Удалить ингредиент?',
          '«${product?.name ?? ingredient?.name}» будет удалён. Действие необратимо.',
          () {
            setState(() {
              if (product != null) {
                app.removeProduct(product.id);
              } else if (ingredient != null) {
                app.removeIngredient(ingredient.id);
              }
            });
            showToast(context, product != null ? 'Товар удалён' : 'Ингредиент удалён', color: AppColors.danger, bg: AppColors.dangerSoft, icon: Icons.delete_outline);
          },
        );
      }, danger: true),
      const SizedBox(height: 8),
    ]));
  }

  Widget _sheetAction(String label, IconData icon, VoidCallback onTap, {bool danger = false}) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(children: [
        Icon(icon, size: 20, color: danger ? AppColors.danger : AppColors.textSecondary),
        const SizedBox(width: 12),
        Text(label, style: AppTheme.sans(size: 15, weight: FontWeight.w500, color: danger ? AppColors.danger : AppColors.text)),
      ]),
    ),
  );

  // ── Ингредиент formasi ──
  void _addIngredient(AppState app, {Ingredient? existing}) {
    final name = TextEditingController(text: existing?.name ?? '');
    final stock = TextEditingController(text: existing != null ? qty(existing.stock) : '');
    final price = TextEditingController(text: existing != null ? existing.costPerUnit.toString() : '');
    final limitCtrl = TextEditingController(text: existing != null ? qty(existing.limit) : '');
    String unit = existing?.unit ?? 'кг';
    String wh = app.storageNames.first;
    showAppSheet(context, title: existing == null ? 'Новый ингредиент' : 'Ингредиент', builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setS) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LabeledField(label: 'Название *', controller: name, hint: 'Например: Нут'),
        const SizedBox(height: 12),
        Text('Единица измерения', style: AppTheme.sans(size: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        Row(children: ['шт', 'кг', 'л'].map((u) => Padding(padding: const EdgeInsets.only(right: 6), child: _pill(u, unit == u, () => setS(() => unit = u)))).toList()),
        if (existing == null) ...[
          const SizedBox(height: 14),
          Text('Складской учёт', style: AppTheme.sans(size: 14, weight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text('Укажите остаток — при сохранении автоматически создастся поставка', style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: LabeledField(label: 'Количество', controller: stock, hint: '0', keyboardType: TextInputType.number)),
            const SizedBox(width: 8),
            Expanded(child: LabeledField(label: 'Цена за ед., сум', controller: price, hint: '0', keyboardType: TextInputType.number)),
          ]),
          const SizedBox(height: 10),
          LabeledField(label: 'Лимит — мин. остаток для ⚠️ предупреждения', controller: limitCtrl, hint: 'Например: 2', keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          _dropdown('Склад', wh, app.storageNames, (v) => setS(() => wh = v)),
        ] else ...[
          const SizedBox(height: 12),
          LabeledField(label: 'Цена за ед., сум', controller: price, keyboardType: TextInputType.number),
          const SizedBox(height: 10),
          LabeledField(label: 'Лимит — мин. остаток', controller: limitCtrl, keyboardType: TextInputType.number),
        ],
        const SizedBox(height: 20),
        PrimaryButton('Сохранить', onPressed: () {
          if (name.text.trim().isEmpty) { showToast(ctx, 'Введите название', color: AppColors.danger, bg: AppColors.dangerSoft, icon: Icons.error_outline); return; }
          if (existing != null) {
            existing.name = name.text.trim();
            existing.unit = unit;
            existing.costPerUnit = int.tryParse(price.text) ?? existing.costPerUnit;
            existing.limit = double.tryParse(limitCtrl.text.replaceAll(',', '.')) ?? existing.limit;
            app.saveIngredient(existing);
            Navigator.pop(ctx);
            showToast(context, 'Ингредиент сохранён');
            return;
          }
          final q = double.tryParse(stock.text.replaceAll(',', '.')) ?? 0;
          final unitPrice = int.tryParse(price.text) ?? 0;
          final lim = double.tryParse(limitCtrl.text.replaceAll(',', '.')) ?? 0;
          app.addIngredient(Ingredient(id: app.newIngredientId(), name: name.text.trim(), unit: unit, stock: q, costPerUnit: unitPrice, limit: lim));
          int? supplyNo;
          if (q > 0) {
            supplyNo = app.newSupplyId();
            final d = DateTime.now();
            app.addSupplyRaw(Supply(
              id: supplyNo,
              date: '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}',
              supplier: 'Начальные остатки',
              storage: wh,
              items: '${name.text.trim()} ×${qty(q)}',
              sum: (q * unitPrice).round(),
              debt: 0,
              status: 'Проведена',
            ));
          }
          Navigator.pop(ctx);
          showToast(context, supplyNo != null ? 'Ингредиент сохранён — создана поставка №$supplyNo' : 'Ингредиент сохранён');
        }),
        const SizedBox(height: 8),
      ]));
    });
  }

  // ── Категория formasi ──
  void _editCategory(AppState app, Category? existing) {
    final name = TextEditingController(text: existing?.name ?? '');
    int color = existing?.color ?? _kCatColors.first;
    showAppSheet(context, title: existing == null ? 'Новая категория' : 'Категория', builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LabeledField(label: 'Название *', controller: name),
      const SizedBox(height: 14),
      Text('Цвет категории', style: AppTheme.sans(size: 13, color: AppColors.textSecondary)),
      const SizedBox(height: 8),
      Wrap(spacing: 10, runSpacing: 10, children: _kCatColors.map((c) {
        final active = c == color;
        return GestureDetector(
          onTap: () => setS(() => color = c),
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: Color(c),
              shape: BoxShape.circle,
              border: Border.all(color: active ? AppColors.text : Colors.transparent, width: 2.5),
            ),
            child: active ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
          ),
        );
      }).toList()),
      const SizedBox(height: 20),
      PrimaryButton('Сохранить', onPressed: () {
        if (name.text.trim().isEmpty) { showToast(ctx, 'Введите название', color: AppColors.danger, bg: AppColors.dangerSoft, icon: Icons.error_outline); return; }
        if (existing != null) {
          existing.name = name.text.trim();
          existing.color = color;
          app.saveCategory(existing);
        } else {
          app.addCategory(Category(id: app.newCategoryId(), name: name.text.trim(), color: color));
        }
        Navigator.pop(ctx);
        showToast(context, 'Категория сохранена');
      }),
      const SizedBox(height: 8),
    ])));
  }

  // ── Цех formasi ──
  void _addWorkshop(AppState app) {
    final name = TextEditingController();
    showAppSheet(context, title: 'Новый цех', builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LabeledField(label: 'Название *', controller: name),
      const SizedBox(height: 20),
      PrimaryButton('Сохранить', onPressed: () {
        if (name.text.trim().isEmpty) { showToast(ctx, 'Введите название', color: AppColors.danger, bg: AppColors.dangerSoft, icon: Icons.error_outline); return; }
        setState(() => _shops.add({'name': name.text.trim(), 'runner': true}));
        Navigator.pop(ctx);
        showToast(context, 'Цех сохранён');
      }),
      const SizedBox(height: 8),
    ]));
  }

  Widget _pill(String label, bool active, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: active ? AppColors.posDark : AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: active ? AppColors.posDark : AppColors.border),
      ),
      child: Text(label, style: AppTheme.sans(size: 12.5, weight: FontWeight.w600, color: active ? Colors.white : AppColors.textSecondary)),
    ),
  );

  Widget _dropdown(String label, String value, List<String> options, ValueChanged<String> onChanged) {
    final safe = options.contains(value) ? value : options.first;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppTheme.sans(size: 13, color: AppColors.textSecondary)),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.input), border: Border.all(color: AppColors.borderStrong)),
        child: DropdownButtonHideUnderline(child: DropdownButton<String>(
          value: safe, isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
          style: AppTheme.sans(size: 15, color: AppColors.text),
          items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        )),
      ),
    ]);
  }

  void _confirm(String title, String desc, VoidCallback onYes) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(title, style: AppTheme.sans(size: 17, weight: FontWeight.w600)),
      content: Text(desc, style: AppTheme.sans(size: 14, color: AppColors.textSecondary)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Отмена', style: AppTheme.sans(color: AppColors.textSecondary))),
        TextButton(onPressed: () { Navigator.pop(ctx); onYes(); }, child: Text('Удалить', style: AppTheme.sans(weight: FontWeight.w600, color: AppColors.danger))),
      ],
    ));
  }

  void _openNotifications(AppState app) {
    final lows = app.ingredients.where((i) => i.low).toList();
    showAppSheet(context, title: 'Уведомления', builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (lows.isNotEmpty)
        _notifRow('⚠️', AppColors.warningSoft, '${lows.first.name} ниже лимита', 'Осталось ${qty(lows.first.stock)} ${lows.first.unit} при лимите ${qty(lows.first.limit)} ${lows.first.unit}', '12 мин')
      else
        Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Center(child: Text('Новых уведомлений нет', style: AppTheme.sans(size: 13.5, color: AppColors.textSecondary)))),
      const SizedBox(height: 8),
    ]));
  }

  Widget _notifRow(String emoji, Color bg, String title, String desc, String time) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 36, height: 36, alignment: Alignment.center, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)), child: Text(emoji, style: const TextStyle(fontSize: 17))),
      const SizedBox(width: 11),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: AppTheme.sans(size: 13.5, weight: FontWeight.w600)),
        Text(desc, style: AppTheme.sans(size: 12, color: AppColors.textSecondary, height: 1.3)),
      ])),
      const SizedBox(width: 8),
      Text(time, style: AppTheme.sans(size: 11, color: AppColors.textTertiary)),
    ]),
  );
}

// ── Tex-karta retseptlari (prototip MENU.recipe + ings) ──
// b = брутто (г), n = нетто (г). Ингредиент costPerUnit — сум/кг(л).
const Map<int, List<Map<String, dynamic>>> _kRecipes = {
  1: [ // Плов чайханский
    {'name': 'Рис девзира', 'b': 120, 'n': 110, 'cost': 28000},
    {'name': 'Говядина', 'b': 100, 'n': 80, 'cost': 90000},
    {'name': 'Морковь', 'b': 100, 'n': 90, 'cost': 5000},
    {'name': 'Лук репчатый', 'b': 40, 'n': 35, 'cost': 4000},
    {'name': 'Масло хлопковое', 'b': 60, 'n': 60, 'cost': 22000},
    {'name': 'Специи для плова', 'b': 6, 'n': 6, 'cost': 45000},
  ],
  2: [ // Лагман уйгурский
    {'name': 'Мука', 'b': 100, 'n': 100, 'cost': 7000},
    {'name': 'Говядина', 'b': 90, 'n': 70, 'cost': 90000},
    {'name': 'Помидоры', 'b': 60, 'n': 55, 'cost': 12000},
    {'name': 'Лук репчатый', 'b': 30, 'n': 25, 'cost': 4000},
    {'name': 'Масло хлопковое', 'b': 40, 'n': 40, 'cost': 22000},
  ],
  3: [ // Шурпа
    {'name': 'Баранина', 'b': 100, 'n': 80, 'cost': 95000},
    {'name': 'Картофель', 'b': 120, 'n': 110, 'cost': 5500},
    {'name': 'Морковь', 'b': 60, 'n': 55, 'cost': 5000},
    {'name': 'Лук репчатый', 'b': 40, 'n': 35, 'cost': 4000},
    {'name': 'Помидоры', 'b': 40, 'n': 38, 'cost': 12000},
  ],
  4: [ // Манты
    {'name': 'Мука', 'b': 80, 'n': 80, 'cost': 7000},
    {'name': 'Говядина', 'b': 90, 'n': 75, 'cost': 90000},
    {'name': 'Лук репчатый', 'b': 60, 'n': 50, 'cost': 4000},
    {'name': 'Масло хлопковое', 'b': 10, 'n': 10, 'cost': 22000},
  ],
  5: [ // Шашлык из говядины
    {'name': 'Говядина', 'b': 180, 'n': 150, 'cost': 90000},
    {'name': 'Лук репчатый', 'b': 30, 'n': 25, 'cost': 4000},
  ],
  6: [ // Шашлык куриный
    {'name': 'Курица', 'b': 200, 'n': 170, 'cost': 38000},
    {'name': 'Лук репчатый', 'b': 30, 'n': 25, 'cost': 4000},
  ],
  7: [ // Салат Ачичук
    {'name': 'Помидоры', 'b': 120, 'n': 110, 'cost': 12000},
    {'name': 'Огурцы', 'b': 80, 'n': 75, 'cost': 10000},
    {'name': 'Лук репчатый', 'b': 30, 'n': 28, 'cost': 4000},
  ],
  8: [ // Салат «Ташкент»
    {'name': 'Говядина', 'b': 60, 'n': 50, 'cost': 90000},
    {'name': 'Картофель', 'b': 80, 'n': 75, 'cost': 5500},
    {'name': 'Огурцы', 'b': 40, 'n': 38, 'cost': 10000},
    {'name': 'Лук репчатый', 'b': 20, 'n': 18, 'cost': 4000},
  ],
  10: [ // Самса
    {'name': 'Мука', 'b': 70, 'n': 70, 'cost': 7000},
    {'name': 'Баранина', 'b': 40, 'n': 35, 'cost': 95000},
    {'name': 'Лук репчатый', 'b': 40, 'n': 35, 'cost': 4000},
    {'name': 'Масло хлопковое', 'b': 15, 'n': 15, 'cost': 22000},
  ],
  11: [ // Чай чёрный
    {'name': 'Чай листовой', 'b': 4, 'n': 4, 'cost': 80000},
  ],
  12: [ // Чай зелёный
    {'name': 'Чай листовой', 'b': 4, 'n': 4, 'cost': 80000},
  ],
  13: [ // Кофе американо
    {'name': 'Кофе зерновой', 'b': 18, 'n': 18, 'cost': 160000},
  ],
};

/// Tex-karta tarkibi — endi mahsulotning REAL retseptidan (product.recipe) o'qiladi.
/// Ilgari id bo'yicha hardcode `_kRecipes` ishlatilar edi (id-collision bug) — bekor qilindi.
List<Map<String, dynamic>> _recipeOf(AppState app, Product p) {
  final r = p.recipe;
  if (r == null || r.isEmpty) return const [];
  return r.map((ri) {
    final ing = app.ingredients.where((i) => i.id == ri.ingredientId).toList();
    final name = ing.isEmpty ? 'Ингредиент #${ri.ingredientId}' : ing.first.name;
    final rowCost = ing.isEmpty ? 0 : (ri.brutto / 1000 * ing.first.costPerUnit).round();
    return {'name': name, 'brutto': ri.brutto, 'net': ri.netto, 'cost': rowCost};
  }).toList();
}

/// Kategoriya uchun rang palitrasi.
const List<int> _kCatColors = [0xFFD97757, 0xFF6A8D73, 0xFF4E7CA1, 0xFFB4879B, 0xFFC9A227, 0xFF9C7BB0, 0xFFCC6B57, 0xFF5C8A8A];

const Map<String, String> _kCatEmoji = {
  'Основные блюда': '🍛',
  'Шашлыки': '🍢',
  'Салаты': '🥗',
  'Выпечка': '🫓',
  'Горячие напитки': '🫖',
  'Холодные напитки': '🥤',
};

String _catEmoji(String name) => _kCatEmoji[name] ?? '🍽️';

// ── App-bar (menu): sarlavha chapda + qo'ng'iroq o'ngda ──
class _MenuAppBar extends StatelessWidget {
  final String title;
  final VoidCallback onBell;
  const _MenuAppBar({required this.title, required this.onBell});
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: Padding(
      padding: const EdgeInsets.only(left: 20, right: 16),
      child: Row(children: [
        Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(size: 17, weight: FontWeight.w600, letterSpacing: -0.2))),
        _MenuBell(onTap: onBell),
      ]),
    ),
  );
}

class _MenuBell extends StatelessWidget {
  final VoidCallback onTap;
  const _MenuBell({required this.onTap});
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
              decoration: BoxDecoration(
                color: active ? AppColors.posDark : AppColors.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: active ? AppColors.posDark : AppColors.border),
              ),
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

class _Toggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _Toggle({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => onChanged(!value),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 40, height: 24,
      decoration: BoxDecoration(color: value ? AppColors.success : AppColors.borderStrong, borderRadius: BorderRadius.circular(999)),
      child: Stack(children: [
        AnimatedPositioned(
          duration: const Duration(milliseconds: 180),
          top: 2, left: value ? 18 : 2,
          child: Container(width: 20, height: 20, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x40141413), blurRadius: 3, offset: Offset(0, 1))])),
        ),
      ]),
    ),
  );
}

class _NothingFound extends StatelessWidget {
  const _NothingFound();
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    const Text('🔍', style: TextStyle(fontSize: 30)),
    const SizedBox(height: 8),
    Text('Ничего не найдено', style: AppTheme.sans(size: 13.5, weight: FontWeight.w600)),
    const SizedBox(height: 3),
    Text('Измените запрос или фильтр категории', textAlign: TextAlign.center, style: AppTheme.sans(size: 12, color: AppColors.textSecondary)),
  ]);
}
