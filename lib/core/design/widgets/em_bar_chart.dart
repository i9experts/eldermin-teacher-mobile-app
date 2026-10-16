import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../tokens/em_colors.dart';
import '../tokens/em_motion.dart';
import '../tokens/em_typography.dart';

class EmBarDatum {
  const EmBarDatum(this.label, this.value, {this.highlight = false});
  final String label;
  final double value;

  /// Draws the stronger tint (e.g. today / selected).
  final bool highlight;
}

/// Rounded-top bars over full-height background tracks, dashed grid, y-axis
/// ticks. Pure `CustomPainter`; no chart dependency. Labels scale with the
/// system text size up to 1.3x.
class EmBarChart extends StatelessWidget {
  const EmBarChart({
    super.key,
    required this.data,
    this.maxValue = 100,
    this.yTicks = 4,
    this.height = 190,
    this.semanticLabel,
  }) : assert(yTicks >= 1);

  final List<EmBarDatum> data;
  final double maxValue;
  final int yTicks;
  final double height;

  /// Overrides the generated spoken summary.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.3).toDouble();
    final summary = semanticLabel ?? 'Bar chart. ${data.map((d) => '${d.label} ${d.value.toStringAsFixed(d.value % 1 == 0 ? 0 : 1)}').join(', ')}';
    return Semantics(
      label: summary,
      image: true,
      excludeSemantics: true,
      child: SizedBox(
        height: height + 24 * scale,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: EmMotion.chart,
          curve: EmMotion.standard,
          builder: (context, t, _) => CustomPaint(
            size: Size.infinite,
            painter: _BarPainter(data: data, maxValue: maxValue, yTicks: yTicks, progress: t, textScale: scale, rtl: Directionality.of(context) == TextDirection.rtl),
          ),
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({required this.data, required this.maxValue, required this.yTicks, required this.progress, required this.textScale, required this.rtl});
  final List<EmBarDatum> data;
  final double maxValue;
  final int yTicks;
  final double progress;
  final double textScale;
  final bool rtl;

  TextPainter _tp(String s, {TextAlign align = TextAlign.start}) => TextPainter(
        text: TextSpan(text: s, style: EmType.caption.copyWith(color: EmColors.textSecondary, fontSize: 12 * textScale)),
        textDirection: TextDirection.ltr,
        textAlign: align,
        maxLines: 1,
        ellipsis: '…',
      );

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final ticks = [for (var i = 0; i <= yTicks; i++) maxValue * i / yTicks];
    final tickPainters = [for (final v in ticks) _tp(v.toStringAsFixed(v % 1 == 0 ? 0 : 1))..layout()];
    final labelW = tickPainters.map((p) => p.width).reduce(math.max) + 10;
    final xLabelH = 12 * textScale * 1.4 + 6;
    final plot = Rect.fromLTRB(rtl ? 0 : labelW, 6, rtl ? size.width - labelW : size.width, size.height - xLabelH);
    final slot = plot.width / data.length;
    final barW = math.min(40.0, slot * 0.58);

    // dashed grid: horizontal
    final grid = Paint()
      ..color = EmColors.primaryLight.withOpacity(0.6)
      ..strokeWidth = 1;
    for (var i = 0; i <= yTicks; i++) {
      final y = plot.bottom - plot.height * i / yTicks;
      _dashed(canvas, Offset(plot.left, y), Offset(plot.right, y), grid);
      final tp = tickPainters[i];
      final dx = rtl ? plot.right + 10 : 0.0;
      tp.paint(canvas, Offset(dx, y - tp.height / 2));
    }
    // dashed grid: vertical at slot edges
    for (var i = 0; i <= data.length; i++) {
      final x = plot.left + slot * i;
      _dashed(canvas, Offset(x, plot.top), Offset(x, plot.bottom), grid);
    }

    for (var i = 0; i < data.length; i++) {
      final d = data[i];
      final cx = plot.left + slot * (i + 0.5);
      // track
      final track = RRect.fromRectAndCorners(
        Rect.fromLTRB(cx - barW / 2, plot.top, cx + barW / 2, plot.bottom),
        topLeft: Radius.circular(barW / 2),
        topRight: Radius.circular(barW / 2),
      );
      canvas.drawRRect(track, Paint()..color = EmColors.primaryContainer.withOpacity(0.55));
      // bar
      final h = plot.height * (d.value / maxValue).clamp(0.0, 1.0) * progress;
      if (h > 0) {
        final r = math.min(barW / 2, h);
        final bar = RRect.fromRectAndCorners(
          Rect.fromLTRB(cx - barW / 2, plot.bottom - h, cx + barW / 2, plot.bottom),
          topLeft: Radius.circular(r),
          topRight: Radius.circular(r),
        );
        canvas.drawRRect(bar, Paint()..color = d.highlight ? EmColors.primary : EmColors.primaryMid);
      }
      final lp = _tp(d.label, align: TextAlign.center)..layout(maxWidth: slot);
      lp.paint(canvas, Offset(cx - lp.width / 2, plot.bottom + 6));
    }
  }

  void _dashed(Canvas canvas, Offset a, Offset b, Paint p) {
    const dash = 3.0, gap = 3.0;
    final len = (b - a).distance;
    final dir = (b - a) / len;
    for (var d = 0.0; d < len; d += dash + gap) {
      canvas.drawLine(a + dir * d, a + dir * math.min(d + dash, len), p);
    }
  }

  @override
  bool shouldRepaint(covariant _BarPainter o) => o.progress != progress || o.data != data || o.maxValue != maxValue || o.textScale != textScale;
}
