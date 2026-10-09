// Shared helpers of the Phase 7a walkthroughs (messages / notifications / student leaves) against the LOCAL STUB (tool/dev/stub_server.py +
// stub_7a.py, dummy data). Not a test itself (no `_test.dart` suffix). Prints SHOT:<name> / STUB:<path> markers for tool/dev/capture_7a.sh.
// Anti-loop rules: every wait / retry loop is capped (waitFor 25 s, leaveToShell 6 attempts), a step has a 240 s wall-clock budget (`guard`),
// `leaveScreen` taps Discard (never Cancel), and the shell script has a watchdog (no marker for 180 s -> abort).
import 'package:eldermin_teacher_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ignore_for_file: avoid_print, curly_braces_in_flow_control_structures

final _step = Stopwatch()..start();
const _budget = Duration(seconds: 240);

void guard(String where) {
  if (_step.elapsed > _budget) throw TestFailure('step time budget (${_budget.inSeconds}s) exceeded in $where');
}

/// Starts a new 240 s step.
void step(String name) {
  _step
    ..reset()
    ..start();
  print('STEP:$name');
}

Future<void> settle(WidgetTester t, [int ms = 1200]) {
  guard('settle');
  return t.pump(Duration(milliseconds: ms));
}

/// Lets transitions finish BEFORE the marker, then gives the capture real time.
Future<void> shot(WidgetTester t, String name, {int ms = 1800}) async {
  await t.pump(Duration(milliseconds: ms));
  print('SHOT:$name');
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1400)));
  await t.pump(const Duration(milliseconds: 100));
}

Future<void> stub(WidgetTester t, String path) async {
  print('STUB:$path');
  await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
  await t.pump(const Duration(milliseconds: 300));
}

Future<void> waitFor(WidgetTester t, Finder f, {int seconds = 25}) async {
  for (var i = 0; i < seconds * 5; i++) {
    guard('waitFor $f');
    if (f.evaluate().isNotEmpty) return;
    await t.pump(const Duration(milliseconds: 200));
  }
  throw TestFailure('Timed out waiting for $f');
}

/// Real waiting (the stub, the 10 s chat poll): bounded by [seconds].
Future<void> realWait(WidgetTester t, int seconds) async {
  guard('realWait');
  await t.runAsync(() => Future<void>.delayed(Duration(seconds: seconds)));
  await t.pump(const Duration(milliseconds: 300));
}

Finder navLabel(String label) => find.descendant(of: find.byType(BottomNavigationBar), matching: find.text(label));

/// Signs in (or switches to) [email]: handles the first-run intro, an already signed-in session (signs out first) and the login form.
Future<void> signInAs(WidgetTester t, String email) async {
  app.main();
  await t.pump(const Duration(milliseconds: 300));
  for (var i = 0; i < 150; i++) {
    guard('boot');
    if (find.text('Skip').evaluate().isNotEmpty || find.text('Sign in').evaluate().isNotEmpty || find.byType(BottomNavigationBar).evaluate().isNotEmpty) break;
    await t.pump(const Duration(milliseconds: 200));
  }
  if (find.text('Skip').evaluate().isNotEmpty) {
    await t.tap(find.text('Skip'));
    for (var i = 0; i < 125; i++) {
      guard('after intro');
      if (find.text('Sign in').evaluate().isNotEmpty || find.byType(BottomNavigationBar).evaluate().isNotEmpty) break;
      await t.pump(const Duration(milliseconds: 200));
    }
  }
  if (find.byType(BottomNavigationBar).evaluate().isNotEmpty) {
    // a previous run left a session: sign out through More (one confirm dialog)
    await t.tap(navLabel('More'));
    await settle(t, 800);
    final out = find.byKey(const Key('more_sign_out'));
    await t.scrollUntilVisible(out, 250, scrollable: find.byType(Scrollable).last, maxScrolls: 12);
    await t.drag(find.byType(Scrollable).last, const Offset(0, -200)); // clear the bottom nav bar
    await settle(t, 500);
    await t.tap(out);
    await waitFor(t, find.byKey(const Key('confirm_dialog_confirm')));
    await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
    await t.pump(const Duration(seconds: 3));
    // after a sign-out on a fresh install (keychain session survived the uninstall) the first-run intro can come first
    for (var i = 0; i < 125; i++) {
      guard('after sign-out');
      if (find.text('Sign in').evaluate().isNotEmpty) break;
      if (find.text('Skip').evaluate().isNotEmpty) {
        await t.tap(find.text('Skip'));
        await t.pump(const Duration(milliseconds: 600));
      }
      await t.pump(const Duration(milliseconds: 200));
    }
    await waitFor(t, find.text('Sign in'), seconds: 5);
  }
  await settle(t);
  await stub(t, '/__stub/reset-state');
  await t.enterText(find.widgetWithText(TextFormField, 'Email'), email);
  await t.enterText(find.widgetWithText(TextFormField, 'Password'), 'StubPass123');
  await t.tap(find.text('Sign in'));
  await waitFor(t, navLabel('Classes'));
  await settle(t, 2500);
}

Future<void> confirmDiscardIfShown(WidgetTester t) async {
  final discard = find.byKey(const Key('confirm_dialog_confirm'));
  if (discard.evaluate().isNotEmpty) {
    await t.tap(discard); // Discard, never Cancel
    await settle(t, 800);
  }
}

Future<void> leaveScreen(WidgetTester t) async {
  await t.pageBack();
  await settle(t, 900);
  await confirmDiscardIfShown(t);
}

/// Pops screens until the bottom-nav shell is visible: at most 6 attempts.
Future<void> leaveToShell(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    if (find.byType(BottomNavigationBar).evaluate().isNotEmpty && find.byType(Dialog).evaluate().isEmpty) return;
    await leaveScreen(t);
  }
  if (find.byType(BottomNavigationBar).evaluate().isEmpty) throw TestFailure('could not get back to the home shell after 6 attempts');
}

/// Stub ids (stub_server._oid / stub_7a._oid).
String sid(int i) => '64f${(0x200 + i).toRadixString(16).padLeft(21, '0')}';
String oid7(int n) => '64e${n.toRadixString(16).padLeft(21, '0')}';

/// Teacher thread n (1..4): stub_7a._oid(0x900 + 0x100 + n).
String threadId(int n) => oid7(0x900 + 0x100 + n);
