import '../../core/network/api_exception.dart';

enum ActionFailureKind { offline, forbidden, notFound, validation, server, other }

/// Teacher-readable outcome of a failed write (create / edit / delete / grade / upload / log). Maps the real error shape
/// `{statusCode, message, timestamp, path}` (filters/sentry.filter.ts:43-48; an array `message` is cut to its first element
/// there). A null status code means no response at all (offline / timeout). The SERVER message is always shown for 400/422/403
/// (it is the validation text, e.g. "Grade cannot exceed this assignment's maximum of 100.").
class ActionFailure {
  final ActionFailureKind kind;
  final String message;
  const ActionFailure(this.kind, this.message);

  /// [what] completes "You can't …": e.g. "edit this homework".
  factory ActionFailure.from(Object e, {required String what, String keep = 'Your changes are kept.'}) {
    if (e is! ApiException) return ActionFailure(ActionFailureKind.other, "Couldn't $what. $keep Try again.");
    final server = e.message.trim();
    switch (e.statusCode) {
      case null:
        return ActionFailure(ActionFailureKind.offline, '$server $keep Reconnect and try again.');
      case 403:
        return ActionFailure(ActionFailureKind.forbidden, "You can't $what. ${_pretty(server)}");
      case 404:
        return ActionFailure(ActionFailureKind.notFound, 'This was not found on the server: it may have been removed. ${_pretty(server)}');
      case 400:
      case 413:
      case 422:
        return ActionFailure(ActionFailureKind.validation, _pretty(server));
      default:
        if (e.statusCode! >= 500) {
          return ActionFailure(ActionFailureKind.server, 'The server had a problem and couldn\'t $what. $keep Try again.');
        }
        return ActionFailure(ActionFailureKind.other, _pretty(server));
    }
  }

  static String _pretty(String s) => s.isEmpty || s == 'Something went wrong. Please try again.' ? '' : s;

  bool get isForbidden => kind == ActionFailureKind.forbidden;
}
