// Dev tool (NOT part of the normal suite: lives under tool/). Rasterises the
// reversed logomark SVG into the PNGs flutter_native_splash needs:
//
//   flutter test tool/brand/export_splash_assets_test.dart
//
// Output (transparent PNG, 4x density, logomark EmLogomark.splashHeight dp tall):
//   assets/splash/splash_logo.png       iOS + Android < 12 (centred on the navy background)
//   assets/splash/splash_android12.png  1152x1152 canvas for the Android 12+ splash icon
//                                       (logo kept well inside the 768px circular mask safe zone)
import 'dart:io';
import 'dart:ui' as ui;
import 'package:eldermin_teacher_app/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _save(WidgetTester t, GlobalKey key, String path, double ratio) async {
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await t.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: ratio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
    // ignore: avoid_print
    print('wrote $path ${image.width}x${image.height}');
  });
}

void main() {
  testWidgets('export splash PNGs', (t) async {
    const ratio = 4.0;
    Future<void> render(Widget child, GlobalKey key) async {
      await t.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Align(alignment: Alignment.topLeft, child: RepaintBoundary(key: key, child: child)),
      ));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await t.pump();
    }

    final a = GlobalKey();
    await render(const EmLogomark(height: EmLogomark.splashHeight, reversed: true), a);
    await _save(t, a, 'assets/splash/splash_logo.png', ratio);

    final b = GlobalKey();
    await render(
      const SizedBox(width: 288, height: 288, child: Center(child: EmLogomark(height: EmLogomark.splashHeight, reversed: true))),
      b,
    );
    await _save(t, b, 'assets/splash/splash_android12.png', ratio);
  });
}
