import '../models/calendar/calendar_models.dart';
import 'classroom_format.dart';

String _hm(DateTime i) {
  final l = i.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

/// "Mon 5 Oct" or "Mon 5 Oct - Wed 7 Oct" (all-day: the stored calendar days; timed: device-local days).
String entryDaysText(CalendarEntry e) {
  final a = e.firstDay, b = e.lastDay;
  return e.isMultiDay ? '${shortDay(a)} - ${shortDay(b)}' : shortDay(a);
}

/// One line for a list card: "All day" / "09:00 - 10:30", plus the day span for multi-day entries.
String entrySubtitle(CalendarEntry e) => e.isMultiDay ? '${entryDaysText(e)} · ${e.timeLabel()}' : e.timeLabel();

String sessionText(EventSession s) {
  final a = s.start.toLocal(), b = s.end.toLocal();
  final sameDay = a.year == b.year && a.month == b.month && a.day == b.day;
  final first = '${shortDay(DateTime(a.year, a.month, a.day))}, ${_hm(s.start)}';
  if (s.end == s.start) return first;
  return sameDay ? '$first - ${_hm(s.end)}' : '$first - ${shortDay(DateTime(b.year, b.month, b.day))}, ${_hm(s.end)}';
}

/// "Mon 5 Oct, 09:00" / "Mon 5 Oct - Wed 7 Oct" / "Date to be confirmed".
String eventWhenText(SchoolEvent e) {
  if (e.sessions.isEmpty) return 'Date to be confirmed';
  if (e.sessions.length == 1) return sessionText(e.sessions.first);
  final a = e.firstStart!.toLocal(), b = e.lastEnd!.toLocal();
  final d1 = DateTime(a.year, a.month, a.day), d2 = DateTime(b.year, b.month, b.day);
  return d1 == d2 ? '${shortDay(d1)} · ${e.sessions.length} sessions' : '${shortDay(d1)} - ${shortDay(d2)} · ${e.sessions.length} sessions';
}

/// "Wed 7 Oct" style heading with the year when it is not the current one.
String dayHeading(DateTime d, DateTime today) => d.year == today.year ? shortDay(d) : '${shortDay(d)} ${d.year}';
