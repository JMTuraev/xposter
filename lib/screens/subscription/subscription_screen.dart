import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme.dart';
import '../../state/app_state.dart';
import '../../widgets/ui.dart';

/// Подписка ekrani — prototip `isSubp` blokiga 1:1 mos.
/// 4 chip (Счета / Подписки / Платежи / Настройки), tariflarni solishtirish,
/// karta orqali to'lov sheet'i. `paid` — mahalliy holat (default false).
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});
  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  // Faol chip: inv | subs | pays | set
  String _tab = 'inv';
  // To'lov holati — prototip subUI.paid ga mos (mahalliy).
  bool _paid = false;

  static const _chips = [
    ['inv', 'Счета'],
    ['subs', 'Подписки'],
    ['pays', 'Платежи'],
    ['set', 'Настройки'],
  ];

  /// ru pluralization — prototip `plural(n, one, few, many)` bilan bir xil.
  String _plural(int n, String one, String few, String many) {
    final a = n % 10, b = n % 100;
    if (a == 1 && b != 11) return one;
    if (a >= 2 && a <= 4 && (b < 10 || b >= 20)) return few;
    return many;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final trialDays = app.trialDaysLeft ?? 0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _appBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
        children: [
          _headerCard(trialDays),
          const SizedBox(height: 10),
          _chipRow(),
          const SizedBox(height: 10),
          if (_tab == 'inv') ..._invoiceTab(app),
          if (_tab == 'subs') _subsTab(),
          if (_tab == 'pays') _paysTab(),
          if (_tab == 'set') _settingsTab(),
        ],
      ),
    );
  }

  // ─────────────────────────── App-bar ───────────────────────────
  PreferredSizeWidget _appBar() {
    return AppBar(
      backgroundColor: AppColors.bg,
      elevation: 0,
      centerTitle: true,
      titleSpacing: 0,
      automaticallyImplyLeading: false,
      title: Text('Подписка', style: AppTheme.sans(size: 17, weight: FontWeight.w600)),
      leadingWidth: 92,
      leading: InkWell(
        onTap: () => Navigator.pop(context),
        child: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('‹', style: AppTheme.sans(size: 20, color: AppColors.accentHover)),
              const SizedBox(width: 3),
              Text('Ещё', style: AppTheme.sans(size: 14.5, weight: FontWeight.w600, color: AppColors.accentHover)),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────── Header plan card ────────────────────────
  Widget _headerCard(int trialDays) {
    final frac = ((1 - trialDays / 14).clamp(0.0, 1.0)).toDouble();
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('Mini', style: AppTheme.serif(size: 19, weight: FontWeight.w700)),
              const SizedBox(width: 8),
              Text('· 1 заведение', style: AppTheme.sans(size: 12, color: AppColors.textTertiary)),
            ],
          ),
          const SizedBox(height: 9),
          if (!_paid) ...[
            _softPill(
              'Пробный период: осталось $trialDays ${_plural(trialDays, 'день', 'дня', 'дней')}',
              fg: AppColors.warning,
              bg: AppColors.warningSoft,
            ),
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: frac,
                minHeight: 5,
                backgroundColor: AppColors.bgSecondary,
                valueColor: const AlwaysStoppedAnimation(AppColors.warning),
              ),
            ),
          ] else
            _softPill(
              'Оплачено до 9 авг. 2026 · Business',
              fg: AppColors.success,
              bg: AppColors.successSoft,
            ),
        ],
      ),
    );
  }

  /// Kichik pill (inline-block, 11px w700).
  Widget _softPill(String text, {required Color fg, required Color bg}) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
        child: Text(text, style: AppTheme.sans(size: 11, weight: FontWeight.w700, color: fg)),
      ),
    );
  }

  // ─────────────────────────── Chip row ───────────────────────────
  Widget _chipRow() {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final id = _chips[i][0];
          final label = _chips[i][1];
          final active = _tab == id;
          return GestureDetector(
            onTap: () => setState(() => _tab = id),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                color: active ? AppColors.posDark : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: active ? AppColors.posDark : AppColors.border),
              ),
              child: Text(
                label,
                style: AppTheme.sans(
                  size: 12.5,
                  weight: FontWeight.w600,
                  color: active ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────── Счета ───────────────────────────
  List<Widget> _invoiceTab(AppState app) {
    final plans = <Map<String, dynamic>>[
      {
        'name': 'Mini',
        'price': '\$29',
        'feats': ['1 заведение', 'Касса и склад', 'Статистика', 'Финансы'],
        'cur': !_paid,
      },
      {
        'name': 'Business',
        'price': '\$59',
        'feats': ['До 3 заведений', 'Всё из Mini', 'Модификаторы блюд', 'Акции и лояльность'],
        'cur': _paid,
      },
      {
        'name': 'Pro',
        'price': '\$99',
        'feats': ['Заведения без лимита', 'Всё из Business', 'Франшиза и API', 'Приоритетная поддержка'],
        'cur': false,
      },
    ];

    return [
      // Invoice card
      AppCard(
        padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Счёт за подписку', style: AppTheme.sans(size: 13.5, weight: FontWeight.w700)),
                const Spacer(),
                _badge(
                  _paid ? 'Оплачен' : (app.trialEndsAtLabel == null ? 'Не оплачен' : 'Оплатить до ${app.trialEndsAtLabel}'),
                  fg: _paid ? AppColors.success : AppColors.warning,
                  bg: _paid ? AppColors.successSoft : AppColors.warningSoft,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Тариф Mini · 1 месяц', style: AppTheme.sans(size: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 9),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('29,00 \$', style: AppTheme.serif(size: 21, weight: FontWeight.w700)),
                if (!_paid)
                  GestureDetector(
                    onTap: _openPaySheet,
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(AppRadius.btn),
                      ),
                      child: Text(
                        'Продлить подписку',
                        style: AppTheme.sans(size: 13.5, weight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      // Uppercase label
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
        child: Text(
          'СРАВНЕНИЕ ТАРИФОВ',
          style: AppTheme.sans(size: 11, weight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 0.9),
        ),
      ),
      const SizedBox(height: 8),
      for (final p in plans) ...[
        _planCard(p['name'] as String, p['price'] as String, (p['feats'] as List).cast<String>(), p['cur'] as bool),
        const SizedBox(height: 8),
      ],
    ];
  }

  Widget _planCard(String name, String price, List<String> feats, bool cur) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
      borderColor: cur ? AppColors.accent : AppColors.border,
      onTap: cur
          ? null
          : () => showToast(
                context,
                'Смена тарифа на $name — со следующего счёта',
                color: AppColors.accentHover,
                bg: AppColors.accentSoft,
                icon: Icons.credit_card,
              ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(name, style: AppTheme.serif(size: 17, weight: FontWeight.w700)),
              const SizedBox(width: 8),
              Text.rich(TextSpan(
                text: price,
                style: AppTheme.sans(size: 15, weight: FontWeight.w700),
                children: [
                  TextSpan(
                    text: '/мес',
                    style: AppTheme.sans(size: 11, weight: FontWeight.w500, color: AppColors.textTertiary),
                  ),
                ],
              )),
              const Spacer(),
              if (cur)
                _badge('Текущий', fg: AppColors.accentHover, bg: AppColors.accentSoft),
            ],
          ),
          const SizedBox(height: 8),
          for (final f in feats)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text('· $f', style: AppTheme.sans(size: 12, color: AppColors.textSecondary)),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────── Подписки ───────────────────────────
  Widget _subsTab() {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.bgSecondary, borderRadius: BorderRadius.circular(12)),
            child: const Text('📦', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Xposter · тариф Mini', style: AppTheme.sans(size: 13.5, weight: FontWeight.w600)),
                const SizedBox(height: 1),
                Text('1 заведение · продлевается ежемесячно',
                    style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── Платежи ───────────────────────────
  Widget _paysTab() {
    final rows = <List<String>>[
      ['Пробный период активирован', 'при регистрации', '\$0,00'],
    ];
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
              decoration: BoxDecoration(
                border: i == 0 ? null : const Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(rows[i][0], style: AppTheme.sans(size: 13, weight: FontWeight.w600)),
                        const SizedBox(height: 1),
                        Text(rows[i][1], style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary)),
                      ],
                    ),
                  ),
                  Text(rows[i][2], style: AppTheme.sans(size: 13, weight: FontWeight.w700)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────── Настройки ───────────────────────────
  Widget _settingsTab() {
    final app = context.read<AppState>();
    final owner = app.currentUser;
    final email = owner.login ?? '—';
    return AppCard(
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
      child: Column(
        children: [
          _kvRow('Плательщик', owner.name),
          const SizedBox(height: 9),
          _kvRow('Счета на e-mail', email),
          const SizedBox(height: 9),
          _kvRow('Валюта оплаты', 'USD'),
        ],
      ),
    );
  }

  Widget _kvRow(String k, String v, {Color? valueColor, VoidCallback? onTap}) {
    final value = Text(
      v,
      style: AppTheme.sans(size: 12.5, weight: FontWeight.w600, color: valueColor ?? AppColors.text),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(k, style: AppTheme.sans(size: 12.5, color: AppColors.textTertiary)),
        onTap == null ? value : GestureDetector(onTap: onTap, child: value),
      ],
    );
  }

  // ─────────────────────────── Shared badge ───────────────────────────
  Widget _badge(String text, {required Color fg, required Color bg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Text(text, style: AppTheme.sans(size: 10.5, weight: FontWeight.w700, color: fg)),
    );
  }

  // ─────────────────────────── Pay sheet (halol versiya) ───────────────────────────
  /// Onlayn-billing hali ulanmagan — foydalanuvchini aldamaymiz:
  /// to'lov rekvizitlari va aloqa kanalini ko'rsatamiz.
  void _openPaySheet() {
    showAppSheet(context, title: 'Оплата подписки', builder: (ctx) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Онлайн-оплата картой скоро появится. Пока подписка продлевается вручную — напишите нам, и мы выставим счёт.',
            style: AppTheme.sans(size: 13.5, color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 14),
          AppCard(
            padding: const EdgeInsets.all(13),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.mail_outline, size: 17, color: AppColors.textSecondary),
                const SizedBox(width: 9),
                Text('support@xposter.app', style: AppTheme.sans(size: 13.5, weight: FontWeight.w600)),
              ]),
              const SizedBox(height: 9),
              Row(children: [
                const Icon(Icons.send_outlined, size: 17, color: AppColors.textSecondary),
                const SizedBox(width: 9),
                Text('Telegram: @xposter_support', style: AppTheme.sans(size: 13.5, weight: FontWeight.w600)),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
          PrimaryButton('Понятно', onPressed: () => Navigator.pop(ctx)),
          const SizedBox(height: 8),
        ],
      );
    });
  }
}
