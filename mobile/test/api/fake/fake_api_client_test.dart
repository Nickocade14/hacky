import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/api_exception.dart';
import 'package:mobile/api/models/auth.dart';
import 'package:mobile/api/models/me.dart';
import 'package:mobile/api/fake/fake_api_client.dart';

import '../../support/screen_harness.dart';

Matcher apiError(String code) =>
    isA<ApiException>().having((e) => e.code, 'code', code);

void main() {
  test('serves the other endpoints and shows profile edits in me', () async {
    final (:api, store: _) = fakeApi();
    await api.login(
      const LoginBody(
        email: FakeApiClient.demoEmail,
        password: FakeApiClient.testPassword,
      ),
    );

    final event = await api.getEvent('knighthacks-ix');
    expect(event.slug, 'knighthacks-ix');

    await api.updateProfile(const UpdateProfileBody(name: 'Renamed Hacker'));
    expect((await api.getMe()).profile.name, 'Renamed Hacker');
  });

  test('the other endpoints need a login', () async {
    final (:api, store: _) = fakeApi();
    await expectLater(
      api.getEvent('knighthacks-ix'),
      throwsA(apiError('unauthorized')),
    );
  });

  test('register saves nothing until the code, which logs in', () async {
    final (:api, :store) = fakeApi();
    const email = 'ethan@example.com';
    const register = RegisterBody(
      name: 'Ethan Zeng',
      handle: 'ethan_z',
      email: email,
      password: 'correct-password',
    );
    await api.register(register);

    // No account yet, so login fails and a wrong code is rejected.
    const login = LoginBody(email: email, password: 'correct-password');
    await expectLater(
      api.login(login),
      throwsA(apiError('invalid_credentials')),
    );
    await expectLater(
      api.verifyEmail(const VerifyCodeBody(email: email, code: '000000')),
      throwsA(apiError('invalid_code')),
    );

    final result = await api.verifyEmail(
      const VerifyCodeBody(email: email, code: FakeApiClient.testCode),
    );
    expect(result.me.profile.name, 'Ethan Zeng');
    expect(store.token, result.token);
    expect((await api.getMe()).profile.handle, 'ethan_z');

    // A code works once.
    await expectLater(
      api.verifyEmail(
        const VerifyCodeBody(email: email, code: FakeApiClient.testCode),
      ),
      throwsA(apiError('invalid_code')),
    );

    await api.logout();
    expect(await api.isLoggedIn, isFalse);
    expect((await api.login(login)).me.profile.handle, 'ethan_z');
  });

  test('the first sign-up to verify gets the username', () async {
    final (:api, store: _) = fakeApi();
    RegisterBody body(String email) => RegisterBody(
      name: 'Dee',
      handle: 'dee',
      email: email,
      password: 'password123',
    );
    await api.register(body('first@example.com'));
    await api.register(body('second@example.com'));

    await api.verifyEmail(
      const VerifyCodeBody(
        email: 'second@example.com',
        code: FakeApiClient.testCode,
      ),
    );
    await expectLater(
      api.verifyEmail(
        const VerifyCodeBody(
          email: 'first@example.com',
          code: FakeApiClient.testCode,
        ),
      ),
      throwsA(apiError('handle_taken')),
    );
  });

  test('resets the password with the code and logs in', () async {
    final (:api, :store) = fakeApi();
    const email = FakeApiClient.demoEmail;
    const reset = ResetCodeBody(
      email: email,
      code: FakeApiClient.testCode,
      password: 'brand-new-pass',
    );
    // No code was asked for yet.
    await expectLater(api.resetPassword(reset), throwsA(apiError('invalid_code')));

    await api.forgotPassword(const EmailBody(email: email));
    final result = await api.resetPassword(reset);
    expect(store.token, result.token);
    await expectLater(
      api.login(
        const LoginBody(email: email, password: FakeApiClient.testPassword),
      ),
      throwsA(apiError('invalid_credentials')),
    );
    await api.login(const LoginBody(email: email, password: 'brand-new-pass'));
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
