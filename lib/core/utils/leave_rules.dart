import '../models/leave/leave_models.dart';
import '../models/json_helpers.dart';

const int kLeaveReasonMin = 10; // the web form requires >= 10 characters (my-leave/index.tsx `canSubmit`); the server has no rule
const int kLeaveReasonMax = 500; // app limit (no server limit exists, LA:20 is a plain string)
const int kLeaveMaxSpanDays = 366; // app sanity limit

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Calendar days from..to inclusive (the server's default count, `countLeaveDays` with excludeWeekends=false, leave-days.util.ts:46-48).
/// The school may count working days only (a policy flag the app cannot read), so this is a HINT, never what is submitted.
int spanDays(DateTime from, DateTime to) => DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays + 1;

class LeaveFormInput {
  final StaffLeaveType? type;
  final DateTime? from;
  final DateTime? to;
  final String reason;
  final bool halfDay;
  const LeaveFormInput({this.type, this.from, this.to, this.reason = '', this.halfDay = false});
}

/// Field -> message. Empty = valid. Rules: type chosen, both dates chosen, end on/after start, a half day is one day, a sane span, reason
/// 10..500 characters. Dates in the past are allowed (retrospective sick leave).
Map<String, String> validateLeave(LeaveFormInput i) {
  final e = <String, String>{};
  if (i.type == null) e['type'] = 'Choose a leave type';
  if (i.from == null) e['from'] = 'Choose the first day';
  if (i.to == null) e['to'] = 'Choose the last day';
  final f = i.from, t = i.to;
  if (f != null && t != null) {
    if (_day(t).isBefore(_day(f))) {
      e['to'] = 'The last day must be on or after the first day';
    } else if (i.halfDay && _day(t) != _day(f)) {
      e['to'] = 'A half day is a single day';
    } else if (spanDays(f, t) > kLeaveMaxSpanDays) {
      e['to'] = 'A request can span at most $kLeaveMaxSpanDays days';
    }
  }
  final r = i.reason.trim();
  if (r.isEmpty) {
    e['reason'] = 'Give a reason';
  } else if (r.length < kLeaveReasonMin) {
    e['reason'] = 'Please write at least $kLeaveReasonMin characters';
  } else if (r.length > kLeaveReasonMax) {
    e['reason'] = 'The reason can be at most $kLeaveReasonMax characters';
  }
  return e;
}

/// Live requests (pending / approved / on hold) whose days overlap [from]..[to]. Informational only: the server decides.
List<StaffLeaveRequest> overlapping(Iterable<StaffLeaveRequest> history, DateTime from, DateTime to) {
  final a = _day(from), b = _day(to);
  return [
    for (final h in history)
      if (h.status.isLive && h.firstDay != null && h.lastDay != null && !h.lastDay!.isBefore(a) && !h.firstDay!.isAfter(b)) h
  ];
}

/// Informational balance warning (the server decides, HS:1262 counts days itself): a message when the request clearly exceeds the remaining
/// days of a tracked type, else null. No warning without a policy (all zeros are not real balances) or for untracked types.
String? balanceWarning(LeaveBalanceSummary? b, StaffLeaveType? type, DateTime? from, DateTime? to, {required bool halfDay}) {
  if (b == null || type == null || !type.tracked || !b.hasPolicy || from == null || to == null) return null;
  final bucket = b.of(type);
  if (bucket == null) return null;
  final need = halfDay ? 0.5 : spanDays(from, to);
  if (need <= bucket.remaining) return null;
  return 'This is more than the ${_n(bucket.remaining)} ${type.label.toLowerCase()} day${bucket.remaining == 1 ? '' : 's'} you have left. You can still send it: the school decides.';
}

String _n(num v) => v == v.roundToDouble() ? v.round().toString() : v.toString();

/// "3 calendar days" / "Half day" hint under the dates.
String spanHint(DateTime? from, DateTime? to, {required bool halfDay}) {
  if (from == null || to == null || _day(to).isBefore(_day(from))) return 'The school calculates how many days are counted.';
  if (halfDay) return 'Half day. The school calculates how many days are counted.';
  final n = spanDays(from, to);
  return '$n calendar day${n == 1 ? '' : 's'} between these dates. The school calculates how many days are counted (it may leave out weekends).';
}

/// Convenience for tests: the `YYYY-MM-DD` that will be sent.
String leaveWireDay(DateTime d) => wireDay(d);
