import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../widgets/ui.dart';

class _AppItem {
  final String id;
  final String emoji;
  final String name;
  final String price;
  final String desc;
  final bool ai;
  const _AppItem(this.id, this.emoji, this.name, this.price, this.desc, {this.ai = false});
}

class AppsScreen extends StatefulWidget {
  const AppsScreen({super.key});
  @override
  State<AppsScreen> createState() => _AppsScreenState();
}

class _AppsScreenState extends State<AppsScreen> {
  final _installed = <String>{};

  static const _apps = <_AppItem>[
    _AppItem('qr', '📱', 'Xposter QR', '\$7/мес', 'QR-меню и отзывы гостей'),
    _AppItem('site', '🌐', 'Xposter Site', 'от \$19', 'Сайт заведения с меню'),
    _AppItem('qrcheck', '🧾', 'QR-код на чек', 'Бесплатно', 'Электронный чек по QR'),
    _AppItem('tg', '✈️', 'Уведомления в Telegram', 'Бесплатно', 'Отчёты и алерты в чат'),
    _AppItem('board', '📺', 'Табло заказов', '\$7/мес', 'Экран статусов для гостей'),
    _AppItem('dbot', '🛵', 'Delivery Bot', '\$15/мес', 'Приём заказов на доставку'),
    _AppItem('kitchen', '👨‍🍳', 'Kitchen Kit', '\$9/мес', 'Экран повара вместо бегунков'),
    _AppItem('ai', '✨', 'Postie AI', '\$12/мес', 'AI-аналитик вашего заведения', ai: true),
  ];

  void _install(_AppItem a) {
    if (_installed.contains(a.id)) return;
    setState(() => _installed.add(a.id));
    showToast(context, '«${a.name}» установлено', icon: Icons.extension);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _buildAppBar(context),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 30),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              'Расширьте Xposter приложениями — они подключаются в один тап.',
              style: AppTheme.sans(size: 12.5, color: AppColors.textSecondary, height: 1.4),
            ),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 9,
              crossAxisSpacing: 9,
              mainAxisExtent: 190,
            ),
            itemCount: _apps.length,
            itemBuilder: (_, i) => _AppCard(
              app: _apps[i],
              installed: _installed.contains(_apps[i].id),
              onInstall: () => _install(_apps[i]),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleSpacing: 0,
      leadingWidth: 96,
      leading: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: InkWell(
          onTap: () => Navigator.of(context).maybePop(),
          borderRadius: BorderRadius.circular(10),
          splashColor: AppColors.accentSoft,
          highlightColor: AppColors.accentSoft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('‹', style: AppTheme.sans(size: 20, weight: FontWeight.w400, color: AppColors.accentHover, height: 1.0)),
                const SizedBox(width: 4),
                Text('Ещё', style: AppTheme.sans(size: 14.5, weight: FontWeight.w600, color: AppColors.accentHover)),
              ],
            ),
          ),
        ),
      ),
      title: Text('Приложения', style: AppTheme.sans(size: 17, weight: FontWeight.w600)),
    );
  }
}

class _AppCard extends StatelessWidget {
  final _AppItem app;
  final bool installed;
  final VoidCallback onInstall;
  const _AppCard({required this.app, required this.installed, required this.onInstall});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
        boxShadow: kSoftShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.bgSecondary,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(app.emoji, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(height: 7),
          _NameRow(name: app.name, ai: app.ai),
          const SizedBox(height: 2),
          Text(
            app.desc,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.sans(size: 11, color: AppColors.textTertiary, height: 1.4),
          ),
          const Spacer(),
          Text(app.price, style: AppTheme.sans(size: 11.5, weight: FontWeight.w700, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          _InstallButton(installed: installed, onInstall: onInstall),
        ],
      ),
    );
  }
}

class _NameRow extends StatelessWidget {
  final String name;
  final bool ai;
  const _NameRow({required this.name, required this.ai});

  @override
  Widget build(BuildContext context) {
    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: AppTheme.sans(size: 13, weight: FontWeight.w700, height: 1.25),
        children: [
          TextSpan(text: name),
          if (ai)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              baseline: TextBaseline.alphabetic,
              child: Padding(
                padding: const EdgeInsets.only(left: 5),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('✨ AI', style: AppTheme.sans(size: 9.5, weight: FontWeight.w700, color: AppColors.accentHover)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InstallButton extends StatelessWidget {
  final bool installed;
  final VoidCallback onInstall;
  const _InstallButton({required this.installed, required this.onInstall});

  @override
  Widget build(BuildContext context) {
    final bg = installed ? AppColors.successSoft : AppColors.accent;
    final fg = installed ? AppColors.success : Colors.white;
    final label = installed ? 'Установлено' : 'Установить';
    return SizedBox(
      width: double.infinity,
      height: 34,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: installed ? null : onInstall,
          borderRadius: BorderRadius.circular(9),
          child: Center(
            child: Text(label, style: AppTheme.sans(size: 12, weight: FontWeight.w600, color: fg)),
          ),
        ),
      ),
    );
  }
}
