import '../models/institution.dart';
import '../models/permission_set.dart';
import '../models/teacher_user.dart';

/// Answers "may this user see/do X?" - pure Dart, no GetX/Flutter
/// dependency so it is trivially unit-testable.
///
///  * [canAccess] mirrors the web `canAccess(permission, subModuleKey?)`
///    from AuthContext.tsx (custom `user.permissions` override, else the
///    role matrix).
///  * `institution.activeModules` is kept (read-only, informational) but
///    NEVER hides anything: the web does not gate on it either
///    (AuthContext.hasModule exists but is never called; Sidebar.tsx and
///    ProtectedRoute.tsx use canAccess permissions only). Owner decision A.
class PermissionService {
  PermissionSet _set;
  List<String> _activeModules;

  PermissionService({String? role, List<String>? customPermissions, List<String> activeModules = const []})
      : _set = PermissionSet(role: role, custom: customPermissions),
        _activeModules = List.unmodifiable(activeModules);

  factory PermissionService.fromSession(TeacherUser? user, Institution? institution) =>
      PermissionService(
        role: user?.role,
        customPermissions: user?.permissions,
        activeModules: institution?.activeModules ?? const [],
      );

  void update(TeacherUser? user, Institution? institution) {
    _set = PermissionSet(role: user?.role, custom: user?.permissions);
    _activeModules = List.unmodifiable(institution?.activeModules ?? const []);
  }

  void clear() => update(null, null);

  String? get role => _set.role;
  List<String> get activeModules => _activeModules;

  bool canAccess(String permission, {String? subModuleKey}) =>
      _set.has(permission, subModuleKey: subModuleKey);

  /// Permission-only visibility, the rule used for every module entry
  /// (tabs, Classes grid, More list). No permission = always visible
  /// (e.g. safeguarding).
  bool canSee({String? permission, String? subModuleKey}) {
    if (permission == null) return true;
    return canAccess(permission, subModuleKey: subModuleKey);
  }
}
