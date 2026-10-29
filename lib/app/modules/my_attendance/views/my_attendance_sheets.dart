import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/design/design.dart';
import '../../../../core/models/attendance/self_attendance_models.dart';
import '../../../../core/models/json_helpers.dart';
import '../../../../core/utils/classroom_format.dart';
import '../../../../core/widgets/detail_bottom_sheet.dart';
import '../../../routes/app_routes.dart';
import 'my_attendance_format.dart';

/// Opens the detail sheet of one attendance day, with the "Request correction" action. [pending] = a correction request for that day is
/// already waiting (shown as a note; the server still accepts another).
Future<void> showAttendanceDaySheet(BuildContext context, StaffAttendanceDay day, {AttendanceCorrectionRequest? pending}) =>
    DetailBottomSheet.show<void>(context, data: () => attendanceDaySheetData(day, pending: pending), fitContent: true);

DetailSheetData attendanceDaySheetData(StaffAttendanceDay d, {AttendanceCorrectionRequest? pending}) {
  final workHours = d.workingHours;
  return DetailSheetData(
    title: dayText(d.day),
    statusLabel: d.statusLabel,
    statusTone: dayStatusTone(d.status),
    notice: pending == null ? null : 'A correction request for this day is waiting for a decision.',
    fields: [
      DetailField('Check-in', d.checkIn),
      DetailField('Check-out', d.checkOut),
      DetailField('Late by', lateText(d.lateByMins)),
      DetailField('Working hours',
          workHours == null || workHours <= 0 ? null : '${workHours == workHours.roundToDouble() ? workHours.round() : workHours.toStringAsFixed(1)} h'),
    ],
    longTextLabel: 'Notes',
    longText: d.notes,
    footer: d.day == null
        ? null
        : EmPrimaryButton(
            key: const Key('my_att_request_correction'),
            label: 'Request correction',
            icon: Icons.edit_calendar_rounded,
            onPressed: () {
              Get.back<void>();
              Get.toNamed(Routes.myAttendanceCorrect, arguments: {'date': wireDay(d.day!)});
            },
          ),
  );
}

/// Opens the detail sheet of one of my correction requests (read-only: a decision is made by the school).
Future<void> showCorrectionSheet(BuildContext context, AttendanceCorrectionRequest r) =>
    DetailBottomSheet.show<void>(context, data: () => correctionSheetData(r), fitContent: true);

DetailSheetData correctionSheetData(AttendanceCorrectionRequest r) {
  final decided = r.status != CorrectionStatus.pending;
  return DetailSheetData(
    title: 'Correction for ${dayText(r.day)}',
    statusLabel: r.status.label,
    statusTone: correctionTone(r.status),
    sections: [
      DetailSection('Recorded', [
        DetailField('Status', r.currentLabel),
        DetailField('Check-in', r.currentCheckIn),
        DetailField('Check-out', r.currentCheckOut),
      ]),
      DetailSection('You asked for', [
        DetailField('Status', r.requestedLabel),
        DetailField('Check-in', r.requestedCheckIn),
        DetailField('Check-out', r.requestedCheckOut),
        DetailField('Sent on', r.createdAt == null ? null : fullDay(r.createdAt!.toLocal())),
      ]),
      if (decided)
        DetailSection('Decision', [
          DetailField('Decided by', r.reviewerName),
          DetailField('Decided on', r.reviewedAt == null ? null : fullDay(r.reviewedAt!.toLocal())),
          DetailField('Note', r.reviewNotes),
        ]),
    ],
    longTextLabel: 'Your reason',
    longText: r.reason,
  );
}
