// Phase 8: permission matrix. One table of PERSONAS x everything a user can see or reach. Every persona is signed in through the real
// AuthController (-> /auth/me role gate, /staff-portal/me) and the REAL PermissionService; visibility comes from the real ModuleCatalog,
// the real Classes / More controllers and screens, the Home dashboard's quick actions and section flags, and the controllers' own `canView` /
// `canLog` / `allowed` gates. Expectations are written out by hand (NOT computed with the code under test).
//
// Facts this test pins (see eldermin-teacher-app-docs/phase8/ERROR_HANDLING_AUDIT.md for the server-side caveat):
//  * UI gating only; the server stays the authority.
//  * `institution.activeModules` never hides anything (owner decision A, web does not gate on it either).
//  * Route level: every GetPage carries RouteGuard (lib/app/routes/route_guard.dart), which applies the SAME ModuleEntry.isVisibleTo rule as the
//    entry lists, so a hidden entry is also unreachable by notification target / deep link (test/app/route_guard_test.dart). Controller gates are
//    the second line.
// ignore_for_file: invalid_use_of_protected_member
import 'package:eldermin_teacher_app/app/common/module_catalog.dart';
import 'package:eldermin_teacher_app/app/modules/assessments/controllers/assessments_controller.dart';
import 'package:eldermin_teacher_app/app/modules/attendance/controllers/attendance_controller.dart';
import 'package:eldermin_teacher_app/app/modules/auth/controllers/auth_controller.dart';
import 'package:eldermin_teacher_app/app/modules/auth/views/unsupported_role_screen.dart';
import 'package:eldermin_teacher_app/app/modules/behaviour/controllers/behaviour_controller.dart';
import 'package:eldermin_teacher_app/app/modules/classes/controllers/classes_controller.dart';
import 'package:eldermin_teacher_app/app/modules/classes/views/classes_screen.dart';
import 'package:eldermin_teacher_app/app/modules/curriculum/controllers/curriculum_controller.dart';
import 'package:eldermin_teacher_app/app/modules/homework/controllers/homework_controller.dart';
import 'package:eldermin_teacher_app/app/modules/home/controllers/home_dashboard_controller.dart';
import 'package:eldermin_teacher_app/app/modules/lesson_plans/controllers/lesson_plans_controller.dart';
import 'package:eldermin_teacher_app/app/modules/library/controllers/library_controller.dart';
import 'package:eldermin_teacher_app/app/modules/more/controllers/more_controller.dart';
import 'package:eldermin_teacher_app/app/modules/more/views/more_screen.dart';
import 'package:eldermin_teacher_app/app/modules/student_leaves/controllers/student_leaves_controller.dart';
import 'package:eldermin_teacher_app/app/modules/students/controllers/students_controller.dart';
import 'package:eldermin_teacher_app/app/modules/syllabus/controllers/syllabus_controller.dart';
import 'package:eldermin_teacher_app/app/modules/timetable/controllers/timetable_controller.dart';
import 'package:eldermin_teacher_app/app/routes/app_routes.dart';
import 'package:eldermin_teacher_app/core/services/permission_service.dart';
import 'package:eldermin_teacher_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_harness.dart';

class Persona {
  final String name;
  final bool classTeacher;
  final List<String>? custom; // user.permissions override
  final List<String> classes, more, quick; // module ids / quick-action titles, in display order
  final Set<String> perms, noPerms; // permissions that must / must not be granted
  final bool showTeachingSections, canLogBehaviour;
  const Persona(this.name, {this.classTeacher = false, this.custom, required this.classes, required this.more, required this.quick, this.perms = const {}, this.noPerms = const {}, required this.showTeachingSections, required this.canLogBehaviour});
}

const _teacherPerms = {'dashboard:view', 'teaching:view', 'students:view', 'academics:view', 'assessments:view', 'assessments:manage', 'behaviour:view', 'behaviour:manage', 'school-calendar:view', 'events:view', 'leave:self', 'attendance:self'};
// every admin-ish permission the web has; NO persona of this app may hold or be granted effect by any of them
const _adminPerms = {'hr:view', 'hr:manage', 'finance:view', 'finance:manage', 'institution:manage', 'roles:manage', 'users:manage', 'teaching:manage', 'students:manage', 'academics:manage', 'school-calendar:manage', 'events:manage', 'settings:manage', 'payroll:manage', 'fees:manage'};

final personas = <Persona>[
  const Persona('plain teacher',
      classes: ['students', 'homework', 'lesson_plans', 'syllabus', 'assessments', 'behaviour'],
      more: ['timetable', 'ptm', 'fixtures', 'leave', 'my_attendance', 'calendar', 'events', 'curriculum', 'library', 'safeguarding'],
      quick: ['Homework', 'Lesson plans', 'Assessments & marks', 'Behaviour & Tarbiyah', 'My leave', 'Parent meetings'],
      perms: _teacherPerms,
      noPerms: _adminPerms,
      showTeachingSections: true,
      canLogBehaviour: true),
  Persona('class teacher',
      classTeacher: true,
      classes: ['students', 'attendance', 'homework', 'lesson_plans', 'syllabus', 'assessments', 'behaviour'],
      more: ['timetable', 'student_leaves', 'ptm', 'fixtures', 'leave', 'my_attendance', 'calendar', 'events', 'curriculum', 'library', 'safeguarding'],
      quick: ['Attendance', 'Homework', 'Lesson plans', 'Assessments & marks', 'Behaviour & Tarbiyah', 'My leave', 'Parent meetings'],
      perms: _teacherPerms,
      noPerms: _adminPerms,
      showTeachingSections: true,
      canLogBehaviour: true),
  Persona('custom role: teaching + students + leave only',
      custom: ['teaching:view', 'students:view', 'leave:self'],
      classes: ['students', 'homework', 'lesson_plans', 'syllabus'],
      more: ['timetable', 'ptm', 'fixtures', 'leave', 'safeguarding'],
      quick: ['Homework', 'Lesson plans', 'My leave', 'Parent meetings'],
      perms: {'teaching:view', 'students:view', 'leave:self'},
      noPerms: {..._adminPerms, 'attendance:self', 'assessments:view', 'behaviour:view', 'behaviour:manage', 'academics:view', 'events:view', 'school-calendar:view', 'dashboard:view'},
      showTeachingSections: true,
      canLogBehaviour: false),
  Persona('custom role + class teacher flag',
      classTeacher: true,
      custom: ['teaching:view', 'students:view'],
      classes: ['students', 'attendance', 'homework', 'lesson_plans', 'syllabus'],
      more: ['timetable', 'student_leaves', 'ptm', 'fixtures', 'safeguarding'],
      quick: ['Attendance', 'Homework', 'Lesson plans', 'Parent meetings'],
      perms: {'teaching:view', 'students:view'},
      noPerms: {..._adminPerms, 'leave:self', 'attendance:self', 'assessments:view'},
      showTeachingSections: true,
      canLogBehaviour: false),
  Persona('custom role with sub-module grants (3-part keys, web semantics)',
      custom: ['academics:library:view', 'assessments:marks:manage', 'behaviour:logging:manage'],
      classes: ['assessments', 'behaviour'],
      more: ['curriculum', 'library', 'safeguarding'],
      quick: ['Assessments & marks', 'Behaviour & Tarbiyah'],
      perms: {'academics:view', 'assessments:view', 'assessments:manage', 'behaviour:view', 'behaviour:manage'},
      noPerms: {..._adminPerms, 'teaching:view', 'students:view', 'leave:self'},
      showTeachingSections: false,
      canLogBehaviour: true),
  Persona('custom role that is ADMIN-flavoured (hr / finance / roles / settings ...) plus teaching:view',
      custom: [..._adminPerms, 'teaching:view'],
      classes: ['homework', 'lesson_plans', 'syllabus'],
      more: ['timetable', 'ptm', 'fixtures', 'safeguarding'],
      quick: ['Homework', 'Lesson plans', 'Parent meetings'],
      perms: {..._adminPerms, 'teaching:view'},
      noPerms: {'students:view', 'assessments:view', 'leave:self', 'attendance:self'},
      showTeachingSections: true,
      canLogBehaviour: false),
  Persona('custom role with an EMPTY permission list (nothing allowed)',
      custom: [],
      classes: [],
      more: ['safeguarding'],
      quick: [],
      perms: {},
      noPerms: {..._teacherPerms, ..._adminPerms},
      showTeachingSections: false,
      canLogBehaviour: false),
];

/// Route paths of anything admin-like. NONE may exist in the route table, in a module entry or in a quick action.
final _adminPath = RegExp(r'admin|payroll|payslip|finance|fee|roles?\b|users?\b|settings|hr\b|institution|campus|billing|refund|order|campaign|badge', caseSensitive: false);

Future<({AuthController auth, PermissionService perms})> boot(Persona p, {List<String> activeModules = const []}) async {
  Get.reset();
  Get.testMode = true;
  final h = await signedIn(classTeacher: p.classTeacher, permissions: p.custom, activeModules: activeModules);
  await h.auth.refreshProfile(force: true);
  return (auth: h.auth, perms: h.perms);
}

List<String> ids(PermissionService perms, ModulePlacement pl, bool ct) => ModuleCatalog.visible(pl, perms, isClassTeacher: ct).map((e) => e.id).toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  group('route table / catalog: no admin surface exists at all', () {
    test('no route path looks like an admin area', () {
      for (final r in [...Routes.all, Routes.home, Routes.login, Routes.splash]) {
        expect(_adminPath.hasMatch(r), isFalse, reason: r);
      }
    });

    test('no module entry (title / route / permission) is admin-flavoured; every gate is a VIEW / self permission of a teacher module', () {
      const teacherModules = {'teaching', 'students', 'academics', 'assessments', 'behaviour', 'early-years', 'school-calendar', 'events', 'leave', 'attendance'};
      for (final e in ModuleCatalog.all) {
        expect(_adminPath.hasMatch(e.route), isFalse, reason: '${e.id} ${e.route}');
        final perm = e.permission;
        if (perm == null) {
          expect(e.id, 'safeguarding', reason: 'only the safeguarding report is ungated (a safeguarding route must never be hidden)');
          continue;
        }
        final parts = perm.split(':');
        expect(teacherModules, contains(parts.first), reason: e.id);
        expect(parts.last, anyOf('view', 'self'), reason: '${e.id} must not be gated by a manage permission');
      }
    });

    test('the role allow-list of the app is exactly {teacher}', () {
      expect(kAllowedRoles, {'teacher'});
    });
  });

  for (final p in personas) {
    group('persona: ${p.name}', () {
      test('permission matrix (granted / not granted) through the real PermissionService after sign-in', () async {
        final m = await boot(p);
        expect(m.auth.roleSupported.value, isTrue);
        expect(m.perms.role, 'teacher');
        for (final perm in p.perms) {
          expect(m.perms.canAccess(perm), isTrue, reason: 'granted: $perm');
        }
        for (final perm in p.noPerms) {
          expect(m.perms.canAccess(perm), isFalse, reason: 'not granted: $perm');
        }
      });

      test('Classes grid, More list and Home quick actions show exactly the expected entries (order included)', () async {
        final m = await boot(p);
        expect(ids(m.perms, ModulePlacement.classes, m.auth.isClassTeacher), p.classes);
        expect(ids(m.perms, ModulePlacement.more, m.auth.isClassTeacher), p.more);
        final ctl = HomeDashboardController(auth: m.auth, permissions: m.perms, tick: null);
        expect(ctl.quickActions.map((a) => a.label).toList(), p.quick);
        // the same through the real controllers the screens use
        Get.put(m.perms);
        Get.put(m.auth);
        expect(ClassesController().entries.map((e) => e.id).toList(), p.classes);
        expect(MoreController().entries.map((e) => e.id).toList(), p.more);
      });

      test('quick actions are a subset of the visible modules (+ attendance) and never an admin route', () async {
        final m = await boot(p);
        final ctl = HomeDashboardController(auth: m.auth, permissions: m.perms, tick: null);
        final visibleRoutes = {
          for (final pl in ModulePlacement.values) ...ModuleCatalog.visible(pl, m.perms, isClassTeacher: m.auth.isClassTeacher).map((e) => e.route),
        };
        for (final a in ctl.quickActions) {
          expect(visibleRoutes, contains(a.route), reason: a.label);
          expect(_adminPath.hasMatch(a.route), isFalse, reason: a.route);
        }
      });

      test('Home sections and controller gates follow the permissions (canView / canLog / allowed)', () async {
        final m = await boot(p);
        final home = HomeDashboardController(auth: m.auth, permissions: m.perms, tick: null);
        expect(home.showTimetable, p.showTeachingSections);
        expect(home.showHomework, p.showTeachingSections);
        expect(home.showLessonPlans, p.showTeachingSections);
        expect(home.showPtms, p.showTeachingSections);
        expect(home.showSubstitutions, p.showTeachingSections);
        expect(home.showClassCard, p.classTeacher && p.classes.contains('students'));

        bool has(String id) => p.classes.contains(id) || p.more.contains(id);
        final a = m.auth, pm = m.perms;
        expect(StudentsController(auth: a, permissions: pm).canView, has('students'));
        expect(HomeworkController(auth: a, permissions: pm).canView, has('homework'));
        expect(LessonPlansController(auth: a, permissions: pm).canView, has('lesson_plans'));
        expect(SyllabusController(auth: a, permissions: pm).canView, has('syllabus'));
        expect(AssessmentsController(auth: a, permissions: pm).canView, has('assessments'));
        expect(BehaviourController(auth: a, permissions: pm).canView, has('behaviour'));
        expect(BehaviourController(auth: a, permissions: pm).canLog, p.canLogBehaviour);
        expect(TimetableController(auth: a, permissions: pm).canView, has('timetable'));
        expect(CurriculumController(auth: a, permissions: pm).canView, has('curriculum'));
        expect(LibraryController(auth: a, permissions: pm).canView, has('library'));
        expect(StudentLeavesController(auth: a).allowed, p.classTeacher, reason: 'student-leave review is for class teachers only');
        expect(AttendanceController(auth: a, permissions: pm).allowed, p.classTeacher && p.classes.contains('attendance') && p.perms.contains('students:view') && a.staffMe.value?.teacherProfile?.classTeacherOf != null);
      });

      test('institution.activeModules NEVER changes anything (owner decision A): none / unrelated / all modules give the identical result', () async {
        final base = await boot(p);
        final expectedClasses = ids(base.perms, ModulePlacement.classes, base.auth.isClassTeacher);
        final expectedMore = ids(base.perms, ModulePlacement.more, base.auth.isClassTeacher);
        for (final modules in [const <String>[], const ['hr', 'finance'], const ['teaching', 'students', 'academics', 'assessments', 'behaviour', 'events', 'school-calendar', 'leave', 'early-years', 'library', 'hr', 'finance', 'fees']]) {
          final m = await boot(p, activeModules: modules);
          expect(m.perms.activeModules, modules, reason: 'kept (informational)');
          expect(ids(m.perms, ModulePlacement.classes, m.auth.isClassTeacher), expectedClasses, reason: '$modules');
          expect(ids(m.perms, ModulePlacement.more, m.auth.isClassTeacher), expectedMore, reason: '$modules');
          expect(ids(m.perms, ModulePlacement.classes, m.auth.isClassTeacher), p.classes);
          expect(ids(m.perms, ModulePlacement.more, m.auth.isClassTeacher), p.more);
        }
      });

      testWidgets('Classes and More SCREENS render exactly the expected tiles, nothing admin, always the account items', (t) async {
        final m = (await t.runAsync(() => boot(p)))!;
        Get.put(m.perms);
        Get.put(m.auth);
        Get.put(ClassesController());
        Get.put(MoreController());
        await t.binding.setSurfaceSize(const Size(430, 2400));
        addTearDown(() => t.binding.setSurfaceSize(null));
        const all = ModuleCatalog.all;
        Future<void> show(Widget w) async {
          await t.pumpWidget(GetMaterialApp(theme: AppTheme.light, home: Scaffold(body: w)));
          await t.pump();
        }

        await show(const ClassesScreen());
        if (p.classes.isEmpty) {
          expect(find.text('Nothing available yet'), findsOneWidget);
        }
        for (final e in all.where((e) => e.placement == ModulePlacement.classes)) {
          expect(find.text(e.title), p.classes.contains(e.id) ? findsOneWidget : findsNothing, reason: 'Classes: ${e.id}');
        }

        await show(const MoreScreen());
        for (final e in all.where((e) => e.placement == ModulePlacement.more)) {
          expect(find.text(e.title), p.more.contains(e.id) ? findsOneWidget : findsNothing, reason: 'More: ${e.id}');
        }
        for (final fixed in ['Notifications', 'Profile', 'Help', 'About', 'Request account deletion', 'Sign out']) {
          expect(find.text(fixed), findsOneWidget, reason: fixed);
        }
        for (final admin in ['Payroll', 'Finance', 'Fees', 'Roles', 'Users', 'Settings', 'Admin', 'Recruitment', 'Early Years']) {
          expect(find.textContaining(admin), findsNothing, reason: admin);
        }
      });
    });
  }

  group('non-teacher roles hit the role gate: "use the web portal", no permissions, no /staff-portal/me', () {
    for (final role in ['admin', 'principal', 'parent', 'student', 'hr_manager', 'finance_manager', 'coordinator', 'super_admin', 'institution_owner', 'Teacher', '']) {
      testWidgets('role "$role" (even with a user.permissions override that grants teaching)', (t) async {
        final h = (await t.runAsync(() => signedIn(role: role, permissions: ['teaching:view', 'students:view', 'hr:manage'])))!;
        expect(h.auth.status.value, AuthStatus.authenticated);
        expect(h.auth.roleSupported.value, isFalse);
        expect(h.auth.staffMe.value, isNull, reason: 'staff-portal is never called for these roles');
        expect(h.auth.staffId, isNull);
        expect(h.auth.isClassTeacher, isFalse);
        expect(h.perms.role, isNull);
        for (final perm in {..._teacherPerms, ..._adminPerms}) {
          expect(h.perms.canAccess(perm), isFalse, reason: '$role must not hold $perm');
        }
        // nothing permission-gated is visible; the ungated safeguarding slot is unreachable because the gate screen replaces the whole app
        expect(ids(h.perms, ModulePlacement.classes, false), isEmpty);
        expect(ids(h.perms, ModulePlacement.more, false), ['safeguarding']);
        expect(HomeDashboardController(auth: h.auth, permissions: h.perms, tick: null).quickActions, isEmpty);
        await t.pumpWidget(GetMaterialApp(theme: AppTheme.light, home: const UnsupportedRoleScreen()));
        await t.pump();
        expect(find.text('Please use the Eldermin web portal'), findsOneWidget);
        expect(find.text('Sign out'), findsOneWidget);
        expect(find.byType(ClassesScreen), findsNothing);
        expect(find.byType(MoreScreen), findsNothing);
      });
    }
  });
}
