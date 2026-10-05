import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'dio_service.dart';

/// Thin wrapper over the shared [Dio] instance - every API service call
/// goes through one of these so timeouts, auth headers, and 401
/// handling stay centralized in [DioService].
class BaseClient {
  Options _jsonOptions(bool requiresAuth) =>
      Options(contentType: 'application/json', extra: {'requiresAuth': requiresAuth});

  Future<Response> get(
    String url, {
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
    Map<String, String>? headers,
  }) async {
    debugPrint('GET → $url');
    return DioService.getDio().get(
      url,
      queryParameters: queryParameters,
      options: Options(extra: {'requiresAuth': requiresAuth}, headers: headers),
    );
  }

  Future<Response> post(
    String url, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
    Map<String, String>? headers,
  }) async {
    debugPrint('POST → $url');
    final options = _jsonOptions(requiresAuth);
    if (headers != null) options.headers = {...?options.headers, ...headers};
    return DioService.getDio().post(url, data: data, queryParameters: queryParameters, options: options);
  }

  Future<Response> patch(
    String url, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) async {
    debugPrint('PATCH → $url');
    return DioService.getDio().patch(url,
        data: data, queryParameters: queryParameters, options: _jsonOptions(requiresAuth));
  }

  // ── Additions over the parent app's BaseClient ───────────────

  Future<Response> put(
    String url, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) async {
    debugPrint('PUT → $url');
    return DioService.getDio().put(url,
        data: data, queryParameters: queryParameters, options: _jsonOptions(requiresAuth));
  }

  Future<Response> delete(
    String url, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) async {
    debugPrint('DELETE → $url');
    return DioService.getDio().delete(url,
        data: data, queryParameters: queryParameters, options: _jsonOptions(requiresAuth));
  }

  /// Multipart upload (avatar, homework attachments, lesson-plan parse...).
  /// [files] maps the form field name to the files to attach under it.
  Future<Response> multipart(
    String url, {
    required Map<String, List<MultipartFile>> files,
    Map<String, dynamic>? fields,
    String method = 'POST',
    void Function(int sent, int total)? onSendProgress,
    bool requiresAuth = true,
  }) async {
    debugPrint('$method (multipart) → $url');
    final form = FormData();
    fields?.forEach((k, v) => form.fields.add(MapEntry(k, v.toString())));
    files.forEach((field, list) {
      for (final f in list) {
        form.files.add(MapEntry(field, f));
      }
    });
    return DioService.getDio().request(
      url,
      data: form,
      onSendProgress: onSendProgress,
      options: Options(
        method: method,
        contentType: 'multipart/form-data',
        extra: {'requiresAuth': requiresAuth},
      ),
    );
  }
}
