import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/api_exception.dart';
import 'package:mobile/api/models/auth.dart';
import 'package:mobile/auth/error_text.dart';
import 'package:mobile/dev/fake_api_client.dart';
import 'package:mobile/routes.dart';
import 'package:mobile/screens/account_screen.dart';

import '../support/screen_harness.dart';

const me = Me(
  profile: PublicProfile(
    userId: '6717a3f2c9e1b04d2a5e8f10',
    handle: 'ethan_z',
    name: 'Ethan Zeng',
    hackyStyle: {},
    photoUrl: null,
    bio: null,
    links: ProfileLinks(),
    isDemo: false,
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

/// A fake whose `GET /api/me` fails with [error].
class FailingMeApi extends FakeApiClient {
  FailingMeApi(this.error)
    : super(tokenStore: MemoryTokenStore(), delay: Duration.zero);

  ApiException error;

  @override
  Future<Me> getMe() async => throw error;
}

void main() {
  testWidgets('shows the user from the login response', (tester) async {
    final (:api, store: _) = fakeApi();
    await pumpScreen(tester, AccountScreen(api: api, me: me));

    expect(find.text('YOUR NEXT CHAPTER'), findsOneWidget);
    expect(find.text('You’re in, Ethan.'), findsOneWidget);
    expect(find.text('Ethan Zeng'), findsOneWidget);
    expect(find.text('@ethan_z'), findsOneWidget);
    expect(find.text('Knight Hacks IX'), findsOneWidget);
    expect(find.text('Hacker'), findsOneWidget);
  });

  testWidgets('loads the user when the app starts with a saved token', (
    tester,
  ) async {
    final (:api, :store) = fakeApi();
    store.token = 'fake-jwt:${FakeApiClient.demoEmail}';
    await pumpScreen(tester, AccountScreen(api: api));

    expect(find.text('Loading your account…'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('You’re in, Demo.'), findsOneWidget);
  });

  testWidgets('a rejected token goes back to log in', (tester) async {
    final (:api, :store) = fakeApi();
    store.token = 'fake-jwt:nobody@example.com';
    final visits = await pumpScreen(tester, AccountScreen(api: api));
    await tester.pumpAndSettle();

    expect(visits.single.route, Routes.login);
    expect(store.token, isNull);
  });

  testWidgets('a connection problem can be retried', (tester) async {
    final api = FailingMeApi(
      const ApiException(statusCode: null, code: 'network_error', message: 'x'),
    );
    await pumpScreen(tester, AccountScreen(api: api));
    await tester.pumpAndSettle();

    expect(find.text(ErrorText.unreachable), findsOneWidget);
    expect(find.text('Welcome back.'), findsOneWidget);

    api.error = const ApiException(
      statusCode: 401,
      code: 'unauthorized',
      message: 'x',
    );
    await tapOn(tester, find.text('Try again'));
    expect(find.text('route ${Routes.login}'), findsOneWidget);
  });

  testWidgets('sign out forgets the token and returns to log in', (
    tester,
  ) async {
    final (:api, :store) = fakeApi();
    store.token = 'fake-jwt:${FakeApiClient.demoEmail}';
    final visits = await pumpScreen(tester, AccountScreen(api: api, me: me));

    await tapOn(tester, find.text('Sign out'));

    expect(store.token, isNull);
    expect(visits.single.route, Routes.login);
  });
}
