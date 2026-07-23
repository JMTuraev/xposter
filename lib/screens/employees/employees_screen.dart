import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../theme.dart';
import '../../state/app_state.dart';
import '../../models.dart';
import '../../widgets/ui.dart';

// ── Ekran-lokal modellar (app_state da yo'q — prototip seed bo'yicha) ──
class _Position {
  String name;
  List<String> rights;
  final bool locked;
  _Position(this.name, this.rights, {this.locked = false});
}

class _Register {
  final String id;
  String name;
  String venue;
  String type;
  String login;
  bool online;
  _Register({required this.id, required this.name, required this.venue, required this.type, required this.login, this.online = false});
}

class _Session {
  final String user;
  final String device;
  final String browser;
  final String ip;
  final String time;
  _Session(this.user, this.device, this.browser, this.ip, this.time);
}

class _Token {
  final String id;
  final String app;
  final String emp;
  final String token;
  final String date;
  _Token({required this.id, required this.app, required this.emp, required this.token, required this.date});
}

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});
  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  // tab: emp / pos / reg / ven / ses / int
  String _tab = 'emp';
  static const _chips = [
    ('emp', 'Сотрудники'),
    ('pos', 'Должности'),
    ('reg', 'Кассы'),
    ('ven', 'Заведения'),
    ('ses', 'Сессии'),
    ('int', 'Интеграции'),
  ];

  // Reveal holatlari (lokal)
  final Set<int> _showPin = {};
  final Set<String> _showTok = {};
  bool _showPass = false;

  // ── Ekran-lokal seed data ──
  final List<_Position> _positions = [
    _Position('Владелец', ['Полный доступ'], locked: true),
    _Position('Управляющий', ['Полный доступ']),
    _Position('Администратор зала', ['Касса', 'Администрирование зала']),
    _Position('Официант', ['Касса']),
    _Position('Маркетолог', ['Статистика', 'Маркетинг']),
    _Position('Повар', []),
  ];

  final List<_Register> _registers = [
    _Register(id: 'r1', name: 'Касса №1', venue: 'Чайхана «Бухоро»', type: 'Стандартная', login: 'kassa1@buxoro', online: true),
  ];

  final List<_Session> _sessions = [
    _Session('Владелец', 'Это устройство · Android', 'Xposter 1.0', '—', 'сейчас'),
  ];

  final List<_Token> _tokens = [];

  static const _rightsAll = ['Касса', 'Статистика', 'Финансы', 'Меню', 'Склад', 'Маркетинг', 'Настройки', 'Администрирование зала'];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _appBar(context),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
        children: [
          _chipRow(app),
          const SizedBox(height: 10),
          ..._tabBody(app),
        ],
      ),
    );
  }

  // ── Custom app-bar: ‹ Ещё | Сотрудники (center) ──
  PreferredSizeWidget _appBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      centerTitle: true,
      title: Text('Сотрудники', style: AppTheme.sans(size: 17, weight: FontWeight.w600)),
      leading: null,
      flexibleSpace: SafeArea(
        child: Align(
          alignment: Alignment.centerLeft,
          child: InkWell(
            onTap: () => Navigator.of(context).maybePop(),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
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
      ),
    );
  }

  // ── Chip qatori + ＋ (emp/pos/reg da) ──
  Widget _chipRow(AppState app) {
    final showAdd = _tab == 'emp' || _tab == 'pos' || _tab == 'reg';
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 2),
              itemCount: _chips.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final c = _chips[i];
                final active = _tab == c.$1;
                return GestureDetector(
                  onTap: () => setState(() => _tab = c.$1),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 13),
                    decoration: BoxDecoration(
                      color: active ? AppColors.posDark : AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: active ? AppColors.posDark : AppColors.border),
                    ),
                    child: Text(
                      c.$2,
                      style: AppTheme.sans(size: 12.5, weight: FontWeight.w600, color: active ? Colors.white : AppColors.textSecondary),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (showAdd) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _onAdd(app),
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(10)),
              child: const Text('＋', style: TextStyle(fontSize: 19, color: Colors.white, height: 1)),
            ),
          ),
        ],
      ],
    );
  }

  void _onAdd(AppState app) {
    if (_tab == 'emp') {
      _openEmployeeSheet(app, null);
    } else if (_tab == 'pos') {
      _openPositionSheet(null);
    } else if (_tab == 'reg') {
      setState(() {
        final n = _registers.length + 1;
        _registers.add(_Register(id: 'r${DateTime.now().millisecondsSinceEpoch}', name: 'Касса №$n', venue: 'Чайхана «Бухоро»', type: 'Стандартная', login: 'kassa$n@buxoro', online: false));
      });
      showToast(context, 'Касса добавлена');
    }
  }

  List<Widget> _tabBody(AppState app) {
    switch (_tab) {
      case 'emp':
        return _employees(app);
      case 'pos':
        return _positionsList();
      case 'reg':
        return _registersList();
      case 'ven':
        return _venues();
      case 'ses':
        return _sessionsList();
      case 'int':
        return _integrations();
      default:
        return const [SizedBox()];
    }
  }

  // ═══════════════════ Сотрудники ═══════════════════
  List<Widget> _employees(AppState app) {
    final code = (app.company['code'] ?? '').toString();
    return [
      // «Код заведения» — xodim shu kod bilan o'z qurilmasidan kiradi.
      if (code.isNotEmpty) ...[
        Container(
          decoration: BoxDecoration(
            color: AppColors.accentSoft,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: const Color(0xFFEBCDBE)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            const Text('🔑', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Код заведения — для входа сотрудников',
                    style: AppTheme.sans(size: 12, color: AppColors.textSecondary)),
                Text('Сотрудник входит: логин + пароль + этот код',
                    style: AppTheme.sans(size: 11, color: AppColors.textTertiary)),
              ]),
            ),
            SelectableText(code,
                style: AppTheme.serif(size: 22, weight: FontWeight.w700, color: AppColors.accentHover)),
          ]),
        ),
        const SizedBox(height: 10),
      ],
      Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (int i = 0; i < app.employees.length; i++) _employeeRow(app, app.employees[i], i != 0),
          ],
        ),
      ),
    ];
  }

  Widget _employeeRow(AppState app, Employee e, bool topBorder) {
    final revealed = _showPin.contains(e.id);
    return InkWell(
      onTap: () => _openEmployeeSheet(app, e),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          border: Border(top: topBorder ? const BorderSide(color: AppColors.border) : BorderSide.none),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: AppColors.accentSoft, shape: BoxShape.circle),
                  child: Text(e.initials, style: AppTheme.sans(size: 13, weight: FontWeight.w700, color: AppColors.accentHover)),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.name, style: AppTheme.sans(size: 13.5, weight: FontWeight.w600)),
                      const SizedBox(height: 1),
                      Text('${e.role} · ${e.phone.isEmpty ? '—' : e.phone}', style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary)),
                    ],
                  ),
                ),
                _iconTap(
                  emoji: '🗑',
                  onTap: () => _deleteEmployee(app, e),
                  activeBg: AppColors.dangerSoft,
                ),
              ],
            ),
            const SizedBox(height: 7),
            Padding(
              padding: const EdgeInsets.only(left: 49),
              child: Row(
                children: [
                  Text.rich(TextSpan(
                    style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary),
                    children: [
                      const TextSpan(text: 'PIN '),
                      TextSpan(
                        // Hash'langan PIN'ni ko'rsatib bo'lmaydi (ochiq matn saqlanmaydi) —
                        // faqat legacy (hali migratsiya qilinmagan) hujjatda ko'rinadi.
                        text: revealed ? (e.pin.isNotEmpty ? e.pin : 'задан · скрыт') : '••••',
                        style: AppTheme.sans(size: 11.5, weight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 1.1),
                      ),
                    ],
                  )),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => revealed ? _showPin.remove(e.id) : _showPin.add(e.id)),
                    behavior: HitTestBehavior.opaque,
                    child: Text(revealed ? '🙈' : '👁', style: const TextStyle(fontSize: 13)),
                  ),
                  const Spacer(),
                  Text('вход: ${e.lastLogin ?? 'ещё не входил(а)'}', style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteEmployee(AppState app, Employee e) {
    if (e.role == 'Владелец') {
      showToast(context, 'Нельзя удалить владельца', color: AppColors.danger, bg: AppColors.dangerSoft, icon: Icons.block);
      return;
    }
    _confirm(
      title: 'Удалить сотрудника?',
      desc: '«${e.name}» потеряет доступ к кассе и админке.',
      label: 'Удалить',
      onOk: () async {
        setState(() => _showPin.remove(e.id));
        if (app.repo.ready && e.uid != null) {
          try {
            await app.deleteEmployee(e.uid!); // Cloud Function: Auth user + doc
          } catch (_) {
            if (mounted) showToast(context, 'Не удалось удалить (требуется Cloud Functions)', color: AppColors.danger, bg: AppColors.dangerSoft, icon: Icons.error_outline);
            return;
          }
        } else {
          app.employees.remove(e);
          app.notify();
        }
        if (mounted) showToast(context, 'Сотрудник удалён', color: AppColors.danger, bg: AppColors.dangerSoft, icon: Icons.delete_outline);
      },

    );
  }

  void _openEmployeeSheet(AppState app, Employee? existing) {
    final nameC = TextEditingController(text: existing?.name ?? '');
    final phoneC = TextEditingController(text: existing?.phone ?? '');
    final loginC = TextEditingController(text: existing?.login ?? '');
    final passC = TextEditingController();
    final pinC = TextEditingController(text: existing?.pin ?? '');
    String role = existing?.role ?? 'Официант';
    bool venue = true;
    bool nameErr = false;
    bool pinErr = false;

    final roleOpts = _positions.map((p) => p.name).toList();
    if (!roleOpts.contains(role)) roleOpts.insert(0, role);

    showAppSheet(
      context,
      title: existing == null ? 'Новый сотрудник' : 'Сотрудник',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sheetField('Имя', nameC, errored: nameErr, onChanged: (_) { if (nameErr) setS(() => nameErr = false); }),
            const SizedBox(height: 12),
            _sheetField('Телефон', phoneC, keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            _sheetField('Логин', loginC),
            const SizedBox(height: 12),
            _sheetField('Пароль', passC),
            const SizedBox(height: 12),
            _sheetField(
              'PIN',
              pinC,
              keyboardType: TextInputType.number,
              errored: pinErr,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
              onChanged: (_) { if (pinErr) setS(() => pinErr = false); },
            ),
            const SizedBox(height: 12),
            _dropdownField('Должность', role, roleOpts, (v) => setS(() => role = v)),
            const SizedBox(height: 14),
            _checkRow('Заведение', venue, () => setS(() => venue = !venue)),
            const SizedBox(height: 20),
            PrimaryButton(
              'Сохранить',
              onPressed: () async {
                final name = nameC.text.trim();
                if (name.isEmpty) {
                  setS(() => nameErr = true);
                  return;
                }
                final pin = pinC.text;
                // Hash rejimida maydon bo'sh = «PIN o'zgarmasin» (eski hash qoladi).
                final keepOldPin = pin.isEmpty && existing != null && existing.hasPin;
                if (!keepOldPin) {
                  final dup = app.employees.any((x) => x.matchesPin(pin) && x.uid != existing?.uid);
                  if (!RegExp(r'^\d{4}$').hasMatch(pin) || dup) {
                    setS(() => pinErr = true);
                    showToast(ctx, 'PIN — 4 цифры, уникальный для каждого', color: AppColors.warning, bg: AppColors.warningSoft, icon: Icons.warning_amber_rounded);
                    return;
                  }
                }
                final login = loginC.text.trim();
                if (existing != null) {
                  // Mavjud xodim — hujjat maydonlarini yangilash (write-through).
                  existing.name = name;
                  existing.phone = phoneC.text.trim();
                  existing.login = login;
                  if (!keepOldPin) existing.setPin(pin); // salt+hash, ochiq matn tozalanadi
                  existing.role = role;
                  if (app.repo.ready) app.repo.saveEmployee(existing);
                  app.notify();
                  if (ctx.mounted) Navigator.pop(ctx);
                  showToast(context, 'Сотрудник сохранён');
                } else {
                  // Yangi xodim — owner login/parol beradi (Cloud Function: Auth user + doc).
                  if (login.isEmpty || passC.text.length < 6) {
                    showToast(ctx, 'Укажите логин и пароль (мин. 6 символов)', color: AppColors.warning, bg: AppColors.warningSoft, icon: Icons.warning_amber_rounded);
                    return;
                  }
                  try {
                    await app.createEmployee(
                      login: login, password: passC.text, name: name,
                      role: role, phone: phoneC.text.trim(), pin: pin,
                    );
                    if (!ctx.mounted) return;
                    showToast(ctx, 'Сотрудник создан');
                    Navigator.pop(ctx);
                  } catch (_) {
                    if (ctx.mounted) {
                      showToast(ctx, 'Не удалось создать сотрудника (требуется деплой Cloud Functions)', color: AppColors.danger, bg: AppColors.dangerSoft, icon: Icons.error_outline);
                    }
                  }
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ═══════════════════ Должности ═══════════════════
  List<Widget> _positionsList() {
    return [
      Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (int i = 0; i < _positions.length; i++) _positionRow(_positions[i], i != 0),
          ],
        ),
      ),
    ];
  }

  Widget _positionRow(_Position p, bool topBorder) {
    final rightsStr = p.rights.isNotEmpty ? p.rights.join(', ') : 'Без доступа к админке';
    return InkWell(
      onTap: () => _openPositionSheet(p),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          border: Border(top: topBorder ? const BorderSide(color: AppColors.border) : BorderSide.none),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(p.name, style: AppTheme.sans(size: 13.5, weight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                      if (p.locked) ...[
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.bgSecondary, borderRadius: BorderRadius.circular(AppRadius.pill)),
                          child: Text('нельзя изменить', style: AppTheme.sans(size: 10, weight: FontWeight.w600, color: AppColors.textTertiary)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(rightsStr, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text('›', style: AppTheme.sans(size: 16, color: AppColors.textTertiary)),
          ],
        ),
      ),
    );
  }

  void _openPositionSheet(_Position? existing) {
    final nameC = TextEditingController(text: existing?.name ?? '');
    final rateValC = TextEditingController();
    final rights = <String, bool>{
      for (final r in _rightsAll) r: existing == null ? false : (existing.rights.contains('Полный доступ') || existing.rights.contains(r)),
    };
    String rate = 'fix'; // fix / hour / pct
    final locked = existing?.locked ?? false;
    bool nameErr = false;

    String unitOf(String r) => r == 'fix' ? 'сум/мес' : (r == 'hour' ? 'сум/час' : '% от продаж');

    showAppSheet(
      context,
      title: existing == null ? 'Новая должность' : existing.name,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (locked)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.bgSecondary, borderRadius: BorderRadius.circular(AppRadius.pill)),
                      child: Text('нельзя изменить', style: AppTheme.sans(size: 11, weight: FontWeight.w600, color: AppColors.textTertiary)),
                    ),
                  ],
                ),
              ),
            _sheetField('Название', nameC, enabled: !locked, errored: nameErr, onChanged: (_) { if (nameErr) setS(() => nameErr = false); }),
            const SizedBox(height: 14),
            Text('Права доступа', style: AppTheme.sans(size: 11, weight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 0.4)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _rightsAll.map((r) {
                final on = rights[r] ?? false;
                return GestureDetector(
                  onTap: () {
                    if (locked) return;
                    setS(() => rights[r] = !on);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: on ? AppColors.accent : AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: on ? AppColors.accent : AppColors.borderStrong),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (on) ...[
                          const Text('✓', style: TextStyle(fontSize: 12, color: Colors.white, height: 1)),
                          const SizedBox(width: 5),
                        ],
                        Text(r, style: AppTheme.sans(size: 12.5, weight: FontWeight.w600, color: on ? Colors.white : AppColors.textSecondary)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text('Тип ставки', style: AppTheme.sans(size: 11, weight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 0.4)),
            const SizedBox(height: 8),
            _radioRow('Фикс', rate == 'fix', () => setS(() => rate = 'fix')),
            _radioRow('Почасовая', rate == 'hour', () => setS(() => rate = 'hour')),
            _radioRow('% от продаж', rate == 'pct', () => setS(() => rate = 'pct')),
            const SizedBox(height: 12),
            _sheetField('Ставка', rateValC, keyboardType: TextInputType.number, suffixText: unitOf(rate)),
            const SizedBox(height: 20),
            PrimaryButton(
              'Сохранить',
              onPressed: () {
                if (locked) {
                  Navigator.pop(ctx);
                  return;
                }
                final name = nameC.text.trim();
                if (name.isEmpty) {
                  setS(() => nameErr = true);
                  return;
                }
                final selected = _rightsAll.where((r) => rights[r] == true).toList();
                final stored = selected.length == 8 ? ['Полный доступ'] : selected;
                setState(() {
                  if (existing != null) {
                    existing.name = name;
                    existing.rights = stored;
                  } else {
                    _positions.add(_Position(name, stored));
                  }
                });
                Navigator.pop(ctx);
                showToast(context, 'Должность сохранена');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ═══════════════════ Кассы ═══════════════════
  List<Widget> _registersList() {
    final widgets = <Widget>[];
    for (int i = 0; i < _registers.length; i++) {
      if (i != 0) widgets.add(const SizedBox(height: 8));
      widgets.add(_registerCard(_registers[i]));
    }
    return widgets;
  }

  Widget _registerCard(_Register r) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${r.name} · ${context.read<AppState>().company['name']}', style: AppTheme.sans(size: 14, weight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(r.type, style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary)),
          const SizedBox(height: 10),
          const _DashedDivider(),
          const SizedBox(height: 10),
          _kvRow('Логин кассы', Text(r.login, style: AppTheme.sans(size: 12.5, weight: FontWeight.w600))),
          const SizedBox(height: 5),
          _kvRow(
            'Пароль',
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_showPass ? 'kassa•2026' : '••••••••', style: AppTheme.sans(size: 12.5, weight: FontWeight.w600)),
                const SizedBox(width: 7),
                GestureDetector(
                  onTap: () => setState(() => _showPass = !_showPass),
                  behavior: HitTestBehavior.opaque,
                  child: Text(_showPass ? '🙈' : '👁', style: const TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 11),
          _dangerButton('Выход', () {
            _confirm(
              title: 'Разлогинить терминал?',
              desc: 'Касса №1 выйдет из аккаунта — для входа понадобится логин и пароль кассы.',
              label: 'Выйти',
              onOk: () => showToast(context, 'Терминал разлогинен', color: AppColors.textSecondary, bg: AppColors.bgSecondary, icon: Icons.power_settings_new),
            );
          }),
        ],
      ),
    );
  }

  // ═══════════════════ Заведения ═══════════════════
  List<Widget> _venues() {
    return [
      Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.bgSecondary, borderRadius: BorderRadius.circular(12)),
              child: const Text('🏠', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${context.read<AppState>().company['name']}', style: AppTheme.sans(size: 13.5, weight: FontWeight.w600)),
                  const SizedBox(height: 1),
                  Text(
                    (context.read<AppState>().company['address'] as String? ?? '').isEmpty
                        ? 'Адрес не указан'
                        : '${context.read<AppState>().company['address']}',
                    style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => showToast(context, 'Название и адрес меняются в Настройках → Компания', color: AppColors.textSecondary, bg: AppColors.bgSecondary, icon: Icons.edit_outlined),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: AppColors.borderStrong),
                ),
                child: Text('Ред.', style: AppTheme.sans(size: 12, weight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: _openVenues,
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.btn),
            border: Border.all(color: AppColors.borderStrong, style: BorderStyle.solid),
          ),
          child: Text('🏪  Мои заведения', style: AppTheme.sans(size: 13.5, weight: FontWeight.w600, color: AppColors.accentHover)),
        ),
      ),
    ];
  }

  // ═══════════════════ Мои заведения (multi-restoran) ═══════════════════

  /// Restoranlar ro'yxati: joriysi belgilangan, bosib almashtirish + yangi ochish.
  void _openVenues() {
    context.read<AppState>().loadMyCafes(); // eng yangi ro'yxatni yuklaymiz
    showAppSheet(
      context,
      title: 'Мои заведения',
      builder: (ctx) => Consumer<AppState>(
        builder: (ctx, app, _) {
          final cafes = app.myCafes;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'У каждого заведения своя касса, меню, склад и статистика. Оплата за каждое — отдельно (через Google Play).',
                style: AppTheme.sans(size: 12.5, color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 14),
              if (cafes.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: Text('Загрузка…', style: AppTheme.sans(size: 13, color: AppColors.textTertiary))),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: AppColors.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (int i = 0; i < cafes.length; i++)
                        _venueRow(ctx, app, cafes[i], topBorder: i != 0),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              PrimaryButton('Новое заведение', icon: Icons.add, busy: app.switchingCafe,
                  onPressed: app.switchingCafe ? null : () => _createVenueDialog(ctx)),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }

  Widget _venueRow(BuildContext sheetCtx, AppState app, Cafe c, {required bool topBorder}) {
    final isCurrent = c.id == app.currentCafeId;
    final trial = c.subscriptionStatus == 'trial';
    return InkWell(
      onTap: (isCurrent || app.switchingCafe)
          ? null
          : () async {
              final ok = await _confirmSwitch(sheetCtx, c);
              if (ok != true) return;
              final done = await app.switchCafe(c.id);
              if (!mounted) return;
              if (done) {
                Navigator.of(sheetCtx).pop();
                showToast(context, 'Заведение: ${c.name}', icon: Icons.storefront_outlined);
              } else {
                showToast(context, app.authError ?? 'Не удалось переключить',
                    color: AppColors.danger, bg: AppColors.dangerSoft, icon: Icons.error_outline);
              }
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          border: Border(top: topBorder ? const BorderSide(color: AppColors.border) : BorderSide.none),
        ),
        child: Row(
          children: [
            Container(
              width: 38, height: 38, alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isCurrent ? AppColors.accent : AppColors.bgSecondary,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Text('🏪', style: TextStyle(fontSize: 17)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.name, style: AppTheme.sans(size: 14, weight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(children: [
                    if (c.code != null && c.code!.isNotEmpty)
                      Text('Код ${c.code}', style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary)),
                    if (trial) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('Пробный',
                            style: AppTheme.sans(size: 10.5, weight: FontWeight.w600, color: AppColors.accentHover)),
                      ),
                    ],
                  ]),
                ],
              ),
            ),
            if (isCurrent)
              const Icon(Icons.check_circle, color: AppColors.accent, size: 22)
            else
              const Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 22),
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirmSwitch(BuildContext ctx, Cafe c) {
    return showDialog<bool>(
      context: ctx,
      builder: (d) => AlertDialog(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Переключить заведение?', style: AppTheme.serif(size: 18, weight: FontWeight.w700)),
        content: Text('Открыть «${c.name}». Касса, меню, склад и статистика сменятся на это заведение.',
            style: AppTheme.sans(size: 13.5, color: AppColors.textSecondary, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false),
              child: Text('Отмена', style: AppTheme.sans(size: 14, color: AppColors.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(d, true),
              child: Text('Переключить', style: AppTheme.sans(size: 14, weight: FontWeight.w700, color: AppColors.accentHover))),
        ],
      ),
    );
  }

  void _createVenueDialog(BuildContext sheetCtx) {
    final ctrl = TextEditingController();
    showDialog(
      context: sheetCtx,
      builder: (d) => AlertDialog(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Новое заведение', style: AppTheme.serif(size: 18, weight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Создаст отдельное заведение с чистой кассой, меню и складом. Пробный период — 14 дней.',
                style: AppTheme.sans(size: 12.5, color: AppColors.textSecondary, height: 1.4)),
            const SizedBox(height: 12),
            LabeledField(label: 'Название', controller: ctrl, hint: 'Например: Чайхана «Центр»'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d),
              child: Text('Отмена', style: AppTheme.sans(size: 14, color: AppColors.textSecondary))),
          TextButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(d); // dialog yopiladi
              final app = context.read<AppState>();
              final id = await app.createRestaurant(name);
              if (!mounted) return;
              if (id != null) {
                Navigator.of(sheetCtx).pop(); // sheet yopiladi — yangi cafega o'tildi
                showToast(context, 'Заведение «$name» создано', icon: Icons.storefront_outlined);
              } else {
                showToast(context, app.authError ?? 'Ошибка',
                    color: AppColors.danger, bg: AppColors.dangerSoft, icon: Icons.error_outline);
              }
            },
            child: Text('Создать', style: AppTheme.sans(size: 14, weight: FontWeight.w700, color: AppColors.accentHover)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════ Сессии ═══════════════════
  List<Widget> _sessionsList() {
    return [
      Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (int i = 0; i < _sessions.length; i++) _sessionRow(_sessions[i], i != 0),
          ],
        ),
      ),
      const SizedBox(height: 8),
      _dangerButton('Завершить все сессии', () {
        _confirm(
          title: 'Завершить все сессии?',
          desc: 'Все устройства, кроме текущего, будут разлогинены.',
          label: 'Завершить все',
          onOk: () {
            setState(() {
              final first = _sessions.first;
              _sessions
                ..clear()
                ..add(first);
            });
            showToast(context, 'Все сессии завершены', color: AppColors.danger, bg: AppColors.dangerSoft, icon: Icons.lock_outline);
          },
        );
      }, height: 46),
    ];
  }

  Widget _sessionRow(_Session s, bool topBorder) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        border: Border(top: topBorder ? const BorderSide(color: AppColors.border) : BorderSide.none),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(s.user, style: AppTheme.sans(size: 13, weight: FontWeight.w600))),
              const SizedBox(width: 8),
              Text(s.time, style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary)),
            ],
          ),
          const SizedBox(height: 2),
          Text('${s.device} · ${s.browser} · IP ${s.ip}', style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary)),
        ],
      ),
    );
  }

  // ═══════════════════ Интеграции ═══════════════════
  List<Widget> _integrations() {
    return [
      Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ключи доступа интеграций', style: AppTheme.sans(size: 14, weight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'API-токены дают внешним приложениям доступ к меню, чекам и складу. Храните их в секрете.',
              style: AppTheme.sans(size: 12, color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => showToast(context, 'Документация API — dev.joinposter.com', color: AppColors.info, bg: AppColors.bgSecondary, icon: Icons.menu_book_outlined),
              child: Text('Документация →', style: AppTheme.sans(size: 12.5, weight: FontWeight.w600, color: AppColors.accentHover)),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            if (_tokens.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
                child: Text('Токенов пока нет', style: AppTheme.sans(size: 12.5, color: AppColors.textTertiary)),
              )
            else
              for (int i = 0; i < _tokens.length; i++) _tokenRow(_tokens[i], i != 0),
          ],
        ),
      ),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: () {
          setState(() {
            _tokens.add(_Token(
              id: 'tk${DateTime.now().millisecondsSinceEpoch}',
              app: 'Моя интеграция',
              emp: 'Жафар Алитураев',
              token: 'pos_live_${_randToken()}',
              date: '05.07.2026',
            ));
          });
          showToast(context, 'Токен создан — скопируйте его значение', color: AppColors.accentHover, bg: AppColors.accentSoft, icon: Icons.vpn_key_outlined);
        },
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(AppRadius.btn)),
          child: Text('🔑 Создать токен', style: AppTheme.sans(size: 13.5, weight: FontWeight.w600, color: Colors.white)),
        ),
      ),
    ];
  }

  Widget _tokenRow(_Token t, bool topBorder) {
    final revealed = _showTok.contains(t.id);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        border: Border(top: topBorder ? const BorderSide(color: AppColors.border) : BorderSide.none),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(t.app, style: AppTheme.sans(size: 13, weight: FontWeight.w600))),
              const SizedBox(width: 8),
              Text(t.date, style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(t.emp, style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary)),
              const Spacer(),
              Flexible(
                child: Text(
                  revealed ? t.token : '••••••••••••',
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.sans(size: 11.5, color: AppColors.textSecondary).copyWith(fontFamily: 'monospace', fontFamilyFallback: const ['Courier']),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => revealed ? _showTok.remove(t.id) : _showTok.add(t.id)),
                behavior: HitTestBehavior.opaque,
                child: Text(revealed ? '🙈' : '👁', style: const TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _randToken() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final now = DateTime.now().microsecondsSinceEpoch;
    final buf = StringBuffer();
    var seed = now;
    for (int i = 0; i < 12; i++) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      buf.write(chars[seed % chars.length]);
    }
    return buf.toString();
  }

  // ═══════════════════ Umumiy yordamchilar ═══════════════════

  Widget _iconTap({required String emoji, required VoidCallback onTap, Color? activeBg}) {
    return _EmojiIconButton(emoji: emoji, onTap: onTap, activeBg: activeBg);
  }

  Widget _kvRow(String label, Widget value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: AppTheme.sans(size: 12.5, color: AppColors.textTertiary)),
        value,
      ],
    );
  }

  Widget _dangerButton(String label, VoidCallback onTap, {double height = 40}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: BorderRadius.circular(AppRadius.btn)),
        child: Text(label, style: AppTheme.sans(size: height >= 46 ? 13.5 : 13, weight: FontWeight.w600, color: AppColors.danger)),
      ),
    );
  }

  // Sheet ichidagi label+input (LabeledField dizayn tili bilan, error border qo'llab-quvvatlaydi)
  Widget _sheetField(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
    bool errored = false,
    bool enabled = true,
    String? suffixText,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
  }) {
    final borderColor = errored ? AppColors.danger : AppColors.borderStrong;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.sans(size: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          enabled: enabled,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          style: AppTheme.sans(size: 15),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: enabled ? AppColors.surface : AppColors.bgSecondary,
            suffixText: suffixText,
            suffixStyle: AppTheme.sans(size: 12.5, color: AppColors.textTertiary),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.input), borderSide: BorderSide(color: borderColor)),
            disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.input), borderSide: const BorderSide(color: AppColors.border)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.input), borderSide: BorderSide(color: borderColor)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.input), borderSide: BorderSide(color: errored ? AppColors.danger : AppColors.accent, width: 2)),
          ),
        ),
      ],
    );
  }

  Widget _dropdownField(String label, String value, List<String> opts, ValueChanged<String> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.sans(size: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.input),
            border: Border.all(color: AppColors.borderStrong),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
              style: AppTheme.sans(size: 15, color: AppColors.text),
              items: opts.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
              onChanged: (v) => onChanged(v ?? value),
            ),
          ),
        ),
      ],
    );
  }

  Widget _checkRow(String label, bool on, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? AppColors.accent : AppColors.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: on ? AppColors.accent : AppColors.borderStrong),
            ),
            child: on ? const Text('✓', style: TextStyle(fontSize: 13, color: Colors.white, height: 1)) : null,
          ),
          const SizedBox(width: 10),
          Text(label, style: AppTheme.sans(size: 13.5, weight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _radioRow(String label, bool on, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: on ? AppColors.accent : AppColors.borderStrong, width: 2),
              ),
              child: Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: on ? AppColors.accent : Colors.transparent),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(label, style: AppTheme.sans(size: 13.5, weight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // Tasdiqlash choyshabi (confirm sheet)
  void _confirm({required String title, required String desc, required String label, required VoidCallback onOk}) {
    showAppSheet(
      context,
      title: title,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(desc, style: AppTheme.sans(size: 13.5, color: AppColors.textSecondary, height: 1.5)),
          const SizedBox(height: 20),
          PrimaryButton(
            label,
            color: AppColors.danger,
            onPressed: () {
              Navigator.pop(ctx);
              onOk();
            },
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SecondaryButton('Отмена', expand: true, onPressed: () => Navigator.pop(ctx)),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// Bosilganda danger-soft fon beradigan emoji tugma (🗑).
class _EmojiIconButton extends StatefulWidget {
  final String emoji;
  final VoidCallback onTap;
  final Color? activeBg;
  const _EmojiIconButton({required this.emoji, required this.onTap, this.activeBg});
  @override
  State<_EmojiIconButton> createState() => _EmojiIconButtonState();
}

class _EmojiIconButtonState extends State<_EmojiIconButton> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _down ? (widget.activeBg ?? AppColors.surfaceHover) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(widget.emoji, style: const TextStyle(fontSize: 13)),
      ),
    );
  }
}

// Chiziqli (dashed) ajratuvchi.
class _DashedDivider extends StatelessWidget {
  const _DashedDivider();
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const dashW = 4.0;
        const gap = 3.0;
        final count = (c.maxWidth / (dashW + gap)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            count,
            (_) => Container(width: dashW, height: 1, color: AppColors.border),
          ),
        );
      },
    );
  }
}
