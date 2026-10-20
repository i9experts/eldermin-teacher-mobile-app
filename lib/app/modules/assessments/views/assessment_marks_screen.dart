import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../../core/models/assessments/assessment_models.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../components/confirm_dialog.dart';
import '../../../utils/toast_util.dart';
import '../../home/models/section_state.dart';
import '../../homework/views/widgets/homework_widgets.dart' show ErrorBanner, FilterChipsRow;
import '../controllers/marks_entry_controller.dart';
import 'widgets/assessment_widgets.dart';
import '../../../../core/design/design.dart';

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
    final ok = await EmBottomSheet.showPanel<bool>(context, builder: (_) => _SummarySheet(c: c));
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
      child: EmScaffold(
        appBar: EmAppBar(titleWidget: Obx(() => Text(c.editable ? 'Enter marks' : 'Marks', maxLines: 1, overflow: TextOverflow.ellipsis, style: EmType.heading.copyWith(color: EmColors.ink)))),
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
        Text(a.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: EmType.heading.copyWith(color: EmColors.ink)),
        const SizedBox(height: EmSpacing.s4),
        EmCaptionLine([c.subject, if (cls != null) cls.label, if (cfg != null) 'out of ${marksText(cfg.totalMarks)}', if (cfg != null) 'pass ${marksText(cfg.passingMarks)}', if (c.state.value.hasData) '${c.rows.length} ${c.rows.length == 1 ? 'student' : 'students'}'].where((e) => e.isNotEmpty).join(' · ')),
      ],
      if (c.classes.length > 1)
        Padding(
          padding: const EdgeInsets.only(bottom: EmSpacing.row),
          child: FilterChipsRow(chips: [
            for (var i = 0; i < c.classes.length; i++) (c.classes[i].label, -1, i == c.selected.value, () => _selectClass(i), 'class$i'),
          ]),
        ),
      if (c.lockMessage != null && c.state.value.status != SectionStatus.loading && c.state.value.status != SectionStatus.error)
        LockBanner(noteKey: const Key('marks_lock_banner'), message: c.lockMessage!)
      else if (c.state.value.status != SectionStatus.loading && !c.access.value.canEdit && c.state.value.status != SectionStatus.error)
        AccessNote(noteKey: const Key('marks_access_note'), access: c.access.value),
      if (c.state.value.hasData && c.editable && c.lockedCount > 0)
        EmInfoBanner(
          key: const Key('marks_locked_note'),
          tone: EmTone.warning,
          icon: Icons.lock_outline_rounded,
          text: c.allLocked
              ? 'All ${c.lockedCount} marks are verified or set by the online quiz, so they are locked. Ask your school admin if one needs a correction.'
              : '${c.lockedCount} ${c.lockedCount == 1 ? 'mark is' : 'marks are'} verified (or set by the online quiz) and locked. You can edit the rest.',
        ),
      if (c.marksTruncated.value) const ErrorBanner(bannerKey: Key('marks_truncated'), message: 'Your school has more marks than the app could load. Some saved marks may not be shown.'),
      if (c.saveFailure.value != null) ErrorBanner(bannerKey: const Key('marks_save_error'), message: c.saveFailure.value!.message, onRetry: c.saving.value || !c.saveFailure.value!.canRetry ? null : _doSave),
      if (c.showErrors.value && c.invalidRows.isNotEmpty)
        ErrorBanner(bannerKey: const Key('marks_invalid_banner'), message: c.invalidRows.length == 1 ? '1 mark needs fixing before you can save.' : '${c.invalidRows.length} marks need fixing before you can save.'),
    ];
  }

  Widget _bottomBar() {
    final n = c.dirtyCount;
    return DecoratedBox(
      decoration: BoxDecoration(color: EmColors.surface, boxShadow: EmShadows.soft),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: EmSpacing.screenH, vertical: EmSpacing.s12),
          child: Row(children: [
            Expanded(child: Text(n == 0 ? 'No changes yet' : '$n unsaved ${n == 1 ? 'change' : 'changes'}', key: const Key('marks_dirty_count'), style: EmType.label.copyWith(color: n == 0 ? EmColors.textSecondary : EmColors.ink))),
            const SizedBox(width: EmSpacing.row),
            EmPrimaryButton(key: const Key('marks_save_button'), expand: false, loading: c.saving.value, label: 'Review & save', onPressed: c.saving.value || n == 0 ? null : _save),
          ]),
        ),
      ),
    );
  }
}

/// One student: roll, name, marks field, absent / exempt toggles, remarks. The controls sit in a Wrap, so a narrow screen or a large text
/// scale moves a toggle to the next line instead of overflowing; the marks field is a plain keyed `TextField` (number keyboard, "next"
/// moves to the next student's marks: the toggles and the remarks button are skipped by focus traversal).
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

  OutlineInputBorder _border(bool error) => OutlineInputBorder(borderRadius: EmRadius.smAll, borderSide: BorderSide(color: error ? EmColors.error : EmColors.border));

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
      padding: EmSpacing.cardPadCompact,
      margin: const EdgeInsets.only(bottom: EmSpacing.s8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: EmSpacing.s32),
            child: Text(r.student.rollNumber ?? '-', style: EmType.valueSmall.copyWith(color: EmColors.textSecondary)),
          ),
          Expanded(child: Text(r.student.fullName.isEmpty ? '(No name)' : r.student.fullName, maxLines: 2, overflow: TextOverflow.ellipsis, style: EmType.body.copyWith(color: EmColors.ink, fontWeight: FontWeight.w600))),
          // a locked row says so with the lock glyph AND the reason below
          if (r.locked) const Padding(padding: EdgeInsetsDirectional.only(start: EmSpacing.s8), child: Icon(Icons.lock_outline_rounded, size: 20, color: EmColors.onWarningContainer)),
        ]),
        const SizedBox(height: EmSpacing.s8),
        Wrap(spacing: EmSpacing.s8, runSpacing: EmSpacing.s8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(
            width: 128,
            child: TextField(
              key: Key('marks_field_$id'),
              controller: marks,
              enabled: editable && !r.absent && !r.exempt,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              textInputAction: TextInputAction.next,
              onChanged: (v) => c.setMarks(id, v),
              style: EmType.valueSmall.copyWith(color: EmColors.ink),
              decoration: InputDecoration(
                isDense: true,
                hintText: r.absent ? 'Absent' : (r.exempt ? 'Exempt' : '-'),
                suffixText: '/${marksText(c.total)}',
                errorText: null,
                border: _border(error != null),
                enabledBorder: _border(error != null),
                focusedBorder: error != null ? _border(true) : null,
              ),
            ),
          ),
          Focus(canRequestFocus: false, skipTraversal: true, child: _Toggle(key: Key('absent_$id'), label: 'Absent', on: r.absent, onChanged: editable ? (v) => c.setAbsent(id, v) : null)),
          Focus(canRequestFocus: false, skipTraversal: true, child: _Toggle(key: Key('exempt_$id'), label: 'Exempt', on: r.exempt, onChanged: editable ? (v) => c.setExempt(id, v) : null)),
          if (editable || r.remarks.isNotEmpty)
            Focus(
              canRequestFocus: false,
              skipTraversal: true,
              child: EmIconCircleButton(
                key: Key('remarks_toggle_$id'),
                icon: showRemarks ? Icons.chat_bubble_rounded : Icons.chat_bubble_outline_rounded,
                semanticLabel: 'Remarks',
                tooltip: 'Remarks',
                elevated: false,
                iconColor: r.remarks.isNotEmpty ? EmColors.primary : EmColors.textSecondary,
                onTap: () => setState(() => showRemarks = !showRemarks),
              ),
            ),
        ]),
        if (showRemarks)
          Padding(
            padding: const EdgeInsets.only(top: EmSpacing.s8),
            child: TextField(
              key: Key('remarks_field_$id'),
              controller: remarks,
              enabled: editable,
              maxLength: 200,
              maxLines: 1,
              onChanged: (v) => c.setRemarks(id, v),
              style: EmType.body.copyWith(color: EmColors.ink),
              decoration: const InputDecoration(isDense: true, hintText: 'Remarks (optional)', counterText: ''),
            ),
          ),
        if (error != null) _Note(key: Key('marks_error_$id'), icon: Icons.error_outline_rounded, text: error, color: EmColors.error),
        if (below) const _Note(icon: Icons.trending_down_rounded, text: 'Below the pass mark', color: EmColors.onWarningContainer),
        if (warn != null) _Note(key: Key('marks_warning_$id'), icon: Icons.warning_amber_rounded, text: warn, color: EmColors.error),
        if (r.locked && r.lockReason != null) _Note(key: Key('marks_lock_$id'), icon: Icons.lock_outline_rounded, text: r.lockReason!, color: EmColors.onWarningContainer),
      ]),
    );
  }
}

/// A validation / status line under a row: glyph + words, readable at large text scales (wraps, never clips).
class _Note extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _Note({super.key, required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: EmSpacing.s8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ExcludeSemantics(child: Icon(icon, size: 16, color: color)),
          const SizedBox(width: EmSpacing.s4),
          Expanded(child: Text(text, style: EmType.caption.copyWith(color: color, fontWeight: FontWeight.w600))),
        ]),
      );
}

/// Absent / Exempt: on = solid fill + check glyph + label, off = outlined label (never colour alone); 48dp tall.
class _Toggle extends StatelessWidget {
  final String label;
  final bool on;
  final ValueChanged<bool>? onChanged;
  const _Toggle({super.key, required this.label, required this.on, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final fg = on ? EmColors.onPrimary : (onChanged == null ? EmColors.onDisabled : EmColors.primary);
    return Semantics(
      button: true,
      selected: on,
      enabled: onChanged != null,
      label: label,
      excludeSemantics: true,
      onTap: onChanged == null ? null : () => onChanged!(!on),
      child: Material(
        color: on ? EmColors.primary : EmColors.surface,
        shape: StadiumBorder(side: BorderSide(color: on ? EmColors.primary : EmColors.border)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          canRequestFocus: false,
          onTap: onChanged == null ? null : () => onChanged!(!on),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: EmSpacing.minTouch),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: EmSpacing.s12),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (on) ...[Icon(Icons.check_rounded, size: 18, color: fg), const SizedBox(width: EmSpacing.s4)],
                Text(label, style: EmType.label.copyWith(color: fg)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
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
    final quiet = EmType.body.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400, height: 1.4);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(EmSpacing.screenH, EmSpacing.s8, EmSpacing.screenH, EmSpacing.s16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Before you save', style: EmType.heading.copyWith(color: EmColors.ink)),
          const SizedBox(height: EmSpacing.s4),
          Text('${c.subject} · ${c.currentClass?.label ?? ''} · out of ${marksText(s.total)}', style: quiet),
          const SizedBox(height: EmSpacing.block),
          Wrap(spacing: EmSpacing.s8, runSpacing: EmSpacing.s8, children: [
            _stat(const Key('sum_entered'), '${s.entered}', 'with marks'),
            _stat(const Key('sum_absent'), '${s.absent}', 'absent'),
            _stat(const Key('sum_exempt'), '${s.exempt}', 'exempt'),
            _stat(const Key('sum_missing'), '${s.notEntered}', 'not entered'),
            _stat(const Key('sum_avg'), s.average == null ? '-' : marksText(s.average!), s.averagePercent == null ? 'average' : 'average (${s.averagePercent!.round()}%)'),
            _stat(const Key('sum_min'), s.lowest == null ? '-' : marksText(s.lowest!), 'lowest'),
            _stat(const Key('sum_max'), s.highest == null ? '-' : marksText(s.highest!), 'highest'),
            _stat(const Key('sum_below'), '${s.belowPass}', 'below pass'),
          ]),
          const SizedBox(height: EmSpacing.block),
          Text('This saves $n ${n == 1 ? 'student' : 'students'} ($fresh new, ${n - fresh} changed). Other rows are not touched.', key: const Key('sum_will_save'), style: EmType.body.copyWith(color: EmColors.ink, fontWeight: FontWeight.w400, height: 1.4)),
          if (s.notEntered > 0) Text('${s.notEntered} ${s.notEntered == 1 ? 'student has' : 'students have'} no marks yet; you can add them later.', style: quiet),
          const SizedBox(height: EmSpacing.block),
          Row(children: [
            Expanded(child: EmSecondaryButton(key: const Key('marks_cancel_save'), expand: true, label: 'Keep editing', onPressed: () => Get.back(result: false))),
            const SizedBox(width: EmSpacing.row),
            Expanded(child: EmPrimaryButton(key: const Key('marks_confirm_save'), label: 'Save $n', onPressed: () => Get.back(result: true))),
          ]),
        ]),
      ),
    );
  }

  Widget _stat(Key key, String value, String label) => ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 96),
        child: EmCard(
          color: EmColors.primaryTint,
          padding: const EdgeInsetsDirectional.symmetric(horizontal: EmSpacing.s12, vertical: EmSpacing.s8),
          radius: EmRadius.sm,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(value, key: key, style: EmType.value.copyWith(color: EmColors.ink)),
            Text(label, textAlign: TextAlign.center, style: EmType.caption.copyWith(color: EmColors.textSecondary)),
          ]),
        ),
      );
}
