/// A recognised, validated incoming link.
sealed class DeepLink {
  const DeepLink();
}

/// `eldermin-teacher://reset-password?token=<t>` (or the https equivalent).
class ResetPasswordLink extends DeepLink {
  final String token;
  const ResetPasswordLink(this.token);
}

/// `eldermin-teacher://login?token=<jwt>&slug=<slug>` (web parity with
/// `/login?token=&slug=`).
class TokenLoginLink extends DeepLink {
  final String token;
  final String slug;
  const TokenLoginLink({required this.token, required this.slug});
}

/// Pure, side-effect-free parsing + validation of incoming links. Anything
/// that is not exactly a supported link returns null - callers never act on
/// unvalidated input. NEVER log the input: it carries credentials.
class DeepLinkParser {
  DeepLinkParser._();

  static const String customScheme = 'eldermin-teacher';

  /// Hosts accepted for https links (future verified app links). Plain
  /// http is never accepted.
  static const Set<String> webHosts = {'app.eldermin.com'};

  static const String _hostReset = 'reset-password';
  static const String _hostLogin = 'login';

  /// Reset tokens are 64 hex chars today; allow a generous opaque range.
  static const int maxResetTokenLength = 512;
  static const int minResetTokenLength = 8;

  /// A JWT is ~300-600 chars; cap well above that but bound abuse.
  static const int maxJwtLength = 4096;

  static final RegExp _resetTokenChars = RegExp(r'^[A-Za-z0-9._~\-]+$');
  static final RegExp _jwtChars = RegExp(r'^[A-Za-z0-9_\-]+(\.[A-Za-z0-9_\-]+){2}$');
  static final RegExp _slugChars = RegExp(r'^[a-z0-9](?:[a-z0-9\-]{0,62})$');

  /// Parses a link; null when it is not a supported, well-formed one.
  static DeepLink? parse(Uri uri) {
    final String kind;
    if (uri.scheme == customScheme) {
      if (uri.userInfo.isNotEmpty || uri.hasPort) return null;
      if (uri.path.isNotEmpty && uri.path != '/') return null;
      kind = uri.host.toLowerCase();
    } else if (uri.scheme == 'https') {
      if (!webHosts.contains(uri.host.toLowerCase())) return null;
      if (uri.userInfo.isNotEmpty || (uri.hasPort && uri.port != 443)) return null;
      var path = uri.path.toLowerCase();
      if (path.endsWith('/') && path.length > 1) path = path.substring(0, path.length - 1);
      if (path == '/reset-password') {
        kind = _hostReset;
      } else if (path == '/login') {
        kind = _hostLogin;
      } else {
        return null;
      }
    } else {
      return null; // javascript:, http:, file:, content:, ...
    }

    switch (kind) {
      case _hostReset:
        final token = _single(uri, 'token');
        if (token == null || !isValidResetToken(token)) return null;
        return ResetPasswordLink(token);
      case _hostLogin:
        final token = _single(uri, 'token');
        final slug = _single(uri, 'slug');
        if (token == null || slug == null) return null;
        if (token.length > maxJwtLength || !_jwtChars.hasMatch(token)) return null;
        final normalizedSlug = slug.trim().toLowerCase();
        if (!_slugChars.hasMatch(normalizedSlug)) return null;
        return TokenLoginLink(token: token, slug: normalizedSlug);
      default:
        return null;
    }
  }

  /// Parses a raw string (e.g. from the OS or the clipboard).
  static DeepLink? parseString(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed.length > maxJwtLength + 256) return null;
    final uri = Uri.tryParse(trimmed);
    return uri == null ? null : parse(uri);
  }

  static bool isValidResetToken(String token) =>
      token.length >= minResetTokenLength &&
      token.length <= maxResetTokenLength &&
      _resetTokenChars.hasMatch(token);

  /// Manual "Paste reset code or link" fallback: accepts a bare token or a
  /// full https / custom-scheme reset link and returns the token, else null.
  static String? extractResetToken(String input) {
    final value = input.trim();
    if (value.isEmpty) return null;
    if (value.contains(RegExp(r'[:/?#]'))) {
      final link = parseString(value);
      return link is ResetPasswordLink ? link.token : null;
    }
    return isValidResetToken(value) ? value : null;
  }

  /// The value of [name] when it appears exactly once and is non-empty.
  static String? _single(Uri uri, String name) {
    final all = uri.queryParametersAll[name];
    if (all == null || all.length != 1) return null;
    final v = all.first;
    return v.isEmpty ? null : v;
  }
}
