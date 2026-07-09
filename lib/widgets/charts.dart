import 'package:flutter/material.dart';
import '../theme.dart';

/// Chiziqli grafik (terrakota, nuqtalar + gradient), pastida label'lar.
class LineChartWidget extends StatelessWidget {
  final List<double> data;
  final List<String> labels;
  const LineChartWidget({super.key, required this.data, this.labels = const []});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(child: CustomPaint(size: Size.infinite, painter: _LinePainter(data))),
      if (labels.isNotEmpty) Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: labels.map((l) => Text(l, style: AppTheme.sans(size: 10, color: AppColors.textTertiary))).toList()),
      ),
    ]);
  }
}

class _LinePainter extends CustomPainter {
  final List<double> data;
  _LinePainter(this.data);
  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final maxV = data.reduce((a, b) => a > b ? a : b);
    final range = maxV == 0 ? 1 : maxV;
    final n = data.length;
    final dx = n > 1 ? size.width / (n - 1) : size.width;
    final grid = Paint()..color = AppColors.border..strokeWidth = 1;
    for (int i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    Offset pt(int i) => Offset(i * dx, size.height - (data[i] / range) * size.height * 0.9 - 4);
    final fill = Path()..moveTo(0, size.height);
    for (int i = 0; i < n; i++) { fill.lineTo(pt(i).dx, pt(i).dy); }
    fill.lineTo(size.width, size.height);
    fill.close();
    canvas.drawPath(fill, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x33D97757), Color(0x00D97757)]).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
    final line = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (int i = 1; i < n; i++) { line.lineTo(pt(i).dx, pt(i).dy); }
    canvas.drawPath(line, Paint()..color = AppColors.accent..style = PaintingStyle.stroke..strokeWidth = 2.5..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
    if (n <= 12) {
      for (int i = 0; i < n; i++) {
        canvas.drawCircle(pt(i), 3.5, Paint()..color = AppColors.surface);
        canvas.drawCircle(pt(i), 3.5, Paint()..color = AppColors.accent..style = PaintingStyle.stroke..strokeWidth = 2);
      }
    }
  }
  @override
  bool shouldRepaint(covariant _LinePainter old) => old.data != data;
}

/// Ustunli grafik.
class BarChartWidget extends StatelessWidget {
  final List<double> values;
  final int labelEvery;
  final String Function(int) labelBuilder;
  const BarChartWidget({super.key, required this.values, this.labelEvery = 1, required this.labelBuilder});
  @override
  Widget build(BuildContext context) {
    final maxV = values.isEmpty ? 1.0 : values.reduce((a, b) => a > b ? a : b);
    final safeMax = maxV == 0 ? 1.0 : maxV;
    return LayoutBuilder(builder: (_, c) {
      return Row(crossAxisAlignment: CrossAxisAlignment.end, children: List.generate(values.length, (i) {
        final h = (values[i] / safeMax) * (c.maxHeight - 18);
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              Container(height: h.clamp(2, c.maxHeight - 18), decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.85), borderRadius: const BorderRadius.vertical(top: Radius.circular(3)))),
              const SizedBox(height: 4),
              SizedBox(height: 12, child: i % labelEvery == 0 ? Text(labelBuilder(i), style: AppTheme.sans(size: 8, color: AppColors.textTertiary), maxLines: 1) : null),
            ]),
          ),
        );
      }));
    });
  }
}
