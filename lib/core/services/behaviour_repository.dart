import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../models/behaviour/behaviour_models.dart';
import '../models/json_helpers.dart';
import '../network/dio_exception_handler.dart';
import '../network/base_client.dart';
import '../utils/roster_scope.dart';

/// Behaviour & Tarbiyah (store B: `BehaviourRecord`, the one the parent app reads).
///
/// Backend: behaviour/behaviour.controller.ts:43-65,95-99 -> behaviour/behaviour.service.ts:154-193,319-334.
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

  /// Records of the students of [cls]: `GET /behaviour/records?grade=<raw variant>&limit=100&page=n` once per raw grade string that
  /// normalises to the class (the `grade` filter is an EXACT string match and there is NO section / reporter / class filter,
  /// behaviour.service.ts:154-193), then re-scoped client-side with the tolerant class matcher so nothing about other classes
  /// is ever returned. Newest first. [grades] = the raw variants (from [queryVariants]).
  Future<List<BehaviourRecord>> fetchClassRecords(ClassRef cls, {required List<String> grades}) => _guard(() async {
        final seen = <String>{};
        final out = <BehaviourRecord>[];
        for (final g in grades) {
          for (var page = 1; page <= maxPagesPerGrade; page++) {
            final res = await _client.get(ApiConstants.behaviourRecords, queryParameters: {'grade': g, 'limit': pageSize, 'page': page});
            final p = BehaviourPage.fromJson(asJsonMap(res.data));
            for (final r in p.records) {
              if (r.id.isNotEmpty && cls.containsRecord(r) && seen.add(r.id)) out.add(r);
            }
            if (page >= p.pages) break;
          }
        }
        out.sort((a, b) => (b.day ?? DateTime(0)).compareTo(a.day ?? DateTime(0)));
        return out;
      });

  /// One student's records: `GET /behaviour/records?studentId=&limit=50` (newest first, server sort by date desc).
  Future<List<BehaviourRecord>> fetchStudentRecords(String studentId) => _guard(() async {
        final res = await _client.get(ApiConstants.behaviourRecords, queryParameters: {'studentId': studentId, 'limit': 50, 'page': 1});
        return BehaviourPage.fromJson(asJsonMap(res.data)).records.where((r) => r.studentId == studentId).toList();
      });

  /// `POST /behaviour/records` (behaviour.controller.ts:55-65 -> behaviour.service.ts:155-165). Body is `any` on the server (no DTO): the
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
