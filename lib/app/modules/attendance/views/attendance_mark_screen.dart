import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/classroom/attendance_models.dart';
import '../../../../core/models/classroom/student_models.dart';
import '../../../../core/utils/home_time.dart';
import '../../../../core/utils/roster_scope.dart';
import '../../../../core/utils/timetable_week.dart';
import '../../../../core/widgets/app_date_picker.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../controllers/attendance_controller.dart';
import 'widgets/attendance_widgets.dart';
import '../../../../core/design/design.dart';

/// Mark (or edit) the daily attendance of MY class (`/attendance/mark[?date=YYYY-MM-DD]`).
/// Every student needs an explicit status before the day can be submitted: unmarked students are
/// never saved as absent. A failed save keeps every mark and offers Retry.
class AttendanceMarkScreen extends StatefulWidget {
  const AttendanceMarkScreen({super.key});

  @override
  State<AttendanceMarkScreen> createState() => _AttendanceMarkScreenState();
}

class _AttendanceMarkScreenState extends State<AttendanceMarkScreen> {
  late final AttendanceController c = Get.find<AttendanceController>();
  final search = TextEditingController();
  final scroll = ScrollController();
  static const double _rowExtent = 104; // approximate row height, used to bring an unbuilt row into view

  @override
  void initState() {
    super.initState();
    final p = Get.parameters['date'];
    final d = p == null ? null : DateTime.tryParse(p);
    // Always start on the requested day (default: today) with fresh server state.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!c.allowed) return;
      c.openDay(d ?? c.today, discard: true);
    });
  }

  @override
  void dispose() {
    search.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<bool> _confirmDiscard() async {
    if (!c.dirty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => EmDialog(
        key: const Key('discard_dialog'),
        title: 'Discard unsaved marks?',
        message: 'You have attendance marks that are not saved yet.',
        actions: [
          EmDialogAction(key: const Key('discard_keep'), label: 'Keep editing', onPressed: () => Navigator.pop(ctx, false)),
          EmDialogAction(key: const Key('discard_confirm'), label: 'Discard', tone: EmDialogTone.destructive, onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _changeDay(DateTime d) async {
    if (!await c.openDay(d)) {
      if (await _confirmDiscard()) await c.openDay(d, discard: true);
    }
  }

  Future<void> _changeClass(ClassRef cls) async {
    if (!await c.selectClass(cls)) {
      if (await _confirmDiscard()) await c.selectClass(cls, discard: true);
    }
  }

  Future<void> _changeSubject(String name) async {
    if (!await c.selectSubject(name)) {
      if (await _confirmDiscard()) await c.selectSubject(name, discard: true);
    }
  }

  /// The calendar entry point (pre-D6 `day_pick`): the same allowed range as the date strip and as the old Material dialog
  /// (`firstDate: earliestEditable`, `lastDate: today`), now in the token date picker.
  Future<void> _pickDay() async {
    final picked = await showAppDatePicker(context, initialDate: c.day.value, firstDate: c.earliestEditable, lastDate: c.today);
    if (picked != null) await _changeDay(picked);
  }

  /// Brings the first unmarked student into view (rows are built lazily, so this scrolls by index).
  void _scrollToFirstUnmarked() {
    final first = c.unmarked.firstOrNull;
    if (first == null || !scroll.hasClients) return;
    final i = c.students_.indexWhere((s) => s.id == first.id);
    final target = (i * _rowExtent).clamp(0.0, scroll.position.maxScrollExtent);
    scroll.animateTo(target, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  Future<void> _submit() async {
    final missing = c.unmarked.length;
    if (missing > 0) {
      await c.submit(); // flags the unmarked rows
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          key: const Key('not_marked_snack'),
          behavior: SnackBarBehavior.floating,
          margin: EmSpacing.snackAboveBar, // above the bottom bar so it never covers the buttons
          content: Text('$missing ${missing == 1 ? 'student isn\'t' : 'students aren\'t'} marked yet. Everyone needs a status.')));
      _scrollToFirstUnmarked();
      return;
    }
    final ok = await showDialog<bool>(context: context, builder: (ctx) => _SummaryDialog(controller: c));
    if (ok != true) return;
    await _doSubmit();
  }

  Future<void> _doSubmit() async {
    final r = await c.submit();
    if (!mounted) return;
    if (r is SubmitSaved) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(
          key: Key('saved_snack'),
          behavior: SnackBarBehavior.floating,
          margin: EmSpacing.snackAboveBar,
          content: Text('Attendance saved')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (!await _confirmDiscard()) return;
        // the hub always shows today: restore it when this screen was on another day or had unsaved marks
        if (c.dirty || !sameDate(c.day.value, c.today)) unawaited(c.openDay(c.today, discard: true));
        if (mounted) Get.back();
      },
      child: EmScaffold(
        appBar: EmAppBar(title: 'Mark attendance'),
        body: Obx(() {
          if (!c.allowed) {
            return const AppEmptyView(
              key: Key('attendance_not_class_teacher'),
              icon: Icons.lock_outline_rounded,
              title: 'Attendance is for class teachers',
              subtitle: 'Only the class teacher of a class marks its daily attendance.',
            );
          }
          return Column(children: [
            Expanded(child: _list()),
            _BottomBar(controller: c, onSubmit: _submit, onMarkRemaining: c.markRemainingPresent, onRetry: _doSubmit),
          ]);
        }),
      ),
    );
  }

  Widget _list() {
    final cls = c.myClass!;
    final day = c.day.value;
    final isToday = sameDate(day, c.today);
    final query = search.text.trim().toLowerCase();
    return ScreenStateView<List<StudentSummary>>(
      state: c.roster.value,
      onRefresh: () async {
        if (c.dirty && !await _confirmDiscard()) return;
        await c.reload();
      },
      onRetry: c.retry,
      emptyIcon: Icons.groups_outlined,
      emptyTitle: 'No students in your class',
      emptySubtitle: 'There are no active students in ${cls.label} yet.',
      padding: EmSpacing.listPadding,
      scrollController: scroll,
      header: [
        _DayBar(
          label: isToday ? 'Today · ${longDateOf(day)}' : longDateOf(day),
          cls: cls.label,
          selected: day,
          days: [for (var i = -kAttendanceEditWindowDays; i <= 0; i++) addDays(c.today, i)],
          onSelect: _changeDay,
          onPick: _pickDay,
        ),
        if (c.hasPicker) _ClassBar(controller: c, onSelect: _changeClass),
        if (c.classStale)
          EmInfoBanner(
            key: const Key('stale_class_banner'),
            tone: EmTone.warning,
            text: staleClassText(cls.label),
            actionLabel: 'Sign out',
            onAction: c.auth.logout,
          ),
        if (c.isSubjectWise) _SubjectBar(controller: c, onSelect: _changeSubject),
        if (c.needsSubject)
          const EmInfoBanner(
            key: Key('no_subjects_banner'),
            tone: EmTone.warning,
            icon: Icons.menu_book_outlined,
            text: 'Your school marks attendance subject by subject, but no subjects are set up yet. Ask your admin to add subjects.',
          ),
        if (!c.editable)
          EmInfoBanner(
            key: const Key('read_only_banner'),
            tone: EmTone.neutral,
            icon: Icons.lock_clock_outlined,
            text: 'You can only change attendance for the last $kAttendanceEditWindowDays days. This day is read-only.',
          ),
        if (c.submitFailure.value != null) EmInfoBanner(key: const Key('submit_error_banner'), tone: EmTone.error, text: c.submitFailure.value!.message),
        if (c.lastSaved.value != null && !c.dirty && c.hasServerRecords && c.submitFailure.value == null)
          const EmInfoBanner(key: Key('saved_banner'), tone: EmTone.success, text: 'Saved. You can still change a mark and save again.'),
        if (c.roster.value.hasData)
          Padding(
            padding: const EdgeInsets.only(bottom: EmSpacing.row),
            child: EmSearchPill(fieldKey: const Key('mark_search'), controller: search, hint: 'Search by name or roll number', onChanged: (_) => setState(() {})),
          ),
      ],
      builder: (roster) {
        final rows = [
          for (final s in roster)
            if (query.isEmpty || s.fullName.toLowerCase().contains(query) || (s.rollNumber ?? '') == query || (s.grNo ?? '').toLowerCase().contains(query)) s
        ];
        if (rows.isEmpty) {
          return [const Padding(padding: EdgeInsets.only(top: EmSpacing.s24), child: AppEmptyView(key: Key('mark_search_empty'), icon: Icons.search_off_rounded, title: 'No student matches your search'))];
        }
        return [
          for (final s in rows)
            // Each row observes its own status: the list builder itself runs outside the screen's Obx.
            Obx(() => StudentAttendanceRow(
                  key: ValueKey('row_${s.id}'),
                  student: s,
                  status: c.marks[s.id],
                  legacyStatus: c.legacyStatus[s.id],
                  enabled: c.editable && !c.submitting.value,
                  highlightMissing: c.showUnmarked.value,
                  onSelect: (st) => c.setStatus(s.id, st),
                )),
        ];
      },
    );
  }
}

/// Which day is being marked: the title, the class, and a date strip over the editable window (today and the 7 days before).
class _DayBar extends StatelessWidget {
  final String label;
  final String cls;
  final DateTime selected;
  final List<DateTime> days;
  final ValueChanged<DateTime> onSelect;
  final VoidCallback onPick;
  const _DayBar({required this.label, required this.cls, required this.selected, required this.days, required this.onSelect, required this.onPick});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: EmSpacing.row),
        child: EmHeroCard(
          padding: const EdgeInsetsDirectional.all(EmSpacing.s16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, key: const Key('day_label'), style: EmType.heading.copyWith(color: EmColors.ink)),
                  Text(cls, style: EmType.caption.copyWith(color: EmColors.textSecondary)),
                ]),
              ),
              const SizedBox(width: EmSpacing.s8),
              EmIconCircleButton(key: const Key('day_pick'), icon: Icons.calendar_month_rounded, semanticLabel: 'Pick a date', tooltip: 'Pick a date', elevated: false, onTap: onPick),
            ]),
            const SizedBox(height: EmSpacing.row),
            KeyedSubtree(
              key: const Key('day_strip'),
              child: EmDateStrip(days: days, selected: selected, onSelected: onSelect, dayKey: (d) => ValueKey('mark_day_${ymdOf(d)}')),
            ),
          ]),
        ),
      );
}

/// Teachers who are class teacher of more than one class: which class is being marked (shown only then; a single-class teacher sees no picker).
class _ClassBar extends StatelessWidget {
  final AttendanceController controller;
  final ValueChanged<ClassRef> onSelect;
  const _ClassBar({required this.controller, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final current = c.myClass;
    return Padding(
      key: const Key('class_bar'),
      padding: const EdgeInsets.only(bottom: EmSpacing.row),
      child: EmCard(
        padding: EmSpacing.cardPadCompact,
        radius: EmRadius.md,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Class', style: EmType.label.copyWith(color: EmColors.textSecondary)),
          const SizedBox(height: EmSpacing.s4),
          Wrap(spacing: EmSpacing.s8, runSpacing: EmSpacing.s8, children: [
            for (final cls in c.classes)
              EmChip(key: ValueKey('class_chip_${cls.key}'), label: cls.label, selected: current?.key == cls.key, onTap: c.submitting.value ? null : () => onSelect(cls)),
          ]),
        ]),
      ),
    );
  }
}

/// Subject-wise schools: which subject's attendance is being marked (the web shows the same picker, first subject selected).
class _SubjectBar extends StatelessWidget {
  final AttendanceController controller;
  final ValueChanged<String> onSelect;
  const _SubjectBar({required this.controller, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (c.subjects.isEmpty) return const SizedBox.shrink();
    return Padding(
      key: const Key('subject_bar'),
      padding: const EdgeInsets.only(bottom: EmSpacing.row),
      child: EmCard(
        padding: EmSpacing.cardPadCompact,
        radius: EmRadius.md,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Subject', style: EmType.label.copyWith(color: EmColors.textSecondary)),
          const SizedBox(height: EmSpacing.s4),
          Wrap(spacing: EmSpacing.s8, children: [
            for (final name in c.subjects)
              EmChip(key: ValueKey('subject_chip_$name'), label: name, selected: c.selectedSubject.value == name, onTap: c.submitting.value ? null : () => onSelect(name)),
          ]),
        ]),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final AttendanceController controller;
  final VoidCallback onSubmit;
  final VoidCallback onMarkRemaining;
  final VoidCallback onRetry;
  const _BottomBar({required this.controller, required this.onSubmit, required this.onMarkRemaining, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Obx(() {
      if (!c.roster.value.hasData) return const SizedBox.shrink();
      final missing = c.unmarked.length;
      final total = c.students_.length;
      final failed = c.submitFailure.value != null && !c.classStale;
      final saving = c.submitting.value;
      final saved = !c.dirty && c.hasServerRecords && missing == 0;
      return DecoratedBox(
        key: const Key('mark_bottom_bar'),
        decoration: BoxDecoration(color: EmColors.surface, boxShadow: EmShadows.soft),
        child: Padding(
          padding: EdgeInsets.fromLTRB(EmSpacing.screenH, EmSpacing.s12, EmSpacing.screenH, EmSpacing.s12 + MediaQuery.paddingOf(context).bottom),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Icon(missing == 0 ? Icons.check_circle_outline_rounded : Icons.pending_actions_rounded, size: 18, color: missing == 0 ? EmColors.onSuccessContainer : EmColors.onWarningContainer),
              const SizedBox(width: EmSpacing.s8),
              Expanded(
                child: Text(
                  missing == 0 ? 'All $total marked' : '${total - missing} of $total marked · $missing not marked',
                  key: const Key('marked_progress'),
                  style: EmType.label.copyWith(color: missing == 0 ? EmColors.onSuccessContainer : EmColors.onWarningContainer),
                ),
              ),
              if (missing > 0 && c.editable)
                TextButton(
                  key: const Key('mark_remaining_present'),
                  onPressed: saving ? null : onMarkRemaining,
                  child: Text(missing == total ? 'Mark all present' : 'Mark remaining present', textAlign: TextAlign.end, style: EmType.label.copyWith(color: EmColors.primary)),
                ),
            ]),
            const SizedBox(height: EmSpacing.s8),
            if (failed)
              EmPrimaryButton(key: const Key('submit_retry'), icon: Icons.refresh_rounded, label: 'Retry saving', onPressed: saving ? null : onRetry)
            else
              // Tappable while incomplete on purpose: the tap explains "N not marked" and scrolls to the first one.
              EmPrimaryButton(
                key: const Key('submit_button'),
                loading: saving,
                label: saved ? 'Saved' : (missing > 0 ? 'Review & submit ($missing not marked)' : 'Review & submit'),
                onPressed: (!c.editable || c.classStale || saving || saved) ? null : onSubmit,
              ),
          ]),
        ),
      );
    });
  }
}

class _SummaryDialog extends StatelessWidget {
  final AttendanceController controller;
  const _SummaryDialog({required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final counts = c.counts;
    final cls = c.myClass!;
    final absentees = [for (final s in c.students_) if (c.marks[s.id] == AttendanceStatus.absent) s.fullName];
    final replaces = c.isSubjectWise ? 'This replaces the ${c.selectedSubject.value} attendance already saved for this day.' : 'This replaces the attendance already saved for this day.';
    return EmDialog(
      key: const Key('attendance_confirm_dialog'),
      title: 'Submit attendance?',
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${cls.label} · ${longDateOf(c.day.value)}${c.isSubjectWise && c.selectedSubject.value != null ? ' · ${c.selectedSubject.value}' : ''}', style: EmType.caption.copyWith(color: EmColors.textSecondary)),
          const SizedBox(height: EmSpacing.s4),
          Text('${c.students_.length} students', style: EmType.label.copyWith(color: EmColors.primary)),
          const SizedBox(height: EmSpacing.s12),
          StatusCountPills(counts: counts, showZero: true),
          if (absentees.isNotEmpty) ...[
            const SizedBox(height: EmSpacing.s12),
            Text('Absent: ${absentees.join(', ')}', style: EmType.caption.copyWith(color: EmColors.error)),
          ],
          if (c.hasServerRecords) ...[
            const SizedBox(height: EmSpacing.s12),
            Text(replaces, style: EmType.caption.copyWith(color: EmColors.onWarningContainer)),
          ],
        ]),
      ),
      actions: [
        EmDialogAction(key: const Key('attendance_confirm_cancel'), label: 'Back', onPressed: () => Navigator.pop(context, false)),
        EmDialogAction(key: const Key('attendance_confirm_submit'), label: 'Submit', tone: EmDialogTone.primary, onPressed: () => Navigator.pop(context, true)),
      ],
    );
  }
}
