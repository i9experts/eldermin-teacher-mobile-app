import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../../core/models/ptm/ptm_models.dart';
import '../../../../../core/utils/classroom_format.dart';
import '../../../../../core/utils/ptm_rules.dart';
import '../../../../../core/widgets/app_widgets.dart';
import '../../../../../core/widgets/shimmer_widgets.dart';
import '../../../home/models/section_state.dart';
import '../../../messages/controllers/class_roster_picker.dart';
import '../../../students/views/widgets/student_widgets.dart';
import '../../../../../core/design/design.dart';

EmTone ptmStatusStyle(PtmStatus s) => switch (s) {
      PtmStatus.requested => EmTone.warning,
      PtmStatus.confirmed => EmTone.info,
      PtmStatus.completed => EmTone.success,
      PtmStatus.cancelled => EmTone.neutral,
      PtmStatus.noShow => EmTone.error,
      PtmStatus.unknown => EmTone.neutral,
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
          Expanded(child: Text(m.studentName.isEmpty ? 'Student' : m.studentName, maxLines: 2, overflow: TextOverflow.ellipsis, style: EmType.body.copyWith(fontWeight: FontWeight.w700, color: EmColors.ink))),
          const SizedBox(width: EmSpacing.s8),
          PtmStatusTag(m.status),
        ]),
        const SizedBox(height: EmSpacing.s4),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.only(top: EmSpacing.s2), child: ExcludeSemantics(child: Icon(Icons.event_rounded, size: 16, color: EmColors.textSecondary))),
          const SizedBox(width: EmSpacing.s8),
          Expanded(child: Text(meetingWhen(m, shortDay), style: EmType.label.copyWith(color: EmColors.ink, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: EmSpacing.s4),
        Text(
          [if (m.classLabel.isNotEmpty) m.classLabel, if (m.guardianName.isNotEmpty) 'with ${m.guardianName}'].join(' · '),
          style: EmType.caption.copyWith(color: EmColors.textSecondary),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (m.discussionPoints.isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: EmSpacing.s4), child: Text(m.discussionPoints.join(', '), style: EmType.caption.copyWith(color: EmColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis)),
        if (overdue)
          Padding(
            padding: const EdgeInsets.only(top: EmSpacing.s8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.schedule_rounded, size: 16, color: EmColors.warning),
              const SizedBox(width: EmSpacing.s4),
              Expanded(child: Text('Date has passed: outcome not recorded', key: const Key('ptm_overdue_hint'), style: EmType.caption.copyWith(color: EmColors.warning, fontWeight: FontWeight.w700))),
            ]),
          ),
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
        borderRadius: EmRadius.mdAll,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: EmSpacing.minTouch),
          padding: const EdgeInsets.symmetric(horizontal: EmSpacing.s12, vertical: EmSpacing.s12),
          decoration: BoxDecoration(color: EmColors.surface, borderRadius: EmRadius.mdAll, border: Border.all(color: error == null ? EmColors.border : EmColors.error)),
          child: Row(children: [
            ExcludeSemantics(child: Icon(icon, size: 20, color: EmColors.primary)),
            const SizedBox(width: EmSpacing.s12),
            Expanded(child: Text(text, style: EmType.label.copyWith(color: filled ? EmColors.ink : EmColors.textSecondary, fontWeight: filled ? FontWeight.w700 : FontWeight.w500))),
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
      padding: const EdgeInsets.fromLTRB(EmSpacing.screenH, EmSpacing.s16, EmSpacing.screenH, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Choose a student', style: EmType.heading.copyWith(color: EmColors.ink)),
        const SizedBox(height: EmSpacing.s12),
        Obx(() {
          final cs = p.classes;
          final sel = p.selectedClass.value;
          return cs.length > 1 ? Padding(padding: const EdgeInsets.only(bottom: EmSpacing.s12), child: ClassPicker(classes: cs, selected: sel, onSelect: p.selectClass)) : const SizedBox.shrink();
        }),
        EmSearchPill(color: EmColors.background, fieldKey: const Key('picker_search'), hint: 'Search by name or roll number', onChanged: (v) => p.query.value = v),
        const SizedBox(height: EmSpacing.s12),
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
            Padding(padding: const EdgeInsets.fromLTRB(EmSpacing.screenH, EmSpacing.s16, EmSpacing.screenH, EmSpacing.s8), child: Text(title, style: EmType.heading.copyWith(color: EmColors.ink))),
            Flexible(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(EmSpacing.screenH, EmSpacing.s4, EmSpacing.screenH, EmSpacing.s8), child: child)),
            Padding(padding: const EdgeInsets.fromLTRB(EmSpacing.screenH, EmSpacing.s4, EmSpacing.screenH, EmSpacing.s12), child: Row(children: actions)),
          ]),
        ),
      ),
    );
  }
}

Future<T?> showAppSheet<T>(BuildContext context, WidgetBuilder builder) => EmBottomSheet.showPanel<T>(context, builder: builder);
