import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../tokens/em_colors.dart';
import '../tokens/em_motion.dart';
import '../tokens/em_typography.dart';
import 'em_hero_card.dart';

/// Ring with round-capped primary arc over a light track, a white knob at the
/// leading edge of the arc and a centred value on a white disc.
/// [value] is 0..1. The arc animates on first build and on change.
class EmProgressRing extends StatelessWidget {
  const EmProgressRing({
    super.key,
    required this.value,
    this.size = 160,
    this.strokeWidth = 12,
    this.centerText,
    this.centerCaption,
    this.center,
    this.color = EmColors.primary,
    this.trackColor = EmColors.primaryLight,
    this.knob = true,
    this.semanticLabel,
  });

  final double value;
  final double size;
  final double strokeWidth;
  final String? centerText;
  final String? centerCaption;

  /// Replaces [centerText]/[centerCaption].
  final Widget? center;
  final Color color;
  final Color trackColor;
  final bool knob;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    final inner = size - strokeWidth * 2 - 16;
    return Semantics(
      label: semanticLabel ?? 'Progress ${(v * 100).round()} percent',
      value: '${(v * 100).round()}%',
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: v),
          duration: EmMotion.chart,
          curve: EmMotion.standard,
          builder: (context, t, _) => CustomPaint(
            painter: _RingPainter(t, strokeWidth, color, trackColor, knob),
            child: Center(
              child: Container(
                width: inner,
                height: inner,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: EmColors.surface, shape: BoxShape.circle),
                padding: const EdgeInsets.all(8),
                child: center ??
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(centerText ?? '${(v * 100).round()}%', style: EmType.value.copyWith(color: EmColors.ink)),
                          if (centerCaption != null) Text(centerCaption!, style: EmType.caption.copyWith(color: EmColors.textSecondary)),
                        ],
                      ),
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.t, this.stroke, this.color, this.track, this.knob);
  final double t;
  final double stroke;
  final Color color;
  final Color track;
  final bool knob;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = (size.shortestSide - stroke) / 2;
    final rect = Rect.fromCircle(center: c, radius: r);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, base..color = track);
    if (t > 0) {
      canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * t, false, base..color = color);
      if (knob) {
        final a = -math.pi / 2 + math.pi * 2 * t;
        final p = c + Offset(math.cos(a), math.sin(a)) * r;
        canvas.drawCircle(p, stroke * 0.62, Paint()..color = EmColors.surface);
        canvas.drawCircle(p, stroke * 0.62, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter o) => o.t != t || o.color != color || o.track != track || o.stroke != stroke;
}

/// Hero card composition: title / subtitle / action on the start side and the
/// ring on the end side. Stacks vertically when narrow or at large text scale.
class EmProgressRingCard extends StatelessWidget {
  const EmProgressRingCard({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    required this.value,
    this.centerText,
    this.centerCaption,
    this.ringSize = 140,
    this.semanticLabel,
  });

  final String title;
  final String? subtitle;
  final Widget? action;
  final double value;
  final String? centerText;
  final String? centerCaption;
  final double ringSize;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return EmHeroCard(
      wave: true,
      semanticLabel: semanticLabel,
      child: LayoutBuilder(builder: (context, c) {
        final stacked = c.maxWidth < 300 + (scale - 1) * 200;
        final text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: EmType.title.copyWith(color: EmColors.ink)),
            if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle!, style: EmType.body.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400))],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        );
        final ring = EmProgressRing(value: value, size: ringSize, centerText: centerText, centerCaption: centerCaption);
        if (stacked) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [text, const SizedBox(height: 16), Center(child: ring)]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [Expanded(child: text), const SizedBox(width: 12), ring]);
      }),
    );
  }
}
