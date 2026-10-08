import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../models/leave/leave_models.dart';
import '../network/base_client.dart';
import '../network/dio_exception_handler.dart';
import '../network/response_shape.dart';

/// Phase 7b: My leave (teacher self-service, permission `leave:self`; eldermin-backend `src/modules/hr/hr.controller.ts` = HC, `hr.service.ts` =
/// HS, branch feat/staff-portal 265fcfa). The server resolves "me" from the login (HS:1424-1428): no staff id is ever sent.
class LeaveRepository {
  final BaseClient _client;
  LeaveRepository([BaseClient? client]) : _client = client ?? BaseClient();

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw DioExceptionHandler.handle(e);
    }
  }

  /// `GET /hr/leave/self/balance` (HC:241-243 -> HS:1430-1434): one object. 404 'No staff record is linked to your account...' (HS:1426).
  Future<LeaveBalanceSummary> fetchBalance() => _guard(() async {
        final res = await _client.get(ApiConstants.leaveSelfBalance);
        return LeaveBalanceSummary.fromJson(expectMap(res.data, what: 'your leave balance'));
      });

  /// `GET /hr/leave/self/history` (HC:245-247 -> HS:1436-1439): bare array, newest first, no limit.
  Future<List<StaffLeaveRequest>> fetchHistory() => _guard(() async {
        final res = await _client.get(ApiConstants.leaveSelfHistory);
        return expectRows(res.data, what: 'your leave requests').map(StaffLeaveRequest.fromJson).where((l) => l.id.isNotEmpty).toList();
      });

  /// `POST /hr/leave/self` (HC:249-253 -> HS:1441-1455, 201): the created application (status `pending`). Invalid bodies are NOT validated by a
  /// DTO: a Mongoose validation error (bad leaveType, missing reason ...) is what the server answers (status UNVERIFIED, probably 400/500).
  Future<StaffLeaveRequest> apply(StaffLeaveRequestBody body) => _guard(() async {
        final res = await _client.post(ApiConstants.leaveSelfApply, data: body.toJson());
        final l = StaffLeaveRequest.fromJson(expectMap(res.data, what: 'your leave request'));
        if (l.id.isEmpty) throw UnexpectedResponseShape('your leave request', '_id missing');
        return l;
      });
}
