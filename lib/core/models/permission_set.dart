/// Role -> permission matrix plus an optional school-defined custom-role
/// override. A faithful port of the web's `roles.ts`
/// (`ROLE_PERMISSIONS`, `roleHasPermission`, `hasSubModulePermission`)
/// - keep it in sync with Eldermin-Frontend/src/types/roles.ts.
class PermissionSet {
  /// Base role value from the backend (`user.role`), e.g. `teacher`.
  final String? role;

  /// `user.permissions`. When non-null (a custom role is assigned) it
  /// FULLY overrides the standard matrix - exactly like the web's
  /// `canAccess`. An empty list therefore means "nothing allowed".
  final List<String>? custom;

  const PermissionSet({this.role, this.custom});

  /// Standard enum-role matrix. Only roles the app can sign in are
  /// listed; unknown roles are denied by default (secure default - do
  /// not turn this into allow-by-default). Add e.g. coordinator roles
  /// here when they are approved for the app.
  static const Map<String, Set<String>> rolePermissions = {
    // roles.ts -> UserRole.Teacher
    'teacher': {
      'dashboard:view',
      'teaching:view',
      'students:view',
      'academics:view',
      'assessments:view',
      'assessments:manage',
      'behaviour:view',
      'behaviour:manage',
      'early-years:view',
      'early-years:manage',
      'apps:view',
      'school-calendar:view',
      'events:view',
      'leave:self',
    },
  };

  bool roleHas(String permission) {
    final r = role;
    if (r == null || r.isEmpty) return false;
    return rolePermissions[r]?.contains(permission) ?? false;
  }

  /// Mirrors web `hasSubModulePermission(permissions, role, permission, subModuleKey)`.
  bool has(String permission, {String? subModuleKey}) {
    final perms = custom;
    if (perms == null) {
      // Standard enum roles have no sub-module concept - module-wide only.
      return roleHas(permission);
    }
    final parts = permission.split(':');
    final moduleKey = parts.first;
    final level = parts.length > 1 ? parts[1] : '';
    if (subModuleKey != null) {
      if (perms.contains('$moduleKey:$subModuleKey:$level')) return true;
      // 'manage' implies 'view'.
      if (level == 'view' && perms.contains('$moduleKey:$subModuleKey:manage')) return true;
      return perms.contains(permission);
    }
    if (perms.contains(permission)) return true;
    final prefix = '$moduleKey:';
    return perms.any((p) {
      if (!p.startsWith(prefix)) return false;
      final segs = p.split(':');
      if (segs.length != 3) return false; // only 3-part = sub-module grants
      final granted = segs[2];
      return level == 'view' ? (granted == 'view' || granted == 'manage') : granted == 'manage';
    });
  }
}
