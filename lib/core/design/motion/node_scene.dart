import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'logomark_geometry.dart';

/// One arrangement of the scene's nodes, in unit coordinates (0..1 on both
/// axes; the scene is square and centred in its box).
class SceneLayout {
  const SceneLayout({required this.nodes, required this.radii, this.links = const [], this.bubbles = const []});

  final List<Offset> nodes;

  /// Node radii in unit coordinates.
  final List<double> radii;

  /// Index pairs; `dashed` links are drawn dashed.
  final List<SceneLink> links;

  /// Soft discs behind nodes (the "chat bubbles"): centre + radius, unit coordinates.
  final List<(Offset, double)> bubbles;
}

class SceneLink {
  const SceneLink(this.a, this.b, {this.dashed = false});
  final int a;
  final int b;
  final bool dashed;
  int get key => a < b ? a * 100 + b : b * 100 + a;
}

/// Scenes of the Eldermin node language: the same nodes rearranged. [progress]
/// 0 = first layout, 1 = second, ...; between two layouts every position,
/// radius, link and bubble blends linearly, so a scrubbed value (a
/// PageController offset) shows exactly the in-between state.
class EmScenes {
  EmScenes._();

  static const List<EmNodeRole> introRoles = [
    EmNodeRole.hub,
    EmNodeRole.node,
    EmNodeRole.hub,
    EmNodeRole.node,
    EmNodeRole.accent,
    EmNodeRole.node,
    EmNodeRole.hub,
    EmNodeRole.node,
    EmNodeRole.hub,
  ];

  /// Page 1: a class: a 3x3 grid of students, links as the grid lines.
  static final SceneLayout classGrid = SceneLayout(
    nodes: [
      for (var r = 0; r < 3; r++)
        for (var c = 0; c < 3; c++) Offset(0.2 + 0.3 * c, 0.2 + 0.3 * r)
    ],
    radii: const [0.075, 0.055, 0.075, 0.055, 0.09, 0.055, 0.075, 0.055, 0.075],
    links: [
      for (var r = 0; r < 3; r++)
        for (var c = 0; c < 2; c++) SceneLink(r * 3 + c, r * 3 + c + 1),
      for (var r = 0; r < 2; r++)
        for (var c = 0; c < 3; c++) SceneLink(r * 3 + c, (r + 1) * 3 + c),
    ],
  );

  /// Page 2: attendance / homework: the nodes line up as a tick; two stay behind ("still to do").
  static const SceneLayout checks = SceneLayout(
    nodes: [
      Offset(0.14, 0.52), // 0 hub, start of the tick
      Offset(0.50, 0.62), // 1
      Offset(0.64, 0.46), // 2
      Offset(0.26, 0.65), // 3
      Offset(0.38, 0.78), // 4 accent, the vertex
      Offset(0.76, 0.34), // 5
      Offset(0.66, 0.84), // 6 left behind
      Offset(0.84, 0.74), // 7 left behind
      Offset(0.88, 0.22), // 8 hub, end of the tick
    ],
    radii: [0.075, 0.055, 0.055, 0.055, 0.09, 0.055, 0.045, 0.045, 0.075],
    links: [SceneLink(0, 3), SceneLink(3, 4), SceneLink(4, 1), SceneLink(1, 2), SceneLink(2, 5), SceneLink(5, 8)],
  );

  /// Page 3: teacher <-> parent: two connected bubbles with the accent node (the message) between.
  static const SceneLayout bubbles = SceneLayout(
    nodes: [
      Offset(0.12, 0.38), // 0 teacher
      Offset(0.30, 0.30), // 1
      Offset(0.70, 0.30), // 2 parent
      Offset(0.12, 0.64), // 3
      Offset(0.50, 0.50), // 4 accent
      Offset(0.88, 0.38), // 5
      Offset(0.30, 0.66), // 6
      Offset(0.70, 0.66), // 7
      Offset(0.88, 0.64), // 8
    ],
    radii: [0.06, 0.05, 0.06, 0.05, 0.085, 0.05, 0.06, 0.05, 0.06],
    links: [
      SceneLink(0, 1),
      SceneLink(1, 6),
      SceneLink(6, 3),
      SceneLink(3, 0),
      SceneLink(2, 5),
      SceneLink(5, 8),
      SceneLink(8, 7),
      SceneLink(7, 2),
      SceneLink(4, 6, dashed: true),
      SceneLink(4, 7, dashed: true),
    ],
    bubbles: [(Offset(0.21, 0.51), 0.26), (Offset(0.79, 0.51), 0.26)],
  );

  static final List<SceneLayout> intro = [classGrid, checks, bubbles];

  // ---- success glyphs: scattered nodes assemble into a shape ----

  static SceneLayout _scatter(int n, int seed, List<double> radii) {
    final r = math.Random(seed);
    return SceneLayout(
        nodes: [for (var i = 0; i < n; i++) Offset(0.08 + 0.84 * r.nextDouble(), 0.08 + 0.84 * r.nextDouble())], radii: radii);
  }

  static const List<EmNodeRole> envelopeRoles = [EmNodeRole.hub, EmNodeRole.hub, EmNodeRole.hub, EmNodeRole.hub, EmNodeRole.accent];
  static final List<SceneLayout> envelope = [
    _scatter(5, 11, const [0.06, 0.06, 0.06, 0.06, 0.075]),
    const SceneLayout(
      nodes: [Offset(0.12, 0.26), Offset(0.88, 0.26), Offset(0.88, 0.78), Offset(0.12, 0.78), Offset(0.5, 0.56)],
      radii: [0.07, 0.07, 0.07, 0.07, 0.09],
      links: [SceneLink(0, 1), SceneLink(1, 2), SceneLink(2, 3), SceneLink(3, 0), SceneLink(0, 4), SceneLink(1, 4)],
    ),
  ];

  static const List<EmNodeRole> checkRoles = [EmNodeRole.hub, EmNodeRole.node, EmNodeRole.accent, EmNodeRole.node, EmNodeRole.hub];
  static final List<SceneLayout> check = [
    _scatter(5, 5, const [0.06, 0.05, 0.075, 0.05, 0.06]),
    const SceneLayout(
      nodes: [Offset(0.16, 0.54), Offset(0.30, 0.70), Offset(0.42, 0.80), Offset(0.66, 0.50), Offset(0.88, 0.24)],
      radii: [0.07, 0.055, 0.09, 0.055, 0.07],
      links: [SceneLink(0, 1), SceneLink(1, 2), SceneLink(2, 3), SceneLink(3, 4)],
    ),
  ];
}

/// Paints [layouts] blended at [progress]. Pure function of [progress.value]:
/// no state, no timers; it repaints when [progress] notifies.
class NodeScenePainter extends CustomPainter {
  NodeScenePainter({
    required this.layouts,
    required this.roles,
    required this.progress,
    this.palette = EmNetworkPalette.standard,
    this.pulse,
  }) : super(repaint: Listenable.merge([progress, pulse]));

  final List<SceneLayout> layouts;
  final List<EmNodeRole> roles;
  final ValueListenable<double> progress;
  final EmNetworkPalette palette;

  /// 0..1: the accent node swells and settles (a finished action).
  final Animation<double>? pulse;

  /// Scene progress, clamped to the layouts: exposed for tests.
  double get value => progress.value.clamp(0.0, (layouts.length - 1).toDouble());

  static const double linkWidth = 0.022;
  static const double dashLength = 0.05;
  static const double dashGap = 0.025;

  final Paint _paint = Paint()..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    final p = value;
    final i = math.min(p.floor(), layouts.length - 2);
    final t = layouts.length == 1 ? 0.0 : p - i;
    final a = layouts[layouts.length == 1 ? 0 : i];
    final b = layouts[layouts.length == 1 ? 0 : i + 1];
    final s = math.min(size.width, size.height);
    final origin = Offset((size.width - s) / 2, (size.height - s) / 2);
    Offset at(Offset u) => origin + u * s;
    Offset pos(int k) => at(Offset.lerp(a.nodes[k], b.nodes[k], t)!);

    // bubbles
    _paint.style = PaintingStyle.fill;
    for (final (layout, w) in [(a, 1 - t), (b, t)]) {
      if (w <= 0) continue;
      for (final (c, r) in layout.bubbles) {
        _paint.color = palette.solid.withAlpha((255 * 0.45 * w).round());
        canvas.drawCircle(at(c), r * s, _paint);
      }
    }

    // links: union of both layouts, alpha by presence
    final keys = <int, (SceneLink, double, double)>{};
    for (final l in a.links) {
      keys[l.key] = (l, 1, 0);
    }
    for (final l in b.links) {
      final prev = keys[l.key];
      keys[l.key] = (prev == null || t > 0.5 ? l : prev.$1, prev == null ? 0 : 1, 1);
    }
    _paint
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..strokeWidth = linkWidth * s;
    for (final (link, from, to) in keys.values) {
      final w = from + (to - from) * t;
      if (w <= 0.01) continue;
      _paint.color = palette.dashed.withAlpha((255 * w).round());
      final p0 = pos(link.a), p1 = pos(link.b);
      if (!link.dashed) {
        canvas.drawLine(p0, p1, _paint);
      } else {
        final len = (p1 - p0).distance;
        final dash = dashLength * s, gap = dashGap * s;
        for (var d = 0.0; d < len; d += dash + gap) {
          canvas.drawLine(Offset.lerp(p0, p1, d / len)!, Offset.lerp(p0, p1, math.min(len, d + dash) / len)!, _paint);
        }
      }
    }

    // nodes
    _paint.style = PaintingStyle.fill;
    final bump = math.sin(math.pi * (pulse?.value ?? 0).clamp(0.0, 1.0));
    for (var k = 0; k < roles.length; k++) {
      _paint.color = switch (roles[k]) {
        EmNodeRole.hub => palette.hub,
        EmNodeRole.node => palette.node,
        EmNodeRole.accent => palette.accent,
      };
      final r = (a.radii[k] + (b.radii[k] - a.radii[k]) * t) * s * (roles[k] == EmNodeRole.accent ? 1 + 0.12 * bump : 1);
      canvas.drawCircle(pos(k), r, _paint);
    }
  }

  @override
  bool shouldRepaint(NodeScenePainter old) =>
      old.layouts != layouts || old.roles != roles || old.progress != progress || old.palette != palette || old.pulse != pulse;
}

/// The scene in a repaint-isolated box; fills its parent (the scene is square and centred).
class EmNodeScene extends StatelessWidget {
  const EmNodeScene({
    super.key,
    required this.layouts,
    required this.roles,
    required this.progress,
    this.palette = EmNetworkPalette.standard,
    this.pulse,
    this.semanticLabel,
  });

  final List<SceneLayout> layouts;
  final List<EmNodeRole> roles;
  final ValueListenable<double> progress;
  final EmNetworkPalette palette;
  final Animation<double>? pulse;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final paint = RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: NodeScenePainter(layouts: layouts, roles: roles, progress: progress, palette: palette, pulse: pulse),
      ),
    );
    return semanticLabel == null ? ExcludeSemantics(child: paint) : Semantics(label: semanticLabel, image: true, child: paint);
  }
}

/// A [PageController]'s fractional page as a listenable (`PageController.page`
/// itself only exists once attached).
class PageOffset extends ValueListenable<double> {
  PageOffset(this.controller);
  final PageController controller;

  @override
  double get value => controller.hasClients && controller.position.haveDimensions
      ? (controller.page ?? controller.initialPage.toDouble())
      : controller.initialPage.toDouble();

  @override
  void addListener(VoidCallback listener) => controller.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => controller.removeListener(listener);
}

/// Node-and-link page indicator: one node per page joined by links. The link
/// after page i fills as [progress] goes i -> i+1 (so it follows the finger),
/// and a node fills once the link into it is full.
class EmNodeIndicator extends StatelessWidget {
  const EmNodeIndicator(
      {super.key, required this.count, required this.progress, this.height = 24, this.palette = EmNetworkPalette.standard});
  final int count;
  final ValueListenable<double> progress;
  final double height;
  final EmNetworkPalette palette;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(count * 44.0, height),
        painter: NodeIndicatorPainter(count: count, progress: progress, palette: palette),
      ),
    );
  }
}

class NodeIndicatorPainter extends CustomPainter {
  NodeIndicatorPainter({required this.count, required this.progress, required this.palette}) : super(repaint: progress);
  final int count;
  final ValueListenable<double> progress;
  final EmNetworkPalette palette;

  /// Fill of link i (0..1) and of node i (0..1) at the current progress: exposed for tests.
  double linkFill(int i) => (progress.value - i).clamp(0.0, 1.0);
  double nodeFill(int i) => i == 0 ? 1 : linkFill(i - 1);

  static const double nodeRadius = 6;
  final Paint _p = Paint()..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    final gap = (size.width - 2 * nodeRadius) / math.max(1, count - 1);
    Offset c(int i) => Offset(nodeRadius + gap * i, size.height / 2);
    _p
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    for (var i = 0; i < count - 1; i++) {
      _p.color = palette.solid;
      canvas.drawLine(c(i), c(i + 1), _p);
      final f = linkFill(i);
      if (f > 0) {
        _p.color = palette.hub;
        canvas.drawLine(c(i), Offset.lerp(c(i), c(i + 1), f)!, _p);
      }
    }
    for (var i = 0; i < count; i++) {
      final f = nodeFill(i);
      _p
        ..style = PaintingStyle.fill
        ..color = palette.solid;
      canvas.drawCircle(c(i), nodeRadius, _p);
      if (f > 0) {
        _p.color = palette.hub;
        canvas.drawCircle(c(i), nodeRadius * f, _p);
      }
      // the accent ring on the node you are on
      final on = (1 - (progress.value - i).abs()).clamp(0.0, 1.0);
      if (on > 0) {
        _p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = palette.accent.withAlpha((255 * on).round());
        canvas.drawCircle(c(i), nodeRadius + 3, _p);
      }
    }
  }

  @override
  bool shouldRepaint(NodeIndicatorPainter old) => old.count != count || old.progress != progress || old.palette != palette;
}

/// Static progress for reduce-motion / tests.
class FixedProgress extends ValueNotifier<double> {
  FixedProgress(super.value);
}
