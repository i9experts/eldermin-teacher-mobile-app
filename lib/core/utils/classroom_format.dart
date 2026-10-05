import 'package:intl/intl.dart';
import '../models/homework/homework_models.dart';

const _wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "Mon 5 Oct" for a calendar day (no timezone involved: [d] is a y/m/d).
String shortDay(DateTime d) => '${_wd[d.weekday - 1]} ${d.day} ${_mo[d.month - 1]}';

/// "5 Oct 2026".
String fullDay(DateTime d) => '${d.day} ${_mo[d.month - 1]} ${d.year}';

/// "5 Oct, 14:32" in the DEVICE timezone, for a real instant (a submission time).
String instantText(DateTime instant) => DateFormat('d MMM, HH:mm').format(instant.toLocal());

/// Whole calendar days from [from] to [to] (both y/m/d), DST-safe.
int daysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// "Due Mon 5 Oct" / "Due today" / "Due tomorrow" / "Overdue by 2 days" / "No due date".
String dueText(Assignment a, DateTime today) {
  final due = a.dueDay;
  if (due == null) return 'No due date';
  final diff = daysBetween(today, due);
  if (a.isDraft) return 'Due ${shortDay(due)}';
  if (diff == 0) return 'Due today';
  if (diff == 1) return 'Due tomorrow';
  if (diff > 1) return 'Due ${shortDay(due)}';
  final late = -diff;
  return 'Overdue by $late ${late == 1 ? 'day' : 'days'}';
}

String markText(double v) => v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

String sizeText(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
