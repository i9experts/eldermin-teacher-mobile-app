import 'json_helpers.dart';

/// Generic envelope for a typed result. The Eldermin backend mostly
/// returns bare bodies (no `{data}` wrapper), so [fromBody] accepts both
/// `{ data: ..., message: ... }` and a bare object.
class ApiResponse<T> {
  final T? data;
  final String? message;
  final int? statusCode;

  const ApiResponse({this.data, this.message, this.statusCode});

  bool get hasData => data != null;

  factory ApiResponse.fromBody(
    Object? body,
    T Function(Map<String, dynamic> json) parse, {
    int? statusCode,
  }) {
    if (body is Map) {
      final map = asJsonMap(body);
      final inner = map['data'];
      return ApiResponse<T>(
        data: inner is Map ? parse(asJsonMap(inner)) : (map.containsKey('data') ? null : parse(map)),
        message: readString(map['message']),
        statusCode: statusCode,
      );
    }
    return ApiResponse<T>(statusCode: statusCode);
  }
}
