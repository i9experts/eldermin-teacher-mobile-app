import 'package:flutter/material.dart';
import '../tokens/em_colors.dart';
import '../tokens/em_radius.dart';

/// Primary-tinted container, radius 28: the "hero" surface level. Nested
/// items inside are white (day pills) or [EmColors.primaryTint] (stat tiles).
/// [wave] paints the soft decorative band across the lower half.
class EmHeroCard extends StatelessWidget {
  const EmHeroCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsetsDirectional.all(20),
    this.color = EmColors.primaryContainer,
    this.wave = false,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final bool wave;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final body = DecoratedBox(
      decoration: BoxDecoration(color: color, borderRadius: EmRadius.heroAll),
      child: ClipRRect(
        borderRadius: EmRadius.heroAll,
        child: CustomPaint(
          painter: wave ? const _WavePainter() : null,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    return semanticLabel == null ? body : Semantics(container: true, label: semanticLabel, child: body);
  }
}

class _WavePainter extends CustomPainter {
  const _WavePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = EmColors.primaryLight.withAlpha(89);
    final y = size.height * 0.55;
    final path = Path()
      ..moveTo(0, y)
      ..cubicTo(size.width * 0.25, y - 26, size.width * 0.5, y + 28, size.width * 0.75, y - 6)
      ..cubicTo(size.width * 0.88, y - 20, size.width * 0.95, y - 12, size.width, y - 8)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
