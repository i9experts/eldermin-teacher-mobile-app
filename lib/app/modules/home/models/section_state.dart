import '../../../../core/network/api_exception.dart';

const String kForbiddenDefault = "You don't have access";

/// The server's own 403 text when it says something specific (for example "No campus assigned — contact your administrator"), else null so the
/// screen keeps the generic "You don't have access". Nest's stock texts ("Forbidden resource", "Forbidden") and anything blank or very long are not shown.
String? forbiddenDetailOf(String? serverMessage) {
  final m = (serverMessage ?? '').trim();
  if (m.isEmpty || m.length > 200) return null;
  const generic = {'forbidden', 'forbidden resource', 'access denied', 'unauthorized', 'something went wrong. please try again.'};
  final l = m.toLowerCase();
  // the backend's role-guard text ("Access denied. Your role does not have view|manage access to teaching:fixtures.") names internal module keys
  if (generic.contains(l) || l.startsWith('access denied') || l.contains('your role does not have')) return null;
  return m;
}

enum SectionStatus { loading, data, empty, error, unavailable, forbidden }

/// State of ONE independent Home section. A failure in one section never
/// touches another. A failed REFRESH keeps the last good data in [data] (status
/// [SectionStatus.error], see [isStale]) so the screen can show it under a
/// "Refresh failed - Retry" banner; a failed FIRST load has no data and shows the
/// plain error card.
class SectionState<T> {
  final SectionStatus status;
  final T? data;
  final String? message;

  const SectionState._(this.status, {this.data, this.message});

  const SectionState.loading({T? previous}) : this._(SectionStatus.loading, data: previous);
  const SectionState.data(T data) : this._(SectionStatus.data, data: data);
  const SectionState.empty() : this._(SectionStatus.empty);
  const SectionState.error(String message, {T? stale}) : this._(SectionStatus.error, data: stale, message: message);
  const SectionState.unavailable() : this._(SectionStatus.unavailable, message: 'Not available yet');
  const SectionState.forbidden({String? detail}) : this._(SectionStatus.forbidden, message: detail ?? kForbiddenDefault);

  /// 403 -> forbidden; 404/501 -> "feature not available yet"; 5xx -> a calm
  /// server message; offline / timeout messages come from the network layer.
  /// With [previous] holding data, a transient failure (status error) keeps that
  /// data as stale; 403 / 404 / 501 replace it (access gone / feature missing).
  factory SectionState.fromError(Object e, {SectionState<T>? previous}) {
    final failed = SectionState._classify<T>(e);
    final keep = previous?.data;
    if (keep != null && failed.status == SectionStatus.error) {
      return SectionState<T>.error(failed.message!, stale: keep);
    }
    return failed;
  }

  static SectionState<T> _classify<T>(Object e) {
    if (e is ApiException) {
      final code = e.statusCode;
      if (code == 403) return SectionState.forbidden(detail: forbiddenDetailOf(e.message));
      if (code == 404 || code == 501) return const SectionState.unavailable();
      if (code != null && code >= 500) {
        return const SectionState.error('The server had a problem. Please try again.');
      }
      return SectionState.error(e.message);
    }
    return const SectionState.error("Couldn't load this section. Please try again.");
  }

  /// For [SectionStatus.forbidden]: the specific server message, or null for the generic wording.
  String? get forbiddenDetail => status == SectionStatus.forbidden && message != kForbiddenDefault ? message : null;

  bool get isLoading => status == SectionStatus.loading;
  /// Data to show: fresh, or the last good data under a failed refresh.
  bool get hasData => data != null && (status == SectionStatus.data || status == SectionStatus.error);

  /// A failed refresh that still carries the previous data.
  bool get isStale => status == SectionStatus.error && data != null;
}
