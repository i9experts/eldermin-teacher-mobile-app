// Phase 8 error-handling audit, executable part. For every list / read screen: the REAL screen + controller + repository + DioExceptionHandler on a
// network that fails in one of the ways a phone sees (offline, timeouts, 403, 404, 500, 501). The screen must stay alive (no exception), say the right
// thing, and offer a retry that really sends a new request. 401 is a session event, not a screen state: see the last group.
// ignore_for_file: invalid_use_of_protected_member
import 'package:eldermin_teacher_app/app/modules/assessments/controllers/assessments_controller.dart';
import 'package:eldermin_teacher_app/app/modules/assessments/views/assessments_screen.dart';
import 'package:eldermin_teacher_app/app/modules/assessments/controllers/quiz_controllers.dart';
import 'package:eldermin_teacher_app/app/modules/assessments/views/assessment_detail_screen.dart';
import 'package:eldermin_teacher_app/app/modules/assessments/views/quiz_attempts_screen.dart';
import 'package:eldermin_teacher_app/app/modules/curriculum/views/curriculum_detail_screen.dart';
import 'package:eldermin_teacher_app/app/modules/events/views/event_detail_screen.dart';
import 'package:eldermin_teacher_app/app/modules/homework/controllers/submissions_controller.dart';
import 'package:eldermin_teacher_app/app/modules/homework/views/homework_submissions_screen.dart';
import 'package:eldermin_teacher_app/app/modules/lesson_plans/controllers/lesson_plan_detail_controller.dart';
import 'package:eldermin_teacher_app/app/modules/lesson_plans/views/lesson_plan_detail_screen.dart';
import 'package:eldermin_teacher_app/app/modules/ptm/controllers/ptm_detail_controller.dart';
import 'package:eldermin_teacher_app/app/modules/ptm/views/ptm_detail_screen.dart';
import 'package:eldermin_teacher_app/app/modules/syllabus/controllers/syllabus_detail_controller.dart';
import 'package:eldermin_teacher_app/app/modules/syllabus/controllers/weekly_planner_controller.dart';
import 'package:eldermin_teacher_app/app/modules/syllabus/views/syllabus_detail_screen.dart';
import 'package:eldermin_teacher_app/app/modules/syllabus/views/syllabus_weekly_planner_screen.dart';
import 'package:eldermin_teacher_app/app/modules/assessments/controllers/report_remarks_controller.dart';
import 'package:eldermin_teacher_app/app/modules/assessments/views/assessment_report_remarks_screen.dart';
import 'package:eldermin_teacher_app/app/modules/attendance/controllers/attendance_controller.dart';
import 'package:eldermin_teacher_app/app/modules/attendance/views/attendance_screen.dart';
import 'package:eldermin_teacher_app/app/modules/behaviour/controllers/behaviour_student_controller.dart';
import 'package:eldermin_teacher_app/app/modules/behaviour/views/behaviour_student_screen.dart';
import 'package:eldermin_teacher_app/app/modules/messages/controllers/chat_controller.dart';
import 'package:eldermin_teacher_app/app/modules/messages/views/message_thread_screen.dart';
import 'package:eldermin_teacher_app/core/services/attendance_repository.dart';
import 'package:eldermin_teacher_app/app/modules/auth/controllers/auth_controller.dart';
import 'package:eldermin_teacher_app/app/modules/calendar/controllers/calendar_controller.dart';
import 'package:eldermin_teacher_app/app/modules/calendar/controllers/circulars_controller.dart';
import 'package:eldermin_teacher_app/app/modules/calendar/views/calendar_screen.dart';
import 'package:eldermin_teacher_app/app/modules/curriculum/controllers/curriculum_controller.dart';
import 'package:eldermin_teacher_app/app/modules/curriculum/views/curriculum_screen.dart';
import 'package:eldermin_teacher_app/app/modules/events/controllers/events_controller.dart';
import 'package:eldermin_teacher_app/app/modules/events/views/events_screen.dart';
import 'package:eldermin_teacher_app/app/modules/fixtures/controllers/fixtures_controller.dart';
import 'package:eldermin_teacher_app/app/modules/fixtures/views/fixtures_screen.dart';
import 'package:eldermin_teacher_app/app/modules/help/controllers/help_controller.dart';
import 'package:eldermin_teacher_app/app/modules/help/views/help_screen.dart';
import 'package:eldermin_teacher_app/app/modules/home/controllers/home_badges_controller.dart';
import 'package:eldermin_teacher_app/app/modules/home/controllers/home_dashboard_controller.dart';
import 'package:eldermin_teacher_app/app/modules/home/views/home_dashboard_screen.dart';
import 'package:eldermin_teacher_app/app/modules/homework/controllers/homework_controller.dart';
import 'package:eldermin_teacher_app/app/modules/homework/views/homework_screen.dart';
import 'package:eldermin_teacher_app/app/modules/leave/controllers/leave_controller.dart';
import 'package:eldermin_teacher_app/app/modules/leave/views/leave_screen.dart';
import 'package:eldermin_teacher_app/app/modules/lesson_plans/controllers/lesson_plans_controller.dart';
import 'package:eldermin_teacher_app/app/modules/lesson_plans/views/lesson_plans_screen.dart';
import 'package:eldermin_teacher_app/app/modules/library/controllers/library_controller.dart';
import 'package:eldermin_teacher_app/app/modules/library/views/library_screen.dart';
import 'package:eldermin_teacher_app/app/modules/messages/controllers/messages_controller.dart';
import 'package:eldermin_teacher_app/app/modules/messages/views/messages_screen.dart';
import 'package:eldermin_teacher_app/app/modules/notifications/controllers/notifications_controller.dart';
import 'package:eldermin_teacher_app/app/modules/notifications/views/notifications_screen.dart';
import 'package:eldermin_teacher_app/app/modules/ptm/controllers/ptm_controller.dart';
import 'package:eldermin_teacher_app/app/modules/ptm/views/ptm_screen.dart';
import 'package:eldermin_teacher_app/app/modules/student_leaves/controllers/student_leaves_controller.dart';
import 'package:eldermin_teacher_app/app/modules/student_leaves/views/student_leaves_screen.dart';
import 'package:eldermin_teacher_app/app/modules/students/controllers/student_detail_controller.dart';
import 'package:eldermin_teacher_app/app/modules/students/controllers/students_controller.dart';
import 'package:eldermin_teacher_app/app/modules/students/views/student_detail_screen.dart';
import 'package:eldermin_teacher_app/app/modules/students/views/students_screen.dart';
import 'package:eldermin_teacher_app/app/modules/syllabus/controllers/syllabus_controller.dart';
import 'package:eldermin_teacher_app/app/modules/syllabus/views/syllabus_screen.dart';
import 'package:eldermin_teacher_app/app/modules/timetable/controllers/timetable_controller.dart';
import 'package:eldermin_teacher_app/app/modules/timetable/views/timetable_screen.dart';
import 'package:eldermin_teacher_app/app/modules/behaviour/controllers/behaviour_controller.dart';
import 'package:eldermin_teacher_app/app/modules/behaviour/views/behaviour_screen.dart';
import 'package:eldermin_teacher_app/core/services/assessment_repository.dart';
import 'package:eldermin_teacher_app/core/services/behaviour_repository.dart';
import 'package:eldermin_teacher_app/core/services/events_repository.dart';
import 'package:eldermin_teacher_app/core/services/fixtures_repository.dart';
import 'package:eldermin_teacher_app/core/services/home_repository.dart';
import 'package:eldermin_teacher_app/core/services/homework_repository.dart';
import 'package:eldermin_teacher_app/core/services/kb_repository.dart';
import 'package:eldermin_teacher_app/core/services/leave_repository.dart';
import 'package:eldermin_teacher_app/core/services/lesson_plan_repository.dart';
import 'package:eldermin_teacher_app/core/services/messaging_repository.dart';
import 'package:eldermin_teacher_app/core/services/permission_service.dart';
import 'package:eldermin_teacher_app/core/services/ptm_repository.dart';
import 'package:eldermin_teacher_app/core/services/reference_repository.dart';
import 'package:eldermin_teacher_app/core/services/school_calendar_repository.dart';
import 'package:eldermin_teacher_app/core/services/students_repository.dart';
import 'package:eldermin_teacher_app/core/services/syllabus_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_harness.dart';
import '../support/failing_client.dart';

class Ctx {
  final FailingClient net;
  final AuthController auth;
  final PermissionService perms;
  Ctx(this.net, this.auth, this.perms);
}

typedef Mount = ({Widget screen, Future<void> Function() load});

class Case {
  final String name;
  final Mount Function(Ctx c) mount;

  /// What a 404 shows when it is NOT "not deployed" (a student that does not exist is "not found", by design).
  final String? on404;
  const Case(this.name, this.mount, {this.on404});
}

Mount _m(Widget s, Future<void> Function() l) => (screen: s, load: l);

final cases = <Case>[
  Case('Homework list', (c) {
    final x = Get.put(HomeworkController(repository: HomeworkRepository(c.net), auth: c.auth, permissions: c.perms));
    return _m(const HomeworkScreen(), () => x.load(force: true));
  }),
  Case('Lesson plans list', (c) {
    final x = Get.put(LessonPlansController(repository: LessonPlanRepository(c.net), auth: c.auth, permissions: c.perms));
    return _m(const LessonPlansScreen(), () => x.load(force: true));
  }),
  Case('Syllabus list', (c) {
    final x = Get.put(SyllabusController(repository: SyllabusRepository(c.net), auth: c.auth, permissions: c.perms));
    return _m(const SyllabusScreen(), () => x.load(force: true));
  }),
  Case('Assessments list', (c) {
    final x = Get.put(AssessmentsController(repository: AssessmentRepository(c.net), auth: c.auth, permissions: c.perms));
    return _m(const AssessmentsScreen(), () => x.load(force: true));
  }),
  Case('Behaviour list', (c) {
    final x = Get.put(BehaviourController(repository: BehaviourRepository(c.net), students: StudentsRepository(c.net), auth: c.auth, permissions: c.perms));
    return _m(const BehaviourScreen(), () => x.load(force: true));
  }),
  Case('My students (roster)', (c) {
    final x = Get.put(StudentsController(repository: StudentsRepository(c.net), auth: c.auth, permissions: c.perms));
    return _m(const StudentsScreen(), () => x.load(force: true));
  }),
  Case('Student 360', (c) {
    final x = Get.put(StudentDetailController('s1', repository: StudentsRepository(c.net), auth: c.auth, permissions: c.perms), tag: 's1');
    return _m(const StudentDetailScreen(studentId: 's1'), () => x.load());
  }, on404: 'Student not found'),
  Case('Timetable', (c) {
    final x = Get.put(TimetableController(repository: HomeRepository(c.net), auth: c.auth, permissions: c.perms, tick: null));
    return _m(const TimetableScreen(), () => x.load(force: true));
  }),
  Case('Curriculum list', (c) {
    final x = Get.put(CurriculumController(repository: ReferenceRepository(c.net), auth: c.auth, permissions: c.perms));
    return _m(const CurriculumScreen(), () => x.load(force: true));
  }),
  Case('Library', (c) {
    final x = Get.put(LibraryController(repository: ReferenceRepository(c.net), auth: c.auth, permissions: c.perms));
    return _m(const LibraryScreen(), () => x.load(force: true));
  }),
  Case('Substitutions', (c) {
    final x = Get.put(FixturesController(repository: FixturesRepository(c.net), auth: c.auth));
    return _m(const FixturesScreen(), () => x.reload(userInitiated: true));
  }),
  Case('Parent meetings', (c) {
    final x = Get.put(PtmController(repository: PtmRepository(c.net), auth: c.auth));
    return _m(const PtmScreen(), () => x.reload(userInitiated: true));
  }),
  Case('Student leave requests (class teacher)', (c) {
    final x = Get.put(StudentLeavesController(repository: MessagingRepository(c.net), auth: c.auth));
    return _m(const StudentLeavesScreen(), () => x.loadTab(x.tab.value, userInitiated: true));
  }),
  Case('Notifications', (c) {
    final x = Get.put(NotificationsController(repository: MessagingRepository(c.net), auth: c.auth, badges: HomeBadgesController(repository: HomeRepository(c.net), auth: c.auth, autoPoll: false)));
    return _m(const NotificationsScreen(), () => x.load(userInitiated: true));
  }),
  Case('Messages inbox', (c) {
    final badges = HomeBadgesController(repository: HomeRepository(c.net), auth: c.auth, autoPoll: false);
    final x = Get.put(MessagesController(repository: MessagingRepository(c.net), badges: badges));
    return _m(const MessagesScreen(embedded: true), () => x.reload());
  }),
  Case('Events', (c) {
    final x = Get.put(EventsController(repository: EventsRepository(c.net)));
    return _m(const EventsScreen(), () => x.load(userInitiated: true));
  }),
  Case('Help', (c) {
    final x = Get.put(HelpController(repository: KbRepository(c.net)));
    return _m(const HelpScreen(), () => x.load(userInitiated: true));
  }),
  Case('School calendar (calendar tab)', (c) {
    final repo = SchoolCalendarRepository(c.net);
    final x = Get.put(CalendarController(repository: repo));
    Get.put(CircularsController(repository: repo, auth: c.auth));
    return _m(const CalendarScreen(), () => x.reload());
  }),
  Case('My leave', (c) {
    final x = Get.put(LeaveController(repository: LeaveRepository(c.net)));
    return _m(const LeaveScreen(), () => x.reload(userInitiated: true));
  }),
  // ── detail / secondary read screens ──
  Case('Homework submissions', (c) {
    final hw = HomeworkRepository(c.net);
    final x = Get.put(SubmissionsController(assignmentId: 'a1', repository: hw, list: HomeworkController(repository: hw, auth: c.auth, permissions: c.perms)));
    return _m(const HomeworkSubmissionsScreen(), () => x.load(force: true));
  }),
  Case('Parent meeting detail', (c) {
    final x = Get.put(PtmDetailController(id: 'p1', repository: PtmRepository(c.net), auth: c.auth), tag: 'p1');
    return _m(const PtmDetailScreen(meetingId: 'p1'), () => x.reload());
  }, on404: 'Meeting not found'),
  Case('Event detail', (c) {
    final x = Get.put(EventDetailController(repository: EventsRepository(c.net), eventId: 'e1'));
    return _m(const EventDetailScreen(), () => x.load(userInitiated: true));
  }),
  Case('Curriculum detail', (c) {
    final ref = ReferenceRepository(c.net);
    final x = Get.put(CurriculumDetailController(id: 'k1', repository: ref, list: CurriculumController(repository: ref, auth: c.auth, permissions: c.perms)));
    return _m(const CurriculumDetailScreen(), () => x.load(force: true));
  }),
  Case('Syllabus detail', (c) {
    final rp = SyllabusRepository(c.net);
    final x = Get.put(SyllabusDetailController(id: 'y1', repository: rp, list: SyllabusController(repository: rp, auth: c.auth, permissions: c.perms)));
    return _m(const SyllabusDetailScreen(), () => x.load(force: true));
  }),
  Case('Syllabus weekly planner', (c) {
    final rp = SyllabusRepository(c.net);
    final x = Get.put(WeeklyPlannerController(repository: rp, syllabi: SyllabusController(repository: rp, auth: c.auth, permissions: c.perms), auth: c.auth));
    return _m(const SyllabusWeeklyPlannerScreen(), () => x.load(force: true));
  }),
  Case('Lesson plan detail', (c) {
    final rp = LessonPlanRepository(c.net);
    final x = Get.put(LessonPlanDetailController(id: 'l1', repository: rp, list: LessonPlansController(repository: rp, auth: c.auth, permissions: c.perms)));
    return _m(const LessonPlanDetailScreen(), () => x.load(force: true));
  }),
  Case('Assessment detail', (c) {
    final ar = AssessmentRepository(c.net);
    final x = Get.put(AssessmentDetailController(id: 'm1', repository: ar, list: AssessmentsController(repository: ar, auth: c.auth, permissions: c.perms)));
    return _m(const AssessmentDetailScreen(), () => x.load(force: true));
  }),
  Case('Quiz attempts to review', (c) {
    final x = Get.put(QuizAttemptsController(repository: AssessmentRepository(c.net), auth: c.auth, permissions: c.perms));
    return _m(const QuizAttemptsScreen(), () => x.load(force: true));
  }),
  Case('Attendance (class teacher hub)', (c) {
    final x = Get.put(AttendanceController(students: StudentsRepository(c.net), attendance: AttendanceRepository(c.net), auth: c.auth, permissions: c.perms));
    return _m(const AttendanceScreen(embedded: true), () => x.load(refreshProfile: false));
  }),
  Case('Report-card remarks', (c) {
    final ar = AssessmentRepository(c.net);
    final x = Get.put(ReportRemarksController(repository: ar, list: AssessmentsController(repository: ar, auth: c.auth, permissions: c.perms)));
    return _m(const AssessmentReportRemarksScreen(), () => x.load());
  }),
  Case('Student behaviour history', (c) {
    final x = Get.put(BehaviourStudentController(studentId: 's1', repository: BehaviourRepository(c.net), students: StudentsRepository(c.net), auth: c.auth, permissions: c.perms));
    return _m(const BehaviourStudentScreen(), () => x.load());
  }),
  Case('Chat thread', (c) {
    final badges = HomeBadgesController(repository: HomeRepository(c.net), auth: c.auth, autoPoll: false);
    final x = Get.put(ChatController(threadId: 't1', repository: MessagingRepository(c.net), badges: badges, observeLifecycle: false), tag: 't1');
    return _m(const MessageThreadScreen(threadId: 't1'), () => x.loadThread());
  }, on404: 'Conversation not found'),
];

const _offline = 'No internet connection. Check your network and try again.';
const _timeout = 'Connection timed out. Check your internet and try again.';
const _server = 'The server had a problem. Please try again.';
const _noAccess = "You don't have access";
const _notDeployed = 'Not available on this server yet';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  Future<Ctx> boot(WidgetTester t, FailingClient net) async {
    Get.reset();
    Get.testMode = true;
    final h = (await t.runAsync(() async {
      final h = await signedIn(classTeacher: true);
      h.api.assignments = const [
        {'gradeLevel': 'Grade 5', 'sectionName': 'A', 'subjectName': 'Mathematics'}
      ];
      await h.auth.refreshProfile(force: true);
      return h;
    }))!;
    return Ctx(net, h.auth, h.perms);
  }

  Future<void> settle(WidgetTester t) async {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
  }

  for (final c in cases) {
    group(c.name, () {
      final expectations = <NetFail, List<String>>{
        NetFail.offline: [_offline],
        NetFail.connectTimeout: [_timeout],
        NetFail.receiveTimeout: [_timeout],
        NetFail.http500: [_server],
        NetFail.http403: [_noAccess],
        NetFail.http404: [c.on404 ?? _notDeployed],
        NetFail.http501: [_notDeployed],
      };
      expectations.forEach((mode, texts) {
        testWidgets('${mode.name}: screen stays alive and says the right thing', (t) async {
          final net = FailingClient(mode);
          final ctx = await boot(t, net);
          final m = c.mount(ctx);
          await t.binding.setSurfaceSize(const Size(430, 1600));
          addTearDown(() => t.binding.setSurfaceSize(null));
          await t.pumpWidget(GetMaterialApp(home: m.screen));
          await t.pump();
          await t.runAsync(() => m.load());
          await settle(t);
          expect(t.takeException(), isNull, reason: 'no crash');
          for (final text in texts) {
            expect(find.text(text), findsWidgets, reason: '${c.name} / ${mode.name}: "$text"');
          }
          // 500 / offline / timeout: a retry control exists and really re-sends a request
          if (mode == NetFail.http500 || mode == NetFail.offline || mode == NetFail.connectTimeout || mode == NetFail.receiveTimeout) {
            final retry = find.text('Try again').evaluate().isNotEmpty ? find.text('Try again').first : find.text('Retry').first;
            expect(retry, findsOneWidget, reason: '${c.name} / ${mode.name}: retry control');
            final before = net.calls;
            await t.ensureVisible(retry);
            await t.tap(retry);
            await settle(t);
            expect(net.calls, greaterThan(before), reason: '${c.name} / ${mode.name}: Retry sent a new request');
            expect(t.takeException(), isNull);
          }
          // the network layer never shows raw technical text
          for (final raw in ['DioException', 'Exception', 'Instance of', 'Null check', 'type \'', 'RangeError', 'StateError']) {
            expect(find.textContaining(raw), findsNothing, reason: raw);
          }
        });
      });
    });
  }

  group('Home dashboard (SectionView per section)', () {
    Future<void> pumpHome(WidgetTester t, FailingClient net) async {
      final ctx = await boot(t, net);
      final repo = HomeRepository(net);
      Get.put<HomeRepository>(repo);
      final badges = Get.put(HomeBadgesController(repository: repo, auth: ctx.auth, autoPoll: false));
      final dash = Get.put(HomeDashboardController(repository: repo, auth: ctx.auth, permissions: ctx.perms, badges: badges, tick: null));
      await t.binding.setSurfaceSize(const Size(430, 3000));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(GetMaterialApp(home: const Scaffold(body: HomeDashboardScreen())));
      await t.pump();
      await t.runAsync(() => dash.loadAll(userInitiated: true));
      await settle(t);
    }

    for (final mode in [NetFail.offline, NetFail.connectTimeout, NetFail.http500]) {
      testWidgets('${mode.name}: every section shows its own error card with Retry, nothing crashes', (t) async {
        final net = FailingClient(mode);
        await pumpHome(t, net);
        expect(t.takeException(), isNull);
        expect(find.byKey(const Key('section_error')), findsWidgets);
        final retry = find.text('Retry');
        expect(retry, findsWidgets);
        final before = net.calls;
        await t.ensureVisible(retry.first);
        await t.tap(retry.first);
        await settle(t);
        expect(net.calls, greaterThan(before), reason: 'a section Retry re-runs its own load');
      });
    }

    testWidgets('403 hides the permission-gated sections instead of showing an error; 404 shows "not available" cards', (t) async {
      await pumpHome(t, FailingClient(NetFail.http403));
      expect(t.takeException(), isNull);
      expect(find.byKey(const Key('section_error')), findsNothing);
      await pumpHome(t, FailingClient(NetFail.http404));
      expect(t.takeException(), isNull);
      expect(find.text(_notDeployed), findsWidgets);
    });
  });
}
