import 'package:flutter/material.dart';
import '../../core/services/permission_service.dart';
import '../routes/app_routes.dart';

/// Where a module entry is listed.
enum ModulePlacement { classes, more }

/// One user-facing module entry (Part D.3 of the audit). Visibility is
/// ALWAYS: permission (web `canAccess` semantics, incl. the optional
/// [subModuleKey] for custom roles) AND the v1 / class-teacher flags below.
/// The web gates menu/routes on institution.activeModules (Sidebar.tsx
/// moduleId via hasModule; ProtectedRoute `module`); the app intentionally
/// does not in v1 - visibility is by permissions only - pending an owner decision.
class ModuleEntry {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  final ModulePlacement placement;

  /// Web-style permission, e.g. `students:view`. Null = no permission gate.
  final String? permission;

  /// Teaching sub-module (web `canAccess(permission, subModuleKey)`): a custom role is checked against `module:sub:level`. Ignored for the
  /// built-in teacher role. Sub-routes inherit it through [ModuleCatalog.entryForRoute].
  final String? subModuleKey;

  /// Only class teachers see it (e.g. attendance, student-leave review).
  final bool classTeacherOnly;

  /// False = slot exists in the route list but is hidden in v1.
  final bool enabledInV1;

  /// True once the module has a real screen. False = the route still opens the honest
  /// "still being built" shell, and the Classes grid labels it "Coming soon".
  final bool built;

  const ModuleEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    required this.placement,
    this.permission,
    this.subModuleKey,
    this.classTeacherOnly = false,
    this.enabledInV1 = true,
    this.built = false,
  });

  bool isVisibleTo(PermissionService permissions, {required bool isClassTeacher}) {
    if (!enabledInV1) return false;
    if (classTeacherOnly && !isClassTeacher) return false;
    return permissions.canSee(permission: permission, subModuleKey: subModuleKey);
  }
}

/// All module entries, in display order.
class ModuleCatalog {
  ModuleCatalog._();

  static const List<ModuleEntry> all = [
    // ── Classes tab ──
    ModuleEntry(id: 'students', title: 'My students', subtitle: 'Roster and Student 360', icon: Icons.groups_rounded, route: Routes.students, placement: ModulePlacement.classes, permission: 'students:view', built: true),
    ModuleEntry(id: 'attendance', title: 'Attendance', subtitle: 'Mark and review your class', icon: Icons.fact_check_outlined, route: Routes.attendance, placement: ModulePlacement.classes, permission: 'teaching:view', subModuleKey: 'attendance', classTeacherOnly: true, built: true),
    ModuleEntry(id: 'homework', title: 'Homework', subtitle: 'Assign and grade', icon: Icons.menu_book_rounded, route: Routes.homework, placement: ModulePlacement.classes, permission: 'teaching:view', subModuleKey: 'homework', built: true),
    ModuleEntry(id: 'lesson_plans', title: 'Lesson plans', subtitle: 'Plan and submit', icon: Icons.edit_note_rounded, route: Routes.lessonPlans, placement: ModulePlacement.classes, permission: 'teaching:view', subModuleKey: 'lesson-plans', built: true),
    ModuleEntry(id: 'syllabus', title: 'Syllabus', subtitle: 'Track coverage', icon: Icons.checklist_rounded, route: Routes.syllabus, placement: ModulePlacement.classes, permission: 'teaching:view', subModuleKey: 'syllabus', built: true),
    ModuleEntry(id: 'assessments', title: 'Assessments & marks', subtitle: 'Enter marks, remarks', icon: Icons.fact_check_rounded, route: Routes.assessments, placement: ModulePlacement.classes, permission: 'assessments:view', built: true),
    ModuleEntry(id: 'behaviour', title: 'Behaviour & Tarbiyah', subtitle: 'Log and review', icon: Icons.emoji_events_rounded, route: Routes.behaviour, placement: ModulePlacement.classes, permission: 'behaviour:view', built: true),

    // ── More tab ──
    ModuleEntry(id: 'timetable', title: 'Timetable', subtitle: 'Your weekly schedule', icon: Icons.calendar_view_week_rounded, route: Routes.timetable, placement: ModulePlacement.more, permission: 'teaching:view', subModuleKey: 'timetable', built: true),
    ModuleEntry(id: 'student_leaves', title: 'Student leave requests', subtitle: 'Approve or reject', icon: Icons.event_busy_rounded, route: Routes.studentLeaves, placement: ModulePlacement.more, permission: 'teaching:view', classTeacherOnly: true, built: true),
    ModuleEntry(id: 'ptm', title: 'Parent meetings', subtitle: 'Schedule and outcomes', icon: Icons.handshake_rounded, route: Routes.ptm, placement: ModulePlacement.more, permission: 'teaching:view', subModuleKey: 'ptm', built: true),
    ModuleEntry(id: 'fixtures', title: 'Substitutions', subtitle: 'Cover duties', icon: Icons.swap_horiz_rounded, route: Routes.fixtures, placement: ModulePlacement.more, permission: 'teaching:view', subModuleKey: 'fixtures', built: true),
    ModuleEntry(id: 'leave', title: 'My leave', subtitle: 'Balance and requests', icon: Icons.beach_access_rounded, route: Routes.leave, placement: ModulePlacement.more, permission: 'leave:self', built: true),
    ModuleEntry(id: 'my_attendance', title: 'My attendance', subtitle: 'Your days and correction requests', icon: Icons.event_available_rounded, route: Routes.myAttendance, placement: ModulePlacement.more, permission: 'attendance:self', built: true),
    ModuleEntry(id: 'calendar', title: 'School calendar', subtitle: 'Dates and circulars', icon: Icons.calendar_month_rounded, route: Routes.calendar, placement: ModulePlacement.more, permission: 'school-calendar:view', built: true),
    ModuleEntry(id: 'events', title: 'Events', subtitle: 'School events', icon: Icons.celebration_rounded, route: Routes.events, placement: ModulePlacement.more, permission: 'events:view', built: true),
    ModuleEntry(id: 'curriculum', title: 'Curriculum', subtitle: 'Frameworks and subjects', icon: Icons.account_tree_rounded, route: Routes.curriculum, placement: ModulePlacement.more, permission: 'academics:view', built: true),
    ModuleEntry(id: 'library', title: 'Library', subtitle: 'Search books', icon: Icons.local_library_rounded, route: Routes.library, placement: ModulePlacement.more, permission: 'academics:view', built: true),
    // Slot exists; hidden in v1 (owner decision).
    ModuleEntry(id: 'early_years', title: 'Early Years', subtitle: 'Observations and portfolios', icon: Icons.child_care_rounded, route: Routes.earlyYears, placement: ModulePlacement.more, permission: 'early-years:view', enabledInV1: false),
    // No permission gate: a safeguarding route must never be hidden.
    ModuleEntry(id: 'safeguarding', title: 'Raise a concern', subtitle: 'Safeguarding report', icon: Icons.shield_rounded, route: Routes.safeguarding, placement: ModulePlacement.more, built: true),
  ];

  /// The entry that owns [location] (a concrete path such as `/homework/abc/submissions`, a route pattern, optionally with a query), or null when
  /// the location belongs to no module (messages, notifications, profile, help, ...). Matches on the first path segment, which is how every
  /// module's list, detail and form routes share a prefix; the Home tab `/home/attendance` belongs to Attendance.
  static ModuleEntry? entryForRoute(String location) {
    final segments = Uri.tryParse(location)?.pathSegments.where((s) => s.isNotEmpty).toList() ?? const <String>[];
    if (segments.isEmpty) return null;
    if (segments.first == 'home') {
      return segments.length > 1 && segments[1] == 'attendance' ? byId('attendance') : null;
    }
    for (final e in all) {
      final first = e.route.split('/').where((s) => s.isNotEmpty).first;
      if (first == segments.first) return e;
    }
    return null;
  }

  /// Screens that exist only to WRITE (create / edit / approve forms), with the permission that writes there:
  /// `(module, sub-module)` for [PermissionService.canManage]. A view-only custom role is not offered them in the UI and the route guard
  /// refuses them (a notification target or a deep link must not open a form the role may not use). The marks grid is not listed: it opens read-only.
  static const List<({String pattern, String module, String? sub})> _writeLocations = [
    (pattern: r'^/homework/new$', module: 'teaching', sub: 'homework'),
    (pattern: r'^/homework/[^/]+/submissions/[^/]+/grade$', module: 'teaching', sub: 'homework'),
    (pattern: r'^/lesson-plans/(new|upload)$', module: 'teaching', sub: 'lesson-plans'),
    (pattern: r'^/ptm/new$', module: 'teaching', sub: 'ptm'),
    (pattern: r'^/attendance/mark$', module: 'teaching', sub: 'attendance'),
    (pattern: r'^/assessments/report-remarks$', module: 'assessments', sub: null),
    (pattern: r'^/behaviour/new$', module: 'behaviour', sub: null),
  ];

  /// May [location] be opened given what the user may WRITE? True for every read screen.
  static bool writeAllowed(String location, PermissionService permissions) {
    final path = Uri.tryParse(location)?.path ?? location;
    for (final w in _writeLocations) {
      if (RegExp(w.pattern).hasMatch(path)) return permissions.canManage(w.module, subModuleKey: w.sub);
    }
    return true;
  }

  static ModuleEntry? byId(String id) {
    for (final e in all) {
      if (e.id == id) return e;
    }
    return null;
  }

  static List<ModuleEntry> visible(
    ModulePlacement placement,
    PermissionService permissions, {
    required bool isClassTeacher,
  }) =>
      all
          .where((e) => e.placement == placement && e.isVisibleTo(permissions, isClassTeacher: isClassTeacher))
          .toList();
}
