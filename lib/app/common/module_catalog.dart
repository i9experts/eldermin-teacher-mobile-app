import 'package:flutter/material.dart';
import '../../core/services/permission_service.dart';
import '../routes/app_routes.dart';

/// Where a module entry is listed.
enum ModulePlacement { classes, more }

/// One user-facing module entry (Part D.3 of the audit). Visibility is
/// ALWAYS: permission (web `canAccess` semantics) AND active-module AND
/// the v1 / class-teacher flags below.
class ModuleEntry {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  final ModulePlacement placement;

  /// Web-style permission, e.g. `students:view`. Null = no permission gate.
  final String? permission;
  final String? subModuleKey;

  /// Any-of backend module-registry ids (`eldermin-backend/src/modules/
  /// module-registry.ts`) that must be active for the school. Empty = not
  /// module-gated. Legacy aliases from older tenants are included.
  final List<String> requiredModules;

  /// Only class teachers see it (e.g. attendance, student-leave review).
  final bool classTeacherOnly;

  /// False = slot exists in the route list but is hidden in v1.
  final bool enabledInV1;

  const ModuleEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    required this.placement,
    this.permission,
    this.subModuleKey,
    this.requiredModules = const [],
    this.classTeacherOnly = false,
    this.enabledInV1 = true,
  });

  bool isVisibleTo(PermissionService permissions, {required bool isClassTeacher}) {
    if (!enabledInV1) return false;
    if (classTeacherOnly && !isClassTeacher) return false;
    return permissions.canSee(
      permission: permission,
      subModuleKey: subModuleKey,
      requiredModules: requiredModules,
    );
  }
}

const _teaching = ['teaching'];
const _students = ['students', 'student_profile'];

/// All module entries, in display order.
class ModuleCatalog {
  ModuleCatalog._();

  static const List<ModuleEntry> all = [
    // ── Classes tab ──
    ModuleEntry(id: 'students', title: 'My students', subtitle: 'Roster and Student 360', icon: Icons.groups_rounded, route: Routes.students, placement: ModulePlacement.classes, permission: 'students:view', requiredModules: _students),
    ModuleEntry(id: 'homework', title: 'Homework', subtitle: 'Assign and grade', icon: Icons.menu_book_rounded, route: Routes.homework, placement: ModulePlacement.classes, permission: 'teaching:view', requiredModules: _teaching),
    ModuleEntry(id: 'lesson_plans', title: 'Lesson plans', subtitle: 'Plan and submit', icon: Icons.edit_note_rounded, route: Routes.lessonPlans, placement: ModulePlacement.classes, permission: 'teaching:view', requiredModules: _teaching),
    ModuleEntry(id: 'syllabus', title: 'Syllabus', subtitle: 'Track coverage', icon: Icons.checklist_rounded, route: Routes.syllabus, placement: ModulePlacement.classes, permission: 'teaching:view', requiredModules: ['syllabus', 'curriculum']),
    ModuleEntry(id: 'assessments', title: 'Assessments & marks', subtitle: 'Enter marks, remarks', icon: Icons.fact_check_rounded, route: Routes.assessments, placement: ModulePlacement.classes, permission: 'assessments:view', requiredModules: ['assessment']),
    ModuleEntry(id: 'behaviour', title: 'Behaviour & Tarbiyah', subtitle: 'Log and review', icon: Icons.emoji_events_rounded, route: Routes.behaviour, placement: ModulePlacement.classes, permission: 'behaviour:view', requiredModules: ['behaviour']),

    // ── More tab ──
    ModuleEntry(id: 'timetable', title: 'Timetable', subtitle: 'Your weekly schedule', icon: Icons.calendar_view_week_rounded, route: Routes.timetable, placement: ModulePlacement.more, permission: 'teaching:view', requiredModules: ['timetable', 'teaching']),
    ModuleEntry(id: 'student_leaves', title: 'Student leave requests', subtitle: 'Approve or reject', icon: Icons.event_busy_rounded, route: Routes.studentLeaves, placement: ModulePlacement.more, permission: 'teaching:view', requiredModules: _students, classTeacherOnly: true),
    ModuleEntry(id: 'ptm', title: 'Parent meetings', subtitle: 'Schedule and outcomes', icon: Icons.handshake_rounded, route: Routes.ptm, placement: ModulePlacement.more, permission: 'teaching:view', requiredModules: _teaching),
    ModuleEntry(id: 'fixtures', title: 'Substitutions', subtitle: 'Cover duties', icon: Icons.swap_horiz_rounded, route: Routes.fixtures, placement: ModulePlacement.more, permission: 'teaching:view', requiredModules: _teaching),
    ModuleEntry(id: 'leave', title: 'My leave', subtitle: 'Balance and requests', icon: Icons.beach_access_rounded, route: Routes.leave, placement: ModulePlacement.more, permission: 'leave:self', requiredModules: ['hr', 'human_resource']),
    ModuleEntry(id: 'calendar', title: 'School calendar', subtitle: 'Dates and circulars', icon: Icons.calendar_month_rounded, route: Routes.calendar, placement: ModulePlacement.more, permission: 'school-calendar:view'),
    ModuleEntry(id: 'events', title: 'Events', subtitle: 'School events', icon: Icons.celebration_rounded, route: Routes.events, placement: ModulePlacement.more, permission: 'events:view'),
    ModuleEntry(id: 'curriculum', title: 'Curriculum', subtitle: 'Frameworks and subjects', icon: Icons.account_tree_rounded, route: Routes.curriculum, placement: ModulePlacement.more, permission: 'academics:view', requiredModules: ['curriculum']),
    ModuleEntry(id: 'library', title: 'Library', subtitle: 'Search books', icon: Icons.local_library_rounded, route: Routes.library, placement: ModulePlacement.more, permission: 'academics:view', requiredModules: ['library']),
    // Slot exists; hidden in v1 (owner decision).
    ModuleEntry(id: 'early_years', title: 'Early Years', subtitle: 'Observations and portfolios', icon: Icons.child_care_rounded, route: Routes.earlyYears, placement: ModulePlacement.more, permission: 'early-years:view', requiredModules: ['early-years', 'early_years', 'ece'], enabledInV1: false),
    // Deliberately NOT module-gated: a safeguarding route must never be hidden.
    ModuleEntry(id: 'safeguarding', title: 'Raise a concern', subtitle: 'Safeguarding report', icon: Icons.shield_rounded, route: Routes.safeguardingNew, placement: ModulePlacement.more),
  ];

  static List<ModuleEntry> visible(
    ModulePlacement placement,
    PermissionService permissions, {
    required bool isClassTeacher,
  }) =>
      all
          .where((e) => e.placement == placement && e.isVisibleTo(permissions, isClassTeacher: isClassTeacher))
          .toList();
}
