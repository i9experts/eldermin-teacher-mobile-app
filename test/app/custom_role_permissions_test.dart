// fix/custom-role-permissions: sub-module-aware gates for custom roles (web `canAccess(permission, subModuleKey)`).
// Personas: A = a real custom role (anonymised keys), B = the built-in teacher (permissions == null), C = minimal custom roles.
// Every entry point is exercised with the REAL AuthController + PermissionService: the module catalog (Classes / More), RouteGuard (real
// navigation), the Home dashboard flags / quick actions / request calls, the shell FAB, the controllers' own gates and the Substitutions
// "Mark complete" control. Expectations are written out by hand.
// ignore_for_file: invalid_use_of_protected_member
import 'package:eldermin_teacher_app/app/common/module_catalog.dart';
import 'package:eldermin_teacher_app/app/common/views/not_available_screen.dart';
import 'package:eldermin_teacher_app/app/modules/attendance/controllers/attendance_controller.dart';
import 'package:eldermin_teacher_app/app/modules/auth/controllers/auth_controller.dart';
import 'package:eldermin_teacher_app/app/modules/fixtures/controllers/fixtures_controller.dart';
import 'package:eldermin_teacher_app/app/modules/home/controllers/home_badges_controller.dart';
import 'package:eldermin_teacher_app/app/modules/home/controllers/home_dashboard_controller.dart';
import 'package:eldermin_teacher_app/app/modules/home/models/shell_quick_actions.dart';
import 'package:eldermin_teacher_app/app/modules/homework/controllers/homework_controller.dart';
import 'package:eldermin_teacher_app/app/modules/lesson_plans/controllers/lesson_plans_controller.dart';
import 'package:eldermin_teacher_app/app/modules/syllabus/controllers/syllabus_controller.dart';
import 'package:eldermin_teacher_app/app/modules/timetable/controllers/timetable_controller.dart';
import 'package:eldermin_teacher_app/app/routes/app_pages.dart';
import 'package:eldermin_teacher_app/app/routes/app_routes.dart';
import 'package:eldermin_teacher_app/app/routes/route_guard.dart';
import 'package:eldermin_teacher_app/core/services/permission_service.dart';
import 'package:eldermin_teacher_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_harness.dart';
import '../support/fake_home_repository.dart';
import '../support/fake_phase7b_repositories.dart';

const _id = '64a0000000000000000000c1';

/// Persona A: a real custom role, anonymised keys.
const personaA = [
  'academics:library:view', 'academics:syllabus:view', 'assessments:marks:manage', 'assessments:marks:view', 'events:view', 'school-calendar:view',
  'teaching:appraisal:view', 'teaching:attendance:manage', 'teaching:attendance:view', 'teaching:behaviour:manage', 'teaching:behaviour:view',
  'teaching:class-diary:manage', 'teaching:class-diary:view', 'teaching:fixtures:view', 'teaching:homework:manage', 'teaching:homework:view',
  'teaching:lesson-plans:manage', 'teaching:lesson-plans:view', 'teaching:ptm:manage', 'teaching:ptm:view', 'teaching:syllabus:manage',
  'teaching:syllabus:view', 'teaching:timetable:manage', 'teaching:timetable:view',
];

Future<({AuthController auth, PermissionService perms})> _boot({bool classTeacher = false, List<String>? custom}) async {
  Get.reset();
  Get.testMode = true;
  final h = await signedIn(classTeacher: classTeacher, permissions: custom);
  await h.auth.refreshProfile(force: true);
  return (auth: h.auth, perms: h.perms);
}

/// Every visible entry id (Classes then More), in display order.
List<String> _visible(h) => [
      for (final pl in ModulePlacement.values) ...ModuleCatalog.visible(pl, h.perms, isClassTeacher: h.auth.isClassTeacher).map((e) => e.id),
    ];

List<String> _classes(h) => ModuleCatalog.visible(ModulePlacement.classes, h.perms, isClassTeacher: h.auth.isClassTeacher).map((e) => e.id).toList();
List<String> _more(h) => ModuleCatalog.visible(ModulePlacement.more, h.perms, isClassTeacher: h.auth.isClassTeacher).map((e) => e.id).toList();

const _teachingIds = {'attendance', 'homework', 'lesson_plans', 'syllabus', 'timetable', 'ptm', 'fixtures', 'student_leaves'};

bool _allows(h, String location) => RouteGuardRules.allows(location,
    signedIn: true, roleSupported: true, profileLoaded: true, permissions: h.perms, isClassTeacher: h.auth.isClassTeacher);

/// Every location of the seven gated Teaching modules (list, forms, details, sub-routes, the Home tab shortcut).
final _routesOf = <String, List<String>>{
  'attendance': [Routes.attendance, Routes.attendanceMark, Routes.attendanceHistory, '${Routes.attendanceMark}?date=2026-10-05', Routes.homeAttendance],
  'homework': [Routes.homework, Routes.homeworkNew, Routes.homeworkDetailOf(_id), Routes.homeworkSubmissionsOf(_id), Routes.homeworkGradeOf(_id, _id)],
  'lesson_plans': [Routes.lessonPlans, Routes.lessonPlanNew, Routes.lessonPlanUpload, Routes.lessonPlanDetailOf(_id)],
  'timetable': [Routes.timetable],
  'ptm': [Routes.ptm, Routes.ptmNew, Routes.ptmDetailOf(_id)],
  'fixtures': [Routes.fixtures, Routes.fixtureDetailOf(_id)],
  'syllabus': [Routes.syllabus, Routes.syllabusWeeklyPlanner, Routes.syllabusDetailOf(_id)],
};

HomeDashboardController _home(h, FakeHomeRepository repo) => HomeDashboardController(
    repository: repo, auth: h.auth, permissions: h.perms, badges: HomeBadgesController(repository: repo, auth: h.auth, autoPoll: false), clock: () => DateTime(2026, 10, 5, 8, 10), tick: null);

Future<void> _app(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  final pages = [
    for (final p in AppPages.pages) p.name == Routes.notAvailable ? p : p.copy(page: () => Scaffold(body: Text('OPENED ${p.name}')), binding: null, bindings: const []),
  ];
  await t.pumpWidget(GetMaterialApp(theme: AppTheme.light, getPages: pages, home: const Scaffold(body: Text('ROOT'))));
}

Future<bool> _opens(WidgetTester t, String location) async {
  Get.until((r) => r.isFirst);
  await t.pumpAndSettle();
  Get.toNamed(location);
  await t.pumpAndSettle();
  return find.byType(NotAvailableScreen).evaluate().isEmpty;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  group('persona A: real custom role (teaching:<sub>:* keys, no students:*), class teacher', () {
    test('Classes + More: Teaching sub-modules, assessments, calendar, events, curriculum, library, safeguarding; NOT students / behaviour / early years; My leave and My attendance always', () async {
      final h = await _boot(classTeacher: true, custom: personaA);
      expect(_classes(h), ['attendance', 'homework', 'lesson_plans', 'syllabus', 'assessments']);
      // My leave and My attendance are self-service: a custom role never removes them
      expect(_more(h), ['timetable', 'student_leaves', 'ptm', 'fixtures', 'leave', 'my_attendance', 'calendar', 'events', 'curriculum', 'library', 'safeguarding']);
      final v = _visible(h);
      // students needs students:view; behaviour needs behaviour:view
      for (final hidden in ['students', 'behaviour', 'early_years']) {
        expect(v, isNot(contains(hidden)), reason: hidden);
      }
    });

    test('every Teaching route (list, forms, detail, sub-routes, /home/attendance) is allowed by the route guard; students / behaviour routes are not, My leave / My attendance are', () async {
      final h = await _boot(classTeacher: true, custom: personaA);
      for (final e in _routesOf.entries) {
        for (final r in e.value) {
          expect(_allows(h, r), isTrue, reason: '${e.key} $r');
        }
      }
      for (final r in [Routes.students, Routes.studentDetailOf(_id), Routes.behaviour, Routes.earlyYears]) {
        expect(_allows(h, r), isFalse, reason: r);
      }
      for (final r in [Routes.leave, Routes.leaveApply, Routes.myAttendance, Routes.myAttendanceCorrect]) {
        expect(_allows(h, r), isTrue, reason: 'self-service $r');
      }
    });

    test('attendance is NOT students:view any more: the persona has no students:* key yet allowed == true', () async {
      final h = await _boot(classTeacher: true, custom: personaA);
      expect(h.perms.canAccess('students:view'), isFalse);
      final c = AttendanceController(students: null, attendance: null, auth: h.auth, permissions: h.perms);
      expect(c.allowed, isTrue);
    });

    test('Home: class card + Attendance quick action + timetable / fixtures sections load (and call the routes); shell FAB lists Mark Attendance', () async {
      final h = await _boot(classTeacher: true, custom: personaA);
      final repo = FakeHomeRepository();
      final c = _home(h, repo);
      expect(c.showClassCard, isTrue);
      expect([c.showTimetable, c.showHomework, c.showLessonPlans, c.showPtms, c.showSubstitutions], everyElement(isTrue));
      expect(c.quickActions.map((a) => a.label).toList(), ['Attendance', 'Homework', 'Lesson plans', 'Assessments & marks', 'My leave', 'Parent meetings']);
      await c.loadAll();
      expect(repo.calls.where((x) => x.startsWith('timetable') || x == 'myTimetable'), isNotEmpty);
      expect(repo.calls.where((x) => x.startsWith('fixtures')), isNotEmpty);
      expect(repo.calls.where((x) => x.startsWith('roster')), isNotEmpty, reason: 'class card');
      expect(shellQuickActions(permissions: h.perms, isClassTeacher: true).map((a) => a.label), ['Mark Attendance', 'Add Homework', 'Apply Leave', 'Timetable']);
    });

    test('controller gates: homework / lesson plans / syllabus / timetable all allowed', () async {
      final h = await _boot(classTeacher: true, custom: personaA);
      expect(HomeworkController(auth: h.auth, permissions: h.perms).canView, isTrue);
      expect(LessonPlansController(auth: h.auth, permissions: h.perms).canView, isTrue);
      expect(SyllabusController(auth: h.auth, permissions: h.perms).canView, isTrue);
      expect(TimetableController(auth: h.auth, permissions: h.perms).canView, isTrue);
    });

    test('Substitutions: fixtures is VIEW-only -> "Mark complete" hidden and complete() ignored (no PATCH)', () async {
      final h = await _boot(classTeacher: true, custom: personaA);
      final repo = FakeFixturesRepository()..list = (s, f) async => [fixture('c1')];
      final c = FixturesController(repository: repo, auth: h.auth, permissions: h.perms, clock: () => DateTime(2026, 10, 8, 13));
      await c.reload();
      expect(c.canManageFixtures, isFalse);
      expect(c.canComplete(c.find('c1')!), isFalse);
      expect(await c.complete('c1'), isA<CompleteIgnored>());
      expect(repo.calls, ['list'], reason: 'no complete call');
    });

    testWidgets('real navigation: /attendance/mark, /homework, /lesson-plans/<id>, /timetable, /ptm/new, /fixtures, /syllabus open; /students and /behaviour are blocked', (t) async {
      Get.reset();
      Get.testMode = true;
      await t.runAsync(() async {
        final h = await signedIn(classTeacher: true, permissions: personaA);
        await h.auth.refreshProfile(force: true);
      });
      await _app(t);
      for (final r in [Routes.attendanceMark, Routes.homework, Routes.lessonPlanDetailOf(_id), Routes.timetable, Routes.ptmNew, Routes.fixtures, Routes.syllabus]) {
        expect(await _opens(t, r), isTrue, reason: r);
      }
      for (final r in [Routes.students, Routes.behaviour]) {
        expect(await _opens(t, r), isFalse, reason: r);
      }
    });
  });

  group('persona B: built-in teacher (permissions == null) is unchanged', () {
    test('class teacher: everything the base matrix gives, incl. attendance (via teaching:view), my attendance and Mark complete', () async {
      final h = await _boot(classTeacher: true);
      expect(_classes(h), ['students', 'attendance', 'homework', 'lesson_plans', 'syllabus', 'assessments', 'behaviour']);
      expect(_more(h), ['timetable', 'student_leaves', 'ptm', 'fixtures', 'leave', 'my_attendance', 'calendar', 'events', 'curriculum', 'library', 'safeguarding']);
      final repo = FakeFixturesRepository()..list = (s, f) async => [fixture('c1')];
      final c = FixturesController(repository: repo, auth: h.auth, permissions: h.perms, clock: () => DateTime(2026, 10, 8, 13));
      await c.reload();
      expect(c.canManageFixtures, isTrue, reason: 'the base matrix has no teaching:manage; the built-in teacher keeps the control');
      expect(c.canComplete(c.find('c1')!), isTrue);
      final home = _home(h, FakeHomeRepository());
      expect(home.showClassCard, isTrue);
      expect(home.quickActions.map((a) => a.label), ['Attendance', 'Homework', 'Lesson plans', 'Assessments & marks', 'Behaviour & Tarbiyah', 'My leave', 'Parent meetings']);
      for (final e in _routesOf.entries) {
        for (final r in e.value) {
          expect(_allows(h, r), isTrue, reason: r);
        }
      }
    });

    test('not a class teacher: attendance hidden, other Teaching entries visible', () async {
      final h = await _boot();
      expect(_visible(h).toSet().intersection(_teachingIds), {'homework', 'lesson_plans', 'syllabus', 'timetable', 'ptm', 'fixtures'});
    });
  });

  group('persona C: minimal custom roles', () {
    test('[] -> only self-service (My leave, My attendance) and the ungated safeguarding report; every Teaching route blocked; Home makes no request', () async {
      final h = await _boot(classTeacher: true, custom: const []);
      expect(_visible(h), ['leave', 'my_attendance', 'safeguarding']);
      for (final r in _routesOf.values.expand((x) => x)) {
        expect(_allows(h, r), isFalse, reason: r);
      }
      final repo = FakeHomeRepository();
      final c = _home(h, repo);
      expect(c.showClassCard, isFalse);
      expect(c.quickActions.map((a) => a.label), ['My leave']);
      await c.loadAll();
      expect(repo.calls.where((x) => !x.startsWith('threads') && !x.startsWith('unread')), isEmpty);
    });

    test("['teaching:view'] (module-wide) -> every Teaching entry incl. attendance (class teacher); students hidden; Mark complete hidden", () async {
      final h = await _boot(classTeacher: true, custom: const ['teaching:view']);
      expect(_classes(h), ['attendance', 'homework', 'lesson_plans', 'syllabus']);
      expect(_more(h), ['timetable', 'student_leaves', 'ptm', 'fixtures', 'leave', 'my_attendance', 'safeguarding']);
      expect(_visible(h), isNot(contains('students')));
      final repo = FakeFixturesRepository()..list = (s, f) async => [fixture('c1')];
      final c = FixturesController(repository: repo, auth: h.auth, permissions: h.perms, clock: () => DateTime(2026, 10, 8, 13));
      await c.reload();
      expect(c.canManageFixtures, isFalse, reason: 'teaching:view is not manage');
    });

    test("['teaching:homework:view'] -> ONLY homework among the sub-module entries; Home skips timetable / fixtures / lesson plans / ptm requests", () async {
      final h = await _boot(classTeacher: true, custom: const ['teaching:homework:view']);
      final v = _visible(h).toSet();
      expect(v.intersection({'attendance', 'homework', 'lesson_plans', 'syllabus', 'timetable', 'ptm', 'fixtures'}), {'homework'});
      // DECISION NOTE: student_leaves stays `teaching:view` + class teacher WITHOUT a sub-module (backend /staff-portal is not custom-role gated),
      // so under the web's any-sub-grant rule a class teacher holding any teaching:*:view key still sees it.
      expect(v.contains('student_leaves'), isTrue);
      // view-only: the read screens of homework open, its write screens (new / edit, grading) do not
      final homeworkWrites = {Routes.homeworkNew, Routes.homeworkGradeOf(_id, _id)};
      for (final e in _routesOf.entries) {
        for (final r in e.value) {
          expect(_allows(h, r), e.key == 'homework' && !homeworkWrites.contains(r), reason: '${e.key} $r');
        }
      }
      final repo = FakeHomeRepository();
      final c = _home(h, repo);
      expect([c.showTimetable, c.showSubstitutions, c.showLessonPlans, c.showPtms, c.showClassCard], everyElement(isFalse));
      expect(c.showHomework, isTrue);
      expect(c.quickActions.map((a) => a.label), ['Homework', 'My leave']);
      await c.loadAll();
      expect(repo.calls.where((x) => x.startsWith('timetable') || x == 'myTimetable' || x.startsWith('fixtures') || x.startsWith('lessonPlans') || x.startsWith('ptm') || x.startsWith('roster') || x.startsWith('attendance')), isEmpty);
      expect(repo.calls.where((x) => x.startsWith('assignments') || x == 'pendingGrading'), isNotEmpty);
      expect(HomeworkController(auth: h.auth, permissions: h.perms).canView, isTrue);
      expect(LessonPlansController(auth: h.auth, permissions: h.perms).canView, isFalse);
      expect(SyllabusController(auth: h.auth, permissions: h.perms).canView, isFalse);
      expect(TimetableController(auth: h.auth, permissions: h.perms).canView, isFalse);
      expect(AttendanceController(auth: h.auth, permissions: h.perms).allowed, isFalse);
    });

    test("['teaching:homework:view'], not a class teacher: only homework in the whole app", () async {
      final h = await _boot(custom: const ['teaching:homework:view']);
      expect(_visible(h), ['homework', 'leave', 'my_attendance', 'safeguarding']);
    });

    test("['teaching:homework:manage'] -> homework visible (manage implies view)", () async {
      final h = await _boot(custom: const ['teaching:homework:manage']);
      expect(_visible(h), ['homework', 'leave', 'my_attendance', 'safeguarding']);
    });

    test("['teaching:fixtures:manage'] -> Substitutions visible AND Mark complete offered; ['teaching:manage'] (module-wide) too; fixtures:view not", () async {
      Future<bool> manage(List<String> p) async {
        final h = await _boot(custom: p);
        final repo = FakeFixturesRepository()..list = (s, f) async => [fixture('c1')];
        final c = FixturesController(repository: repo, auth: h.auth, permissions: h.perms, clock: () => DateTime(2026, 10, 8, 13));
        await c.reload();
        return c.canManageFixtures && c.canComplete(c.find('c1')!);
      }

      final h = await _boot(custom: const ['teaching:fixtures:manage']);
      expect(_visible(h), ['fixtures', 'leave', 'my_attendance', 'safeguarding']);
      expect(await manage(const ['teaching:fixtures:manage']), isTrue);
      expect(await manage(const ['teaching:manage']), isTrue);
      expect(await manage(const ['teaching:fixtures:view']), isFalse);
      expect(await manage(const ['teaching:homework:manage']), isFalse, reason: 'another sub-module');
    });

    test('non-class teacher with attendance grants: attendance entry, route and quick action stay hidden', () async {
      final h = await _boot(custom: personaA);
      expect(_visible(h), isNot(contains('attendance')));
      expect(_visible(h), isNot(contains('student_leaves')));
      expect(shellQuickActions(permissions: h.perms, isClassTeacher: false).map((a) => a.label), ['Add Homework', 'Apply Leave', 'Timetable']);
      for (final r in _routesOf['attendance']!) {
        expect(_allows(h, r), isFalse, reason: r);
      }
    });
  });

  group('route guard through real navigation', () {
    testWidgets("['teaching:homework:view'] class teacher: homework opens, every other Teaching module is replaced by the not-available screen", (t) async {
      Get.reset();
      Get.testMode = true;
      await t.runAsync(() async {
        final h = await signedIn(classTeacher: true, permissions: const ['teaching:homework:view']);
        await h.auth.refreshProfile(force: true);
      });
      await _app(t);
      expect(await _opens(t, Routes.homeworkDetailOf(_id)), isTrue);
      expect(await _opens(t, Routes.homeworkSubmissionsOf(_id)), isTrue);
      // view-only: the grading form and the new / edit form are refused
      expect(await _opens(t, Routes.homeworkGradeOf(_id, _id)), isFalse);
      expect(await _opens(t, Routes.homeworkNew), isFalse);
      for (final e in _routesOf.entries.where((e) => e.key != 'homework')) {
        for (final r in e.value) {
          expect(await _opens(t, r), isFalse, reason: r);
        }
      }
      expect(find.text('Not available for your account'), findsOneWidget);
    });

    testWidgets('[] -> blocked everywhere in Teaching; safeguarding still opens', (t) async {
      Get.reset();
      Get.testMode = true;
      await t.runAsync(() async {
        final h = await signedIn(classTeacher: true, permissions: const <String>[]);
        await h.auth.refreshProfile(force: true);
      });
      await _app(t);
      for (final r in [Routes.attendanceMark, Routes.homework, Routes.lessonPlans, Routes.timetable, Routes.ptm, Routes.fixtures, Routes.syllabus]) {
        expect(await _opens(t, r), isFalse, reason: r);
      }
      expect(await _opens(t, Routes.safeguarding), isTrue);
    });
  });

  test('entryForRoute: every sub-route inherits its entry (and therefore its subModuleKey)', () {
    const keys = {'attendance': 'attendance', 'homework': 'homework', 'lesson_plans': 'lesson-plans', 'timetable': 'timetable', 'ptm': 'ptm', 'fixtures': 'fixtures', 'syllabus': 'syllabus'};
    for (final e in _routesOf.entries) {
      for (final r in e.value) {
        final entry = ModuleCatalog.entryForRoute(r)!;
        expect(entry.id, e.key, reason: r);
        expect(entry.subModuleKey, keys[e.key], reason: r);
        expect(entry.permission, 'teaching:view', reason: r);
      }
    }
    expect(ModuleCatalog.byId('student_leaves')!.subModuleKey, isNull, reason: 'decision note: no sub-module');
    expect(ModuleCatalog.byId('students')!.permission, 'students:view', reason: 'My students stays on students:view');
  });
}
