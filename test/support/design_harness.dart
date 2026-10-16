import 'dart:io';
import 'dart:typed_data';
import 'package:eldermin_teacher_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';

/// Loads the bundled Plus Jakarta Sans so layout/goldens use real glyph widths
/// (flutter_test otherwise falls back to the wide "Ahem" font).
Future<void> loadDesignFonts() async {
  final loader = FontLoader('PlusJakartaSans');
  for (final f in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    final b = File('assets/fonts/PlusJakartaSans-$f.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(Uint8List.fromList(b).buffer)));
  }
  await loader.load();

  // flutter_test does not load the Material icon font; without it every icon
  // renders as a box in goldens.
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final f = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (f.existsSync()) {
      final icons = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.view(Uint8List.fromList(f.readAsBytesSync()).buffer)));
      await icons.load();
    }
  }
}

/// Pumps [child] at logical [width] x [height], [textScale] and [dir], inside
/// the app theme. Returns once first-frame animations (chart 600 ms) finish.
Future<void> pumpEm(
  WidgetTester t,
  Widget child, {
  double width = 360,
  double height = 800,
  double textScale = 1.0,
  TextDirection dir = TextDirection.ltr,
  bool scaffold = true,
  EdgeInsets padding = const EdgeInsets.all(16),
  bool settle = true,
}) async {
  t.view.physicalSize = Size(width, height);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    builder: (context, c) => Directionality(
      textDirection: dir,
      child: MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)), child: c!),
    ),
    home: scaffold
        ? Scaffold(body: SafeArea(child: SingleChildScrollView(padding: padding, child: child)))
        : child,
  ));
  if (settle) await t.pump(const Duration(seconds: 1));
}

/// Asserts the finder's widget is at least [min] x [min] dp.
void expectMinTouch(WidgetTester t, Finder f, {double min = 48}) {
  final s = t.getSize(f.first);
  expect(s.width, greaterThanOrEqualTo(min - 0.01), reason: 'width ${s.width}');
  expect(s.height, greaterThanOrEqualTo(min - 0.01), reason: 'height ${s.height}');
}

/// Fails if the last frame raised a layout exception (RenderFlex overflow etc).
void expectNoLayoutErrors(WidgetTester t) {
  final e = t.takeException();
  expect(e, isNull, reason: e?.toString().split('\n').first);
}

/// Pumps [builder] at 1.0x and 1.3x text scale, narrow width, LTR and RTL,
/// asserting no layout exception in any combination.
Future<void> expectRobust(WidgetTester t, Widget Function() builder, {double width = 320}) async {
  for (final scale in [1.0, 1.3]) {
    for (final dir in [TextDirection.ltr, TextDirection.rtl]) {
      await pumpEm(t, builder(), width: width, textScale: scale, dir: dir);
      expectNoLayoutErrors(t);
    }
  }
}
