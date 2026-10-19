import 'package:flutter/material.dart';
import '../../../../core/services/permission_service.dart';
import '../../../common/module_catalog.dart';
import '../../../routes/app_routes.dart';

/// One item of the shell's centre-FAB "Quick actions" sheet.
class ShellQuickAction {
  final String id;
  final String label;
  final String subtitle;
  final IconData icon;
  final String route;
  const ShellQuickAction(this.id, this.label, this.subtitle, this.icon, this.route);
}

/// The quick actions the signed-in teacher may use, in display order. Each
/// action is shown only when the module it belongs to is visible under the SAME
/// rule the Classes / More grids and the route guard use
/// ([ModuleEntry.isVisibleTo]: permission + class-teacher-only + enabled in v1),
/// so attendance stays class-teacher-only. An empty list hides the FAB.
List<ShellQuickAction> shellQuickActions({required PermissionService permissions, required bool isClassTeacher}) {
  bool allowed(String moduleId) => ModuleCatalog.byId(moduleId)?.isVisibleTo(permissions, isClassTeacher: isClassTeacher) ?? false;
  return [
    if (allowed('attendance'))
      const ShellQuickAction('attendance', 'Mark Attendance', "Take today's register", Icons.fact_check_outlined, Routes.attendanceMark),
    if (allowed('homework'))
      const ShellQuickAction('homework', 'Add Homework', 'Assign work to a class', Icons.menu_book_outlined, Routes.homeworkNew),
    if (allowed('leave'))
      const ShellQuickAction('leave', 'Apply Leave', 'Request time off', Icons.beach_access_outlined, Routes.leaveApply),
    if (allowed('timetable'))
      const ShellQuickAction('timetable', 'Timetable', 'Your weekly schedule', Icons.calendar_view_week_rounded, Routes.timetable),
  ];
}
