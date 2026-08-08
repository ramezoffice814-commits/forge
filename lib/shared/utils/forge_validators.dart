/// Form-field validators shared across sign-in, sign-up, and
/// forgot-password. Each returns a short, accessible error string (read by
/// screen readers via `TextFormField`'s error semantics) or `null` when
/// valid.
abstract final class ForgeValidators {
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Minimum length only — length is a better security lever than forced
  /// symbol/number combinations, and easier for users (and password
  /// managers) to satisfy predictably.
  static const passwordMinLength = 8;

  static String? email(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Email is required.';
    if (!_emailPattern.hasMatch(trimmed)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required.';
    if (v.length < passwordMinLength) {
      return 'Use at least $passwordMinLength characters.';
    }
    return null;
  }

  /// Pass the *current* password value at call time (e.g.
  /// `(v) => ForgeValidators.matchesPassword(v, passwordController.text)`)
  /// rather than capturing it once — otherwise the check runs against
  /// whatever the password field held at the moment the validator closure
  /// was built, not what it holds now.
  static String? matchesPassword(String? value, String password) {
    if (value == null || value.isEmpty) return 'Confirm your password.';
    if (value != password) return "Passwords don't match.";
    return null;
  }

  static String? displayName(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Display name is required.';
    if (trimmed.length < 2) return 'Use at least 2 characters.';
    return null;
  }
}
