import '../models/json_helpers.dart';
import 'api_exception.dart';

/// Thrown when a 2xx response has a body that is NOT the shape the app expects (a Map where a list was expected, a missing or wrongly named
/// wrapper key, rows that are not objects, a null / String body ...). Bug B0 showed the danger of reading such a body "tolerantly" into an
/// empty list: the screen then looks like "nothing here" although the server is broken. It is an [ApiException] with no status code, so every
/// controller's existing error path (SectionState.fromError -> error state with Retry) shows [message].
///
/// Rule used by EVERY repository (one place, this file):
///  * a valid but empty list/envelope  -> an empty result (empty state);
///  * a failed call                    -> DioExceptionHandler's ApiException (error state);
///  * anything else                    -> [UnexpectedResponseShape] (error state, NOT an empty list).
/// Legitimately optional FIELDS inside a row stay tolerant (readString/readNum ...); only the container shape is strict.
class UnexpectedResponseShape extends ApiException {
  /// What was being loaded, e.g. "homework" (completes "Something went wrong loading ...").
  final String what;

  /// Developer detail (never shown): what was received.
  final String detail;

  UnexpectedResponseShape(this.what, [this.detail = ''])
      : super('Something went wrong loading $what — try again.');

  @override
  String toString() => detail.isEmpty ? message : '$message ($detail)';
}

String _kind(Object? v) => v == null ? 'null' : v.runtimeType.toString();

/// The body as a JSON object, or [UnexpectedResponseShape].
Map<String, dynamic> expectMap(Object? body, {required String what}) {
  if (body is Map) return Map<String, dynamic>.from(body);
  throw UnexpectedResponseShape(what, 'expected an object, got ${_kind(body)}');
}

/// Rows of a list response: the body itself is a List, or an object whose first PRESENT key among [keys] holds a List. Every row must be
/// an object. An empty list is valid (returns []).
List<Map<String, dynamic>> expectRows(Object? body, {required String what, List<String> keys = const ['data']}) {
  Object? raw;
  if (body is List) {
    raw = body;
  } else if (body is Map) {
    for (final k in keys) {
      if (body.containsKey(k)) {
        raw = body[k];
        if (raw is! List) throw UnexpectedResponseShape(what, '"$k" is ${_kind(raw)}, expected a list');
        break;
      }
    }
    if (raw == null) throw UnexpectedResponseShape(what, 'none of ${keys.map((k) => '"$k"').join(', ')} in the response');
  } else {
    throw UnexpectedResponseShape(what, 'expected a list, got ${_kind(body)}');
  }
  return _rowsOf(raw as List, what);
}

/// The list under [key] of an object body (the object itself is returned by [expectMap]); [key] must be present and a List of objects.
List<Map<String, dynamic>> expectKeyRows(Map<String, dynamic> body, String key, {required String what}) {
  final raw = body[key];
  if (raw is! List) throw UnexpectedResponseShape(what, '"$key" is ${_kind(raw)}, expected a list');
  return _rowsOf(raw, what);
}

List<Map<String, dynamic>> _rowsOf(List raw, String what) {
  final out = <Map<String, dynamic>>[];
  for (final e in raw) {
    if (e is! Map) throw UnexpectedResponseShape(what, 'a row is ${_kind(e)}, expected an object');
    out.add(asJsonMap(e));
  }
  return out;
}
