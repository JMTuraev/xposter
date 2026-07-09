import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/ui.dart';

/// Vaqtinchalik zaglushka — keyingi bosqichlarda to'ldiriladi.
class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title, style: AppTheme.serif(size: 20, weight: FontWeight.w600))),
      body: const EmptyState(
        emoji: '🛠️',
        title: 'Появится в следующем шаге',
        subtitle: 'Этот раздел наполняется по мере разработки модулей.',
      ),
    );
  }
}
