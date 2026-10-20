import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// D6 layout probes: every classroom screen is rendered at these widths x text scales x directions and must lay out without an overflow
/// (a RenderFlex overflow surfaces as a test exception), keep its key labels on one line and keep actions on screen.
const probeWidths = <double>[320, 360, 375, 430];
const probeScales = <double>[1.0, 1.3];
const probeDirs = <TextDirection>[TextDirection.ltr, TextDirection.rtl];

/// Wraps [screen] so the text scale and the direction are forced for this render.
Widget probeWrap(Widget screen, {double scale = 1.0, TextDirection dir = TextDirection.ltr}) => Builder(
      builder: (c) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
        child: Directionality(textDirection: dir, child: screen),
      ),
    );

String probeName(String what, double w, double s, TextDirection d) => '$what at ${w.toInt()} x $s ${d == TextDirection.rtl ? 'RTL' : 'LTR'}';

/// No layout exception was thrown while pumping (overflow, unbounded constraints ...). To find the offending widget run the single probe
/// with `FlutterError.onError = FlutterError.dumpErrorToConsole;` at the top of the test.
void expectNoLayoutError(WidgetTester t) {
  final e = t.takeException();
  expect(e, isNull, reason: e is FlutterError ? e.toStringDeep().split('\n').take(4).join(' ') : e?.toString());
}

/// Every match of [f] is laid out on a single line: its height is at most one line of its own style at [scale] (plus rounding slack).
void expectOneLine(WidgetTester t, Finder f, {required double scale}) {
  final matches = f.evaluate().toList();
  expect(matches, isNotEmpty, reason: 'nothing found for $f');
  for (final e in matches) {
    final w = e.widget;
    if (w is! Text) continue;
    final style = DefaultTextStyle.of(e).style.merge(w.style);
    final line = (style.fontSize ?? 14) * scale * (style.height ?? 1.4) + 2;
    final h = t.getSize(find.byWidget(w)).height;
    expect(h, lessThanOrEqualTo(line), reason: '"${w.data}" wrapped: height $h > one line $line');
  }
}

/// Every match of [f] is fully inside the [width] x anything screen.
void expectInsideScreen(WidgetTester t, Finder f, double width) {
  final matches = f.evaluate().toList();
  expect(matches, isNotEmpty, reason: 'nothing found for $f');
  for (final e in matches) {
    final r = t.getRect(find.byWidget(e.widget));
    expect(r.left >= -0.5 && r.right <= width + 0.5, isTrue, reason: '${e.widget.runtimeType} at $r is outside the $width dp screen');
  }
}

/// Probe environment for test files whose boot helpers are shared with ordinary tests: a probe test sets it, [probeSize] / [probeHome]
/// apply it inside the existing helper, and [ProbeEnv.reset] (call it in tearDown) restores the defaults.
class ProbeEnv {
  ProbeEnv._();
  static double? width;
  static double scale = 1.0;
  static TextDirection dir = TextDirection.ltr;

  static void set(double w, double s, TextDirection d) {
    width = w;
    scale = s;
    dir = d;
  }

  static void reset() {
    width = null;
    scale = 1.0;
    dir = TextDirection.ltr;
  }
}

Size probeSize(Size s) => Size(ProbeEnv.width ?? s.width, s.height);

Widget probeHome(Widget screen) => probeWrap(screen, scale: ProbeEnv.scale, dir: ProbeEnv.dir);
