import 'dart:async';
import 'package:eldermin_teacher_app/app/modules/home/controllers/home_badges_controller.dart';
import 'package:eldermin_teacher_app/app/modules/home/controllers/home_dashboard_controller.dart';
import 'package:eldermin_teacher_app/app/modules/home/controllers/home_shell_controller.dart';
import 'package:eldermin_teacher_app/app/modules/home/models/section_state.dart';
import 'package:eldermin_teacher_app/app/modules/home/views/home_dashboard_screen.dart';
import 'package:eldermin_teacher_app/app/modules/home/views/home_shell.dart';
import 'package:eldermin_teacher_app/app/modules/home/views/widgets/home_sections.dart';
import 'package:eldermin_teacher_app/app/modules/home/views/widgets/section_view.dart';
import 'package:eldermin_teacher_app/core/models/home/class_snapshot.dart';
import 'package:eldermin_teacher_app/core/models/home/messaging.dart';
import 'package:eldermin_teacher_app/core/models/home/summaries.dart';
import 'package:eldermin_teacher_app/core/models/home/teaching.dart';
import 'package:eldermin_teacher_app/core/services/home_repository.dart';
import 'package:eldermin_teacher_app/core/theme/app_theme.dart';
import 'package:eldermin_teacher_app/core/utils/home_time.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_harness.dart';
import '../support/fake_home_repository.dart';

const me = '64a0000000000000000000a1';

Widget host(Widget child) => GetMaterialApp(theme: AppTheme.light, home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  setUp(() {
    Get.reset();
    Get.testMode = true;
  });
  tearDown(Get.reset);

  group('SectionView states', () {
    Widget view(SectionState<int> s, {VoidCallback? retry, bool hideForbidden = true, bool hideUnavailable = false}) => host(SectionView<int>(
          title: 'T',
          state: s,
          onRetry: retry ?? () {},
          hideWhenForbidden: hideForbidden,
          hideWhenUnavailable: hideUnavailable,
          emptyTitle: 'Nothing',
          builder: (d) => Text('data $d'),
        ));

    testWidgets('loading shows shimmer, data shows builder, empty shows message', (t) async {
      await t.pumpWidget(view(const SectionState.loading()));
      expect(find.byKey(const Key('section_loading')), findsOneWidget);
      await t.pumpWidget(view(const SectionState.data(5)));
      expect(find.text('data 5'), findsOneWidget);
      await t.pumpWidget(view(const SectionState.empty()));
      expect(find.text('Nothing'), findsOneWidget);
    });

    testWidgets('error shows the message and Retry calls back', (t) async {
      var retried = 0;
      await t.pumpWidget(view(const SectionState.error('Server down'), retry: () => retried++));
      expect(find.text('Server down'), findsOneWidget);
      await t.tap(find.text('Retry'));
      expect(retried, 1);
    });

    testWidgets('403 hides the section (or says no access when not hidden); 404 hides when asked', (t) async {
      await t.pumpWidget(view(const SectionState.forbidden()));
      expect(find.text('T'), findsNothing);
      await t.pumpWidget(view(const SectionState.forbidden(), hideForbidden: false));
      expect(find.text("You don't have access"), findsOneWidget);
      await t.pumpWidget(view(const SectionState.unavailable(), hideUnavailable: true));
      expect(find.text('T'), findsNothing);
      await t.pumpWidget(view(const SectionState.unavailable()));
      expect(find.text('Not available on this server yet'), findsOneWidget);
    });
  });

  group('section widgets (data)', () {
    TeacherPeriod tp(String s, String e, {String? tag, String? split}) => TeacherPeriod(
        day: 1, periodNo: 1, startMinutes: parseHm(s), endMinutes: parseHm(e), startText: s, endText: e,
        classLabel: 'Grade 5 - A', subject: 'Maths', room: '101', weekCycleTag: tag, splitLabel: split);

    testWidgets('timetable: NOW / NEXT tags, week tag, room, 24h times', (t) async {
      final now = DateTime(2026, 10, 5, 8, 10);
      final periods = annotatePeriods([tp('08:00', '08:45'), tp('09:00', '09:45', tag: 'A'), tp('14:00', '14:45')], now);
      await t.pumpWidget(host(TimetableStrip(periods: periods)));
      expect(find.text('NOW'), findsOneWidget);
      expect(find.text('NEXT'), findsOneWidget);
      expect(find.text('Week A'), findsOneWidget);
      expect(find.text('08:00'), findsOneWidget);
      expect(find.text('Maths · Grade 5 - A'), findsNWidgets(3));
      expect(find.text('Room 101'), findsNWidgets(3));
    });

    testWidgets('timetable: empty day says "No classes today"', (t) async {
      await t.pumpWidget(host(const TimetableStrip(periods: [])));
      expect(find.text('No classes today'), findsOneWidget);
    });

    testWidgets('class card: roster, marked-today text and Mark Attendance', (t) async {
      var tapped = 0;
      const snap = ClassAttendanceSnapshot(label: 'Grade 5 - A', grade: 'Grade 5', section: 'A', rosterSize: 30, markedCount: 0);
      await t.pumpWidget(host(ClassTeacherCard(snap: snap, onMarkAttendance: () => tapped++)));
      expect(find.text("Attendance isn't marked yet today"), findsOneWidget);
      expect(find.text('0 / 30'), findsOneWidget);
      await t.tap(find.byKey(const Key('mark_attendance_button')));
      expect(tapped, 1);
    });

    testWidgets('homework: totals, per-assignment counts and the cap note', (t) async {
      const a = HomeworkAssignment(id: 'a', title: 'Chapter 3', subject: 'Maths', gradeLevel: 'Grade 5', sectionName: 'A');
      await t.pumpWidget(host(HomeworkCard(
          data: const HomeworkToGrade(items: [GradingItem(a, 3)], totalUngraded: 3, assignmentsChecked: 10, capped: true, failedLookups: 1),
          onOpen: (_) {})));
      expect(find.text('3'), findsOneWidget);
      expect(find.text('3 to grade'), findsOneWidget);
      expect(find.textContaining('10 most recent'), findsOneWidget);
      expect(find.textContaining("Couldn't check 1"), findsOneWidget);
    });

    testWidgets('lesson plans: counts, rejection reason shown only for rejected', (t) async {
      const rejected = LessonPlan(id: '1', topic: 'Fractions', status: 'rejected', rejectionReason: 'Add assessment');
      const submitted = LessonPlan(id: '2', topic: 'Decimals', status: 'submitted');
      await t.pumpWidget(host(LessonPlansCard(
          data: const LessonPlanSummary(submitted: [submitted], rejected: [rejected]), onOpen: (_) {})));
      expect(find.text('Rejected: Add assessment'), findsOneWidget);
      expect(find.text('Awaiting approval'), findsOneWidget);
      expect(find.text('Decimals'), findsOneWidget);
      expect(find.textContaining('Rejected: '), findsOneWidget);
    });

    testWidgets('ptm list', (t) async {
      final m = PtmMeeting(id: 'p', studentName: 'Sam', scheduledDate: DateTime.utc(2026, 10, 10), startTime: '10:00', endTime: '10:20', status: 'confirmed');
      await t.pumpWidget(host(PtmList(meetings: [m], onOpen: (_) {})));
      expect(find.text('Sam'), findsOneWidget);
      expect(find.text('10 Oct · 10:00 - 10:20'), findsOneWidget);
      expect(find.text('Confirmed'), findsOneWidget);
    });

    testWidgets('substitutions: covering vs being covered', (t) async {
      const cover = Substitution(id: '1', subject: 'Maths', startTime: '09:20', endTime: '10:00', originalTeacherName: 'Olive', substituteTeacherId: me);
      const away = Substitution(id: '2', subject: 'Science', substituteTeacherName: 'Sub Teacher', originalTeacherId: me);
      const none = Substitution(id: '3', subject: 'Art', originalTeacherId: me);
      await t.pumpWidget(host(SubstitutionsCard(data: const SubstitutionsToday(covering: [cover], covered: [away, none]), onOpen: (_) {})));
      expect(find.text("You're covering Maths"), findsOneWidget);
      expect(find.textContaining('for Olive'), findsOneWidget);
      expect(find.text('Science is being covered'), findsOneWidget);
      expect(find.textContaining('by Sub Teacher'), findsOneWidget);
      expect(find.textContaining('no substitute assigned yet'), findsOneWidget);
    });

    testWidgets('messages summary tap opens messages', (t) async {
      var opened = 0;
      final r = ThreadsResult(items: [const MessageThread(id: '1', guardianName: 'Gina', studentName: 'Sam', lastMessagePreview: 'Thanks', staffHasUnread: true)]);
      await t.pumpWidget(host(MessagesSummary(data: r, onOpen: () => opened++)));
      expect(find.text('1 unread conversation'), findsOneWidget);
      await t.tap(find.text('Gina · Sam'));
      expect(opened, 1);
    });
  });

  group('dashboard screen (fake repository)', () {
    late FakeHomeRepository repo;
    Future<HomeDashboardController> pumpDashboard(WidgetTester t, {bool classTeacher = false, DateTime? clock}) async {
      repo = FakeHomeRepository();
      return _mount(t, repo, classTeacher: classTeacher, clock: clock);
    }

    testWidgets('shimmer while loading, then sections; greeting uses the injected clock', (t) async {
      repo = FakeHomeRepository();
      final gate = Completer<List<PtmMeeting>>();
      repo.ptms = (_) => gate.future;
      await _mount(t, repo, clock: DateTime(2026, 10, 5, 8, 10));
      expect(find.byKey(const Key('section_loading')), findsWidgets);
      expect(find.text('Good morning, Tess'), findsOneWidget);
      expect(find.text('Monday, 5 October'), findsOneWidget);
      gate.complete([const PtmMeeting(id: 'p', teacherId: me, studentName: 'Sam')]);
      await t.pump();
      await t.pump();
      expect(find.text('Sam'), findsOneWidget);
    });

    testWidgets('empty states for every section', (t) async {
      await pumpDashboard(t);
      await t.pump();
      expect(find.text('No classes today'), findsOneWidget);
      expect(find.text('No substitutions today'), findsOneWidget);
      expect(find.text('Nothing to grade'), findsOneWidget);
      expect(find.text('All caught up'), findsOneWidget);
      expect(find.text('No upcoming meetings'), findsOneWidget);
      expect(find.byKey(const Key('messages_caught_up')), findsOneWidget);
    });

    testWidgets('one section failing shows error+Retry while the others render; Retry recovers', (t) async {
      repo = FakeHomeRepository();
      var fail = true;
      repo.ptms = (_) async => fail ? failWith(500) : [const PtmMeeting(id: 'p', teacherId: me, studentName: 'Sam')];
      await _mount(t, repo);
      await t.pump();
      expect(find.byKey(const Key('section_error')), findsOneWidget);
      expect(find.text('No classes today'), findsOneWidget);
      fail = false;
      await t.ensureVisible(find.text('Retry'));
      await t.tap(find.text('Retry'));
      await t.pump();
      await t.pump();
      expect(find.byKey(const Key('section_error')), findsNothing);
      expect(find.text('Sam'), findsOneWidget);
    });

    testWidgets('403 hides a section; threads 404 hides Messages; class card appears for class teacher', (t) async {
      repo = FakeHomeRepository();
      repo.assignments = (_) async => failWith(403);
      repo.threads = () async => failWith(404);
      repo.attendance = (_, __, ___, ____) async => 12;
      await _mount(t, repo, classTeacher: true);
      await t.pump();
      expect(find.text('Homework to grade'), findsNothing);
      expect(find.text('Messages'), findsNothing);
      expect(find.text('Mark Attendance'), findsOneWidget);
      expect(find.text('12 / 30'), findsOneWidget);
      expect(find.text('Today\'s classes'), findsOneWidget);
    });

    testWidgets('quick action chips are shown (permission filtered)', (t) async {
      await pumpDashboard(t);
      await t.pump();
      expect(find.byKey(const Key('quick_Homework')), findsOneWidget);
      expect(find.byKey(const Key('quick_Attendance')), findsNothing);
    });

    testWidgets('pull-to-refresh reloads every section', (t) async {
      await pumpDashboard(t);
      await t.pump();
      repo.calls.clear();
      await t.drag(find.byType(SingleChildScrollView).first, const Offset(0, 500));
      await t.pump(const Duration(milliseconds: 50));
      await t.pump(const Duration(milliseconds: 600));
      await t.pump();
      expect(repo.calls, containsAll(['timetable:$me', 'assignments:$me', 'ptms:$me', 'fixtures:$me', 'threads', 'unread']));
    });
  });

  group('shell badges', () {
    testWidgets('bell and Messages tab badges show real counts', (t) async {
      final repo = FakeHomeRepository()
        ..unread = (() async => 3)
        ..threads = (() async => ThreadsResult(items: [
              const MessageThread(id: '1', staffHasUnread: true),
              const MessageThread(id: '2', staffHasUnread: true),
            ]));
      await _mountShell(t, repo);
      await t.pump();
      expect(find.descendant(of: find.byKey(const Key('bell_badge')), matching: find.text('3')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('messages_badge')), matching: find.text('2')), findsOneWidget);
    });

    testWidgets('404/zero: no badge anywhere', (t) async {
      final repo = FakeHomeRepository()
        ..unread = (() async => failWith(404))
        ..threads = (() async => failWith(404));
      await _mountShell(t, repo);
      await t.pump();
      expect(find.byType(Badge), findsNothing);
      final zero = FakeHomeRepository();
      Get.reset();
      Get.testMode = true;
      await _mountShell(t, zero);
      await t.pump();
      expect(find.byType(Badge), findsNothing);
    });
  });
}

Future<HomeDashboardController> _mount(WidgetTester t, FakeHomeRepository repo, {bool classTeacher = false, DateTime? clock}) async {
  final h = (await t.runAsync(() => signedIn(classTeacher: classTeacher)))!;
  Get.put<HomeRepository>(repo);
  Get.put(HomeShellController());
  final badges = Get.put(HomeBadgesController(repository: repo, auth: h.auth, autoPoll: false));
  final c = Get.put(HomeDashboardController(
      repository: repo, auth: h.auth, permissions: h.perms, badges: badges, clock: clock == null ? null : () => clock, tick: null));
  await t.pumpWidget(GetMaterialApp(theme: AppTheme.light, home: const Scaffold(body: HomeDashboardScreen())));
  await t.pump();
  return c;
}

Future<void> _mountShell(WidgetTester t, FakeHomeRepository repo) async {
  final h = (await t.runAsync(() => signedIn()))!;
  Get.put<HomeRepository>(repo);
  final badges = Get.put(HomeBadgesController(repository: repo, auth: h.auth, autoPoll: false));
  Get.put(HomeDashboardController(repository: repo, auth: h.auth, permissions: h.perms, badges: badges, tick: null));
  await t.pumpWidget(GetMaterialApp(theme: AppTheme.light, home: const HomeShell()));
  await t.pump();
}
