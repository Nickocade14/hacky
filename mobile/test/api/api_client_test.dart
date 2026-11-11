import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api/api_client.dart';
import 'package:mobile/api/api_exception.dart';
import 'package:mobile/api/models/auth.dart';
import 'package:mobile/api/token_store.dart';

const baseUrl = 'https://api.test';

class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([this.token]);

  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String token) async => this.token = token;

  @override
  Future<void> clear() async => token = null;
}

/// A `Me` matching docs/openapi.yaml.
final meJson = {
  'profile': {
    'userId': '6716a3f2c9e77b0012ab34cd',
    'handle': 'nico_c',
    'name': 'Nicolas Cadena',
    'hackyStyle': {'look': 'knit', 'avatar': 'hacky'},
    'photoUrl': null,
    'bio': null,
    'links': {'github': 'https://github.com/Nickocade14'},
    'isDemo': false,
  },
  'events': [
    {
      'slug': 'knighthacks-ix',
      'name': 'KnightHacks IX',
      'role': 'hacker',
      'verified': true,
    },
  ],
};

http.Response jsonResponse(Object body, int status) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

http.Response apiError(int status, String code, String message) =>
    jsonResponse({
      'error': {'code': code, 'message': message},
    }, status);

void main() {
  late MemoryTokenStore store;
  late List<http.Request> requests;

  /// A client whose server answers every request with [handler].
  ApiClient clientWith(
    Future<http.Response> Function(http.Request) handler, {
    String url = baseUrl,
    Duration timeout = const Duration(seconds: 15),
  }) => ApiClient(
    tokenStore: store,
    baseUrl: url,
    timeout: timeout,
    httpClient: MockClient((request) {
      requests.add(request);
      return handler(request);
    }),
  );

  setUp(() {
    store = MemoryTokenStore();
    requests = [];
  });

  group('login', () {
    test('posts the LoginBody as JSON without a bearer header', () async {
      store.token = 'old-token';
      final client = clientWith(
        (_) async => jsonResponse({
          'token': 'new-jwt',
          'expiresAt': '2026-11-10T12:00:00.000Z',
          'me': meJson,
        }, 200),
      );

      await client.login(
        const LoginBody(email: 'nico@example.com', password: 'secret-pass'),
      );

      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.url.toString(), '$baseUrl/api/auth/login');
      expect(request.headers['Content-Type'], startsWith('application/json'));
      expect(request.headers.containsKey('Authorization'), isFalse);
      expect(jsonDecode(request.body), {
        'email': 'nico@example.com',
        'password': 'secret-pass',
      });
    });

    test('parses the LoginResult and saves the token', () async {
      final client = clientWith(
        (_) async => jsonResponse({
          'token': 'new-jwt',
          'expiresAt': '2026-11-10T12:00:00.000Z',
          'me': meJson,
        }, 200),
      );

      final result = await client.login(
        const LoginBody(email: 'nico@example.com', password: 'secret-pass'),
      );

      expect(result.token, 'new-jwt');
      expect(result.expiresAt, DateTime.utc(2026, 11, 10, 12));
      expect(result.me.profile.handle, 'nico_c');
      expect(result.me.profile.photoUrl, isNull);
      expect(result.me.profile.links.github, 'https://github.com/Nickocade14');
      expect(result.me.profile.hackyStyle['look'], 'knit');
      expect(result.me.events.single.role, MemberRole.hacker);
      expect(store.token, 'new-jwt');
      expect(await client.isLoggedIn, isTrue);
    });

    test(
      'a wrong password throws the server error and keeps no token',
      () async {
        final client = clientWith(
          (_) async =>
              apiError(401, 'invalid_credentials', 'Wrong email or password'),
        );

        await expectLater(
          client.login(const LoginBody(email: 'a@b.co', password: 'nope-nope')),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'statusCode', 401)
                .having((e) => e.code, 'code', 'invalid_credentials')
                .having((e) => e.message, 'message', 'Wrong email or password'),
          ),
        );
        expect(store.token, isNull);
      },
    );

    test('an unverified email throws email_not_verified', () async {
      final client = clientWith(
        (_) async => apiError(403, 'email_not_verified', 'Verify your email'),
      );

      await expectLater(
        client.login(const LoginBody(email: 'a@b.co', password: 'password1')),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            'email_not_verified',
          ),
        ),
      );
    });
  });

  group('other auth routes', () {
    test('send their bodies to the contract paths', () async {
      final client = clientWith((_) async => jsonResponse({'ok': true}, 200));

      await client.register(
        const RegisterBody(
          name: 'Nicolas Cadena',
          handle: 'nico_c',
          email: 'nico@example.com',
          password: 'secret-pass',
        ),
      );
      await client.resendVerification(
        const EmailBody(email: 'nico@example.com'),
      );
      await client.forgotPassword(const EmailBody(email: 'nico@example.com'));

      expect(requests.map((r) => '${r.method} ${r.url.path}'), [
        'POST /api/auth/register',
        'POST /api/auth/resend-verification',
        'POST /api/auth/forgot-password',
      ]);
      expect(jsonDecode(requests[0].body), {
        'name': 'Nicolas Cadena',
        'handle': 'nico_c',
        'email': 'nico@example.com',
        'password': 'secret-pass',
      });
      expect(jsonDecode(requests[1].body), {'email': 'nico@example.com'});
      for (final request in requests) {
        expect(request.headers.containsKey('Authorization'), isFalse);
      }
    });

    test('verify-email and reset-password send the code and log in', () async {
      final client = clientWith(
        (_) async => jsonResponse({
          'token': 'code-jwt',
          'expiresAt': '2026-11-10T12:00:00.000Z',
          'me': meJson,
        }, 200),
      );

      final verified = await client.verifyEmail(
        const VerifyCodeBody(email: 'nico@example.com', code: '482913'),
      );
      expect(verified.me.profile.handle, 'nico_c');
      expect(store.token, 'code-jwt');

      store.token = null;
      await client.resetPassword(
        const ResetCodeBody(
          email: 'nico@example.com',
          code: '123456',
          password: 'new-password',
        ),
      );
      expect(store.token, 'code-jwt');

      expect(requests.map((r) => '${r.method} ${r.url.path}'), [
        'POST /api/auth/verify-email',
        'POST /api/auth/reset-password',
      ]);
      expect(jsonDecode(requests[0].body), {
        'email': 'nico@example.com',
        'code': '482913',
      });
      expect(jsonDecode(requests[1].body), {
        'email': 'nico@example.com',
        'code': '123456',
        'password': 'new-password',
      });
      for (final request in requests) {
        expect(request.headers.containsKey('Authorization'), isFalse);
      }
    });

    test('a wrong code throws invalid_code and saves no token', () async {
      final client = clientWith(
        (_) async => apiError(400, 'invalid_code', 'That code is wrong'),
      );

      await expectLater(
        client.verifyEmail(
          const VerifyCodeBody(email: 'nico@example.com', code: '000000'),
        ),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'invalid_code')),
      );
      expect(store.token, isNull);
    });

    test('a taken handle throws handle_taken with status 409', () async {
      final client = clientWith(
        (_) async => apiError(409, 'handle_taken', 'That handle is taken'),
      );

      await expectLater(
        client.register(
          const RegisterBody(
            name: 'N',
            handle: 'nico_c',
            email: 'n@example.com',
            password: 'secret-pass',
          ),
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 409)
              .having((e) => e.code, 'code', 'handle_taken'),
        ),
      );
    });

    test('invalid input errors include the field details', () async {
      final client = clientWith(
        (_) async => jsonResponse({
          'error': {
            'code': 'invalid_input',
            'message': 'Invalid input',
            'details': [
              {
                'path': ['password'],
                'message': 'Too short',
              },
            ],
          },
        }, 400),
      );

      await expectLater(
        client.resetPassword(
          const ResetCodeBody(
            email: 'a@b.co',
            code: '123456',
            password: 'short',
          ),
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'invalid_input')
              .having((e) => e.details.single.path, 'path', ['password'])
              .having((e) => e.details.single.message, 'message', 'Too short'),
        ),
      );
    });

    test('logout forgets the token', () async {
      store.token = 'jwt';
      final client = clientWith((_) async => jsonResponse({}, 200));

      await client.logout();

      expect(store.token, isNull);
      expect(await client.isLoggedIn, isFalse);
      expect(requests, isEmpty);
    });
  });

  group('authenticated routes', () {
    test('send Authorization: Bearer with the stored token', () async {
      store.token = 'my-jwt';
      final client = clientWith((_) async => jsonResponse(meJson, 200));

      final me = await client.getMe();

      expect(requests.single.method, 'GET');
      expect(requests.single.url.toString(), '$baseUrl/api/me');
      expect(requests.single.headers['Authorization'], 'Bearer my-jwt');
      expect(me.events.single.slug, 'knighthacks-ix');
    });

    test('send no Authorization header when logged out', () async {
      final client = clientWith(
        (_) async => apiError(401, 'unauthorized', 'Log in first'),
      );

      await expectLater(client.getMe(), throwsA(isA<ApiException>()));
      expect(requests.single.headers.containsKey('Authorization'), isFalse);
    });

    test('a 401 forgets the expired token', () async {
      store.token = 'expired-jwt';
      final client = clientWith(
        (_) async => apiError(401, 'unauthorized', 'Token expired'),
      );

      await expectLater(
        client.getMe(),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'unauthorized'),
        ),
      );
      expect(store.token, isNull);
    });

    test('other errors keep the token', () async {
      store.token = 'my-jwt';
      final client = clientWith(
        (_) async => apiError(429, 'rate_limited', 'Slow down'),
      );

      await expectLater(client.getMe(), throwsA(isA<ApiException>()));
      expect(store.token, 'my-jwt');
    });
  });

  group('errors without the contract body', () {
    test('a non-JSON error page becomes http_<status>', () async {
      final client = clientWith(
        (_) async => http.Response('<html>502 Bad Gateway</html>', 502),
      );

      await expectLater(
        client.forgotPassword(const EmailBody(email: 'a@b.co')),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 502)
              .having((e) => e.code, 'code', 'http_502'),
        ),
      );
    });

    test('JSON without an error object becomes http_<status>', () async {
      final client = clientWith((_) async => jsonResponse({'oops': 1}, 500));

      await expectLater(
        client.forgotPassword(const EmailBody(email: 'a@b.co')),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'http_500')),
      );
    });

    test(
      'a success that breaks the contract throws invalid_response',
      () async {
        store.token = 'my-jwt';
        final client = clientWith(
          (_) async =>
              jsonResponse({'profile': 'not an object', 'events': []}, 200),
        );

        await expectLater(
          client.getMe(),
          throwsA(
            isA<ApiException>()
                .having((e) => e.code, 'code', 'invalid_response')
                .having((e) => e.message, 'message', contains('profile')),
          ),
        );
      },
    );

    test('an unknown MemberRole throws invalid_response', () async {
      store.token = 'my-jwt';
      final badEvent = {
        ...(meJson['events'] as List).single as Map<String, dynamic>,
        'role': 'judge',
      };
      final client = clientWith(
        (_) async => jsonResponse({
          ...meJson,
          'events': [badEvent],
        }, 200),
      );

      await expectLater(
        client.getMe(),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'invalid_response'),
        ),
      );
    });

    test('a connection failure throws network_error', () async {
      final client = clientWith(
        (_) async => throw http.ClientException('Connection refused'),
      );

      await expectLater(
        client.forgotPassword(const EmailBody(email: 'a@b.co')),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', isNull)
              .having((e) => e.code, 'code', 'network_error'),
        ),
      );
    });

    test('a slow server throws timeout', () async {
      final client = clientWith((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return jsonResponse({'ok': true}, 200);
      }, timeout: const Duration(milliseconds: 20));

      await expectLater(
        client.forgotPassword(const EmailBody(email: 'a@b.co')),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'timeout')),
      );
    });
  });

  test('a trailing slash on the base URL is ignored', () async {
    final client = clientWith(
      (_) async => jsonResponse({'ok': true}, 200),
      url: '$baseUrl/',
    );

    await client.forgotPassword(const EmailBody(email: 'a@b.co'));

    expect(requests.single.url.toString(), '$baseUrl/api/auth/forgot-password');
  });
}
