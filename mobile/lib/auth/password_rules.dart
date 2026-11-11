import 'dart:convert';

/// Same password rules as `passwordProblem` in web/src/components.tsx
/// (and the contract: 8 characters minimum, bcrypt's 72-byte maximum).
abstract final class PasswordRules {
  static const minCharacters = 8;
  static const maxBytes = 72;

  /// The problem with [password], or null when it's fine.
  static String? problem(String password) {
    if (password.runes.length < minCharacters) {
      return 'Use at least 8 characters for your password.';
    }
    if (utf8.encode(password).length > maxBytes) {
      // bcrypt only reads 72 bytes; emoji count as several.
      return 'That password is too long. Try a shorter one.';
    }
    return null;
  }
}
