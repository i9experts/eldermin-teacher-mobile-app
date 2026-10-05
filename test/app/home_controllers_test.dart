// ignore_for_file: invalid_use_of_protected_member
import 'package:eldermin_teacher_app/app/modules/auth/controllers/auth_controller.dart';
import 'package:eldermin_teacher_app/app/modules/home/controllers/home_badges_controller.dart';
import 'package:eldermin_teacher_app/app/modules/home/controllers/home_dashboard_controller.dart';
import 'package:eldermin_teacher_app/app/modules/home/models/section_state.dart';
import 'package:eldermin_teacher_app/core/models/home/class_snapshot.dart';
import 'package:eldermin_teacher_app/core/models/home/messaging.dart';
import 'package:eldermin_teacher_app/core/models/home/teaching.dart';
import 'package:eldermin_teacher_app/core/models/home/timetable.dart';
import 'package:eldermin_teacher_app/core/utils/home_time.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_harness.dart';
import '../support/fake_home_repository.dart';

const me = '64a0000000000000000000a1';

HomeworkAssignment hw(int i, {String teacher = me, int subs = 2, String status = 'assigned'}) => HomeworkAssignment(
    id: 'a$i', teacherId: teacher, title: 'HW $i', status: status, submissionsCount: subs, dueDate: DateTime.utc(2026, 10, 30 - i));

TimetableDoc timetableDoc() => TimetableDoc(id: 'd', gradeLevel: 'Grade 5', sectionName: 'A', periods: [
      const TimetablePeriod(day: 1, periodNo: 1, startTime: '08:00', endTime: '08:45', subject: 'Maths', teacherId: me, roomNo: '101'),
      const TimetablePeriod(day: 1, periodNo: 2, startTime: '09:00', endTime: '09:45', subject: 'English', teacherId: 'other'),
    ]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeHomeRepository repo;
  late DateTime now;

  setUp(() {
    Get.reset();
    Get.testMode = true;
    repo = FakeHomeRepository();
    now = DateTime(2026, 10, 5, 8, 10); // Monday
  });
  tearDown(Get.reset);

  Future<({HomeDashboardController c, AuthController auth, HomeBadgesController badges})> make({
    bool classTeacher = false,
    List<String>? permissions,
  }) async {
    final h = await signedIn(classTeacher: classTeacher, permissions: permissions);
    final badges = HomeBadgesController(repository: repo, auth: h.auth, autoPoll: false);
    final c = HomeDashboardController(
        repository: repo, auth: h.auth, permissions: h.perms, badges: badges, clock: () => now, tick: null);
    return (c: c, auth: h.auth, badges: badges);
  }

  test('happy path: every section loads using the staffId from /staff-portal/me', () async {
    repo.timetable = (_) async => [timetableDoc()];
    repo.assignments = (_) async => [hw(1)];
    repo.submissions = (_) async => [const HomeworkSubmission(id: 's', status: 'submitted'), const HomeworkSubmission(id: 't', status: 'graded')];
    repo.lessonPlans = (_, st) async => [LessonPlan(id: st, teacherId: me, status: st, topic: st)];
    repo.ptms = (_) async => [const PtmMeeting(id: 'p', teacherId: me, studentName: 'S')];
    repo.fixtures = (_, __, ___) async => [const Substitution(id: 'f', substituteTeacherId: me, status: 'assigned')];
    final t = await make();
    await t.c.loadAll();
    expect(t.c.timetable.value.hasData, isTrue);
    expect(t.c.todayTimetable.single.phase, PeriodPhase.current); // 08:10 inside 08:00-08:45
    expect(t.c.todayTimetable.single.period.subject, 'Maths'); // colleague's period filtered out
    expect(t.c.homework.value.data!.totalUngraded, 1);
    expect(t.c.lessonPlans.value.data!.submitted, hasLength(1));
    expect(t.c.lessonPlans.value.data!.rejected, hasLength(1));
    expect(t.c.ptms.value.hasData, isTrue);
    expect(t.c.substitutions.value.data!.covering, hasLength(1));
    expect(repo.calls, containsAll(['timetable:$me', 'assignments:$me', 'lessonPlans:$me:submitted', 'lessonPlans:$me:rejected', 'ptms:$me', 'fixtures:$me']));
    expect(repo.calls.where((c) => c.startsWith('roster')), isEmpty, reason: 'not a class teacher');
  });

  test('independent failure: one failing section does not affect the others', () async {
    repo.timetable = (_) async => failWith(500);
    repo.ptms = (_) async => [const PtmMeeting(id: 'p', teacherId: me)];
    final t = await make();
    await t.c.loadAll();
    expect(t.c.timetable.value.status, SectionStatus.error);
    expect(t.c.ptms.value.status, SectionStatus.data);
    expect(t.c.homework.value.status, SectionStatus.empty);
    expect(t.c.lessonPlans.value.status, SectionStatus.empty);
    expect(t.c.substitutions.value.status, SectionStatus.empty);
  });

  test('error then retry succeeds; 403 -> forbidden; 404 -> unavailable', () async {
    var fail = true;
    repo.ptms = (_) async => fail ? failWith(500) : [const PtmMeeting(id: 'p', teacherId: me)];
    repo.assignments = (_) async => failWith(403);
    repo.fixtures = (_, __, ___) async => failWith(404);
    final t = await make();
    await t.c.loadAll();
    expect(t.c.ptms.value.status, SectionStatus.error);
    expect(t.c.homework.value.status, SectionStatus.forbidden);
    expect(t.c.substitutions.value.status, SectionStatus.unavailable);
    fail = false;
    await t.c.loadPtms();
    expect(t.c.ptms.value.status, SectionStatus.data);
  });

  test('offline message from the network layer is surfaced', () async {
    repo.timetable = (_) async => failWith(null, 'No internet connection. Check your network and try again.');
    final t = await make();
    await t.c.loadTimetable();
    expect(t.c.timetable.value.status, SectionStatus.error);
    expect(t.c.timetable.value.message, contains('No internet'));
  });

  test('class-teacher card: only for class teachers, uses /me class, derives marked state', () async {
    repo.attendance = (_, __, ___, ____) async => 12;
    final plain = await make();
    await plain.c.loadAll();
    expect(plain.c.showClassCard, isFalse);
    expect(repo.calls.where((c) => c.startsWith('attendance')), isEmpty);

    Get.reset();
    Get.testMode = true;
    final ct = await make(classTeacher: true);
    await ct.c.loadAll();
    final snap = ct.c.classCard.value.data!;
    expect(snap.label, 'Grade 5 - A');
    expect(snap.rosterSize, 30);
    expect(snap.markedCount, 12);
    expect(snap.state, AttendanceMarkState.partial);
    expect(repo.calls, contains('roster:Grade 5:A'));
    expect(repo.calls, contains('attendance:Grade 5:A'));
  });

  test('homework N+1 is capped at 10 assignments and reports it', () async {
    repo.assignments = (_) async => [for (var i = 1; i <= 14; i++) hw(i)];
    repo.submissions = (_) async => [const HomeworkSubmission(id: 's', status: 'late')];
    final t = await make();
    await t.c.loadHomework();
    expect(repo.calls.where((c) => c.startsWith('submissions')), hasLength(10));
    final d = t.c.homework.value.data!;
    expect(d.capped, isTrue);
    expect(d.totalUngraded, 10);
    expect(d.assignmentsChecked, 10);
  });

  test('homework: other teachers\' and draft/zero-submission assignments are not fetched', () async {
    repo.assignments = (_) async => [hw(1, teacher: 'other'), hw(2, status: 'draft'), hw(3, subs: 0), hw(4)];
    repo.submissions = (_) async => [];
    final t = await make();
    await t.c.loadHomework();
    expect(repo.calls.where((c) => c.startsWith('submissions')), ['submissions:a4']);
    expect(t.c.homework.value.status, SectionStatus.empty);
  });

  test('homework: partial lookup failure still shows data with a failure count; total failure is an error', () async {
    repo.assignments = (_) async => [hw(1), hw(2)];
    repo.submissions = (id) async => id == 'a1' ? failWith(500) : [const HomeworkSubmission(id: 's', status: 'submitted')];
    final t = await make();
    await t.c.loadHomework();
    expect(t.c.homework.value.data!.failedLookups, 1);
    expect(t.c.homework.value.data!.totalUngraded, 1);
    repo.submissions = (_) async => failWith(500);
    await t.c.loadHomework();
    expect(t.c.homework.value.status, SectionStatus.error);
  });

  test('permission-gated sections are neither loaded nor shown without teaching:view', () async {
    final t = await make(permissions: ['dashboard:view']);
    await t.c.loadAll();
    expect(t.c.showTimetable, isFalse);
    expect(repo.calls.where((c) => !c.startsWith('threads') && !c.startsWith('unread')), isEmpty);
    expect(t.c.quickActions, isEmpty);
  });

  test('quick actions are permission filtered; Attendance only for class teachers', () async {
    final plain = await make();
    expect(plain.c.quickActions.map((a) => a.label), isNot(contains('Attendance')));
    expect(plain.c.quickActions.map((a) => a.label), contains('Homework'));
    Get.reset();
    Get.testMode = true;
    final ct = await make(classTeacher: true);
    expect(ct.c.quickActions.first.label, 'Attendance');
  });

  test('midnight rollover: clock tick on a new day reloads the day-bound sections', () async {
    now = DateTime(2026, 10, 5, 23, 59, 50);
    final t = await make(classTeacher: true);
    await t.c.loadAll();
    final before = repo.calls.length;
    t.c.advanceClock(); // same day: nothing reloads
    await Future<void>.delayed(Duration.zero);
    expect(repo.calls.length, before);
    now = DateTime(2026, 10, 6, 0, 0, 5);
    t.c.advanceClock();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(repo.calls.skip(before), containsAll(['fixtures:$me', 'ptms:$me', 'attendance:Grade 5:A']));
    expect(dayIndexOf(t.c.now.value), 2);
  });

  test('stale response is ignored (last request wins)', () async {
    var n = 0;
    repo.ptms = (_) async {
      final call = ++n;
      await Future<void>.delayed(Duration(milliseconds: call == 1 ? 60 : 5));
      return [PtmMeeting(id: 'call$call', teacherId: me)];
    };
    final t = await make();
    final first = t.c.loadPtms();
    final second = t.c.loadPtms();
    await Future.wait([first, second]);
    expect(t.c.ptms.value.data!.single.id, 'call2');
  });

  group('badges', () {
    test('counts from the endpoints; unread threads derived from staffHasUnread', () async {
      repo.unread = () async => 4;
      repo.threads = () async => ThreadsResult(items: [
            const MessageThread(id: '1', staffHasUnread: true),
            const MessageThread(id: '2', staffHasUnread: false),
          ]);
      final t = await make();
      await t.badges.refreshAll();
      expect(t.badges.notificationUnread.value, 4);
      expect(t.badges.messagesUnread, 1);
    });

    test('404/501 from unread-count or threads -> no badge, no crash', () async {
      repo.unread = () async => failWith(404);
      repo.threads = () async => failWith(501);
      final t = await make();
      await t.badges.refreshAll();
      expect(t.badges.notificationUnread.value, isNull);
      expect(t.badges.notificationsUnavailable.value, isTrue);
      expect(t.badges.messagesUnread, isNull);
      expect(t.badges.threads.value.status, SectionStatus.unavailable);
    });

    test('a transient poll failure keeps the last real count (never invents one)', () async {
      var fail = false;
      repo.unread = () async => fail ? failWith(500) : 2;
      repo.threads = () async => fail ? failWith(500) : ThreadsResult(items: [const MessageThread(id: '1', staffHasUnread: true)]);
      final t = await make();
      await t.badges.refreshAll();
      fail = true;
      await t.badges.refreshAll();
      expect(t.badges.notificationUnread.value, 2);
      expect(t.badges.messagesUnread, 1);
      await t.badges.refreshAll(userInitiated: true);
      expect(t.badges.threads.value.status, SectionStatus.error, reason: 'user-initiated failure is visible');
    });

    test('polls on the interval and refreshes on resume; stops in the background', () async {
      final h = await signedIn();
      final b = HomeBadgesController(repository: repo, auth: h.auth, pollInterval: const Duration(milliseconds: 40));
      b.onReady();
      await Future<void>.delayed(const Duration(milliseconds: 190));
      final polled = repo.calls.where((c) => c == 'unread').length;
      expect(polled, greaterThanOrEqualTo(3));
      b.didChangeAppLifecycleState(AppLifecycleState.paused);
      final atPause = repo.calls.where((c) => c == 'unread').length;
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(repo.calls.where((c) => c == 'unread').length, atPause, reason: 'no polling in the background');
      b.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(repo.calls.where((c) => c == 'unread').length, greaterThan(atPause), reason: 'immediate refresh on resume');
      b.onClose();
    });
  });
}
