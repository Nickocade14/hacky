import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/api_exception.dart';
import 'package:mobile/api/models/auth.dart';
import 'package:mobile/dev/fake_api_client.dart';

import '../support/screen_harness.dart';

Matcher apiError(String code) =>
    isA<ApiException>().having((e) => e.code, 'code', code);

void main() {
  test('register, verify by resending, log in, load me, log out', () async {
    final (:api, :store) = fakeApi();
    const email = 'ethan@example.com';
    await api.register(
      const RegisterBody(
        name: 'Ethan Zeng',
        handle: 'ethan_z',
        email: email,
        password: 'correct-password',
      ),
    );

    const login = LoginBody(email: email, password: 'correct-password');
    await expectLater(
      api.login(login),
      throwsA(apiError('email_not_verified')),
    );

    await api.resendVerification(const EmailBody(email: email));
    final result = await api.login(login);
    expect(result.me.profile.name, 'Ethan Zeng');
    expect(store.token, result.token);
    expect(await api.isLoggedIn, isTrue);
    expect((await api.getMe()).profile.handle, 'ethan_z');

    await api.logout();
    expect(await api.isLoggedIn, isFalse);
  });

  test('rejects a wrong password and taken email or handle', () async {
    final (:api, store: _) = fakeApi();
    await expectLater(
      api.login(
        const LoginBody(email: FakeApiClient.demoEmail, password: 'wrong'),
      ),
      throwsA(apiError('invalid_credentials')),
    );
    await expectLater(
      api.register(
        const RegisterBody(
          name: 'X',
          handle: 'someone_new',
          email: FakeApiClient.demoEmail,
          password: 'password123',
        ),
      ),
      throwsA(apiError('email_taken')),
    );
    await expectLater(
      api.register(
        const RegisterBody(
          name: 'X',
          handle: 'demo_hacker',
          email: 'x@example.com',
          password: 'password123',
        ),
      ),
      throwsA(apiError('handle_taken')),
    );
  });

  test('a stale token gets a 401 and is forgotten', () async {
    final (:api, :store) = fakeApi();
    store.token = 'fake-jwt:nobody@example.com';
    await expectLater(api.getMe(), throwsA(apiError('unauthorized')));
    expect(store.token, isNull);
  });

  test('the offline email fails like a lost connection', () async {
    final (:api, store: _) = fakeApi();
    await expectLater(
      api.forgotPassword(const EmailBody(email: FakeApiClient.offlineEmail)),
      throwsA(apiError('network_error')),
    );
  });
}
