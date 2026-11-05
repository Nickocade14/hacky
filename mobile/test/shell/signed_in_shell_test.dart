import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/api_exception.dart';
import 'package:mobile/api/fake/fake_api_client.dart';
import 'package:mobile/api/models/auth.dart';
import 'package:mobile/auth/error_text.dart';
import 'package:mobile/routes.dart';
import 'package:mobile/shell/app_tab.dart';
import 'package:mobile/shell/app_tab_bar.dart';
import 'package:mobile/shell/signed_in_shell.dart';

import '../support/screen_harness.dart';

Finder tabOf(AppTab tab) => find.byKey(AppTabBar.keyOf(tab));

/// A signed-in fake whose `GET /api/me` fails with [error] while it's set.
class FailingMeApi extends FakeApiClient {
  FailingMeApi(MemoryTokenStore store)
    : super(tokenStore: store, delay: Duration.zero);

  ApiException? error = const ApiException(
    statusCode: null,
    code: 'network_error',
    message: 'x',
  );

  @override
  Future<Me> getMe() async {
    final error = this.error;
    if (error != null) throw error;
    return super.getMe();
  }
}

/// The demo user before they join any event.
class NoEventApi extends FakeApiClient {
  NoEventApi() : super(tokenStore: MemoryTokenStore(), delay: Duration.zero);

  @override
  Future<Me> getMe() async =>
      Me(profile: demoMe.profile, events: const <MyEvent>[]);
}

void main() {
  testWidgets('shows the five tabs in order and opens Home', (tester) async {
    final (:api, store: _) = signedInFakeApi();
    await pumpScreen(tester, SignedInShell(api: api, me: demoMe));
    await tester.pumpAndSettle();

    final labels = tester
        .widgetList<NavigationDestination>(find.byType(NavigationDestination))
        .map((d) => d.label);
    expect(labels, ['Home', 'People', 'Hacky', 'Chats', 'Me']);
    for (final tab in AppTab.values) {
      expect(tabOf(tab), findsOneWidget);
    }
    expect(find.text('YOUR EVENT'), findsOneWidget);
  });

  testWidgets('switches tabs and keeps Home loaded', (tester) async {
    final (:api, store: _) = signedInFakeApi();
    await pumpScreen(tester, SignedInShell(api: api, me: demoMe));
    await tester.pumpAndSettle();

    await tapOn(tester, tabOf(AppTab.people));
    expect(find.text('Screen 06 is on its way'), findsOneWidget);

    await tapOn(tester, tabOf(AppTab.hacky));
    expect(find.text('Screen 12 is on its way'), findsOneWidget);

    await tapOn(tester, tabOf(AppTab.chats));
    expect(find.text('Screen 10 is on its way'), findsOneWidget);

    await tapOn(tester, tabOf(AppTab.me));
    expect(find.text('Change Hacky style'), findsOneWidget);
    expect(find.text('Demo Hacker\n@demo_hacker'), findsOneWidget);

    await tapOn(tester, tabOf(AppTab.home));
    expect(find.text('YOUR EVENT'), findsOneWidget);
    expect(find.text('Loading your event…'), findsNothing);
  });

  testWidgets('can open on another tab', (tester) async {
    final (:api, store: _) = signedInFakeApi();
    await pumpScreen(
      tester,
      SignedInShell(api: api, me: demoMe, initialTab: AppTab.chats),
    );
    await tester.pumpAndSettle();

    expect(find.text('Screen 10 is on its way'), findsOneWidget);
    expect(find.text('YOUR EVENT'), findsNothing);
  });

  testWidgets('Home buttons switch to the Me and Hacky tabs', (tester) async {
    final (:api, store: _) = signedInFakeApi();
    await pumpScreen(tester, SignedInShell(api: api, me: demoMe));
    await tester.pumpAndSettle();

    await tapOn(tester, find.text('Ask Hacky'));
    expect(find.text('Screen 12 is on its way'), findsOneWidget);
  });

  testWidgets('Chats opens 09 Requests for the current event', (tester) async {
    final (:api, store: _) = signedInFakeApi();
    final visits = await pumpScreen(tester, SignedInShell(api: api, me: demoMe));
    await tester.pumpAndSettle();

    await tapOn(tester, tabOf(AppTab.chats));
    await tapOn(tester, find.widgetWithText(TextButton, 'Requests'));

    expect(visits.single.route, Routes.requests);
    expect((visits.single.arguments as RequestsArgs).eventSlug, 'knighthacks-ix');
  });

  testWidgets('loads the user when the app starts with a saved token', (
    tester,
  ) async {
    final (:api, store: _) = signedInFakeApi();
    await pumpScreen(tester, SignedInShell(api: api));

    expect(find.text('Loading your account…'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Knight Hacks IX'), findsOneWidget);
  });

  testWidgets('a rejected token goes back to log in', (tester) async {
    final (:api, :store) = fakeApi();
    store.token = 'fake-jwt:nobody@example.com';
    final visits = await pumpScreen(tester, SignedInShell(api: api));
    await tester.pumpAndSettle();

    expect(visits.single.route, Routes.login);
    expect(store.token, isNull);
  });

  testWidgets('a connection problem can be retried', (tester) async {
    final store = MemoryTokenStore()
      ..token = 'fake-jwt:${FakeApiClient.demoEmail}';
    final api = FailingMeApi(store);
    await pumpScreen(tester, SignedInShell(api: api));
    await tester.pumpAndSettle();

    expect(find.text(ErrorText.unreachable), findsOneWidget);

    api.error = null;
    await tapOn(tester, find.text('Try again'));
    expect(find.text('Knight Hacks IX'), findsOneWidget);
  });

  testWidgets('sign out on Me forgets the token and returns to log in', (
    tester,
  ) async {
    final (:api, :store) = signedInFakeApi();
    final visits = await pumpScreen(tester, SignedInShell(api: api, me: demoMe));
    await tester.pumpAndSettle();

    await tapOn(tester, tabOf(AppTab.me));
    await tapOn(tester, find.text('Sign out'));

    expect(store.token, isNull);
    expect(visits.single.route, Routes.login);
  });

  testWidgets('without an event, Home lists events and joining opens it', (
    tester,
  ) async {
    final api = NoEventApi();
    await pumpScreen(tester, SignedInShell(api: api));
    await tester.pumpAndSettle();

    expect(find.text('Pick your hackathon'), findsOneWidget);

    await tapOn(tester, tabOf(AppTab.people));
    expect(find.text('Join an event first'), findsOneWidget);
    await tapOn(tester, find.text('Go to Home'));

    await tapOn(tester, find.widgetWithText(FilledButton, 'Join'));

    expect(find.text('YOUR EVENT'), findsOneWidget);
    expect(find.text('Knight Hacks IX'), findsOneWidget);

    await tapOn(tester, tabOf(AppTab.people));
    expect(find.text('Join an event first'), findsNothing);
    expect(find.text('Screen 06 is on its way'), findsOneWidget);
  });
}
