import 'package:shared_preferences/shared_preferences.dart';
import 'secure_storage_service.dart';

/// Static, app-wide access to locally persisted account state. The access
/// token goes through [SecureStorageService] (Keychain / encrypted
/// storage) since it's a real credential - everything else here is plain
/// SharedPreferences and deliberately non-sensitive.
class AppPreferences {
  AppPreferences._();

  static const _keySchoolSlug = 'eldermin_teacher_school_slug';
  static const _keyIntroSeen = 'eldermin_teacher_intro_seen';

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

  static Future<void> clearSchoolSlug() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySchoolSlug);
  }

  static Future<String?> getSchoolSlug() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySchoolSlug);
  }

  // ── First-launch intro ───────────────────────────────────────
  static Future<bool> isIntroSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIntroSeen) ?? false;
  }

  static Future<void> setIntroSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIntroSeen, true);
  }

  /// Full sign-out - wipes the token and every cached preference so the
  /// next login starts completely clean and never leaks one account's
  /// data into another's session. Two non-sensitive device-level
  /// conveniences survive: the "intro seen" flag and the last school code.
  static Future<void> clearPreference() async {
    await _secureStorage.clearToken();
    final prefs = await SharedPreferences.getInstance();
    final introSeen = prefs.getBool(_keyIntroSeen);
    final slug = prefs.getString(_keySchoolSlug);
    await prefs.clear();
    if (introSeen != null) await prefs.setBool(_keyIntroSeen, introSeen);
    if (slug != null) await prefs.setString(_keySchoolSlug, slug);
  }
}
