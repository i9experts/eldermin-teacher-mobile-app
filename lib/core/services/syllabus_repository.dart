import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../models/academic/syllabus_models.dart';
import '../models/json_helpers.dart';
import '../network/api_exception.dart';
import '../network/base_client.dart';
import '../network/response_shape.dart';
import '../network/dio_exception_handler.dart';

/// Syllabus tracking: list, one, mark topic / sub-topic, weekly planner.
///
/// Backend (paths relative to eldermin-backend/src/syllabus/): syllabus.controller.ts:34-37,106-114,139-149 -> syllabus.service.ts:95-116,
/// 262-293,301-332,524-544. NOT used on purpose: PATCH :id/behind-schedule (no guard, a coordinator judgement), :id/lessons POST/PATCH/DELETE,
/// :id/publish, :id/approve, PUT/DELETE :id. There is NO `GET /syllabus/behind-schedule` and NO `GET /syllabus/:id/lessons`: lessons are
/// nested in `units[].topics[].lessons[]` of the syllabus document.
class SyllabusRepository {
  final BaseClient _client;
  SyllabusRepository([BaseClient? client]) : _client = client ?? BaseClient();

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw DioExceptionHandler.handle(e);
    }
  }

  static List<Map<String, dynamic>> _rows(Object? data, String what) => expectRows(data, what: what);

  /// `GET /syllabus` with [query] (any of `teacherId` (MongoId), `gradeLevel`, `sectionName`, `subjectName`, `academicYearLabel`,
  /// `term`, `status`, `trackStatus`: SyllabusQueryDto, syllabus.dto.ts:152-161). Bare array of FULL documents, no pagination.
  Future<List<Syllabus>> list(Map<String, String> query) => _guard(() async {
        final res = await _client.get(ApiConstants.syllabus, queryParameters: query);
        return _rows(res.data, 'the syllabus').map(Syllabus.fromJson).where((s) => s.id.isNotEmpty).toList();
      });

  /// `GET /syllabus/:id` (tenant check only: no campus / owner check, syllabus.service.ts:112-116).
  Future<Syllabus> one(String id) => _guard(() async {
        final res = await _client.get(ApiConstants.syllabusById(id));
        final s = Syllabus.fromJson(expectMap(res.data, what: 'this syllabus'));
        if (s.id.isEmpty) throw ApiException('Syllabus not found', statusCode: 404);
        return s;
      });

  /// `PATCH /syllabus/:id/mark-topic` { unitNo, topicNo, isCovered, coveredBy? } (MarkTopicDto, syllabus.dto.ts:93-100). Returns the whole
  /// saved syllabus with the re-rolled totals.
  Future<Syllabus> markTopic(String id, {required int unitNo, required int topicNo, required bool covered, String? coveredBy}) => _guard(() async {
        final res = await _client.patch(ApiConstants.syllabusMarkTopic(id), data: {
          'unitNo': unitNo,
          'topicNo': topicNo,
          'isCovered': covered,
          if (coveredBy != null && coveredBy.isNotEmpty) 'coveredBy': coveredBy,
        });
        return _saved(res.data);
      });

  /// `PATCH /syllabus/:id/mark-sub-topic` { unitNo, topicNo, subTopicNo, isCovered, coveredBy? } (MarkSubTopicDto, syllabus.dto.ts:102-109).
  Future<Syllabus> markSubTopic(String id, {required int unitNo, required int topicNo, required int subTopicNo, required bool covered, String? coveredBy}) => _guard(() async {
        final res = await _client.patch(ApiConstants.syllabusMarkSubTopic(id), data: {
          'unitNo': unitNo,
          'topicNo': topicNo,
          'subTopicNo': subTopicNo,
          'isCovered': covered,
          if (coveredBy != null && coveredBy.isNotEmpty) 'coveredBy': coveredBy,
        });
        return _saved(res.data);
      });

  Syllabus _saved(Object? data) {
    final s = Syllabus.fromJson(asJsonMap(data));
    if (s.id.isEmpty) throw ApiException('The server saved the change but sent nothing back. Pull to refresh.');
    return s;
  }

  /// `GET /syllabus/weekly-planner?teacherId=<id>` for each id (Staff id; the TeacherProfile id too, UNVERIFIED which one real data
  /// holds), merged by syllabus. Current week only, per syllabus (syllabus.service.ts:301-332).
  Future<List<PlannerEntry>> weeklyPlanner(Iterable<String> teacherIds) => _guard(() async {
        final byId = <String, PlannerEntry>{};
        for (final id in teacherIds.where((e) => e.isNotEmpty).toSet()) {
          final res = await _client.get(ApiConstants.syllabusWeeklyPlanner, queryParameters: {'teacherId': id});
          for (final e in _rows(res.data, 'the weekly planner').map(PlannerEntry.fromJson)) {
            if (e.syllabusId.isNotEmpty) byId[e.syllabusId] = e;
          }
        }
        return byId.values.toList();
      });
}
