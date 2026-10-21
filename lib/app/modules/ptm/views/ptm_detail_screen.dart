import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/ptm/ptm_models.dart';
import '../../../../core/theme/app_theme.dart' show TagStyle;
import '../../../../core/utils/classroom_format.dart';
import '../../../../core/utils/ptm_rules.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../components/confirm_dialog.dart';
import '../../../routes/app_routes.dart';
import '../../home/models/section_state.dart';
import '../controllers/ptm_detail_controller.dart';
import 'ptm_action_sheets.dart';
import 'widgets/ptm_widgets.dart';
import '../../../../core/design/design.dart';

/// One meeting (`/ptm/:id`). The controller is created here, tagged by id (a controller registered beforehand is reused, tests).
class PtmDetailScreen extends StatefulWidget {
  final String? meetingId;
  const PtmDetailScreen({super.key, this.meetingId});

  @override
  State<PtmDetailScreen> createState() => _PtmDetailScreenState();
}

class _PtmDetailScreenState extends State<PtmDetailScreen> {
  late final String id = widget.meetingId ?? Get.parameters['id'] ?? '';
  late final PtmDetailController c;
  bool _owned = false;

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<PtmDetailController>(tag: id)) {
      c = Get.find<PtmDetailController>(tag: id);
    } else {
      c = Get.put(PtmDetailController(id: id), tag: id);
      _owned = true;
    }
  }

  @override
  void dispose() {
    if (_owned && Get.isRegistered<PtmDetailController>(tag: id)) Get.delete<PtmDetailController>(tag: id);
    super.dispose();
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));

  void _report(PtmResult r) {
    if (!mounted) return;
    switch (r) {
      case PtmDone(:final notice):
        _snack(notice);
      case PtmFailed(:final text):
        _snack(text);
      case PtmInvalid(:final errors):
        _snack(errors.values.first);
      case PtmIgnored():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return EmScaffold(
      appBar: EmAppBar(title: 'Meeting'),
      body: Obx(() {
        if (c.notFound.value) {
          return const AppEmptyView(key: Key('ptm_not_found'), icon: Icons.search_off_rounded, title: 'Meeting not found', subtitle: 'It may have been removed.');
        }
        return ScreenStateView<ParentMeeting>(
          state: c.state.value,
          onRefresh: c.reload,
          onRetry: c.reload,
          builder: (m) => _content(m),
        );
      }),
    );
  }

  List<Widget> _content(ParentMeeting m) {
    final allowed = c.allowed;
    final busy = c.busy.value;
    final now = c.clock();
    return [
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(m.studentName.isEmpty ? 'Student' : m.studentName, key: const Key('ptm_student'), style: EmType.bodyLarge.copyWith(fontWeight: FontWeight.w800, color: EmColors.ink))),
            const SizedBox(width: EmSpacing.s8),
            PtmStatusTag(m.status),
          ]),
          if (m.classLabel.isNotEmpty) Padding(padding: const EdgeInsets.only(top: EmSpacing.s2), child: Text(m.classLabel, style: EmType.caption.copyWith(color: EmColors.textSecondary))),
          const SizedBox(height: EmSpacing.s12),
          _line(Icons.event_rounded, meetingWhen(m, (d) => '${shortDay(d)} ${d.year}'), key: const Key('ptm_when')),
          _line(Icons.family_restroom_rounded, m.guardianName.isEmpty ? 'Guardian not recorded' : 'With ${m.guardianName}', key: const Key('ptm_guardian')),
          if (m.teacherName.isNotEmpty) _line(Icons.person_rounded, 'Teacher: ${m.teacherName}${c.isMine ? ' (you)' : ''}'),
          if (isOverdueOpen(m, now)) Padding(padding: const EdgeInsets.only(top: EmSpacing.s4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.schedule_rounded, size: 16, color: EmColors.warning), const SizedBox(width: EmSpacing.s4), Expanded(child: Text('The date has passed and no outcome is recorded yet.', key: const Key('ptm_overdue_hint'), style: EmType.caption.copyWith(color: EmColors.warning, fontWeight: FontWeight.w700)))])),
          if (!c.isMine) Padding(padding: const EdgeInsets.only(top: EmSpacing.s8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.visibility_outlined, size: 16, color: EmColors.textSecondary), const SizedBox(width: EmSpacing.s8), Expanded(child: Text('This meeting belongs to another teacher, so you can only view it.', key: const Key('ptm_not_mine'), style: EmType.caption.copyWith(color: EmColors.textSecondary)))])),
        ]),
      ),
      if (m.status == PtmStatus.cancelled)
        AppCard(
          key: const Key('ptm_cancelled_box'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.event_busy_rounded, size: 18, color: EmColors.error),
              const SizedBox(width: EmSpacing.s8),
              Text('Cancelled', style: EmType.label.copyWith(fontWeight: FontWeight.w800, color: EmColors.error)),
            ]),
            const SizedBox(height: EmSpacing.s4),
            Text(m.cancelledReason.isEmpty ? 'No reason was recorded.' : m.cancelledReason, style: EmType.label.copyWith(color: EmColors.ink, fontWeight: FontWeight.w400)),
            if (m.cancelledBy.isNotEmpty) Padding(padding: const EdgeInsets.only(top: EmSpacing.s4), child: Text('By ${m.cancelledBy}', style: EmType.caption.copyWith(color: EmColors.textSecondary))),
          ]),
        ),
      if (m.discussionPoints.isNotEmpty) ...[
        const SubHeading('Discussion points'),
        AppCard(key: const Key('ptm_points'), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final p in m.discussionPoints) _bullet(p)])),
      ],
      if (m.status == PtmStatus.completed || m.status == PtmStatus.noShow) ...[
        const SubHeading('Outcome'),
        AppCard(
          key: const Key('ptm_outcome'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              AppTag(m.status == PtmStatus.completed ? 'PARENT ATTENDED' : 'NO-SHOW', style: m.status == PtmStatus.completed ? TagStyle.green : TagStyle.red),
            ]),
            const SizedBox(height: EmSpacing.s8),
            Text(m.meetingNotes.isEmpty ? 'No notes were recorded.' : m.meetingNotes, style: EmType.label.copyWith(color: m.meetingNotes.isEmpty ? EmColors.textSecondary : EmColors.ink, fontWeight: FontWeight.w400)),
          ]),
        ),
      ],
      if (m.actionItems.isNotEmpty) ...[
        const SubHeading('Action items'),
        for (final a in m.actionItems) _actionItem(m, a, enabled: allowed.contains(PtmAction.toggleActionItems)),
      ],
      const SizedBox(height: EmSpacing.s4),
      ..._buttons(m, allowed, busy),
      _history(),
    ];
  }

  Widget _line(IconData icon, String text, {Key? key}) => Padding(
        padding: const EdgeInsets.only(bottom: EmSpacing.s8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: EmSpacing.s2), child: ExcludeSemantics(child: Icon(icon, size: 18, color: EmColors.textSecondary))),
          const SizedBox(width: EmSpacing.s8),
          Expanded(child: Text(text, key: key, style: EmType.label.copyWith(color: EmColors.ink, fontWeight: FontWeight.w500))),
        ]),
      );

  Widget _bullet(String t) => Padding(
        padding: const EdgeInsets.only(bottom: EmSpacing.s4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsetsDirectional.only(top: EmSpacing.s8, end: EmSpacing.s8), child: ExcludeSemantics(child: Icon(Icons.circle, size: 6, color: EmColors.textSecondary))),
          Expanded(child: Text(t, style: EmType.label.copyWith(color: EmColors.ink, fontWeight: FontWeight.w400))),
        ]),
      );

  Widget _actionItem(ParentMeeting m, PtmActionItem a, {required bool enabled}) {
    final busy = c.itemBusy.contains(a.id);
    final due = a.dueDay;
    return AppCard(
      key: ValueKey('ptm_item_${a.id}'),
      padding: const EdgeInsetsDirectional.fromSTEB(EmSpacing.s4, EmSpacing.s4, EmSpacing.s12, EmSpacing.s4),
      child: Row(children: [
        if (busy)
          const Padding(padding: EdgeInsets.all(EmSpacing.s12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
        else
          Checkbox(
            key: ValueKey('ptm_item_check_${a.id}'),
            value: a.done,
            onChanged: enabled ? (v) async => _report(await c.setActionItem(a.id, done: v ?? false)) : null,
          ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.description.isEmpty ? '(No description)' : a.description, style: EmType.label.copyWith(fontWeight: FontWeight.w700, color: a.done ? EmColors.textSecondary : EmColors.ink, decoration: a.done ? TextDecoration.lineThrough : null)),
            if (a.assignedTo.isNotEmpty || due != null)
              Text([if (a.assignedTo.isNotEmpty) a.assignedTo, if (due != null) 'due ${shortDay(due)}'].join(' · '), style: EmType.caption.copyWith(color: EmColors.textSecondary)),
          ]),
        ),
      ]),
    );
  }

  List<Widget> _buttons(ParentMeeting m, Set<PtmAction> allowed, PtmAction? busy) {
    Widget btn(PtmAction a, String key, String label, IconData icon, VoidCallback onTap, {bool primary = false, bool danger = false}) {
      if (!allowed.contains(a)) return const SizedBox.shrink();
      final working = busy == a;
      final off = busy != null;
      return Padding(
        padding: const EdgeInsets.only(bottom: EmSpacing.s8),
        child: primary
            ? EmPrimaryButton(key: Key(key), label: label, icon: icon, loading: working, onPressed: off ? null : onTap)
            : EmSecondaryButton(key: Key(key), label: label, icon: icon, expand: true, destructive: danger, loading: working, onPressed: off ? null : onTap),
      );
    }

    return [
      btn(PtmAction.confirm, 'ptm_confirm', 'Confirm meeting', Icons.check_circle_outline_rounded, _confirm, primary: true),
      btn(PtmAction.recordOutcome, 'ptm_outcome_btn', 'Record outcome', Icons.fact_check_outlined, () => showOutcomeSheet(context, c, onResult: _report), primary: !allowed.contains(PtmAction.confirm)),
      btn(PtmAction.reschedule, 'ptm_reschedule', 'Reschedule', Icons.edit_calendar_rounded, () => showRescheduleSheet(context, c, onResult: _report)),
      btn(PtmAction.messageGuardian, 'ptm_message', 'Message guardian', Icons.chat_bubble_outline_rounded, () {
        final s = c.messageStudent;
        if (s != null) Get.toNamed(Routes.messageNew, arguments: s);
      }),
      btn(PtmAction.cancel, 'ptm_cancel', 'Cancel meeting', Icons.event_busy_rounded, () => showCancelSheet(context, c, onResult: _report), danger: true),
    ];
  }

  Future<void> _confirm() async {
    final ok = await ConfirmDialog.show(title: 'Confirm this meeting?', message: 'The guardian is told that the meeting is confirmed.', confirmLabel: 'Confirm');
    if (!ok) return;
    _report(await c.confirm());
  }

  Widget _history() => Obx(() {
        final st = c.history.value;
        if (c.meeting == null || c.meeting!.studentId.isEmpty) return const SizedBox.shrink();
        Widget body;
        switch (st.status) {
          case SectionStatus.loading:
            body = const Padding(padding: EdgeInsets.all(EmSpacing.s8), child: LinearProgressIndicator(key: Key('ptm_history_loading')));
          case SectionStatus.data:
            body = Column(children: [
              for (final h in st.data!.take(10))
                AppCard(
                  key: ValueKey('ptm_hist_${h.id}'),
                  onTap: () => Get.toNamed(Routes.ptmDetailOf(h.id)),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(meetingWhen(h, shortDay), style: EmType.label.copyWith(fontWeight: FontWeight.w700, color: EmColors.ink)),
                        if (h.teacherName.isNotEmpty) Text(h.teacherName, style: EmType.caption.copyWith(color: EmColors.textSecondary)),
                      ]),
                    ),
                    PtmStatusTag(h.status),
                  ]),
                ),
            ]);
          case SectionStatus.empty:
            body = Text('No earlier meetings for this student.', key: const Key('ptm_history_empty'), style: EmType.label.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400));
          default:
            body = Text("Earlier meetings couldn't be loaded.", key: const Key('ptm_history_unavailable'), style: EmType.label.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400));
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const SubHeading('Earlier meetings with this student'), body]);
      });
}
