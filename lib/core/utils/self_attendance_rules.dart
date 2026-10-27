import '../models/attendance/self_attendance_models.dart';

/// Reason length bounds: the web form requires >= 10 (my-attendance/index.tsx), the DTO allows 1..2000.
const int kCorrectionReasonMin = 10;
const int kCorrectionReasonMax = 2000;

/// Per-field problems of a correction form ([] = valid). Keys: `date`, `status`, `reason`.
Map<String, String> validateCorrection({DateTime? date, StaffDayStatus? status, required String reason, required DateTime today}) {
  final e = <String, String>{};
  final t = DateTime(today.year, today.month, today.day);
  if (date == null) {
    e['date'] = 'Choose the date to correct.';
  } else if (DateTime(date.year, date.month, date.day).isAfter(t)) {
    e['date'] = 'You can only correct today or a past day.';
  }
  if (status == null) {
    e['status'] = 'Choose what your attendance should be.';
  } else if (!status.requestable) {
    e['status'] = 'This status cannot be requested.';
  }
  final r = reason.trim();
  if (r.length < kCorrectionReasonMin) {
    e['reason'] = 'Explain the reason in at least $kCorrectionReasonMin characters.';
  } else if (r.length > kCorrectionReasonMax) {
    e['reason'] = 'The reason can be at most $kCorrectionReasonMax characters.';
  }
  return e;
}

/// Counts shown in the month summary (only what the records support): Present = present, remote, extra day; Late; Absent; Leave = on leave, sick leave.
class MonthSummary {
  final int present, late, absent, leave;
  const MonthSummary({this.present = 0, this.late = 0, this.absent = 0, this.leave = 0});

  factory MonthSummary.of(Iterable<StaffAttendanceDay> days) {
    var p = 0, l = 0, a = 0, v = 0;
    for (final d in days) {
      switch (d.status) {
        case StaffDayStatus.present || StaffDayStatus.remote || StaffDayStatus.extraDay:
          p++;
        case StaffDayStatus.late:
          l++;
        case StaffDayStatus.absent:
          a++;
        case StaffDayStatus.onLeave || StaffDayStatus.sickLeave:
          v++;
        default:
          break;
      }
    }
    return MonthSummary(present: p, late: l, absent: a, leave: v);
  }
}
