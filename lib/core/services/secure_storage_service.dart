import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wraps flutter_secure_storage (Keychain on iOS, EncryptedSharedPreferences
/// on Android) - the JWT is never stored in plain SharedPreferences, since
/// it's a real credential granting access to school and student data. Used
/// only by [AppPreferences]; nothing else should touch this directly.
class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyToken = 'eldermin_teacher_token';

  Future<void> saveToken(String token) => _storage.write(key: _keyToken, value: token);
  Future<String?> getToken() => _storage.read(key: _keyToken);
  Future<void> clearToken() => _storage.delete(key: _keyToken);
}
