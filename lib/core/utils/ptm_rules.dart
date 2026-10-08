import '../models/home/teaching.dart';
import '../models/json_helpers.dart';
import '../models/ptm/ptm_models.dart';
import 'home_time.dart';
import 'ptm_agenda.dart';

/// What a teacher can do with a meeting (UI gating: the server has no ownership check on confirm / cancel / action items, ptm.service.ts
/// :155-163, :200-209, :211-221, so the UI MUST only offer them for meetings that are mine).
enum PtmAction { confirm, reschedule, recordOutcome, cancel, toggleActionItems, messageGuardian }

/// True when the meeting belongs to the signed-in teacher. [myStaffId] comes only from `GET /staff-portal/me`; meetings are keyed by
/// `Staff._id` (ptm-meeting.schema.ts:38). Unknown ids never match.
bool isMyMeeting(ParentMeeting m, String? myStaffId) => myStaffId != null && myStaffId.isNotEmpty && m.teacherId.isNotEmpty && m.teacherId == myStaffId;

/// Allowed actions per status, for MY meetings only (others: none).
///
///   requested : confirm, reschedule, record outcome, cancel      (the web offers the same: PTMTab.tsx:262-267)
///   confirmed : reschedule, record outcome, cancel
///   completed / no_show : toggle action items (the outcome is final; the server would also allow cancelling or re-recording: not offered)
///   cancelled / unknown : nothing
///
/// Server rules behind it: confirm only from `requested` (404 'Meeting not found or not in a requested state', ptm.service.ts:155-161);
/// reschedule only from requested|confirmed and it ALWAYS resets the status to `requested` (:166-174); outcome refuses cancelled (400, :186);
/// cancel works from ANY status (:211-217: a completed meeting could be cancelled), hence the UI restriction. 'Message guardian' is offered
/// for my meetings that are not cancelled (in-app messaging only; the teacher never sees a phone number or email).
Set<PtmAction> allowedPtmActions(ParentMeeting m, String? myStaffId) {
  if (!isMyMeeting(m, myStaffId)) return const {};
  switch (m.status) {
    case PtmStatus.requested:
      return const {PtmAction.confirm, PtmAction.reschedule, PtmAction.recordOutcome, PtmAction.cancel, PtmAction.messageGuardian};
    case PtmStatus.confirmed:
      return const {PtmAction.reschedule, PtmAction.recordOutcome, PtmAction.cancel, PtmAction.messageGuardian};
    case PtmStatus.completed:
    case PtmStatus.noShow:
      return {if (m.actionItems.isNotEmpty) PtmAction.toggleActionItems, PtmAction.messageGuardian};
    case PtmStatus.cancelled:
    case PtmStatus.unknown:
      return const {};
  }
}

/// Which list tab a meeting belongs to.
enum PtmTab { upcoming, today, past, cancelled }

/// The tabs, built from meetings of any window. Rules (all dates compared as calendar days, see [isPtmToday] for the UTC-midnight rule):
///  * cancelled                                   -> Cancelled (newest first)
///  * today (not cancelled)                       -> Today: not over first, then "Earlier today"
///  * requested|confirmed on a later day          -> Upcoming (soonest first)
///  * everything else (done, or still open but its day has passed) -> Past (newest first); an open meeting in the past has no outcome
///    recorded yet and says so.
class PtmTabs {
  final List<ParentMeeting> upcoming;
  final List<ParentMeeting> todayRemaining;
  final List<ParentMeeting> todayEarlier;
  final List<ParentMeeting> past;
  final List<ParentMeeting> cancelled;
  const PtmTabs({this.upcoming = const [], this.todayRemaining = const [], this.todayEarlier = const [], this.past = const [], this.cancelled = const []});

  int get todayCount => todayRemaining.length + todayEarlier.length;
  int countOf(PtmTab t) => switch (t) {
        PtmTab.upcoming => upcoming.length,
        PtmTab.today => todayCount,
        PtmTab.past => past.length,
        PtmTab.cancelled => cancelled.length,
      };
  bool get isEmpty => upcoming.isEmpty && todayCount == 0 && past.isEmpty && cancelled.isEmpty;
}

PtmTabs buildPtmTabs(Iterable<ParentMeeting> meetings, DateTime now) {
  final seen = <String>{};
  final all = <ParentMeeting>[];
  for (final m in meetings) {
    if (m.id.isNotEmpty && !seen.add(m.id)) continue;
    all.add(m);
  }
  final cancelled = <ParentMeeting>[], notCancelled = <ParentMeeting>[];
  for (final m in all) {
    (m.status == PtmStatus.cancelled ? cancelled : notCancelled).add(m);
  }
  // Reuse the Home agenda semantics for today / upcoming (isPtmToday, "Earlier today", UTC-midnight rule).
  final byId = {for (final m in notCancelled) m.id: m};
  final agenda = buildPtmAgenda([for (final m in notCancelled) m.toAgendaRow()], now);
  List<ParentMeeting> back(List<PtmMeeting> rows) => [for (final r in rows) if (byId[r.id] != null) byId[r.id]!];
  final today1 = back(agenda.remainingToday), today2 = back(agenda.earlierToday), ahead = back(agenda.upcoming);
  final placed = {for (final m in [...today1, ...today2, ...ahead]) m.id};
  final past = [for (final m in notCancelled) if (!placed.contains(m.id)) m];
  int byDateDesc(ParentMeeting a, ParentMeeting b) {
    final x = a.scheduledDate, y = b.scheduledDate;
    if (x == null && y == null) return 0;
    if (x == null) return 1;
    if (y == null) return -1;
    final c = y.compareTo(x);
    return c != 0 ? c : (parseHm(b.startTime) ?? 0).compareTo(parseHm(a.startTime) ?? 0);
  }

  past.sort(byDateDesc);
  cancelled.sort(byDateDesc);
  return PtmTabs(upcoming: ahead, todayRemaining: today1, todayEarlier: today2, past: past, cancelled: cancelled);
}

/// True for an open meeting whose day has passed (nobody recorded what happened).
bool isOverdueOpen(ParentMeeting m, DateTime now) {
  final d = m.day;
  if (d == null || !m.status.isOpen) return false;
  final t = DateTime(now.year, now.month, now.day);
  return d.isBefore(t);
}

/// The two windows the list loads (any status each): meetings from the start of today on, and meetings before it. The boundary is the
/// widest of the UTC day and the local day of [now] ([ptmTodayWindow]), so a meeting on today's date is never lost whatever the timezone.
({DateTime aheadFrom, DateTime pastTo}) ptmWindows(DateTime now) {
  final w = ptmTodayWindow(now);
  return (aheadFrom: w.from, pastTo: w.from.subtract(const Duration(milliseconds: 1)));
}

// ── validation (client side; the server validates nothing here: PC:43-47 takes the raw body) ─────────────

const int kPtmPointMax = 200;
const int kPtmMaxPoints = 10;
const int kPtmNotesMax = 4000;
const int kPtmActionDescriptionMax = 300;
const int kPtmActionAssigneeMax = 80;
const int kPtmReasonMax = 500;
const int kPtmMaxActionItems = 20;

/// null when [s] is a valid HH:mm; else the error.
String? validateHm(String? s, {required String label}) {
  if (s == null || s.trim().isEmpty) return 'Choose the $label time';
  final m = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(s.trim());
  if (m == null) return 'Use the 24-hour HH:mm format for the $label time';
  final h = int.parse(m.group(1)!), min = int.parse(m.group(2)!);
  if (h > 23 || min > 59) return 'The $label time is not a valid time';
  return null;
}

/// Time rules shared by create and reschedule: both times, end after start. [allowBothEmpty] (reschedule of a meeting that had no times).
Map<String, String> validatePtmTimes(String? start, String? end, {bool allowBothEmpty = false}) {
  final e = <String, String>{};
  final s = (start ?? '').trim(), n = (end ?? '').trim();
  if (allowBothEmpty && s.isEmpty && n.isEmpty) return e;
  final es = validateHm(s, label: 'start'), en = validateHm(n, label: 'end');
  if (es != null) e['start'] = es;
  if (en != null) e['end'] = en;
  if (es == null && en == null && parseHm(n)! <= parseHm(s)!) e['end'] = 'The end time must be after the start time';
  return e;
}

/// The day must be today or later (device calendar). Null day -> required.
String? validatePtmDay(DateTime? day, DateTime now) {
  if (day == null) return 'Choose a date';
  final d = DateTime(day.year, day.month, day.day), t = DateTime(now.year, now.month, now.day);
  return d.isBefore(t) ? 'Choose today or a later date' : null;
}

/// Outcome form validation. Notes optional (<= 4000), every non-blank action item needs a description.
Map<String, String> validateOutcome(PtmOutcomeRequest r) {
  final e = <String, String>{};
  if (r.meetingNotes.trim().length > kPtmNotesMax) e['notes'] = 'Notes can be at most $kPtmNotesMax characters';
  final items = r.actionItems.where((a) => !a.isBlank).toList();
  if (items.length > kPtmMaxActionItems) e['items'] = 'At most $kPtmMaxActionItems action items';
  for (var i = 0; i < items.length; i++) {
    final a = items[i];
    if (a.description.trim().isEmpty) {
      e['item$i'] = 'Describe this action item';
    } else if (a.description.trim().length > kPtmActionDescriptionMax) {
      e['item$i'] = 'At most $kPtmActionDescriptionMax characters';
    } else if (a.assignedTo.trim().length > kPtmActionAssigneeMax) {
      e['item$i'] = 'The name can be at most $kPtmActionAssigneeMax characters';
    }
  }
  return e;
}

/// Display line for a day + times: "Mon 5 Oct, 14:00 - 14:30".
String meetingWhen(ParentMeeting m, String Function(DateTime) dayText) {
  final d = m.day;
  final day = d == null ? 'Date not set' : dayText(d);
  return m.timeRange.isEmpty ? day : '$day, ${m.timeRange}';
}

/// Convenience for tests and screens: the `YYYY-MM-DD` that will be sent for a picked day.
String ptmWireDay(DateTime d) => wireDay(d);
