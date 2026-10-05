/// Thrown when the backend returns an error - the UI checks statusCode
/// to route appropriately (401 -> logout, 403 -> access-denied message,
/// everything else -> the message itself).
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}
