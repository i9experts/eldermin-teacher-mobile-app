import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../models/academic/lesson_plan_models.dart';
import '../models/json_helpers.dart';
import '../network/api_exception.dart';
import '../network/base_client.dart';
import '../network/response_shape.dart';
import '../network/dio_exception_handler.dart';

/// Lesson plans: list mine, create, patch (draft edits and submit), and the AI-assisted parse-upload.
///
/// Backend (paths relative to eldermin-backend/src/, branch feat/staff-portal HEAD 62db9f8): modules/teaching/teaching.controller.ts:59-82
/// -> teaching.service.ts:151-207 (list/create/update), :294-379 (parse). Errors surface as [ApiException]; the server body is the real
/// `{statusCode, message, timestamp, path}` (filters/sentry.filter.ts:43-48).
class LessonPlanRepository {
  final BaseClient _client;
  LessonPlanRepository([BaseClient? client]) : _client = client ?? BaseClient();

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw DioExceptionHandler.handle(e);
    }
  }

  static List<Map<String, dynamic>> _rows(Object? data) => expectRows(data, what: 'lesson plans');

  /// `GET /teaching/lesson-plans?teacherId=<id>` for every id in [teacherIds] (my Staff id, plus my TeacherProfile id: the web writes
  /// plans with the profile id and the backend tolerates both, teaching.service.ts:381-392; real data UNVERIFIED), merged by `_id`,
  /// re-filtered to those ids (the unfiltered endpoint returns every teacher's, :151-162), newest plan date first. Hard limit 100 per
  /// request, no pagination.
  Future<List<LessonPlanRecord>> fetchMine(Iterable<String> teacherIds) => _guard(() async {
        final ids = teacherIds.where((e) => e.isNotEmpty).toSet();
        final byId = <String, LessonPlanRecord>{};
        for (final id in ids) {
          final res = await _client.get(ApiConstants.lessonPlans, queryParameters: {'teacherId': id});
          for (final p in _rows(res.data).map(LessonPlanRecord.fromJson)) {
            if (p.id.isNotEmpty && ids.contains(p.teacherId)) byId[p.id] = p;
          }
        }
        final out = byId.values.toList()
          ..sort((a, b) => (b.planDate ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(a.planDate ?? DateTime.fromMillisecondsSinceEpoch(0)));
        return out;
      });

  /// Number of rows one request can return at most (the server's hard `limit(100)`).
  static const int serverLimit = 100;

  /// `POST /teaching/lesson-plans` (teaching.controller.ts:62-64). Returns the created document (201).
  Future<LessonPlanRecord> create(Map<String, Object?> body) => _guard(() async {
        final res = await _client.post(ApiConstants.lessonPlans, data: body);
        final p = LessonPlanRecord.fromJson(asJsonMap(res.data));
        if (p.id.isEmpty) throw ApiException('The server saved the plan but sent nothing back. Pull to refresh to see it.');
        return p;
      });

  /// `PATCH /teaching/lesson-plans/:id` (teaching.controller.ts:80-82) with ONLY the changed fields (raw `$set`). For a teacher an
  /// unknown id answers HTTP 200 with an EMPTY body (the service returns null, teaching.service.ts:195): treated as "not found".
  Future<LessonPlanRecord> update(String id, Map<String, Object?> patch) => _guard(() async {
        final res = await _client.patch(ApiConstants.lessonPlan(id), data: patch);
        final p = LessonPlanRecord.fromJson(asJsonMap(res.data));
        if (p.id.isEmpty) throw ApiException('This lesson plan was not found on the server. It may have been removed.', statusCode: 404);
        return p;
      });

  /// `POST /teaching/lesson-plans/parse-upload` multipart: field `file` (<= 10 MB; .docx .xlsx .xls .csv .txt) and/or text field
  /// `sourceUrl` (a Google Doc link). Needs the backend's Claude key (500 'AI assistance is not configured on this server.' otherwise).
  /// Never saves a plan.
  Future<LessonPlanDraft> parseUpload({String? path, String? fileName, String? sourceUrl, void Function(int sent, int total)? onProgress}) => _guard(() async {
        final files = <String, List<MultipartFile>>{};
        if (path != null && fileName != null) {
          files['file'] = [await MultipartFile.fromFile(path, filename: fileName)];
        }
        final link = sourceUrl?.trim() ?? '';
        final res = await _client.multipart(
          ApiConstants.lessonPlanParseUpload,
          files: files,
          fields: {if (link.isNotEmpty && files.isEmpty) 'sourceUrl': link},
          onSendProgress: onProgress,
        );
        return LessonPlanDraft.fromJson(asJsonMap(res.data));
      });
}
