import '../models/institution.dart';
import '../models/permission_set.dart';
import '../models/teacher_user.dart';

/// Answers "may this user see/do X?" - pure Dart, no GetX/Flutter
/// dependency so it is trivially unit-testable.
///
///  * [canAccess] mirrors the web `canAccess(permission, subModuleKey?)`
///    from AuthContext.tsx (custom `user.permissions` override, else the
///    role matrix).
///  * [isModuleActive] is an ADDITIONAL, app-only UI visibility rule
///    (`institution.activeModules`); the web never gates on it and the
///    backend does not enforce it.
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

  /// True when [requiredModules] is empty (feature not module-gated) or
  /// at least one of the module ids is active for the school.
  bool isModuleActive(List<String> requiredModules) {
    if (requiredModules.isEmpty) return true;
    return requiredModules.any(_activeModules.contains);
  }

  /// Permission AND active-module check, the rule used for every
  /// module entry (tabs, Classes grid, More list).
  bool canSee({
    String? permission,
    String? subModuleKey,
    List<String> requiredModules = const [],
  }) {
    if (permission != null && !canAccess(permission, subModuleKey: subModuleKey)) return false;
    return isModuleActive(requiredModules);
  }
}
