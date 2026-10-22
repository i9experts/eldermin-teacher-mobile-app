import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'logomark_geometry.dart';

/// Paints the Eldermin logomark as a live node network.
///
/// With every animation null (or at 0) the picture is the SVG's: same
/// geometry, same colours, same draw order (solid links, dashed links, nodes).
/// The animations add, on top of that:
///
/// * [charge]    0..1 sweep: a light travels along each solid link in turn
/// * [dashPhase] 0..1: one dash period of the dashed links (wraps)
/// * [pulse]     0..1: the accent node swells and settles
/// * [ripple]    0..1 sweep: three rings leave the accent node
/// * [morph]     0..1: palette [from] -> [to] (reversed -> standard on hand-off)
///
/// Paints in the SVG's coordinate space scaled to fit; no allocation per
/// frame (Paint objects are fields, links are straight lines), no blur, no
/// shaders, no saveLayer.
class NodeNetworkPainter extends CustomPainter {
  NodeNetworkPainter({
    this.from = EmNetworkPalette.standard,
    this.to,
    this.morph,
    this.charge,
    this.dashPhase,
    this.pulse,
    this.ripple,
  }) : super(repaint: Listenable.merge([morph, charge, dashPhase, pulse, ripple]));

  final EmNetworkPalette from;
  final EmNetworkPalette? to;
  final Animation<double>? morph;
  final Animation<double>? charge;
  final Animation<double>? dashPhase;
  final Animation<double>? pulse;
  final Animation<double>? ripple;

  // ---- Sweep shapes (ms). The drivers map their interval onto 0..1 of these. ----
  static const int chargeStaggerMs = 110;
  static const int chargeTravelMs = 420;
  static final int chargeTotalMs = chargeStaggerMs * (EmLogomarkGeometry.solidLinks.length - 1) + chargeTravelMs;
  static const int rippleCount = 3;
  static const int rippleStaggerMs = 120;
  static const int rippleLifeMs = 520;
  static const int rippleTotalMs = rippleStaggerMs * (rippleCount - 1) + rippleLifeMs;
  static const double pulseSwell = 0.10;
  static const double rippleReach = 1.2;

  final Paint _paint = Paint()..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    const vb = EmLogomarkGeometry.viewBox;
    final scale = math.min(size.width / vb.width, size.height / vb.height);
    final palette = (to != null && morph != null) ? EmNetworkPalette.lerp(from, to!, morph!.value) : from;

    canvas.save();
    canvas.translate((size.width - vb.width * scale) / 2, (size.height - vb.height * scale) / 2);
    canvas.scale(scale);
    canvas.translate(-vb.left, -vb.top);

    _solidLinks(canvas, palette);
    _dashedLinks(canvas, palette);
    _ripples(canvas, palette);
    _nodes(canvas, palette);

    canvas.restore();
  }

  void _solidLinks(Canvas canvas, EmNetworkPalette palette) {
    _paint
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..strokeWidth = EmLogomarkGeometry.solidWidth
      ..color = palette.solid;
    for (final l in EmLogomarkGeometry.solidLinks) {
      canvas.drawLine(l.from, l.to, _paint);
    }

    final c = charge?.value ?? 0;
    if (c <= 0 || c >= 1) return;
    final now = c * chargeTotalMs;
    const links = EmLogomarkGeometry.solidLinks;
    for (var i = 0; i < links.length; i++) {
      final p = (now - i * chargeStaggerMs) / chargeTravelMs;
      if (p <= 0 || p >= 1) continue;
      final l = links[i];
      final len = l.length;
      final head = Curves.easeInOutCubic.transform(p) * len;
      final edge = math.min(1.0, math.min(p, 1 - p) * 6); // fade in/out at the ends
      // Layered strokes (long+faint to short+bright) instead of a blur or gradient.
      const tails = [0.30, 0.18, 0.08];
      const alphas = [0.25, 0.5, 0.95];
      _paint.strokeWidth = EmLogomarkGeometry.solidWidth * 0.6;
      for (var k = 0; k < tails.length; k++) {
        final tail = math.max(0.0, head - tails[k] * len);
        if (head <= tail) continue;
        _paint.color = palette.light.withAlpha((255 * alphas[k] * edge).round());
        canvas.drawLine(_along(l, tail / len), _along(l, head / len), _paint);
      }
    }
  }

  void _dashedLinks(Canvas canvas, EmNetworkPalette palette) {
    const period = EmLogomarkGeometry.dashLength + EmLogomarkGeometry.dashGap;
    final offset = ((dashPhase?.value ?? 0) % 1.0) * period;
    _paint
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..strokeWidth = EmLogomarkGeometry.dashedWidth
      ..color = palette.dashed;
    for (final l in EmLogomarkGeometry.dashedLinks) {
      final len = l.length;
      for (var s = offset - period; s < len; s += period) {
        final a = math.max(0.0, s);
        final b = math.min(len, s + EmLogomarkGeometry.dashLength);
        if (b <= a) continue;
        canvas.drawLine(_along(l, a / len), _along(l, b / len), _paint);
      }
    }
  }

  void _ripples(Canvas canvas, EmNetworkPalette palette) {
    final r = ripple?.value ?? 0;
    if (r <= 0 || r >= 1) return;
    final now = r * rippleTotalMs;
    final hub = EmLogomarkGeometry.nodes[EmLogomarkGeometry.centre];
    _paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24;
    for (var j = 0; j < rippleCount; j++) {
      final t = (now - j * rippleStaggerMs) / rippleLifeMs;
      if (t <= 0 || t >= 1) continue;
      _paint.color = palette.accent.withAlpha((255 * 0.5 * (1 - t)).round());
      canvas.drawCircle(hub.centre, hub.radius * (1 + rippleReach * Curves.easeOut.transform(t)), _paint);
    }
  }

  void _nodes(Canvas canvas, EmNetworkPalette palette) {
    _paint.style = PaintingStyle.fill;
    final bump = math.sin(math.pi * (pulse?.value ?? 0).clamp(0.0, 1.0));
    for (final n in EmLogomarkGeometry.nodes) {
      _paint.color = switch (n.role) {
        EmNodeRole.hub => palette.hub,
        EmNodeRole.node => palette.node,
        EmNodeRole.accent => palette.accent,
      };
      final swell = n.role == EmNodeRole.accent ? 1 + pulseSwell * bump : 1.0;
      canvas.drawCircle(n.centre, n.radius * swell, _paint);
    }
  }

  static Offset _along(EmLink l, double t) => Offset.lerp(l.from, l.to, t)!;

  @override
  bool shouldRepaint(NodeNetworkPainter old) =>
      old.from != from ||
      old.to != to ||
      old.morph != morph ||
      old.charge != charge ||
      old.dashPhase != dashPhase ||
      old.pulse != pulse ||
      old.ripple != ripple;
}

/// The animation inputs of [NodeNetworkPainter], bundled so a logo widget can
/// carry them without a field per animation.
class EmNetworkDrive {
  const EmNetworkDrive({this.to, this.morph, this.charge, this.dashPhase, this.pulse, this.ripple});
  final EmNetworkPalette? to;
  final Animation<double>? morph;
  final Animation<double>? charge;
  final Animation<double>? dashPhase;
  final Animation<double>? pulse;
  final Animation<double>? ripple;
}

/// The painter in a sized, repaint-isolated box with the logomark's semantics.
class EmNodeNetwork extends StatelessWidget {
  const EmNodeNetwork({
    super.key,
    required this.height,
    this.from = EmNetworkPalette.standard,
    this.drive = const EmNetworkDrive(),
    this.semanticLabel = 'Eldermin',
  });

  final double height;
  final EmNetworkPalette from;
  final EmNetworkDrive drive;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      image: true,
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size(height * EmLogomarkGeometry.aspect, height),
          painter: NodeNetworkPainter(
            from: from,
            to: drive.to,
            morph: drive.morph,
            charge: drive.charge,
            dashPhase: drive.dashPhase,
            pulse: drive.pulse,
            ripple: drive.ripple,
          ),
        ),
      ),
    );
  }
}
