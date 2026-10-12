import 'package:dio/dio.dart';
import 'package:eldermin_teacher_app/core/network/base_client.dart';
import 'package:eldermin_teacher_app/core/network/dio_service.dart' show kNoInternetMarker;

/// How the fake network fails. Mirrors what [DioService] / Dio produce, so the REAL repositories run their REAL error mapping
/// ([DioExceptionHandler]) and the real controllers / screens see exactly what the app sees in production.
enum NetFail { offline, connectTimeout, receiveTimeout, http403, http404, http500, http501, http401 }

/// A [BaseClient] whose every request fails the same way (and counts the requests). Real repositories are built on it.
class FailingClient extends BaseClient {
  NetFail mode;
  int calls = 0;
  final urls = <String>[];
  FailingClient([this.mode = NetFail.http500]);

  Future<Response> _fail(String url) async {
    calls++;
    urls.add(url);
    final ro = RequestOptions(path: url);
    int? code;
    switch (mode) {
      case NetFail.offline:
        throw DioException(requestOptions: ro, type: DioExceptionType.connectionError, error: kNoInternetMarker);
      case NetFail.connectTimeout:
        throw DioException(requestOptions: ro, type: DioExceptionType.connectionTimeout);
      case NetFail.receiveTimeout:
        throw DioException(requestOptions: ro, type: DioExceptionType.receiveTimeout);
      case NetFail.http403:
        code = 403;
      case NetFail.http404:
        code = 404;
      case NetFail.http500:
        code = 500;
      case NetFail.http501:
        code = 501;
      case NetFail.http401:
        code = 401;
    }
    throw DioException(
      requestOptions: ro,
      type: DioExceptionType.badResponse,
      response: Response(requestOptions: ro, statusCode: code, data: {'statusCode': code, 'message': code == 403 ? 'Forbidden resource' : (code == 404 ? 'Not Found' : 'Internal server error')}),
    );
  }

  @override
  Future<Response> get(String url, {Map<String, dynamic>? queryParameters, bool requiresAuth = true, Map<String, String>? headers}) => _fail(url);
  @override
  Future<Response> post(String url, {dynamic data, Map<String, dynamic>? queryParameters, bool requiresAuth = true, Map<String, String>? headers}) => _fail(url);
  @override
  Future<Response> patch(String url, {dynamic data, Map<String, dynamic>? queryParameters, bool requiresAuth = true}) => _fail(url);
  @override
  Future<Response> put(String url, {dynamic data, Map<String, dynamic>? queryParameters, bool requiresAuth = true}) => _fail(url);
  @override
  Future<Response> delete(String url, {dynamic data, Map<String, dynamic>? queryParameters, bool requiresAuth = true}) => _fail(url);
  @override
  Future<Response> multipart(String url, {required Map<String, List<MultipartFile>> files, Map<String, dynamic>? fields, String method = 'POST', void Function(int sent, int total)? onSendProgress, bool requiresAuth = true}) => _fail(url);
}
