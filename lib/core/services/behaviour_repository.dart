import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../models/behaviour/behaviour_models.dart';
import '../models/json_helpers.dart';
import '../network/dio_exception_handler.dart';
import '../network/base_client.dart';

/// Behaviour & Tarbiyah (store B: `BehaviourRecord`, the one the parent app reads).
///
/// Backend: behaviour/behaviour.controller.ts:43-65,95-99 -> behaviour/behaviour.service.ts:170-207,319-334.
class BehaviourRepository {
  final BaseClient _client;
  BehaviourRepository([BaseClient? client]) : _client = client ?? BaseClient();

  static const int pageSize = 100;
  static const int maxPagesPerGrade = 2;

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw DioExceptionHandler.handle(e);
    }
  }

  /// Every record of the campus whose `grade` string is EXACTLY [rawGrade]: `GET /behaviour/records?grade=&limit=100&page=n`, newest first,
  /// at most [maxPagesPerGrade] pages (behaviour.service.ts:170-207). The route has NO section, class or reporter filter and does not
  /// scope to the caller's classes, so callers MUST re-scope the result with the tolerant class matcher ([ClassRef.containsRecord]).
  Future<List<BehaviourRecord>> fetchGradeRecords(String rawGrade) => _guard(() async {
        final out = <BehaviourRecord>[];
        for (var page = 1; page <= maxPagesPerGrade; page++) {
          final res = await _client.get(ApiConstants.behaviourRecords, queryParameters: {'grade': rawGrade, 'limit': pageSize, 'page': page});
          final p = BehaviourPage.fromJson(asJsonMap(res.data));
          out.addAll(p.records);
          if (page >= p.pages) break;
        }
        return out;
      });

  /// One student's records: `GET /behaviour/records?studentId=&limit=50` (newest first, server sort by date desc).
  Future<List<BehaviourRecord>> fetchStudentRecords(String studentId) => _guard(() async {
        final res = await _client.get(ApiConstants.behaviourRecords, queryParameters: {'studentId': studentId, 'limit': 50, 'page': 1});
        return BehaviourPage.fromJson(asJsonMap(res.data)).records.where((r) => r.studentId == studentId).toList();
      });

  /// `POST /behaviour/records` (behaviour.controller.ts:55-65 -> behaviour.service.ts:159-168). Body is `any` on the server (no DTO): the
  /// payload is exactly [BehaviourDraft.toJson]. A mongoose validation failure is a bare HTTP 500 there (no try/catch), so everything is
  /// validated before sending. Returns the created record (HTTP 201).
  Future<BehaviourRecord> create(Map<String, Object?> body) => _guard(() async {
        final res = await _client.post(ApiConstants.behaviourRecords, data: body);
        return BehaviourRecord.fromJson(asJsonMap(res.data));
      });

  /// `GET /behaviour/tarbiyah?studentId=&limit=20` (behaviour.controller.ts:95-99 -> :319-334), read-only.
  Future<List<TarbiyahAssessment>> fetchTarbiyah(String studentId) => _guard(() async {
        final res = await _client.get(ApiConstants.behaviourTarbiyah, queryParameters: {'studentId': studentId, 'limit': 20, 'page': 1});
        final body = asJsonMap(res.data);
        return asJsonMapList(body['data']).map(TarbiyahAssessment.fromJson).where((t) => t.studentId == studentId).toList();
      });
}
