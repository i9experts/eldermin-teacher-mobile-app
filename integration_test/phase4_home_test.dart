// Phase 4 on-device walkthrough of the Home dashboard, driven against the LOCAL STUB
// (tool/dev/stub_server.py, dummy data). Prints SHOT:<name> / STUB:<path> markers for
// tool/dev/capture_walkthrough.sh. Not a unit test.
//
//   tool/dev/capture_walkthrough.sh <sim> <out-dir> integration_test/phase4_home_test.dart
import 'package:eldermin_teacher_app/app/modules/more/views/more_screen.dart';
import 'package:eldermin_teacher_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// ignore_for_file: avoid_print

Future<void> settle(WidgetTester t, [int ms = 1200]) => t.pump(Duration(milliseconds: ms));

Future<void> shot(WidgetTester t, String name, {int ms = 2600}) async {
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

Finder tf(String hint) => find.widgetWithText(TextFormField, hint);

Future<void> signIn(WidgetTester t, String email) async {
  await t.enterText(tf('Email'), email);
  await t.enterText(tf('Password'), 'StubPass123');
  await t.tap(find.text('Sign in'));
  await settle(t, 800);
}

Future<void> pull(WidgetTester t) async {
  await t.drag(find.byType(SingleChildScrollView).first, const Offset(0, 500));
  await t.pump(const Duration(milliseconds: 100));
  await settle(t, 2500);
}

Future<void> scrollDown(WidgetTester t, double dy) async {
  await t.drag(find.byType(SingleChildScrollView).first, Offset(0, -dy));
  await settle(t, 600);
}

Future<void> scrollTop(WidgetTester t) async {
  await t.drag(find.byType(SingleChildScrollView).first, const Offset(0, 3000));
  await settle(t, 600);
}

Future<void> signOutViaUi(WidgetTester t) async {
  await t.tap(find.text('More'));
  await waitFor(t, find.byType(MoreScreen));
  await settle(t, 500);
  await t.scrollUntilVisible(find.byKey(const Key('more_sign_out')), 200,
      scrollable: find.descendant(of: find.byType(MoreScreen), matching: find.byType(Scrollable)));
  await settle(t, 500);
  await t.tap(find.byKey(const Key('more_sign_out')));
  await waitFor(t, find.text('Sign out of Eldermin Teacher?'));
  await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
  await waitFor(t, find.text('Sign in'));
  await settle(t);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Phase 4 Home walkthrough against the stub', (t) async {
    app.main();
    await t.pump(const Duration(milliseconds: 300));
    await waitFor(t, find.text('Skip'));
    await t.tap(find.text('Skip'));
    await waitFor(t, find.text('Sign in'));
    await settle(t);

    // ── Plain teacher, slow timetable + homework so the shimmer is capturable ──
    await stub(t, '/__stub/reset-state');
    await stub(t, '/__stub/mode?feature=timetable&value=slow');
    await stub(t, '/__stub/mode?feature=homework&value=slow');
    await signIn(t, 'teacher@stub.test');
    await waitFor(t, find.text('Home'));
    await settle(t, 1200);
    await shot(t, '30_home_loading_shimmer', ms: 1500);
    await waitFor(t, find.text('Today\'s classes'));
    await settle(t, 7500);
    await shot(t, '31_home_plain_teacher_top');
    await scrollDown(t, 420);
    await shot(t, '32_home_plain_teacher_middle');
    await scrollDown(t, 900);
    await shot(t, '33_home_plain_teacher_bottom');
    await stub(t, '/__stub/mode?feature=timetable&value=ok');
    await stub(t, '/__stub/mode?feature=homework&value=ok');

    // ── One section error (PTM 500) ──
    await stub(t, '/__stub/mode?feature=ptm&value=500');
    await scrollTop(t);
    await pull(t);
    await scrollDown(t, 1500);
    await shot(t, '34_home_section_error_ptm_retry');

    // ── Empty states ──
    for (final f in ['ptm', 'fixtures', 'homework', 'lessonplans', 'timetable']) {
      await stub(t, '/__stub/mode?feature=$f&value=empty');
    }
    await scrollTop(t);
    await pull(t);
    await shot(t, '35_home_empty_states_top');
    await scrollDown(t, 900);
    await shot(t, '36_home_empty_states_bottom');

    // ── threads + unread-count 404 (not deployed): no badges, Messages section hidden ──
    await stub(t, '/__stub/mode?feature=threads&value=404');
    await stub(t, '/__stub/mode?feature=unread&value=404');
    await stub(t, '/__stub/mode?feature=fixtures&value=ok');
    await scrollTop(t);
    await pull(t);
    await shot(t, '37_home_unavailable_404_no_badges');
    await scrollDown(t, 900);
    await shot(t, '38_home_unavailable_404_bottom_no_messages_section');

    // ── Class teacher ──
    await signOutViaUi(t);
    await stub(t, '/__stub/reset-state');
    await signIn(t, 'classteacher@stub.test');
    await waitFor(t, find.text('Mark Attendance'));
    await settle(t, 1500);
    await shot(t, '40_home_class_teacher_not_marked');
    await stub(t, '/__stub/attendance?count=12');
    await pull(t);
    await scrollTop(t);
    await shot(t, '41_home_class_teacher_partly_marked');
    await scrollDown(t, 500);
    await shot(t, '42_home_class_teacher_middle');
    await scrollTop(t);
    await t.tap(find.byKey(const Key('mark_attendance_button')));
    await settle(t, 1200);
    await shot(t, '43_mark_attendance_route_shell');

    print('WALKTHROUGH_DONE');
  });
}
