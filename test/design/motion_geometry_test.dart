import 'dart:io';
import 'dart:ui';
import 'package:eldermin_teacher_app/core/design/design.dart';
import 'package:flutter_test/flutter_test.dart';

/// The SVGs are the source of truth for the logomark; the painter's constants
/// must match them.
void main() {
  Color hex(String s) => Color(0xFF000000 | int.parse(s.substring(1), radix: 16));
  double d(String s) => double.parse(s);

  for (final reversed in [false, true]) {
    test('${reversed ? 'logomark_reversed' : 'logomark'}.svg matches EmLogomarkGeometry and the palette', () {
      final svg = File('assets/brand/${reversed ? 'logomark_reversed' : 'logomark'}.svg').readAsStringSync();
      final palette = reversed ? EmNetworkPalette.reversed : EmNetworkPalette.standard;

      final vb = RegExp(r'viewBox="([\d. ]+)"').firstMatch(svg)!.group(1)!.split(' ').map(d).toList();
      expect(Rect.fromLTWH(vb[0], vb[1], vb[2], vb[3]), EmLogomarkGeometry.viewBox);

      // circles, in document order = EmLogomarkGeometry.nodes order
      final circles = RegExp(r'<circle cx="([\d.]+)" cy="([\d.]+)" r="([\d.]+)" fill="(#[0-9A-Fa-f]{6})"').allMatches(svg).toList();
      expect(circles, hasLength(EmLogomarkGeometry.nodes.length));
      for (var i = 0; i < circles.length; i++) {
        final n = EmLogomarkGeometry.nodes[i];
        expect(Offset(d(circles[i].group(1)!), d(circles[i].group(2)!)), n.centre, reason: 'node $i centre');
        expect(d(circles[i].group(3)!), n.radius, reason: 'node $i radius');
        final want = switch (n.role) {
          EmNodeRole.hub => palette.hub,
          EmNodeRole.node => palette.node,
          EmNodeRole.accent => palette.accent,
        };
        expect(hex(circles[i].group(4)!), want, reason: 'node $i colour');
      }

      // the two stroke groups: solid then dashed
      final groups = RegExp(
              r'<g fill="none" stroke="(#[0-9A-Fa-f]{6})" stroke-width="(\d+)"(?: stroke-dasharray="(\d+) (\d+)")?[^>]*>(.*?)</g>',
              dotAll: true)
          .allMatches(svg)
          .toList();
      expect(groups, hasLength(2));
      expect(hex(groups[0].group(1)!), palette.solid);
      expect(d(groups[0].group(2)!), EmLogomarkGeometry.solidWidth);
      expect(hex(groups[1].group(1)!), palette.dashed);
      expect(d(groups[1].group(2)!), EmLogomarkGeometry.dashedWidth);
      expect(d(groups[1].group(3)!), EmLogomarkGeometry.dashLength);
      expect(d(groups[1].group(4)!), EmLogomarkGeometry.dashGap);

      // solid: M x y V y2 | M x y H x2 ; dashed: M x y L x2 y2
      // solid: M x y V y2 | M x y H x2 ; dashed: M x y L x2 y2
      final solidPaths = RegExp(r'd="M(\d+) (\d+)([VH])(\d+)"').allMatches(groups[0].group(5)!).toList();
      expect(solidPaths, hasLength(EmLogomarkGeometry.solidLinks.length));
      for (var i = 0; i < solidPaths.length; i++) {
        final m = solidPaths[i];
        final from = Offset(d(m.group(1)!), d(m.group(2)!));
        final to = m.group(3) == 'V' ? Offset(from.dx, d(m.group(4)!)) : Offset(d(m.group(4)!), from.dy);
        expect(EmLogomarkGeometry.solidLinks[i].from, from, reason: 'solid $i');
        expect(EmLogomarkGeometry.solidLinks[i].to, to, reason: 'solid $i');
      }
      final dashed = RegExp(r'd="M(\d+) (\d+)L(\d+) (\d+)"').allMatches(groups[1].group(5)!).toList();
      expect(dashed, hasLength(EmLogomarkGeometry.dashedLinks.length));
      for (var i = 0; i < dashed.length; i++) {
        final m = dashed[i];
        expect(EmLogomarkGeometry.dashedLinks[i].from, Offset(d(m.group(1)!), d(m.group(2)!)), reason: 'dashed $i');
        expect(EmLogomarkGeometry.dashedLinks[i].to, Offset(d(m.group(3)!), d(m.group(4)!)), reason: 'dashed $i');
      }
    });
  }
}
