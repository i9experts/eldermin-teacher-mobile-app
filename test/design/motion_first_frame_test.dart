import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:eldermin_teacher_app/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Uint8List> _raster(WidgetTester t, Widget child) async {
  final key = GlobalKey();
  await t.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Align(alignment: Alignment.topLeft, child: RepaintBoundary(key: key, child: child)),
  ));
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300))); // svg asset load
  await t.pump();
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return (await t.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 4);
    return (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
  }))!;
}

/// Share of pixels whose channels differ by more than [tol].
double _diff(Uint8List a, Uint8List b, {int tol = 24}) {
  expect(a.length, b.length);
  var bad = 0;
  for (var i = 0; i < a.length; i += 4) {
    for (var c = 0; c < 4; c++) {
      if ((a[i + c] - b[i + c]).abs() > tol) {
        bad++;
        break;
      }
    }
  }
  return bad / (a.length / 4);
}

void main() {
  for (final reversed in [true, false]) {
    testWidgets('frame 0 of the animated mark = the SVG (${reversed ? 'reversed, native splash' : 'standard'})', (t) async {
      final svg = await _raster(t, EmLogomark(height: EmLogomark.splashHeight, reversed: reversed));
      final painted = await _raster(
        t,
        EmLogomark(height: EmLogomark.splashHeight, reversed: reversed, drive: const EmNetworkDrive()),
      );
      // anti-aliasing only (measured ~0.27% of pixels, all on shape edges): same geometry and colours
      expect(_diff(svg, painted), lessThan(0.004));
    });
  }

  testWidgets('the diff metric does see a real difference (charge light on)', (t) async {
    final base = await _raster(t, const EmLogomark(height: EmLogomark.splashHeight, reversed: true, drive: EmNetworkDrive()));
    final lit = await _raster(
      t,
      EmLogomark(
        height: EmLogomark.splashHeight,
        reversed: true,
        drive: EmNetworkDrive(charge: const AlwaysStoppedAnimation(0.35), dashPhase: const AlwaysStoppedAnimation(0.5)),
      ),
    );
    expect(_diff(base, lit), greaterThan(0.002));
  });
}
