import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../models/safeguarding/safeguarding_models.dart';
import '../network/base_client.dart';
import '../network/dio_exception_handler.dart';

/// `POST /compliance/safeguarding` (compliance.controller.ts:112-118, `safeguarding:report`; 201). WRITE ONLY: there is deliberately no read method here.
/// The body is built by [SafeguardingReport.toRequestBody] (an allow-list); this class sends exactly what it is given and logs nothing of it.
class SafeguardingRepository {
  final BaseClient _client;
  SafeguardingRepository([BaseClient? client]) : _client = client ?? BaseClient();

  Future<SafeguardingReceipt> submit(SafeguardingReport report) async {
    try {
      final res = await _client.post(ApiConstants.safeguarding, data: report.toRequestBody());
      return SafeguardingReceipt.fromResponse(res.data);
    } on DioException catch (e) {
      throw DioExceptionHandler.handle(e);
    }
  }
}
