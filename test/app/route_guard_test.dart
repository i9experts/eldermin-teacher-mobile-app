// Phase 8 follow-up: route guards. Every route in AppPages carries RouteGuard (except the public ones). The guard uses the real
// AuthController + PermissionService and the same ModuleEntry rule the Classes / More lists use, so a blocked location opens the friendly
// "Not available for your account" screen instead of the module. Navigation is real (GetMaterialApp + Get.toNamed); only the page BUILDERS
// are swapped for a marker so no network / binding is needed.
import 'package:eldermin_teacher_app/app/common/module_catalog.dart';
import 'package:eldermin_teacher_app/app/common/views/not_available_screen.dart';
import 'package:eldermin_teacher_app/app/modules/auth/controllers/auth_controller.dart';
import 'package:eldermin_teacher_app/app/routes/app_pages.dart';
import 'package:eldermin_teacher_app/app/routes/app_routes.dart';
import 'package:eldermin_teacher_app/app/routes/route_guard.dart';
import 'package:eldermin_teacher_app/core/models/messaging/notification_models.dart';
import 'package:eldermin_teacher_app/core/services/permission_service.dart';
import 'package:eldermin_teacher_app/core/theme/app_theme.dart';
import 'package:eldermin_teacher_app/core/utils/notification_target.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_harness.dart';

const _id = '64a0000000000000000000c1';

Future<void> _boot(WidgetTester t, {bool classTeacher = false, List<String>? custom, String role = 'teacher', bool signIn = true, List<String> activeModules = const []}) async {
  Get.reset();
  Get.testMode = true;
  if (signIn) {
    await t.runAsync(() async {
      final h = await signedIn(classTeacher: classTeacher, permissions: custom, role: role, activeModules: activeModules);
      await h.auth.refreshProfile(force: true);
    });
  }
}

Future<void> _app(WidgetTester t) async {
  await t.pumpWidget(const SizedBox()); // a fresh GetMaterialApp (its route tree is rebuilt after Get.reset)
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
  final blocked = find.byType(NotAvailableScreen).evaluate().isNotEmpty;
  if (!blocked) expect(find.textContaining('OPENED'), findsOneWidget, reason: location);
  return !blocked;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  group('route table', () {
    test('every page except the public ones has a RouteGuard; public ones have none', () {
      for (final p in AppPages.pages) {
        final guarded = (p.middlewares ?? const []).any((m) => m is RouteGuard);
        expect(guarded, !RouteGuardRules.isPublic(p.name), reason: p.name);
      }
      expect(RouteGuardRules.publicRoutes, containsAll([Routes.splash, Routes.login, Routes.forgotPassword, Routes.resetPassword, Routes.intro, Routes.unsupportedRole]));
    });

    test('entryForRoute maps list, detail, form and home-tab locations to their module', () {
      String? id(String l) => ModuleCatalog.entryForRoute(l)?.id;
      expect(id('/student-leaves/$_id'), 'student_leaves');
      expect(id('/students/$_id'), 'students');
      expect(id('/my-attendance'), 'my_attendance');
      expect(id('/my-attendance/correct'), 'my_attendance');
      expect(id('/attendance/mark'), 'attendance');
      expect(id('/homework/$_id/submissions/$_id/grade'), 'homework');
      expect(id('/assessments/report-remarks?assessmentId=$_id'), 'assessments');
      expect(id('/home/attendance'), 'attendance');
      expect(id('/home/more'), isNull);
      expect(id('/messages/$_id'), isNull);
      expect(id('/profile'), isNull);
      // every catalog entry owns its own route
      for (final e in ModuleCatalog.all) {
        expect(id(e.route), e.id, reason: e.route);
      }
    });
  });

  group('guard decisions through real navigation', () {
    testWidgets('plain teacher: class-teacher-only routes are blocked, the rest open', (t) async {
      await _boot(t);
      await _app(t);
      for (final r in [Routes.attendance, Routes.attendanceMark, Routes.attendanceHistory, Routes.studentLeaves, Routes.studentLeaveDetailOf(_id), Routes.homeAttendance]) {
        expect(await _opens(t, r), isFalse, reason: r);
      }
      expect(find.text('Not available for your account'), findsOneWidget);
      for (final r in [Routes.students, Routes.studentDetailOf(_id), Routes.homework, Routes.homeworkGradeOf(_id, _id), Routes.leave, Routes.myAttendance, Routes.myAttendanceCorrect, Routes.calendar, Routes.messageThreadOf(_id), Routes.profile, Routes.help, Routes.safeguarding, Routes.homeMore]) {
        expect(await _opens(t, r), isTrue, reason: r);
      }
    });

    testWidgets('class teacher may open attendance and student leaves', (t) async {
      await _boot(t, classTeacher: true);
      await _app(t);
      for (final r in [Routes.attendance, Routes.attendanceMark, Routes.studentLeaves, Routes.studentLeaveDetailOf(_id), Routes.homeAttendance]) {
        expect(await _opens(t, r), isTrue, reason: r);
      }
    });

    testWidgets('custom role without a permission is blocked from that module (and its detail routes) only', (t) async {
      await _boot(t, custom: ['teaching:view', 'students:view', 'leave:self']);
      await _app(t);
      for (final r in [Routes.assessments, Routes.assessmentDetailOf(_id), Routes.assessmentMarksOf(_id), Routes.behaviour, Routes.behaviourStudentOf(_id), Routes.events, Routes.eventDetailOf(_id), Routes.calendar, Routes.curriculum, Routes.library]) {
        expect(await _opens(t, r), isFalse, reason: r);
      }
      for (final r in [Routes.homework, Routes.timetable, Routes.ptmDetailOf(_id), Routes.students, Routes.leaveApply, Routes.safeguarding,
        // self-service: a custom role never removes it, with or without a leave:self / attendance:self key
        Routes.myAttendance, Routes.myAttendanceCorrect]) {
        expect(await _opens(t, r), isTrue, reason: r);
      }
    });

    testWidgets('activeModules never blocks (owner decision A: one rule set with the entry lists)', (t) async {
      await _boot(t, activeModules: const ['hr']);
      await _app(t);
      expect(await _opens(t, Routes.homework), isTrue);
    });

    testWidgets('non-teacher roles: every protected route is blocked', (t) async {
      for (final role in ['admin', 'principal', 'parent', 'Teacher', '']) {
        await _boot(t, role: role);
        await _app(t);
        for (final r in [Routes.homework, Routes.students, Routes.messageThreadOf(_id), Routes.profile, Routes.help, Routes.notifications, Routes.deleteAccount, Routes.safeguarding]) {
          expect(await _opens(t, r), isFalse, reason: '$role $r');
        }
      }
    });

    testWidgets('no session: protected routes blocked, login / forgot / reset / splash / intro keep working', (t) async {
      await _boot(t, signIn: false);
      await _app(t);
      expect(await _opens(t, Routes.homework), isFalse);
      expect(await _opens(t, Routes.profile), isFalse);
      for (final r in [Routes.login, Routes.splash, Routes.forgotPassword, Routes.resetPassword, '${Routes.resetPassword}?token=abc', Routes.intro, Routes.unsupportedRole]) {
        expect(await _opens(t, r), isTrue, reason: r);
      }
    });

    testWidgets('the Back to home button leaves the screen', (t) async {
      await _boot(t);
      await _app(t);
      expect(await _opens(t, Routes.studentLeaves), isFalse);
      await t.tap(find.text('Back to home'));
      await t.pumpAndSettle();
      expect(find.text('ROOT'), findsOneWidget);
    });
  });

  group('notification / deep-link targets go through the guard', () {
    AppNotification n(String type, {String title = '', String id = _id}) => AppNotification(id: 'n', type: type, title: title, relatedEntityId: id);

    testWidgets('a target the user cannot open lands on the friendly screen', (t) async {
      await _boot(t, custom: ['students:view', 'leave:self']); // no teaching:view
      await _app(t);
      for (final x in [n('ptm'), n('substitution'), n('lesson_plan'), n('homework')]) {
        final target = notificationTargetFor(x, isClassTeacher: false)!;
        expect(await _opens(t, target.route), isFalse, reason: '${x.type} -> ${target.route}');
      }
      // still reachable: own leave status, messages
      expect(await _opens(t, notificationTargetFor(n('leave_status'), isClassTeacher: false)!.route), isTrue);
      expect(await _opens(t, notificationTargetFor(n('message'), isClassTeacher: false)!.route), isTrue);
    });

    testWidgets('student-leave notification: class teacher opens it; the route is blocked if the flag is lost', (t) async {
      await _boot(t, classTeacher: true);
      await _app(t);
      final target = notificationTargetFor(n('leave_status', title: newStudentLeaveTitle), isClassTeacher: true)!;
      expect(await _opens(t, target.route), isTrue);
      await _boot(t);
      await _app(t);
      expect(await _opens(t, target.route), isFalse);
    });

    test('allows() is pure over the same rule: unresolved profile is blocked', () {
      final perms = PermissionService(role: 'teacher');
      bool ok(String l, {bool signedIn = true, bool profile = true, bool ct = false}) => RouteGuardRules.allows(l,
          signedIn: signedIn, roleSupported: true, profileLoaded: profile, permissions: perms, isClassTeacher: ct);
      expect(ok(Routes.homework), isTrue);
      expect(ok(Routes.homework, profile: false), isFalse);
      expect(ok(Routes.homework, signedIn: false), isFalse);
      expect(ok(Routes.studentLeaves), isFalse);
      expect(ok(Routes.studentLeaves, ct: true), isTrue);
      expect(ok(Routes.earlyYears), isFalse, reason: 'hidden in v1');
      expect(ok(Routes.login, signedIn: false), isTrue);
      expect(AuthStatus.values, isNotEmpty);
    });
  });
}
