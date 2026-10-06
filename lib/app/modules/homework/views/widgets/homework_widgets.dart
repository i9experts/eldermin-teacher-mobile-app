import 'package:flutter/material.dart';
import '../../../../../core/models/homework/homework_models.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/classroom_format.dart';
import '../../../../../core/widgets/app_widgets.dart';
import '../../../../components/custom_text.dart';

/// Tag for where an assignment is (draft / due today / overdue ...). [today] is the device's calendar day.
class PhaseTag extends StatelessWidget {
  final Assignment assignment;
  final DateTime today;
  const PhaseTag({super.key, required this.assignment, required this.today});

  @override
  Widget build(BuildContext context) {
    switch (assignment.phaseOn(today)) {
      case HomeworkPhase.draft:
        return const AppTag('DRAFT', style: TagStyle.neutral);
      case HomeworkPhase.active:
        return const AppTag('ASSIGNED', style: TagStyle.info);
      case HomeworkPhase.dueToday:
        return const AppTag('DUE TODAY', style: TagStyle.amber);
      case HomeworkPhase.overdue:
        return const AppTag('OVERDUE', style: TagStyle.red);
      case HomeworkPhase.other:
        return AppTag(assignment.status.toUpperCase(), style: TagStyle.neutral);
    }
  }
}

class HomeworkTile extends StatelessWidget {
  final Assignment assignment;
  final DateTime today;
  final VoidCallback onTap;
  const HomeworkTile({super.key, required this.assignment, required this.today, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final a = assignment;
    final phase = a.phaseOn(today);
    final dueStyle = phase == HomeworkPhase.overdue ? AppColors.redText : (phase == HomeworkPhase.dueToday ? AppColors.amberText : AppColors.muted);
    return AppCard(
      key: ValueKey('hw_${a.id}'),
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: CustomText(text: a.title.isEmpty ? '(No title)' : a.title, fontWeight: FontWeight.w800, color: AppColors.primaryColor, fontSize: 13.5, maxLines: 2, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          PhaseTag(assignment: a, today: today),
        ]),
        const SizedBox(height: 4),
        CustomText(text: [a.subject, a.classLabel, a.typeLabel].where((e) => e.isNotEmpty).join(' · '), color: AppColors.muted, fontSize: 11),
        const SizedBox(height: 8),
        Row(children: [
          Icon(Icons.event_rounded, size: 14, color: dueStyle),
          const SizedBox(width: 4),
          CustomText(text: dueText(a, today), color: dueStyle, fontSize: 11, fontWeight: FontWeight.w700),
          const Spacer(),
          if (!a.isDraft) ...[
            const Icon(Icons.inbox_rounded, size: 14, color: AppColors.muted),
            const SizedBox(width: 4),
            CustomText(text: '${a.submissionsCount} handed in', color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w700),
          ],
        ]),
      ]),
    );
  }
}

class FilterChipsRow extends StatelessWidget {
  final List<(String label, int count, bool selected, VoidCallback onTap, String keyName)> chips;
  const FilterChipsRow({super.key, required this.chips});

  /// A Wrap (not a horizontal list): four chips with counts are wider than a small phone, and a hidden chip is a hidden filter.
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (label, count, on, tap, name) in chips)
          InkWell(
            key: Key('chip_$name'),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            onTap: tap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: on ? AppColors.primaryColor : Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: on ? AppColors.primaryColor : AppColors.line),
              ),
              child: CustomText(text: count < 0 ? label : '$label  $count', color: on ? Colors.white : AppColors.primaryColor, fontWeight: FontWeight.w800, fontSize: 11.5),
            ),
          ),
      ],
    );
  }
}

/// Status tags of a submission row.
class SubmissionTags extends StatelessWidget {
  final Submission s;
  const SubmissionTags({super.key, required this.s});

  @override
  Widget build(BuildContext context) {
    final tags = <Widget>[];
    switch (s.state) {
      case SubmissionState.graded:
        tags.add(const AppTag('GRADED', style: TagStyle.green));
      case SubmissionState.submitted:
        tags.add(const AppTag('TO GRADE', style: TagStyle.info));
      case SubmissionState.late:
        tags.add(const AppTag('TO GRADE', style: TagStyle.info));
      case SubmissionState.pending:
        tags.add(const AppTag('NOT HANDED IN', style: TagStyle.neutral));
      case SubmissionState.missed:
        tags.add(const AppTag('MISSED', style: TagStyle.red));
      case SubmissionState.unknown:
        tags.add(AppTag(s.statusWire.toUpperCase(), style: TagStyle.neutral));
    }
    if (s.wasLate) tags.add(const AppTag('LATE', style: TagStyle.amber));
    return Wrap(spacing: 6, runSpacing: 4, children: tags);
  }
}

class SubmissionTile extends StatelessWidget {
  final Submission submission;
  final VoidCallback onTap;
  const SubmissionTile({super.key, required this.submission, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = submission;
    final line = <String>[
      if (s.submittedAt != null) 'Handed in ${instantText(s.submittedAt!)}',
      if (s.attachmentKeys.isNotEmpty) '${s.attachmentKeys.length} ${s.attachmentKeys.length == 1 ? 'file' : 'files'}',
      if (s.textResponse.isNotEmpty) 'Written answer',
    ].join(' · ');
    return AppCard(
      key: ValueKey('sub_${s.id}'),
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CustomText(text: s.studentName.isEmpty ? 'Student' : s.studentName, fontWeight: FontWeight.w800, color: AppColors.primaryColor, fontSize: 13, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            SubmissionTags(s: s),
            if (line.isNotEmpty) ...[const SizedBox(height: 5), CustomText(text: line, color: AppColors.muted, fontSize: 11)],
          ]),
        ),
        if (s.isGraded && s.grade != null)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: CustomText(text: '${markText(s.grade!)}/${markText(s.maxGrade)}', fontWeight: FontWeight.w800, color: AppColors.greenText, fontSize: 14),
          )
        else
          const Icon(Icons.chevron_right_rounded, color: AppColors.faint),
      ]),
    );
  }
}

/// A tappable attachment row (opens the signed link).
class AttachmentLink extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback onTap;
  const AttachmentLink({super.key, required this.label, required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: AppColors.pale, borderRadius: BorderRadius.circular(AppRadius.md)),
        child: Row(children: [
          const Icon(Icons.attach_file_rounded, size: 18, color: AppColors.primaryColor),
          const SizedBox(width: 8),
          Expanded(child: CustomText(text: label, color: AppColors.primaryColor, fontWeight: FontWeight.w700, fontSize: 12)),
          if (busy)
            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
          else
            const Icon(Icons.open_in_new_rounded, size: 16, color: AppColors.muted),
        ]),
      ),
    );
  }
}

class InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  const InfoLine({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 16, color: AppColors.muted),
          const SizedBox(width: 8),
          Expanded(child: CustomText(text: text, color: AppColors.black, fontSize: 12.5, height: 1.35)),
        ]),
      );
}

/// Inline error banner used by forms.
class ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final Key? bannerKey;
  const ErrorBanner({super.key, required this.message, this.onRetry, this.bannerKey});

  @override
  Widget build(BuildContext context) => Container(
        key: bannerKey,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.redBg, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.redText.withOpacity(0.25))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.error_outline_rounded, size: 18, color: AppColors.redText),
          const SizedBox(width: 8),
          Expanded(child: CustomText(text: message, color: AppColors.redText, fontSize: 12, fontWeight: FontWeight.w600, height: 1.35)),
          if (onRetry != null) TextButton(onPressed: onRetry, child: const CustomText(text: 'Retry', color: AppColors.redText, fontWeight: FontWeight.w800)),
        ]),
      );
}

/// Label + text field in the app's form style, with an inline error line.
class LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? error;
  final int maxLines;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final Key? fieldKey;
  final int? maxLength;
  final bool required;
  const LabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.error,
    this.maxLines = 1,
    this.keyboardType,
    this.onChanged,
    this.fieldKey,
    this.maxLength,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: error == null ? AppColors.line : AppColors.redText));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CustomText(text: required ? '$label *' : label, color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w800),
        const SizedBox(height: 5),
        TextField(
          key: fieldKey,
          controller: controller,
          maxLines: maxLines,
          minLines: maxLines > 1 ? 2 : 1,
          maxLength: maxLength,
          keyboardType: keyboardType,
          onChanged: onChanged,
          textCapitalization: maxLines > 1 || keyboardType == null ? TextCapitalization.sentences : TextCapitalization.none,
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            counterText: '',
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: border,
            enabledBorder: border,
            focusedBorder: border.copyWith(borderSide: BorderSide(color: error == null ? AppColors.primaryColor : AppColors.redText)),
          ),
        ),
        if (error != null) Padding(padding: const EdgeInsets.only(top: 4), child: CustomText(text: error!, color: AppColors.redText, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

/// Wrap of selectable chips (single choice).
class ChoiceWrap extends StatelessWidget {
  final List<String> labels;
  final String? selected;
  final ValueChanged<String> onSelect;
  final String keyPrefix;
  const ChoiceWrap({super.key, required this.labels, required this.selected, required this.onSelect, required this.keyPrefix});

  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final l in labels)
          InkWell(
            key: Key('$keyPrefix$l'),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            onTap: () => onSelect(l),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: l == selected ? AppColors.primaryColor : Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: l == selected ? AppColors.primaryColor : AppColors.line),
              ),
              child: CustomText(text: l, color: l == selected ? Colors.white : AppColors.primaryColor, fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
      ]);
}

class FormLabel extends StatelessWidget {
  final String text;
  final String? error;
  const FormLabel(this.text, {super.key, this.error});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 2),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CustomText(text: text, color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w800),
          if (error != null) CustomText(text: error!, color: AppColors.redText, fontSize: 11, fontWeight: FontWeight.w600),
        ]),
      );
}
