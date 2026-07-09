import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme.dart';
import '../../state/app_state.dart';
import '../../widgets/ui.dart';
import 'kassa_controller.dart';

/// PIN kirish ekrani (kassa boshlanishi / bloklash) — prototip «Касса — PIN».
class PinScreen extends StatefulWidget {
  final KassaController ctrl;
  const PinScreen({super.key, required this.ctrl});
  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> with SingleTickerProviderStateMixin {
  String _pin = '';
  bool _error = false;
  late final AnimationController _shake;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _press(String d) {
    if (_error || _pin.length >= 4) return;
    setState(() => _pin += d);
    if (_pin.length == 4) {
      Future.delayed(const Duration(milliseconds: 180), _submit);
    }
  }

  void _del() => setState(() => _pin = _pin.isEmpty ? _pin : _pin.substring(0, _pin.length - 1));

  void _submit() {
    final name = widget.ctrl.tryLogin(_pin);
    if (name == null) {
      setState(() => _error = true);
      _shake.forward(from: 0);
      Future.delayed(const Duration(milliseconds: 550), () {
        if (mounted) setState(() { _pin = ''; _error = false; });
      });
    }
    // muvaffaqiyatli bo'lsa — controller notifyListeners → ota-ekran chek ekraniga o'tadi
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo «X»
                    Container(
                      width: 62, height: 62,
                      decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(18)),
                      alignment: Alignment.center,
                      child: Text('X', style: AppTheme.serif(size: 30, weight: FontWeight.w700, color: Colors.white)),
                    ),
                    const SizedBox(height: 12),
                    Text('Xposter', style: AppTheme.serif(size: 23, weight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text('Больше, чем просто касса', style: AppTheme.sans(size: 13, color: AppColors.textSecondary)),
                    const SizedBox(height: 26),
                    // Nuqtalar
                    AnimatedBuilder(
                      animation: _shake,
                      builder: (_, child) {
                        final dx = _error ? (8 * (1 - _shake.value)) * ((_shake.value * 8).floor().isEven ? 1 : -1) : 0.0;
                        return Transform.translate(offset: Offset(dx, 0), child: child);
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (i) {
                          final filled = i < _pin.length;
                          final fill = _error ? AppColors.danger : AppColors.accent;
                          final border = _error ? AppColors.danger : (filled ? AppColors.accent : AppColors.borderStrong);
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 7),
                            width: 13, height: 13,
                            decoration: BoxDecoration(
                              color: filled ? fill : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(color: border, width: 1.5),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 22),
                    _Keypad(onDigit: _press, onDelete: _del, onKeyboard: () => showToast(context, 'Внешняя клавиатура не подключена', color: AppColors.textSecondary, bg: AppColors.bgSecondary, icon: Icons.keyboard_outlined)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  context.watch<AppState>().company['name']?.toString() ?? '',
                  textAlign: TextAlign.center,
                  style: AppTheme.sans(size: 12, height: 1.6, color: AppColors.textTertiary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final VoidCallback onKeyboard;
  const _Keypad({required this.onDigit, required this.onDelete, required this.onKeyboard});
  @override
  Widget build(BuildContext context) {
    Widget key({String? label, VoidCallback? onTap, Widget? child, double fs = 22}) => SizedBox(
          width: 72, height: 58,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap ?? () => onDigit(label!),
            child: Center(child: child ?? Text(label!, style: AppTheme.sans(size: fs, weight: FontWeight.w600))),
          ),
        );
    Widget row(List<Widget> ch) => Row(mainAxisAlignment: MainAxisAlignment.center, children: ch);
    return Column(children: [
      row([key(label: '1'), key(label: '2'), key(label: '3')]),
      row([key(label: '4'), key(label: '5'), key(label: '6')]),
      row([key(label: '7'), key(label: '8'), key(label: '9')]),
      row([
        key(onTap: onDelete, child: Text('Удалить', style: AppTheme.sans(size: 13, weight: FontWeight.w600, color: AppColors.textSecondary))),
        key(label: '0'),
        key(onTap: onKeyboard, child: const Icon(Icons.keyboard_outlined, size: 22, color: AppColors.textSecondary)),
      ]),
    ]);
  }
}
