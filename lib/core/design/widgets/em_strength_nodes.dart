import 'package:flutter/material.dart';
import '../motion/reduce_motion.dart';
import '../tokens/em_colors.dart';
import '../tokens/em_motion.dart';
import '../tokens/em_typography.dart';

/// Password strength as four nodes that link up as [level] (0-4) rises, with
/// the word beside them (colour is never the only cue). For the dark auth card.
/// The fill animates (a link charges per step); reduce motion: instant.
class EmStrengthNodes extends StatelessWidget {
  const EmStrengthNodes({super.key, required this.level, required this.label});
  final int level;
  final String label;

  @override
  Widget build(BuildContext context) {
    final reduced = EmReduceMotion.of(context);
    return Semantics(
      label: 'Password strength: ${label.isEmpty ? 'none' : label}',
      excludeSemantics: true,
      child: Row(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: level.toDouble()),
            duration: reduced ? Duration.zero : EmMotion.fast * 2,
            curve: Curves.easeOut,
            builder: (context, v, _) => RepaintBoundary(child: CustomPaint(size: const Size(120, 20), painter: StrengthPainter(v))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: EmType.caption.copyWith(color: EmColors.primaryContainer))),
        ],
      ),
    );
  }
}

/// [value] 0..4: node i is filled once value >= i + 1; the link between nodes i
/// and i+1 fills from value i + 1 to i + 2 (so it charges as the level rises).
class StrengthPainter extends CustomPainter {
  const StrengthPainter(this.value);
  final double value;

  static const double r = 6;

  double nodeFill(int i) => (value - i).clamp(0.0, 1.0);
  double linkFill(int i) => (value - i - 1).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final gap = (size.width - 2 * r) / 3;
    Offset c(int i) => Offset(r + gap * i, size.height / 2);
    final p = Paint()
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    for (var i = 0; i < 3; i++) {
      p
        ..style = PaintingStyle.stroke
        ..color = EmColors.primaryMid;
      canvas.drawLine(c(i), c(i + 1), p);
      final f = linkFill(i);
      if (f > 0) {
        p.color = EmColors.onPrimaryDark;
        canvas.drawLine(c(i), Offset.lerp(c(i), c(i + 1), f)!, p);
      }
    }
    for (var i = 0; i < 4; i++) {
      p
        ..style = PaintingStyle.fill
        ..color = EmColors.primaryMid;
      canvas.drawCircle(c(i), r, p);
      final f = nodeFill(i);
      if (f > 0) {
        // the node you are on glows accent, the ones behind it are white
        p.color = (value - i) < 1.001 && value.round() == i + 1 ? EmColors.accent : EmColors.onPrimaryDark;
        canvas.drawCircle(c(i), r * f, p);
      }
    }
  }

  @override
  bool shouldRepaint(StrengthPainter old) => old.value != value;
}
