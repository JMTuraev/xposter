import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme.dart';
import '../../state/app_state.dart';
import '../../widgets/ui.dart';
import '../../services/printer_ui.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ── Поиск ──
  final _searchCtrl = TextEditingController();
  String _q = '';

  // ── Компания ──
  late final TextEditingController _nameCtrl;
  late final TextEditingController _addrCompanyCtrl;

  // ── Общие ──
  String _tz = '+05:00 Asia/Samarkand';
  final _shiftEndCtrl = TextEditingController(text: '0:00');
  String _lang = 'Русский';
  bool _hallMap = true;
  bool _guestsQ = true;
  bool _portion = false;
  bool _rounding = false;
  String _service = 'Не использовать';

  // ── Администрирование ──
  bool _techProd = true;
  bool _taxes = false;
  bool _fiscal = false;
  bool _timeTrack = false;
  String _stockNotify = 'Раз в день';
  final _emailCtrl = TextEditingController();

  // ── Заказы ──
  final List<Map<String, dynamic>> _sources = [
    {'name': 'В заведении', 'on': true},
    {'name': 'Навынос', 'on': true},
    {'name': 'Доставка', 'on': false},
    {'name': 'Telegram-бот', 'on': false},
  ];
  final List<String> _payMethods = ['Наличными', 'Карточкой'];

  // ── Доставка ──
  bool _delivery = false;
  String _deliveryMode = 'Вручную с кассы';

  // ── Безопасность ──
  bool _preCheckBan = false;
  bool _twoChecks = false;
  bool _cardOnly = false;
  String _runners = 'Перед оплатой';
  String _pwdDelete = 'Всегда';
  bool _pwdPrecheck = false;
  bool _pwdRunners = false;

  // ── Чек ──
  bool _rcAuto = true;
  bool _rcNo = true;
  bool _rcComment = false;
  bool _rcClient = false;
  bool _rcTaxes = false;
  bool _rcFortune = true;
  bool _rcWifi = false;
  final _wifiNameCtrl = TextEditingController();
  final _wifiPassCtrl = TextEditingController();
  bool _rcAddr = false;
  final _cityCtrl = TextEditingController();
  final _zipCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  final _phoneRcCtrl = TextEditingController();
  String _rcLang = 'Русский';
  final _rcTextCtrl = TextEditingController(text: 'Спасибо! Рахмат!');

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    _nameCtrl = TextEditingController(text: app.company['name'] as String);
    _addrCompanyCtrl = TextEditingController(text: app.company['address'] as String? ?? '');
    _service = app.serviceFeePct == 0 ? 'Не использовать' : '${app.serviceFeePct}%';
    _hydrate(app.uiSettings);
  }

  /// Firestore'dagi saqlangan sozlamalarni lokal maydonlarga yuklash.
  void _hydrate(Map<String, dynamic> s) {
    T pick<T>(String k, T dflt) => s[k] is T ? s[k] as T : dflt;
    _tz = pick('tz', _tz);
    _shiftEndCtrl.text = pick('shiftEnd', _shiftEndCtrl.text);
    _lang = pick('lang', _lang);
    _hallMap = pick('hallMap', _hallMap);
    _guestsQ = pick('guestsQ', _guestsQ);
    _portion = pick('portion', _portion);
    _rounding = pick('rounding', _rounding);
    _techProd = pick('techProd', _techProd);
    _taxes = pick('taxes', _taxes);
    _fiscal = pick('fiscal', _fiscal);
    _timeTrack = pick('timeTrack', _timeTrack);
    _stockNotify = pick('stockNotify', _stockNotify);
    _emailCtrl.text = pick('notifyEmail', _emailCtrl.text);
    final src = s['sources'];
    if (src is List) {
      _sources
        ..clear()
        ..addAll(src.map((e) => Map<String, dynamic>.from(e as Map)));
    }
    final pm = s['payMethods'];
    if (pm is List) {
      _payMethods
        ..clear()
        ..addAll(pm.cast<String>());
    }
    _delivery = pick('delivery', _delivery);
    _deliveryMode = pick('deliveryMode', _deliveryMode);
    _preCheckBan = pick('preCheckBan', _preCheckBan);
    _twoChecks = pick('twoChecks', _twoChecks);
    _cardOnly = pick('cardOnly', _cardOnly);
    _runners = pick('runners', _runners);
    _pwdDelete = pick('pwdDelete', _pwdDelete);
    _pwdPrecheck = pick('pwdPrecheck', _pwdPrecheck);
    _pwdRunners = pick('pwdRunners', _pwdRunners);
    _rcAuto = pick('rcAuto', _rcAuto);
    _rcNo = pick('rcNo', _rcNo);
    _rcComment = pick('rcComment', _rcComment);
    _rcClient = pick('rcClient', _rcClient);
    _rcTaxes = pick('rcTaxes', _rcTaxes);
    _rcFortune = pick('rcFortune', _rcFortune);
    _rcWifi = pick('rcWifi', _rcWifi);
    _wifiNameCtrl.text = pick('wifiName', _wifiNameCtrl.text);
    _wifiPassCtrl.text = pick('wifiPass', _wifiPassCtrl.text);
    _rcAddr = pick('rcAddr', _rcAddr);
    _cityCtrl.text = pick('rcCity', _cityCtrl.text);
    _zipCtrl.text = pick('rcZip', _zipCtrl.text);
    _addrCtrl.text = pick('rcStreet', _addrCtrl.text);
    _phoneRcCtrl.text = pick('rcPhone', _phoneRcCtrl.text);
    _rcLang = pick('rcLang', _rcLang);
    _rcTextCtrl.text = pick('rcText', _rcTextCtrl.text);
  }

  /// Bo'lim qiymatlarini Firestore'ga saqlash (cafe.uiSettings).
  Map<String, dynamic> _collectAll() => {
        'tz': _tz,
        'shiftEnd': _shiftEndCtrl.text,
        'lang': _lang,
        'hallMap': _hallMap,
        'guestsQ': _guestsQ,
        'portion': _portion,
        'rounding': _rounding,
        'techProd': _techProd,
        'taxes': _taxes,
        'fiscal': _fiscal,
        'timeTrack': _timeTrack,
        'stockNotify': _stockNotify,
        'notifyEmail': _emailCtrl.text,
        'sources': _sources,
        'payMethods': _payMethods,
        'delivery': _delivery,
        'deliveryMode': _deliveryMode,
        'preCheckBan': _preCheckBan,
        'twoChecks': _twoChecks,
        'cardOnly': _cardOnly,
        'runners': _runners,
        'pwdDelete': _pwdDelete,
        'pwdPrecheck': _pwdPrecheck,
        'pwdRunners': _pwdRunners,
        'rcAuto': _rcAuto,
        'rcNo': _rcNo,
        'rcComment': _rcComment,
        'rcClient': _rcClient,
        'rcTaxes': _rcTaxes,
        'rcFortune': _rcFortune,
        'rcWifi': _rcWifi,
        'wifiName': _wifiNameCtrl.text,
        'wifiPass': _wifiPassCtrl.text,
        'rcAddr': _rcAddr,
        'rcCity': _cityCtrl.text,
        'rcZip': _zipCtrl.text,
        'rcStreet': _addrCtrl.text,
        'rcPhone': _phoneRcCtrl.text,
        'rcLang': _rcLang,
        'rcText': _rcTextCtrl.text,
      };

  @override
  void dispose() {
    _searchCtrl.dispose();
    _nameCtrl.dispose();
    _addrCompanyCtrl.dispose();
    _shiftEndCtrl.dispose();
    _emailCtrl.dispose();
    _wifiNameCtrl.dispose();
    _wifiPassCtrl.dispose();
    _cityCtrl.dispose();
    _zipCtrl.dispose();
    _addrCtrl.dispose();
    _phoneRcCtrl.dispose();
    _rcTextCtrl.dispose();
    super.dispose();
  }

  bool _visible(String title, List<String> words) {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (title.toLowerCase().contains(q)) return true;
    return words.any((w) => w.contains(q));
  }

  void _save(String name) {
    context.read<AppState>().saveUiSettings(_collectAll());
    showToast(context, '$name — настройки сохранены');
  }

  String get _todayStr {
    final d = DateTime.now();
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd.$mm.2026';
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _appBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
                children: [
                  // ── Поиск ──
                  _searchField(),
                  const SizedBox(height: 12),
                  if (_visible('Компания', const ['название', 'адрес', 'логотип'])) ...[
                    _company(app),
                    const SizedBox(height: 12),
                  ],
                  if (_visible('Общие', const ['часовой', 'валюта', 'язык', 'смена', 'округление', 'обслуживание', 'гости'])) ...[
                    _general(),
                    const SizedBox(height: 12),
                  ],
                  if (_visible('Администрирование', const ['тех', 'смены', 'налог', 'фискал', 'остатк', 'рабочего'])) ...[
                    _admin(app),
                    const SizedBox(height: 12),
                  ],
                  if (_visible('Заказы', const ['источник', 'оплат', 'доставка', 'telegram'])) ...[
                    _orders(),
                    const SizedBox(height: 12),
                  ],
                  if (_visible('Доставка', const ['доставка', 'курьер'])) ...[
                    _deliverySec(),
                    const SizedBox(height: 12),
                  ],
                  if (_visible('Безопасность', const ['пароль', 'пречек', 'бегунк', 'удалени'])) ...[
                    _security(),
                    const SizedBox(height: 12),
                  ],
                  if (_visible('Чек', const ['чек', 'печать', 'wi-fi', 'предсказ', 'налог'])) ...[
                    _receipt(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════ App-bar ═══════════════
  Widget _appBar() {
    return SizedBox(
      height: 52,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('‹', style: AppTheme.sans(size: 20, weight: FontWeight.w600, color: AppColors.accentHover)),
                    const SizedBox(width: 3),
                    Text('Ещё', style: AppTheme.sans(size: 14.5, weight: FontWeight.w600, color: AppColors.accentHover)),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Text('Настройки', style: AppTheme.sans(size: 17, weight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _q = v),
        style: AppTheme.sans(size: 13.5),
        decoration: InputDecoration(
          hintText: 'Поиск по настройкам…',
          hintStyle: AppTheme.sans(size: 13.5, color: AppColors.textTertiary),
          isDense: true,
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: AppColors.border)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: AppColors.accent, width: 2)),
        ),
      ),
    );
  }

  // ═══════════════ Section shells ═══════════════
  Widget _sectionCard(String header, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
        boxShadow: kSoftShadow,
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(header, style: AppTheme.sans(size: 14.5, weight: FontWeight.w700)),
          const SizedBox(height: 10),
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            children[i],
          ],
        ],
      ),
    );
  }

  Widget _saveButton(String section) {
    return GestureDetector(
      onTap: () => _save(section),
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(AppRadius.btn)),
        child: Text('Сохранить', style: AppTheme.sans(size: 13, weight: FontWeight.w600, color: Colors.white)),
      ),
    );
  }

  // ═══════════════ Reusable rows ═══════════════
  Widget _pillToggle(bool value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 40,
        height: 24,
        decoration: BoxDecoration(
          color: value ? AppColors.success : AppColors.borderStrong,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              top: 2,
              left: value ? 18 : 2,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Color(0x40141413), blurRadius: 3, offset: Offset(0, 1))],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggleRow(String label, bool value, VoidCallback onTap, {String? sub}) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTheme.sans(size: 13, weight: FontWeight.w500)),
              if (sub != null) ...[
                const SizedBox(height: 2),
                Text(sub, style: AppTheme.sans(size: 11, color: AppColors.textTertiary)),
              ],
            ],
          ),
        ),
        const SizedBox(width: 10),
        _pillToggle(value, onTap),
      ],
    );
  }

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Text(
          text.toUpperCase(),
          style: AppTheme.sans(size: 10.5, weight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 0.5),
        ),
      );

  Widget _textField(TextEditingController ctrl, {String? hint, double height = 42, TextAlign align = TextAlign.start, double fontSize = 13.5, ValueChanged<String>? onChanged}) {
    return SizedBox(
      height: height,
      child: TextField(
        controller: ctrl,
        textAlign: align,
        onChanged: onChanged,
        style: AppTheme.sans(size: fontSize),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTheme.sans(size: fontSize, color: AppColors.textTertiary),
          isDense: true,
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderStrong)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderStrong)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accent, width: 2)),
        ),
      ),
    );
  }

  Widget _selectField(String value, List<String> options, ValueChanged<String> onChanged, {double fontSize = 13}) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textSecondary),
          style: AppTheme.sans(size: fontSize, color: AppColors.text),
          items: options.map((o) => DropdownMenuItem(value: o, child: Text(o, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }

  Widget _chipGroup(List<String> options, String selected, ValueChanged<String> onSelected) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: options.map((o) {
        final active = o == selected;
        return GestureDetector(
          onTap: () => onSelected(o),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: active ? AppColors.posDark : AppColors.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: active ? AppColors.posDark : AppColors.border),
            ),
            child: Text(o, style: AppTheme.sans(size: 12, weight: FontWeight.w600, color: active ? Colors.white : AppColors.textSecondary)),
          ),
        );
      }).toList(),
    );
  }

  Widget _labeledGroup(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(label.toUpperCase(), style: AppTheme.sans(size: 10.5, weight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 0.5)),
        ),
        child,
      ],
    );
  }

  Widget _addLink(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('＋', style: AppTheme.sans(size: 15, weight: FontWeight.w600, color: AppColors.accentHover)),
          const SizedBox(width: 6),
          Text(label, style: AppTheme.sans(size: 12.5, weight: FontWeight.w600, color: AppColors.accentHover)),
        ],
      ),
    );
  }

  Widget _staticRow(String left, String right, {bool rightBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(left, style: AppTheme.sans(size: 12.5, color: AppColors.textTertiary)),
        Text(right, style: AppTheme.sans(size: 12.5, weight: rightBold ? FontWeight.w600 : FontWeight.w400, color: rightBold ? AppColors.text : AppColors.textTertiary)),
      ],
    );
  }

  Widget _linkRow(String left, String linkLabel, VoidCallback onTap) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(left, style: AppTheme.sans(size: 12.5, color: AppColors.textTertiary)),
        GestureDetector(
          onTap: onTap,
          child: Text(linkLabel, style: AppTheme.sans(size: 12.5, weight: FontWeight.w600, color: AppColors.accentHover)),
        ),
      ],
    );
  }

  // ═══════════════ 🏠 Компания ═══════════════
  Widget _company(AppState app) {
    return _sectionCard('🏠 Компания', [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('Название'),
          _textField(_nameCtrl, onChanged: (_) => setState(() {})),
        ],
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('Адрес'),
          _textField(_addrCompanyCtrl, onChanged: (_) => setState(() {})),
        ],
      ),
      _staticRow('ID заведения', app.currentCafeId ?? '—'),
      GestureDetector(
        onTap: () {
          if (_nameCtrl.text.trim().isEmpty) {
            showToast(context, 'Название не может быть пустым', color: AppColors.danger, bg: AppColors.dangerSoft, icon: Icons.error_outline);
            return;
          }
          app.setCompany(name: _nameCtrl.text, address: _addrCompanyCtrl.text);
          showToast(context, 'Компания — настройки сохранены');
        },
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(AppRadius.btn)),
          child: Text('Сохранить', style: AppTheme.sans(size: 13, weight: FontWeight.w600, color: Colors.white)),
        ),
      ),
    ]);
  }

  // ═══════════════ 🕐 Общие ═══════════════
  Widget _general() {
    return _sectionCard('🕐 Общие', [
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _fieldLabel('Часовой пояс'),
                _selectField(_tz, const ['+05:00 Asia/Samarkand', '+05:00 Asia/Tashkent'], (v) => setState(() => _tz = v), fontSize: 12.5),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 92,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _fieldLabel('Конец смены'),
                _textField(_shiftEndCtrl, align: TextAlign.center, fontSize: 13),
              ],
            ),
          ),
        ],
      ),
      Padding(
        padding: const EdgeInsets.only(top: 0),
        child: Text('Продажи после полуночи попадут в бизнес-день накануне', style: AppTheme.sans(size: 11, color: AppColors.textTertiary)),
      ),
      _staticRow('Валюта', 'Узбекский сум', rightBold: true),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('Язык'),
          _selectField(_lang, const ['Русский', "O'zbekcha", 'English'], (v) {
            setState(() => _lang = v);
            showToast(context, 'Язык изменится после перезапуска приложения', icon: Icons.language);
          }),
        ],
      ),
      _toggleRow('Карта зала на кассе', _hallMap, () => setState(() => _hallMap = !_hallMap)),
      _toggleRow('Спрашивать количество гостей', _guestsQ, () => setState(() => _guestsQ = !_guestsQ)),
      _toggleRow('Продажа части порции', _portion, () => setState(() => _portion = !_portion)),
      _toggleRow('Округление суммы чека', _rounding, () => setState(() => _rounding = !_rounding)),
      _labeledGroup('Процент за обслуживание', _chipGroup(
        {'Не использовать', '5%', '10%', '15%', _service}.toList(),
        _service,
        (v) {
          setState(() => _service = v);
          final pct = v == 'Не использовать' ? 0 : (int.tryParse(v.replaceAll('%', '')) ?? 0);
          context.read<AppState>().setServiceFeePct(pct);
        },
      )),
      _saveButton('Общие'),
    ]);
  }

  // ═══════════════ 🗂 Администрирование ═══════════════
  Widget _admin(AppState app) {
    return _sectionCard('🗂 Администрирование', [
      _toggleRow('Производство тех. карт', _techProd, () => setState(() => _techProd = !_techProd)),
      _toggleRow(
        'Кассовые смены',
        app.cashShiftsEnabled,
        () {
          app.setCashShifts(!app.cashShiftsEnabled);
          showToast(context, 'Настройка «Кассовые смены» применена к разделу «Финансы»');
        },
        sub: 'Влияет на раздел Финансы',
      ),
      _toggleRow('Учитывать налоги', _taxes, () => setState(() => _taxes = !_taxes)),
      _toggleRow('Фискализация', _fiscal, () => setState(() => _fiscal = !_fiscal)),
      _toggleRow('Учёт рабочего времени', _timeTrack, () => setState(() => _timeTrack = !_timeTrack)),
      _labeledGroup('Оповещение об остатках', _chipGroup(const ['Не оповещать', 'Раз в день'], _stockNotify, (v) => setState(() => _stockNotify = v))),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('E-mail для оповещений'),
          _textField(_emailCtrl, fontSize: 13),
        ],
      ),
      _saveButton('Администрирование'),
    ]);
  }

  // ═══════════════ 🧾 Заказы ═══════════════
  Widget _orders() {
    return _sectionCard('🧾 Заказы', [
      Text('ИСТОЧНИКИ ЗАКАЗОВ · ОТОБРАЖАТЬ НА КАССЕ', style: AppTheme.sans(size: 10.5, weight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 0.5)),
      Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (int i = 0; i < _sources.length; i++)
              Container(
                decoration: BoxDecoration(
                  border: i > 0 ? const Border(top: BorderSide(color: AppColors.border)) : null,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Expanded(child: Text(_sources[i]['name'] as String, style: AppTheme.sans(size: 13, weight: FontWeight.w500))),
                    const SizedBox(width: 10),
                    _pillToggle(_sources[i]['on'] as bool, () => setState(() => _sources[i]['on'] = !(_sources[i]['on'] as bool))),
                  ],
                ),
              ),
          ],
        ),
      ),
      _addLink('Добавить источник', () {
        setState(() => _sources.add({'name': 'Агрегатор №${_sources.length - 3}', 'on': true}));
        showToast(context, 'Источник добавлен');
      }),
      Text('МЕТОДЫ ОПЛАТЫ', style: AppTheme.sans(size: 10.5, weight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 0.5)),
      Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (int i = 0; i < _payMethods.length; i++)
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: i > 0 ? const Border(top: BorderSide(color: AppColors.border)) : null,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Text(_payMethods[i], style: AppTheme.sans(size: 13, weight: FontWeight.w500)),
              ),
          ],
        ),
      ),
      _addLink('Добавить свой метод', _openPmSheet),
      _saveButton('Заказы'),
    ]);
  }

  void _openPmSheet() {
    final draftCtrl = TextEditingController();
    showAppSheet<void>(
      context,
      title: 'Новый метод оплаты',
      builder: (ctx) {
        void addNamed(String n) {
          setState(() => _payMethods.add(n));
          Navigator.of(ctx).pop();
          showToast(context, 'Метод «$n» добавлен');
        }

        return StatefulBuilder(
          builder: (ctx, setSheet) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: _pmQuick('Click', () => addNamed('Click'))),
                  const SizedBox(width: 8),
                  Expanded(child: _pmQuick('Payme', () => addNamed('Payme'))),
                ],
              ),
              const SizedBox(height: 10),
              _textField(draftCtrl, hint: 'Или своё название…', height: 46, fontSize: 13.5),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  final n = draftCtrl.text.trim();
                  if (n.isEmpty) return;
                  setState(() => _payMethods.add(n));
                  Navigator.of(ctx).pop();
                  showToast(context, 'Метод «$n» добавлен');
                },
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(AppRadius.btn)),
                  child: Text('Добавить', style: AppTheme.sans(size: 14.5, weight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pmQuick(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.btn),
          border: Border.all(color: AppColors.borderStrong),
        ),
        child: Text(label, style: AppTheme.sans(size: 13.5, weight: FontWeight.w600)),
      ),
    );
  }

  // ═══════════════ 🛵 Доставка ═══════════════
  Widget _deliverySec() {
    return _sectionCard('🛵 Доставка', [
      _toggleRow('Работать с доставкой', _delivery, () => setState(() => _delivery = !_delivery)),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('Как принимать заказы'),
          _selectField(_deliveryMode, const ['Вручную с кассы', 'Через Delivery Bot', 'Сайт и Telegram'], (v) => setState(() => _deliveryMode = v)),
        ],
      ),
      _saveButton('Доставка'),
    ]);
  }

  // ═══════════════ 🔒 Безопасность ═══════════════
  Widget _security() {
    return _sectionCard('🔒 Безопасность', [
      _linkRow('Пароль администратора', 'Изменить', () => showToast(context, 'Ссылка для смены пароля отправлена на ${_emailCtrl.text}', icon: Icons.vpn_key)),
      _toggleRow('Запретить печать пречека', _preCheckBan, () => setState(() => _preCheckBan = !_preCheckBan)),
      _toggleRow('Печатать два чека', _twoChecks, () => setState(() => _twoChecks = !_twoChecks)),
      _toggleRow('Клиент только по карте', _cardOnly, () => setState(() => _cardOnly = !_cardOnly)),
      _labeledGroup('Бегунки на кухню', _chipGroup(const ['Никогда', 'Перед оплатой', 'Перед оплатой и при выходе'], _runners, (v) => setState(() => _runners = v))),
      _labeledGroup('Пароль администратора при удалении товара', _chipGroup(const ['Никогда', 'Всегда'], _pwdDelete, (v) => setState(() => _pwdDelete = v))),
      _toggleRow('…после печати пречека', _pwdPrecheck, () => setState(() => _pwdPrecheck = !_pwdPrecheck)),
      _toggleRow('…после печати бегунков', _pwdRunners, () => setState(() => _pwdRunners = !_pwdRunners)),
      _saveButton('Безопасность'),
    ]);
  }

  // ═══════════════ 🧾 Чек ═══════════════
  Widget _receipt() {
    return _sectionCard('🧾 Чек', [
      // ── Wi-Fi termal printer: qidirish/ulash ──
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showPrinterPicker(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            const Text('🖨', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 10),
            Expanded(child: Text('Wi-Fi принтер — найти и подключить', style: AppTheme.sans(size: 13.5, weight: FontWeight.w500))),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.textTertiary),
          ]),
        ),
      ),
      const Divider(height: 1, color: AppColors.border),
      _toggleRow('Автопечать чека', _rcAuto, () => setState(() => _rcAuto = !_rcAuto)),
      _toggleRow('Номер чека', _rcNo, () => setState(() => _rcNo = !_rcNo)),
      _toggleRow('Комментарий к чеку', _rcComment, () => setState(() => _rcComment = !_rcComment)),
      _toggleRow('Телефон и адрес клиента', _rcClient, () => setState(() => _rcClient = !_rcClient)),
      _toggleRow('Суммы налогов', _rcTaxes, () => setState(() => _rcTaxes = !_rcTaxes)),
      _toggleRow('Печатать предсказания 🥠', _rcFortune, () => setState(() => _rcFortune = !_rcFortune)),
      _toggleRow('Wi-Fi для гостей', _rcWifi, () => setState(() => _rcWifi = !_rcWifi)),
      if (_rcWifi)
        Row(
          children: [
            Expanded(child: _textField(_wifiNameCtrl, hint: 'Название сети', height: 40, fontSize: 12.5, onChanged: (_) => setState(() {}))),
            const SizedBox(width: 8),
            Expanded(child: _textField(_wifiPassCtrl, hint: 'Пароль', height: 40, fontSize: 12.5, onChanged: (_) => setState(() {}))),
          ],
        ),
      _toggleRow('Адрес заведения', _rcAddr, () => setState(() => _rcAddr = !_rcAddr)),
      if (_rcAddr)
        Column(
          children: [
            Row(
              children: [
                Expanded(child: _textField(_cityCtrl, hint: 'Город', height: 40, fontSize: 12.5, onChanged: (_) => setState(() {}))),
                const SizedBox(width: 8),
                SizedBox(width: 88, child: _textField(_zipCtrl, hint: 'Индекс', height: 40, fontSize: 12.5)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _textField(_addrCtrl, hint: 'Адрес', height: 40, fontSize: 12.5, onChanged: (_) => setState(() {}))),
                const SizedBox(width: 8),
                SizedBox(width: 88, child: _textField(_phoneRcCtrl, hint: 'Телефон', height: 40, fontSize: 12.5, onChanged: (_) => setState(() {}))),
              ],
            ),
          ],
        ),
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _fieldLabel('Язык чека'),
                _selectField(_rcLang, const ['Русский', "O'zbekcha"], (v) => setState(() => _rcLang = v), fontSize: 12.5),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _fieldLabel('Печатать на чеке'),
                _textField(_rcTextCtrl, fontSize: 12.5, onChanged: (_) => setState(() {})),
              ],
            ),
          ),
        ],
      ),
      Center(child: _receiptPreview()),
      _saveButton('Чек'),
    ]);
  }

  Widget _receiptPreview() {
    const mono = 'monospace';
    const rcColor = Color(0xFF2A2A26);
    const dashColor = Color(0xFFB8B5AC);

    TextStyle base({double size = 10, FontWeight weight = FontWeight.w400}) => TextStyle(
          fontFamily: mono,
          fontSize: size,
          fontWeight: weight,
          height: 1.5,
          color: rcColor,
        );

    Widget dashed() => Container(
          height: 1,
          margin: const EdgeInsets.symmetric(vertical: 7),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: dashColor, style: BorderStyle.solid)),
          ),
        );

    Widget row(String l, String r) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 0.5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text(l, style: base()), Text(r, style: base())],
          ),
        );

    Widget note(String l) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 0.5),
          child: Text(l, style: base().copyWith(color: const Color(0xFF6B6961))),
        );

    Widget total(String l, String r) => Container(
          margin: const EdgeInsets.only(top: 5),
          padding: const EdgeInsets.only(top: 5),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: dashColor))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l, style: base(size: 11, weight: FontWeight.w700)),
              Text(r, style: base(size: 11, weight: FontWeight.w700)),
            ],
          ),
        );

    Widget thanks(String l) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Center(child: Text(l, style: base(weight: FontWeight.w700), textAlign: TextAlign.center)),
        );

    final lines = <Widget>[];
    if (_rcNo) lines.add(row('Чек №42', _todayStr));
    lines.add(row('Плов чайханский ×1', '35 000'));
    lines.add(row('Чай чёрный ×2', '10 000'));
    if (_rcComment) lines.add(note('💬 Подать всё вместе'));
    if (_rcTaxes) lines.add(row('НДС 12%', '5 400'));
    lines.add(total('ИТОГО', '45 000'));
    if (_rcClient) lines.add(note('Азиз Каримов · +998 90 123-45-67'));
    if (_rcWifi) {
      final name = _wifiNameCtrl.text.isEmpty ? '—' : _wifiNameCtrl.text;
      final pass = _wifiPassCtrl.text.isEmpty ? '' : ' · ${_wifiPassCtrl.text}';
      lines.add(note('📶 Wi-Fi: $name$pass'));
    }
    if (_rcAddr) lines.add(note('${_cityCtrl.text}, ${_addrCtrl.text} · ${_phoneRcCtrl.text}'));
    if (_rcTextCtrl.text.isNotEmpty) lines.add(thanks(_rcTextCtrl.text));
    if (_rcFortune) lines.add(note('🥠 Вас ждёт удачная неделя!'));

    return Container(
      width: 230,
      padding: const EdgeInsets.fromLTRB(13, 13, 13, 15),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF5),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.border),
        boxShadow: const [BoxShadow(color: Color(0x14141413), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: Text(_nameCtrl.text, style: base(size: 11, weight: FontWeight.w700), textAlign: TextAlign.center)),
          dashed(),
          ...lines,
        ],
      ),
    );
  }
}
