import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../models.dart';
import '../../state/app_state.dart';
import '../../widgets/ui.dart';

/// Yangi/tahrir mijoz formasi (bottom sheet). Prototip «Новый клиент» bilan 1:1:
/// Имя*, Пол (М/Ж), Дата рождения, Группа (· 5%/· 10%) + Скидка %, Телефон · +998 +
/// Номер карты, E-mail, Комментарий, Адрес доставки (+ второй адрес).
void showClientForm(BuildContext context, AppState app, {Client? existing, required ValueChanged<Client> onSaved}) {
  final name = TextEditingController(text: existing?.name ?? '');
  final birth = TextEditingController(text: existing?.birthday ?? '');
  final discount = TextEditingController(text: existing != null ? _pct(app, existing.group).toString() : '5');
  final card = TextEditingController(text: existing?.card ?? '');
  final phone = TextEditingController(text: existing != null ? existing.phone.replaceAll('+998 ', '') : '');
  final email = TextEditingController();
  final comment = TextEditingController();
  final address = TextEditingController();
  final addr2 = TextEditingController();
  bool addr2On = false;
  String gender = 'М';
  String group = existing?.group ?? _defaultGroup(app);

  showAppSheet(context, title: existing == null ? 'Новый клиент' : 'Клиент', builder: (ctx) {
    return StatefulBuilder(builder: (ctx, setS) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label('Имя *'),
        _input(name, hint: 'Имя и фамилия'),
        const SizedBox(height: 10),
        // Пол + Дата рождения
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label('Пол'),
            _genderToggle(gender, (v) => setS(() => gender = v)),
          ])),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label('Дата рождения'),
            _input(birth, hint: 'дд.мм.гггг'),
          ])),
        ]),
        const SizedBox(height: 10),
        // Группа + Скидка %
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label('Группа'),
            _groupDropdown(app, group, (v) => setS(() { group = v; discount.text = _pct(app, v).toString(); })),
          ])),
          const SizedBox(width: 10),
          SizedBox(width: 90, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label('Скидка %'),
            _input(discount, align: TextAlign.center, keyboardType: TextInputType.number),
          ])),
        ]),
        const SizedBox(height: 10),
        // Телефон + Номер карты
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label('Телефон · +998'),
            _input(phone, hint: '90 123-45-67', keyboardType: TextInputType.phone),
          ])),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label('Номер карты'),
            _input(card, hint: 'Например: 1024', keyboardType: TextInputType.number),
          ])),
        ]),
        const SizedBox(height: 10),
        _label('E-mail'),
        _input(email, hint: 'client@mail.uz', keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 10),
        _label('Комментарий'),
        _input(comment, hint: 'Например: любит место у окна'),
        const SizedBox(height: 10),
        _label('Адрес доставки'),
        _input(address, hint: 'Улица, дом, квартира'),
        if (addr2On) ...[
          const SizedBox(height: 8),
          _input(addr2, hint: 'Второй адрес'),
        ] else ...[
          const SizedBox(height: 8),
          GestureDetector(onTap: () => setS(() => addr2On = true), child: Row(mainAxisSize: MainAxisSize.min, children: [const Text('＋', style: TextStyle(fontSize: 15, color: AppColors.accentHover)), const SizedBox(width: 6), Text('Добавить адрес', style: AppTheme.sans(size: 12.5, weight: FontWeight.w600, color: AppColors.accentHover))])),
        ],
        const SizedBox(height: 16),
        PrimaryButton(existing == null ? 'Добавить клиента' : 'Сохранить', onPressed: () {
          if (name.text.trim().isEmpty) { showToast(ctx, 'Введите имя', color: AppColors.danger, bg: AppColors.dangerSoft, icon: Icons.error_outline); return; }
          final phoneStr = phone.text.trim().isEmpty ? (existing?.phone ?? '+998 —') : '+998 ${phone.text.trim()}';
          String? tx(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
          if (existing != null) {
            existing.name = name.text.trim();
            existing.phone = phoneStr;
            existing.group = group;
            if (card.text.trim().isNotEmpty) existing.card = card.text.trim();
            existing.birthday = birth.text.trim().isEmpty ? existing.birthday : birth.text.trim();
            existing.gender = gender;
            existing.email = tx(email);
            existing.comment = tx(comment);
            existing.address = [tx(address), tx(addr2)].where((e) => e != null).join(' · ').trim().isEmpty ? existing.address : [tx(address), tx(addr2)].where((e) => e != null).join(' · ');
            app.notify();
            Navigator.pop(ctx);
            showToast(context, 'Клиент сохранён');
            onSaved(existing);
            return;
          }
          final c = Client(
            id: app.newClientId(),
            name: name.text.trim(),
            phone: phoneStr,
            group: group,
            card: card.text.trim().isEmpty ? '${1000 + app.newClientId()}' : card.text.trim(),
            birthday: birth.text.trim().isEmpty ? null : birth.text.trim(),
            gender: gender,
            email: tx(email),
            comment: tx(comment),
            address: [tx(address), tx(addr2)].where((e) => e != null).join(' · ').trim().isEmpty ? null : [tx(address), tx(addr2)].where((e) => e != null).join(' · '),
          );
          app.addClient(c);
          Navigator.pop(ctx);
          showToast(context, 'Клиент добавлен: ${c.name}');
          onSaved(c);
        }),
        const SizedBox(height: 8),
      ]);
    });
  });
}

// Guruh foizini AppState'dan olish (Новые=0, Постоянные=5, VIP=10).
int _pct(AppState app, String group) {
  final g = app.clientGroups.where((g) => g.name == group);
  return g.isEmpty ? 0 : g.first.percent;
}

String _defaultGroup(AppState app) {
  final perm = app.clientGroups.where((g) => g.percent == 5);
  return perm.isNotEmpty ? perm.first.name : app.clientGroups.first.name;
}

Widget _label(String t) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(t.toUpperCase(), style: AppTheme.sans(size: 11, weight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 0.8)));

Widget _genderToggle(String value, ValueChanged<String> onChanged) => Container(
  height: 44,
  padding: const EdgeInsets.all(3),
  decoration: BoxDecoration(color: AppColors.bgSecondary, borderRadius: BorderRadius.circular(AppRadius.btn)),
  child: Row(children: [
    _genderSeg('М', value == 'М', () => onChanged('М')),
    const SizedBox(width: 3),
    _genderSeg('Ж', value == 'Ж', () => onChanged('Ж')),
  ]),
);

Widget _genderSeg(String label, bool active, VoidCallback onTap) => Expanded(
  child: GestureDetector(
    onTap: onTap,
    child: Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(color: active ? AppColors.surface : Colors.transparent, borderRadius: BorderRadius.circular(9)),
      child: Text(label, style: AppTheme.sans(size: 13, weight: FontWeight.w600, color: active ? AppColors.text : AppColors.textSecondary)),
    ),
  ),
);

Widget _input(TextEditingController c, {String? hint, TextInputType? keyboardType, TextAlign align = TextAlign.left}) => SizedBox(
  height: 44,
  child: TextField(
    controller: c,
    keyboardType: keyboardType,
    textAlign: align,
    style: AppTheme.sans(size: 13.5),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: AppTheme.sans(size: 13.5, color: AppColors.textTertiary),
      isDense: true, filled: true, fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.btn), borderSide: const BorderSide(color: AppColors.borderStrong)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.btn), borderSide: const BorderSide(color: AppColors.borderStrong)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.btn), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
    ),
  ),
);

Widget _groupDropdown(AppState app, String value, ValueChanged<String> onChanged) {
  final options = app.clientGroups;
  final names = options.map((g) => g.name).toList();
  final safe = names.contains(value) ? value : names.first;
  return Container(
    height: 44,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.btn), border: Border.all(color: AppColors.borderStrong)),
    child: DropdownButtonHideUnderline(child: DropdownButton<String>(
      value: safe, isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
      style: AppTheme.sans(size: 13.5, color: AppColors.text),
      items: options.map((g) => DropdownMenuItem(value: g.name, child: Text(g.percent > 0 ? '${g.name} · ${g.percent}%' : g.name, maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: (v) { if (v != null) onChanged(v); },
    )),
  );
}
