import 'package:flutter/material.dart';
import '../../../../core/models/leave/leave_models.dart';
import '../../../../core/utils/classroom_format.dart';
import '../../../../core/widgets/detail_bottom_sheet.dart';
import 'leave_screen.dart' show leaveRange, leaveStatusTag;

/// Opens the detail sheet of one of my leave requests (read-only: a request can only be sent or viewed here).
Future<void> showLeaveDetailSheet(BuildContext context, StaffLeaveRequest request) =>
    DetailBottomSheet.show<void>(context, data: () => leaveSheetData(request));

/// What the sheet shows. Only parsed fields: `approvedBy` (the approver's profile and e-mail) is never read.
DetailSheetData leaveSheetData(StaffLeaveRequest l) {
  final note = l.status == StaffLeaveStatus.rejected && l.rejectionReason.isNotEmpty ? l.rejectionReason : l.approverNote;
  return DetailSheetData(
    title: '${l.typeLabel} leave',
    statusLabel: l.status.label,
    statusTone: leaveStatusTag(l.status),
    fields: [
      DetailField('Dates', leaveRange(l)),
      DetailField('Half day', l.isHalfDay ? (l.halfDaySession.isEmpty ? 'Yes' : _capitalise(l.halfDaySession)) : null),
      DetailField('Request no.', l.leaveNo),
      DetailField('Applied on', l.createdAt == null ? null : fullDay(l.createdAt!.toLocal())),
    ],
    longTextLabel: 'Reason',
    longText: l.reason,
    sections: [
      if (l.status != StaffLeaveStatus.pending)
        DetailSection('Decision', [
          DetailField(l.status == StaffLeaveStatus.rejected ? 'Decided by' : 'Decision by', l.approverName),
          DetailField('Decided on', l.decidedAt == null ? null : fullDay(l.decidedAt!.toLocal())),
          DetailField(l.status == StaffLeaveStatus.rejected ? 'Reason given' : 'Note', note),
        ]),
    ],
  );
}

String _capitalise(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
