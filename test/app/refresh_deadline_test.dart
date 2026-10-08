// ignore_for_file: invalid_use_of_protected_member
// Pull-to-refresh on a HUNG server (owner decision 2026-10-08): every section ends in an error state within the 20 s deadline, /me runs
// concurrently with the sections, a late answer can never overwrite the newer state, and the 60 s badge polling is never stuck behind a hung call.
import 'dart:async';
import 'package:eldermin_teacher_app/app/modules/home/controllers/home_badges_controller.dart';
import 'package:eldermin_teacher_app/app/modules/home/controllers/home_dashboard_controller.dart';
import 'package:eldermin_teacher_app/app/modules/home/models/section_state.dart';
import 'package:eldermin_teacher_app/core/models/home/messaging.dart';
import 'package:eldermin_teacher_app/core/models/home/pending_grading.dart';
import 'package:eldermin_teacher_app/core/models/home/teaching.dart';
import 'package:eldermin_teacher_app/core/models/home/timetable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_harness.dart';
import '../support/fake_home_repository.dart';

Future<T> never<T>() => Completer<T>().future;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeHomeRepository repo;

  setUp(() {
    Get.reset();
    Get.testMode = true;
    repo = FakeHomeRepository();
  });
  tearDown(Get.reset);

  Future<({HomeDashboardController c, HarnessApi api, HomeBadgesController badges})> make(WidgetTester t, {bool autoPoll = false}) async {
    final h = (await t.runAsync(() async {
      final h = await signedIn(classTeacher: true);
      await h.auth.refreshProfile(force: true);
      return h;
    }))!;
    final badges = HomeBadgesController(repository: repo, auth: h.auth, autoPoll: autoPoll);
    final c = HomeDashboardController(repository: repo, auth: h.auth, permissions: h.perms, badges: badges, clock: () => DateTime(2026, 10, 5, 9), tick: null);
    return (c: c, api: h.api, badges: badges);
  }

  List<SectionStatus> statuses(HomeDashboardController c) => [
        c.timetable.value.status,
        c.classCard.value.status,
        c.homework.value.status,
        c.lessonPlans.value.status,
        c.ptms.value.status,
        c.substitutions.value.status,
        c.messages.value.status,
      ];

  void hangEverything() {
    repo.myTimetable = (_, __) => never<MyTimetable>();
    repo.roster = (_, __) => never();
    repo.pendingGrading = () => never<PendingGrading>();
    repo.lessonPlans = (_, __) => never<List<LessonPlan>>();
    repo.ptmRange = (_, __, ___) => never<List<PtmMeeting>>();
    repo.ptms = (_) => never<List<PtmMeeting>>();
    repo.fixtures = (_, __, ___) => never<List<Substitution>>();
    repo.threads = () => never<ThreadsResult>();
  }

  testWidgets('hung server: /me and every section hang -> all sections show an error within 20 s of virtual time, the pull completes then', (t) async {
    final m = await make(t);
    hangEverything();
    m.api.staffMeGate = never<void>();
    var done = false;
    unawaited(m.c.refreshAll().then((_) => done = true));
    await t.pump(const Duration(seconds: 19));
    expect(done, isFalse);
    expect(statuses(m.c), everyElement(SectionStatus.loading));
    await t.pump(const Duration(seconds: 1, milliseconds: 1));
    expect(done, isTrue, reason: 'the pull must end by the 20 s deadline');
    expect(statuses(m.c), everyElement(SectionStatus.error));
    expect(m.c.timetable.value.message, contains('taking too long'));
    expect(m.c.messages.value.message, contains('taking too long'));
  });

  testWidgets('old data stays visible while waiting, then the section ends in its error state (Retry) at the deadline', (t) async {
    final m = await make(t);
    final someGrading = PendingGrading.fromJson({
      'total': 3,
      'items': [
        {'assignmentId': 'a1', 'title': 'HW', 'subject': 'Maths', 'gradeLevel': 'Grade 5', 'sectionName': 'A', 'submittedCount': 3, 'totalSubmissions': 5}
      ]
    });
    var calls = 0;
    repo.pendingGrading = () => ++calls == 1 ? Future.value(someGrading) : never<PendingGrading>();
    await t.runAsync(() => m.c.loadHomework());
    expect(m.c.homework.value.hasData, isTrue);
    unawaited(m.c.refreshAll());
    await t.pump(const Duration(seconds: 5));
    expect(m.c.homework.value.hasData, isTrue, reason: 'the old data stays visible while the request is pending');
    await t.pump(const Duration(seconds: 16));
    expect(m.c.homework.value.status, SectionStatus.error);
  });

  testWidgets('/me hung while the sections answer: sections are shown immediately (not behind /me); the pull ends at the deadline', (t) async {
    final m = await make(t);
    m.api.staffMeGate = never<void>();
    var done = false;
    unawaited(m.c.refreshAll().then((_) => done = true));
    await t.pump();
    await t.pump(const Duration(milliseconds: 10));
    expect(m.c.homework.value.status, SectionStatus.empty);
    expect(m.c.ptms.value.status, SectionStatus.empty);
    expect(m.c.messages.value.status, SectionStatus.data);
    expect(statuses(m.c), isNot(contains(SectionStatus.loading)));
    expect(done, isFalse); // still waiting for /me
    await t.pump(const Duration(seconds: 20));
    expect(done, isTrue);
    expect(m.c.homework.value.status, SectionStatus.empty, reason: 'sections that answered are not turned into errors by the deadline');
  });

  testWidgets('a late answer after the deadline cannot overwrite the error state', (t) async {
    final m = await make(t);
    final lateHomework = Completer<PendingGrading>();
    hangEverything();
    repo.pendingGrading = () => lateHomework.future;
    unawaited(m.c.refreshAll());
    await t.pump(const Duration(seconds: 21));
    expect(m.c.homework.value.status, SectionStatus.error);
    lateHomework.complete(PendingGrading.fromJson({
      'total': 3,
      'items': [
        {'assignmentId': 'a1', 'title': 'HW', 'subject': 'Maths', 'gradeLevel': 'Grade 5', 'sectionName': 'A', 'submittedCount': 3, 'totalSubmissions': 5}
      ]
    }));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(m.c.homework.value.status, SectionStatus.error, reason: 'the token guard ignores the late answer');
  });

  testWidgets('a section pulled again after the deadline loads normally (Retry works)', (t) async {
    final m = await make(t);
    hangEverything();
    unawaited(m.c.refreshAll());
    await t.pump(const Duration(seconds: 21));
    expect(m.c.ptms.value.status, SectionStatus.error);
    repo.ptmRange = (_, __, ___) async => [];
    repo.ptms = (_) async => [];
    await t.runAsync(() => m.c.loadPtms());
    expect(m.c.ptms.value.status, SectionStatus.empty);
  });

  testWidgets('the 60 s badge polling is not blocked by a hung call: every poll starts a fresh request after the 20 s deadline', (t) async {
    final m = await make(t, autoPoll: true);
    var threadCalls = 0;
    repo.threads = () {
      threadCalls++;
      return never<ThreadsResult>();
    };
    m.badges.onReady();
    await t.pump();
    expect(threadCalls, 1);
    await t.pump(const Duration(seconds: 61)); // poll #1 at 60 s: the first call was abandoned at 20 s
    expect(threadCalls, 2);
    await t.pump(const Duration(seconds: 60));
    expect(threadCalls, 3);
    m.badges.onClose(); // stops the poll timer
    await t.pump(const Duration(seconds: 21)); // lets the last abandoned call's deadline timer fire
  });

  testWidgets('a hung /me does not keep the profile refresh stuck: after the deadline the next pull can re-read it', (t) async {
    final m = await make(t);
    m.api.staffMeGate = never<void>();
    unawaited(m.c.refreshAll());
    await t.pump(const Duration(seconds: 21));
    m.api.staffMeGate = null;
    m.api.classTeacher = false; // the server now says: no longer class teacher
    var done = false;
    unawaited(m.c.refreshAll().then((_) => done = true));
    await t.pump(const Duration(milliseconds: 50));
    expect(done, isTrue);
    expect(m.c.auth.isClassTeacher, isFalse, reason: 'the second pull re-read /me');
  });
}
