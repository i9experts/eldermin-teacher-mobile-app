import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../models/json_helpers.dart';
import '../models/login_result.dart';
import '../models/staff_me.dart';
import '../network/api_exception.dart';
import '../network/base_client.dart';
import '../network/dio_exception_handler.dart';

/// The only network calls Phase 2 needs: sign in, resolve the staff
/// identity, and (best-effort) tell the server we signed out.
/// Throws [ApiException] for every failure.
class AuthApiService {
  final BaseClient _client;
  AuthApiService(this._client);

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw DioExceptionHandler.handle(e);
    }
  }

  /// `POST /auth/login`. A 401 here means invalid credentials - the
  /// network layer deliberately does NOT treat it as an expired session.
  Future<LoginResult> login({required String email, required String password, String? slug}) =>
      _guard(() async {
        final res = await _client.post(
          ApiConstants.login,
          data: {
            'email': email,
            'password': password,
            if (slug != null && slug.trim().isNotEmpty) 'slug': slug.trim(),
          },
          requiresAuth: false,
        );
        return LoginResult.fromJson(asJsonMap(res.data));
      });

  /// `GET /staff-portal/me` - the only source of staffId/teacherProfileId.
  Future<StaffMe> fetchStaffMe() => _guard(() async {
        final res = await _client.get(ApiConstants.staffMe);
        return StaffMe.fromJson(asJsonMap(res.data));
      });

  /// `POST /auth/logout` is stateless server-side; failures are ignored.
  Future<void> logout() async {
    try {
      await _client.post(ApiConstants.logout, requiresAuth: false);
    } catch (_) {}
  }
}
