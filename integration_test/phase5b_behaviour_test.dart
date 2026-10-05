// Phase 5b behaviour walkthrough against the LOCAL STUB (dummy data):
//   tool/dev/capture_walkthrough.sh <sim> <out-dir> integration_test/phase5b_behaviour_test.dart
import 'package:eldermin_teacher_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// ignore_for_file: avoid_print

Future<void> settle(WidgetTester t, [int ms = 1200]) => t.pump(Duration(milliseconds: ms));

Future<void> shot(WidgetTester t, String name, {int ms = 2000}) async {
  print('SHOT:$name');
  await t.pump(Duration(milliseconds: ms));
}

Future<void> stub(WidgetTester t, String path) async {
  print('STUB:$path');
  await t.pump(const Duration(milliseconds: 900));
}

Future<void> waitFor(WidgetTester t, Finder f, {int seconds = 25}) async {
  for (var i = 0; i < seconds * 5; i++) {
    if (f.evaluate().isNotEmpty) return;
    await t.pump(const Duration(milliseconds: 200));
  }
  throw TestFailure('Timed out waiting for $f');
}

Finder navLabel(String label) => find.descendant(of: find.byType(BottomNavigationBar), matching: find.text(label));

Finder get page => find.descendant(of: find.byType(ListView).first, matching: find.byType(Scrollable)).first;

Future<void> scroll(WidgetTester t, double dy) async {
  await t.drag(page, Offset(0, -dy));
  await settle(t, 600);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Phase 5b behaviour walkthrough against the stub', (t) async {
    app.main();
    await t.pump(const Duration(milliseconds: 300));
    await waitFor(t, find.text('Skip'));
    await t.tap(find.text('Skip'));
    await waitFor(t, find.text('Sign in'));
    await settle(t);
    await stub(t, '/__stub/reset-state');
    await t.enterText(find.widgetWithText(TextFormField, 'Email'), 'teacher@stub.test');
    await t.enterText(find.widgetWithText(TextFormField, 'Password'), 'StubPass123');
    await t.tap(find.text('Sign in'));
    await waitFor(t, navLabel('Classes'));
    await settle(t, 2500);
    await t.tap(navLabel('Classes'));
    await settle(t, 1200);

    // ── list: my entries, then my classes ──
    await t.tap(find.byKey(const ValueKey('module_behaviour')));
    await waitFor(t, find.byKey(const Key('beh_new_fab')));
    await waitFor(t, find.text('Late to class'));
    await settle(t, 1200);
    await shot(t, '5b_40_behaviour_mine');
    await t.tap(find.textContaining('My classes ('));
    await settle(t, 800);
    await shot(t, '5b_41_behaviour_my_classes');

    // ── quick log: validation, picker, save ──
    await t.tap(find.byKey(const Key('beh_new_fab')));
    await waitFor(t, find.byKey(const Key('beh_submit')));
    await settle(t, 800);
    await shot(t, '5b_42_log_form');
    await t.tap(find.byKey(const Key('beh_submit')));
    await settle(t, 800);
    await shot(t, '5b_43_log_validation_errors');
    await t.tap(find.byKey(const Key('beh_student_picker')));
    await waitFor(t, find.byKey(const Key('beh_picker_search')));
    await settle(t, 1500);
    await shot(t, '5b_44_student_picker');
    await t.enterText(find.byKey(const Key('beh_picker_search')), 'Aarav');
    await settle(t, 600);
    await t.tap(find.textContaining('Aarav').first);
    await settle(t, 800);
    await t.tap(find.byKey(const Key('cat_leadership')));
    await settle(t, 400);
    await t.enterText(find.byKey(const Key('beh_description')), 'Organised the group and made sure everyone had a turn.');
    await settle(t, 600);
    await shot(t, '5b_45_log_form_filled');
    // server problem (a bare 500, as the backend gives for a body mongoose rejects): everything is kept
    await stub(t, '/__stub/mode?feature=behaviourcreate&value=500');
    await t.tap(find.byKey(const Key('beh_submit')));
    await waitFor(t, find.byKey(const Key('beh_submit_error')));
    await settle(t, 600);
    await t.drag(page, const Offset(0, 2000));
    await settle(t, 600);
    await shot(t, '5b_46_log_server_error');
    await stub(t, '/__stub/mode?feature=behaviourcreate&value=ok');
    await t.tap(find.byKey(const Key('beh_submit')));
    await waitFor(t, find.byKey(const Key('beh_new_fab')));
    await settle(t, 1200);
    await shot(t, '5b_47_behaviour_after_save', ms: 600);

    // ── student history (with Tarbiyah) ──
    await t.tap(find.text('Leadership').first);
    await waitFor(t, find.byKey(const Key('beh_student_log')));
    await settle(t, 2000);
    await shot(t, '5b_50_student_history');
    await scroll(t, 700);
    await shot(t, '5b_51_student_history_tarbiyah');
    await t.pageBack();
    await settle(t, 800);

    // ── Student 360 link ──
    await t.pageBack();
    await settle(t, 500);
    await t.tap(find.byKey(const ValueKey('module_students')));
    await waitFor(t, find.byKey(const Key('students_count')));
    await settle(t, 1500);
    await t.tap(find.textContaining('Aarav').first);
    await waitFor(t, find.byKey(const Key('student_behaviour_history')), seconds: 25);
    await t.ensureVisible(find.byKey(const Key('student_behaviour_history')));
    await settle(t, 800);
    await shot(t, '5b_52_student_360_behaviour_link');
    await t.pageBack();
    await settle(t, 600);
    await t.pageBack();
    await settle(t, 600);

    // ── 403 ──
    await stub(t, '/__stub/mode?feature=behaviour&value=403');
    await t.tap(find.byKey(const ValueKey('module_behaviour')));
    await waitFor(t, find.byKey(const Key('screen_forbidden')));
    await settle(t, 800);
    await shot(t, '5b_91_behaviour_403');
    await stub(t, '/__stub/mode?feature=behaviour&value=ok');
  });
}
