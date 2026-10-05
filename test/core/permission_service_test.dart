import 'package:eldermin_teacher_app/core/models/institution.dart';
import 'package:eldermin_teacher_app/core/models/teacher_user.dart';
import 'package:eldermin_teacher_app/core/services/permission_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('standard teacher role (no custom permissions)', () {
    final p = PermissionService(role: 'teacher');

    test('has the teacher matrix from web roles.ts', () {
      for (final perm in [
        'dashboard:view',
        'teaching:view',
        'students:view',
        'academics:view',
        'assessments:view',
        'assessments:manage',
        'behaviour:view',
        'behaviour:manage',
        'school-calendar:view',
        'events:view',
        'leave:self',
      ]) {
        expect(p.canAccess(perm), isTrue, reason: perm);
      }
    });

    test('has no admin permissions', () {
      for (final perm in [
        'teaching:manage',
        'students:manage',
        'academics:manage',
        'hr:view',
        'hr:manage',
        'finance:view',
        'school-calendar:manage',
        'events:manage',
        'institution:manage',
      ]) {
        expect(p.canAccess(perm), isFalse, reason: perm);
      }
    });

    test('sub-module keys are ignored for standard roles (module-wide only)', () {
      expect(p.canAccess('teaching:view', subModuleKey: 'lesson-plans'), isTrue);
      expect(p.canAccess('teaching:manage', subModuleKey: 'lesson-plans'), isFalse);
    });
  });

  test('unknown / empty roles are denied by default', () {
    expect(PermissionService(role: 'wizard').canAccess('dashboard:view'), isFalse);
    expect(PermissionService(role: '').canAccess('dashboard:view'), isFalse);
    expect(PermissionService().canAccess('dashboard:view'), isFalse);
    // A role present on the web but not allow-listed in the app.
    expect(PermissionService(role: 'principal').canAccess('dashboard:view'), isFalse);
  });

  group('custom user.permissions override', () {
    test('fully replaces the role matrix', () {
      final p = PermissionService(role: 'teacher', customPermissions: ['students:view']);
      expect(p.canAccess('students:view'), isTrue);
      // Standard teacher grants vanish when a custom role is assigned.
      expect(p.canAccess('teaching:view'), isFalse);
      expect(p.canAccess('assessments:manage'), isFalse);
    });

    test('empty custom list means nothing is allowed', () {
      final p = PermissionService(role: 'teacher', customPermissions: const []);
      expect(p.canAccess('dashboard:view'), isFalse);
    });

    test('custom role can grant more than the standard role', () {
      final p = PermissionService(role: 'teacher', customPermissions: ['teaching:manage']);
      expect(p.canAccess('teaching:manage'), isTrue);
    });

    test('sub-module grants (3-part) follow web hasSubModulePermission', () {
      final p = PermissionService(
        role: 'teacher',
        customPermissions: ['teaching:lesson-plans:manage', 'students:roster:view'],
      );
      // exact sub-module + level
      expect(p.canAccess('teaching:manage', subModuleKey: 'lesson-plans'), isTrue);
      // manage implies view for the same sub-module
      expect(p.canAccess('teaching:view', subModuleKey: 'lesson-plans'), isTrue);
      // other sub-module not granted
      expect(p.canAccess('teaching:view', subModuleKey: 'homework'), isFalse);
      // view does not imply manage
      expect(p.canAccess('students:manage', subModuleKey: 'roster'), isFalse);
      // module-level check: any granular grant satisfies the bare 'view'
      expect(p.canAccess('teaching:view'), isTrue);
      expect(p.canAccess('students:view'), isTrue);
      // ... and 'manage' only if some grant is manage
      expect(p.canAccess('teaching:manage'), isTrue);
      expect(p.canAccess('students:manage'), isFalse);
      // module-wide grant satisfies a sub-module check
      final q = PermissionService(role: 'teacher', customPermissions: ['teaching:view']);
      expect(q.canAccess('teaching:view', subModuleKey: 'anything'), isTrue);
    });

    test('2-part grants do not leak across modules or prefixes', () {
      final p = PermissionService(role: 'teacher', customPermissions: ['teaching:view']);
      expect(p.canAccess('teaching-extra:view'), isFalse);
      expect(p.canAccess('students:view'), isFalse);
    });
  });

  group('activeModules visibility rule', () {
    final p = PermissionService(role: 'teacher', activeModules: ['teaching', 'assessment']);

    test('empty requirement is always satisfied', () {
      expect(p.isModuleActive(const []), isTrue);
    });

    test('any-of semantics', () {
      expect(p.isModuleActive(['teaching']), isTrue);
      expect(p.isModuleActive(['library', 'assessment']), isTrue);
      expect(p.isModuleActive(['library']), isFalse);
    });

    test('canSee needs permission AND module', () {
      expect(p.canSee(permission: 'teaching:view', requiredModules: ['teaching']), isTrue);
      expect(p.canSee(permission: 'teaching:manage', requiredModules: ['teaching']), isFalse);
      expect(p.canSee(permission: 'academics:view', requiredModules: ['library']), isFalse);
      expect(p.canSee(permission: 'leave:self'), isTrue);
    });

    test('no active modules hides every module-gated entry', () {
      final none = PermissionService(role: 'teacher');
      expect(none.canSee(permission: 'teaching:view', requiredModules: ['teaching']), isFalse);
      expect(none.canSee(permission: 'events:view'), isTrue);
    });
  });

  test('update()/clear() follow the session', () {
    final p = PermissionService();
    const user = TeacherUser(id: '1', name: 'A B', email: 'a@b.c', role: 'teacher');
    p.update(user, const Institution(activeModules: ['teaching']));
    expect(p.canAccess('teaching:view'), isTrue);
    expect(p.isModuleActive(['teaching']), isTrue);
    p.clear();
    expect(p.canAccess('teaching:view'), isFalse);
    expect(p.isModuleActive(['teaching']), isFalse);
  });
}
