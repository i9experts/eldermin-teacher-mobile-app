import 'package:flutter/material.dart';
import '../../../../../core/models/classroom/student_models.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/roster_scope.dart';
import '../../../../components/custom_text.dart';

/// Round avatar: the photo when there is one, else the initials.
class StudentAvatar extends StatelessWidget {
  final StudentSummary student;
  final double size;
  const StudentAvatar({super.key, required this.student, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final fallback = Center(child: CustomText(text: student.initials, color: AppColors.primaryColor, fontWeight: FontWeight.w800, fontSize: size * 0.32));
    final url = student.photoUrl;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: AppColors.pale, borderRadius: BorderRadius.circular(size * 0.34)),
      child: (url == null || !url.startsWith('http')) ? fallback : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback),
    );
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
    return Container(
      key: ValueKey('student_${student.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.line)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              StudentAvatar(student: student),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  CustomText(text: student.fullName, fontWeight: FontWeight.w700, color: AppColors.primaryColor, fontSize: 13, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (sub.isNotEmpty) CustomText(text: sub, color: AppColors.muted, fontSize: 11),
                ]),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.faint),
            ]),
          ),
        ),
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
      height: 38,
      child: ListView.separated(
        key: const Key('class_picker'),
        scrollDirection: Axis.horizontal,
        itemCount: classes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final on = i == selected;
          return InkWell(
            key: ValueKey('class_chip_$i'),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            onTap: () => onSelect(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? AppColors.primaryColor : Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: on ? AppColors.primaryColor : AppColors.line),
              ),
              child: CustomText(text: classes[i].label, color: on ? Colors.white : AppColors.primaryColor, fontWeight: FontWeight.w800, fontSize: 12),
            ),
          );
        },
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
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          key: const Key('students_search'),
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search by name or roll number',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.line)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.line)),
          ),
        ),
      );
}
