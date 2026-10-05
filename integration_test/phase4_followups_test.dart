// Phase 4 FOLLOW-UP walkthrough (pending-grading, my timetable, PTM today agenda, 404 fallbacks), driven against the LOCAL STUB
// (tool/dev/stub_server.py, dummy data). Prints SHOT:<name> / STUB:<path> markers for
// tool/dev/capture_walkthrough.sh. Not a unit test.
//
//   tool/dev/capture_walkthrough.sh <sim> <out-dir> integration_test/phase4_followups_test.dart
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

/// Scrolls so that [f] sits at the top of the scroll view (alignment 0), regardless of where it was.
Future<void> reveal(WidgetTester t, Finder f) async {
  await Scrollable.ensureVisible(t.element(f.last), alignment: 0.0, duration: Duration.zero);
  await settle(t, 700);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Phase 4 follow-ups walkthrough against the stub', (t) async {
    app.main();
    await t.pump(const Duration(milliseconds: 300));
    await waitFor(t, find.text('Skip'));
    await t.tap(find.text('Skip'));
    await waitFor(t, find.text('Sign in'));
    await settle(t);

    // ── New endpoints available ──
    await stub(t, '/__stub/reset-state');
    await signIn(t, 'teacher@stub.test');
    await waitFor(t, find.text("Today's classes"));
    await waitFor(t, find.text('Homework to grade'));
    await settle(t, 1500);

    // Today's classes with the split-group-only slot (only the NEW endpoint returns it) + Week A/B tags.
    await reveal(t, find.text("Today's classes"));
    await shot(t, '53_home_today_split_group_slot');

    // Homework: total + per-assignment counts from pending-grading.
    await reveal(t, find.text('Homework to grade'));
    await shot(t, '52_home_homework_pending_grading_card');

    // PTMs: remaining today, collapsed "Earlier today", upcoming.
    await reveal(t, find.text('Parent meetings'));
    await shot(t, '50_home_ptm_remaining_earlier_upcoming');
    await t.tap(find.byKey(const Key('ptm_earlier_toggle')));
    await settle(t, 600);
    await reveal(t, find.text('Parent meetings'));
    await shot(t, '51_home_ptm_earlier_today_expanded');

    // ── Fallback: both new endpoints answer 404 (server without feat/staff-portal follow-ups) ──
    await stub(t, '/__stub/mode?feature=new&value=404');
    await scrollTop(t);
    await pull(t);
    await settle(t, 2500);
    await reveal(t, find.text("Today's classes"));
    await shot(t, '54_home_fallback_timetable_old_path');
    await reveal(t, find.text('Homework to grade'));
    await shot(t, '55_home_fallback_homework_n_plus_1');

    print('WALKTHROUGH_DONE');
  });
}
