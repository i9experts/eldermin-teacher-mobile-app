import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../models/behaviour/behaviour_models.dart';
import '../models/json_helpers.dart';
import '../network/dio_exception_handler.dart';
import '../network/base_client.dart';
import '../network/response_shape.dart';

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
          final body = expectMap(res.data, what: 'behaviour records');
          expectKeyRows(body, 'data', what: 'behaviour records');
          final p = BehaviourPage.fromJson(body);
          out.addAll(p.records);
          if (page >= p.pages) break;
        }
        return out;
      });

  /// One student's records: `GET /behaviour/records?studentId=&limit=50` (newest first, server sort by date desc).
  Future<List<BehaviourRecord>> fetchStudentRecords(String studentId) => _guard(() async {
        final res = await _client.get(ApiConstants.behaviourRecords, queryParameters: {'studentId': studentId, 'limit': 50, 'page': 1});
        final body = expectMap(res.data, what: 'behaviour records');
        expectKeyRows(body, 'data', what: 'behaviour records');
        return BehaviourPage.fromJson(body).records.where((r) => r.studentId == studentId).toList();
      });

  /// One page of `GET /behaviour/records` with the server-side filters (backend B1 adds `section` and `mine`; older servers ignore
  /// them, so callers re-check with [RecordFilters.accepts] / the class matcher). [grade] is matched EXACTLY by the server (raw
  /// variants), [section] tolerantly (a record WITHOUT a section is not returned for a `section` filter, so the app queries grade-wide
  /// and re-scopes with the shared section rule). Newest first. `meta.pages` says whether a next page exists.
  Future<BehaviourPage> fetchRecordsPage({
    String? grade,
    String? section,
    String? studentId,
    RecordFilters filters = RecordFilters.none,
    bool mine = false,
    int page = 1,
    int limit = pageSize,
  }) =>
      _guard(() async {
        final res = await _client.get(ApiConstants.behaviourRecords, queryParameters: {
          if (grade != null && grade.isNotEmpty) 'grade': grade,
          if (section != null && section.isNotEmpty) 'section': section,
          if (studentId != null && studentId.isNotEmpty) 'studentId': studentId,
          ...filters.toQuery(),
          if (mine) 'mine': 'true',
          'limit': limit,
          'page': page,
        });
        final body = expectMap(res.data, what: 'behaviour records');
        expectKeyRows(body, 'data', what: 'behaviour records');
        return BehaviourPage.fromJson(body);
      });

  /// `GET /behaviour/records/:id`: the whole record (staff see every field). 403 when it is outside my classes (enforce mode).
  Future<BehaviourRecord> fetchRecord(String id) => _guard(() async {
        final res = await _client.get(ApiConstants.behaviourRecord(id));
        return BehaviourRecord.fromJson(expectMap(res.data, what: 'this behaviour record'));
      });

  /// `PUT /behaviour/records/:id` (behaviour.controller.ts:68-78): a teacher may edit only records they logged (403 otherwise in
  /// enforce mode); `schoolSlug` / `campusId` / reporter fields are ignored. Returns the updated document.
  Future<BehaviourRecord> update(String id, Map<String, Object?> body) => _guard(() async {
        final res = await _client.put(ApiConstants.behaviourRecord(id), data: body);
        return BehaviourRecord.fromJson(expectMap(res.data, what: 'this behaviour record'));
      });

  /// `PATCH /behaviour/records/:id/resolve {note}` (behaviour.controller.ts:80-88): any record in my classes. Returns the updated record.
  Future<BehaviourRecord> resolve(String id, {String note = ''}) => _guard(() async {
        final res = await _client.patch(ApiConstants.behaviourRecordResolve(id), data: {'note': note.trim()});
        return BehaviourRecord.fromJson(expectMap(res.data, what: 'this behaviour record'));
      });

  /// `GET /behaviour/character-settings` (meta read, allowed for teachers): programme name and trait labels.
  Future<CharacterSettings> fetchCharacterSettings() => _guard(() async {
        final res = await _client.get(ApiConstants.behaviourCharacterSettings);
        return CharacterSettings.fromJson(expectMap(res.data, what: 'the character programme'));
      });

  /// `GET /behaviour/students/:id/profile` -> `pointsTotal` (all records of the student in the year filter, signed: + merit / - demerit).
  /// Null when the server does not answer with one.
  Future<int?> fetchPointsTotal(String studentId) => _guard(() async {
        final res = await _client.get(ApiConstants.behaviourStudentProfile(studentId));
        return readInt(expectMap(res.data, what: 'the behaviour summary')['pointsTotal']);
      });

  /// `POST /behaviour/records` (behaviour.controller.ts:55-65 -> behaviour.service.ts:159-168). Body is `any` on the server (no DTO): the
  /// payload is exactly [BehaviourDraft.toJson]. A mongoose validation failure is a bare HTTP 500 there (no try/catch), so everything is
  /// validated before sending. Returns the created record (HTTP 201).
  Future<BehaviourRecord> create(Map<String, Object?> body) => _guard(() async {
        final res = await _client.post(ApiConstants.behaviourRecords, data: body);
        return BehaviourRecord.fromJson(asJsonMap(res.data));
      });

  /// `POST /behaviour/tarbiyah` (behaviour.controller.ts createTarbiyah): a teacher may assess only students of their own classes (403 otherwise,
  /// checkTeacherStudent); one assessment per student and period (a duplicate is a server error). Returns the created assessment (201).
  Future<TarbiyahAssessment> createTarbiyah(Map<String, Object?> body) => _guard(() async {
        final res = await _client.post(ApiConstants.behaviourTarbiyah, data: body);
        return TarbiyahAssessment.fromJson(expectMap(res.data, what: 'this assessment'));
      });

  /// `PUT /behaviour/tarbiyah/:id` (updateTarbiyahAssessment): author, academic coordinator or admin only; a teacher who is not the author gets 403
  /// ("You can only edit Tarbiyah assessments you recorded yourself"). Returns the updated assessment.
  Future<TarbiyahAssessment> updateTarbiyah(String id, Map<String, Object?> body) => _guard(() async {
        final res = await _client.put('${ApiConstants.behaviourTarbiyah}/$id', data: body);
        return TarbiyahAssessment.fromJson(expectMap(res.data, what: 'this assessment'));
      });

  /// `GET /behaviour/tarbiyah?studentId=&limit=20` (behaviour.controller.ts:95-99 -> :319-334), read-only.
  Future<List<TarbiyahAssessment>> fetchTarbiyah(String studentId) => _guard(() async {
        final res = await _client.get(ApiConstants.behaviourTarbiyah, queryParameters: {'studentId': studentId, 'limit': 20, 'page': 1});
        final body = expectMap(res.data, what: 'Tarbiyah assessments');
        return expectKeyRows(body, 'data', what: 'Tarbiyah assessments').map(TarbiyahAssessment.fromJson).where((t) => t.studentId == studentId).toList();
      });
}
