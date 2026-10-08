import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/ptm/ptm_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/classroom_format.dart';
import '../../../../core/utils/ptm_rules.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/screen_state_view.dart';
import '../../../components/confirm_dialog.dart';
import '../../../components/custom_text.dart';
import '../../../routes/app_routes.dart';
import '../../home/models/section_state.dart';
import '../controllers/ptm_detail_controller.dart';
import 'ptm_action_sheets.dart';
import 'widgets/ptm_widgets.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Meeting')),
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
            Expanded(child: CustomText(key: const Key('ptm_student'), text: m.studentName.isEmpty ? 'Student' : m.studentName, fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.primaryColor)),
            PtmStatusTag(m.status),
          ]),
          if (m.classLabel.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: CustomText(text: m.classLabel, fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 10),
          _line(Icons.event_rounded, meetingWhen(m, (d) => '${shortDay(d)} ${d.year}'), key: const Key('ptm_when')),
          _line(Icons.family_restroom_rounded, m.guardianName.isEmpty ? 'Guardian not recorded' : 'With ${m.guardianName}', key: const Key('ptm_guardian')),
          if (m.teacherName.isNotEmpty) _line(Icons.person_rounded, 'Teacher: ${m.teacherName}${c.isMine ? ' (you)' : ''}'),
          if (isOverdueOpen(m, now)) const Padding(padding: EdgeInsets.only(top: 4), child: CustomText(key: Key('ptm_overdue_hint'), text: 'The date has passed and no outcome is recorded yet.', fontSize: 12, color: AppColors.amberText, fontWeight: FontWeight.w700)),
          if (!c.isMine) const Padding(padding: EdgeInsets.only(top: 8), child: CustomText(key: Key('ptm_not_mine'), text: 'This meeting belongs to another teacher, so you can only view it.', fontSize: 12, color: AppColors.muted)),
        ]),
      ),
      if (m.status == PtmStatus.cancelled)
        AppCard(
          key: const Key('ptm_cancelled_box'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const CustomText(text: 'Cancelled', fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.redText),
            const SizedBox(height: 4),
            CustomText(text: m.cancelledReason.isEmpty ? 'No reason was recorded.' : m.cancelledReason, fontSize: 12.5, color: AppColors.ink, height: 1.35),
            if (m.cancelledBy.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: CustomText(text: 'By ${m.cancelledBy}', fontSize: 11, color: AppColors.muted)),
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
            const SizedBox(height: 8),
            CustomText(text: m.meetingNotes.isEmpty ? 'No notes were recorded.' : m.meetingNotes, fontSize: 12.5, color: m.meetingNotes.isEmpty ? AppColors.muted : AppColors.ink, height: 1.4),
          ]),
        ),
      ],
      if (m.actionItems.isNotEmpty) ...[
        const SubHeading('Action items'),
        for (final a in m.actionItems) _actionItem(m, a, enabled: allowed.contains(PtmAction.toggleActionItems)),
      ],
      const SizedBox(height: 4),
      ..._buttons(m, allowed, busy),
      _history(),
    ];
  }

  Widget _line(IconData icon, String text, {Key? key}) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 16, color: AppColors.muted),
          const SizedBox(width: 8),
          Expanded(child: CustomText(key: key, text: text, fontSize: 13, color: AppColors.ink)),
        ]),
      );

  Widget _bullet(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.only(top: 6, right: 8), child: Icon(Icons.circle, size: 5, color: AppColors.muted)),
          Expanded(child: CustomText(text: t, fontSize: 12.5, color: AppColors.ink, height: 1.35)),
        ]),
      );

  Widget _actionItem(ParentMeeting m, PtmActionItem a, {required bool enabled}) {
    final busy = c.itemBusy.contains(a.id);
    final due = a.dueDay;
    return AppCard(
      key: ValueKey('ptm_item_${a.id}'),
      padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
      child: Row(children: [
        if (busy)
          const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
        else
          Checkbox(
            key: ValueKey('ptm_item_check_${a.id}'),
            value: a.done,
            onChanged: enabled ? (v) async => _report(await c.setActionItem(a.id, done: v ?? false)) : null,
          ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.description.isEmpty ? '(No description)' : a.description, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: a.done ? AppColors.muted : AppColors.ink, decoration: a.done ? TextDecoration.lineThrough : null)),
            if (a.assignedTo.isNotEmpty || due != null)
              CustomText(text: [if (a.assignedTo.isNotEmpty) a.assignedTo, if (due != null) 'due ${shortDay(due)}'].join(' · '), fontSize: 11, color: AppColors.muted),
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
      final style = danger ? OutlinedButton.styleFrom(foregroundColor: AppColors.redText, side: BorderSide(color: AppColors.redText.withOpacity(0.5))) : null;
      final child = working ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 18), const SizedBox(width: 8), Text(label)]);
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: SizedBox(
          width: double.infinity,
          child: primary
              ? ElevatedButton(key: Key(key), onPressed: off ? null : onTap, child: child)
              : OutlinedButton(key: Key(key), style: style, onPressed: off ? null : onTap, child: child),
        ),
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
            body = const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator(key: Key('ptm_history_loading')));
          case SectionStatus.data:
            body = Column(children: [
              for (final h in st.data!.take(10))
                AppCard(
                  key: ValueKey('ptm_hist_${h.id}'),
                  onTap: () => Get.toNamed(Routes.ptmDetailOf(h.id)),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        CustomText(text: meetingWhen(h, shortDay), fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.ink),
                        if (h.teacherName.isNotEmpty) CustomText(text: h.teacherName, fontSize: 11, color: AppColors.muted),
                      ]),
                    ),
                    PtmStatusTag(h.status),
                  ]),
                ),
            ]);
          case SectionStatus.empty:
            body = const CustomText(key: Key('ptm_history_empty'), text: 'No earlier meetings for this student.', fontSize: 12, color: AppColors.muted);
          default:
            body = const CustomText(key: Key('ptm_history_unavailable'), text: "Earlier meetings couldn't be loaded.", fontSize: 12, color: AppColors.muted);
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const SubHeading('Earlier meetings with this student'), body]);
      });
}
