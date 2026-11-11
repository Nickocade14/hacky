import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/api_exception.dart';
import 'package:mobile/api/fake/fake_api_client.dart';
import 'package:mobile/api/models/auth.dart';
import 'package:mobile/auth/error_text.dart';
import 'package:mobile/routes.dart';
import 'package:mobile/screens/conversations_screen.dart';
import 'package:mobile/shell/app_tab.dart';
import 'package:mobile/shell/ask_hacky_button.dart';
import 'package:mobile/shell/shell_header.dart';
import 'package:mobile/shell/signed_in_shell.dart';
import 'package:mobile/widgets/hacky_chat_widgets.dart';

import '../support/screen_harness.dart';

/// A page's button in the header; for Hacky, the Ask Hacky button.
Finder tabOf(AppTab tab) => find.byKey(ShellHeader.keyOf(tab));

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
  testWidgets('opens on Hacky, with the header and no Ask Hacky button', (
    tester,
  ) async {
    final (:api, store: _) = signedInFakeApi();
    await pumpScreen(tester, SignedInShell(api: api, me: demoMe));
    await tester.pumpAndSettle();

    expect(find.text(HackyBrief.title), findsOneWidget);
    // The header: the event under "Hacky", then Chats, People, Home and Me.
    expect(find.text('Knight Hacks IX'), findsOneWidget);
    for (final tab in [AppTab.chats, AppTab.people, AppTab.home, AppTab.me]) {
      expect(tabOf(tab), findsOneWidget);
    }
    expect(find.byType(AskHackyButton), findsNothing);
  });

  testWidgets('the header switches pages and keeps them loaded', (
    tester,
  ) async {
    final (:api, store: _) = signedInFakeApi();
    await pumpScreen(tester, SignedInShell(api: api, me: demoMe));
    await tester.pumpAndSettle();

    await tapOn(tester, tabOf(AppTab.people));
    expect(find.text('Find your people'), findsOneWidget);
    expect(find.text(AskHackyButton.label), findsOneWidget);

    await tapOn(tester, tabOf(AppTab.chats));
    expect(find.byType(ConversationsScreen), findsOneWidget);
    // On Chats the button is just Hacky's face.
    expect(find.byType(AskHackyButton), findsOneWidget);
    expect(find.text(AskHackyButton.label), findsNothing);

    await tapOn(tester, tabOf(AppTab.me));
    expect(find.text('Change Hacky style'), findsOneWidget);
    expect(find.text('Demo Hacker\n@demo_hacker'), findsOneWidget);

    await tapOn(tester, tabOf(AppTab.home));
    expect(find.text('YOUR EVENT'), findsOneWidget);

    await tapOn(tester, tabOf(AppTab.hacky));
    expect(find.text(HackyBrief.title), findsOneWidget);
    expect(find.text('Loading your chat…'), findsNothing);
    expect(find.byType(AskHackyButton), findsNothing);

    await tapOn(tester, tabOf(AppTab.home));
    expect(find.text('YOUR EVENT'), findsOneWidget);
    expect(find.text('Loading your event…'), findsNothing);
  });

  testWidgets('can open on another page', (tester) async {
    final (:api, store: _) = signedInFakeApi();
    await pumpScreen(
      tester,
      SignedInShell(api: api, me: demoMe, initialTab: AppTab.chats),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ConversationsScreen), findsOneWidget);
    expect(find.text(HackyBrief.title), findsNothing);
  });

  testWidgets('the Chats button says when something is waiting', (
    tester,
  ) async {
    final (:api, store: _) = signedInFakeApi();
    await pumpScreen(tester, SignedInShell(api: api, me: demoMe));
    await tester.pumpAndSettle();

    // The demo user has a request to answer and an unread message.
    final chats = tester.widget<IconButton>(tabOf(AppTab.chats));
    expect(chats.tooltip, startsWith('Chats, '));
    expect(chats.tooltip, endsWith(' waiting'));
  });

  testWidgets('Chats opens 09 Requests for the current event', (tester) async {
    final (:api, store: _) = signedInFakeApi();
    final visits = await pumpScreen(tester, SignedInShell(api: api, me: demoMe));
    await tester.pumpAndSettle();

    await tapOn(tester, tabOf(AppTab.chats));
    await tapOn(tester, find.byKey(ConversationsScreen.seeAllKey));

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
    expect(find.text(HackyBrief.title), findsOneWidget);
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

  testWidgets('without an event, it opens on Home and joining opens the event', (
    tester,
  ) async {
    final api = NoEventApi();
    await pumpScreen(tester, SignedInShell(api: api));
    await tester.pumpAndSettle();

    expect(find.text('Pick your hackathon'), findsOneWidget);
    expect(find.text('No hackathon yet'), findsOneWidget);
    // There's no Hacky to ask before joining an event.
    expect(find.byType(AskHackyButton), findsNothing);

    await tapOn(tester, tabOf(AppTab.people));
    expect(find.text('Join an event first'), findsOneWidget);
    await tapOn(tester, find.text('Go to Home'));

    await tapOn(tester, find.widgetWithText(FilledButton, 'Join'));

    expect(find.text('YOUR EVENT'), findsOneWidget);
    expect(find.text('Knight Hacks IX'), findsOneWidget);
    expect(find.byType(AskHackyButton), findsOneWidget);

    await tapOn(tester, tabOf(AppTab.people));
    expect(find.text('Join an event first'), findsNothing);
    expect(find.text('Find your people'), findsOneWidget);
  });
}
