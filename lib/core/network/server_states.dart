/// Account-level states the backend reports on any authenticated call (auth-state.service.ts, school-suspended.ts):
///  * 403 `SCHOOL_SUSPENDED` - the school's account is suspended. The response filter (sentry.filter.ts) keeps only `statusCode`, `message`,
///    `timestamp`, `path`, so the `code` is normally NOT on the wire; the app therefore also recognises the server's wording.
///  * 401 "This account is no longer active." - the user, or every Staff row of the user, was deactivated.
class ServerStates {
  ServerStates._();

  static const String suspendedCode = 'SCHOOL_SUSPENDED';

  /// Shown when the server sent a suspended 403 without readable text.
  static const String suspendedFallback = "Your school's account is currently suspended. Please contact your school administration.";

  /// The message of an error body (`message` may be a list), or null.
  static String? messageOf(Object? body) {
    if (body is! Map) return null;
    final m = body['message'];
    if (m == null) return null;
    final text = m is List ? m.join(', ') : m.toString();
    return text.trim().isEmpty ? null : text.trim();
  }

  static String? codeOf(Object? body) {
    if (body is! Map) return null;
    final c = body['code']?.toString();
    if (c != null && c.trim().isNotEmpty) return c.trim();
    // `error` is Nest's HTTP name ("Forbidden") unless the server sets a machine code (UPPER_SNAKE), as school-suspended.ts does
    final e = body['error']?.toString().trim() ?? '';
    return RegExp(r'^[A-Z][A-Z0-9_]+$').hasMatch(e) ? e : null;
  }

  /// Code first: a `SCHOOL_SUSPENDED` code decides; another code is some other 403 (never mistaken for a suspension by its wording). The wording
  /// ("suspended") is only a FALLBACK for servers whose error filter drops the code (backend sentry.filter.ts:43-47, see hardening-backlog.md).
  static bool isSchoolSuspended(int? statusCode, {String? message, String? code}) {
    if (statusCode != 403) return false;
    final c = (code ?? '').trim();
    if (c.isNotEmpty) return c == suspendedCode;
    return (message ?? '').toLowerCase().contains('suspended');
  }

  static bool isAccountInactive(int? statusCode, {String? message}) {
    if (statusCode != 401) return false;
    return (message ?? '').toLowerCase().contains('no longer active');
  }
}
