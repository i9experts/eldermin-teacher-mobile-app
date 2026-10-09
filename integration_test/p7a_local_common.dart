// Shared helpers of the Phase 7 part 1 LOCAL end-to-end verification (integration_test/p7a_local_test.dart) against the LOCAL backend
// (isolated DB eldermin_teacher_verify, NOT staging, NOT the stub). Not a test itself. Builds on e2e_common.dart (same anti-loop rules:
// capped waits, 240 s step budget, `leaveScreen` taps Discard never Cancel, shell watchdog in tool/dev/capture_p7a.sh).
import 'package:eldermin_teacher_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'e2e_common.dart';

export 'e2e_common.dart' hide shot;

// ignore_for_file: avoid_print, curly_braces_in_flow_control_structures

const p7ShotStart = int.fromEnvironment('P7_SHOT_START', defaultValue: 1);
const p7Ids = String.fromEnvironment('P7_IDS'); // "T1=<id>;T2=<id>;..." (fixture ids, not secrets)
const p7Names = String.fromEnvironment('P7_NAMES'); // "S8=<student name>;S2=<student name>" (dummy)
const p7Scenario = String.fromEnvironment('P7_SCENARIO');
var _p7Shot = p7ShotStart - 1;

/// `T1`, `ptm0`, `fx1`, `lv2`, `my0`... -> id (from the seed's out/p7_ids.txt through --dart-define).
String pid(String name) {
  for (final kv in p7Ids.split(';')) {
    final i = kv.indexOf('=');
    if (i > 0 && kv.substring(0, i) == name) return kv.substring(i + 1);
  }
  throw TestFailure('unknown fixture id $name (P7_IDS=$p7Ids)');
}

String pname(String key) {
  for (final kv in p7Names.split(';')) {
    final i = kv.indexOf('=');
    if (i > 0 && kv.substring(0, i) == key) return kv.substring(i + 1);
  }
  throw TestFailure('unknown name $key');
}

/// Screenshot marker `p7a_NN_<name>`; lets transitions finish first, then gives the capture real time.
Future<void> pshot(WidgetTester t, String name, {int ms = 1500}) async {
  await t.pump(Duration(milliseconds: ms));
  _p7Shot++;
  print('SHOT:p7a_${_p7Shot.toString().padLeft(2, '0')}_$name');
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1400)));
  await t.pump(const Duration(milliseconds: 100));
}

/// A structured result line for the report (the shell script passes every `RESULT:` line to the log).
void result(String what, Object? value) => print('RESULT: $what = $value');

/// Real waiting (backend / poll), capped at [seconds].
Future<void> realWait(WidgetTester t, int seconds) async {
  guard('realWait');
  await t.runAsync(() => Future<void>.delayed(Duration(seconds: seconds)));
  await t.pump(const Duration(milliseconds: 300));
}

/// The count shown by a `_CountBadge` with [key] ('0' when there is no badge).
String badgeOf(String key) {
  final badge = find.descendant(of: find.byKey(Key(key)), matching: find.byType(Badge));
  if (badge.evaluate().isEmpty) return '0';
  final txt = find.descendant(of: badge, matching: find.byType(Text));
  return txt.evaluate().isEmpty ? '?' : (txt.evaluate().first.widget as Text).data ?? '?';
}

String badges() => 'tab=${badgeOf('messages_badge')} bell=${badgeOf('bell_badge')}';

/// Boots the app, skips the intro, signs out an old session if one survived, signs in with [email]/[password].
Future<void> bootAndSignIn(WidgetTester t, String email, String password) async {
  print('MARK boot: app.main');
  app.main();
  await t.pump(const Duration(milliseconds: 300));
  for (var i = 0; i < 150; i++) {
    guard('boot');
    if (find.text('Skip').evaluate().isNotEmpty || find.text('Sign in').evaluate().isNotEmpty || find.byType(BottomNavigationBar).evaluate().isNotEmpty) break;
    await t.pump(const Duration(milliseconds: 200));
  }
  // a session left by an earlier run can be ended by the server mid-boot (401 on /auth/me after a DB reset): let the app settle first
  for (var i = 0; i < 12; i++) {
    await t.pump(const Duration(milliseconds: 500));
  }
  if (find.text('Skip').evaluate().isNotEmpty) {
    await t.tap(find.text('Skip'));
    for (var i = 0; i < 125; i++) {
      guard('after intro');
      if (find.text('Sign in').evaluate().isNotEmpty || find.byType(BottomNavigationBar).evaluate().isNotEmpty) break;
      await t.pump(const Duration(milliseconds: 200));
    }
  }
  print('MARK boot: settled; shell=${find.byType(BottomNavigationBar).evaluate().isNotEmpty} skip=${find.text('Skip').evaluate().isNotEmpty} signIn=${find.text('Sign in').evaluate().isNotEmpty}');
  if (find.byType(BottomNavigationBar).evaluate().isNotEmpty) {
    // sign out through More (one confirm dialog); the first-run intro may come before the login form
    await t.tap(navLabel('More'));
    await settle(t, 900);
    await t.scrollUntilVisible(find.byKey(const Key('more_sign_out')), 200, scrollable: find.byType(Scrollable).last);
    await settle(t, 500);
    await t.tap(find.byKey(const Key('more_sign_out')));
    await waitFor(t, find.byKey(const Key('confirm_dialog_confirm')));
    await t.tap(find.byKey(const Key('confirm_dialog_confirm')));
    await t.pump(const Duration(seconds: 3));
    for (var i = 0; i < 40; i++) {
      guard('after sign-out');
      if (find.text('Skip').evaluate().isNotEmpty) {
        await t.tap(find.text('Skip'));
        await t.pump(const Duration(milliseconds: 600));
      }
      if (find.text('Sign in').evaluate().isNotEmpty) break;
      await t.pump(const Duration(milliseconds: 200));
    }
  }
  await settle(t);
  await signIn(t, email, password);
}

/// Opens an entry of the More tab by its title.
Future<void> openFromMore(WidgetTester t, String title, Finder until) async {
  await t.tap(navLabel('More'));
  await settle(t, 1000);
  final entry = find.text(title);
  await t.scrollUntilVisible(entry, 250, scrollable: find.byType(Scrollable).last, maxScrolls: 14);
  await settle(t, 400);
  await t.tap(entry);
  await waitFor(t, until);
  await settle(t, 1200);
}

/// Pull-to-refresh on the topmost list.
Future<void> pullToRefresh(WidgetTester t) async {
  await t.drag(find.byType(Scrollable).last, const Offset(0, 500));
  await t.pump(const Duration(milliseconds: 600));
  await t.pump(const Duration(seconds: 2));
}

/// Picks [target] in the app's own date sheet opened by tapping [pickerKey]: next-month chevron taps (max 3), then the day cell.
Future<void> pickDate(WidgetTester t, Key pickerKey, DateTime target) async {
  await t.ensureVisible(find.byKey(pickerKey));
  await settle(t, 300);
  await t.tap(find.byKey(pickerKey));
  await waitFor(t, find.text('Select date'));
  await settle(t, 600);
  final now = DateTime.now();
  var months = (target.year - now.year) * 12 + target.month - now.month;
  for (var i = 0; i < 3 && months > 0; i++, months--) {
    await t.tap(find.byIcon(Icons.chevron_right_rounded).first);
    await settle(t, 500);
  }
  await t.tap(find.descendant(of: find.byType(GridView), matching: find.text('${target.day}')).first);
  await settle(t, 900);
  if (find.text('Select date').evaluate().isNotEmpty) {
    // the cell was disabled (e.g. an end date before the start date): the sheet stays open; close it with its X (bounded, one tap)
    print('MARK date ${target.day} not selectable: sheet still open, closing it');
    await t.tap(find.byIcon(Icons.close_rounded).first);
    await settle(t, 900);
  }
}

/// Everything identifiable about the screen on top: AppBar title text and which well-known keys exist.
String landed() {
  final bar = find.byType(AppBar);
  final titles = <String>[];
  for (final e in bar.evaluate()) {
    for (final w in find.descendant(of: find.byWidget(e.widget), matching: find.byType(Text)).evaluate()) {
      final s = (w.widget as Text).data ?? '';
      if (s.isNotEmpty) titles.add(s);
    }
  }
  const keys = [
    'chat_title', 'chat_input', 'chat_closed_banner', 'messages_new', 'ptm_student', 'ptm_not_found', 'ptm_new', 'fx_title', 'fx_tabs', 'fx_not_found', 'leave_detail', 'leave_decided',
    'leaves_tabs', 'leave_not_found', 'leave_apply', 'screen_empty', 'screen_error', 'screen_unavailable', 'screen_forbidden', 'notif_mark_all', 'notif_filter',
  ];
  final present = [for (final k in keys) if (find.byKey(Key(k)).evaluate().isNotEmpty) k];
  final onShell = find.byType(BottomNavigationBar).evaluate().isNotEmpty;
  return 'appbar=${titles.take(3).toList()} keys=$present shellVisible=$onShell';
}

Future<void> openInbox(WidgetTester t) async {
  await t.tap(navLabel('Messages'));
  await settle(t, 1500);
  await waitFor(t, find.byKey(const Key('messages_new')));
}

Future<void> openNotifications(WidgetTester t) async {
  await t.tap(find.byIcon(Icons.notifications_none_rounded).first);
  await waitFor(t, find.byKey(const Key('notif_mark_all')));
  await settle(t, 1500);
}
