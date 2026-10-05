import 'package:shared_preferences/shared_preferences.dart';
import 'secure_storage_service.dart';

/// Static, app-wide access to locally persisted account state. The access
/// token goes through [SecureStorageService] (Keychain / encrypted
/// storage) since it's a real credential - everything else here is plain
/// SharedPreferences and deliberately non-sensitive.
class AppPreferences {
  AppPreferences._();

  static const _keySchoolSlug = 'eldermin_teacher_school_slug';

  static final _secureStorage = SecureStorageService();

  // ── Access token ─────────────────────────────────────────────
  static Future<void> setAccessToken(String token) => _secureStorage.saveToken(token);
  static Future<String?> getAccessTokenAsync() => _secureStorage.getToken();
  static Future<void> clearAccessToken() => _secureStorage.clearToken();

  static Future<bool> isLoggedIn() async {
    final token = await getAccessTokenAsync();
    return token != null && token.isNotEmpty;
  }

  // ── Last used school code (login convenience) ────────────────
  static Future<void> saveSchoolSlug(String slug) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySchoolSlug, slug);
  }

  static Future<String?> getSchoolSlug() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySchoolSlug);
  }

  /// Full sign-out - wipes the token and every cached preference so the
  /// next login starts completely clean and never leaks one account's
  /// data into another's session.
  static Future<void> clearPreference() async {
    await _secureStorage.clearToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
