import '../../../../core/design/design.dart';
import '../../../../core/models/attendance/self_attendance_models.dart';
import '../../../../core/utils/classroom_format.dart';

/// Chip tone of a day / requested status. Colour is never the only signal: the chip always carries the words.
EmTone dayStatusTone(StaffDayStatus s) => switch (s) {
      StaffDayStatus.present || StaffDayStatus.remote || StaffDayStatus.extraDay => EmTone.success,
      StaffDayStatus.late => EmTone.warning,
      StaffDayStatus.absent => EmTone.error,
      StaffDayStatus.halfDay => EmTone.info,
      StaffDayStatus.onLeave || StaffDayStatus.sickLeave => EmTone.leave,
      StaffDayStatus.holiday || StaffDayStatus.weekend || StaffDayStatus.unknown => EmTone.neutral,
    };

EmTone correctionTone(CorrectionStatus s) => switch (s) {
      CorrectionStatus.pending => EmTone.warning,
      CorrectionStatus.approved => EmTone.success,
      CorrectionStatus.rejected => EmTone.error,
      CorrectionStatus.unknown => EmTone.neutral,
    };

/// "In 08:25 · Out 14:30" from whatever of the two times exist; '' when neither.
String timesText(String checkIn, String checkOut) => [if (checkIn.isNotEmpty) 'In $checkIn', if (checkOut.isNotEmpty) 'Out $checkOut'].join(' · ');

/// "Fri 3 Oct 2026" (a day the server stored; null -> "Date not given").
String dayText(DateTime? d) => d == null ? 'Date not given' : '${shortDay(d)} ${d.year}';

String monthTitle(DateTime m) {
  const names = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  return '${names[m.month - 1]} ${m.year}';
}

String lateText(num? mins) {
  if (mins == null || mins <= 0) return '';
  final n = mins == mins.roundToDouble() ? mins.round().toString() : mins.toString();
  return '$n min late';
}
