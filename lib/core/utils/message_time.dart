import 'package:intl/intl.dart';

/// Time text for messages and notifications. Every instant is converted to the DEVICE timezone ([DateTime.toLocal]); `now` is always passed
/// in so tests never depend on the wall clock.

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// "Just now", "5 min ago", "3 h ago" (same local day), "Yesterday", "Mon" (within the last week), else "5 Oct" / "5 Oct 2025".
String relativeTime(DateTime now, DateTime instant) {
  final n = now.toLocal(), t = instant.toLocal();
  final diff = n.difference(t);
  if (diff.isNegative || diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  final days = _day(n).difference(_day(t)).inDays;
  if (days == 0) return '${diff.inHours} h ago';
  if (days == 1) return 'Yesterday';
  if (days < 7) return DateFormat('EEE').format(t);
  return DateFormat(t.year == n.year ? 'd MMM' : 'd MMM yyyy').format(t);
}

/// "5 Oct 2026, 3:07 PM" in the device timezone.
String absoluteTime(DateTime instant) => DateFormat('d MMM yyyy, h:mm a').format(instant.toLocal());

/// Time of day in a chat bubble: "3:07 PM" today, "5 Oct, 3:07 PM" otherwise.
String bubbleTime(DateTime now, DateTime instant) {
  final t = instant.toLocal();
  return _day(now.toLocal()) == _day(t) ? DateFormat('h:mm a').format(t) : DateFormat('d MMM, h:mm a').format(t);
}

/// Group heading of a day: "Today", "Yesterday", "Mon, 5 Oct" (+ year when not the current one).
String dayHeading(DateTime now, DateTime instant) {
  final n = now.toLocal(), t = instant.toLocal();
  final days = _day(n).difference(_day(t)).inDays;
  if (days == 0) return 'Today';
  if (days == 1) return 'Yesterday';
  return DateFormat(t.year == n.year ? 'EEE, d MMM' : 'EEE, d MMM yyyy').format(t);
}

/// Local calendar day key `yyyy-MM-dd` for grouping.
String dayKey(DateTime instant) => DateFormat('yyyy-MM-dd').format(instant.toLocal());
