import '../../../../core/network/api_exception.dart';

enum SectionStatus { loading, data, empty, error, unavailable, forbidden }

/// State of ONE independent Home section. A failure in one section never
/// touches another.
class SectionState<T> {
  final SectionStatus status;
  final T? data;
  final String? message;

  const SectionState._(this.status, {this.data, this.message});

  const SectionState.loading({T? previous}) : this._(SectionStatus.loading, data: previous);
  const SectionState.data(T data) : this._(SectionStatus.data, data: data);
  const SectionState.empty() : this._(SectionStatus.empty);
  const SectionState.error(String message) : this._(SectionStatus.error, message: message);
  const SectionState.unavailable() : this._(SectionStatus.unavailable, message: 'Not available yet');
  const SectionState.forbidden() : this._(SectionStatus.forbidden, message: "You don't have access");

  /// 403 -> forbidden; 404/501 -> "feature not available yet"; 5xx -> a calm
  /// server message; offline / timeout messages come from the network layer.
  factory SectionState.fromError(Object e) {
    if (e is ApiException) {
      final code = e.statusCode;
      if (code == 403) return const SectionState.forbidden();
      if (code == 404 || code == 501) return const SectionState.unavailable();
      if (code != null && code >= 500) {
        return const SectionState.error('The server had a problem. Please try again.');
      }
      return SectionState.error(e.message);
    }
    return const SectionState.error("Couldn't load this section. Please try again.");
  }

  bool get isLoading => status == SectionStatus.loading;
  bool get hasData => data != null && status == SectionStatus.data;
}
