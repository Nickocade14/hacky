import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/models/auth.dart';
import 'package:mobile/api/token_store.dart';
import 'package:mobile/api/fake/fake_api_client.dart';
import 'package:mobile/api/fake/fake_world.dart';
import 'package:mobile/hacky/chat_start.dart';
import 'package:mobile/screens/hacky_chat_screen.dart';
import 'package:mobile/theme.dart';
import 'package:mobile/theme_choice.dart';
import 'package:mobile/widgets/hacky_chat_widgets.dart';

/// A token store that only lives in memory.
class MemoryTokenStore implements TokenStore {
  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String token) async => this.token = token;

  @override
  Future<void> clear() async => token = null;
}

/// A navigation done by the screen under test.
class Visit {
  const Visit(this.route, this.arguments);

  final String route;
  final Object? arguments;
}

/// A fake API without delays, and the store it saves the token in.
({FakeApiClient api, MemoryTokenStore store}) fakeApi() {
  final store = MemoryTokenStore();
  return (
    api: FakeApiClient(tokenStore: store, delay: Duration.zero),
    store: store,
  );
}

/// A fake API already signed in as the demo user (`demo@hacky.dev`), who is
/// in the fake event [fakeEventSlug].
({FakeApiClient api, MemoryTokenStore store}) signedInFakeApi() {
  final fake = fakeApi();
  fake.store.token = 'fake-jwt:${FakeApiClient.demoEmail}';
  return fake;
}

/// The demo user as the signed-in screens get it.
const demoMe = Me(
  profile: PublicProfile(
    userId: '6717a3f2c9e1b04d2a5e8f10',
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
      slug: fakeEventSlug,
      name: 'Knight Hacks IX',
      role: MemberRole.hacker,
      verified: false,
    ),
  ],
);

/// Shows [screen] on a phone-sized view. Any navigation lands on a stub page
/// and is recorded in the returned list.
Future<List<Visit>> pumpScreen(WidgetTester tester, Widget screen) async {
  // Hacky's clips would keep `pumpAndSettle` waiting; show their still frames.
  HackyFilm.debugStill = true;
  // Each test starts without a "New chat" from another test.
  HackyChatScreen.defaultStartStore = MemoryChatStartStore();
  ThemeChoice.instance = ThemeChoice();
  tester.view.physicalSize = const Size(1200, 2700);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final visits = <Visit>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: screen,
      onGenerateRoute: (settings) {
        visits.add(Visit(settings.name!, settings.arguments));
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Scaffold(body: Text('route ${settings.name}')),
        );
      },
    ),
  );
  return visits;
}

/// A scrollable page around a form that has no page of its own.
Widget inPage(Widget form) => Scaffold(
  body: SingleChildScrollView(padding: const EdgeInsets.all(24), child: form),
);

/// Taps the widget found by [finder] after scrolling it into view.
Future<void> tapOn(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  // The scroll moves the widget on the next frame; tap where it is then.
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
