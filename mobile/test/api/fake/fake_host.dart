import 'package:mobile/api/api_client.dart';
import 'package:mobile/api/fake/fake_endpoints.dart';
import 'package:mobile/api/models/auth.dart';

const hostMe = Me(
  profile: PublicProfile(
    userId: '6716a3f2c9e700000000beef',
    handle: 'demo_hacker',
    name: 'Demo Hacker',
    hackyStyle: {},
    photoUrl: null,
    bio: null,
    links: ProfileLinks(),
    isDemo: true,
  ),
  events: [
    MyEvent(
      slug: 'knighthacks-ix',
      name: 'Knight Hacks IX',
      role: MemberRole.hacker,
      verified: false,
    ),
  ],
);

/// A fake client like the app's: auth lives in the host, everything else
/// comes from [FakeEndpoints].
class FakeHost with FakeEndpoints implements ApiClient {
  FakeHost({this.me = hostMe});

  Me me;
  bool loggedIn = true;

  @override
  Future<Me> getMe() async {
    if (!loggedIn) throw fakeError(401, 'unauthorized', 'Log in first');
    return me;
  }

  // The auth routes are the host's job (FakeApiClient on the app side). This
  // class has no noSuchMethod, so it only compiles while FakeEndpoints covers
  // every other ApiClient method.

  @override
  Duration get timeout => Duration.zero;

  @override
  Future<void> register(RegisterBody body) => throw UnimplementedError();

  @override
  Future<void> verifyEmail(TokenBody body) => throw UnimplementedError();

  @override
  Future<void> resendVerification(EmailBody body) => throw UnimplementedError();

  @override
  Future<LoginResult> login(LoginBody body) => throw UnimplementedError();

  @override
  Future<void> forgotPassword(EmailBody body) => throw UnimplementedError();

  @override
  Future<void> resetPassword(ResetPasswordBody body) =>
      throw UnimplementedError();

  @override
  Future<void> logout() async => loggedIn = false;

  @override
  Future<bool> get isLoggedIn async => loggedIn;

  @override
  void close() {}
}
