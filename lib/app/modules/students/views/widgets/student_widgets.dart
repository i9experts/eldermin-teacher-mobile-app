import 'package:flutter/material.dart';
import '../../../../../core/design/design.dart';
import '../../../../../core/models/classroom/student_models.dart';
import '../../../../../core/utils/roster_scope.dart';

/// Round avatar: the photo when there is one, else the initials.
class StudentAvatar extends StatelessWidget {
  final StudentSummary student;
  final double size;
  const StudentAvatar({super.key, required this.student, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final url = student.photoUrl;
    return EmAvatar(initials: student.initials, imageUrl: (url == null || !url.startsWith('http')) ? null : url, size: size);
  }
}

class StudentTile extends StatelessWidget {
  final StudentSummary student;
  final VoidCallback onTap;
  const StudentTile({super.key, required this.student, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sub = [
      if ((student.rollNumber ?? '').isNotEmpty) 'Roll ${student.rollNumber}',
      if ((student.grNo ?? '').isNotEmpty) student.grNo!,
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: EmSpacing.s8),
      child: EmListRow(
        key: ValueKey('student_${student.id}'),
        leading: StudentAvatar(student: student, size: 44),
        title: student.fullName,
        subtitle: sub.isEmpty ? null : sub,
        trailing: const Icon(Icons.chevron_right_rounded, color: EmColors.textSecondary),
        onTap: onTap,
      ),
    );
  }
}

/// Horizontal class chips (the teacher teaches several classes).
class ClassPicker extends StatelessWidget {
  final List<ClassRef> classes;
  final int selected;
  final ValueChanged<int> onSelect;
  const ClassPicker({super.key, required this.classes, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: EmSpacing.minTouch,
      child: ListView.separated(
        key: const Key('class_picker'),
        scrollDirection: Axis.horizontal,
        itemCount: classes.length,
        separatorBuilder: (_, __) => const SizedBox(width: EmSpacing.s8),
        itemBuilder: (_, i) => EmChip(key: ValueKey('class_chip_$i'), label: classes[i].label, selected: i == selected, onTap: () => onSelect(i)),
      ),
    );
  }
}

class SearchBox extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const SearchBox({super.key, required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: EmSpacing.row),
        child: EmSearchPill(fieldKey: const Key('students_search'), controller: controller, hint: 'Search by name or roll number', onChanged: onChanged),
      );
}
