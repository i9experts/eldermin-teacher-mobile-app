import '../json_helpers.dart';

/// Backend source cited from `eldermin-backend/src/modules/hr/`: `hr.controller.ts:321-333`, `hr.service.ts` getMyAttendance / getStaffAttendance /
/// createMyAttendanceCorrectionRequest, `schemas/staff-attendance.schema.ts`, `schemas/attendance-correction-request.schema.ts`,
/// `dto/self-attendance-correction.dto.ts` (main 8247bd9).

/// `StaffAttendance.status` (a record may carry any of the ten) and `AttendanceCorrectionRequest.requestedStatus` (only the first eight).
/// A value the app does not know parses to [unknown] and renders neutrally, never crashes.
enum StaffDayStatus {
  present('present', 'Present', true),
  absent('absent', 'Absent', true),
  late('late', 'Late', true),
  halfDay('half_day', 'Half day', true),
  onLeave('on_leave', 'On leave', true),
  sickLeave('sick_leave', 'Sick leave', true),
  remote('remote', 'Remote', true),
  extraDay('extra_day', 'Extra day', true),
  holiday('holiday', 'Holiday', false),
  weekend('weekend', 'Weekend', false),
  unknown('', 'Other', false);

  final String wire;
  final String label;

  /// May be REQUESTED in a correction (`ATTENDANCE_CORRECTION_STATUSES`; holiday and weekend are rejected by the DTO).
  final bool requestable;
  const StaffDayStatus(this.wire, this.label, this.requestable);

  static StaffDayStatus parse(String? s) => values.firstWhere((e) => e.wire == s && e != unknown, orElse: () => unknown);

  /// The eight statuses a teacher may ask for, in display order.
  static List<StaffDayStatus> get requestableValues => [for (final v in values) if (v.requestable) v];
}

/// `AttendanceCorrectionRequest.status`.
enum CorrectionStatus {
  pending('pending', 'Pending'),
  approved('approved', 'Approved'),
  rejected('rejected', 'Rejected'),
  unknown('', 'Unknown');

  final String wire;
  final String label;
  const CorrectionStatus(this.wire, this.label);
  static CorrectionStatus parse(String? s) => values.firstWhere((e) => e.wire == s && e != unknown, orElse: () => unknown);
}

/// The label of a status wire value the server sent: the known label, else the raw text made readable (never empty for a non-empty wire).
String statusText(StaffDayStatus s, String wire) {
  if (s != StaffDayStatus.unknown) return s.label;
  final w = wire.trim().replaceAll('_', ' ');
  return w.isEmpty ? 'Not recorded' : w[0].toUpperCase() + w.substring(1);
}

/// One row of `GET /hr/attendance/self?month=&year=` (bare array, newest first). `date` is stored at UTC midnight of the calendar day it was
/// written for, so [day] reads the UTC components (a local-time reading would shift a day west of UTC). NEVER read: `staffId` (the server populates
/// it with the staff profile).
class StaffAttendanceDay {
  final String id;

  /// The calendar day (local-midnight DateTime of the stored UTC y/m/d); null when the server sent no readable date.
  final DateTime? day;
  final StaffDayStatus status;
  final String statusWire;
  final String checkIn;
  final String checkOut;
  final num? lateByMins;
  final num? workingHours;
  final String notes;
  final String source;

  const StaffAttendanceDay({
    this.id = '',
    this.day,
    this.status = StaffDayStatus.unknown,
    this.statusWire = '',
    this.checkIn = '',
    this.checkOut = '',
    this.lateByMins,
    this.workingHours,
    this.notes = '',
    this.source = '',
  });

  factory StaffAttendanceDay.fromJson(Map<String, dynamic> j) {
    final wire = readText(j['status']);
    return StaffAttendanceDay(
      id: readId(j['_id'] ?? j['id']) ?? '',
      day: storedCalendarDay(readDate(j['date'])),
      status: StaffDayStatus.parse(wire),
      statusWire: wire,
      checkIn: readText(j['checkInTime']),
      checkOut: readText(j['checkOutTime']),
      lateByMins: readNum(j['lateByMins']),
      workingHours: readNum(j['workingHours']),
      notes: readText(j['notes']),
      source: readText(j['source']),
    );
  }

  String get statusLabel => statusText(status, statusWire);
}

/// A row of `GET /hr/attendance/self/correction-requests` (bare array, newest first). NEVER read: staffId / reviewedBy (ids).
class AttendanceCorrectionRequest {
  final String id;
  final DateTime? day;
  final StaffDayStatus currentStatus;
  final String currentStatusWire;
  final String currentCheckIn;
  final String currentCheckOut;
  final StaffDayStatus requestedStatus;
  final String requestedStatusWire;
  final String requestedCheckIn;
  final String requestedCheckOut;
  final String reason;
  final CorrectionStatus status;
  final String reviewerName;
  final DateTime? reviewedAt;
  final String reviewNotes;
  final DateTime? createdAt;

  const AttendanceCorrectionRequest({
    required this.id,
    this.day,
    this.currentStatus = StaffDayStatus.unknown,
    this.currentStatusWire = '',
    this.currentCheckIn = '',
    this.currentCheckOut = '',
    this.requestedStatus = StaffDayStatus.unknown,
    this.requestedStatusWire = '',
    this.requestedCheckIn = '',
    this.requestedCheckOut = '',
    this.reason = '',
    this.status = CorrectionStatus.unknown,
    this.reviewerName = '',
    this.reviewedAt,
    this.reviewNotes = '',
    this.createdAt,
  });

  factory AttendanceCorrectionRequest.fromJson(Map<String, dynamic> j) {
    final cur = readText(j['currentStatus']), req = readText(j['requestedStatus']);
    return AttendanceCorrectionRequest(
      id: readId(j['_id'] ?? j['id']) ?? '',
      day: storedCalendarDay(readDate(j['attendanceDate'])),
      currentStatus: StaffDayStatus.parse(cur),
      currentStatusWire: cur,
      currentCheckIn: readText(j['currentCheckInTime']),
      currentCheckOut: readText(j['currentCheckOutTime']),
      requestedStatus: StaffDayStatus.parse(req),
      requestedStatusWire: req,
      requestedCheckIn: readText(j['requestedCheckInTime']),
      requestedCheckOut: readText(j['requestedCheckOutTime']),
      reason: readText(j['reason']),
      status: CorrectionStatus.parse(readString(j['status'])),
      reviewerName: readText(j['reviewerName']),
      reviewedAt: readDate(j['reviewedAt']),
      reviewNotes: readText(j['reviewNotes']),
      createdAt: readDate(j['createdAt']),
    );
  }

  /// "Not recorded" when the server had no record for that day (a fully missed punch).
  String get currentLabel => currentStatusWire.isEmpty ? 'No record' : statusText(currentStatus, currentStatusWire);
  String get requestedLabel => statusText(requestedStatus, requestedStatusWire);
}

/// Body of `POST /hr/attendance/self/correction-requests` (`CreateSelfAttendanceCorrectionDto`): `attendanceDate` `YYYY-MM-DD`, `requestedStatus`
/// one of the eight [StaffDayStatus.requestable], optional `requestedCheckInTime` / `requestedCheckOutTime` (plain strings; the web sends `HH:mm`),
/// `reason` 1-2000 (trimmed server-side). Identity, snapshot and review fields are stripped by the server and never sent.
class AttendanceCorrectionBody {
  final DateTime date;
  final StaffDayStatus status;
  final String? checkIn;
  final String? checkOut;
  final String reason;
  const AttendanceCorrectionBody({required this.date, required this.status, this.checkIn, this.checkOut, required this.reason});

  Map<String, dynamic> toJson() => {
        'attendanceDate': wireDay(date),
        'requestedStatus': status.wire,
        if (checkIn != null && checkIn!.isNotEmpty) 'requestedCheckInTime': checkIn,
        if (checkOut != null && checkOut!.isNotEmpty) 'requestedCheckOutTime': checkOut,
        'reason': reason.trim(),
      };
}
