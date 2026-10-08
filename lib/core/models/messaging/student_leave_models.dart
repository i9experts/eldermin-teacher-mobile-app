import '../json_helpers.dart';

enum LeaveStatus {
  pending('pending', 'Pending'),
  approved('approved', 'Approved'),
  rejected('rejected', 'Rejected');

  final String wire;
  final String label;
  const LeaveStatus(this.wire, this.label);

  /// Unknown values are treated as pending (the only state a teacher can act on is checked against the server anyway, SPS:354).
  static LeaveStatus parse(String? s) => values.firstWhere((e) => e.wire == s, orElse: () => LeaveStatus.pending);
}

/// A row of `GET /staff-portal/student-leaves` / the answer of `PATCH .../:id`: the raw `StudentLeave` document
/// (parent-portal/schemas/consent-and-leave.schema.ts:54-70 = CL): `_id, studentId, studentName, fromDate, toDate, reason,
/// leaveType(sick|family|travel|other), requestedByUserId, requestedByName, status, approverName?, approverNote?, approvedAt?,
/// schoolSlug, campusId, createdAt`. `requestedByName` is the guardian's name (names only; no contact data is in the document).
class StudentLeaveRequest {
  final String id;
  final String studentId;
  final String studentName;
  final DateTime? fromDate;
  final DateTime? toDate;
  final String reason;
  final String leaveType;
  final String requestedByName;
  final LeaveStatus status;
  final String approverName;
  final String approverNote;
  final DateTime? decidedAt;
  final DateTime? createdAt;

  const StudentLeaveRequest({
    required this.id,
    this.studentId = '',
    this.studentName = '',
    this.fromDate,
    this.toDate,
    this.reason = '',
    this.leaveType = 'other',
    this.requestedByName = '',
    this.status = LeaveStatus.pending,
    this.approverName = '',
    this.approverNote = '',
    this.decidedAt,
    this.createdAt,
  });

  factory StudentLeaveRequest.fromJson(Map<String, dynamic> j) => StudentLeaveRequest(
        id: readId(j['_id'] ?? j['id']) ?? '',
        studentId: readId(j['studentId']) ?? '',
        studentName: readText(j['studentName']),
        fromDate: readDate(j['fromDate']),
        toDate: readDate(j['toDate']),
        reason: readText(j['reason']),
        leaveType: readString(j['leaveType']) ?? 'other',
        requestedByName: readText(j['requestedByName']),
        status: LeaveStatus.parse(readString(j['status'])),
        approverName: readText(j['approverName']),
        approverNote: readText(j['approverNote']),
        decidedAt: readDate(j['approvedAt']),
        createdAt: readDate(j['createdAt']),
      );

  bool get isPending => status == LeaveStatus.pending;

  String get typeLabel => switch (leaveType) {
        'sick' => 'Sick leave',
        'family' => 'Family',
        'travel' => 'Travel',
        _ => 'Other',
      };

  /// The calendar days the parent asked for (the writer sends a date; Mongo keeps UTC midnight, so UTC components are the day,
  /// UNVERIFIED for clients that send a time of day).
  DateTime? get firstDay => storedCalendarDay(fromDate);
  DateTime? get lastDay => storedCalendarDay(toDate);

  int? get days {
    final a = firstDay, b = lastDay;
    if (a == null || b == null) return null;
    final n = DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays + 1;
    return n < 1 ? null : n;
  }
}

/// Max length of `remarks` (ReviewStudentLeaveDto, staff-portal.dto.ts:16).
const int kLeaveRemarksMax = 1000;
