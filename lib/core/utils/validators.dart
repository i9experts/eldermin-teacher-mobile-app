/// Pure form validators (return an error message, or null when valid).
class Validators {
  Validators._();

  static final RegExp _email = RegExp(r"^[^\s@]+@[^\s@]+\.[^\s@]{2,}$");

  /// Minimum new-password length: backend `ResetPasswordDto` is
  /// `@MinLength(6)` (eldermin-backend/src/modules/auth/auth.controller.ts).
  static const int minPasswordLength = 6;

  static String? email(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Enter your email address.';
    if (!_email.hasMatch(v)) return 'Enter a valid email address.';
    return null;
  }

  static String? requiredPassword(String? value) =>
      (value == null || value.isEmpty) ? 'Enter your password.' : null;

  static String? newPassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Enter a new password.';
    if (v.length < minPasswordLength) return 'Password must be at least $minPasswordLength characters.';
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) return 'Confirm your new password.';
    if (value != password) return "Passwords don't match.";
    return null;
  }
}
