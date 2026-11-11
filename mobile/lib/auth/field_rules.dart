import 'password_rules.dart';

/// Form field checks. The web gets most of these from the browser
/// (`required`, `type="email"`, `pattern`); the limits match web/src/AuthPages.tsx.
abstract final class FieldRules {
  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final _handle = RegExp(r'^[a-z0-9_]{3,30}$');
  static final _code = RegExp(r'^[0-9]{6}$');

  static const handleHint = '3–30 lowercase letters, numbers, or underscores.';
  static const passwordHint = 'At least 8 characters.';

  /// Trimmed and lowercased, like the web sends it.
  static String normalizeEmail(String value) => value.trim().toLowerCase();

  /// Login takes an email or a username. Usernames can't contain `@`, so an
  /// `@` after the first character means an email (same rule as the server).
  static bool _isEmailLogin(String value) => value.trim().indexOf('@') > 0;

  static String normalizeLogin(String value) =>
      _isEmailLogin(value) ? normalizeEmail(value) : normalizeHandle(value);

  static String? login(String? value) {
    final login = (value ?? '').trim();
    if (login.isEmpty) return 'Enter your email or username.';
    if (_isEmailLogin(login)) return email(login);
    return handle(login) == null ? null : 'Enter a valid email or username.';
  }

  static String? email(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) return 'Enter your email address.';
    if (!_email.hasMatch(email)) return 'Enter a valid email address.';
    return null;
  }

  static String? name(String? value) => (value ?? '').trim().isEmpty
      ? 'Enter your name so your teammates know what to call you.'
      : null;

  /// The username (`handle` in the API). Checked as it's sent: trimmed and
  /// lowercased, with or without a typed `@`.
  static String? handle(String? value) =>
      _handle.hasMatch(normalizeHandle(value ?? '')) ? null : handleHint;

  static String normalizeHandle(String value) {
    final handle = value.trim().toLowerCase();
    return handle.startsWith('@') ? handle.substring(1) : handle;
  }

  static String? code(String? value) => _code.hasMatch((value ?? '').trim())
      ? null
      : 'Enter the 6-digit code from the email.';

  /// Login only checks that a password was typed.
  static String? loginPassword(String? value) =>
      (value ?? '').isEmpty ? 'Enter your password.' : null;

  static String? newPassword(String? value) =>
      PasswordRules.problem(value ?? '');
}
