import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/classroom/student_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../components/custom_text.dart';
import '../../../routes/app_routes.dart';
import '../controllers/students_controller.dart';
import 'widgets/student_widgets.dart';

/// My students (`/students`): the roster of each of MY classes with search. Read-only; tap a student for
/// the Student 360. Never lists students outside the teacher's classes.
class StudentsScreen extends GetView<StudentsController> {
  const StudentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const CustomText(text: 'My students', color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
      body: Obx(_body),
    );
  }

  Widget _body() {
    final c = controller;
    final state = c.state;
    final classes = c.classes;
    final current = c.current;
    // Reactive reads happen here, inside the Obx; the builder runs outside its tracking.
    final visible = c.visible;
    final query = c.query.value;
    final selected = c.selected.value;
    return ScreenStateView<List<StudentSummary>>(
      state: state,
      onRefresh: c.reload,
      onRetry: () => c.load(force: true),
      emptyIcon: classes.isEmpty ? Icons.school_outlined : Icons.groups_outlined,
      emptyTitle: classes.isEmpty ? "You aren't assigned to any class yet" : 'No students in ${current?.label ?? 'this class'}',
      emptySubtitle: classes.isEmpty
          ? 'Your classes come from your teaching assignments. Ask your school admin to assign you to a class.'
          : 'There are no active students in this class.',
      header: [
        ScreenHeader(
          title: 'My students',
          caption: current == null ? 'No classes assigned' : '${current.label}${current.isClassTeacherClass ? ' · Class teacher' : ''}',
        ),
        if (classes.length > 1) ...[ClassPicker(classes: classes, selected: selected, onSelect: c.selectClass), const SizedBox(height: 10)],
        if (state.hasData) SearchBox(controller: c.searchController, onChanged: (v) => c.query.value = v),
      ],
      builder: (all) {
        if (visible.isEmpty) {
          return [Padding(padding: const EdgeInsets.only(top: 24), child: AppEmptyView(key: const Key('students_search_empty'), icon: Icons.search_off_rounded, title: 'No student matches "$query"'))];
        }
        return [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: CustomText(
              key: const Key('students_count'),
              text: query.isEmpty ? '${all.length} ${all.length == 1 ? 'student' : 'students'}' : '${visible.length} of ${all.length} students',
              color: AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          for (final s in visible) StudentTile(student: s, onTap: () => Get.toNamed(Routes.studentDetailOf(s.id))),
        ];
      },
    );
  }
}
