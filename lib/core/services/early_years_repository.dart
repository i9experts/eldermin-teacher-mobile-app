import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../models/early_years/ece_models.dart';
import '../models/json_helpers.dart';
import '../network/api_exception.dart';
import '../network/base_client.dart';
import '../network/dio_exception_handler.dart';
import '../network/response_shape.dart';
import '../models/homework/homework_models.dart' show attachmentMimeFor;

/// Early Years (backend `ece/ece.controller.ts`), teacher side. Only the routes the v1 screens need:
/// the children roster, reference lists (domains, skills, level names), one child's profile / observations / portfolio, three create routes and
/// the photo upload + signed link. Care records, allergies and support cases are NOT reachable from here on purpose.
///
/// `x-academic-year` is sent on EVERY Early Years call. The backend stamps new records with it and reads the child profile per year
/// (ece.controller.ts ctx(): the JWT carries no year and the fallback is the literal 'unset'), and the web always sends it, so the app uses the
/// school's current year from `GET /organization/academic-years` (the web's own source). With no known current year the header is omitted on
/// reads and the create calls refuse to run (see [requireAcademicYear]).
class EarlyYearsRepository {
  final BaseClient _client;
  EarlyYearsRepository([BaseClient? client]) : _client = client ?? BaseClient();

  static const String academicYearHeader = 'x-academic-year';

  String? _year;

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw DioExceptionHandler.handle(e);
    }
  }

  // ── academic year ─────────────────────────────────────────────

  /// The school's current academic year name (e.g. '2025-26'), cached after the first success. Null when it cannot be determined (no year is
  /// flagged current, or the call failed); a failed lookup is retried on the next call.
  Future<String?> currentAcademicYear({bool refresh = false}) async {
    if (!refresh && _year != null) return _year;
    try {
      final res = await _client.get(ApiConstants.academicYears);
      final rows = expectRows(res.data, what: 'academic years', keys: const ['data', 'items']);
      final current = rows.where((r) => readBool(r['isCurrent'])).toList();
      final name = current.isEmpty ? null : readString(current.first['name']);
      _year = name;
      return name;
    } on DioException {
      return null;
    } on UnexpectedResponseShape {
      return null;
    } on ApiException {
      return null;
    }
  }

  /// The year to stamp on a record about to be created; throws [AcademicYearUnknown] (no request is sent) when there is none.
  Future<String> requireAcademicYear() async {
    final y = await currentAcademicYear();
    if (y == null || y.isEmpty) throw const AcademicYearUnknown();
    return y;
  }

  Future<Map<String, String>?> _headers() async {
    final y = await currentAcademicYear();
    return (y == null || y.isEmpty) ? null : {academicYearHeader: y};
  }

  // ── reads ─────────────────────────────────────────────────────

  /// `GET /ece/children`: every active Early Years child of the school (the caller narrows it to their classes).
  Future<List<EceChild>> fetchChildren() => _guard(() async {
        final res = await _client.get(ApiConstants.eceChildren, headers: await _headers());
        return [for (final r in expectRows(res.data, what: 'early years children')) EceChild.fromJson(r)];
      });

  Future<List<EceDomain>> fetchDomains() => _guard(() async {
        final res = await _client.get(ApiConstants.eceDomains, headers: await _headers());
        final list = [for (final r in expectRows(res.data, what: 'early years domains')) EceDomain.fromJson(r)];
        list.sort((a, b) => a.order.compareTo(b.order));
        return list;
      });

  Future<List<EceSkill>> fetchSkills({String? domainId}) => _guard(() async {
        final res = await _client.get(ApiConstants.eceSkills,
            queryParameters: {if (domainId != null && domainId.isNotEmpty) 'domainId': domainId}, headers: await _headers());
        return [for (final r in expectRows(res.data, what: 'early years skills')) EceSkill.fromJson(r)];
      });

  /// Level names for the pickers: the first framework's `progressionLevels` (as the web does), else the default six.
  Future<List<String>> fetchProgressionLevels() => _guard(() async {
        final res = await _client.get(ApiConstants.eceFrameworks, headers: await _headers());
        final rows = expectRows(res.data, what: 'early years frameworks');
        return rows.isEmpty ? kDefaultProgressionLevels : EceFramework.fromJson(rows.first).progressionLevels;
      });

  /// `GET /ece/students/:id/profile` (never a 404: a child never observed gets the empty shape).
  Future<EceProfile> fetchProfile(String studentId) => _guard(() async {
        final res = await _client.get(ApiConstants.eceProfile(studentId), headers: await _headers());
        return EceProfile.fromJson(expectMap(res.data, what: 'early years profile'));
      });

  /// `GET /ece/observations?studentId=` newest first, no paging on the server.
  Future<List<EceObservation>> fetchObservations(String studentId) => _guard(() async {
        final res = await _client.get(ApiConstants.eceObservations, queryParameters: {'studentId': studentId}, headers: await _headers());
        return [for (final r in expectRows(res.data, what: 'early years observations')) EceObservation.fromJson(r)];
      });

  /// `GET /ece/students/:id/portfolio`: all entries of the child, including ones not shared with the family.
  Future<List<EcePortfolioEntry>> fetchPortfolio(String studentId) => _guard(() async {
        final res = await _client.get(ApiConstants.eceStudentPortfolio(studentId), headers: await _headers());
        return [for (final r in expectRows(res.data, what: 'early years portfolio')) EcePortfolioEntry.fromJson(r)];
      });

  // ── writes ────────────────────────────────────────────────────

  /// `POST /ece/observations/quick`. Needs a known academic year.
  Future<EceObservation> createQuickObservation(EceQuickObservationDraft draft) => _guard(() async {
        final y = await requireAcademicYear();
        final res = await _client.post(ApiConstants.eceObservationsQuick, data: draft.toJson(), headers: {academicYearHeader: y});
        return EceObservation.fromJson(expectMap(res.data, what: 'created observation'));
      });

  /// `POST /ece/observations`. Needs a known academic year.
  Future<EceObservation> createObservation(EceObservationDraft draft) => _guard(() async {
        final y = await requireAcademicYear();
        final res = await _client.post(ApiConstants.eceObservations, data: draft.toJson(), headers: {academicYearHeader: y});
        return EceObservation.fromJson(expectMap(res.data, what: 'created observation'));
      });

  /// `POST /ece/portfolio`. Sharing (`isVisibleToFamily`) makes the backend email the guardian.
  Future<EcePortfolioEntry> createPortfolioEntry(EcePortfolioDraft draft) => _guard(() async {
        final y = await requireAcademicYear();
        final res = await _client.post(ApiConstants.ecePortfolio, data: draft.toJson(), headers: {academicYearHeader: y});
        return EcePortfolioEntry.fromJson(expectMap(res.data, what: 'created portfolio entry'));
      });

  // ── photos ────────────────────────────────────────────────────

  /// `POST /upload/single/ece-evidence` multipart field `file` (max 10 MB; 503 when storage is not configured). Photos only in v1.
  Future<EceUploaded> uploadEvidence({required String path, required String fileName, void Function(int sent, int total)? onProgress}) =>
      _guard(() async {
        final mime = attachmentMimeFor(fileName);
        final file = await MultipartFile.fromFile(path, filename: fileName, contentType: mime == null ? null : DioMediaType.parse(mime));
        final res = await _client.multipart(ApiConstants.uploadSingle(ApiConstants.eceEvidenceFolder), files: {'file': [file]}, onSendProgress: onProgress);
        final up = EceUploaded.fromBody(res.data);
        if (up == null) throw ApiException('The upload finished but the server sent no file reference. Please try again.');
        return up;
      });

  /// `GET /upload/signed-url?key=` -> `{url}` (valid about 1 hour). Only keys of evidence rows the teacher already received are requested.
  Future<String> signedUrl(String key) => _guard(() async {
        final res = await _client.get(ApiConstants.uploadSignedUrl, queryParameters: {'key': key});
        final url = readString(asJsonMap(res.data)['url']);
        if (url == null) throw ApiException("Couldn't open this photo. Please try again.");
        return url;
      });
}

/// Thrown (before any request) when a record would be created but the school's current academic year cannot be determined.
class AcademicYearUnknown implements Exception {
  const AcademicYearUnknown();
  static const String message = "Couldn't work out the school's current academic year, so nothing was saved. Check your connection and try again.";
  @override
  String toString() => message;
}
