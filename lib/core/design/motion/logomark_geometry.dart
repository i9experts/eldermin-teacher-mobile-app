import 'dart:ui';
import '../tokens/em_colors.dart';

/// Eldermin logomark geometry, in the SVG's own coordinates.
///
/// Single source of truth is assets/brand/logomark.svg (and the reversed
/// variant); `test/design/motion_geometry_test.dart` parses both files and
/// fails if these constants drift from them. PENDING BRAND APPROVAL, like the
/// SVGs.
class EmLogomarkGeometry {
  EmLogomarkGeometry._();

  /// SVG viewBox `150 60 1410 1670`.
  static const Rect viewBox = Rect.fromLTWH(150, 60, 1410, 1670);
  static const double aspect = 1410 / 1670;

  /// Index of each node in [nodes].
  static const int hubTop = 0, hubBottom = 1, nodeTop = 2, nodeBottom = 3, nodeMid = 4, centre = 5;

  static const List<EmNode> nodes = [
    EmNode(Offset(346.5, 253.5), 172.5, EmNodeRole.hub),
    EmNode(Offset(346.5, 1534.5), 172.5, EmNodeRole.hub),
    EmNode(Offset(1413, 253.5), 129, EmNodeRole.node),
    EmNode(Offset(1413, 1534.5), 129, EmNodeRole.node),
    EmNode(Offset(345, 895.5), 147, EmNodeRole.node),
    EmNode(Offset(1135.5, 894), 251, EmNodeRole.accent),
  ];

  static const double solidWidth = 58;
  static const List<EmLink> solidLinks = [
    EmLink(Offset(346, 253), Offset(346, 1535)),
    EmLink(Offset(346, 249), Offset(1413, 249)),
    EmLink(Offset(345, 901), Offset(1135, 901)),
    EmLink(Offset(346, 1554), Offset(1413, 1554)),
  ];

  static const double dashedWidth = 34;
  static const double dashLength = 52;
  static const double dashGap = 15;
  static const List<EmLink> dashedLinks = [
    EmLink(Offset(1368, 362), Offset(1226, 655)),
    EmLink(Offset(1226, 1122), Offset(1362, 1405)),
  ];
}

enum EmNodeRole { hub, node, accent }

class EmNode {
  const EmNode(this.centre, this.radius, this.role);
  final Offset centre;
  final double radius;
  final EmNodeRole role;
}

class EmLink {
  const EmLink(this.from, this.to);
  final Offset from;
  final Offset to;
  double get length => (to - from).distance;
}

/// Colours of the mark (from the SVGs) plus the colour of the travelling light.
class EmNetworkPalette {
  const EmNetworkPalette({
    required this.solid,
    required this.dashed,
    required this.hub,
    required this.node,
    required this.accent,
    required this.light,
  });

  final Color solid;
  final Color dashed;
  final Color hub;
  final Color node;
  final Color accent;
  final Color light;

  /// logomark.svg (on light surfaces).
  static const standard = EmNetworkPalette(
    solid: EmColors.primaryLight,
    dashed: EmColors.primaryMid,
    hub: EmColors.primaryDark,
    node: EmColors.primary,
    accent: EmColors.accent,
    light: EmColors.primary,
  );

  /// logomark_reversed.svg (on primaryDark).
  static const reversed = EmNetworkPalette(
    solid: EmColors.primaryMid,
    dashed: EmColors.primaryLight,
    hub: EmColors.onPrimaryDark,
    node: EmColors.primaryLight,
    accent: EmColors.accent,
    light: EmColors.onPrimaryDark,
  );

  /// [t] 0 = [a], 1 = [b].
  static EmNetworkPalette lerp(EmNetworkPalette a, EmNetworkPalette b, double t) {
    if (t <= 0) return a;
    if (t >= 1) return b;
    Color l(Color x, Color y) => Color.lerp(x, y, t)!;
    return EmNetworkPalette(
      solid: l(a.solid, b.solid),
      dashed: l(a.dashed, b.dashed),
      hub: l(a.hub, b.hub),
      node: l(a.node, b.node),
      accent: l(a.accent, b.accent),
      light: l(a.light, b.light),
    );
  }
}
