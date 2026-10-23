import 'package:flutter/widgets.dart';
import '../tokens/em_colors.dart';

/// Two thin accent rings that ripple outward from a rounded tile (the splash logo tile).
/// The same ripple idea as the logomark's hub ripple (M1), moved out to the tile:
/// each ring leaves the tile's edge, grows [reach] of the tile side and fades out.
///
/// [phase] 0..1 is one cycle (loop it); [strength] 0..1 scales the opacity (the
/// rings only exist once the tile has appeared). No blur, no shader, no saveLayer.
class EmRippleRings extends CustomPainter {
  EmRippleRings({required this.phase, required this.strength, this.radiusFactor = 0.2})
      : super(repaint: Listenable.merge([phase, strength]));

  final Animation<double> phase;
  final Animation<double> strength;

  /// Tile corner radius as a fraction of its side (EmRadius.logoTileRatio).
  final double radiusFactor;

  static const int count = 2;
  static const double reach = 0.55;
  static const double strokeWidth = 1.5;
  static const double peakAlpha = 0.6;

  final Paint _paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth
    ..isAntiAlias = true;

  /// Ring [i] at cycle position [p]: its growth (0..1) and opacity (0..1).
  static ({double growth, double opacity}) ring(int i, double p) {
    final t = (p + i / count) % 1.0;
    return (growth: Curves.easeOut.transform(t), opacity: 1 - t);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = strength.value;
    if (s <= 0) return;
    for (var i = 0; i < count; i++) {
      final r = ring(i, phase.value);
      final grow = size.shortestSide * reach * r.growth;
      _paint.color = EmColors.accent.withAlpha((255 * peakAlpha * r.opacity * s).round());
      canvas.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.shortestSide * radiusFactor)).inflate(grow),
        _paint,
      );
    }
  }

  @override
  bool shouldRepaint(EmRippleRings old) => old.phase != phase || old.strength != strength || old.radiusFactor != radiusFactor;
}
