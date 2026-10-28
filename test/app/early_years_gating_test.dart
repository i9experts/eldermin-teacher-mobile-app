import 'package:eldermin_teacher_app/app/common/module_catalog.dart';
import 'package:eldermin_teacher_app/app/routes/app_routes.dart';
import 'package:eldermin_teacher_app/core/services/permission_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Early Years gating rows: `early-years:view` opens the module (list + child page), `early-years:manage` is needed for every create action.
/// Plain two-part permissions, as the web registry's single `early-years` sub-module: `manage` does NOT imply `view` on a 2-part grant
/// (only 3-part sub-module grants do, see PermissionSet.has), so a custom role needs `view` to see the module at all.
void main() {
  PermissionService custom(List<String> p) => PermissionService(role: 'teacher', customPermissions: p);
  final teacher = PermissionService(role: 'teacher');

  bool inMore(PermissionService s) => ModuleCatalog.visible(ModulePlacement.more, s, isClassTeacher: false).any((e) => e.id == 'early_years');

  test('the catalog entry is built, visible in v1 and gated on early-years:view', () {
    final e = ModuleCatalog.all.firstWhere((e) => e.id == 'early_years');
    expect(e.built, isTrue);
    expect(e.enabledInV1, isTrue);
    expect(e.permission, 'early-years:view');
    expect(e.route, Routes.earlyYears);
  });

  test('built-in teacher: sees the module and may create', () {
    expect(inMore(teacher), isTrue);
    expect(teacher.canAccess('early-years:view'), isTrue);
    expect(teacher.canAccess('early-years:manage'), isTrue);
  });

  test('custom role with no grants: nothing', () {
    final s = custom(const []);
    expect(inMore(s), isFalse);
    expect(s.canAccess('early-years:view'), isFalse);
    expect(s.canAccess('early-years:manage'), isFalse);
  });

  test('custom role with only early-years:view: sees the module, cannot create', () {
    final s = custom(const ['early-years:view']);
    expect(inMore(s), isTrue);
    expect(s.canAccess('early-years:manage'), isFalse);
  });

  test('custom role with only a 2-part early-years:manage: can create but manage does not imply view', () {
    final s = custom(const ['early-years:manage']);
    expect(s.canAccess('early-years:manage'), isTrue);
    expect(s.canAccess('early-years:view'), isFalse);
    expect(inMore(s), isFalse);
  });

  test('custom role with view + manage: sees everything', () {
    final s = custom(const ['early-years:view', 'early-years:manage']);
    expect(inMore(s), isTrue);
    expect(s.canAccess('early-years:manage'), isTrue);
  });

  test('a 3-part sub-module manage grant implies view', () {
    final s = custom(const ['early-years:early-years:manage']);
    expect(inMore(s), isTrue);
    expect(s.canAccess('early-years:manage'), isTrue);
  });

  test('the child and create routes inherit the module gate through the first path segment', () {
    for (final r in [Routes.earlyYearsChildOf('c'), Routes.earlyYearsQuickOf('c'), Routes.earlyYearsObserveOf('c'), Routes.earlyYearsPortfolioNewOf('c')]) {
      expect(ModuleCatalog.entryForRoute(r)?.id, 'early_years', reason: r);
    }
  });
}
