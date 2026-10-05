import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../models/homework/homework_models.dart';
import '../models/json_helpers.dart';
import '../network/api_exception.dart';
import '../network/base_client.dart';
import '../network/dio_exception_handler.dart';

/// Homework (assignments), submissions, grading and attachments.
///
/// Backend: modules/teaching/teaching.controller.ts:192-217 -> teaching.service.ts:861-1027, upload/upload.controller.ts.
/// Errors surface as [ApiException] (`statusCode` null = no response/offline); the server body is the real
/// `{statusCode, message, timestamp, path}` (filters/sentry.filter.ts:43-48).
class HomeworkRepository {
  final BaseClient _client;
  HomeworkRepository([BaseClient? client]) : _client = client ?? BaseClient();

  /// Upload folder used by the web for homework (HomeworkTab.tsx:94). Keys come back as `<schoolSlug>/homework-attachments/<uuid>.<ext>`.
  static const String uploadFolder = 'homework-attachments';

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw DioExceptionHandler.handle(e);
    }
  }

  /// `GET /teaching/assignments?teacherId=<my staffId>` -> bare array, sorted by dueDate desc, NO pagination (teaching.service.ts:861-871).
  /// The result is re-filtered to [staffId] here as well (defence in depth: the unfiltered endpoint returns every teacher's).
  Future<List<Assignment>> fetchMine(String staffId) => _guard(() async {
        final res = await _client.get(ApiConstants.assignments, queryParameters: {'teacherId': staffId});
        final data = res.data;
        final list = data is List ? asJsonMapList(data) : asJsonMapList(asJsonMap(data)['data']);
        return list.map(Assignment.fromJson).where((a) => a.id.isNotEmpty && a.teacherId == staffId).toList();
      });

  /// `POST /teaching/assignments` (teaching.controller.ts:197-199 -> teaching.service.ts:873-908). Returns the created document (HTTP 201).
  Future<Assignment> create(AssignmentInput input, {required String teacherId, required bool assign}) => _guard(() async {
        final res = await _client.post(ApiConstants.assignments, data: input.toCreateJson(teacherId: teacherId, assign: assign));
        return Assignment.fromJson(asJsonMap(res.data));
      });

  /// `PATCH /teaching/assignments/:id` (teaching.controller.ts:201-203 -> :910-920). Returns the updated document.
  Future<Assignment> update(String id, Map<String, Object?> patch) => _guard(() async {
        final res = await _client.patch(ApiConstants.assignment(id), data: patch);
        return Assignment.fromJson(asJsonMap(res.data));
      });

  /// `DELETE /teaching/assignments/:id` -> `{ deleted: true }` (:922-929). Also deletes every submission of it.
  Future<void> delete(String id) => _guard(() async {
        await _client.delete(ApiConstants.assignment(id));
      });

  /// `GET /teaching/assignments/:id/submissions` -> `{ assignment, submissions[] }` (:990-1002), sorted by student name.
  /// Includes the roster snapshot (`pending` / `missed` rows = students who have NOT turned work in).
  Future<SubmissionsResult> fetchSubmissions(String assignmentId) => _guard(() async {
        final res = await _client.get(ApiConstants.assignmentSubmissions(assignmentId));
        return SubmissionsResult.fromJson(asJsonMap(res.data));
      });

  /// `PATCH /teaching/assignments/:id/submissions/:sid` { grade, feedback? } (GradeSubmissionDto, assignment.dto.ts:50-53; :1004-1027).
  /// Returns the updated submission row. The server rejects `grade > maxGrade` with 400 (:1007-1009).
  Future<Submission> grade(String assignmentId, String submissionId, {required double grade, String? feedback}) => _guard(() async {
        final g = grade == grade.roundToDouble() ? grade.round() : grade;
        final res = await _client.patch(ApiConstants.assignmentSubmission(assignmentId, submissionId), data: {
          'grade': g,
          if (feedback != null && feedback.trim().isNotEmpty) 'feedback': feedback.trim(),
        });
        return Submission.fromJson(asJsonMap(res.data));
      });

  /// `POST /upload/single/homework-attachments` multipart field `file` (upload.controller.ts:20-31). Max 10 MB (413 'File too large').
  /// [onProgress] gets (sent, total) bytes.
  Future<UploadedFile> upload({
    required String path,
    required String fileName,
    String folder = uploadFolder,
    void Function(int sent, int total)? onProgress,
  }) =>
      _guard(() async {
        final mime = attachmentMimeFor(fileName);
        final file = await MultipartFile.fromFile(path,
            filename: fileName, contentType: mime == null ? null : DioMediaType.parse(mime));
        final res = await _client.multipart(ApiConstants.uploadSingle(folder), files: {'file': [file]}, onSendProgress: onProgress);
        final up = UploadedFile.fromBody(res.data);
        if (up == null) throw ApiException('The upload finished but the server sent no file reference. Please try again.');
        return up;
      });

  /// `GET /upload/signed-url?key=` -> `{ url }` (upload.controller.ts:46-50): a time-limited (1 h) link to open an attachment.
  /// No ownership check exists server-side, so only keys read from a payload the teacher is allowed to see are ever requested.
  Future<String> signedUrl(String key) => _guard(() async {
        final res = await _client.get(ApiConstants.uploadSignedUrl, queryParameters: {'key': key});
        final url = readString(asJsonMap(res.data)['url']);
        if (url == null) throw ApiException("Couldn't open this file. Please try again.");
        return url;
      });
}
