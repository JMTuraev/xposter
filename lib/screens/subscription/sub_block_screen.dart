import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme.dart';

/// QATTIQ BLOK: obuna/sinov muddati tugagan — kassa ochilmaydi.
/// Server (firestore.rules, `subActive`) ham yangi cheklarni RAD etadi, shuning
/// uchun bu ekranni chetlab o'tishning foydasi yo'q: yozuvlar baribir o'tmaydi.
/// Muddat serverda uzaytirilgach (paidUntil), kafe hujjatining jonli listener'i
/// blokni o'zi ko'taradi — «Проверить оплату» shunchaki jarayonni tezlashtiradi.
class SubBlockScreen extends StatefulWidget {
  const SubBlockScreen({super.key});
  @override
  State<SubBlockScreen> createState() => _SubBlockScreenState();
}

class _SubBlockScreenState extends State<SubBlockScreen> {
  bool _busy = false;

  String _fmt(DateTime? d) => d == null
      ? '—'
      : '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  Future<void> _check() async {
    final app = context.read<AppState>();
    setState(() => _busy = true);
    await app.refreshSubscription();
    if (!mounted) return;
    setState(() => _busy = false);
    if (app.subBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
            'Оплата пока не найдена. Если вы уже оплатили — подождите минуту и повторите.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final until = app.subUntil;
    return Scaffold(
      backgroundColor: AppColors.posDark,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 470),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(20)),
                  alignment: Alignment.center,
                  child:
                      const Icon(Icons.lock_outline, color: Colors.white, size: 38),
                ),
                const SizedBox(height: 22),
                Text('Подписка истекла',
                    style: AppTheme.serif(
                        size: 26, weight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 10),
                Text(
                  'Срок действия подписки Xposter POS закончился ${_fmt(until)}.\n'
                  'Касса и приём оплат остановлены до продления.',
                  textAlign: TextAlign.center,
                  style: AppTheme.sans(size: 14, color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Text(
                  'Для продления свяжитесь с Xposter, затем нажмите «Проверить оплату».',
                  textAlign: TextAlign.center,
                  style: AppTheme.sans(size: 13, color: Colors.white54),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  width: 260,
                  height: 46,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    onPressed: _busy ? null : _check,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.2, color: Colors.white))
                        : const Text('Проверить оплату',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _busy ? null : () => context.read<AppState>().logout(),
                  child: const Text('Сменить аккаунт',
                      style: TextStyle(color: Colors.white60)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
