import 'package:flutter/foundation.dart';

/// The only place the app writes to the console. Everything is behind [kDebugMode]: a release build logs nothing (no URLs, response bodies or
/// identifiers reach the device log). Use [AppLog.d]; never call `print` / `debugPrint` directly (test/core/release_hygiene_test.dart enforces it).
class AppLog {
  AppLog._();

  static void d(String message) {
    if (kDebugMode) debugPrint(message);
  }
}
