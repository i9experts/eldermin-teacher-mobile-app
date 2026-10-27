import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../models/attendance/self_attendance_models.dart';
import '../network/api_exception.dart';
import '../network/base_client.dart';
import '../network/dio_exception_handler.dart';
import '../network/response_shape.dart';

/// The login has no Staff record: `404 'No staff record is linked to your account. Contact HR ...'` (hr.service.ts getOwnStaffRecord). A typed
/// state, NOT a generic "not available": the screen explains it plainly. Still an [ApiException] (404) for code that only knows those.
class NoStaffRecord extends ApiException {
  NoStaffRecord([String message = "Your account isn't linked to a staff record yet. Ask your school admin to link it."]) : super(message, statusCode: 404);
}

/// True for the server's 404 text of a missing Staff link (other 404s, such as an undeployed route, are not).
bool isNoStaffRecordMessage(String message) => RegExp(r'staff record', caseSensitive: false).hasMatch(message);

/// My attendance (teacher self-service, permission `attendance:self`; `hr.controller.ts:321-333`). The server resolves "me" from the login: no
/// staff id is ever sent.
class SelfAttendanceRepository {
  final BaseClient _client;
  SelfAttendanceRepository([BaseClient? client]) : _client = client ?? BaseClient();

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      final ex = DioExceptionHandler.handle(e);
      if (ex.statusCode == 404 && isNoStaffRecordMessage(ex.message)) throw NoStaffRecord();
      throw ex;
    }
  }

  /// `GET /hr/attendance/self?month=<1-12>&year=<yyyy>`: bare array (no pagination), newest day first. Rows without a readable day are dropped.
  Future<List<StaffAttendanceDay>> fetchMonth(int month, int year) => _guard(() async {
        final res = await _client.get(ApiConstants.attendanceSelf, queryParameters: {'month': month, 'year': year});
        final rows = expectRows(res.data, what: 'your attendance').map(StaffAttendanceDay.fromJson).where((d) => d.day != null).toList();
        rows.sort((a, b) => b.day!.compareTo(a.day!));
        return rows;
      });

  /// `GET /hr/attendance/self/correction-requests`: bare array, newest first.
  Future<List<AttendanceCorrectionRequest>> listCorrections() => _guard(() async {
        final res = await _client.get(ApiConstants.attendanceSelfCorrections);
        return expectRows(res.data, what: 'your correction requests').map(AttendanceCorrectionRequest.fromJson).where((r) => r.id.isNotEmpty).toList();
      });

  /// `POST /hr/attendance/self/correction-requests` (201): the created request (status `pending`).
  Future<AttendanceCorrectionRequest> submitCorrection(AttendanceCorrectionBody body) => _guard(() async {
        final res = await _client.post(ApiConstants.attendanceSelfCorrections, data: body.toJson());
        final r = AttendanceCorrectionRequest.fromJson(expectMap(res.data, what: 'your correction request'));
        if (r.id.isEmpty) throw UnexpectedResponseShape('your correction request', '_id missing');
        return r;
      });
}
