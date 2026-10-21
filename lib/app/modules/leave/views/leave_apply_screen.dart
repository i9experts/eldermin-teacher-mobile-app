import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/leave/leave_models.dart';
import '../../../../core/utils/classroom_format.dart';
import '../../../../core/utils/leave_rules.dart';
import '../../../../core/widgets/app_date_picker.dart';
import '../../../components/confirm_dialog.dart';
import '../../homework/views/widgets/homework_widgets.dart';
import '../../ptm/views/widgets/ptm_widgets.dart';
import '../controllers/leave_apply_controller.dart';
import 'leave_screen.dart';
import '../../../../core/design/design.dart';

/// Apply for leave (`/leave/apply`).
class LeaveApplyScreen extends GetView<LeaveApplyController> {
  const LeaveApplyScreen({super.key});

  LeaveApplyController get c => controller;

  void _snack(BuildContext context, String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || c.saving.value) return;
        if (c.isDirty) {
          final leave = await ConfirmDialog.show(title: 'Discard this request?', message: 'What you entered will be lost.', confirmLabel: 'Discard', destructive: true);
          if (!leave) return;
        }
        Get.back();
      },
      child: EmScaffold(
        appBar: EmAppBar(title: 'Apply for leave'),
        body: Column(children: [Expanded(child: Obx(() => _form(context))), _bottom(context)]),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final e = c.errors;
    final f = c.failureText.value;
    final from = c.from.value, to = c.to.value;
    final today = DateTime.now();
    final hint = c.balanceHint;
    final overlaps = c.overlaps;
    return ListView(padding: const EdgeInsets.fromLTRB(EmSpacing.screenH, EmSpacing.s16, EmSpacing.screenH, EmSpacing.s24), children: [
      if (f != null) ErrorBanner(bannerKey: const Key('leave_submit_error'), message: f),
      FormLabel('Leave type *', error: e['type']),
      Wrap(spacing: EmSpacing.s8, runSpacing: EmSpacing.s8, children: [
        for (final t in StaffLeaveType.values)
          EmChip(key: Key('leave_type_${t.wire}'), label: t.label, icon: c.type.value == t ? Icons.check_rounded : null, selected: c.type.value == t, onTap: () => c.setType(t)),
      ]),
      const SizedBox(height: EmSpacing.block),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FormLabel('From *', error: e['from']),
            PickField(fieldKey: const Key('leave_from'), icon: Icons.event_rounded, text: from == null ? 'Choose' : '${shortDay(from)} ${from.year}', filled: from != null, error: e['from'], onTap: () async {
              final p = await showAppDatePicker(context, initialDate: from ?? today, firstDate: DateTime(today.year - 1, today.month, today.day), lastDate: DateTime(today.year + 2, 12, 31));
              if (p != null) c.setFrom(p);
            }),
          ]),
        ),
        const SizedBox(width: EmSpacing.row),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FormLabel('To *', error: e['to']),
            PickField(fieldKey: const Key('leave_to'), icon: Icons.event_rounded, text: to == null ? 'Choose' : '${shortDay(to)} ${to.year}', filled: to != null, error: e['to'], onTap: () async {
              final base = from ?? today;
              final p = await showAppDatePicker(context, initialDate: to ?? base, firstDate: from ?? DateTime(today.year - 1, today.month, today.day), lastDate: DateTime(today.year + 2, 12, 31));
              if (p != null) c.setTo(p);
            }),
          ]),
        ),
      ]),
      const SizedBox(height: EmSpacing.s8),
      Text(c.daysHint, key: const Key('leave_days_hint'), style: EmType.caption.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400)),
      const SizedBox(height: EmSpacing.s8),
      SwitchListTile(
        key: const Key('leave_half_day'),
        contentPadding: EdgeInsets.zero,
        title: Text('Half day', style: EmType.label.copyWith(fontWeight: FontWeight.w700, color: EmColors.ink)),
        value: c.halfDay.value,
        onChanged: c.setHalfDay,
      ),
      if (c.halfDay.value)
        Wrap(spacing: EmSpacing.s8, runSpacing: EmSpacing.s8, children: [
          for (final s in const ['morning', 'afternoon'])
            EmChip(key: Key('leave_session_$s'), label: s == 'morning' ? 'Morning' : 'Afternoon', icon: c.session.value == s ? Icons.check_rounded : null, selected: c.session.value == s, onTap: () => c.session.value = s),
        ]),
      if (hint != null) _note(const Key('leave_balance_hint'), hint, warn: true),
      if (overlaps.isNotEmpty) _note(const Key('leave_overlap_hint'), 'You already have a ${overlaps.first.status.label.toLowerCase()} request for ${leaveRange(overlaps.first)}. You can still send this one.', warn: true),
      const SizedBox(height: EmSpacing.s12),
      LabeledField(label: 'Reason', required: true, controller: c.reasonC, fieldKey: const Key('leave_reason'), maxLines: 4, maxLength: kLeaveReasonMax, hint: 'Why do you need leave? (at least $kLeaveReasonMin characters)', error: e['reason'], onChanged: (_) => c.errors.remove('reason')),
      Text('Your request goes to the school for a decision. You are notified when it is decided.', style: EmType.caption.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400)),
    ]);
  }

  Widget _note(Key key, String text, {bool warn = false}) => Padding(
        padding: const EdgeInsets.only(top: EmSpacing.s8),
        child: EmInfoBanner(key: key, text: text, tone: warn ? EmTone.warning : EmTone.info, icon: Icons.info_outline_rounded),
      );

  Widget _bottom(BuildContext context) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(EmSpacing.screenH, EmSpacing.s12, EmSpacing.screenH, EmSpacing.s12),
          decoration: const BoxDecoration(color: EmColors.surface, border: Border(top: BorderSide(color: EmColors.border))),
          child: Obx(() => EmPrimaryButton(key: const Key('leave_submit'), label: 'Send request', loading: c.saving.value, onPressed: c.saving.value ? null : () => _submit(context))),
        ),
      );

  Future<void> _submit(BuildContext context) async {
    final problems = validateLeave(c.input);
    if (problems.isNotEmpty) {
      c.errors.assignAll(problems);
      _snack(context, problems.values.first);
      return;
    }
    final i = c.input;
    final ok = await ConfirmDialog.show(
      title: 'Send this leave request?',
      message: '${i.type!.label} leave, ${shortDay(i.from!)}${i.to == i.from ? '' : ' - ${shortDay(i.to!)}'}${i.halfDay ? ' (half day)' : ''}. The school decides how many days are counted.',
      confirmLabel: 'Send',
    );
    if (!ok || !context.mounted) return;
    final r = await c.submit();
    if (!context.mounted) return;
    switch (r) {
      case ApplyDone():
        _snack(context, 'Leave request sent. You are notified when it is decided.');
        Get.back();
      case ApplyInvalid(:final errors):
        _snack(context, errors.values.first);
      case ApplyFailed(:final text):
        _snack(context, text);
      case ApplyIgnored():
        break;
    }
  }
}
