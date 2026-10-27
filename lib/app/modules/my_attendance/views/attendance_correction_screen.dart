import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/design/design.dart';
import '../../../../core/models/attendance/self_attendance_models.dart';
import '../../../../core/services/self_attendance_repository.dart' show kNoStaffRecordMessage;
import '../../../../core/utils/self_attendance_rules.dart';
import '../../../../core/widgets/app_date_picker.dart';
import '../../../components/confirm_dialog.dart';
import '../../homework/views/widgets/homework_widgets.dart' show ErrorBanner, FormLabel;
import '../../ptm/views/widgets/ptm_widgets.dart' show pickHm;
import '../controllers/attendance_correction_controller.dart';
import 'my_attendance_format.dart';

/// Request an attendance correction (`/my-attendance/correct`).
class AttendanceCorrectionScreen extends GetView<AttendanceCorrectionController> {
  const AttendanceCorrectionScreen({super.key});

  AttendanceCorrectionController get c => controller;

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
          final leave =
              await ConfirmDialog.show(title: 'Discard this request?', message: 'What you entered will be lost.', confirmLabel: 'Discard', destructive: true);
          if (!leave) return;
        }
        Get.back();
      },
      child: EmScaffold(
        appBar: EmAppBar(title: 'Request a correction'),
        body: Obx(() {
          if (c.noStaffRecord.value) {
            return const Padding(
              padding: EmSpacing.listPadding,
              child: EmEmptyState(key: Key('corr_no_staff'), icon: Icons.person_off_outlined, title: 'No staff record linked', message: kNoStaffRecordMessage),
            );
          }
          return Column(children: [Expanded(child: _form(context)), _bottom(context)]);
        }),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final e = c.errors;
    final f = c.failureText.value;
    final date = c.date.value;
    final status = c.status.value;
    final today = c.today;
    return ListView(padding: const EdgeInsets.fromLTRB(EmSpacing.screenH, EmSpacing.s16, EmSpacing.screenH, EmSpacing.s24), children: [
      if (f != null) ...[ErrorBanner(bannerKey: const Key('corr_submit_error'), message: f), const SizedBox(height: EmSpacing.s12)],
      const EmInfoBanner(
          text: 'Your school reviews this request. Your attendance record changes only if it is approved.',
          tone: EmTone.info,
          icon: Icons.info_outline_rounded),
      const SizedBox(height: EmSpacing.block),
      FormLabel('Date *', error: e['date']),
      KeyedSubtree(
        key: const Key('corr_date'),
        child: EmSelectField(
          icon: Icons.event_rounded,
          trailingIcon: null,
          title: date == null ? null : dayText(date),
          placeholder: 'Choose the day',
          hasError: e['date'] != null,
          onTap: () async {
            final p =
                await showAppDatePicker(context, initialDate: date ?? today, firstDate: DateTime(today.year - 1, today.month, today.day), lastDate: today);
            if (p != null) c.setDate(p);
          },
        ),
      ),
      const SizedBox(height: EmSpacing.block),
      FormLabel('What your attendance should be *', error: e['status']),
      KeyedSubtree(
        key: const Key('corr_status'),
        child: EmSelectField(
          icon: Icons.fact_check_outlined,
          titleKey: const Key('corr_status_value'),
          title: status?.label,
          placeholder: 'Choose a status',
          hasError: e['status'] != null,
          trailingIcon: Icons.expand_more_rounded,
          onTap: () => _pickStatus(context),
        ),
      ),
      const SizedBox(height: EmSpacing.block),
      FormLabel('Check-in time (if known)'),
      _timeField(context, 'corr_check_in', c.checkIn.value, 'Not set', c.setCheckIn),
      const SizedBox(height: EmSpacing.block),
      FormLabel('Check-out time (if known)'),
      _timeField(context, 'corr_check_out', c.checkOut.value, 'Not set', c.setCheckOut),
      const SizedBox(height: EmSpacing.block),
      FormLabel('Reason *', error: e['reason']),
      TextField(
        key: const Key('corr_reason'),
        controller: c.reasonC,
        maxLines: 5,
        minLines: 3,
        maxLength: kCorrectionReasonMax,
        textCapitalization: TextCapitalization.sentences,
        onChanged: (_) => c.errors.remove('reason'),
        style: EmType.body.copyWith(color: EmColors.ink),
        decoration:
            InputDecoration(hintText: 'What happened? (at least $kCorrectionReasonMin characters)', counterText: '', errorText: e['reason'], errorMaxLines: 3),
      ),
      const SizedBox(height: EmSpacing.s4),
      Obx(() {
        final n = c.reasonLength.value;
        final low = n > 0 && n < kCorrectionReasonMin;
        return Text(
          '$n / $kCorrectionReasonMax${low ? ' (at least $kCorrectionReasonMin)' : ''}',
          key: const Key('corr_counter'),
          textAlign: TextAlign.end,
          style: EmType.caption.copyWith(color: low ? EmColors.error : EmColors.textSecondary, fontWeight: FontWeight.w400),
        );
      }),
    ]);
  }

  Widget _timeField(BuildContext context, String key, String? value, String placeholder, ValueChanged<String?> set) {
    return Row(children: [
      Expanded(
        child: KeyedSubtree(
          key: Key(key),
          child: EmSelectField(
              icon: Icons.schedule_rounded,
              trailingIcon: null,
              title: value,
              placeholder: placeholder,
              onTap: () async {
                final p = await pickHm(context, initial: value ?? '08:00');
                if (p != null) set(p);
              }),
        ),
      ),
      if (value != null)
        EmIconCircleButton(
            key: Key('${key}_clear'), icon: Icons.close_rounded, semanticLabel: 'Clear time', tooltip: 'Clear time', elevated: false, onTap: () => set(null)),
    ]);
  }

  Future<void> _pickStatus(BuildContext context) async {
    final picked = await EmBottomSheet.show<StaffDayStatus>(
      context,
      title: 'What your attendance should be',
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        for (final s in c.statusOptions)
          InkWell(
            key: Key('corr_status_${s.wire}'),
            onTap: () => Navigator.of(context).pop(s),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: EmSpacing.minTouch),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: EmSpacing.screenH, vertical: EmSpacing.s8),
                child: Row(children: [
                  Expanded(
                      child:
                          Text(s.label, style: EmType.body.copyWith(color: EmColors.ink, fontWeight: c.status.value == s ? FontWeight.w700 : FontWeight.w400))),
                  if (c.status.value == s) const Icon(Icons.check_rounded, color: EmColors.primary),
                ]),
              ),
            ),
          ),
      ]),
    );
    if (picked != null) c.setStatus(picked);
  }

  Widget _bottom(BuildContext context) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(EmSpacing.screenH, EmSpacing.s12, EmSpacing.screenH, EmSpacing.s12),
          decoration: const BoxDecoration(color: EmColors.surface, border: Border(top: BorderSide(color: EmColors.border))),
          child: Obx(() => EmPrimaryButton(
              key: const Key('corr_submit'), label: 'Send request', loading: c.saving.value, onPressed: c.saving.value ? null : () => _submit(context))),
        ),
      );

  Future<void> _submit(BuildContext context) async {
    final r = await c.submit();
    if (!context.mounted) return;
    switch (r) {
      case CorrectionDone():
        _snack(context, 'Correction request sent. You will see the decision under Requests.');
        Get.back();
      case CorrectionInvalid(:final errors):
        _snack(context, errors.values.first);
      case CorrectionFailed(:final text):
        _snack(context, text);
      case CorrectionIgnored():
        break;
    }
  }
}
