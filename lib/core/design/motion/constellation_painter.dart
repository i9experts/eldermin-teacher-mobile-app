import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import '../tokens/em_colors.dart';
import '../tokens/em_motion.dart';

/// A faint field of small nodes behind navy surfaces, drifting slowly.
///
/// Deterministic (same [seed] -> same field), cheap (a few dozen circles plus
/// at most [maxLinks] hairlines per frame, no blur / shader / saveLayer, no
/// allocation in [paint] after the first one per size). [time] is a 0..1
/// animation over [EmMotion.ambientPeriod]; every node drifts in whole cycles
/// per loop so the loop never seams. [intensity] 0..1 fades the whole field.
class ConstellationPainter extends CustomPainter {
  ConstellationPainter({
    required Animation<double> time,
    required Animation<double> intensity,
    this.seed = 7,
    this.count = 36,
    this.color = EmColors.primaryLight,
    this.maxLinks = 40,
    this.linkDistance = 120,
    this.avoid,
  })  : _time = time,
        _intensity = intensity,
        super(repaint: Listenable.merge([time, intensity]));

  final Animation<double> _time;
  final Animation<double> _intensity;
  final int seed;
  final int count;
  final Color color;
  final int maxLinks;

  /// dp; nodes closer than this (at rest) are joined by a hairline.
  final double linkDistance;

  /// Normalised (0..1) rect kept free of nodes at rest (the logo and title).
  final Rect? avoid;

  /// Minimum spacing of nodes at rest, normalised (x is scaled by a phone-ish aspect).
  static const double minSeparation = 0.1;
  static const double _sampleAspect = 0.46;
  static const int maxDegree = 2;

  static const double maxNodeAlpha = 0.3;
  static const double maxLinkAlpha = 0.12;

  late final List<_Star> _stars = _seedStars();
  Size? _linkedFor;
  List<(int, int)> _links = const [];
  final Paint _paint = Paint()..isAntiAlias = true;

  List<_Star> _seedStars() {
    final r = math.Random(seed);
    final placed = <Offset>[];
    var attempts = 0;
    // dart throwing: evenly spread, outside [avoid]; after enough attempts accept anything so the count is fixed
    Offset next() {
      while (true) {
        final p = Offset(r.nextDouble(), r.nextDouble());
        attempts++;
        final relaxed = attempts > 4000;
        if (!relaxed && avoid != null && avoid!.contains(p)) continue;
        if (!relaxed && placed.any((q) => Offset((p.dx - q.dx) * _sampleAspect, p.dy - q.dy).distance < minSeparation)) {
          continue;
        }
        placed.add(p);
        return p;
      }
    }

    return List.generate(count, (_) {
      final p = next();
      return _Star(
        x: p.dx,
        y: p.dy,
        radius: 1.2 + r.nextDouble() * 1.8,
        alpha: 0.4 + r.nextDouble() * 0.6,
        amplitude: EmMotion.driftMin + r.nextDouble() * (EmMotion.driftMax - EmMotion.driftMin),
        cyclesX: 3 + r.nextInt(4), // 3..6 cycles / 60 s
        cyclesY: 3 + r.nextInt(4),
        phaseX: r.nextDouble(),
        phaseY: r.nextDouble(),
      );
    });
  }

  Offset _at(_Star s, Size size, double t) => Offset(
        s.x * size.width + s.amplitude * math.sin(2 * math.pi * (t * s.cyclesX + s.phaseX)),
        s.y * size.height + s.amplitude * math.cos(2 * math.pi * (t * s.cyclesY + s.phaseY)),
      );

  void _computeLinks(Size size) {
    _linkedFor = size;
    final pairs = <(int, int, double)>[];
    for (var i = 0; i < _stars.length; i++) {
      for (var j = i + 1; j < _stars.length; j++) {
        final a = Offset(_stars[i].x * size.width, _stars[i].y * size.height);
        final b = Offset(_stars[j].x * size.width, _stars[j].y * size.height);
        final d = (a - b).distance;
        if (d < linkDistance) pairs.add((i, j, d));
      }
    }
    pairs.sort((a, b) => a.$3.compareTo(b.$3));
    final degree = List<int>.filled(_stars.length, 0);
    final links = <(int, int)>[];
    for (final p in pairs) {
      if (links.length >= maxLinks) break;
      if (degree[p.$1] >= maxDegree || degree[p.$2] >= maxDegree) continue;
      degree[p.$1]++;
      degree[p.$2]++;
      links.add((p.$1, p.$2));
    }
    _links = links;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final k = _intensity.value;
    if (k <= 0 || size.isEmpty) return;
    if (_linkedFor != size) _computeLinks(size);
    final t = _time.value;

    _paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color.withAlpha((255 * maxLinkAlpha * k).round());
    for (final (i, j) in _links) {
      canvas.drawLine(_at(_stars[i], size, t), _at(_stars[j], size, t), _paint);
    }

    _paint.style = PaintingStyle.fill;
    for (final s in _stars) {
      _paint.color = color.withAlpha((255 * maxNodeAlpha * s.alpha * k).round());
      canvas.drawCircle(_at(s, size, t), s.radius, _paint);
    }
  }

  @override
  bool shouldRepaint(ConstellationPainter old) =>
      old.seed != seed || old.count != count || old.color != color || old._time != _time || old._intensity != _intensity;
}

class _Star {
  const _Star({
    required this.x,
    required this.y,
    required this.radius,
    required this.alpha,
    required this.amplitude,
    required this.cyclesX,
    required this.cyclesY,
    required this.phaseX,
    required this.phaseY,
  });
  final double x, y, radius, alpha, amplitude, phaseX, phaseY;
  final int cyclesX, cyclesY;
}

/// The constellation as a fill-the-parent, repaint-isolated, non-interactive layer.
class EmConstellation extends StatelessWidget {
  const EmConstellation({super.key, required this.time, required this.intensity, this.seed = 7, this.avoid});
  final Animation<double> time;
  final Animation<double> intensity;
  final int seed;
  final Rect? avoid;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: ConstellationPainter(time: time, intensity: intensity, seed: seed, avoid: avoid),
          ),
        ),
      ),
    );
  }
}
