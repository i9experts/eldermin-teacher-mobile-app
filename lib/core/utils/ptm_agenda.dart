import '../models/home/teaching.dart';
import 'home_time.dart';

/// Today's and upcoming parent meetings, ready for the Home card.
///
/// Sources (merged, deduped by `_id`):
///  - `GET /teaching/ptm?teacherId&from&to` for today's window (any status). Verified in
///    eldermin-backend ptm.service.ts:91-104 (filters teacherId/status/from/to via `new Date(x)`,
///    sorted scheduledDate desc, limit 200, campus-scoped).
///  - `GET /teaching/ptm/upcoming/mine?teacherId` (ptm.service.ts:178-183): requested|confirmed with
///    scheduledDate >= now, which DROPS today's meetings once now passes the stored midnight.
///
/// UNVERIFIED (U8-ptm, register in PHASE4_REPORT): `scheduledDate` is the picked day stored as a Date
/// (midnight UTC assumed). So a meeting counts as "today" when its UTC date OR its local date equals
/// the device-local calendar date.
class PtmAgenda {
  /// Today, not over yet (start time order).
  final List<PtmMeeting> remainingToday;

  /// Today, but already past (end time before now) or completed/cancelled/no_show.
  final List<PtmMeeting> earlierToday;

  /// requested|confirmed on a later date (date, then start time).
  final List<PtmMeeting> upcoming;

  const PtmAgenda({this.remainingToday = const [], this.earlierToday = const [], this.upcoming = const []});

  bool get isEmpty => remainingToday.isEmpty && earlierToday.isEmpty && upcoming.isEmpty;
}

const _closedStatuses = {'completed', 'cancelled', 'no_show'};
const _openStatuses = {'requested', 'confirmed'};

/// Query window for today's meetings: the UTC day of the device-local date, widened to also cover
/// the local-midnight-based day (so [isPtmToday]'s local-date tolerance can actually match).
/// In a UTC device zone this is exactly the UTC-day window.
({DateTime from, DateTime to}) ptmTodayWindow(DateTime now) {
  final utc = todayRangeUtc(now);
  final localFrom = DateTime(now.year, now.month, now.day).toUtc();
  final localTo = DateTime(now.year, now.month, now.day, 23, 59, 59, 999).toUtc();
  return (
    from: localFrom.isBefore(utc.from) ? localFrom : utc.from,
    to: localTo.isAfter(utc.to) ? localTo : utc.to,
  );
}

String _utcKey(DateTime d) {
  final u = d.toUtc();
  return dateKeyOf(DateTime(u.year, u.month, u.day));
}

/// True when the meeting's UTC date OR local date equals [now]'s local calendar date.
bool isPtmToday(PtmMeeting m, DateTime now) {
  final d = m.scheduledDate;
  if (d == null) return false;
  final today = dateKeyOf(now);
  return _utcKey(d) == today || dateKeyOf(d.toLocal()) == today;
}

/// A today meeting is over when its status is closed, or its end time (parseable) is not after now.
/// With no readable end time we cannot prove it is over, so only the status decides.
bool _isOver(PtmMeeting m, int nowMinutes) {
  if (_closedStatuses.contains(m.status)) return true;
  final end = parseHm(m.endTime);
  return end != null && nowMinutes >= end;
}

int _startOf(PtmMeeting m) => parseHm(m.startTime) ?? 1 << 20;

/// Merges [meetings] (any number of source lists concatenated) and splits them for [now].
PtmAgenda buildPtmAgenda(Iterable<PtmMeeting> meetings, DateTime now) {
  final seen = <String>{};
  final nowMin = now.hour * 60 + now.minute;
  final today = dateKeyOf(now);
  final remaining = <PtmMeeting>[], earlier = <PtmMeeting>[], upcoming = <PtmMeeting>[];
  for (final m in meetings) {
    if (m.id.isNotEmpty && !seen.add(m.id)) continue; // dedupe by _id (first source wins)
    final d = m.scheduledDate;
    if (d == null) continue;
    if (isPtmToday(m, now)) {
      (_isOver(m, nowMin) ? earlier : remaining).add(m);
    } else if (_utcKey(d).compareTo(today) > 0 && _openStatuses.contains(m.status)) {
      upcoming.add(m);
    }
  }
  int byStart(PtmMeeting a, PtmMeeting b) => _startOf(a).compareTo(_startOf(b));
  remaining.sort(byStart);
  earlier.sort(byStart);
  upcoming.sort((a, b) {
    final c = a.scheduledDate!.compareTo(b.scheduledDate!);
    return c != 0 ? c : byStart(a, b);
  });
  return PtmAgenda(remainingToday: remaining, earlierToday: earlier, upcoming: upcoming);
}
