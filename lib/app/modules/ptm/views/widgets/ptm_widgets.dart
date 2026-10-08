import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../../core/models/ptm/ptm_models.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/classroom_format.dart';
import '../../../../../core/utils/ptm_rules.dart';
import '../../../../../core/widgets/app_widgets.dart';
import '../../../../../core/widgets/shimmer_widgets.dart';
import '../../../../components/custom_text.dart';
import '../../../home/models/section_state.dart';
import '../../../messages/controllers/class_roster_picker.dart';
import '../../../students/views/widgets/student_widgets.dart';

TagStyle ptmStatusStyle(PtmStatus s) => switch (s) {
      PtmStatus.requested => TagStyle.amber,
      PtmStatus.confirmed => TagStyle.info,
      PtmStatus.completed => TagStyle.green,
      PtmStatus.cancelled => TagStyle.neutral,
      PtmStatus.noShow => TagStyle.red,
      PtmStatus.unknown => TagStyle.neutral,
    };

class PtmStatusTag extends StatelessWidget {
  final PtmStatus status;
  const PtmStatusTag(this.status, {super.key});

  @override
  Widget build(BuildContext context) => AppTag(status.label.toUpperCase(), style: ptmStatusStyle(status));
}

/// One meeting in a list.
class PtmCard extends StatelessWidget {
  final ParentMeeting meeting;
  final DateTime now;
  final VoidCallback onTap;
  const PtmCard({super.key, required this.meeting, required this.now, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final m = meeting;
    final overdue = isOverdueOpen(m, now);
    return AppCard(
      key: ValueKey('ptm_${m.id}'),
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: CustomText(text: m.studentName.isEmpty ? 'Student' : m.studentName, fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.primaryColor, maxLines: 1, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          PtmStatusTag(m.status),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          const Icon(Icons.event_rounded, size: 14, color: AppColors.muted),
          const SizedBox(width: 5),
          Expanded(child: CustomText(text: meetingWhen(m, shortDay), fontSize: 12, color: AppColors.ink, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 3),
        CustomText(
          text: [if (m.classLabel.isNotEmpty) m.classLabel, if (m.guardianName.isNotEmpty) 'with ${m.guardianName}'].join(' · '),
          fontSize: 11.5,
          color: AppColors.muted,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (m.discussionPoints.isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 4), child: CustomText(text: m.discussionPoints.join(', '), fontSize: 11.5, color: AppColors.muted, maxLines: 1, overflow: TextOverflow.ellipsis)),
        if (overdue) const Padding(padding: EdgeInsets.only(top: 6), child: CustomText(key: Key('ptm_overdue_hint'), text: 'Date has passed: outcome not recorded', fontSize: 11, color: AppColors.amberText, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// A tappable form field (date / time / student) in the app's form style.
class PickField extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool filled;
  final String? error;
  final VoidCallback onTap;
  final Key? fieldKey;
  const PickField({super.key, required this.icon, required this.text, required this.filled, required this.onTap, this.error, this.fieldKey});

  @override
  Widget build(BuildContext context) => InkWell(
        key: fieldKey,
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: error == null ? AppColors.line : AppColors.redText)),
          child: Row(children: [
            Icon(icon, size: 18, color: AppColors.primaryColor),
            const SizedBox(width: 10),
            Expanded(child: CustomText(text: text, color: filled ? AppColors.black : AppColors.faint, fontWeight: FontWeight.w700, fontSize: 13)),
          ]),
        ),
      );
}

/// 24-hour time picker (the wire form is `HH:mm`); returns null when dismissed.
Future<String?> pickHm(BuildContext context, {String? initial}) async {
  var t = const TimeOfDay(hour: 14, minute: 0);
  final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(initial ?? '');
  if (m != null) t = TimeOfDay(hour: int.parse(m.group(1)!).clamp(0, 23), minute: int.parse(m.group(2)!).clamp(0, 59));
  final picked = await showTimePicker(
    context: context,
    initialTime: t,
    builder: (ctx, child) => MediaQuery(data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true), child: child!),
  );
  if (picked == null) return null;
  return '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
}

/// Student picker sheet: class chips -> search -> roster (my classes only, via [ClassRosterPicker]).
class StudentPickerSheet extends StatelessWidget {
  final ClassRosterPicker picker;
  final ValueChanged<dynamic> onPick;
  const StudentPickerSheet({super.key, required this.picker, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final p = picker;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const CustomText(text: 'Choose a student', fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primaryColor),
        const SizedBox(height: 10),
        Obx(() {
          final cs = p.classes;
          final sel = p.selectedClass.value;
          return cs.length > 1 ? Padding(padding: const EdgeInsets.only(bottom: 10), child: ClassPicker(classes: cs, selected: sel, onSelect: p.selectClass)) : const SizedBox.shrink();
        }),
        TextField(
          key: const Key('picker_search'),
          onChanged: (v) => p.query.value = v,
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search by name or roll number',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            filled: true,
            fillColor: AppColors.pale,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Obx(() {
            final st = p.state;
            final list = p.visible;
            final q = p.query.value;
            switch (st.status) {
              case SectionStatus.loading:
                return AppShimmer(key: const Key('picker_loading'), child: Column(children: List.generate(5, (_) => const ShimmerListRowSkeleton())));
              case SectionStatus.error:
                return AppErrorView(message: st.message ?? 'Something went wrong', onRetry: () => p.load(force: true));
              case SectionStatus.forbidden:
                return const AppEmptyView(icon: Icons.lock_outline_rounded, title: "You don't have access");
              case SectionStatus.unavailable:
                return const AppEmptyView(icon: Icons.cloud_off_rounded, title: 'Not available on this server yet');
              case SectionStatus.empty:
                return const AppEmptyView(key: Key('picker_empty'), icon: Icons.groups_outlined, title: 'No students in this class');
              case SectionStatus.data:
                if (list.isEmpty) return AppEmptyView(icon: Icons.search_off_rounded, title: 'No student matches "$q"');
                return ListView(children: [
                  for (final s in list)
                    StudentTile(
                      student: s,
                      onTap: () {
                        onPick(s);
                        Navigator.of(context).pop();
                      },
                    ),
                ]);
            }
          }),
        ),
      ]),
    );
  }
}

/// Wraps a sheet body so it rises above the keyboard and scrolls when it is taller than the space.
class SheetFrame extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget> actions;
  const SheetFrame({super.key, required this.title, required this.child, required this.actions});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 8), child: CustomText(text: title, fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primaryColor)),
            Flexible(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 8), child: child)),
            Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 12), child: Row(children: actions)),
          ]),
        ),
      ),
    );
  }
}

Future<T?> showAppSheet<T>(BuildContext context, WidgetBuilder builder) => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: builder,
    );
