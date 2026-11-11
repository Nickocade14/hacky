import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/api_exception.dart';
import 'package:mobile/auth/error_text.dart';
import 'package:mobile/auth/field_rules.dart';
import 'package:mobile/auth/password_rules.dart';

void main() {
  group('PasswordRules (same boundaries as the web tests)', () {
    test('rejects 7 code points, even if they are many bytes', () {
      expect(
        PasswordRules.problem('🦄' * 7),
        contains('at least 8 characters'),
      );
    });
    test('accepts 8 code points', () {
      expect(PasswordRules.problem('🦄' * 8), isNull);
    });
    test('accepts exactly 72 UTF-8 bytes', () {
      expect(PasswordRules.problem('🦄' * 18), isNull);
    });
    test('rejects 73 UTF-8 bytes', () {
      expect(
        PasswordRules.problem('${'🦄' * 18}a'),
        contains('at most 72 UTF-8 bytes'),
      );
    });
  });

  group('FieldRules', () {
    test('email', () {
      expect(FieldRules.email(''), 'Enter your email address.');
      expect(FieldRules.email('nope'), 'Enter a valid email address.');
      expect(FieldRules.email(' a@b.co '), isNull);
      expect(
        FieldRules.normalizeEmail(' ETHAN@Example.COM '),
        'ethan@example.com',
      );
    });
    test('handle follows the contract pattern after normalizing', () {
      expect(FieldRules.handle('ethan_z'), isNull);
      // Sent lowercased and without the @, like the server stores it.
      expect(FieldRules.handle(' @Ethan_Z '), isNull);
      expect(FieldRules.normalizeHandle(' @Ethan_Z '), 'ethan_z');
      expect(FieldRules.handle('ab'), FieldRules.handleHint);
      expect(FieldRules.handle('Ethan Z'), FieldRules.handleHint);
      expect(FieldRules.handle('a' * 31), FieldRules.handleHint);
    });
    test('login takes an email or a username', () {
      expect(FieldRules.login('nico@ucf.edu'), isNull);
      expect(FieldRules.login('nico_c'), isNull);
      expect(FieldRules.login('@Nico_C'), isNull);
      expect(FieldRules.login(''), 'Enter your email or username.');
      expect(FieldRules.login('nico c'), 'Enter a valid email or username.');
      expect(FieldRules.login('nico@ucf'), 'Enter a valid email address.');
      expect(FieldRules.normalizeLogin(' Nico@UCF.edu '), 'nico@ucf.edu');
      expect(FieldRules.normalizeLogin(' @Nico_C '), 'nico_c');
    });
    test('code is 6 digits', () {
      expect(FieldRules.code('482913'), isNull);
      expect(FieldRules.code(' 482913 '), isNull);
      for (final code in ['', '12345', '1234567', '12345a']) {
        expect(FieldRules.code(code), 'Enter the 6-digit code from the email.');
      }
    });
    test('name must not be blank', () {
      expect(FieldRules.name('   '), contains('Enter your name'));
      expect(FieldRules.name('Ethan'), isNull);
    });
  });

  group('ErrorText', () {
    ApiException error(String code, [int? status]) =>
        ApiException(statusCode: status, code: code, message: 'server says hi');

    test('keeps the server message for contract errors', () {
      expect(ErrorText.of(error('invalid_credentials', 401)), 'server says hi');
    });
    test('replaces client-side codes with the web texts', () {
      expect(ErrorText.of(error('network_error')), ErrorText.unreachable);
      expect(ErrorText.of(error('timeout')), ErrorText.unreachable);
      expect(
        ErrorText.of(error('invalid_response', 200)),
        ErrorText.unexpected,
      );
      expect(ErrorText.of(error('http_404', 404)), ErrorText.unavailable);
      expect(ErrorText.of(error('http_502', 502)), ErrorText.unexpected);
      expect(ErrorText.of(StateError('boom')), ErrorText.generic);
    });
  });
}
