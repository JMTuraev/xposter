import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../theme.dart';
import '../../state/app_state.dart';
import '../../widgets/ui.dart';

/// Login / Register ekrani — ilova darajasidagi kirish (Firebase Auth).
/// Kassa qulflanган bo'lsa (isLocked) — PIN bilan tez qaytish ko'rsatiladi.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _view = 'login'; // login | pin | register | staff

  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _obscure = true;

  // Xodim kirishi (login + код заведения + пароль)
  final _sLogin = TextEditingController();
  final _sCode = TextEditingController();
  final _sPass = TextEditingController();
  bool _sObscure = true;

  final _rCompany = TextEditingController();
  final _rOwner = TextEditingController();
  final _rEmail = TextEditingController();
  final _rPass = TextEditingController();
  final _rPin = TextEditingController();
  bool _rObscure = true;

  String _pin = '';
  bool _pinError = false;

  static final _emailRe = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

  @override
  void initState() {
    super.initState();
    // Kassa qulflangan (Firebase sessiya bor) — PIN ekrani bilan boshlaymiz.
    final app = context.read<AppState>();
    if (app.isLocked && app.employees.any((e) => e.pin.isNotEmpty)) _view = 'pin';
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _sLogin.dispose();
    _sCode.dispose();
    _sPass.dispose();
    _rCompany.dispose();
    _rOwner.dispose();
    _rEmail.dispose();
    _rPass.dispose();
    _rPin.dispose();
    super.dispose();
  }

  void _err(String msg) =>
      showToast(context, msg, color: AppColors.danger, bg: AppColors.dangerSoft, icon: Icons.error_outline);

  Future<void> _doLogin() async {
    FocusScope.of(context).unfocus();
    final app = context.read<AppState>();
    if (app.authBusy) return;
    if (_email.text.trim().isEmpty) { _err('Введите e-mail'); return; }
    if (!_emailRe.hasMatch(_email.text.trim())) { _err('Неверный формат e-mail'); return; }
    if (_pass.text.isEmpty) { _err('Введите пароль'); return; }
    final name = await app.loginByEmail(_email.text, _pass.text);
    if (name == null && mounted) _err(app.authError ?? 'Ошибка входа');
  }

  Future<void> _forgotPassword() async {
    final app = context.read<AppState>();
    final c = TextEditingController(text: _email.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Восстановление пароля', style: AppTheme.serif(size: 19, weight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Отправим ссылку для сброса пароля на ваш e-mail.',
              style: AppTheme.sans(size: 13.5, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          LabeledField(label: 'E-mail', controller: c, keyboardType: TextInputType.emailAddress, hint: 'you@example.com'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Отмена', style: AppTheme.sans(size: 14, color: AppColors.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: Text('Отправить', style: AppTheme.sans(size: 14, weight: FontWeight.w700, color: AppColors.accentHover))),
        ],
      ),
    );
    if (email == null || !mounted) return;
    if (!_emailRe.hasMatch(email)) { _err('Неверный формат e-mail'); return; }
    final res = await app.resetPassword(email);
    if (!mounted) return;
    if (res == null) {
      showToast(context, 'Письмо отправлено на $email', icon: Icons.mark_email_read_outlined);
    } else {
      _err(res);
    }
  }

  void _pressPin(String d) {
    if (_pinError || _pin.length >= 4) return;
    setState(() => _pin += d);
    if (_pin.length == 4) Future.delayed(const Duration(milliseconds: 150), _submitPin);
  }

  void _delPin() => setState(() => _pin = _pin.isEmpty ? _pin : _pin.substring(0, _pin.length - 1));

  void _submitPin() {
    final app = context.read<AppState>();
    final name = app.loginByPin(_pin);
    if (name == null && mounted) {
      setState(() => _pinError = true);
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) setState(() { _pin = ''; _pinError = false; });
      });
    }
  }

  Future<void> _doStaffLogin() async {
    FocusScope.of(context).unfocus();
    final app = context.read<AppState>();
    if (app.authBusy) return;
    if (_sLogin.text.trim().isEmpty) { _err('Введите логин'); return; }
    if (!RegExp(r'^\d{6}$').hasMatch(_sCode.text.trim())) { _err('Код заведения — 6 цифр'); return; }
    if (_sPass.text.isEmpty) { _err('Введите пароль'); return; }
    final name = await app.loginByStaffCode(_sLogin.text, _sCode.text, _sPass.text);
    if (name == null && mounted) _err(app.authError ?? 'Ошибка входа');
  }

  Future<void> _doRegister() async {
    FocusScope.of(context).unfocus();
    final app = context.read<AppState>();
    if (app.authBusy) return;
    if (_rCompany.text.trim().isEmpty) { _err('Укажите название заведения'); return; }
    if (_rOwner.text.trim().isEmpty) { _err('Укажите имя владельца'); return; }
    if (!_emailRe.hasMatch(_rEmail.text.trim())) { _err('Неверный формат e-mail'); return; }
    if (_rPass.text.length < 6) { _err('Пароль — минимум 6 символов'); return; }
    final pin = _rPin.text.trim();
    if (pin.isNotEmpty && !RegExp(r'^\d{4}$').hasMatch(pin)) { _err('PIN — ровно 4 цифры'); return; }
    final name = await app.register(
      company: _rCompany.text.trim(),
      owner: _rOwner.text.trim(),
      email: _rEmail.text.trim(),
      password: _rPass.text,
      pin: pin.isEmpty ? '0000' : pin,
    );
    if (!mounted) return;
    if (name == null) {
      _err(app.authError ?? 'Ошибка регистрации');
    } else {
      showToast(context, 'Аккаунт создан. Подтвердите e-mail: письмо отправлено на ${_rEmail.text.trim()}',
          color: AppColors.accent, bg: AppColors.bgSecondary, icon: Icons.mark_email_read_outlined);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo
                  Container(
                    width: 62, height: 62,
                    decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(18)),
                    alignment: Alignment.center,
                    child: Text('X', style: AppTheme.serif(size: 30, weight: FontWeight.w700, color: Colors.white)),
                  ),
                  const SizedBox(height: 12),
                  Text('Xposter', style: AppTheme.serif(size: 24, weight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text('Больше, чем просто касса', style: AppTheme.sans(size: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 24),
                  if (_view == 'login') _loginView(app),
                  if (_view == 'pin') _pinView(app),
                  if (_view == 'register') _registerView(app),
                  if (_view == 'staff') _staffView(app),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Login (логин/пароль) ──
  Widget _loginView(AppState app) {
    return Column(children: [
      LabeledField(label: 'Логин (e-mail)', controller: _email, keyboardType: TextInputType.emailAddress, hint: 'you@example.com'),
      const SizedBox(height: 12),
      _passwordField(),
      const SizedBox(height: 6),
      Align(
        alignment: Alignment.centerRight,
        child: GestureDetector(
          onTap: _forgotPassword,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text('Забыли пароль?', style: AppTheme.sans(size: 13, weight: FontWeight.w600, color: AppColors.accentHover)),
          ),
        ),
      ),
      const SizedBox(height: 10),
      PrimaryButton('Войти', icon: Icons.login, busy: app.authBusy, onPressed: _doLogin),
      if (app.isLocked && app.employees.any((e) => e.pin.isNotEmpty)) ...[
        const SizedBox(height: 10),
        SecondaryButton('Войти по PIN', icon: Icons.dialpad, expand: true, onPressed: () => setState(() => _view = 'pin')),
      ],
      const SizedBox(height: 10),
      SecondaryButton('Я сотрудник — войти по коду', icon: Icons.badge_outlined, expand: true,
          onPressed: app.authBusy ? null : () => setState(() => _view = 'staff')),
      const SizedBox(height: 14),
      GestureDetector(
        onTap: app.authBusy ? null : () => setState(() => _view = 'register'),
        child: RichText(text: TextSpan(children: [
          TextSpan(text: 'Нет аккаунта? ', style: AppTheme.sans(size: 13, color: AppColors.textSecondary)),
          TextSpan(text: 'Регистрация', style: AppTheme.sans(size: 13, weight: FontWeight.w700, color: AppColors.accentHover)),
        ])),
      ),
    ]);
  }

  // ── Xodim kirishi ──
  Widget _staffView(AppState app) {
    return Column(children: [
      Text('Вход для сотрудников', style: AppTheme.sans(size: 14, weight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text('Логин, пароль и код заведения выдаёт владелец\n(Ещё → Сотрудники)',
          textAlign: TextAlign.center,
          style: AppTheme.sans(size: 12, color: AppColors.textTertiary, height: 1.4)),
      const SizedBox(height: 14),
      LabeledField(label: 'Логин', controller: _sLogin, hint: 'например: aziz'),
      const SizedBox(height: 12),
      LabeledField(
        label: 'Код заведения (6 цифр)', controller: _sCode,
        keyboardType: TextInputType.number, hint: '123456',
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
      ),
      const SizedBox(height: 12),
      LabeledField(
        label: 'Пароль', controller: _sPass, obscure: _sObscure,
        suffix: IconButton(
          icon: Icon(_sObscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 19, color: AppColors.textSecondary),
          onPressed: () => setState(() => _sObscure = !_sObscure),
        ),
      ),
      const SizedBox(height: 18),
      PrimaryButton('Войти', icon: Icons.login, busy: app.authBusy, onPressed: _doStaffLogin),
      const SizedBox(height: 12),
      SecondaryButton('‹ Вход для владельца', onPressed: app.authBusy ? null : () => setState(() => _view = 'login')),
    ]);
  }

  Widget _passwordField() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Пароль', style: AppTheme.sans(size: 13, color: AppColors.textSecondary)),
      const SizedBox(height: 6),
      TextField(
        controller: _pass,
        obscureText: _obscure,
        style: AppTheme.sans(size: 15),
        onSubmitted: (_) => _doLogin(),
        decoration: InputDecoration(
          hintText: '••••••',
          isDense: true,
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          hintStyle: AppTheme.sans(size: 15, color: AppColors.textTertiary),
          suffixIcon: IconButton(
            icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 19, color: AppColors.textSecondary),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.input), borderSide: const BorderSide(color: AppColors.borderStrong)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.input), borderSide: const BorderSide(color: AppColors.borderStrong)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.input), borderSide: const BorderSide(color: AppColors.accent, width: 2)),
        ),
      ),
    ]);
  }

  // ── PIN (faqat kassa qulflanган holatda) ──
  Widget _pinView(AppState app) {
    final who = app.company['name']?.toString() ?? '';
    return Column(children: [
      Text('Введите PIN-код', style: AppTheme.sans(size: 14, weight: FontWeight.w600)),
      if (who.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(who, style: AppTheme.sans(size: 12.5, color: AppColors.textTertiary)),
      ],
      const SizedBox(height: 16),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (i) {
          final filled = i < _pin.length;
          final fill = _pinError ? AppColors.danger : AppColors.accent;
          final border = _pinError ? AppColors.danger : (filled ? AppColors.accent : AppColors.borderStrong);
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            width: 14, height: 14,
            decoration: BoxDecoration(color: filled ? fill : Colors.transparent, shape: BoxShape.circle, border: Border.all(color: border, width: 1.5)),
          );
        }),
      ),
      SizedBox(
        height: 24,
        child: _pinError
            ? Center(child: Text('Неверный PIN', style: AppTheme.sans(size: 12.5, weight: FontWeight.w600, color: AppColors.danger)))
            : null,
      ),
      _keypad(),
      const SizedBox(height: 12),
      SecondaryButton('Войти по e-mail', onPressed: () => setState(() { _view = 'login'; _pin = ''; _pinError = false; })),
    ]);
  }

  Widget _keypad() {
    Widget key({String? label, VoidCallback? onTap, Widget? child}) => SizedBox(
          width: 74, height: 58,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap ??
                () {
                  HapticFeedback.selectionClick();
                  _pressPin(label!);
                },
            child: Center(child: child ?? Text(label!, style: AppTheme.sans(size: 23, weight: FontWeight.w600))),
          ),
        );
    Widget row(List<Widget> ch) => Row(mainAxisAlignment: MainAxisAlignment.center, children: ch);
    return Column(children: [
      row([key(label: '1'), key(label: '2'), key(label: '3')]),
      row([key(label: '4'), key(label: '5'), key(label: '6')]),
      row([key(label: '7'), key(label: '8'), key(label: '9')]),
      row([
        key(onTap: () {}, child: const SizedBox()),
        key(label: '0'),
        key(onTap: _delPin, child: const Icon(Icons.backspace_outlined, size: 21, color: AppColors.textSecondary)),
      ]),
    ]);
  }

  // ── Register ──
  Widget _registerView(AppState app) {
    return Column(children: [
      LabeledField(label: 'Название заведения *', controller: _rCompany, hint: 'Например: Чайхана «Бухоро»'),
      const SizedBox(height: 12),
      LabeledField(label: 'Имя владельца *', controller: _rOwner, hint: 'Ваше имя'),
      const SizedBox(height: 12),
      LabeledField(label: 'E-mail *', controller: _rEmail, keyboardType: TextInputType.emailAddress, hint: 'you@example.com'),
      const SizedBox(height: 12),
      LabeledField(
        label: 'Пароль *', controller: _rPass, hint: 'Минимум 6 символов', obscure: _rObscure,
        suffix: IconButton(
          icon: Icon(_rObscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 19, color: AppColors.textSecondary),
          onPressed: () => setState(() => _rObscure = !_rObscure),
        ),
      ),
      const SizedBox(height: 12),
      LabeledField(label: 'PIN для кассы (4 цифры, можно позже)', controller: _rPin, keyboardType: TextInputType.number, hint: 'Например: 2580',
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)]),
      const SizedBox(height: 18),
      PrimaryButton('Зарегистрироваться', icon: Icons.person_add_alt, busy: app.authBusy, onPressed: _doRegister),
      const SizedBox(height: 12),
      SecondaryButton('‹ У меня уже есть аккаунт', onPressed: app.authBusy ? null : () => setState(() => _view = 'login')),
      const SizedBox(height: 8),
    ]);
  }
}
