import 'app_preferences.dart';

/// Seam over local session storage so [AuthController] can be unit
/// tested without platform channels.
abstract class TokenStore {
  Future<String?> readToken();
  Future<void> saveToken(String token);
  Future<void> clearAll();
}

/// Production implementation: JWT in secure storage via [AppPreferences].
class SecureTokenStore implements TokenStore {
  const SecureTokenStore();
  @override
  Future<String?> readToken() => AppPreferences.getAccessTokenAsync();
  @override
  Future<void> saveToken(String token) => AppPreferences.setAccessToken(token);
  @override
  Future<void> clearAll() => AppPreferences.clearPreference();
}
