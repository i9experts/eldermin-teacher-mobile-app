// D5 walkthrough against the LOCAL STUB (tool/dev/stub_server.py, dummy data): the migrated app bars on six representative screens, a
// confirm dialog and a bottom sheet, at text scale 1.0 and 1.3. Prints SHOT:<name>/STUB:<path> markers for tool/dev/capture_walkthrough.sh.
//
//   tool/dev/capture_walkthrough.sh <sim> <out-dir> integration_test/d5_appbars_shots_test.dart
import 'package:eldermin_teacher_app/app/modules/more/views/more_screen.dart';
import 'package:eldermin_teacher_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// ignore_for_file: avoid_print

Future<void> settle(WidgetTester t, [int ms = 1200]) => t.pump(Duration(milliseconds: ms));

Future<void> shot(WidgetTester t, String name, {int ms = 1500}) async {
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

Finder navLabel(String label) => find.descendant(of: find.byKey(const Key('app_shell_nav')), matching: find.text(label));
Finder tf(String hint) => find.widgetWithText(TextFormField, hint);

Future<void> signIn(WidgetTester t, String email) async {
  await t.enterText(tf('Email'), email);
  await t.enterText(tf('Password'), 'StubPass123');
  await t.tap(find.text('Sign in'));
  await settle(t, 800);
}

Future<void> openModule(WidgetTester t, String id, String tag) async {
  await t.tap(navLabel('Classes'));
  await settle(t, 1200);
  final tile = find.byKey(ValueKey('module_$id'));
  await t.scrollUntilVisible(tile, 250, scrollable: find.byType(Scrollable).last);
  await settle(t, 300);
  await t.tap(tile);
  await settle(t, 2800);
  await shot(t, tag);
  await back(t);
  await t.drag(find.byType(Scrollable).last, const Offset(0, 4000));
  await settle(t, 300);
}

Future<void> back(WidgetTester t) async {
  await t.pageBack(); // finds the app bar's circle by its "Back" tooltip
  await settle(t, 900);
}

Future<void> screens(WidgetTester t, String scale) async {
  await openModule(t, 'homework', 'd5_homework_$scale');
  await openModule(t, 'assessments', 'd5_assessments_$scale');
  await openModule(t, 'lesson_plans', 'd5_lesson_plans_$scale');
  await t.tap(navLabel('More'));
  await settle(t, 1200);
  await t.scrollUntilVisible(find.text('School calendar'), 250, scrollable: find.byType(Scrollable).last);
  await t.tap(find.text('School calendar'));
  await settle(t, 2800);
  await shot(t, 'd5_calendar_$scale');
  await back(t);
  await t.drag(find.byType(Scrollable).last, const Offset(0, 4000));
  await t.tap(navLabel('Home'));
  await settle(t, 800);
  await t.tap(find.byIcon(Icons.notifications_none_rounded).first);
  await settle(t, 2500);
  await shot(t, 'd5_notifications_$scale');
  await back(t);

  // message thread: first row of the inbox (two-line title + overflow action)
  await t.tap(navLabel('Messages'));
  await settle(t, 2200);
  final row = find.byWidgetPredicate((w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('thread_'));
  await waitFor(t, row);
  await t.tap(row.first);
  await settle(t, 2500);
  await shot(t, 'd5_thread_$scale');
  await back(t);

  // bottom sheet: new message -> student picker
  await t.tap(find.byKey(const Key('messages_new')));
  await settle(t, 2500);
  await waitFor(t, find.byKey(const Key('new_student_picker')));
  await shot(t, 'd5_message_new_$scale');
  await t.tap(find.byKey(const Key('new_student_picker')));
  await settle(t, 2000);
  await shot(t, 'd5_sheet_picker_$scale');
  await t.tapAt(const Offset(200, 60)); // barrier
  await settle(t, 800);
  await back(t);
  await t.tap(navLabel('Home'));
  await settle(t, 800);

  // confirm dialog: More -> Sign out
  await t.tap(navLabel('More'));
  await waitFor(t, find.byType(MoreScreen));
  await settle(t, 500);
  await t.scrollUntilVisible(find.byKey(const Key('more_sign_out')), 200, scrollable: find.descendant(of: find.byType(MoreScreen), matching: find.byType(Scrollable)));
  await settle(t, 500);
  await t.tap(find.byKey(const Key('more_sign_out')));
  await waitFor(t, find.byKey(const Key('confirm_dialog_confirm')));
  await settle(t, 900); // let the dialog finish fading in before the capture
  await shot(t, 'd5_confirm_dialog_$scale');
  await t.tap(find.byKey(const Key('confirm_dialog_cancel')));
  await settle(t, 600);
  await t.drag(find.byType(Scrollable).last, const Offset(0, 3000));
  await t.tap(navLabel('Home'));
  await settle(t, 800);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('D5 app bars, dialog and sheet walkthrough', (t) async {
    app.main();
    await t.pump(const Duration(milliseconds: 300));
    await waitFor(t, find.text('Skip'));
    await t.tap(find.text('Skip'));
    await waitFor(t, find.text('Sign in'));
    await settle(t);
    await stub(t, '/__stub/reset-state');
    await signIn(t, 'classteacher@stub.test');
    await waitFor(t, find.byKey(const Key('app_shell_nav')));
    await settle(t, 4000);
    await screens(t, 'normal');
    binding.platformDispatcher.textScaleFactorTestValue = 1.3;
    await settle(t, 1200);
    await screens(t, 'scale13');
    binding.platformDispatcher.clearTextScaleFactorTestValue();
    print('DONE');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
