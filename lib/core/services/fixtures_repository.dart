import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../models/home/teaching.dart';
import '../network/base_client.dart';
import '../network/dio_exception_handler.dart';
import '../network/response_shape.dart';

/// Phase 7b: substitutions ("fixtures"), TEACHER view only (eldermin-backend `src/modules/teaching/substitution.controller.ts` = SC,
/// `substitution.service.ts` = SS, branch feat/staff-portal 265fcfa). Assign / cancel / generate / suggestions are admin actions and are not
/// in the app.
class FixturesRepository {
  final BaseClient _client;
  FixturesRepository([BaseClient? client]) : _client = client ?? BaseClient();

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw DioExceptionHandler.handle(e);
    }
  }

  /// `GET /teaching/fixtures?teacherId=<staffId>&from&to&status` (SC:42-45 -> SS:232-245): bare array, rows where the teacher is the ORIGINAL
  /// OR the SUBSTITUTE (SS:241), sorted date DESC then periodNo ASC, at most 200. `from`/`to` bound `date` (inclusive, `new Date(x)`).
  Future<List<Substitution>> fetchFixtures({required String staffId, DateTime? from, DateTime? to, String? status}) => _guard(() async {
        final res = await _client.get(ApiConstants.fixtures, queryParameters: {
          'teacherId': staffId,
          if (from != null) 'from': from.toUtc().toIso8601String(),
          if (to != null) 'to': to.toUtc().toIso8601String(),
          if (status != null) 'status': status,
        });
        return expectRows(res.data, what: 'substitutions').map(Substitution.fromJson).where((s) => s.id.isNotEmpty).toList();
      });

  /// `PATCH /teaching/fixtures/:id/complete` (SC:36-40 -> SS:223-230): only from `assigned` (else 404 'Fixture not found or not in an assigned
  /// state'). The server does NOT check that the caller is the substitute: the app only offers it to the substitute (UI gating).
  Future<Substitution> complete(String id) => _guard(() async {
        final res = await _client.patch(ApiConstants.fixtureComplete(id));
        final s = Substitution.fromJson(expectMap(res.data, what: 'this substitution'));
        if (s.id.isEmpty) throw UnexpectedResponseShape('this substitution', '_id missing');
        return s;
      });
}
