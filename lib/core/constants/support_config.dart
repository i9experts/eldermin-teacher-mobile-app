/// Where "Contact support" on the Help screen points. NOTHING is hard-coded: the app ships without a support address until the school / owner
/// provides one, and the Help card is shown only when at least one value is set, e.g.
/// `--dart-define=SUPPORT_EMAIL=help@school.example --dart-define=SUPPORT_URL=https://school.example/help`.
class SupportConfig {
  SupportConfig._();

  static const String _email = String.fromEnvironment('SUPPORT_EMAIL');
  static const String _url = String.fromEnvironment('SUPPORT_URL');

  /// Overridable in tests (compile-time defines cannot change at runtime).
  static String? emailOverride;
  static String? urlOverride;

  static final RegExp _emailRe = RegExp(r'^[^\s@<>]+@[^\s@<>]+\.[^\s@<>]+$');

  /// A well-formed address, or null.
  static String? get email {
    final v = (emailOverride ?? _email).trim();
    return _emailRe.hasMatch(v) ? v : null;
  }

  /// An absolute https URL, or null (plain http is not accepted for a support page).
  static Uri? get url {
    final u = Uri.tryParse((urlOverride ?? _url).trim());
    return u != null && u.scheme == 'https' && u.host.isNotEmpty ? u : null;
  }

  static bool get isConfigured => email != null || url != null;
}
