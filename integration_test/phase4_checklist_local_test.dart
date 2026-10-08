// PHASE 4 CHECKLIST, LOCAL verification (isolated DB eldermin_teacher_verify, NOT staging, NOT the stub, no shim). One scenario per run
// (--dart-define=E2E_SCENARIO=<home|refresh|offline|unreach|cap|tz>), driven by tool/dev/capture_phase4_local.sh (watchdog, screenshots,
// fixed list of DB / backend / proxy actions between taps). Credentials only via --dart-define. Anti-loop rules as in e2e_common.dart:
// every wait is capped, step budget 240 s, `leaveScreen` taps Discard never Cancel, nothing retries more than 3 times.
import 'package:eldermin_teacher_app/app/modules/auth/controllers/auth_controller.dart';
import 'package:eldermin_teacher_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';

import 'e2e_common.dart';

// ignore_for_file: avoid_print, curly_braces_in_flow_control_structures

const p4ShotStart = int.fromEnvironment('P4_SHOT_START', defaultValue: 1);
var _p4No = p4ShotStart - 1;

Future<void> p4shot(WidgetTester t, String name, {int ms = 1500}) async {
  await t.pump(Duration(milliseconds: ms));
  _p4No++;
  print('SHOT:p4_${_p4No.toString().padLeft(2, '0')}_$name');
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1400)));
  await t.pump(const Duration(milliseconds: 100));
}

Finder homeScroll() => find.byType(SingleChildScrollView).first;

Future<void> homeTop(WidgetTester t) async {
  await t.drag(homeScroll(), const Offset(0, 3000));
  await settle(t, 600);
}

Future<void> homeDown(WidgetTester t, double dy) async {
  await t.drag(homeScroll(), Offset(0, -dy));
  await settle(t, 600);
}

/// Real pull-to-refresh gesture on Home.
Future<void> pull(WidgetTester t, {int waitMs = 3500}) async {
  await homeTop(t);
  await t.drag(homeScroll(), const Offset(0, 500));
  await t.pump(const Duration(milliseconds: 100));
  await settle(t, waitMs);
}

String _texts(Finder within) => [
      for (final e in find.descendant(of: within, matching: find.byType(Text)).evaluate()) ((e.widget as Text).data ?? '').trim(),
    ].where((s) => s.isNotEmpty).join(' / ');

/// Prints what Home shows (text only: names are dummy fixtures). Returns nothing; the test logs are the evidence next to the screenshots.
void dumpHome(String who) {
  print('HOME[$who] time-of-day on device: ${DateTime.now().toIso8601String()} offset=${DateTime.now().timeZoneOffset} name=${DateTime.now().timeZoneName}');
  for (var i = 0; i < 12; i++) {
    final f = find.byKey(ValueKey('period_$i'));
    if (f.evaluate().isEmpty) break;
    print('HOME[$who] period_$i: ${_texts(f)}');
  }
  for (final k in ['ptm_label_today', 'ptm_earlier_toggle', 'ptm_label_upcoming']) {
    final f = find.byKey(Key(k));
    if (f.evaluate().isNotEmpty) print('HOME[$who] $k: ${_texts(f)}');
  }
  for (final e in idKeyedAnyPrefix(['ptm_', 'sub_covering_', 'sub_covered_']).evaluate()) {
    print('HOME[$who] ${keyOf(e)}: ${_texts(find.byWidget(e.widget))}');
  }
  print('HOME[$who] section_error count=${find.byKey(const Key('section_error')).evaluate().length} section_empty=${find.byKey(const Key('section_empty')).evaluate().length} loading=${find.byKey(const Key('section_loading')).evaluate().length}');
}

Finder idKeyedAnyPrefix(List<String> prefixes) => find.byWidgetPredicate((w) {
      final k = w.key;
      return k is ValueKey<String> && prefixes.any((p) => k.value.startsWith(p)) && RegExp(r'[0-9a-f]{24}$').hasMatch(k.value);
    });

String badgeTexts(WidgetTester t) {
  final out = <String>[];
  for (final e in find.byType(Badge).evaluate()) {
    final b = e.widget as Badge;
    final l = b.label;
    if (l is Text) out.add(l.data ?? '');
  }
  return out.join(',');
}

Future<void> openTimetableTabForA(WidgetTester t) async {
  await t.tap(navLabel('Timetable'));
  await settle(t, 1500);
}

Future<void> toHome(WidgetTester t) async {
  await t.tap(navLabel('Home'));
  await settle(t, 1200);
}

Future<void> sectionTour(WidgetTester t, String who, String prefix, {int stops = 5}) async {
  await homeTop(t);
  await p4shot(t, '${prefix}_${who}_home_top');
  for (var i = 1; i < stops; i++) {
    await homeDown(t, 520);
    await p4shot(t, '${prefix}_${who}_home_scroll$i');
  }
}

// ------------------------------------------------------------------------------------------------ scenario home
Future<void> homeFor(WidgetTester t, String who, bool classTeacher) async {
  await step(t, '$who Home data', () async {
    await settle(t, 3000);
    expectNoBadStates('Home $who');
    dumpHome(who);
    print('HOME[$who] badges=${badgeTexts(t)} isClassTeacher=${Get.find<AuthController>().isClassTeacher} staffId=${(Get.find<AuthController>().staffId ?? '').isNotEmpty}');
    print('HOME[$who] all texts: ${allTexts().where((s) => s.trim().isNotEmpty).join(' / ')}');
    await sectionTour(t, who, 'home', stops: 6);
  });
  await step(t, '$who PTM Earlier today expand', () async {
    await homeTop(t);
    final toggle = find.byKey(const Key('ptm_earlier_toggle'));
    await t.scrollUntilVisible(toggle, 200, scrollable: find.byType(Scrollable).last, maxScrolls: 30);
    await settle(t, 400);
    await t.drag(homeScroll(), const Offset(0, -150));
    await settle(t, 400);
    await t.tap(toggle);
    await settle(t, 900);
    dumpHome('$who after expand');
    await p4shot(t, '${who}_ptm_earlier_expanded');
  });
}

Future<void> homeScenario(WidgetTester t) async {
  await step(t, 'A login', () async => signIn(t, e2eTeacherEmail, e2eTeacherPassword));
  await homeFor(t, 'A', false);
  await step(t, 'A Timetable tab: today (NOW/NEXT) and tomorrow (no NOW/NEXT)', () async {
    await openTimetableTabForA(t);
    await settle(t, 2000);
    await p4shot(t, 'A_timetable_today');
    final nowTags = find.text('NOW').evaluate().length, nextTags = find.text('NEXT').evaluate().length;
    print('TIMETABLE[A] today: NOW tags=$nowTags NEXT tags=$nextTags');
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final key = find.byKey(ValueKey('day_${tomorrow.year}-${tomorrow.month}-${tomorrow.day}'));
    if (key.evaluate().isEmpty) {
      print('TIMETABLE[A] no day pill for tomorrow (${tomorrow.year}-${tomorrow.month}-${tomorrow.day}) visible in this week strip');
    } else {
      await t.tap(key.first);
      await settle(t, 1800);
      print('TIMETABLE[A] tomorrow: NOW tags=${find.text('NOW').evaluate().length} NEXT tags=${find.text('NEXT').evaluate().length} periods=${[for (var i = 0; i < 8; i++) if (find.byKey(ValueKey('period_$i')).evaluate().isNotEmpty) _texts(find.byKey(ValueKey('period_$i')))].join(' || ')}');
      await p4shot(t, 'A_timetable_tomorrow_no_chips');
    }
  });
  await step(t, 'A Lesson plans list + details', () async {
    await toHome(t);
    await openClassesModule(t, 'lesson_plans');
    await settle(t, 2500);
    await p4shot(t, 'A_lessonplans_list_top');
    print('LP[A] list texts: ${allTexts().where((s) => s.trim().isNotEmpty).join(' / ')}');
    print('LP[A] STALE text visible in list: ${allTexts().any((s) => s.contains('STALE-REASON'))}');
    await t.drag(find.byType(Scrollable).last, const Offset(0, -450));
    await settle(t, 700);
    await p4shot(t, 'A_lessonplans_list_scroll');
    await tapText(t, 'P4 Approved after fixes');
    await settle(t, 1800);
    print('LP[A] approved detail: approver notes shown=${find.byKey(const Key('lp_approver_notes')).evaluate().isNotEmpty} rejection box shown=${find.byKey(const Key('lp_rejection')).evaluate().isNotEmpty} stale visible=${allTexts().any((s) => s.contains('STALE-REASON'))}');
    await p4shot(t, 'A_lessonplan_approved_detail');
    await leaveScreen(t);
    await settle(t, 900);
    await tapText(t, 'Linear equations');
    await settle(t, 1800);
    print('LP[A] rejected detail: rejection box shown=${find.byKey(const Key('lp_rejection')).evaluate().isNotEmpty} texts=${_texts(find.byKey(const Key('lp_rejection')))}');
    await p4shot(t, 'A_lessonplan_rejected_detail');
    await leaveScreen(t);
    await settle(t, 900);
    await tapText(t, 'P4 Resubmitted decimals');
    await settle(t, 1800);
    print('LP[A] resubmitted detail: rejection box shown=${find.byKey(const Key('lp_rejection')).evaluate().isNotEmpty} under review=${find.byKey(const Key('lp_under_review')).evaluate().isNotEmpty} stale visible=${allTexts().any((s) => s.contains('STALE-REASON'))}');
    await p4shot(t, 'A_lessonplan_resubmitted_detail_no_reason');
    await leaveToShell(t);
  });
  await step(t, 'A Messages tab (open threads only)', () async {
    await t.tap(navLabel('Messages'));
    await settle(t, 2500);
    print('MSG[A] badges=${badgeTexts(t)} texts=${allTexts().where((s) => s.trim().isNotEmpty).join(' / ')}');
    await p4shot(t, 'A_messages_tab');
    await toHome(t);
  });
  await step(t, 'A sign out', () async => signOutViaUi(t));
  await step(t, 'B login', () async => signIn(t, e2eClassEmail, e2eClassPassword));
  await homeFor(t, 'B', true);
  await step(t, 'B Messages tab', () async {
    await t.tap(navLabel('Messages'));
    await settle(t, 2500);
    print('MSG[B] badges=${badgeTexts(t)} texts=${allTexts().where((s) => s.trim().isNotEmpty).join(' / ')}');
    await p4shot(t, 'B_messages_tab');
    await toHome(t);
  });
}

// ------------------------------------------------------------------------------------------------ scenario refresh (through the logging proxy)
Future<void> refreshScenario(WidgetTester t) async {
  await step(t, 'A login', () async => signIn(t, e2eTeacherEmail, e2eTeacherPassword));
  var tabsBefore = '';
  await step(t, 'A baseline Home', () async {
    await settle(t, 2500);
    expectNoBadStates('Home A');
    tabsBefore = [for (final l in ['Timetable', 'Attendance']) if (navLabel(l).evaluate().isNotEmpty) l].join();
    print('REFRESH[A] baseline tab=$tabsBefore isClassTeacher=${Get.find<AuthController>().isClassTeacher} badges=${badgeTexts(t)} classCardShown=${find.textContaining('Class teacher').evaluate().isNotEmpty}');
    print('REFRESH[A] baseline messages/notifications texts: ${allTexts().where((s) => s.contains('unread') || s.contains('caught up')).join(' / ')}');
    await p4shot(t, 'A_refresh_baseline_top');
    print('MARK:before_pull');
  });
  await step(t, 'DB changes behind the app, then pull-to-refresh', () async {
    await dbAction(t, 'fixture_change_for_refresh');
    await dbAction(t, 'flip_class_teacher_on');
    print('MARK:pull_1');
    await pull(t, waitMs: 4500);
    print('MARK:after_pull_1');
    final tabsAfter = [for (final l in ['Timetable', 'Attendance']) if (navLabel(l).evaluate().isNotEmpty) l].join();
    print('REFRESH[A] after pull: tab=$tabsAfter (was $tabsBefore) isClassTeacher=${Get.find<AuthController>().isClassTeacher} badges=${badgeTexts(t)} classCardShown=${find.textContaining('Class teacher').evaluate().isNotEmpty}');
    print('REFRESH[A] after pull messages texts: ${allTexts().where((s) => s.contains('unread') || s.contains('caught up')).join(' / ')}');
    await p4shot(t, 'A_refresh_after_pull_top');
    await homeDown(t, 400);
    await p4shot(t, 'A_refresh_after_pull_class_card');
    await dbAction(t, 'flip_class_teacher_off');
    print('MARK:pull_2');
    await pull(t, waitMs: 4500);
    print('MARK:after_pull_2');
    final tabsBack = [for (final l in ['Timetable', 'Attendance']) if (navLabel(l).evaluate().isNotEmpty) l].join();
    print('REFRESH[A] after flip back + pull: tab=$tabsBack isClassTeacher=${Get.find<AuthController>().isClassTeacher} classCardShown=${find.textContaining('Class teacher').evaluate().isNotEmpty}');
    await p4shot(t, 'A_refresh_after_flip_back');
  });
}

// ------------------------------------------------------------------------------------------------ scenario offline / unreach
Future<void> offlineScenario(WidgetTester t, {required bool unreachable}) async {
  final tag = unreachable ? 'unreach' : 'down';
  await step(t, 'A login', () async => signIn(t, e2eTeacherEmail, e2eTeacherPassword));
  await step(t, '$tag: baseline', () async {
    await settle(t, 2500);
    expectNoBadStates('Home baseline');
    dumpHome('A baseline');
    await p4shot(t, '${tag}_baseline_home');
  });
  await step(t, '$tag: go offline, pull-to-refresh', () async {
    await dbAction(t, unreachable ? 'proxy_blackhole' : 'backend_stop');
    print('MARK:offline_pull');
    // the unreachable case waits for the 20 s receive timeout of every request (they run in parallel)
    await pull(t, waitMs: unreachable ? 3000 : 6000);
    if (unreachable) {
      // refreshAll awaits /staff-portal/me (20 s receive timeout) BEFORE the sections start, then they time out in parallel (20 s): ~40-45 s.
      // Bounded wait: until every section shows its error or 70 s.
      final t0 = DateTime.now();
      while (find.byKey(const Key('section_error')).evaluate().length < 6 && DateTime.now().difference(t0).inSeconds < 70) {
        guard('wait timeouts');
        await t.pump(const Duration(seconds: 2));
      }
      print('OFFLINE[$tag] errors appeared after ~${DateTime.now().difference(t0).inSeconds + 3} s of the pull');
    }
    await homeTop(t);
    await settle(t, 1500);
    print('OFFLINE[$tag] section_error=${find.byKey(const Key('section_error')).evaluate().length} section_empty=${find.byKey(const Key('section_empty')).evaluate().length} loading=${find.byKey(const Key('section_loading')).evaluate().length} retryButtons=${find.text('Retry').evaluate().length}');
    print('OFFLINE[$tag] error texts: ${[for (final e in find.byKey(const Key('section_error')).evaluate()) _texts(find.byWidget(e.widget))].join(' || ')}');
    await sectionTour(t, 'A', 'offline_$tag', stops: 5);
  });
  await step(t, '$tag: tab bar and app bar stay usable', () async {
    await toHome(t);
    for (final l in ['Messages', 'Classes', 'More', 'Home']) {
      await t.tap(navLabel(l));
      await settle(t, 1400);
      print('OFFLINE[$tag] tapped tab $l -> bottom bar present=${find.byType(BottomNavigationBar).evaluate().isNotEmpty} appBar present=${find.byType(AppBar).evaluate().isNotEmpty}');
      if (l == 'Messages' || l == 'Classes') await p4shot(t, 'offline_${tag}_tab_$l');
    }
  });
  await step(t, '$tag: recover (backend/proxy back, then Retry)', () async {
    await dbAction(t, unreachable ? 'proxy_forward' : 'backend_start');
    await homeTop(t);
    print('MARK:retry');
    var tapped = 0;
    for (var round = 0; round < 3 && find.text('Retry').evaluate().isNotEmpty; round++) {
      guard('retry rounds');
      for (var i = 0; i < 8 && find.text('Retry').evaluate().isNotEmpty; i++) {
        final r = find.text('Retry').first;
        await t.ensureVisible(r);
        await settle(t, 300);
        await t.tap(r, warnIfMissed: false);
        tapped++;
        await settle(t, 1800);
      }
    }
    await settle(t, 2500);
    print('OFFLINE[$tag] Retry taps=$tapped; after: section_error=${find.byKey(const Key('section_error')).evaluate().length} retryButtons=${find.text('Retry').evaluate().length}');
    dumpHome('A recovered');
    await sectionTour(t, 'A', 'offline_${tag}_recovered', stops: 3);
  });
}

// ------------------------------------------------------------------------------------------------ scenario cap
Future<void> capScenario(WidgetTester t) async {
  await step(t, 'A login', () async => signIn(t, e2eTeacherEmail, e2eTeacherPassword));
  await step(t, 'cap: before (open unread only)', () async {
    await settle(t, 2500);
    print('CAP[A] before: badges=${badgeTexts(t)} ${allTexts().where((s) => s.contains('unread') || s.contains('caught up')).join(' / ')}');
    await p4shot(t, 'cap_before');
  });
  await step(t, 'cap: 100 open unread threads', () async {
    await dbAction(t, 'cap_on');
    await pull(t, waitMs: 4500);
    print('CAP[A] after 100+: badges=${badgeTexts(t)} ${allTexts().where((s) => s.contains('unread') || s.contains('caught up')).join(' / ')}');
    await homeTop(t);
    await p4shot(t, 'cap_after_home_top');
    await homeDown(t, 1500);
    await p4shot(t, 'cap_after_messages_card');
    await dbAction(t, 'cap_off');
    await pull(t, waitMs: 4500);
    print('CAP[A] removed again: badges=${badgeTexts(t)} ${allTexts().where((s) => s.contains('unread') || s.contains('caught up')).join(' / ')}');
  });
}

// ------------------------------------------------------------------------------------------------ scenario tz (device timezone emulated by the host script)
Future<void> tzScenario(WidgetTester t) async {
  final now = DateTime.now();
  print('TZ device: offset=${now.timeZoneOffset} name=${now.timeZoneName} local=${now.toIso8601String()} utc=${now.toUtc().toIso8601String()} localDate!=utcDate=${now.day != now.toUtc().day}');
  await step(t, 'A login', () async => signIn(t, e2eTeacherEmail, e2eTeacherPassword));
  await homeFor(t, 'A-tz', false);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final configured = [e2eBaseUrl, e2eTeacherEmail, e2eTeacherPassword, e2eClassEmail, e2eClassPassword, e2eScenario].every((e) => e.isNotEmpty);
  if (!configured) print('SKIPPED phase4_checklist_local_test: pass --dart-define API_BASE_URL, LOCAL_* credentials and E2E_SCENARIO.');
  testWidgets('Phase 4 checklist LOCAL: $e2eScenario', skip: !configured, timeout: const Timeout(Duration(minutes: 13)), (t) async {
    await startRun(t, app.main);
    switch (e2eScenario) {
      case 'home':
        await homeScenario(t);
      case 'refresh':
        await refreshScenario(t);
      case 'offline':
        await offlineScenario(t, unreachable: false);
      case 'unreach':
        await offlineScenario(t, unreachable: true);
      case 'cap':
        await capScenario(t);
      case 'tz':
        await tzScenario(t);
      default:
        throw TestFailure('unknown E2E_SCENARIO $e2eScenario');
    }
    print('P4_DONE scenario=$e2eScenario failures=${e2eFailures.length}');
    for (final f in e2eFailures) print('FAILED_STEP $f');
    expect(e2eFailures, isEmpty);
  });
}
