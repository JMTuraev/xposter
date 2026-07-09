import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../state/app_state.dart';
import '../widgets/ui.dart';
import 'home_screen.dart';
import 'more_screen.dart';
import 'kassa/kassa_screen.dart';
import 'menu/menu_screen.dart';
import 'sklad/sklad_screen.dart';

/// Trial banner + pastki 5-tab navigatsiya.
class RootScaffold extends StatefulWidget {
  const RootScaffold({super.key});
  @override
  State<RootScaffold> createState() => RootScaffoldState();
}

class RootScaffoldState extends State<RootScaffold> {
  int _index = 0;

  // Har tab uchun ruxsat kaliti (RBAC). Ещё — hamma uchun (ichi filtrlanadi).
  static const _tabs = [
    (emoji: '🏠', label: 'Главная', size: 17.0, perm: 'home'),
    (emoji: '🛒', label: 'Касса', size: 17.0, perm: 'kassa'),
    (emoji: '📋', label: 'Меню', size: 17.0, perm: 'menu'),
    (emoji: '📦', label: 'Склад', size: 17.0, perm: 'sklad'),
    (emoji: '⋯', label: 'Ещё', size: 22.0, perm: 'home'),
  ];

  void goTo(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final screens = [
      HomeScreen(onNavigate: goTo),
      const KassaScreen(),
      const MenuScreen(),
      const SkladScreen(),
      MoreScreen(onNavigate: goTo),
    ];

    // Ruxsat berilgan tab indekslari (IndexedStack indekslari o'zgarmaydi).
    final visible = <int>[for (int i = 0; i < _tabs.length; i++) if (app.can(_tabs[i].perm)) i];
    // Joriy tab yopiq bo'lib qolsa — birinchi ruxsatli tabga o'tamiz.
    if (visible.isNotEmpty && !visible.contains(_index)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _index = visible.first);
      });
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (app.trialBannerVisible && _index != 1 && app.trialDaysLeft != null) _TrialBanner(app: app, onPay: () => goTo(4)),
            Expanded(child: IndexedStack(index: _index, children: screens)),
          ],
        ),
      ),
      bottomNavigationBar: _TabBar(index: _index, visible: visible, onTap: goTo),
    );
  }
}

class _TrialBanner extends StatelessWidget {
  final AppState app;
  final VoidCallback onPay;
  const _TrialBanner({required this.app, required this.onPay});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 2, 12, 6),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEFE0C4)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      child: Row(children: [
        const Text('⏳', style: TextStyle(fontSize: 13)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
              (app.trialDaysLeft ?? 0) > 0
                  ? 'Пробный период до ${app.trialEndsAtLabel}.'
                  : 'Пробный период истёк.',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: AppTheme.sans(size: 12.5, color: AppColors.text)),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () {
            onPay();
            showToast(context, 'Откройте «Подписка» — оплата картой', color: AppColors.warning, bg: AppColors.warningSoft, icon: Icons.credit_card);
          },
          child: Text('Оплатить',
              style: AppTheme.sans(size: 12.5, weight: FontWeight.w600, color: AppColors.accentHover)
                  .copyWith(decoration: TextDecoration.underline, decorationColor: AppColors.accentHover)),
        ),
        const Spacer(),
        GestureDetector(
          onTap: app.hideTrialBanner,
          child: const SizedBox(width: 28, height: 28, child: Icon(Icons.close, size: 14, color: AppColors.textTertiary)),
        ),
      ]),
    );
  }
}

class _TabBar extends StatelessWidget {
  final int index;
  final List<int> visible;
  final ValueChanged<int> onTap;
  const _TabBar({required this.index, required this.visible, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgSecondary,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(visible.length, (vi) {
              final i = visible[vi];
              final t = RootScaffoldState._tabs[i];
              final active = i == index;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 44, height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: active ? AppColors.accentSoft : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Opacity(
                          opacity: active ? 1 : 0.55,
                          child: Text(t.emoji, style: TextStyle(fontSize: t.size)),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(t.label, style: AppTheme.sans(size: 10, weight: active ? FontWeight.w700 : FontWeight.w500, color: active ? AppColors.accentHover : AppColors.textTertiary)),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
