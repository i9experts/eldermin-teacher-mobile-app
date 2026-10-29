import 'package:eldermin_teacher_app/core/models/attendance/self_attendance_models.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/services/self_attendance_repository.dart';

/// A day record built the way the server sends it.
StaffAttendanceDay dayRow(String day, {String status = 'present', String? checkIn, String? checkOut, int? late, String notes = ''}) => StaffAttendanceDay.fromJson({
      '_id': 'd$day',
      'date': '${day}T00:00:00.000Z',
      'status': status,
      if (checkIn != null) 'checkInTime': checkIn,
      if (checkOut != null) 'checkOutTime': checkOut,
      if (late != null) 'lateByMins': late,
      if (notes.isNotEmpty) 'notes': notes,
    });

AttendanceCorrectionRequest corrRow(String id,
        {String day = '2026-10-03',
        String status = 'pending',
        String requested = 'present',
        String? current,
        String reason = 'The biometric reader was down all morning.',
        String reviewer = '',
        String notes = ''}) =>
    AttendanceCorrectionRequest.fromJson({
      '_id': id,
      'attendanceDate': '${day}T00:00:00.000Z',
      if (current != null) 'currentStatus': current,
      'requestedStatus': requested,
      'reason': reason,
      'status': status,
      if (reviewer.isNotEmpty) 'reviewerName': reviewer,
      if (reviewer.isNotEmpty) 'reviewedAt': '2026-10-04T09:00:00.000Z',
      if (notes.isNotEmpty) 'reviewNotes': notes,
      'createdAt': '2026-10-05T06:00:00.000Z',
    });

class FakeSelfAttendanceRepository extends SelfAttendanceRepository {
  Future<List<StaffAttendanceDay>> Function(int month, int year) month = (m, y) async => [];
  Future<List<AttendanceCorrectionRequest>> Function() corrections = () async => [];
  Future<AttendanceCorrectionRequest> Function(AttendanceCorrectionBody b) submit0 = (b) async => corrRow('new1', requested: b.status.wire);
  final calls = <String>[];
  final monthCalls = <(int, int)>[];
  AttendanceCorrectionBody? lastSubmit;
  int submitCount = 0;

  @override
  Future<List<StaffAttendanceDay>> fetchMonth(int m, int y) {
    calls.add('month');
    monthCalls.add((m, y));
    return month(m, y);
  }

  @override
  Future<List<AttendanceCorrectionRequest>> listCorrections() {
    calls.add('corrections');
    return corrections();
  }

  @override
  Future<AttendanceCorrectionRequest> submitCorrection(AttendanceCorrectionBody body) {
    calls.add('submit');
    submitCount++;
    lastSubmit = body;
    return submit0(body);
  }
}

Never failSelf(int? status, [String message = 'error']) => throw ApiException(message, statusCode: status);
Never failNoStaff() => throw NoStaffRecord();
