import 'password_rules.dart';

/// Form field checks. The web gets most of these from the browser
/// (`required`, `type="email"`, `pattern`); the limits match web/src/AuthPages.tsx.
abstract final class FieldRules {
  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final _handle = RegExp(r'^[a-z0-9_]{3,30}$');

  static const handleHint = '3–30 lowercase letters, numbers, or underscores.';
  static const passwordHint = 'At least 8 characters. Up to 72 UTF-8 bytes.';

  /// Trimmed and lowercased, like the web sends it.
  static String normalizeEmail(String value) => value.trim().toLowerCase();

  static String? email(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) return 'Enter your email address.';
    if (!_email.hasMatch(email)) return 'Enter a valid email address.';
    return null;
  }

  static String? name(String? value) => (value ?? '').trim().isEmpty
      ? 'Enter your name so your teammates know what to call you.'
      : null;

  static String? handle(String? value) =>
      _handle.hasMatch((value ?? '').trim()) ? null : handleHint;

  /// Login only checks that a password was typed.
  static String? loginPassword(String? value) =>
      (value ?? '').isEmpty ? 'Enter your password.' : null;

  static String? newPassword(String? value) =>
      PasswordRules.problem(value ?? '');
}
