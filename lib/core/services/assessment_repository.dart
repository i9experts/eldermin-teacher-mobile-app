import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../models/assessments/assessment_models.dart';
import '../models/json_helpers.dart';
import '../models/paginated.dart';
import '../network/api_exception.dart';
import '../network/base_client.dart';
import '../network/dio_exception_handler.dart';

/// One row of `POST /assessments/marks/bulk` (SingleMarkDto, assessment.dto.ts:150-159).
class MarkWrite {
  final String studentId;
  final String studentName;
  final String rollNumber;
  final String section;

  /// null for an absent / exempt row (the previous number is then cleared: `@IsOptional` lets `null` through, assessment.dto.ts:155).
  final double? obtainedMarks;
  final bool isAbsent;
  final bool isExempt;
  final String remarks;

  const MarkWrite({
    required this.studentId,
    required this.studentName,
    required this.rollNumber,
    this.section = '',
    this.obtainedMarks,
    this.isAbsent = false,
    this.isExempt = false,
    this.remarks = '',
  });

  /// `{studentId, studentName, rollNumber, section, obtainedMarks, isAbsent, isExempt, remarks}` exactly (AD:150-159).
  Map<String, Object?> toJson() => {
        'studentId': studentId,
        'studentName': studentName,
        'rollNumber': rollNumber,
        'section': section,
        'obtainedMarks': isAbsent || isExempt ? null : obtainedMarks,
        'isAbsent': isAbsent,
        'isExempt': isExempt,
        'remarks': remarks,
      };
}

/// All pages of a list plus whether the safety cap cut it short.
class AllPages<T> {
  final List<T> items;
  final bool truncated;
  const AllPages(this.items, {this.truncated = false});
}

/// Assessments, marks entry, report-card remarks and quiz grading (eldermin-backend/src/assessments/: AC controller, AS service, AD dto).
/// NOT used on purpose: POST/PUT/PATCH/DELETE /assessments (create, update, status, delete), PATCH marks/verify, POST report-cards/generate
/// and /publish, question bank, exam papers, OMR, analytics, dashboard.
class AssessmentRepository {
  final BaseClient _client;
  AssessmentRepository([BaseClient? client]) : _client = client ?? BaseClient();

  static const int assessmentPageSize = 100;
  static const int markPageSize = 200;
  static const int cardPageSize = 100;
  static const int maxPages = 10;

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw DioExceptionHandler.handle(e);
    }
  }

  Future<AllPages<T>> _allPages<T>(String url, Map<String, Object?> query, int pageSize, T Function(Map<String, dynamic>) parse) async {
    final out = <T>[];
    for (var page = 1; page <= maxPages; page++) {
      final res = await _client.get(url, queryParameters: {...query, 'page': page, 'limit': pageSize});
      final p = Paginated<T>.fromJson(res.data, parse);
      out.addAll(p.items);
      if (!p.hasMore) return AllPages(out);
    }
    return AllPages(out, truncated: true);
  }

  /// `GET /assessments?page&limit=100&sortBy=startDate&sortOrder=desc` (AC:54-58 -> AS:994-1021; `limit` has no maximum, AD:14). Pages
  /// until `meta.pages` is reached (cap [maxPages]). Campus-scoped by the server, NOT teacher-scoped.
  Future<AllPages<Assessment>> listAssessments() => _guard(() => _allPages(
        ApiConstants.assessments,
        {'sortBy': 'startDate', 'sortOrder': 'desc'},
        assessmentPageSize,
        Assessment.fromJson,
      ).then((r) => AllPages([...r.items.where((a) => a.id.isNotEmpty)], truncated: r.truncated)));

  /// `GET /assessments/:id` (AC:195-199): 404 "Assessment not found".
  Future<Assessment> assessment(String id) => _guard(() async {
        final res = await _client.get(ApiConstants.assessment(id));
        final a = Assessment.fromJson(asJsonMap(res.data));
        if (a.id.isEmpty) throw ApiException('Assessment not found', statusCode: 404);
        return a;
      });

  /// `GET /assessments/marks/list?assessmentId&subject&page&limit=200` (AC:78-82 -> AS:1301-1318). NOT filtered by grade/section (marks of
  /// every section of an all-sections assessment come back; the caller keeps its own roster's).
  Future<AllPages<MarkRecord>> marks(String assessmentId, String subject) => _guard(() => _allPages(
        ApiConstants.marksList,
        {'assessmentId': assessmentId, 'subject': subject},
        markPageSize,
        MarkRecord.fromJson,
      ).then((r) => AllPages([...r.items.where((m) => m.studentId.isNotEmpty)], truncated: r.truncated)));

  /// `POST /assessments/marks/bulk` -> 201 `{message, subject}` (AC:349-354 -> AS:1239-1299): body
  /// `{assessmentId, subject, grade, marks[...]}` (BulkMarkEntryDto, AD:161-171). `x-academic-year` = the assessment's year (the server
  /// stamps `req.user.academicYear || header || '2025-26'`, AC:37-44; whether the JWT carries one is UNVERIFIED).
  Future<void> saveMarks({required String assessmentId, required String subject, required String grade, required List<MarkWrite> marks, String? academicYear}) =>
      _guard(() async {
        await _client.post(
          ApiConstants.marksBulk,
          data: {'assessmentId': assessmentId, 'subject': subject, 'grade': grade, 'marks': [for (final m in marks) m.toJson()]},
          headers: {if (academicYear != null && academicYear.isNotEmpty) 'x-academic-year': academicYear},
        );
      });

  /// `GET /assessments/report-cards?assessmentId&page&limit=100` (AC:96-100 -> AS:1695-1711).
  Future<AllPages<ReportCard>> reportCards(String assessmentId) => _guard(() => _allPages(
        ApiConstants.reportCards,
        {'assessmentId': assessmentId},
        cardPageSize,
        ReportCard.fromJson,
      ).then((r) => AllPages([...r.items.where((c) => c.id.isNotEmpty)], truncated: r.truncated)));

  /// `PATCH /assessments/report-cards/:id/remarks` `{classTeacherRemarks}` ONLY (UpdateReportCardRemarksDto, AD:196-199; principalRemarks
  /// is never sent). An unknown id answers HTTP 200 with an EMPTY body (AS:1723-1727 returns null): mapped to a 404 here.
  Future<ReportCard> saveRemarks(String id, String classTeacherRemarks) => _guard(() async {
        final res = await _client.patch(ApiConstants.reportCardRemarks(id), data: {'classTeacherRemarks': classTeacherRemarks});
        final c = ReportCard.fromJson(asJsonMap(res.data));
        if (c.id.isEmpty) throw ApiException('This report card was not found on the server.', statusCode: 404);
        return c;
      });

  /// `GET /assessments/quiz-attempts` (AC:165-169 -> AS:1468-1473): attempts waiting for a teacher (status submitted), oldest first.
  /// Bare array, no pagination, no class scoping.
  Future<List<QuizAttempt>> pendingAttempts() => _guard(() async {
        final res = await _client.get(ApiConstants.quizAttempts);
        final rows = res.data is List ? asJsonMapList(res.data) : asJsonMapList(asJsonMap(res.data)['data']);
        return rows.map(QuizAttempt.fromJson).where((a) => a.id.isNotEmpty).toList();
      });

  /// `GET /assessments/quiz-attempts/:attemptId` (AC:171-175 -> AS:1475-1484): answers with the hydrated question (answer key included).
  Future<QuizAttempt> attempt(String id) => _guard(() async {
        final res = await _client.get(ApiConstants.quizAttempt(id));
        final a = QuizAttempt.fromJson(asJsonMap(res.data));
        if (a.id.isEmpty) throw ApiException('Quiz attempt not found', statusCode: 404);
        return a;
      });

  /// `POST /assessments/quiz-attempts/:attemptId/grade` `{grades:[{questionId, marksAwarded}]}` -> 200 with the saved attempt
  /// (AC:177-182 -> AS:1490-1516; GradeQuizAttemptDto, AD:85-94).
  Future<QuizAttempt> gradeAttempt(String id, List<({String questionId, double marks})> grades) => _guard(() async {
        final res = await _client.post(ApiConstants.quizAttemptGrade(id), data: {
          'grades': [for (final g in grades) {'questionId': g.questionId, 'marksAwarded': g.marks}],
        });
        final a = QuizAttempt.fromJson(asJsonMap(res.data));
        if (a.id.isEmpty) throw ApiException('The server saved the marks but sent nothing back. Pull to refresh.');
        return a;
      });
}
