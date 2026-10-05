import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'api_exception.dart';
import 'dio_service.dart' show kNoInternetMarker;

/// Maps a [DioException] to the [ApiException] every controller already
/// expects — same status-code messages the old ApiClient produced.
class DioExceptionHandler {
  DioExceptionHandler._();

  static ApiException handle(DioException e) {
    debugPrint('Dio error status  --> ${e.response?.statusCode}');
    debugPrint('Dio error type    --> ${e.type}');
    debugPrint('Dio error data    --> ${e.response?.data}');

    final status = e.response?.statusCode;

    if (e.error == kNoInternetMarker) {
      return ApiException('No internet connection. Check your network and try again.', statusCode: status);
    }

    switch (e.type) {
      case DioExceptionType.cancel:
        return ApiException('Request was cancelled.', statusCode: status);
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException('Connection timed out. Check your internet and try again.', statusCode: status);
      case DioExceptionType.connectionError:
        return ApiException("Couldn't reach Eldermin. Check your internet connection.", statusCode: status);
      case DioExceptionType.badCertificate:
        return ApiException('Security certificate error.', statusCode: status);
      case DioExceptionType.badResponse:
        return ApiException(_messageFromResponse(e.response), statusCode: status);
      case DioExceptionType.unknown:
      default:
        return ApiException('Something went wrong. Please try again.', statusCode: status);
    }
  }

  static String _messageFromResponse(Response<dynamic>? response) {
    final body = response?.data;
    if (body is Map && body['message'] != null) {
      return body['message'] is List ? (body['message'] as List).join(', ') : body['message'].toString();
    }
    return 'Something went wrong. Please try again.';
  }
}
