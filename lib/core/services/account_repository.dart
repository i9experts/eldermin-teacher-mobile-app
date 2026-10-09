import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../models/json_helpers.dart';
import '../network/base_client.dart';
import '../network/dio_exception_handler.dart';
import '../network/response_shape.dart';

/// Answer of `POST /staff-portal/account/delete-request` (staff-portal.service.ts:410-436, 201): `{ requestId, status: 'pending', alreadyRequested?: true,
/// message? }`. `message` is sent only for a NEW request ('Your request was sent to the school administration. Your records are retained until they
/// process it.'); `alreadyRequested: true` (and no message) when a pending request exists (:415-416).
class DeletionRequestResult {
  final String requestId;
  final String status;
  final bool alreadyRequested;
  final String? message;
  const DeletionRequestResult({required this.requestId, required this.status, required this.alreadyRequested, this.message});

  factory DeletionRequestResult.fromJson(Map<String, dynamic> j) => DeletionRequestResult(
        requestId: readString(j['requestId']) ?? '',
        status: readString(j['status']) ?? 'pending',
        alreadyRequested: j['alreadyRequested'] == true,
        message: readString(j['message']),
      );
}

/// Account deletion REQUEST (never an instant deletion: "never hard-deletes", staff-portal.service.ts:408).
class AccountRepository {
  final BaseClient _client;
  AccountRepository([BaseClient? client]) : _client = client ?? BaseClient();

  /// Body = `AccountDeleteRequestDto` (dto/staff-portal.dto.ts:30-33): `confirm` (boolean, REQUIRED) and optional `reason` (string, @MaxLength(1000)). A missing
  /// `confirm` is 400 'Please confirm the request.' (service :411). Requires the teacher role + a linked Staff record (requireStaff).
  Future<DeletionRequestResult> request({String? reason}) async {
    try {
      final r = reason?.trim() ?? '';
      final res = await _client.post(ApiConstants.accountDeleteRequest, data: {'confirm': true, if (r.isNotEmpty) 'reason': r});
      return DeletionRequestResult.fromJson(expectMap(res.data, what: 'your request'));
    } on DioException catch (e) {
      throw DioExceptionHandler.handle(e);
    }
  }
}

/// The reason limit of the DTO.
const int kDeleteReasonMax = 1000;
