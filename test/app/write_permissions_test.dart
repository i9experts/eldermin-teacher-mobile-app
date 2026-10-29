// Release A1 items 4 and 5: write actions follow the same permission source as module visibility (`user.permissions` of
// GET /staff-portal/me), and My leave / My attendance are self-service that no custom role can remove.
import 'package:eldermin_teacher_app/app/common/module_catalog.dart';
import 'package:eldermin_teacher_app/app/common/write_access.dart';
import 'package:eldermin_teacher_app/app/routes/route_guard.dart';
import 'package:eldermin_teacher_app/core/models/permission_set.dart';
import 'package:eldermin_teacher_app/core/services/permission_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

PermissionService svc([List<String>? custom, String? role = 'teacher']) => PermissionService(role: role, customPermissions: custom);

const _writeRoutes = [
  '/homework/new',
  '/homework/64a0000000000000000000c1/submissions/64a0000000000000000000c2/grade',
  '/lesson-plans/new',
  '/lesson-plans/upload',
  '/ptm/new',
  '/attendance/mark',
  '/attendance/mark?date=2026-10-05',
  '/behaviour/new',
  '/assessments/report-remarks?assessmentId=64a0000000000000000000c1',
];
const _readRoutes = [
  '/homework',
  '/homework/64a0000000000000000000c1',
  '/homework/64a0000000000000000000c1/submissions',
  '/lesson-plans',
  '/lesson-plans/64a0000000000000000000c1',
  '/ptm',
  '/ptm/64a0000000000000000000c1',
  '/attendance',
  '/attendance/history',
  '/assessments/64a0000000000000000000c1/marks', // opens read-only for a view-only role
  '/behaviour',
];

bool _allows(String loc, PermissionService p, {bool classTeacher = true}) =>
    RouteGuardRules.allows(loc, signedIn: true, roleSupported: true, profileLoaded: true, permissions: p, isClassTeacher: classTeacher);

void main() {
  tearDown(Get.reset);

  group('PermissionService.canManage', () {
    test('the built-in teacher (no custom role) may write: the base matrix has no teaching:manage, the server lets the role through', () {
      final p = svc();
      expect(p.isCustomRole, isFalse);
      expect(p.canManage('teaching', subModuleKey: 'homework'), isTrue);
      expect(p.canManage('teaching', subModuleKey: 'lesson-plans'), isTrue);
      expect(p.canManage('assessments'), isTrue);
      expect(p.canManage('behaviour'), isTrue);
    });

    test('a view-only custom role may not write anywhere it can read', () {
      final p = svc(['teaching:view', 'teaching:homework:view', 'assessments:view', 'behaviour:view', 'students:view']);
      expect(p.canAccess('teaching:view', subModuleKey: 'homework'), isTrue);
      expect(p.canManage('teaching', subModuleKey: 'homework'), isFalse);
      expect(p.canManage('teaching', subModuleKey: 'ptm'), isFalse);
      expect(p.canManage('teaching'), isFalse);
      expect(p.canManage('assessments'), isFalse);
      expect(p.canManage('behaviour'), isFalse);
    });

    test('a :manage grant is per sub-module; a module-wide :manage covers all of them', () {
      final p = svc(['teaching:homework:manage', 'teaching:ptm:view']);
      expect(p.canManage('teaching', subModuleKey: 'homework'), isTrue);
      expect(p.canManage('teaching', subModuleKey: 'ptm'), isFalse);
      expect(p.canManage('teaching', subModuleKey: 'lesson-plans'), isFalse);
      final all = svc(['teaching:manage']);
      expect(all.canManage('teaching', subModuleKey: 'ptm'), isTrue);
      expect(all.canManage('teaching', subModuleKey: 'attendance'), isTrue);
    });

    test('an empty custom role writes nothing', () {
      final p = svc(<String>[]);
      expect(p.canManage('teaching', subModuleKey: 'homework'), isFalse);
      expect(p.canManage('assessments'), isFalse);
    });
  });

  group('self-service (My leave / My attendance) is never removed by a custom role', () {
    test('any staff role, any custom role, even an empty one', () {
      for (final custom in <List<String>?>[null, <String>[], ['teaching:view'], ['hr:manage'], ['students:view', 'leave:self']]) {
        final p = svc(custom);
        expect(p.canAccess('leave:self'), isTrue, reason: '$custom');
        expect(p.canAccess('attendance:self'), isTrue, reason: '$custom');
        expect(p.canSee(permission: 'leave:self'), isTrue);
      }
    });

    test('catalog entries My leave and My attendance are visible to an empty custom role, for class teachers or not', () {
      final p = svc(<String>[]);
      for (final id in ['leave', 'my_attendance']) {
        expect(ModuleCatalog.byId(id)!.isVisibleTo(p, isClassTeacher: false), isTrue, reason: id);
      }
      expect(ModuleCatalog.visible(ModulePlacement.more, p, isClassTeacher: false).map((e) => e.id), ['leave', 'my_attendance', 'safeguarding']);
    });

    test('only the two self-service permissions are special: nothing else is granted by it', () {
      final p = svc(<String>[]);
      for (final perm in ['teaching:view', 'students:view', 'assessments:view', 'behaviour:view', 'events:view', 'academics:view']) {
        expect(p.canAccess(perm), isFalse, reason: perm);
      }
      expect(PermissionSet.selfService, {'leave:self', 'attendance:self'});
    });

    test('no role (signed out) or a role the app does not sign in has nothing, self-service included', () {
      for (final role in <String?>[null, '', 'parent', 'student', 'accountant']) {
        final p = svc(<String>[], role);
        expect(p.canAccess('leave:self'), isFalse, reason: '$role');
        expect(p.canAccess('attendance:self'), isFalse, reason: '$role');
      }
    });

    test('the self-service routes pass the route guard for an empty custom role', () {
      final p = svc(<String>[]);
      for (final r in ['/leave', '/leave/apply', '/my-attendance', '/my-attendance/correct']) {
        expect(_allows(r, p, classTeacher: false), isTrue, reason: r);
      }
    });
  });

  group('write screens are closed to a view-only role by the route guard (deep links and notification targets too)', () {
    test('view-only custom role: every write screen is refused, every read screen opens', () {
      final p = svc(['teaching:view', 'teaching:homework:view', 'assessments:view', 'behaviour:view', 'students:view']);
      for (final r in _writeRoutes) {
        expect(_allows(r, p), isFalse, reason: r);
      }
      for (final r in _readRoutes) {
        expect(_allows(r, p), isTrue, reason: r);
      }
    });

    test('built-in teacher: every write screen opens', () {
      for (final r in [..._writeRoutes, ..._readRoutes]) {
        expect(_allows(r, svc()), isTrue, reason: r);
      }
    });

    test('a role with the matching :manage grants opens the write screens', () {
      final p = svc([
        'teaching:homework:manage', 'teaching:lesson-plans:manage', 'teaching:ptm:manage', 'teaching:attendance:manage',
        'behaviour:manage', 'behaviour:view', 'assessments:manage', 'assessments:view', 'students:view',
      ]);
      for (final r in _writeRoutes) {
        expect(_allows(r, p), isTrue, reason: r);
      }
    });

    test('one sub-module grant does not open another sub-module form', () {
      final p = svc(['teaching:homework:manage', 'teaching:ptm:view', 'teaching:lesson-plans:view']);
      expect(_allows('/homework/new', p), isTrue);
      expect(_allows('/ptm/new', p), isFalse);
      expect(_allows('/lesson-plans/new', p), isFalse);
    });
  });

  group('canWrite helper (the one rule behind every write button)', () {
    test('follows the registered PermissionService; allows when none is registered (isolated widget tests)', () {
      expect(canWriteHomework, isTrue); // nothing registered
      Get.put(svc(['teaching:homework:view']));
      expect(canWriteHomework, isFalse);
      expect(canWritePtm, isFalse);
      expect(canWriteAssessments, isFalse);
      Get.reset();
      Get.put(svc(['teaching:homework:manage']));
      expect(canWriteHomework, isTrue);
      expect(canWritePtm, isFalse);
      expect(canApproveStudentLeaves, isTrue); // any teaching :manage grant
    });
  });
}
