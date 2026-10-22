import 'validators.dart';

/// Display-only password strength (0-4) for the reset screen's four nodes.
///
/// The app had no strength rules, only the minimum length
/// ([Validators.minPasswordLength]), and that stays the only thing that
/// blocks a submit. This just scores what was typed:
///
///   1  anything typed
///   +1 at least the minimum length
///   +1 three or more of: lower case, upper case, digit, symbol
///   +1 12+ characters with two or more of those classes
class PasswordStrength {
  PasswordStrength._();

  static const labels = ['', 'Weak', 'Fair', 'Good', 'Strong'];

  static int of(String password) {
    if (password.isEmpty) return 0;
    final classes = [
      RegExp('[a-z]'),
      RegExp('[A-Z]'),
      RegExp('[0-9]'),
      RegExp(r'[^A-Za-z0-9]'),
    ].where((r) => r.hasMatch(password)).length;
    var s = 1;
    if (password.length >= Validators.minPasswordLength) s++;
    if (classes >= 3) s++;
    if (password.length >= 12 && classes >= 2) s++;
    return s.clamp(1, 4);
  }
}
