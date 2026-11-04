/// Route names. Screens navigate by name so they don't import each other.
abstract final class Routes {
  static const login = '/login';
  static const register = '/register';

  /// Argument: the email the link was sent to (`String?`).
  static const checkEmail = '/check-email';
  static const forgotPassword = '/forgot-password';

  /// Argument: the signed-in user (`Me?`). Loaded from the API when null.
  static const account = '/account';
}
