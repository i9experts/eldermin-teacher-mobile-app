import 'package:eldermin_teacher_app/app/modules/calendar/views/calendar_widgets.dart';
import 'package:eldermin_teacher_app/core/design/design.dart';
import 'package:eldermin_teacher_app/core/models/calendar/calendar_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/design_harness.dart';

void main() {
  setUpAll(loadDesignFonts);

  group('CalendarTypeLabel: the event colour is a dot, the text is always ink', () {
    for (final hex in ['#FFE08A', '#101010', '#7F77DD', '#F0F0F0', '#EE9F27']) {
      testWidgets('server colour $hex keeps AA text', (t) async {
        final color = Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));
        await pumpEm(t, CalendarTypeLabel(color: color, label: 'Exam'));
        final text = t.widget<Text>(find.text('EXAM'));
        expect(text.style!.color, EmColors.ink);
        expect(contrastRatio(text.style!.color!, EmColors.surface), greaterThanOrEqualTo(4.5));
        final dot = t.widget<Container>(find.byKey(const Key('cal_type_dot')));
        expect((dot.decoration as BoxDecoration).color, color);
        expect((dot.decoration as BoxDecoration).shape, BoxShape.circle);
      });
    }
    testWidgets('robust at 1.3x / RTL, long label ellipsizes', (t) async {
      await expectRobust(t, () => const CalendarTypeLabel(color: EmColors.primary, label: 'Admission deadline and other long names'), width: 160);
    });
    testWidgets('every default event type renders with ink text', (t) async {
      for (final type in CalendarEventType.values) {
        await pumpEm(t, CalendarTypeLabel(color: type.color, label: type.label));
        expect(t.widget<Text>(find.text(type.label.toUpperCase())).style!.color, EmColors.ink);
      }
    });
  });
}
