import 'package:eldermin_teacher_app/app/modules/home/models/shell_quick_actions.dart';
import 'package:eldermin_teacher_app/app/routes/app_routes.dart';
import 'package:eldermin_teacher_app/app/routes/route_guard.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_harness.dart';
import 'permission_matrix_test.dart' show Persona, personas;

void main() {
  tearDown(Get.reset);

  List<String> labels(Iterable<ShellQuickAction> a) => a.map((x) => x.label).toList();

  group('shell quick actions follow the module visibility rule (same as Classes / More / route guard)', () {
    test('class teacher with the default teacher permissions: all four, in order', () async {
      final h = await signedIn(classTeacher: true);
      final a = shellQuickActions(permissions: h.perms, isClassTeacher: h.auth.isClassTeacher);
      expect(labels(a), ['Mark Attendance', 'Add Homework', 'Apply Leave', 'Timetable']);
      expect(a.map((x) => x.route), [Routes.attendanceMark, Routes.homeworkNew, Routes.leaveApply, Routes.timetable]);
    });

    test('subject teacher (not a class teacher): no Mark Attendance', () async {
      final h = await signedIn(classTeacher: false);
      final a = shellQuickActions(permissions: h.perms, isClassTeacher: h.auth.isClassTeacher);
      expect(labels(a), ['Add Homework', 'Apply Leave', 'Timetable']);
    });

    test('attendance stays class-teacher-only even when the permission is granted', () async {
      final h = await signedIn(classTeacher: false, permissions: ['students:view', 'teaching:view']);
      expect(labels(shellQuickActions(permissions: h.perms, isClassTeacher: false)), isNot(contains('Mark Attendance')));
      Get.reset();
      final c = await signedIn(classTeacher: true, permissions: ['students:view', 'teaching:view']);
      expect(labels(shellQuickActions(permissions: c.perms, isClassTeacher: true)), isNot(contains('Mark Attendance'))); // view-only
      Get.reset();
      final m = await signedIn(classTeacher: true, permissions: ['students:view', 'teaching:attendance:manage']);
      expect(labels(shellQuickActions(permissions: m.perms, isClassTeacher: true)), contains('Mark Attendance'));
    });

    // CHANGED (fix/custom-role-permissions): the Attendance gate is now `teaching:view` + sub-module `attendance` (web Teaching > Attendance), no
    // longer `students:view`. A module-wide `teaching:view` therefore grants Mark Attendance; `students:view` alone does not (it is not the gate).
    test('a class teacher with teaching:view (no students:view) gets Mark Attendance; students:view alone does not', () async {
      final h = await signedIn(classTeacher: true, permissions: ['teaching:view', 'leave:self']);
      // a custom role needs `:manage` to be offered a write action: teaching:view alone is read-only
      expect(labels(shellQuickActions(permissions: h.perms, isClassTeacher: true)), ['Apply Leave', 'Timetable']);
      Get.reset();
      final s = await signedIn(classTeacher: true, permissions: ['students:view', 'leave:self']);
      expect(labels(shellQuickActions(permissions: s.perms, isClassTeacher: true)), ['Apply Leave']);
    });

    test('a sub-module custom role: only the actions whose sub-module it holds (attendance + homework, not timetable)', () async {
      final h = await signedIn(classTeacher: true, permissions: ['teaching:attendance:manage', 'teaching:homework:manage']);
      expect(labels(shellQuickActions(permissions: h.perms, isClassTeacher: true)), ['Mark Attendance', 'Add Homework', 'Apply Leave']);
      Get.reset();
      final v = await signedIn(classTeacher: true, permissions: ['teaching:attendance:manage', 'teaching:homework:view']);
      expect(labels(shellQuickActions(permissions: v.perms, isClassTeacher: true)), ['Mark Attendance', 'Apply Leave']); // view-only homework: no Add Homework
    });

    test('an empty custom role: only the self-service Apply Leave (My leave is never removed)', () async {
      final h = await signedIn(classTeacher: false, permissions: <String>[]);
      expect(labels(shellQuickActions(permissions: h.perms, isClassTeacher: false)), ['Apply Leave']);
      Get.reset();
      final c = await signedIn(classTeacher: true, permissions: <String>[]);
      expect(labels(shellQuickActions(permissions: c.perms, isClassTeacher: true)), ['Apply Leave']);
    });

    test('leave only / teaching only: each action depends on its own permission', () async {
      final leaveOnly = await signedIn(permissions: ['leave:self']);
      expect(labels(shellQuickActions(permissions: leaveOnly.perms, isClassTeacher: false)), ['Apply Leave']);
      Get.reset();
      final teachingOnly = await signedIn(permissions: ['teaching:view']);
      expect(labels(shellQuickActions(permissions: teachingOnly.perms, isClassTeacher: false)), ['Apply Leave', 'Timetable']);
      Get.reset();
      final teachingManage = await signedIn(permissions: ['teaching:homework:manage', 'teaching:timetable:view']);
      expect(labels(shellQuickActions(permissions: teachingManage.perms, isClassTeacher: false)), ['Add Homework', 'Apply Leave', 'Timetable']);
    });

    for (final Persona p in personas) {
      test('persona "${p.name}": actions = exactly the modules this persona already sees, and every route is guard-allowed', () async {
        final h = await signedIn(classTeacher: p.classTeacher, permissions: p.custom);
        final a = shellQuickActions(permissions: h.perms, isClassTeacher: h.auth.isClassTeacher);
        final expected = [
          // write actions: the built-in teacher has them; the custom-role personas of this table are view-only for teaching
          if ((p.custom == null || p.custom!.contains('teaching:manage')) && p.classes.contains('attendance')) 'Mark Attendance',
          if ((p.custom == null || p.custom!.contains('teaching:manage')) && p.classes.contains('homework')) 'Add Homework',
          if (p.more.contains('leave')) 'Apply Leave',
          if (p.more.contains('timetable')) 'Timetable',
        ];
        expect(labels(a), expected);
        for (final x in a) {
          expect(
            RouteGuardRules.allows(x.route, signedIn: true, roleSupported: true, profileLoaded: true, permissions: h.perms, isClassTeacher: h.auth.isClassTeacher),
            isTrue,
            reason: '${p.name}: ${x.label} -> ${x.route} must pass the route guard',
          );
        }
      });
    }

    test('every action route is an existing, non-admin route', () {
      final all = [...Routes.all];
      for (final r in [Routes.attendanceMark, Routes.homeworkNew, Routes.leaveApply, Routes.timetable]) {
        expect(all, contains(r));
      }
    });
  });
}
