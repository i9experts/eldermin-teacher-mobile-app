import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../models/auth_me.dart';
import '../models/json_helpers.dart';
import '../models/login_result.dart';
import '../models/staff_me.dart';
import '../network/api_exception.dart';
import '../network/base_client.dart';
import '../network/dio_exception_handler.dart';

/// Auth network calls: sign in, session check, staff identity, forgot /
/// reset password and (best-effort) sign-out.
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

  /// `GET /auth/me` - the session check. Returns the user's role only (all
  /// the app needs from it; identity comes from `/staff-portal/me`).
  ///
  /// With [token] (deep-link auto-login) the supplied JWT is sent explicitly
  /// and a 401 is NOT treated as a session expiry (nothing is stored yet);
  /// without it the stored token is used like any authenticated call.
  Future<AuthMe> fetchAuthMe({String? token}) => _guard(() async {
        final res = token == null
            ? await _client.get(ApiConstants.authMe)
            : await _client.get(
                ApiConstants.authMe,
                requiresAuth: false,
                headers: {'Authorization': 'Bearer $token'},
              );
        return AuthMe.fromJson(asJsonMap(res.data));
      });

  /// `POST /auth/forgot-password` - the backend always answers with the
  /// same generic message, whether or not the account exists.
  Future<void> forgotPassword(String email) => _guard(() async {
        await _client.post(ApiConstants.forgotPassword, data: {'email': email}, requiresAuth: false);
      });

  /// `POST /auth/reset-password {token, newPassword}`. An invalid/expired
  /// token is a 401 ("This reset link is invalid or has expired") that must
  /// reach the form, never end a session.
  Future<void> resetPassword({required String token, required String newPassword}) => _guard(() async {
        await _client.post(ApiConstants.resetPassword,
            data: {'token': token, 'newPassword': newPassword}, requiresAuth: false);
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
