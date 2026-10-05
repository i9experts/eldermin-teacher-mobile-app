import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/classroom/attendance_models.dart';
import '../../../../core/models/classroom/student_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/home_time.dart';
import '../../../../core/utils/timetable_week.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../components/custom_text.dart';
import '../controllers/attendance_controller.dart';
import 'widgets/attendance_widgets.dart';

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
      builder: (ctx) => AlertDialog(
        key: const Key('discard_dialog'),
        title: const Text('Discard unsaved marks?'),
        content: const Text('You have attendance marks that are not saved yet.'),
        actions: [
          TextButton(key: const Key('discard_keep'), onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep editing')),
          TextButton(key: const Key('discard_confirm'), onPressed: () => Navigator.pop(ctx, true), child: const Text('Discard')),
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

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: c.day.value,
      firstDate: c.earliestEditable,
      lastDate: c.today,
      helpText: 'Attendance for',
    );
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
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 170), // above the bottom bar so it never covers the buttons
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
          margin: EdgeInsets.fromLTRB(16, 0, 16, 170),
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
      child: Scaffold(
        appBar: AppBar(title: const CustomText(text: 'Mark attendance', color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      scrollController: scroll,
      header: [
        _DayBar(
          label: isToday ? 'Today · ${longDateOf(day)}' : longDateOf(day),
          cls: cls.label,
          canBack: !day.isBefore(addDays(c.earliestEditable, 1)),
          canForward: day.isBefore(c.today),
          onBack: () => _changeDay(addDays(day, -1)),
          onForward: () => _changeDay(addDays(day, 1)),
          onPick: _pickDay,
        ),
        if (!c.editable)
          _Banner(
            key: const Key('read_only_banner'),
            icon: Icons.lock_clock_outlined,
            text: 'You can only change attendance for the last $kAttendanceEditWindowDays days. This day is read-only.',
            color: AppColors.muted,
          ),
        if (c.submitFailure.value != null)
          _Banner(
            key: const Key('submit_error_banner'),
            icon: Icons.error_outline_rounded,
            text: c.submitFailure.value!.message,
            color: AppColors.red,
          ),
        if (c.lastSaved.value != null && !c.dirty && c.hasServerRecords && c.submitFailure.value == null)
          const _Banner(key: Key('saved_banner'), icon: Icons.check_circle_outline_rounded, text: 'Saved. You can still change a mark and save again.', color: AppColors.green),
        if (c.roster.value.hasData) _SearchBar(controller: search, onChanged: (_) => setState(() {})),
      ],
      builder: (roster) {
        final rows = [
          for (final s in roster)
            if (query.isEmpty || s.fullName.toLowerCase().contains(query) || (s.rollNumber ?? '') == query || (s.grNo ?? '').toLowerCase().contains(query)) s
        ];
        if (rows.isEmpty) {
          return [const Padding(padding: EdgeInsets.only(top: 24), child: AppEmptyView(key: Key('mark_search_empty'), icon: Icons.search_off_rounded, title: 'No student matches your search'))];
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

class _DayBar extends StatelessWidget {
  final String label;
  final String cls;
  final bool canBack;
  final bool canForward;
  final VoidCallback onBack, onForward, onPick;
  const _DayBar({required this.label, required this.cls, required this.canBack, required this.canForward, required this.onBack, required this.onForward, required this.onPick});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.line)),
        child: Row(children: [
          IconButton(key: const Key('day_back'), onPressed: canBack ? onBack : null, icon: const Icon(Icons.chevron_left_rounded)),
          Expanded(
            child: InkWell(
              key: const Key('day_pick'),
              onTap: onPick,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(children: [
                  CustomText(text: label, color: AppColors.primaryColor, fontWeight: FontWeight.w800, fontSize: 13, textAlign: TextAlign.center),
                  CustomText(text: cls, color: AppColors.muted, fontSize: 10.5, textAlign: TextAlign.center),
                ]),
              ),
            ),
          ),
          IconButton(key: const Key('day_forward'), onPressed: canForward ? onForward : null, icon: const Icon(Icons.chevron_right_rounded)),
        ]),
      );
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _Banner({super.key, required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: color.withOpacity(0.35))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(child: CustomText(text: text, color: AppColors.ink, fontSize: 12)),
        ]),
      );
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          key: const Key('mark_search'),
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
      final failed = c.submitFailure.value != null;
      final saving = c.submitting.value;
      final saved = !c.dirty && c.hasServerRecords && missing == 0;
      return Container(
        key: const Key('mark_bottom_bar'),
        padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: AppColors.primaryColor.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, -4))]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(
              child: CustomText(
                key: const Key('marked_progress'),
                text: missing == 0 ? 'All $total marked' : '${total - missing} of $total marked · $missing not marked',
                color: missing == 0 ? AppColors.green : AppColors.amberText,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            if (missing > 0 && c.editable)
              TextButton(
                key: const Key('mark_remaining_present'),
                onPressed: saving ? null : onMarkRemaining,
                child: CustomText(text: missing == total ? 'Mark all present' : 'Mark remaining present', color: AppColors.blue, fontWeight: FontWeight.w800, fontSize: 12),
              ),
          ]),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: failed
                ? ElevatedButton.icon(
                    key: const Key('submit_retry'),
                    onPressed: saving ? null : onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const CustomText(text: 'Retry saving', color: Colors.white, fontWeight: FontWeight.w700),
                  )
                : ElevatedButton(
                    key: const Key('submit_button'),
                    // Tappable while incomplete on purpose: the tap explains "N not marked" and scrolls to the first one.
                    onPressed: (!c.editable || saving || saved) ? null : onSubmit,
                    child: saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : CustomText(text: saved ? 'Saved' : (missing > 0 ? 'Review & submit ($missing not marked)' : 'Review & submit'), color: Colors.white, fontWeight: FontWeight.w700),
                  ),
          ),
        ]),
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
    return AlertDialog(
      key: const Key('attendance_confirm_dialog'),
      title: const Text('Submit attendance?'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          CustomText(text: '${cls.label} · ${longDateOf(c.day.value)}', color: AppColors.muted, fontSize: 12),
          const SizedBox(height: 4),
          CustomText(text: '${c.students_.length} students', color: AppColors.primaryColor, fontWeight: FontWeight.w800, fontSize: 14),
          const SizedBox(height: 10),
          StatusCountPills(counts: counts, showZero: true),
          if (absentees.isNotEmpty) ...[
            const SizedBox(height: 10),
            CustomText(text: 'Absent: ${absentees.join(', ')}', color: AppColors.redText, fontSize: 12),
          ],
          if (c.hasServerRecords) ...[
            const SizedBox(height: 10),
            const CustomText(text: 'This replaces the attendance already saved for this day.', color: AppColors.muted, fontSize: 11),
          ],
        ]),
      ),
      actions: [
        TextButton(key: const Key('attendance_confirm_cancel'), onPressed: () => Navigator.pop(context, false), child: const Text('Back')),
        TextButton(key: const Key('attendance_confirm_submit'), onPressed: () => Navigator.pop(context, true), child: const Text('Submit')),
      ],
    );
  }
}
