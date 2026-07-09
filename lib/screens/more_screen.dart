import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../state/app_state.dart';
import '../widgets/ui.dart';
import 'stats/stats_screen.dart';
import 'finance/finance_screen.dart';
import 'marketing/marketing_screen.dart';
import 'employees/employees_screen.dart';
import 'settings/settings_screen.dart';
import 'subscription/subscription_screen.dart';
import 'apps/apps_screen.dart';

/// Ещё (More) — hub. App-bar (title «Ещё» + bell) home_screen tomonidan beriladi.
class MoreScreen extends StatelessWidget {
  final ValueChanged<int> onNavigate;
  const MoreScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final u = app.currentUser;
    final venueName = app.company['name'] as String;

    final accCount = app.accounts.length;
    final clientCount = app.clients.length;
    final activePromos = app.promotionsList.where((p) => p['active'] == true).length;
    final empCount = app.employees.length;
    final trialDays = app.trialDaysLeft;
    final trialLabel = trialDays == null ? null : '$trialDays ${_plural(trialDays, 'день', 'дня', 'дней')}';

    final business = <_Row>[
      _Row('📊', 'Статистика', '8 отчётов и ABC-анализ', const StatsScreen(), perm: 'stats'),
      _Row('💰', 'Финансы', '$accCount ${_plural(accCount, 'счёт', 'счёта', 'счетов')} · P&L', const FinanceScreen(), perm: 'finance'),
      _Row('🎯', 'Маркетинг', '$clientCount ${_plural(clientCount, 'клиент', 'клиента', 'клиентов')} · $activePromos ${_plural(activePromos, 'акция', 'акции', 'акций')}', const MarketingScreen(), perm: 'marketing'),
      _Row('👥', 'Сотрудники', '$empCount ${_plural(empCount, 'сотрудник', 'сотрудника', 'сотрудников')} · 1 касса', const EmployeesScreen(), perm: 'employees'),
    ].where((r) => app.can(r.perm)).toList();
    final system = <_Row>[
      _Row('⚙️', 'Настройки', venueName, const SettingsScreen(), perm: 'settings'),
      _Row('💳', 'Подписка', trialLabel == null ? 'Тариф Mini' : 'Mini · $trialLabel триала', const SubscriptionScreen(), chip: trialLabel, perm: 'subscription'),
      _Row('🧩', 'Приложения', '8 в каталоге', const AppsScreen(), perm: 'apps'),
    ].where((r) => app.can(r.perm)).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 30),
      children: [
        // ── Профиль ──
        InkWell(
          onTap: () => _editProfile(context, app),
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Container(
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.card), border: Border.all(color: AppColors.border)),
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 52, height: 52,
                decoration: const BoxDecoration(color: AppColors.accentSoft, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(u.initials, style: AppTheme.serif(size: 19, weight: FontWeight.w700, color: AppColors.accentHover)),
              ),
              const SizedBox(width: 13),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(u.name, style: AppTheme.sans(size: 16, weight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('${u.role} · $venueName', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(size: 12.5, color: AppColors.textSecondary)),
              ])),
              const Text('›', style: TextStyle(fontSize: 17, color: AppColors.textTertiary)),
            ]),
          ),
        ),
        const SizedBox(height: 14),

        if (business.isNotEmpty) ...[_group('Бизнес', business, context), const SizedBox(height: 14)],
        if (system.isNotEmpty) ...[_group('Система', system, context), const SizedBox(height: 14)],

        // ── Выйти ──
        InkWell(
          onTap: () => _logout(context),
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Container(
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.card), border: Border.all(color: AppColors.border)),
            padding: const EdgeInsets.all(13),
            alignment: Alignment.center,
            child: Text('Выйти', style: AppTheme.sans(size: 14.5, weight: FontWeight.w600, color: AppColors.danger)),
          ),
        ),
        const SizedBox(height: 14),
        // DIQQAT: pubspec.yaml dagi `version:` bilan bir xil bo'lsin.
        Center(child: Text('Xposter · v1.0.3', style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary))),
      ],
    );
  }

  Widget _group(String title, List<_Row> rows, BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 6, bottom: 8),
        child: Text(title.toUpperCase(), style: AppTheme.sans(size: 11, weight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 0.9)),
      ),
      Container(
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.card), border: Border.all(color: AppColors.border)),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.border),
            _tile(context, rows[i]),
          ],
        ]),
      ),
    ]);
  }

  Widget _tile(BuildContext context, _Row r) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => r.screen)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: AppColors.bgSecondary, borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: Text(r.emoji, style: const TextStyle(fontSize: 17)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.label, style: AppTheme.sans(size: 14.5, weight: FontWeight.w500)),
            const SizedBox(height: 1),
            Text(r.sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary)),
          ])),
          if (r.chip != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppColors.warningSoft, borderRadius: BorderRadius.circular(999)),
              child: Text(r.chip!, style: AppTheme.sans(size: 11, weight: FontWeight.w700, color: AppColors.warning)),
            ),
            const SizedBox(width: 8),
          ],
          const Text('›', style: TextStyle(fontSize: 17, color: AppColors.textTertiary)),
        ]),
      ),
    );
  }

  void _editProfile(BuildContext context, AppState app) {
    final name = TextEditingController(text: app.currentUser.name);
    final phone = TextEditingController(text: app.currentUser.phone);
    showAppSheet(context, title: 'Профиль', builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LabeledField(label: 'Имя', controller: name),
      const SizedBox(height: 12),
      LabeledField(label: 'Телефон', controller: phone, keyboardType: TextInputType.phone),
      const SizedBox(height: 18),
      PrimaryButton('Сохранить', onPressed: () {
        if (name.text.trim().isNotEmpty) app.currentUser.name = name.text.trim();
        if (phone.text.trim().isNotEmpty) app.currentUser.phone = phone.text.trim();
        if (app.repo.ready) app.repo.saveEmployee(app.currentUser);
        app.notify();
        Navigator.pop(ctx);
        showToast(context, 'Профиль обновлён');
      }),
      const SizedBox(height: 8),
    ]));
  }

  void _logout(BuildContext context) {
    showAppSheet(context, title: 'Выход', builder: (ctx) => Column(children: [
      const Text('👋', style: TextStyle(fontSize: 38)),
      const SizedBox(height: 6),
      Text('Выйти из аккаунта?', textAlign: TextAlign.center, style: AppTheme.serif(size: 20, weight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text('Вы вернётесь на экран входа. Данные смены сохранятся.', textAlign: TextAlign.center, style: AppTheme.sans(size: 13.5, color: AppColors.textSecondary, height: 1.5)),
      const SizedBox(height: 18),
      PrimaryButton('Выйти', color: AppColors.danger, onPressed: () {
        Navigator.pop(ctx);
        context.read<AppState>().logout(); // haqiqiy chiqish → Login ekran
      }),
      const SizedBox(height: 10),
      SecondaryButton('Отмена', expand: true, onPressed: () => Navigator.pop(ctx)),
      const SizedBox(height: 8),
    ]));
  }
}

class _Row {
  final String emoji, label, sub;
  final Widget screen;
  final String? chip;
  final String perm;
  _Row(this.emoji, this.label, this.sub, this.screen, {this.chip, this.perm = 'home'});
}

String _plural(int n, String one, String few, String many) {
  final a = n % 10, b = n % 100;
  if (a == 1 && b != 11) return one;
  if (a >= 2 && a <= 4 && (b < 10 || b >= 20)) return few;
  return many;
}
