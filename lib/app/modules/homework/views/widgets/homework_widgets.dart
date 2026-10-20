import 'package:flutter/material.dart';
import '../../../../../core/design/design.dart';
import '../../../../../core/models/homework/homework_models.dart';
import '../../../../../core/theme/app_theme.dart' show TagStyle;
import '../../../../../core/utils/classroom_format.dart';
import '../../../../../core/widgets/app_widgets.dart';

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
    // Due-date emphasis: tone colour plus the PhaseTag text, so it is never colour alone.
    final dueColor = phase == HomeworkPhase.overdue ? EmColors.error : (phase == HomeworkPhase.dueToday ? EmColors.onWarningContainer : EmColors.textSecondary);
    return Padding(
      key: ValueKey('hw_${a.id}'),
      padding: const EdgeInsets.only(bottom: EmSpacing.row),
      child: EmCard(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(a.title.isEmpty ? '(No title)' : a.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: EmType.bodyLarge.copyWith(color: EmColors.ink))),
            const SizedBox(width: EmSpacing.s8),
            PhaseTag(assignment: a, today: today),
          ]),
          const SizedBox(height: EmSpacing.s4),
          Text([a.subject, a.classLabel, a.typeLabel].where((e) => e.isNotEmpty).join(' · '), style: EmType.body.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400)),
          const SizedBox(height: EmSpacing.s12),
          Wrap(spacing: EmSpacing.s16, runSpacing: EmSpacing.s4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            _Meta(icon: Icons.event_rounded, text: dueText(a, today), color: dueColor, bold: true),
            if (!a.isDraft) _Meta(icon: Icons.inbox_rounded, text: '${a.submissionsCount} handed in', color: EmColors.textSecondary),
          ]),
        ]),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final bool bold;
  const _Meta({required this.icon, required this.text, required this.color, this.bold = false});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        ExcludeSemantics(child: Icon(icon, size: 16, color: color)),
        const SizedBox(width: EmSpacing.s4),
        Flexible(child: Text(text, style: EmType.caption.copyWith(color: color, fontWeight: bold ? FontWeight.w600 : FontWeight.w500))),
      ]);
}

class FilterChipsRow extends StatelessWidget {
  final List<(String label, int count, bool selected, VoidCallback onTap, String keyName)> chips;
  const FilterChipsRow({super.key, required this.chips});

  /// A Wrap (not a horizontal list): four chips with counts are wider than a small phone, and a hidden chip is a hidden filter.
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: EmSpacing.s8,
      children: [
        for (final (label, count, on, tap, name) in chips) EmChip(key: Key('chip_$name'), label: count < 0 ? label : '$label  $count', selected: on, onTap: tap),
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
    return Wrap(spacing: EmSpacing.s8, runSpacing: EmSpacing.s4, children: tags);
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
    return Padding(
      key: ValueKey('sub_${s.id}'),
      padding: const EdgeInsets.only(bottom: EmSpacing.row),
      child: EmCard(
        onTap: onTap,
        padding: EmSpacing.cardPadCompact,
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.studentName.isEmpty ? 'Student' : s.studentName, maxLines: 2, overflow: TextOverflow.ellipsis, style: EmType.bodyLarge.copyWith(color: EmColors.ink)),
              const SizedBox(height: EmSpacing.s4),
              SubmissionTags(s: s),
              if (line.isNotEmpty) ...[const SizedBox(height: EmSpacing.s4), Text(line, style: EmType.caption.copyWith(color: EmColors.textSecondary))],
            ]),
          ),
          if (s.isGraded && s.grade != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: EmSpacing.s8),
              child: Text('${markText(s.grade!)}/${markText(s.maxGrade)}', style: EmType.value.copyWith(color: EmColors.onSuccessContainer)),
            )
          else
            const Icon(Icons.chevron_right_rounded, color: EmColors.textSecondary),
        ]),
      ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: EmSpacing.s8),
      child: EmCard(
        color: EmColors.primaryTint,
        padding: const EdgeInsetsDirectional.symmetric(horizontal: EmSpacing.s12, vertical: EmSpacing.s12),
        onTap: busy ? null : onTap,
        child: Row(children: [
          const ExcludeSemantics(child: Icon(Icons.attach_file_rounded, size: 20, color: EmColors.primary)),
          const SizedBox(width: EmSpacing.s8),
          Expanded(child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: EmType.body.copyWith(color: EmColors.primary))),
          if (busy)
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          else
            const ExcludeSemantics(child: Icon(Icons.open_in_new_rounded, size: 18, color: EmColors.textSecondary)),
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
        padding: const EdgeInsets.only(bottom: EmSpacing.s8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ExcludeSemantics(child: Icon(icon, size: 18, color: EmColors.textSecondary)),
          const SizedBox(width: EmSpacing.s8),
          Expanded(child: Text(text, style: EmType.body.copyWith(color: EmColors.ink, fontWeight: FontWeight.w400))),
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
  Widget build(BuildContext context) => EmInfoBanner(key: bannerKey, tone: EmTone.error, text: message, actionLabel: onRetry == null ? null : 'Retry', onAction: onRetry);
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
    return Padding(
      padding: const EdgeInsets.only(bottom: EmSpacing.block),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(required ? '$label *' : label, style: EmType.label.copyWith(color: EmColors.textSecondary)),
        const SizedBox(height: EmSpacing.s8),
        // Border, fill and focus colours come from the theme's inputDecorationTheme (tokens); only the error state is set here.
        TextField(
          key: fieldKey,
          controller: controller,
          maxLines: maxLines,
          minLines: maxLines > 1 ? 2 : 1,
          maxLength: maxLength,
          keyboardType: keyboardType,
          onChanged: onChanged,
          textCapitalization: maxLines > 1 || keyboardType == null ? TextCapitalization.sentences : TextCapitalization.none,
          style: EmType.body.copyWith(color: EmColors.ink),
          decoration: InputDecoration(hintText: hint, counterText: '', errorText: error, errorMaxLines: 3),
        ),
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
  Widget build(BuildContext context) => Wrap(spacing: EmSpacing.s8, children: [
        for (final l in labels) EmChip(key: Key('$keyPrefix$l'), label: l, selected: l == selected, onTap: () => onSelect(l)),
      ]);
}

class FormLabel extends StatelessWidget {
  final String text;
  final String? error;
  const FormLabel(this.text, {super.key, this.error});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: EmSpacing.s8, top: EmSpacing.s2),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(text, style: EmType.label.copyWith(color: EmColors.textSecondary)),
          if (error != null) Text(error!, style: EmType.caption.copyWith(color: EmColors.error)),
        ]),
      );
}
