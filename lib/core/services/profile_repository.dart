import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../models/auth_me.dart';
import '../models/json_helpers.dart';
import '../network/base_client.dart';
import '../network/dio_exception_handler.dart';
import '../network/response_shape.dart';

/// Phase 7c: profile (eldermin-backend `src/modules/auth/auth.controller.ts` = AC, `auth.service.ts` = AS, branch feat/staff-portal 265fcfa).
class ProfileRepository {
  final BaseClient _client;
  ProfileRepository([BaseClient? client]) : _client = client ?? BaseClient();

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw DioExceptionHandler.handle(e);
    }
  }

  /// `GET /auth/me` (AC:49-52 -> AS:316-328): the user document without `passwordHash`, plus permissions. Only name / email / role / avatar are read
  /// (see [AuthMe]).
  Future<AuthMe> fetchAccount() => _guard(() async {
        final res = await _client.get(ApiConstants.authMe);
        return AuthMe.fromJson(expectMap(res.data, what: 'your account'));
      });

  /// `POST /auth/me/avatar` multipart field `avatar` (AC:54-58 -> AS:330-339): stores the file and answers `{ avatarUrl }`. Limits: 10 MB
  /// (upload.service.ts MAX_FILE_SIZE, 400 'File too large. Max 10MB allowed.'); the route itself has no type filter (UNVERIFIED: the app only sends
  /// jpg / png / webp). 503 'File uploads are not available on this server (storage is not configured).' when storage is not set up (commit 9890ad1).
  Future<String> uploadAvatar({required String path, required String fileName, required String mime}) => _guard(() async {
        final file = await MultipartFile.fromFile(path, filename: fileName, contentType: DioMediaType.parse(mime));
        final res = await _client.multipart(ApiConstants.authMeAvatar, files: {'avatar': [file]});
        final url = readString(expectMap(res.data, what: 'your photo')['avatarUrl']);
        if (url == null || !(url.startsWith('https://') || url.startsWith('http://'))) {
          throw UnexpectedResponseShape('your photo', 'avatarUrl missing');
        }
        return url;
      });
}
