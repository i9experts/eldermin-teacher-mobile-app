import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../../core/models/assessments/assessment_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../components/confirm_dialog.dart';
import '../../../components/custom_text.dart';
import '../../../utils/toast_util.dart';
import '../../home/models/section_state.dart';
import '../../homework/views/widgets/homework_widgets.dart' show ErrorBanner, FilterChipsRow;
import '../controllers/marks_entry_controller.dart';
import 'widgets/assessment_widgets.dart';

/// Marks entry grid (`/assessments/:id/marks?subject=&section=`). See [MarksEntryController] for the integrity rules the app enforces
/// because the server does not (marks above the total, verified rows, assessment state).
class AssessmentMarksScreen extends GetView<MarksEntryController> {
  const AssessmentMarksScreen({super.key});

  @override
  Widget build(BuildContext context) => _MarksBody(c: controller);
}

class _MarksBody extends StatefulWidget {
  final MarksEntryController c;
  const _MarksBody({required this.c});

  @override
  State<_MarksBody> createState() => _MarksBodyState();
}

class _MarksBodyState extends State<_MarksBody> {
  final scroll = ScrollController();
  MarksEntryController get c => widget.c;

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  Future<bool> _confirmLeave() async {
    if (!c.hasUnsavedChanges) return true;
    return ConfirmDialog.show(title: 'Leave without saving?', message: 'You have ${c.dirtyCount} unsaved ${c.dirtyCount == 1 ? 'mark' : 'marks'}. They will be lost.', confirmLabel: 'Leave', destructive: true);
  }

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final r = c.review();
    switch (r) {
      case MarksInvalid(:final count):
        ToastUtil.showToast(count == 1 ? 'Fix 1 mark first' : 'Fix $count marks first');
        final i = c.rows.indexWhere((x) => c.errorOf(x) != null && !x.locked && x.isDirty);
        if (i >= 0 && scroll.hasClients) unawaited(scroll.animateTo((i * 124.0).clamp(0, scroll.position.maxScrollExtent), duration: const Duration(milliseconds: 300), curve: Curves.easeOut));
        return;
      case MarksNothingToSave():
        ToastUtil.showToast('Nothing to save: no marks were changed');
        return;
      case MarksSaveIgnored():
        return;
      default:
        break;
    }
    final ok = await Get.bottomSheet<bool>(_SummarySheet(c: c), backgroundColor: Colors.white, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))));
    if (ok != true) return;
    await _doSave();
  }

  Future<void> _doSave() async {
    final r = await c.save();
    switch (r) {
      case MarksSaved(:final count):
        ToastUtil.showToast('Saved marks for $count ${count == 1 ? 'student' : 'students'}');
      case MarksSaveFailed():
      case MarksInvalid():
      case MarksNothingToSave():
      case MarksSaveIgnored():
        break;
    }
  }

  Future<void> _selectClass(int i) async {
    if (i == c.selected.value) return;
    if (c.hasUnsavedChanges) {
      final go = await ConfirmDialog.show(title: 'Switch class?', message: 'Your unsaved marks for this class will be lost.', confirmLabel: 'Switch', destructive: true);
      if (!go) return;
    }
    await c.selectClass(i);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (c.saving.value) return;
        if (await _confirmLeave()) Get.back();
      },
      child: Scaffold(
        appBar: AppBar(title: Obx(() => CustomText(text: c.editable ? 'Enter marks' : 'Marks', color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700))),
        body: Obx(() {
          c.revision.value;
          final state = c.state.value;
          return Column(children: [
            Expanded(
              child: ScreenStateView<List<MarkEntryRow>>(
                scrollController: scroll,
                state: state,
                onRefresh: () async {
                  if (c.hasUnsavedChanges && !await _confirmLeave()) return;
                  await c.reload();
                },
                onRetry: () => c.load(force: true),
                emptyIcon: Icons.groups_outlined,
                emptyTitle: 'No students in this class',
                emptySubtitle: "There are no active students on the roster for this class, so there is nothing to mark.",
                header: _header(),
                skeletonRows: 6,
                builder: (rows) => [for (final r in rows) _MarkRowTile(key: ValueKey('mark_${r.student.id}'), row: r, c: c)],
              ),
            ),
            if (state.hasData && c.canEnter) _bottomBar(),
          ]);
        }),
      ),
    );
  }

  List<Widget> _header() {
    final a = c.assessment.value;
    final cfg = c.subjectConfig;
    final cls = c.currentClass;
    return [
      if (a != null) ...[
        CustomText(text: a.title, fontWeight: FontWeight.w800, color: AppColors.primaryColor, fontSize: 16, maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 3),
        CustomText(
            text: [c.subject, if (cls != null) cls.label, if (cfg != null) 'out of ${marksText(cfg.totalMarks)}', if (cfg != null) 'pass ${marksText(cfg.passingMarks)}', if (c.state.value.hasData) '${c.rows.length} ${c.rows.length == 1 ? 'student' : 'students'}'].join(' · '),
            color: AppColors.muted,
            fontSize: 12),
        const SizedBox(height: 10),
      ],
      if (c.classes.length > 1)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: FilterChipsRow(chips: [
            for (var i = 0; i < c.classes.length; i++) (c.classes[i].label, -1, i == c.selected.value, () => _selectClass(i), 'class$i'),
          ]),
        ),
      if (c.state.value.status != SectionStatus.loading && !c.access.value.canEdit && c.state.value.status != SectionStatus.error) AccessNote(noteKey: const Key('marks_access_note'), access: c.access.value),
      if (c.editable && c.statusWarning != null && c.state.value.status != SectionStatus.loading && c.state.value.status != SectionStatus.error) StatusWarningNote(noteKey: const Key('marks_status_warning'), message: c.statusWarning!),
      if (c.state.value.hasData && c.editable && c.lockedCount > 0)
        Container(
          key: const Key('marks_locked_note'),
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.amberBg, borderRadius: BorderRadius.circular(AppRadius.md)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.amberText),
            const SizedBox(width: 8),
            Expanded(
                child: CustomText(
                    text: c.allLocked
                        ? 'All ${c.lockedCount} marks are verified or set by the online quiz, so they are locked. Ask your school admin if one needs a correction.'
                        : '${c.lockedCount} ${c.lockedCount == 1 ? 'mark is' : 'marks are'} verified (or set by the online quiz) and locked. You can edit the rest.',
                    color: AppColors.amberText,
                    fontSize: 12.5,
                    height: 1.35)),
          ]),
        ),
      if (c.marksTruncated.value) const ErrorBanner(bannerKey: Key('marks_truncated'), message: 'Your school has more marks than the app could load. Some saved marks may not be shown.'),
      if (c.saveFailure.value != null) ErrorBanner(bannerKey: const Key('marks_save_error'), message: c.saveFailure.value!.message, onRetry: c.saving.value || !c.saveFailure.value!.canRetry ? null : _doSave),
      if (c.showErrors.value && c.invalidRows.isNotEmpty)
        ErrorBanner(bannerKey: const Key('marks_invalid_banner'), message: c.invalidRows.length == 1 ? '1 mark needs fixing before you can save.' : '${c.invalidRows.length} marks need fixing before you can save.'),
    ];
  }

  Widget _bottomBar() {
    final n = c.dirtyCount;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.line))),
        child: Row(children: [
          Expanded(child: CustomText(key: const Key('marks_dirty_count'), text: n == 0 ? 'No changes yet' : '$n unsaved ${n == 1 ? 'change' : 'changes'}', color: n == 0 ? AppColors.muted : AppColors.primaryColor, fontWeight: FontWeight.w700, fontSize: 12.5)),
          const SizedBox(width: 12),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              key: const Key('marks_save_button'),
              onPressed: c.saving.value || n == 0 ? null : _save,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white, disabledBackgroundColor: AppColors.buttonDisableColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
              child: c.saving.value
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const CustomText(text: 'Review & save', color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
        ]),
      ),
    );
  }
}

/// One student: roll, name, marks field, absent / exempt toggles, remarks.
class _MarkRowTile extends StatefulWidget {
  final MarkEntryRow row;
  final MarksEntryController c;
  const _MarkRowTile({super.key, required this.row, required this.c});

  @override
  State<_MarkRowTile> createState() => _MarkRowTileState();
}

class _MarkRowTileState extends State<_MarkRowTile> {
  late final TextEditingController marks = TextEditingController(text: widget.row.text);
  late final TextEditingController remarks = TextEditingController(text: widget.row.remarks);
  late bool showRemarks = widget.row.remarks.isNotEmpty;

  @override
  void didUpdateWidget(covariant _MarkRowTile old) {
    super.didUpdateWidget(old);
    if (widget.row.text != marks.text) marks.text = widget.row.text;
    if (widget.row.remarks != remarks.text) remarks.text = widget.row.remarks;
  }

  @override
  void dispose() {
    marks.dispose();
    remarks.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.row;
    final c = widget.c;
    final id = r.student.id;
    final editable = c.editable && !r.locked;
    final error = c.showErrors.value || r.serverError != null ? c.errorOf(r) : null;
    final warn = r.warning(c.total);
    final below = r.value != null && r.value! < c.passing && error == null && !r.absent && !r.exempt;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SizedBox(width: 30, child: CustomText(text: r.student.rollNumber ?? '-', color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w700)),
          Expanded(child: CustomText(text: r.student.fullName.isEmpty ? '(No name)' : r.student.fullName, fontWeight: FontWeight.w700, color: AppColors.black, fontSize: 13.5, maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (r.locked) const Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.amberText),
        ]),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          SizedBox(
            width: 96,
            child: TextField(
              key: Key('marks_field_$id'),
              controller: marks,
              enabled: editable && !r.absent && !r.exempt,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              textInputAction: TextInputAction.next,
              onChanged: (v) => c.setMarks(id, v),
              decoration: InputDecoration(
                isDense: true,
                hintText: r.absent ? 'Absent' : r.exempt ? 'Exempt' : '-',
                suffixText: '/${marksText(c.total)}',
                errorText: null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm), borderSide: BorderSide(color: error != null ? AppColors.redText : AppColors.line)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm), borderSide: BorderSide(color: error != null ? AppColors.redText : AppColors.line)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _toggle(Key('absent_$id'), 'Absent', r.absent, editable ? (v) => c.setAbsent(id, v) : null),
          const SizedBox(width: 6),
          _toggle(Key('exempt_$id'), 'Exempt', r.exempt, editable ? (v) => c.setExempt(id, v) : null),
          const Spacer(),
          if (editable || r.remarks.isNotEmpty)
            IconButton(
              key: Key('remarks_toggle_$id'),
              visualDensity: VisualDensity.compact,
              tooltip: 'Remarks',
              icon: Icon(showRemarks ? Icons.chat_bubble_rounded : Icons.chat_bubble_outline_rounded, size: 18, color: r.remarks.isNotEmpty ? AppColors.blue : AppColors.muted),
              onPressed: () => setState(() => showRemarks = !showRemarks),
            ),
        ]),
        if (showRemarks)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextField(
              key: Key('remarks_field_$id'),
              controller: remarks,
              enabled: editable,
              maxLength: 200,
              maxLines: 1,
              onChanged: (v) => c.setRemarks(id, v),
              decoration: InputDecoration(isDense: true, hintText: 'Remarks (optional)', counterText: '', contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm))),
            ),
          ),
        if (error != null) Padding(padding: const EdgeInsets.only(top: 6), child: CustomText(key: Key('marks_error_$id'), text: error, color: AppColors.redText, fontSize: 11.5, fontWeight: FontWeight.w600)),
        if (below) const Padding(padding: EdgeInsets.only(top: 6), child: CustomText(text: 'Below the pass mark', color: AppColors.amberText, fontSize: 11.5, fontWeight: FontWeight.w600)),
        if (warn != null) Padding(padding: const EdgeInsets.only(top: 6), child: CustomText(key: Key('marks_warning_$id'), text: warn, color: AppColors.redText, fontSize: 11.5, fontWeight: FontWeight.w600)),
        if (r.locked && r.lockReason != null) Padding(padding: const EdgeInsets.only(top: 6), child: CustomText(key: Key('marks_lock_$id'), text: r.lockReason!, color: AppColors.amberText, fontSize: 11.5)),
      ]),
    );
  }

  Widget _toggle(Key key, String label, bool on, ValueChanged<bool>? onChanged) => InkWell(
        key: key,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onChanged == null ? null : () => onChanged(!on),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: on ? AppColors.primaryColor : Colors.white, borderRadius: BorderRadius.circular(AppRadius.pill), border: Border.all(color: on ? AppColors.primaryColor : AppColors.line)),
          child: CustomText(text: label, color: on ? Colors.white : (onChanged == null ? AppColors.faint : AppColors.primaryColor), fontWeight: FontWeight.w800, fontSize: 11),
        ),
      );
}

/// "Before you save": the numbers of the whole sheet and how many rows will be written.
class _SummarySheet extends StatelessWidget {
  final MarksEntryController c;
  const _SummarySheet({required this.c});

  @override
  Widget build(BuildContext context) {
    final s = c.summary();
    final n = c.dirtyCount;
    final fresh = c.dirtyRows.where((r) => r.saved == null).length;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const CustomText(text: 'Before you save', fontWeight: FontWeight.w800, color: AppColors.primaryColor, fontSize: 17),
          const SizedBox(height: 4),
          CustomText(text: '${c.subject} · ${c.currentClass?.label ?? ''} · out of ${marksText(s.total)}', color: AppColors.muted, fontSize: 12),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _stat(const Key('sum_entered'), '${s.entered}', 'with marks'),
            _stat(const Key('sum_absent'), '${s.absent}', 'absent'),
            _stat(const Key('sum_exempt'), '${s.exempt}', 'exempt'),
            _stat(const Key('sum_missing'), '${s.notEntered}', 'not entered'),
            _stat(const Key('sum_avg'), s.average == null ? '-' : marksText(s.average!), s.averagePercent == null ? 'average' : 'average (${s.averagePercent!.round()}%)'),
            _stat(const Key('sum_min'), s.lowest == null ? '-' : marksText(s.lowest!), 'lowest'),
            _stat(const Key('sum_max'), s.highest == null ? '-' : marksText(s.highest!), 'highest'),
            _stat(const Key('sum_below'), '${s.belowPass}', 'below pass'),
          ]),
          const SizedBox(height: 14),
          CustomText(key: const Key('sum_will_save'), text: 'This saves $n ${n == 1 ? 'student' : 'students'} ($fresh new, ${n - fresh} changed). Other rows are not touched.', color: AppColors.black, fontSize: 12.5, height: 1.4),
          if (s.notEntered > 0) CustomText(text: '${s.notEntered} ${s.notEntered == 1 ? 'student has' : 'students have'} no marks yet; you can add them later.', color: AppColors.muted, fontSize: 12, height: 1.4),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton(key: const Key('marks_cancel_save'), onPressed: () => Get.back(result: false), child: const CustomText(text: 'Keep editing', color: AppColors.primaryColor, fontWeight: FontWeight.w800))),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                key: const Key('marks_confirm_save'),
                onPressed: () => Get.back(result: true),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white),
                child: CustomText(text: 'Save $n', color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _stat(Key key, String value, String label) => Container(
        width: 96,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(color: AppColors.pale, borderRadius: BorderRadius.circular(AppRadius.sm)),
        child: Column(children: [
          CustomText(key: key, text: value, fontWeight: FontWeight.w800, color: AppColors.primaryColor, fontSize: 16),
          CustomText(text: label, color: AppColors.muted, fontSize: 10.5, textAlign: TextAlign.center),
        ]),
      );
}
