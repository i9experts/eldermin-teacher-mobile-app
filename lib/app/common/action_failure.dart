import '../../core/network/api_exception.dart';

enum ActionFailureKind { offline, forbidden, notFound, validation, conflict, server, uploadUnavailable, other }

/// Teacher-readable outcome of a failed write (create / edit / delete / grade / upload / log). Maps the real error shape
/// `{statusCode, message, timestamp, path}` (filters/sentry.filter.ts:43-48; an array `message` is cut to its first element
/// there). A null status code means no response at all (offline / timeout). The SERVER message is always shown for 400/422/403
/// (it is the validation text, e.g. "Grade cannot exceed this assignment's maximum of 100.").
class ActionFailure {
  final ActionFailureKind kind;
  final String message;

  /// The server's own text (cleaned), '' when it sent none. Banners that must show exactly what the server said use this.
  final String serverMessage;
  const ActionFailure(this.kind, this.message, {this.serverMessage = ''});

  /// Title for the dedicated [ActionFailureKind.uploadUnavailable] state.
  static const uploadUnavailableTitle = 'Upload unavailable';

  /// [what] completes "You can't …": e.g. "edit this homework".
  ///
  /// [upload]: the request was a file upload; a 503 then means "storage is not configured on this server" (backend, eldermin-backend feat/staff-portal
  /// commit 9890ad1 (2026-10-08): 503 'File uploads are not available on this server (storage is not configured).') and maps to
  /// [ActionFailureKind.uploadUnavailable]: retrying cannot help.
  factory ActionFailure.from(Object e, {required String what, String keep = 'Your changes are kept.', bool upload = false}) {
    if (e is! ApiException) return ActionFailure(ActionFailureKind.other, "Couldn't $what. $keep Try again.");
    final server = e.message.trim();
    switch (e.statusCode) {
      case null:
        return ActionFailure(ActionFailureKind.offline, '$server $keep Reconnect and try again.');
      case 403:
        return ActionFailure(ActionFailureKind.forbidden, "You can't $what. ${_pretty(server)}", serverMessage: _pretty(server));
      case 404:
        return ActionFailure(ActionFailureKind.notFound, 'This was not found on the server: it may have been removed. ${_pretty(server)}');
      case 409:
        return ActionFailure(ActionFailureKind.conflict, _pretty(server).isEmpty ? "Couldn't $what: it changed on the server. Reload and check." : _pretty(server), serverMessage: _pretty(server));
      case 400:
      case 413:
      case 422:
        return ActionFailure(ActionFailureKind.validation, _pretty(server), serverMessage: _pretty(server));
      case 503 when upload:
        return ActionFailure(ActionFailureKind.uploadUnavailable, _pretty(server).isEmpty ? 'File uploads are not available on this server.' : _pretty(server), serverMessage: _pretty(server));
      default:
        if (e.statusCode! >= 500) {
          return ActionFailure(ActionFailureKind.server, 'The server had a problem and couldn\'t $what. $keep Try again.');
        }
        return ActionFailure(ActionFailureKind.other, _pretty(server));
    }
  }

  static String _pretty(String s) => s.isEmpty || s == 'Something went wrong. Please try again.' ? '' : s;

  bool get isForbidden => kind == ActionFailureKind.forbidden;

  /// Resending the same request can succeed only after a transient failure (offline / 5xx / unknown). A 400 / 403 / 404 / 409 answer is
  /// the server's verdict on the content: the teacher has to change something (or reload) first.
  bool get canRetry => kind == ActionFailureKind.offline || kind == ActionFailureKind.server || kind == ActionFailureKind.other;
}
