import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme.dart';
import '../../models.dart';
import '../../state/app_state.dart';
import '../../utils/format.dart';
import '../../widgets/ui.dart';

/// Товар / Тех. карта qo'shish-tahrirlash (bottom sheet).
/// techCard=false → «Новый товар» (себест/наценка/итого + модификации),
/// techCard=true  → «Новая тех. карта» (состав: ингредиенты).
void showProductForm(BuildContext context, AppState app, {Product? existing, bool techCard = false}) {
  if (app.categories.isEmpty) {
    showToast(context, 'Сначала создайте категорию — вкладка «Категории» в Меню', color: AppColors.warning, bg: AppColors.warningSoft, icon: Icons.category_outlined);
    return;
  }
  if (techCard && app.ingredients.isEmpty) {
    showToast(context, 'Для тех. карты нужны ингредиенты — добавьте во вкладке «Ингредиенты»', color: AppColors.warning, bg: AppColors.warningSoft, icon: Icons.egg_outlined);
    return;
  }
  if (techCard) {
    _showTechForm(context, app, existing: existing);
  } else {
    _showProductForm(context, app, existing: existing);
  }
}

const _kEmojis = ['🍛', '🍜', '🍲', '🥟', '🍢', '🍗', '🥗', '🫓', '🥧', '🫖', '☕', '🥤', '💧', '🍰', '🧃', '🍽️'];
const _kShops = ['Без цеха', 'Бар', 'Кухня'];

// ══════════════════ Товар ══════════════════
void _showProductForm(BuildContext context, AppState app, {Product? existing}) {
  final name = TextEditingController(text: existing?.name ?? '');
  final cost = TextEditingController(text: existing != null ? existing.cost.toString() : '');
  final markup = TextEditingController(text: existing != null ? existing.markup.toString() : '');
  final price = TextEditingController(text: existing != null ? existing.price.toString() : '');
  String emoji = existing?.photo ?? '🍽️';
  String? imagePath = existing?.imagePath;
  int categoryId = existing?.categoryId ?? app.categories.first.id;
  String workshop = existing?.workshop ?? 'Без цеха';
  bool weighted = existing?.byWeight ?? false;
  bool noDiscount = existing?.noDiscount ?? false;
  bool hasMods = (existing?.modifications?.isNotEmpty ?? false);
  final mods = <TextEditingController>[
    if (existing?.modifications != null) ...existing!.modifications!.map((m) => TextEditingController(text: m.name)),
  ];

  void recalcFromMarkup() {
    final c = int.tryParse(cost.text) ?? 0;
    final m = int.tryParse(markup.text) ?? 0;
    price.text = (c + c * m / 100).round().toString();
  }
  void recalcMarkup() {
    final c = int.tryParse(cost.text) ?? 0;
    final p = int.tryParse(price.text) ?? 0;
    markup.text = c == 0 ? '0' : (((p - c) / c) * 100).round().toString();
  }

  showAppSheet(context, title: existing == null ? 'Новый товар' : 'Товар', builder: (ctx) {
    return StatefulBuilder(builder: (ctx, setS) {
      final c = int.tryParse(cost.text) ?? 0;
      final p = int.tryParse(price.text) ?? 0;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label('Название *'),
        _input(name, hint: 'Например: Лимонад тархун'),
        const SizedBox(height: 11),
        _label('Категория'),
        _dropdown(app.categoryById(categoryId).name, app.categories.map((c) => c.name).toList(), (v) => setS(() => categoryId = app.categories.firstWhere((c) => c.name == v).id)),
        const SizedBox(height: 11),
        _label('Цех'),
        _chipRow(_kShops, workshop, (v) => setS(() => workshop = v)),
        const SizedBox(height: 11),
        _label('Обложка — фото или эмодзи'),
        _photoPicker(imagePath, emoji, () async { await _pickImage((path) => setS(() => imagePath = path)); }, () => setS(() => imagePath = null)),
        const SizedBox(height: 8),
        _emojiGrid(emoji, (e) => setS(() => emoji = e)),
        const SizedBox(height: 8),
        _checkRow('Весовой товар', '— количество с точностью 0,5', weighted, () => setS(() => weighted = !weighted)),
        const SizedBox(height: 4),
        _checkRow('Не участвует в скидках', '', noDiscount, () => setS(() => noDiscount = !noDiscount)),
        const SizedBox(height: 14),
        // Цена / модификации-blok
        _radioRow('Без модификаций', !hasMods, () => setS(() => hasMods = false)),
        if (!hasMods) ...[
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _miniField('Себестоимость', cost, onChanged: () => setS(recalcFromMarkup))),
            const SizedBox(width: 8),
            Expanded(child: _miniField('Наценка %', markup, onChanged: () => setS(recalcFromMarkup))),
            const SizedBox(width: 8),
            Expanded(child: _miniField('Итого, сум', price, accent: true, onChanged: () => setS(recalcMarkup))),
          ]),
          const SizedBox(height: 7),
          Text(c > 0 && p > 0 ? 'Прибыль с единицы: ${sum(p - c)}' : 'Заполните себестоимость и наценку — итог посчитается сам', style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary)),
        ],
        const SizedBox(height: 12),
        _radioRow('С модификациями', hasMods, () => setS(() { hasMods = true; if (mods.isEmpty) mods.add(TextEditingController()); })),
        if (hasMods) ...[
          const SizedBox(height: 10),
          for (int i = 0; i < mods.length; i++) Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(children: [
              Expanded(child: _input(mods[i], hint: 'Название модификации')),
              const SizedBox(width: 7),
              GestureDetector(onTap: () => setS(() => mods.removeAt(i)), child: Container(width: 34, height: 34, alignment: Alignment.center, decoration: const BoxDecoration(color: AppColors.bgSecondary, shape: BoxShape.circle), child: const Text('✕', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)))),
            ]),
          ),
          GestureDetector(onTap: () => setS(() => mods.add(TextEditingController())), child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisSize: MainAxisSize.min, children: [const Text('＋', style: TextStyle(fontSize: 15, color: AppColors.accentHover)), const SizedBox(width: 6), Text('Добавить ещё', style: AppTheme.sans(size: 12.5, weight: FontWeight.w600, color: AppColors.accentHover))]))),
          const SizedBox(height: 5),
          Text('Цена и себестоимость у всех модификаций — как у товара', style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary)),
        ],
        const SizedBox(height: 20),
        PrimaryButton('Сохранить', onPressed: () => _saveProduct(context, ctx, app, existing, name, cost, price, emoji, categoryId, workshop, weighted, noDiscount, hasMods, mods, again: false, imagePath: imagePath)),
        const SizedBox(height: 8),
        SecondaryButton('Сохранить и создать ещё', expand: true, onPressed: () => _saveProduct(context, ctx, app, existing, name, cost, price, emoji, categoryId, workshop, weighted, noDiscount, hasMods, mods, again: true, imagePath: imagePath)),
        const SizedBox(height: 8),
      ]);
    });
  });
}

void _saveProduct(BuildContext outer, BuildContext ctx, AppState app, Product? existing, TextEditingController name, TextEditingController cost, TextEditingController price, String emoji, int categoryId, String workshop, bool weighted, bool noDiscount, bool hasMods, List<TextEditingController> mods, {required bool again, String? imagePath}) {
  if (name.text.trim().isEmpty) { showToast(ctx, 'Введите название', color: AppColors.danger, bg: AppColors.dangerSoft, icon: Icons.error_outline); return; }
  final modList = hasMods ? mods.where((m) => m.text.trim().isNotEmpty).map((m) => Modification(m.text.trim())).toList() : null;
  final ws = workshop == 'Без цеха' ? null : workshop;
  if (existing != null) {
    existing.name = name.text.trim();
    existing.categoryId = categoryId;
    existing.workshop = ws;
    existing.photo = emoji;
    existing.imagePath = imagePath;
    existing.cost = int.tryParse(cost.text) ?? existing.cost;
    existing.price = int.tryParse(price.text) ?? existing.price;
    existing.byWeight = weighted;
    existing.noDiscount = noDiscount;
    existing.modifications = modList;
    app.saveProduct(existing); // Firestore'ga ham yoziladi
  } else {
    app.addProduct(Product(id: app.newProductId(), name: name.text.trim(), categoryId: categoryId, type: 'product', workshop: ws, price: int.tryParse(price.text) ?? 0, cost: int.tryParse(cost.text) ?? 0, photo: emoji, imagePath: imagePath, byWeight: weighted, noDiscount: noDiscount, modifications: modList));
  }
  if (again && existing == null) {
    name.clear(); cost.clear(); price.clear();
    showToast(outer, 'Товар сохранён');
  } else {
    Navigator.pop(ctx);
    showToast(outer, 'Товар сохранён');
  }
}

// ══════════════════ Тех. карта ══════════════════
class _RecipeRow {
  String ingredient;
  final TextEditingController brutto;
  final TextEditingController netto;
  _RecipeRow(this.ingredient, {String b = '', String n = ''})
      : brutto = TextEditingController(text: b),
        netto = TextEditingController(text: n);
}

void _showTechForm(BuildContext context, AppState app, {Product? existing}) {
  final name = TextEditingController(text: existing?.name ?? '');
  final price = TextEditingController(text: existing != null ? existing.price.toString() : '');
  int categoryId = existing?.categoryId ?? app.categories.first.id;
  String workshop = existing?.workshop ?? 'Кухня';
  String? imagePath = existing?.imagePath;
  final ingNames = app.ingredients.map((i) => i.name).toList();
  // Mavjud tex.karta retseptidan qatorlarni tiklaymiz (avval yo'qolar edi).
  final rows = <_RecipeRow>[];
  if (existing?.recipe != null && existing!.recipe!.isNotEmpty) {
    for (final ri in existing.recipe!) {
      final ing = app.ingredients.where((i) => i.id == ri.ingredientId).toList();
      rows.add(_RecipeRow(ing.isEmpty ? ingNames.first : ing.first.name, b: _numStr(ri.brutto), n: _numStr(ri.netto)));
    }
  }
  if (rows.isEmpty) rows.add(_RecipeRow(ingNames.first));

  int rowCost(_RecipeRow r) {
    final b = double.tryParse(r.brutto.text.replaceAll(',', '.')) ?? 0;
    final ing = app.ingredients.firstWhere((i) => i.name == r.ingredient, orElse: () => app.ingredients.first);
    // O-2: 'шт' birlikda brutto = dona soni (÷1000 EMAS — sotuvdagi
    // consumeStockForSale bilan bir xil); g/ml da ÷1000 (кг/л narxiga).
    // Ilgari doim /1000 edi → donali ingredient (tuxum/non) tannarxi 1000× kam.
    return ((ing.unit == 'шт' ? b : b / 1000) * ing.costPerUnit).round();
  }

  showAppSheet(context, title: existing == null ? 'Новая тех. карта' : 'Тех. карта', builder: (ctx) {
    return StatefulBuilder(builder: (ctx, setS) {
      final totalCost = rows.fold<int>(0, (s, r) => s + rowCost(r));
      final out = rows.fold<double>(0, (s, r) => s + (double.tryParse(r.netto.text.replaceAll(',', '.')) ?? 0));
      final p = int.tryParse(price.text) ?? 0;
      final markup = totalCost > 0 && p > 0 ? ((p / totalCost - 1) * 100).round() : null;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label('Название *'),
        _input(name, hint: 'Например: Плов свадебный'),
        const SizedBox(height: 11),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label('Категория'),
            _dropdown(app.categoryById(categoryId).name, app.categories.map((c) => c.name).toList(), (v) => setS(() => categoryId = app.categories.firstWhere((c) => c.name == v).id)),
          ])),
          const SizedBox(width: 8),
          SizedBox(width: 118, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label('Цена, сум'),
            _input(price, keyboardType: TextInputType.number, accent: true, align: TextAlign.right, onChanged: () => setS(() {})),
          ])),
        ]),
        const SizedBox(height: 11),
        _label('Цех'),
        _chipRow(_kShops, workshop, (v) => setS(() => workshop = v)),
        const SizedBox(height: 11),
        _label('Обложка — фото или эмодзи 🍽️'),
        _photoPicker(imagePath, '🍽️', () async { await _pickImage((path) => setS(() => imagePath = path)); }, () => setS(() => imagePath = null)),
        const SizedBox(height: 10),
        Row(children: [
          RichText(text: TextSpan(children: [
            TextSpan(text: 'Себестоимость: ', style: AppTheme.sans(size: 12.5, color: AppColors.textTertiary)),
            TextSpan(text: groupNum(totalCost), style: AppTheme.sans(size: 12.5, weight: FontWeight.w700)),
          ])),
          const SizedBox(width: 14),
          RichText(text: TextSpan(children: [
            TextSpan(text: 'Наценка: ', style: AppTheme.sans(size: 12.5, color: AppColors.textTertiary)),
            TextSpan(text: markup == null ? '—' : '+$markup%', style: AppTheme.sans(size: 12.5, weight: FontWeight.w700, color: markup == null ? AppColors.text : (markup < 100 ? AppColors.warning : AppColors.success))),
          ])),
        ]),
        const SizedBox(height: 16),
        // Состав
        Container(
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.card), border: Border.all(color: AppColors.border), boxShadow: kSoftShadow),
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Состав', style: AppTheme.sans(size: 14, weight: FontWeight.w700)),
            const SizedBox(height: 9),
            Row(children: [
              Expanded(child: _colHead('Ингредиент', TextAlign.left)),
              SizedBox(width: 52, child: _colHead('Брутто', TextAlign.right)),
              SizedBox(width: 52, child: _colHead('Нетто', TextAlign.right)),
              SizedBox(width: 58, child: _colHead('Себест', TextAlign.right)),
              const SizedBox(width: 24),
            ]),
            const SizedBox(height: 5),
            for (int i = 0; i < rows.length; i++) Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Expanded(child: _smallDropdown(rows[i].ingredient, ingNames, (v) => setS(() => rows[i].ingredient = v))),
                const SizedBox(width: 6),
                SizedBox(width: 52, child: _cell(rows[i].brutto, () => setS(() {}))),
                const SizedBox(width: 6),
                SizedBox(width: 52, child: _cell(rows[i].netto, () => setS(() {}))),
                const SizedBox(width: 6),
                SizedBox(width: 58, child: Text(groupNum(rowCost(rows[i])), textAlign: TextAlign.right, style: AppTheme.sans(size: 12, weight: FontWeight.w600, color: AppColors.textSecondary))),
                SizedBox(width: 24, child: GestureDetector(onTap: () => setS(() => rows.removeAt(i)), child: Container(width: 24, height: 24, alignment: Alignment.center, decoration: const BoxDecoration(color: AppColors.bgSecondary, shape: BoxShape.circle), child: const Text('✕', style: TextStyle(fontSize: 9.5, color: AppColors.textSecondary))))),
              ]),
            ),
            GestureDetector(onTap: () => setS(() => rows.add(_RecipeRow(ingNames.first))), child: Padding(padding: const EdgeInsets.only(top: 6), child: Row(mainAxisSize: MainAxisSize.min, children: [const Text('＋', style: TextStyle(fontSize: 15, color: AppColors.accentHover)), const SizedBox(width: 6), Text('Добавить ингредиент', style: AppTheme.sans(size: 12.5, weight: FontWeight.w600, color: AppColors.accentHover))]))),
            const SizedBox(height: 8),
            const Divider(color: AppColors.borderStrong, height: 1),
            const SizedBox(height: 10),
            Row(children: [
              RichText(text: TextSpan(children: [
                TextSpan(text: 'Выход: ', style: AppTheme.sans(size: 12.5, color: AppColors.textTertiary)),
                TextSpan(text: '${qty(double.parse(out.toStringAsFixed(1)))} г', style: AppTheme.sans(size: 12.5, weight: FontWeight.w700)),
              ])),
              const Spacer(),
              RichText(text: TextSpan(children: [
                TextSpan(text: 'Итого: ', style: AppTheme.sans(size: 12.5, color: AppColors.textTertiary)),
                TextSpan(text: sum(totalCost), style: AppTheme.serif(size: 15, weight: FontWeight.w700)),
              ])),
            ]),
          ]),
        ),
        const SizedBox(height: 8),
        // Модификаторы (заглушка бизнес-тариф)
        Container(
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.card), border: Border.all(color: AppColors.border), boxShadow: kSoftShadow),
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Модификаторы', style: AppTheme.sans(size: 14, weight: FontWeight.w600, color: AppColors.textSecondary)),
              Text('Вариации блюда с собственным составом', style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary)),
            ])),
            StatusBadge.warning('Доступно в Business и Pro'),
          ]),
        ),
        const SizedBox(height: 16),
        PrimaryButton('Сохранить тех. карту', onPressed: () {
          if (name.text.trim().isEmpty) { showToast(ctx, 'Введите название', color: AppColors.danger, bg: AppColors.dangerSoft, icon: Icons.error_outline); return; }
          if (rows.where((r) => (double.tryParse(r.brutto.text.replaceAll(',', '.')) ?? 0) > 0).isEmpty) { showToast(ctx, 'Добавьте хотя бы один ингредиент', color: AppColors.warning, bg: AppColors.warningSoft, icon: Icons.warning_amber); return; }
          final ws = workshop == 'Без цеха' ? null : workshop;
          // Retseptni real ingredientlarga bog'lab saqlaymiz (sotuvda hisobdan chiqadi).
          final recipe = <RecipeItem>[];
          for (final r in rows) {
            final b = double.tryParse(r.brutto.text.replaceAll(',', '.')) ?? 0;
            if (b <= 0) continue;
            final n = double.tryParse(r.netto.text.replaceAll(',', '.')) ?? b;
            final ing = app.ingredients.where((i) => i.name == r.ingredient).toList();
            if (ing.isEmpty) continue;
            recipe.add(RecipeItem(ingredientId: ing.first.id, brutto: b, netto: n));
          }
          if (existing != null) {
            existing.name = name.text.trim();
            existing.categoryId = categoryId;
            existing.workshop = ws;
            existing.price = int.tryParse(price.text) ?? existing.price;
            existing.cost = totalCost;
            existing.recipe = recipe;
            existing.imagePath = imagePath;
            app.saveProduct(existing); // Firestore'ga ham yoziladi
          } else {
            app.addProduct(Product(id: app.newProductId(), name: name.text.trim(), categoryId: categoryId, type: 'dish', workshop: ws, price: int.tryParse(price.text) ?? 0, cost: totalCost, photo: '🍽️', imagePath: imagePath, recipe: recipe));
          }
          Navigator.pop(ctx);
          showToast(context, 'Тех. карта сохранена');
        }),
        const SizedBox(height: 8),
      ]);
    });
  });
}

// ── Umumiy kichik widgetlar ──
Widget _label(String t) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(t.toUpperCase(), style: AppTheme.sans(size: 11, weight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 0.8)));

Widget _input(TextEditingController c, {String? hint, TextInputType? keyboardType, bool accent = false, TextAlign align = TextAlign.left, VoidCallback? onChanged}) => SizedBox(
  height: 44,
  child: TextField(
    controller: c,
    keyboardType: keyboardType,
    textAlign: align,
    onChanged: onChanged == null ? null : (_) => onChanged(),
    style: AppTheme.sans(size: 13.5, weight: accent ? FontWeight.w700 : FontWeight.w400),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: AppTheme.sans(size: 13.5, color: AppColors.textTertiary),
      isDense: true,
      filled: true,
      fillColor: accent ? AppColors.accentSoft : AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.btn), borderSide: BorderSide(color: accent ? AppColors.accent : AppColors.borderStrong, width: accent ? 1.5 : 1)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.btn), borderSide: BorderSide(color: accent ? AppColors.accent : AppColors.borderStrong)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.btn), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
    ),
  ),
);

Widget _miniField(String label, TextEditingController c, {bool accent = false, VoidCallback? onChanged}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
  Text(label.toUpperCase(), style: AppTheme.sans(size: 10.5, weight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 0.6)),
  const SizedBox(height: 5),
  SizedBox(
    height: 42,
    child: TextField(
      controller: c,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.right,
      onChanged: onChanged == null ? null : (_) => onChanged(),
      style: AppTheme.sans(size: 13.5, weight: accent ? FontWeight.w700 : FontWeight.w400),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: accent ? AppColors.accentSoft : AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: accent ? AppColors.accent : AppColors.borderStrong, width: accent ? 1.5 : 1)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: accent ? AppColors.accent : AppColors.borderStrong)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
      ),
    ),
  ),
]);

Widget _cell(TextEditingController c, VoidCallback onChanged) => SizedBox(
  height: 38,
  child: TextField(
    controller: c,
    keyboardType: TextInputType.number,
    textAlign: TextAlign.right,
    onChanged: (_) => onChanged(),
    style: AppTheme.sans(size: 12.5),
    decoration: InputDecoration(
      hintText: 'г',
      hintStyle: AppTheme.sans(size: 12.5, color: AppColors.textTertiary),
      isDense: true,
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 7, vertical: 9),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: AppColors.borderStrong)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: AppColors.borderStrong)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
    ),
  ),
);

Widget _colHead(String t, TextAlign align) => Text(t.toUpperCase(), textAlign: align, style: AppTheme.sans(size: 10, weight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 0.4));

Widget _chipRow(List<String> opts, String selected, ValueChanged<String> onSelected) => Wrap(spacing: 6, runSpacing: 6, children: opts.map((o) {
  final active = o == selected;
  return GestureDetector(
    onTap: () => onSelected(o),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(color: active ? AppColors.posDark : AppColors.surface, borderRadius: BorderRadius.circular(999), border: Border.all(color: active ? AppColors.posDark : AppColors.border)),
      child: Text(o, style: AppTheme.sans(size: 12.5, weight: FontWeight.w600, color: active ? Colors.white : AppColors.textSecondary)),
    ),
  );
}).toList());

Widget _emojiGrid(String selected, ValueChanged<String> onTap) => GridView.count(
  crossAxisCount: 8,
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  mainAxisSpacing: 5,
  crossAxisSpacing: 5,
  children: _kEmojis.map((e) => GestureDetector(
    onTap: () => onTap(e),
    child: Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(color: selected == e ? AppColors.accentSoft : AppColors.bgSecondary, borderRadius: BorderRadius.circular(9), border: Border.all(color: selected == e ? AppColors.accent : Colors.transparent, width: 1.5)),
      child: Text(e, style: const TextStyle(fontSize: 19)),
    ),
  )).toList(),
);

Widget _checkRow(String title, String sub, bool value, VoidCallback onTap) => GestureDetector(
  onTap: onTap,
  child: Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      Container(width: 22, height: 22, alignment: Alignment.center, decoration: BoxDecoration(color: value ? AppColors.accent : AppColors.surface, borderRadius: BorderRadius.circular(6), border: Border.all(color: value ? AppColors.accent : AppColors.borderStrong, width: 1.5)), child: value ? const Text('✓', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700)) : null),
      const SizedBox(width: 10),
      Flexible(child: RichText(text: TextSpan(children: [
        TextSpan(text: title, style: AppTheme.sans(size: 13.5, weight: FontWeight.w500)),
        if (sub.isNotEmpty) TextSpan(text: ' $sub', style: AppTheme.sans(size: 13.5, color: AppColors.textTertiary)),
      ]))),
    ]),
  ),
);

Widget _radioRow(String title, bool selected, VoidCallback onTap) => GestureDetector(
  onTap: onTap,
  child: Row(children: [
    Container(width: 22, height: 22, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: selected ? AppColors.accent : AppColors.borderStrong, width: 1.5)), child: Container(width: 11, height: 11, decoration: BoxDecoration(color: selected ? AppColors.accent : Colors.transparent, shape: BoxShape.circle))),
    const SizedBox(width: 10),
    Text(title, style: AppTheme.sans(size: 13.5, weight: FontWeight.w600)),
  ]),
);

Widget _dropdown(String value, List<String> options, ValueChanged<String> onChanged) {
  final safe = options.contains(value) ? value : options.first;
  return Container(
    height: 44,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.btn), border: Border.all(color: AppColors.borderStrong)),
    child: DropdownButtonHideUnderline(child: DropdownButton<String>(
      value: safe, isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
      style: AppTheme.sans(size: 13.5, color: AppColors.text),
      items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
      onChanged: (v) { if (v != null) onChanged(v); },
    )),
  );
}

Widget _smallDropdown(String value, List<String> options, ValueChanged<String> onChanged) {
  final safe = options.contains(value) ? value : options.first;
  return Container(
    height: 38,
    padding: const EdgeInsets.symmetric(horizontal: 6),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(9), border: Border.all(color: AppColors.borderStrong)),
    child: DropdownButtonHideUnderline(child: DropdownButton<String>(
      value: safe, isExpanded: true, isDense: true,
      icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textSecondary),
      style: AppTheme.sans(size: 12, color: AppColors.text),
      items: options.map((o) => DropdownMenuItem(value: o, child: Text(o, maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: (v) { if (v != null) onChanged(v); },
    )),
  );
}

// ── Rasm yuklash (galereya) ──
Future<void> _pickImage(void Function(String path) onPicked) async {
  try {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 900);
    if (x != null) onPicked(x.path);
  } catch (_) {/* ruxsat berilmadi yoki bekor qilindi */}
}

Widget _photoPicker(String? imagePath, String emoji, VoidCallback onPick, VoidCallback onClear) {
  final has = imagePath != null && imagePath.isNotEmpty;
  return Row(children: [
    ProductThumb(imagePath: imagePath, emoji: emoji, size: 58, radius: 12),
    const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      GestureDetector(
        onTap: onPick,
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.btn), border: Border.all(color: AppColors.borderStrong)),
          child: Text(has ? '📷 Заменить фото' : '📷 Загрузить фото', style: AppTheme.sans(size: 13, weight: FontWeight.w600)),
        ),
      ),
      if (has) ...[
        const SizedBox(height: 5),
        GestureDetector(onTap: onClear, child: Text('Удалить фото', style: AppTheme.sans(size: 12, weight: FontWeight.w600, color: AppColors.danger))),
      ],
    ])),
  ]);
}

String _numStr(double d) => d == d.roundToDouble() ? d.toInt().toString() : d.toString();
