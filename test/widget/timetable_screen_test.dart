import 'dart:async';
import 'package:eldermin_teacher_app/app/modules/timetable/controllers/timetable_controller.dart';
import 'package:eldermin_teacher_app/app/modules/timetable/views/timetable_screen.dart';
import 'package:eldermin_teacher_app/core/models/home/timetable.dart';
import 'package:eldermin_teacher_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../app/timetable_controller_test.dart' show serverWeek, mon, tue;
import '../support/auth_harness.dart';
import '../support/fake_home_repository.dart';

void main() {
  late FakeHomeRepository repo;
  late TimetableController c;
  final now = DateTime(2026, 10, 5, 8, 10); // Monday

  setUp(() {
    Get.reset();
    Get.testMode = true;
    repo = FakeHomeRepository()..myTimetable = (f, t) async => serverWeek(f, t, {1: mon, 2: tue});
  });
  tearDown(Get.reset);

  Future<void> pump(WidgetTester t, {List<String>? permissions, bool load = true, bool tall = true}) async {
    final h = (await t.runAsync(() => signedIn(permissions: permissions)))!;
    c = TimetableController(repository: repo, auth: h.auth, permissions: h.perms, clock: () => now, tick: null);
    Get.put(c);
    if (tall) {
      await t.binding.setSurfaceSize(const Size(430, 3200));
      addTearDown(() => t.binding.setSurfaceSize(null));
    }
    await t.pumpWidget(GetMaterialApp(theme: AppTheme.light, home: const Scaffold(body: TimetableScreen(embedded: true))));
    if (load) {
      await c.load();
      await t.pump();
    }
  }

  testWidgets('day view: NOW / NEXT, Week A/B tags + note, room, split group, 24h times', (t) async {
    await pump(t);
    expect(find.text('NOW'), findsOneWidget);
    expect(find.text('NEXT'), findsNWidgets(2)); // the A and B variants of the 09:00 slot
    expect(find.text('Week A'), findsOneWidget);
    expect(find.text('Week B'), findsOneWidget);
    expect(find.byKey(const Key('week_cycle_note')), findsOneWidget);
    expect(find.text('Maths · Grade 5 - A'), findsOneWidget);
    expect(find.text('Room 101'), findsOneWidget);
    expect(find.text('Group: Group 1'), findsOneWidget);
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('Today · Monday, 5 October'), findsOneWidget);
  });

  testWidgets('selecting an empty weekday shows the empty-day card; Today chip returns to today', (t) async {
    await pump(t);
    await t.tap(find.byKey(const ValueKey('day_2026-10-8')));
    await t.pump();
    expect(find.byKey(const Key('timetable_day_empty')), findsOneWidget);
    expect(find.text('No classes on Thu 8 Oct'), findsOneWidget);
    await t.tap(find.text('Today'));
    await t.pump();
    expect(find.text('NOW'), findsOneWidget);
  });

  testWidgets('week view lists all seven days with counts and "No classes" for empty days', (t) async {
    await pump(t);
    await t.tap(find.text('Week'));
    await t.pump();
    expect(find.text('Sun 4 Oct'), findsOneWidget);
    expect(find.text('Sat 10 Oct'), findsOneWidget);
    expect(find.text('4 periods'), findsOneWidget);
    expect(find.text('1 period'), findsOneWidget);
    expect(find.text('No classes'), findsNWidgets(5));
    expect(find.text('Today'), findsWidgets);
  });

  testWidgets('next week arrow loads the next week', (t) async {
    await pump(t);
    final calls = <DateTime>[];
    repo.myTimetable = (f, to) async {
      calls.add(f);
      return serverWeek(f, to, {2: tue});
    };
    await t.tap(find.byKey(const Key('week_next')));
    await t.pump();
    await t.pump();
    expect(calls.single, DateTime(2026, 10, 11));
    expect(find.text('Sun 11 Oct'), findsNothing); // day mode: header shows the selected day's caption instead
    expect(find.text('Today'), findsWidgets); // the "Today" shortcut chip appears
  });

  testWidgets('loading shows shimmer; error shows message + Retry that reloads', (t) async {
    final gate = Completer<MyTimetable>();
    repo.myTimetable = (f, to) => gate.future;
    await pump(t, load: false);
    unawaited(c.load());
    await t.pump();
    expect(find.byKey(const Key('screen_loading')), findsOneWidget);
    gate.completeError(Exception('x'));
    await t.pump();
    await t.pump();
    expect(find.byKey(const Key('screen_error')), findsOneWidget);
    repo.myTimetable = (f, to) async => serverWeek(f, to, {1: mon});
    await t.tap(find.text('Try again'));
    await t.pump();
    await t.pump();
    expect(find.text('NOW'), findsOneWidget);
  });

  testWidgets('403 shows "You don\'t have access" (no crash); empty week shows the empty state', (t) async {
    repo.myTimetable = (f, to) async => failWith(403);
    await pump(t);
    expect(find.byKey(const Key('screen_forbidden')), findsOneWidget);
    expect(find.text("You don't have access"), findsOneWidget);

    Get.reset();
    Get.testMode = true;
    repo = FakeHomeRepository()..myTimetable = (f, to) async => serverWeek(f, to, {});
    await pump(t);
    expect(find.byKey(const Key('screen_empty')), findsOneWidget);
    expect(find.text('No periods this week'), findsOneWidget);
  });

  testWidgets('pull to refresh re-requests the week', (t) async {
    await pump(t, tall: false);
    final before = repo.calls.where((e) => e == 'myTimetable').length;
    await t.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await t.pump(const Duration(seconds: 1));
    expect(repo.calls.where((e) => e == 'myTimetable').length, greaterThan(before));
  });
}
