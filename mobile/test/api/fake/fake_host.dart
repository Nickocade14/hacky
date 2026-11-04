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

  // Endpoints not faked yet.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
