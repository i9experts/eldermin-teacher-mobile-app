import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/assessments/assessment_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../components/custom_text.dart';
import '../../../utils/toast_util.dart';
import '../../home/models/section_state.dart';
import '../../homework/views/widgets/homework_widgets.dart' show FilterChipsRow;
import '../controllers/report_remarks_controller.dart';

/// Report-card remarks (`/assessments/report-remarks?assessmentId=`): the class teacher's remark per student. Generating and publishing
/// report cards are admin actions and are not offered; the principal's remarks are shown read-only; published cards are read-only.
class AssessmentReportRemarksScreen extends GetView<ReportRemarksController> {
  const AssessmentReportRemarksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const CustomText(text: 'Report card remarks', color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
      body: Obx(_body),
    );
  }

  Widget _body() {
    final c = controller;
    final state = c.state.value;
    final saving = c.saving.toSet();
    return ScreenStateView<List<ReportCard>>(
      state: c.list.canView ? state : const SectionState<List<ReportCard>>.forbidden(),
      onRefresh: c.reload,
      onRetry: c.reload,
      emptyIcon: Icons.rate_review_outlined,
      emptyTitle: c.candidates.isEmpty ? 'No report cards to comment on yet' : 'No report cards for your class',
      emptySubtitle: c.candidates.isEmpty
          ? (c.isClassTeacher ? 'Report cards appear here once your school has generated them for an assessment of your class.' : 'Remarks are written by the class teacher of a class.')
          : 'There are no generated report cards for your class in this assessment.',
      header: [
        if (c.candidates.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FilterChipsRow(chips: [for (final a in c.candidates) (a.title, -1, a.id == c.selectedId.value, () => c.select(a.id), 'asm_${a.id}')]),
          )
        else if (c.candidates.length == 1)
          Padding(padding: const EdgeInsets.only(bottom: 10), child: CustomText(text: c.candidates.first.title, fontWeight: FontWeight.w800, color: AppColors.primaryColor, fontSize: 15)),
        if (c.truncated.value) const Padding(padding: EdgeInsets.only(bottom: 10), child: CustomText(key: Key('remarks_truncated'), text: 'Some report cards may not be shown.', color: AppColors.amberText, fontSize: 12)),
      ],
      builder: (cards) => [for (final card in cards) _CardTile(key: ValueKey('rc_${card.id}'), card: card, c: c, saving: saving.contains(card.id))],
    );
  }
}

class _CardTile extends StatefulWidget {
  final ReportCard card;
  final ReportRemarksController c;
  final bool saving;
  const _CardTile({super.key, required this.card, required this.c, required this.saving});

  @override
  State<_CardTile> createState() => _CardTileState();
}

class _CardTileState extends State<_CardTile> {
  late final TextEditingController text = TextEditingController(text: widget.card.classTeacherRemarks);
  String? error;
  bool? savedOk;

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      error = null;
      savedOk = null;
    });
    final r = await widget.c.saveRemarks(widget.card, text.text);
    if (!mounted) return;
    switch (r) {
      case RemarksSaved():
        setState(() => savedOk = true);
        ToastUtil.showToast('Remarks saved');
      case RemarksInvalid(:final message):
        setState(() => error = message);
      case RemarksFailed(:final failure):
        setState(() => error = failure.message);
      case RemarksIgnored():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final editable = widget.c.canEdit(card);
    final changed = text.text.trim() != card.classTeacherRemarks.trim();
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: CustomText(text: '${card.rollNumber.isEmpty ? '' : '${card.rollNumber}. '}${card.studentName}', fontWeight: FontWeight.w800, color: AppColors.primaryColor, fontSize: 14)),
          if (card.published) const AppTag('PUBLISHED', style: TagStyle.green),
        ]),
        const SizedBox(height: 3),
        CustomText(
            text: [
              if (card.overallPercentage != null) '${marksText(card.overallPercentage!)}%',
              if (card.overallGrade.isNotEmpty) 'Grade ${card.overallGrade}',
              if (card.classPosition != null) 'Position ${card.classPosition}${card.totalStudents != null ? ' of ${card.totalStudents}' : ''}',
            ].join(' · '),
            color: AppColors.muted,
            fontSize: 12),
        const SizedBox(height: 10),
        if (editable)
          TextField(
            key: Key('remarks_input_${card.id}'),
            controller: text,
            maxLines: 3,
            minLines: 2,
            maxLength: ReportRemarksController.maxLength,
            onChanged: (_) => setState(() => savedOk = null),
            decoration: InputDecoration(hintText: 'Class teacher remarks', border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm))),
          )
        else
          CustomText(key: Key('remarks_read_${card.id}'), text: card.classTeacherRemarks.isEmpty ? 'No class teacher remarks.' : card.classTeacherRemarks, color: card.classTeacherRemarks.isEmpty ? AppColors.muted : AppColors.black, fontSize: 12.5, height: 1.4),
        if (card.published && !editable) const Padding(padding: EdgeInsets.only(top: 6), child: CustomText(text: 'Published report cards are read-only.', color: AppColors.muted, fontSize: 11.5)),
        if (card.principalRemarks.isNotEmpty) ...[
          const SizedBox(height: 8),
          CustomText(text: 'Principal: ${card.principalRemarks}', color: AppColors.muted, fontSize: 12, height: 1.4),
        ],
        if (error != null) Padding(padding: const EdgeInsets.only(top: 6), child: CustomText(key: Key('remarks_error_${card.id}'), text: error!, color: AppColors.redText, fontSize: 12, fontWeight: FontWeight.w600)),
        if (editable)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: Key('remarks_save_${card.id}'),
              onPressed: widget.saving || !changed ? null : _save,
              child: widget.saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : CustomText(text: savedOk == true && !changed ? 'Saved' : 'Save remarks', color: changed ? AppColors.blue : AppColors.muted, fontWeight: FontWeight.w800),
            ),
          ),
      ]),
    );
  }
}
