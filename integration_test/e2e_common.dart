// Shared helpers of the END-TO-END WRITE verification (integration_test/e2e_writes_local_test.dart) against the LOCAL backend
// (isolated DB eldermin_teacher_verify, NOT staging, NOT the stub). Not a test itself (no `_test.dart` suffix).
// Anti-loop rules (same as local_backend_smoke_test.dart): every wait/retry loop is capped, `leaveScreen` taps Discard (never Cancel),
// each step has a 240 s wall-clock budget (`guard`), the whole run is bounded by tool/dev/capture_e2e_writes.sh (watchdog).
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ignore_for_file: avoid_print, curly_braces_in_flow_control_structures

const e2eTeacherEmail = String.fromEnvironment('LOCAL_TEACHER_EMAIL');
const e2eTeacherPassword = String.fromEnvironment('LOCAL_TEACHER_PASSWORD');
const e2eClassEmail = String.fromEnvironment('LOCAL_CLASS_EMAIL');
const e2eClassPassword = String.fromEnvironment('LOCAL_CLASS_PASSWORD');
const e2eBaseUrl = String.fromEnvironment('API_BASE_URL');
const e2eScenario = String.fromEnvironment('E2E_SCENARIO');
const e2eShotStart = int.fromEnvironment('E2E_SHOT_START', defaultValue: 1);
const e2eFlagDir = String.fromEnvironment('E2E_FLAG_DIR');
// deep-link scenario inputs (dummy local values, passed at run time only)
const e2eResetToken = String.fromEnvironment('E2E_RESET_TOKEN');
const e2eResetNewPassword = String.fromEnvironment('E2E_RESET_NEW_PASSWORD');
const e2eLoginJwt = String.fromEnvironment('E2E_LOGIN_JWT');
const e2eLoginJwt2 = String.fromEnvironment('E2E_LOGIN_JWT2');
const e2eSlug = String.fromEnvironment('LOCAL_SCHOOL_SLUG');

final e2eFailures = <String>[];
var _shotNo = e2eShotStart - 1;

final _stepWatch = Stopwatch()..start();
const _stepBudget = Duration(seconds: 240);

void guard(String where) {
  if (_stepWatch.elapsed > _stepBudget)
    throw TestFailure('step time budget (${_stepBudget.inSeconds}s) exceeded in $where');
}

Future<void> settle(WidgetTester t, [int ms = 1200]) {
  guard('settle');
  return t.pump(Duration(milliseconds: ms));
}

/// Prints the SHOT marker that tool/dev/capture_e2e_writes.sh turns into a simulator screenshot (`e2e_NN_<name>.png`).
Future<void> shot(WidgetTester t, String name, {int ms = 1500}) async {
  await t.pump(Duration(milliseconds: ms));
  _shotNo++;
  print('SHOT:e2e_${_shotNo.toString().padLeft(2, '0')}_$name');
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1400)));
  await t.pump(const Duration(milliseconds: 100));
}

Future<void> waitFor(WidgetTester t, Finder f, {int seconds = 25}) async {
  for (var i = 0; i < seconds * 5; i++) {
    guard('waitFor $f');
    if (f.evaluate().isNotEmpty) return;
    await t.pump(const Duration(milliseconds: 200));
  }
  throw TestFailure('Timed out waiting for $f');
}

Future<bool> waitForAny(WidgetTester t, List<Finder> fs, {int seconds = 25}) async {
  for (var i = 0; i < seconds * 5; i++) {
    guard('waitForAny');
    if (fs.any((f) => f.evaluate().isNotEmpty)) return true;
    await t.pump(const Duration(milliseconds: 200));
  }
  return false;
}

Finder navLabel(String label) => find.descendant(of: find.byType(BottomNavigationBar), matching: find.text(label));
Finder tf(String label) => find.widgetWithText(TextFormField, label);

Finder keyPrefix(String p) => find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith(p));

/// Rows keyed `<prefix><24-hex ObjectId>`.
Finder idKeyed(String prefix) =>
    find.byWidgetPredicate((w) => w.key is ValueKey<String> && RegExp('^$prefix[0-9a-f]{24}\$').hasMatch((w.key as ValueKey<String>).value));

String keyOf(Element e) => (e.widget.key as ValueKey<String>).value;

Iterable<String> allTexts() => [
      for (final w in find.byType(Text).evaluate().map((e) => e.widget as Text)) w.data ?? w.textSpan?.toPlainText() ?? '',
    ];

String textOf(WidgetTester t, Finder f) {
  final w = t.widget(f);
  return w is Text ? (w.data ?? w.textSpan?.toPlainText() ?? '') : '';
}

String fieldText(WidgetTester t, Finder keyed) {
  final e = find.descendant(of: keyed, matching: find.byType(EditableText));
  if (e.evaluate().isNotEmpty) return t.widget<EditableText>(e.first).controller.text;
  final w = t.widget(keyed);
  return w is EditableText ? w.controller.text : '';
}

const _errorKeys = ['screen_error', 'section_error', 'screen_forbidden', 'section_forbidden', 'screen_unavailable', 'section_unavailable'];

void expectNoBadStates(String where) {
  for (final k in _errorKeys) {
    if (find.byKey(Key(k)).evaluate().isNotEmpty) throw TestFailure('$where shows $k');
  }
}

Future<void> step(WidgetTester t, String name, Future<void> Function() body) async {
  print('STEP $name');
  _stepWatch
    ..reset()
    ..start();
  try {
    await body();
    final ex = t.takeException();
    if (ex != null) throw TestFailure('uncaught exception: $ex');
    print('STEP_OK $name');
  } catch (e) {
    final msg = '$e'.split('\n').first;
    print('STEP_FAIL $name: $msg');
    e2eFailures.add('$name: $msg');
    try {
      await shot(t, 'FAILED_${name.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}', ms: 300);
    } catch (_) {}
    t.takeException();
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    try {
      _stepWatch
        ..reset()
        ..start();
      await leaveToShell(t);
    } catch (e2) {
      print('NOTE recoverToShell: $e2');
    }
  }
}

/// Taps the CONFIRM ("Discard") button of an unsaved-changes dialog. NEVER taps Cancel / Keep editing. One tap, no loop.
Future<bool> confirmDiscardIfShown(WidgetTester t) async {
  for (final f in [
    find.byKey(const Key('discard_confirm')),
    find.byKey(const Key('confirm_dialog_confirm')),
    find.widgetWithText(TextButton, 'Discard'),
    find.widgetWithText(FilledButton, 'Discard'),
  ]) {
    if (f.evaluate().isNotEmpty) {
      await t.tap(f.first);
      await settle(t, 900);
      return true;
    }
  }
  return false;
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
    if (!await confirmDiscardIfShown(t)) await leaveScreen(t);
  }
  if (find.byType(BottomNavigationBar).evaluate().isEmpty) throw TestFailure('could not get back to the home shell after 6 attempts');
}

Future<void> scroll(WidgetTester t, double dy) async {
  await t.drag(find.byType(Scrollable).last, Offset(0, -dy));
  await settle(t, 600);
}

Future<void> toTop(WidgetTester t) async {
  await t.drag(find.byType(Scrollable).last, const Offset(0, 5000));
  await settle(t, 500);
}

Future<void> tapText(WidgetTester t, String text, {bool last = false}) async {
  final f = last ? find.text(text).last : find.text(text).first;
  await t.scrollUntilVisible(f, 250, scrollable: find.byType(Scrollable).last, maxScrolls: 40);
  await settle(t, 300);
  await t.tap(f);
  await settle(t, 900);
}

Future<void> openClassesModule(WidgetTester t, String id) async {
  await t.tap(navLabel('Classes'));
  await settle(t, 1000);
  final tile = find.byKey(ValueKey('module_$id'));
  await t.scrollUntilVisible(tile, 250, scrollable: find.byType(Scrollable).last, maxScrolls: 20);
  for (var i = 0; i < 3; i++) {
    await t.ensureVisible(tile);
    await settle(t, 400);
    await t.tap(tile, warnIfMissed: false);
    await settle(t, 1500);
    if (tile.evaluate().isEmpty) return;
  }
  throw TestFailure('could not open Classes module $id after 3 taps');
}

/// Types the credentials and taps Sign in. Returns once the shell shows, or throws with the on-screen error text. Capped at 25 s.
Future<void> signIn(WidgetTester t, String email, String password) async {
  await t.enterText(tf('Email'), email);
  await t.enterText(tf('Password'), password);
  await t.tap(find.text('Sign in'));
  for (var i = 0; i < 100; i++) {
    guard('signIn');
    await t.pump(const Duration(milliseconds: 250));
    if (find.byType(BottomNavigationBar).evaluate().isNotEmpty) {
      await settle(t, 2500);
      return;
    }
    for (final w in t.widgetList<Text>(find.byType(Text))) {
      final s = w.data ?? '';
      if (s.contains('nvalid') || s.contains('Something went wrong') || s.contains('credentials')) throw TestFailure('login error shown: $s');
    }
  }
  throw TestFailure('login did not reach Home');
}

Future<void> signOutViaUi(WidgetTester t) async {
  await t.tap(navLabel('More'));
  await settle(t, 900);
  await t.scrollUntilVisible(find.byKey(const Key('more_sign_out')), 200, scrollable: find.byType(Scrollable).last);
  await settle(t, 500);
  await t.tap(find.byKey(const Key('more_sign_out')));
  await waitFor(t, find.text('Sign out of Eldermin Teacher?'));
  await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
  await waitFor(t, find.text('Sign in'));
  await settle(t);
}

/// Asks the host script (tool/dev/capture_e2e_writes.sh) to change the isolated DB RIGHT NOW (stale-client situations), then waits (max 60 s)
/// for its flag file. The script only knows a fixed list of actions on eldermin_teacher_verify.
Future<void> dbAction(WidgetTester t, String name, {String arg = ''}) async {
  if (e2eFlagDir.isEmpty) throw TestFailure('E2E_FLAG_DIR not set');
  final flag = File('$e2eFlagDir/$name.flag');
  if (flag.existsSync()) flag.deleteSync();
  print('DBACTION:$name:$arg');
  for (var i = 0; i < 300; i++) {
    guard('dbAction $name');
    if (flag.existsSync()) {
      print('DBACTION_DONE:$name');
      return;
    }
    await t.pump(const Duration(milliseconds: 200));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  }
  throw TestFailure('db action $name not acknowledged within 60 s');
}

Future<void> startRun(WidgetTester t, void Function() appMain) async {
  appMain();
  await t.pump(const Duration(milliseconds: 300));
  await waitFor(t, find.text('Skip'));
  await t.tap(find.text('Skip'));
  await waitFor(t, find.text('Sign in'));
  await settle(t);
}
