import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/token_store.dart';
import 'package:mobile/dev/fake_api_client.dart';
import 'package:mobile/theme.dart';

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

/// Shows [screen] on a phone-sized view. Any navigation lands on a stub page
/// and is recorded in the returned list.
Future<List<Visit>> pumpScreen(WidgetTester tester, Widget screen) async {
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

/// Taps the widget found by [finder] after scrolling it into view.
Future<void> tapOn(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
