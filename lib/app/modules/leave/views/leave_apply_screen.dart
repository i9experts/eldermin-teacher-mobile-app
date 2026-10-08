import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/models/leave/leave_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/classroom_format.dart';
import '../../../../core/utils/leave_rules.dart';
import '../../../../core/widgets/app_date_picker.dart';
import '../../../components/confirm_dialog.dart';
import '../../../components/custom_text.dart';
import '../../homework/views/widgets/homework_widgets.dart';
import '../../ptm/views/widgets/ptm_widgets.dart';
import '../controllers/leave_apply_controller.dart';
import 'leave_screen.dart';

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
      child: Scaffold(
        appBar: AppBar(title: const Text('Apply for leave')),
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
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
      if (f != null) ErrorBanner(bannerKey: const Key('leave_submit_error'), message: f),
      FormLabel('Leave type *', error: e['type']),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final t in StaffLeaveType.values)
          ChoiceChip(key: Key('leave_type_${t.wire}'), label: Text(t.label), selected: c.type.value == t, onSelected: (_) => c.setType(t)),
      ]),
      const SizedBox(height: 14),
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
        const SizedBox(width: 12),
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
      const SizedBox(height: 6),
      CustomText(key: const Key('leave_days_hint'), text: c.daysHint, fontSize: 11.5, color: AppColors.muted, height: 1.35),
      const SizedBox(height: 10),
      SwitchListTile(
        key: const Key('leave_half_day'),
        contentPadding: EdgeInsets.zero,
        title: const CustomText(text: 'Half day', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink),
        value: c.halfDay.value,
        onChanged: c.setHalfDay,
      ),
      if (c.halfDay.value)
        Row(children: [
          for (final s in const ['morning', 'afternoon'])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(key: Key('leave_session_$s'), label: Text(s == 'morning' ? 'Morning' : 'Afternoon'), selected: c.session.value == s, onSelected: (_) => c.session.value = s),
            ),
        ]),
      if (hint != null) _note(const Key('leave_balance_hint'), hint, warn: true),
      if (overlaps.isNotEmpty) _note(const Key('leave_overlap_hint'), 'You already have a ${overlaps.first.status.label.toLowerCase()} request for ${leaveRange(overlaps.first)}. You can still send this one.', warn: true),
      const SizedBox(height: 10),
      LabeledField(label: 'Reason', required: true, controller: c.reasonC, fieldKey: const Key('leave_reason'), maxLines: 4, maxLength: kLeaveReasonMax, hint: 'Why do you need leave? (at least $kLeaveReasonMin characters)', error: e['reason'], onChanged: (_) => c.errors.remove('reason')),
      const CustomText(text: 'Your request goes to the school for a decision. You are notified when it is decided.', fontSize: 11.5, color: AppColors.muted, height: 1.35),
    ]);
  }

  Widget _note(Key key, String text, {bool warn = false}) => Container(
        key: key,
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: warn ? AppColors.amberBg : AppColors.pale, borderRadius: BorderRadius.circular(AppRadius.md)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline_rounded, size: 16, color: warn ? AppColors.amberText : AppColors.blue),
          const SizedBox(width: 8),
          Expanded(child: CustomText(text: text, fontSize: 11.5, color: warn ? AppColors.amberText : AppColors.muted, height: 1.35)),
        ]),
      );

  Widget _bottom(BuildContext context) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.line))),
          child: SizedBox(
            width: double.infinity,
            child: Obx(() => ElevatedButton(
                  key: const Key('leave_submit'),
                  onPressed: c.saving.value ? null : () => _submit(context),
                  child: c.saving.value ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const CustomText(text: 'Send request', color: Colors.white, fontWeight: FontWeight.w700),
                )),
          ),
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
