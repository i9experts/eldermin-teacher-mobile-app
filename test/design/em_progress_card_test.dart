import 'package:eldermin_teacher_app/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/design_harness.dart';
import '../support/layout_probe.dart';

/// D6 follow-up: the action of `EmProgressRingCard` ("Mark remaining") must NOT wrap at text scale 1.0 at any phone width 320-430
/// (wrapping at 1.3x is acceptable). The card puts the action under the title / ring at its natural width.
void main() {
  setUpAll(loadDesignFonts);

  for (final w in probeWidths) {
    testWidgets('"Mark remaining" stays on one line at ${w.toInt()} x 1.0', (t) async {
      await pumpEm(
        t,
        EmProgressRingCard(title: 'Attendance target', subtitle: '28 of 30 students marked', value: 0.93, centerText: '93%', centerCaption: 'present', action: EmSecondaryButton(label: 'Mark remaining', onPressed: () {})),
        width: w,
        padding: const EdgeInsets.symmetric(horizontal: EmSpacing.screenH),
      );
      expectNoLayoutError(t);
      expectOneLine(t, find.text('Mark remaining'), scale: 1.0);
      expectInsideScreen(t, find.text('Mark remaining'), w);
    });
    for (final d in probeDirs) {
      testWidgets(probeName('progress card at 1.3 (may wrap, never overflows)', w, 1.3, d), (t) async {
        await pumpEm(
          t,
          EmProgressRingCard(title: 'Attendance target', subtitle: '28 of 30 students marked', value: 0.93, centerText: '93%', centerCaption: 'present', action: EmSecondaryButton(label: 'Mark remaining', onPressed: () {})),
          width: w,
          textScale: 1.3,
          dir: d,
          padding: const EdgeInsets.symmetric(horizontal: EmSpacing.screenH),
        );
        expectNoLayoutError(t);
        expectInsideScreen(t, find.text('Mark remaining'), w);
      });
    }
  }
}
