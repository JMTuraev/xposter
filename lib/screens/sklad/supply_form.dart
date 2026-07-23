import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../models.dart';
import '../../state/app_state.dart';
import '../../utils/format.dart';
import '../../widgets/ui.dart';

class _Pos {
  Ingredient ing;
  final TextEditingController qty = TextEditingController();
  final TextEditingController price = TextEditingController();
  _Pos(this.ing);
  int get sumVal {
    final q = double.tryParse(qty.text.replaceAll(',', '.')) ?? 0;
    final p = int.tryParse(price.text) ?? 0;
    return (q * p).round();
  }
}

class _Pay {
  String acc;
  final TextEditingController sum = TextEditingController();
  _Pay(this.acc);
  int get val => int.tryParse(sum.text) ?? 0;
}

/// Поставка (Новая поставка) — saqlash qoldiqlarni oshiradi.
/// Prototip: Дата+Склад, Поставщик(+), Позиции(Продукт/Кол-во/Цена/Сумма),
/// Оплата (Долг/Оплачена, счета), pastda «Итого» + «Сохранить».
void showSupplyForm(BuildContext context, AppState app) {
  if (app.ingredients.isEmpty) {
    showToast(context, 'Сначала добавьте ингредиенты: Остатки → ＋ → Ингредиент', color: AppColors.warning, bg: AppColors.warningSoft, icon: Icons.egg_outlined);
    return;
  }
  // `storageNames.first` bo'sh ro'yxatda StateError bilan qulardi.
  if (app.storageNames.isEmpty) {
    showToast(context, 'Сначала добавьте склад', color: AppColors.warning, bg: AppColors.warningSoft, icon: Icons.warehouse_outlined);
    return;
  }
  final dateCtrl = TextEditingController(text: _today());
  String supplier = app.suppliers.isNotEmpty ? app.suppliers.first.name : 'Без поставщика';
  String wh = app.storageNames.first;
  final positions = <_Pos>[_Pos(app.ingredients.first)];
  final pays = <_Pay>[];
  final accounts = app.accounts.map((a) => a.name).toList();

  showAppSheet(context, title: 'Новая поставка', builder: (ctx) {
    return StatefulBuilder(builder: (ctx, setS) {
      final total = positions.fold<int>(0, (s, p) => s + p.sumVal);
      final paid = pays.fold<int>(0, (s, p) => s + p.val);
      final debt = total - paid;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Дата + Склад
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_sub('Дата'), _input(dateCtrl)])),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_sub('Склад'), _dropdown(wh, app.storageNames, (v) => setS(() => wh = v))])),
        ]),
        const SizedBox(height: 11),
        _sub('Поставщик'),
        Row(children: [
          Expanded(child: _dropdown(supplier, app.suppliers.isNotEmpty ? app.suppliers.map((s) => s.name).toList() : const ['Без поставщика'], (v) => setS(() => supplier = v))),
          const SizedBox(width: 7),
          GestureDetector(onTap: () => _newSupplier(context, app, (name) => setS(() => supplier = name)), child: Container(width: 42, height: 42, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.borderStrong)), child: const Text('＋', style: TextStyle(fontSize: 17, color: AppColors.accentHover)))),
        ]),
        const SizedBox(height: 16),
        // Позиции
        _sectionCard(children: [
          Text('Позиции', style: AppTheme.sans(size: 14, weight: FontWeight.w700)),
          const SizedBox(height: 9),
          Row(children: [
            Expanded(child: _colHead('Продукт', TextAlign.left)),
            SizedBox(width: 46, child: _colHead('Кол-во', TextAlign.right)),
            SizedBox(width: 62, child: _colHead('Цена', TextAlign.right)),
            SizedBox(width: 58, child: _colHead('Сумма', TextAlign.right)),
            const SizedBox(width: 24),
          ]),
          const SizedBox(height: 5),
          for (int i = 0; i < positions.length; i++) Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Expanded(child: _smallDropdown('${positions[i].ing.name} (${positions[i].ing.unit})', app.ingredients.map((e) => '${e.name} (${e.unit})').toList(), (v) => setS(() => positions[i].ing = app.ingredients.firstWhere((e) => '${e.name} (${e.unit})' == v)))),
              const SizedBox(width: 6),
              SizedBox(width: 46, child: _cell(positions[i].qty, () => setS(() {}))),
              const SizedBox(width: 6),
              SizedBox(width: 62, child: _cell(positions[i].price, () => setS(() {}))),
              const SizedBox(width: 6),
              SizedBox(width: 58, child: Text(groupNum(positions[i].sumVal), textAlign: TextAlign.right, style: AppTheme.sans(size: 12, weight: FontWeight.w600, color: AppColors.textSecondary))),
              SizedBox(width: 24, child: GestureDetector(onTap: () => setS(() { if (positions.length > 1) positions.removeAt(i); }), child: Container(width: 24, height: 24, alignment: Alignment.center, decoration: const BoxDecoration(color: AppColors.bgSecondary, shape: BoxShape.circle), child: const Text('✕', style: TextStyle(fontSize: 9.5, color: AppColors.textSecondary))))),
            ]),
          ),
          GestureDetector(onTap: () => setS(() => positions.add(_Pos(app.ingredients.first))), child: Padding(padding: const EdgeInsets.only(top: 6), child: Row(mainAxisSize: MainAxisSize.min, children: [const Text('＋', style: TextStyle(fontSize: 15, color: AppColors.accentHover)), const SizedBox(width: 6), Text('Добавить позицию', style: AppTheme.sans(size: 12.5, weight: FontWeight.w600, color: AppColors.accentHover))]))),
        ]),
        const SizedBox(height: 8),
        // Оплата
        _sectionCard(children: [
          Row(children: [
            Text('Оплата', style: AppTheme.sans(size: 14, weight: FontWeight.w700)),
            const SizedBox(width: 8),
            if (total > 0 && paid >= total) StatusBadge.success('Оплачена')
            else if (debt > 0 && total > 0) StatusBadge.danger('Долг ${groupNum(debt)}'),
          ]),
          if (pays.isEmpty) ...[
            const SizedBox(height: 7),
            Text('Без платежа поставка сохранится как долг поставщику', style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary)),
          ],
          const SizedBox(height: 9),
          for (int i = 0; i < pays.length; i++) Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Expanded(child: _smallDropdown(pays[i].acc, accounts, (v) => setS(() => pays[i].acc = v))),
              const SizedBox(width: 6),
              SizedBox(width: 104, child: _cell(pays[i].sum, () => setS(() {}), hint: 'Сумма')),
              const SizedBox(width: 6),
              GestureDetector(onTap: () => setS(() => pays.removeAt(i)), child: Container(width: 24, height: 24, alignment: Alignment.center, decoration: const BoxDecoration(color: AppColors.bgSecondary, shape: BoxShape.circle), child: const Text('✕', style: TextStyle(fontSize: 9.5, color: AppColors.textSecondary)))),
            ]),
          ),
          GestureDetector(onTap: () => setS(() => pays.add(_Pay(accounts.first))), child: Padding(padding: const EdgeInsets.only(top: 6), child: Row(mainAxisSize: MainAxisSize.min, children: [const Text('＋', style: TextStyle(fontSize: 15, color: AppColors.accentHover)), const SizedBox(width: 6), Text('Добавить платёж', style: AppTheme.sans(size: 12.5, weight: FontWeight.w600, color: AppColors.accentHover))]))),
        ]),
        const SizedBox(height: 16),
        // Итого + Сохранить
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.card), border: Border.all(color: AppColors.border), boxShadow: kSoftShadow),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Итого', style: AppTheme.sans(size: 11, color: AppColors.textTertiary)),
              Text(sum(total), style: AppTheme.serif(size: 17, weight: FontWeight.w700)),
            ])),
            PrimaryButton('Сохранить', color: AppColors.success, expand: false, onPressed: () {
              final valid = positions.where((p) => (double.tryParse(p.qty.text.replaceAll(',', '.')) ?? 0) > 0).toList();
              if (valid.isEmpty) { showToast(ctx, 'Добавьте хотя бы одну позицию', color: AppColors.danger, bg: AppColors.dangerSoft, icon: Icons.error_outline); return; }
              final lines = valid.map((p) => (ing: p.ing, qty: double.parse(p.qty.text.replaceAll(',', '.')))).toList();
              final no = app.newSupplyId();
              final s = Supply(
                id: no,
                date: dateCtrl.text.trim().isEmpty ? _today() : dateCtrl.text.trim(),
                supplier: supplier,
                storage: wh,
                items: valid.map((p) => '${p.ing.name} ×${qty(double.parse(p.qty.text.replaceAll(',', '.')))}').join(', '),
                sum: total,
                debt: debt > 0 ? debt : 0,
                status: 'Проведена',
              );
              final payLines = pays.where((p) => p.val > 0).map((p) => (account: p.acc, amount: p.val)).toList();
              app.addSupply(s, lines, payments: payLines);
              Navigator.pop(ctx);
              showToast(context, 'Поставка №$no сохранена — остатки увеличены', icon: Icons.local_shipping_outlined);
            }),
          ]),
        ),
        const SizedBox(height: 8),
      ]);
    });
  });
}

void _newSupplier(BuildContext context, AppState app, ValueChanged<String> onSaved) {
  final name = TextEditingController();
  final phone = TextEditingController(text: '+998 ');
  showAppSheet(context, title: 'Новый поставщик', builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    LabeledField(label: 'Название *', controller: name),
    const SizedBox(height: 12),
    LabeledField(label: 'Телефон', controller: phone, keyboardType: TextInputType.phone),
    const SizedBox(height: 20),
    PrimaryButton('Сохранить', onPressed: () {
      if (name.text.trim().isEmpty) { showToast(ctx, 'Введите название', color: AppColors.danger, bg: AppColors.dangerSoft, icon: Icons.error_outline); return; }
      app.addSupplier(Supplier(id: app.newSupplierId(), name: name.text.trim(), phone: phone.text.trim()));
      Navigator.pop(ctx);
      onSaved(name.text.trim());
      showToast(context, 'Поставщик сохранён');
    }),
    const SizedBox(height: 8),
  ]));
}

String _today() {
  final d = DateTime.now();
  return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
}

Widget _sub(String t) => Padding(padding: const EdgeInsets.only(bottom: 5), child: Text(t.toUpperCase(), style: AppTheme.sans(size: 10.5, weight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 0.5)));

Widget _colHead(String t, TextAlign align) => Text(t.toUpperCase(), textAlign: align, style: AppTheme.sans(size: 10, weight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 0.4));

Widget _sectionCard({required List<Widget> children}) => Container(
  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.card), border: Border.all(color: AppColors.border), boxShadow: kSoftShadow),
  padding: const EdgeInsets.all(14),
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
);

Widget _input(TextEditingController c) => SizedBox(
  height: 42,
  child: TextField(
    controller: c,
    style: AppTheme.sans(size: 13),
    decoration: InputDecoration(
      isDense: true, filled: true, fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderStrong)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderStrong)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
    ),
  ),
);

Widget _cell(TextEditingController c, VoidCallback onChanged, {String? hint}) => SizedBox(
  height: 38,
  child: TextField(
    controller: c,
    keyboardType: TextInputType.number,
    textAlign: TextAlign.right,
    onChanged: (_) => onChanged(),
    style: AppTheme.sans(size: 12.5),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: AppTheme.sans(size: 12.5, color: AppColors.textTertiary),
      isDense: true, filled: true, fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 7, vertical: 9),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: AppColors.borderStrong)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: AppColors.borderStrong)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
    ),
  ),
);

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
