import '../api/api_exception.dart';

/// What the user reads when a request fails. Same texts as the web client
/// (web/src/lib/api.ts): the server's message when it sent one, otherwise a
/// friendly sentence instead of the client's technical codes.
abstract final class ErrorText {
  static const unreachable =
      'Can’t reach Hacky. Check your connection and try again.';
  static const unavailable =
      'This part of Hacky isn’t available yet. Please try again later.';
  static const unexpected =
      'Hacky sent an unexpected response. Please try again.';
  static const generic = 'Something went wrong. Please try again.';

  static String of(Object error) {
    if (error is! ApiException) return generic;
    return switch (error.code) {
      'network_error' || 'timeout' => unreachable,
      'invalid_response' => unexpected,
      'http_404' || 'http_501' => unavailable,
      final code when code.startsWith('http_') => unexpected,
      _ => error.message,
    };
  }
}
