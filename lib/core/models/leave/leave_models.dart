import '../json_helpers.dart';

/// Backend source cited as HC = `eldermin-backend/src/modules/hr/hr.controller.ts`, HS = `hr.service.ts`, LA = `schemas/leave-application.schema.ts`,
/// LB = `schemas/leave-balance.schema.ts` (branch feat/staff-portal, 265fcfa).

/// `LeaveApplication.leaveType` (LA:14), in the order of the web form (Eldermin-Frontend my-leave/index.tsx).
enum StaffLeaveType {
  annual('annual', 'Annual', true),
  sick('sick', 'Sick', true),
  casual('casual', 'Casual', true),
  maternity('maternity', 'Maternity', true),
  paternity('paternity', 'Paternity', true),
  hajj('hajj', 'Hajj', true),
  emergency('emergency', 'Emergency', false),
  unpaid('unpaid', 'Unpaid', false),
  study('study', 'Study', false),
  other('other', 'Other', false);

  final String wire;
  final String label;

  /// True for the six types that have an entitled/used/remaining counter in the balance (HS:1397-1409).
  final bool tracked;
  const StaffLeaveType(this.wire, this.label, this.tracked);

  static StaffLeaveType? parse(String? s) {
    for (final t in values) {
      if (t.wire == s) return t;
    }
    return null;
  }
}

/// Entitled / used / remaining for one type (`{ entitled, used, remaining }`, HS:1397-1409).
class LeaveBucket {
  final StaffLeaveType type;
  final num entitled;
  final num used;
  final num remaining;
  const LeaveBucket(this.type, this.entitled, this.used, this.remaining);
}

/// `GET /hr/leave/self/balance` (HC:241-243 -> HS:1430-1434 -> formatLeaveBalance HS:1397-1409): `{ staffId, staffName, employeeId, department,
/// annual|sick|casual|maternity|paternity|hajj: {entitled, used, remaining}, hasPolicy }`. `hasPolicy` is false when the staff member has NO
/// LeaveBalance document yet; the numbers are then all 0 and meaningless, so they are not shown as balances.
class LeaveBalanceSummary {
  final List<LeaveBucket> buckets;
  final bool hasPolicy;
  const LeaveBalanceSummary({this.buckets = const [], this.hasPolicy = true});

  factory LeaveBalanceSummary.fromJson(Map<String, dynamic> j) {
    final out = <LeaveBucket>[];
    for (final t in StaffLeaveType.values.where((t) => t.tracked)) {
      final b = j[t.wire];
      if (b is! Map) continue;
      final entitled = readNum(b['entitled']) ?? 0, used = readNum(b['used']) ?? 0;
      final remaining = readNum(b['remaining']) ?? (entitled - used);
      out.add(LeaveBucket(t, entitled, used, remaining));
    }
    return LeaveBalanceSummary(buckets: out, hasPolicy: readBool(j['hasPolicy'], fallback: true));
  }

  LeaveBucket? of(StaffLeaveType t) {
    for (final b in buckets) {
      if (b.type == t) return b;
    }
    return null;
  }

  /// Buckets worth a card: something entitled or already used.
  List<LeaveBucket> get shown => [for (final b in buckets) if (b.entitled != 0 || b.used != 0) b];
}

/// `LeaveApplication.status` (LA:24: pending|approved|rejected|cancelled|on_hold).
enum StaffLeaveStatus {
  pending('pending', 'Pending'),
  approved('approved', 'Approved'),
  rejected('rejected', 'Rejected'),
  cancelled('cancelled', 'Cancelled'),
  onHold('on_hold', 'On hold'),
  unknown('', 'Unknown');

  final String wire;
  final String label;
  const StaffLeaveStatus(this.wire, this.label);
  static StaffLeaveStatus parse(String? s) => values.firstWhere((e) => e.wire == s && e != unknown, orElse: () => unknown);

  /// Still counts against the calendar (for the overlap hint).
  bool get isLive => this == pending || this == approved || this == onHold;
}

/// A row of `GET /hr/leave/self/history` (HC:245-247 -> HS:1436-1439 -> getLeaveApplications HS:680-685, newest first). Consumed: `_id, leaveNo,
/// leaveType, fromDate, toDate, totalDays, isHalfDay, halfDaySession, reason, status, approverName, approvedAt, approverNote, rejectionReason,
/// createdAt`. NEVER parsed: `approvedBy` (the server populates it with the approver's profile and EMAIL, HS:684), staffId, workflowInstanceId.
class StaffLeaveRequest {
  final String id;
  final String leaveNo;
  final String typeWire;
  final DateTime? fromDate;
  final DateTime? toDate;
  final num? totalDays;
  final bool isHalfDay;
  final String halfDaySession;
  final String reason;
  final StaffLeaveStatus status;
  final String approverName;
  final DateTime? decidedAt;
  final String approverNote;
  final String rejectionReason;
  final DateTime? createdAt;

  const StaffLeaveRequest({
    required this.id,
    this.leaveNo = '',
    this.typeWire = '',
    this.fromDate,
    this.toDate,
    this.totalDays,
    this.isHalfDay = false,
    this.halfDaySession = '',
    this.reason = '',
    this.status = StaffLeaveStatus.unknown,
    this.approverName = '',
    this.decidedAt,
    this.approverNote = '',
    this.rejectionReason = '',
    this.createdAt,
  });

  factory StaffLeaveRequest.fromJson(Map<String, dynamic> j) => StaffLeaveRequest(
        id: readId(j['_id'] ?? j['id']) ?? '',
        leaveNo: readText(j['leaveNo']),
        typeWire: readText(j['leaveType']),
        fromDate: readDate(j['fromDate']),
        toDate: readDate(j['toDate']),
        totalDays: readNum(j['totalDays']),
        isHalfDay: readBool(j['isHalfDay']),
        halfDaySession: readText(j['halfDaySession']),
        reason: readText(j['reason']),
        status: StaffLeaveStatus.parse(readString(j['status'])),
        approverName: readText(j['approverName']),
        decidedAt: readDate(j['approvedAt']),
        approverNote: readText(j['approverNote']),
        rejectionReason: readText(j['rejectionReason']),
        createdAt: readDate(j['createdAt']),
      );

  String get typeLabel => StaffLeaveType.parse(typeWire)?.label ?? (typeWire.isEmpty ? 'Leave' : typeWire);
  DateTime? get firstDay => storedCalendarDay(fromDate);
  DateTime? get lastDay => storedCalendarDay(toDate);
}

/// Body of `POST /hr/leave/self` (HC:249-253 -> HS:1441-1455 -> createLeaveApplication HS:1248-1268). The service takes the raw body (no DTO),
/// strips identity/approval fields (leave-self.util.ts:44-52) and sets staffId/staffName/... from the caller's own Staff record. `totalDays` is
/// always recomputed by the server (HS:1262), so it is NOT sent (the web sends one that is ignored). Required by the schema: leaveType, fromDate,
/// toDate, reason. `isHalfDay` / `halfDaySession` (morning|afternoon) are stored as sent (LA:18-19).
class StaffLeaveRequestBody {
  final StaffLeaveType type;
  final DateTime from;
  final DateTime to;
  final String reason;
  final bool halfDay;
  final String halfDaySession;
  const StaffLeaveRequestBody({required this.type, required this.from, required this.to, required this.reason, this.halfDay = false, this.halfDaySession = 'morning'});

  Map<String, dynamic> toJson() => {
        'leaveType': type.wire,
        'fromDate': wireDay(from),
        'toDate': wireDay(to),
        'reason': reason.trim(),
        'isHalfDay': halfDay,
        if (halfDay) 'halfDaySession': halfDaySession,
      };
}
