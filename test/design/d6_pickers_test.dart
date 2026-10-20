import 'package:eldermin_teacher_app/core/design/design.dart';
import 'package:eldermin_teacher_app/core/widgets/app_date_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/design_harness.dart';
import '../support/layout_probe.dart';

/// D6: the date / month / weekday pickers on tokens: same API and results, laid out at every width / scale / direction, 48dp cells.
void main() {
  setUpAll(loadDesignFonts);

  Future<void> open(WidgetTester t, double w, double sc, TextDirection d, Future<void> Function(BuildContext) opener) async {
    t.view.physicalSize = Size(w, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      theme: buildEmTheme(),
      home: probeWrap(Scaffold(body: Builder(builder: (c) => TextButton(onPressed: () => opener(c), child: const Text('open')))), scale: sc, dir: d),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
  }

  for (final w in probeWidths) {
    for (final sc in probeScales) {
      for (final d in probeDirs) {
        testWidgets(probeName('date picker', w, sc, d), (t) async {
          await open(t, w, sc, d, (c) => showAppDatePicker(c, initialDate: DateTime(2026, 10, 20), firstDate: DateTime(2026, 10, 1), lastDate: DateTime(2026, 12, 31)));
          expectNoLayoutError(t);
          expect(find.text('Select date'), findsOneWidget);
          // a 48dp-tall cell around a day
          final cell = find.ancestor(of: find.text('21'), matching: find.byType(InkWell)).first;
          expect(t.getSize(cell).height, greaterThanOrEqualTo(48));
          expectInsideScreen(t, find.text('Jump to today'), w);
        });
        testWidgets(probeName('month + weekday pickers', w, sc, d), (t) async {
          await open(t, w, sc, d, (c) => showAppMonthPicker(c, initialMonth: DateTime(2026, 10)));
          expectNoLayoutError(t);
          expect(find.text('Select month'), findsOneWidget);
          expectInsideScreen(t, find.text('Oct'), w);
          await t.tap(find.text('Nov'));
          await t.pumpAndSettle();
          await t.tap(find.text('open'));
          await t.pumpAndSettle();
        });
        testWidgets(probeName('weekday picker', w, sc, d), (t) async {
          int? picked;
          await open(t, w, sc, d, (c) async => picked = await showAppWeekdayPicker(c, initialWeekday: 2));
          expectNoLayoutError(t);
          expect(find.text('Wednesday'), findsOneWidget);
          await t.tap(find.text('Friday'));
          await t.pumpAndSettle();
          expect(picked, 4);
        });
      }
    }
  }

  testWidgets('date picker returns the tapped day and respects the bounds', (t) async {
    DateTime? picked;
    await open(t, 360, 1.0, TextDirection.ltr, (c) async => picked = await showAppDatePicker(c, initialDate: DateTime(2026, 10, 20), firstDate: DateTime(2026, 10, 10), lastDate: DateTime(2026, 10, 25)));
    await t.tap(find.text('5')); // before firstDate: disabled
    await t.pumpAndSettle();
    expect(find.text('Select date'), findsOneWidget);
    await t.tap(find.text('22'));
    await t.pumpAndSettle();
    expect(picked, DateTime(2026, 10, 22));
  });
}
