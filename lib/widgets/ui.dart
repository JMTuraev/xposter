import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';

/// Mahsulot rasmi: `imagePath` bo'lsa — haqiqiy rasm, aks holda emoji plitka.
class ProductThumb extends StatelessWidget {
  final String? imagePath;
  final String emoji;
  final double size;
  final double radius;
  const ProductThumb({super.key, this.imagePath, required this.emoji, this.size = 38, this.radius = 11});

  @override
  Widget build(BuildContext context) {
    final p = imagePath;
    if (p != null && p.isNotEmpty) {
      // §7: Firebase Storage URL bo'lsa — Image.network; mahalliy yo'l bo'lsa — Image.file.
      if (p.startsWith('http://') || p.startsWith('https://')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Image.network(p, width: size, height: size, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _emojiBox()),
        );
      }
      if (File(p).existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Image.file(File(p), width: size, height: size, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _emojiBox()),
        );
      }
    }
    return _emojiBox();
  }

  Widget _emojiBox() => Container(
        width: size, height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: AppColors.bgSecondary, borderRadius: BorderRadius.circular(radius)),
        child: Text(emoji, style: TextStyle(fontSize: size * 0.5)),
      );
}

/// Oq karta, yumshoq ramka, radius 16.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: borderColor ?? AppColors.border),
        boxShadow: kSoftShadow,
      ),
      child: child,
    );
    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: card,
    );
  }
}

/// Asosiy terrakota tugma (to'liq kenglik). [busy] — spinner + bloklash.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;
  final bool expand;
  final bool busy;
  const PrimaryButton(this.label, {super.key, this.onPressed, this.icon, this.color = AppColors.accent, this.expand = true, this.busy = false});

  @override
  Widget build(BuildContext context) {
    final btn = SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: busy ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withOpacity(busy ? 0.75 : 0.4),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.btn)),
          textStyle: AppTheme.sans(size: 15, weight: FontWeight.w600),
        ),
        child: busy
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
                  Text(label),
                ],
              ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

/// Ikkilamchi (oq + ramka) tugma.
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  const SecondaryButton(this.label, {super.key, this.onPressed, this.icon, this.expand = false});

  @override
  Widget build(BuildContext context) {
    final btn = SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.text,
          side: const BorderSide(color: AppColors.borderStrong),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.btn)),
          textStyle: AppTheme.sans(size: 14, weight: FontWeight.w500),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 6)],
            Text(label),
          ],
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

/// Status-badge (pill): «Открыт» warning, «Закрыт» success, dolg danger.
class StatusBadge extends StatelessWidget {
  final String text;
  final Color fg;
  final Color bg;
  const StatusBadge(this.text, {super.key, required this.fg, required this.bg});

  factory StatusBadge.success(String t) => StatusBadge(t, fg: AppColors.success, bg: AppColors.successSoft);
  factory StatusBadge.warning(String t) => StatusBadge(t, fg: AppColors.warning, bg: AppColors.warningSoft);
  factory StatusBadge.danger(String t) => StatusBadge(t, fg: AppColors.danger, bg: AppColors.dangerSoft);
  factory StatusBadge.accent(String t) => StatusBadge(t, fg: AppColors.accentHover, bg: AppColors.accentSoft);
  factory StatusBadge.neutral(String t) => StatusBadge(t, fg: AppColors.textSecondary, bg: AppColors.bgSecondary);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Text(text, style: AppTheme.sans(size: 12, weight: FontWeight.w600, color: fg)),
    );
  }
}

/// Gorizontal chip-filtr.
class FilterChipRow extends StatelessWidget {
  final List<String> options;
  final int selected;
  final ValueChanged<int> onSelected;
  const FilterChipRow({super.key, required this.options, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final active = i == selected;
          return GestureDetector(
            onTap: () => onSelected(i),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: active ? AppColors.accent : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: active ? AppColors.accent : AppColors.border),
              ),
              child: Text(
                options[i],
                style: AppTheme.sans(size: 13, weight: FontWeight.w500, color: active ? Colors.white : AppColors.textSecondary),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Bo'sh holat: emoji + sarlavha + tavsif + CTA.
class EmptyState extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String? cta;
  final VoidCallback? onCta;
  const EmptyState({super.key, required this.emoji, required this.title, required this.subtitle, this.cta, this.onCta});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: AppTheme.sans(size: 17, weight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center, style: AppTheme.sans(size: 14, color: AppColors.textSecondary, height: 1.4)),
            if (cta != null) ...[
              const SizedBox(height: 18),
              PrimaryButton(cta!, expand: false, onPressed: onCta),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bo'lim sarlavhasi.
class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Text(text, style: AppTheme.sans(size: 16, weight: FontWeight.w600)),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Toast (success/info/danger) — yuqoridan tushadi, 2.5s.
void showToast(BuildContext context, String message, {Color? color, Color? bg, IconData icon = Icons.check_circle}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: bg ?? AppColors.successSoft,
    elevation: 0,
    duration: const Duration(milliseconds: 2500),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
    content: Row(children: [
      Icon(icon, size: 18, color: color ?? AppColors.success),
      const SizedBox(width: 10),
      Expanded(child: Text(message, style: AppTheme.sans(size: 14, weight: FontWeight.w500, color: color ?? AppColors.success))),
    ]),
  ));
}

/// Umumiy bottom sheet (dizayn: handle, radius 20).
Future<T?> showAppSheet<T>(BuildContext context, {required String title, required WidgetBuilder builder, List<Widget>? actions}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet))),
    builder: (ctx) {
      // Kontentga moslanadi, 92% dan oshsa scroll. Klaviatura ochilganda ustiga
      // chiqadi — «Сохранить» va boshqa tugmalar doim yetib boradi.
      final maxH = MediaQuery.of(ctx).size.height * 0.92;
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.borderStrong, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(children: [
                  Expanded(child: Text(title, style: AppTheme.serif(size: 20, weight: FontWeight.w600))),
                  IconButton(icon: const Icon(Icons.close, color: AppColors.textSecondary), onPressed: () => Navigator.pop(ctx)),
                ]),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + MediaQuery.of(ctx).viewPadding.bottom),
                  child: builder(ctx),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Oddiy input (label ustida).
class LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final String? hint;
  final TextInputType? keyboardType;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final Widget? suffix;
  final bool enabled;
  final bool obscure;
  final List<TextInputFormatter>? inputFormatters;
  const LabeledField({super.key, required this.label, this.controller, this.hint, this.keyboardType, this.maxLines = 1, this.onChanged, this.suffix, this.enabled = true, this.obscure = false, this.inputFormatters});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.sans(size: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: obscure ? 1 : maxLines,
          obscureText: obscure,
          enabled: enabled,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          style: AppTheme.sans(size: 15),
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            filled: true,
            fillColor: AppColors.surface,
            suffixIcon: suffix,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            hintStyle: AppTheme.sans(size: 15, color: AppColors.textTertiary),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.input), borderSide: const BorderSide(color: AppColors.borderStrong)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.input), borderSide: const BorderSide(color: AppColors.borderStrong)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.input), borderSide: const BorderSide(color: AppColors.accent, width: 2)),
          ),
        ),
      ],
    );
  }
}
