import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/fake/fake_api_client.dart';
import 'package:mobile/app.dart';
import 'package:mobile/routes.dart';
import 'package:mobile/screens/chat_thread_screen.dart';
import 'package:mobile/theme.dart';

import 'support/screen_harness.dart';

/// A page with one button per pushed signed-in screen, opened through the
/// app's real router and the [Navigate] helpers.
Future<void> pumpLauncher(WidgetTester tester, FakeApiClient api) async {
  tester.view.physicalSize = const Size(1200, 2700);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      onGenerateRoute: AppRouter(api).route,
      home: Builder(
        builder: (context) => Scaffold(
          body: Column(
            children: [
              TextButton(
                onPressed: () => Navigate.toPerson(
                  context,
                  eventSlug: 'knighthacks-ix',
                  handle: 'maya_ml',
                ),
                child: const Text('open person'),
              ),
              TextButton(
                onPressed: () =>
                    Navigate.toRequests(context, eventSlug: 'knighthacks-ix'),
                child: const Text('open requests'),
              ),
              TextButton(
                onPressed: () => Navigate.toChatThread(
                  context,
                  eventSlug: 'knighthacks-ix',
                  conversationId: '6716a3f2c9e700000000010a',
                ),
                child: const Text('open chat'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> goBack(WidgetTester tester) async {
  tester.state<NavigatorState>(find.byType(Navigator)).pop();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens 07 Person profile with the handle, and comes back', (
    tester,
  ) async {
    final (:api, store: _) = signedInFakeApi();
    await pumpLauncher(tester, api);

    await tapOn(tester, find.text('open person'));
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Screen 07 is on its way'), findsOneWidget);
    expect(find.textContaining('@maya_ml'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    await goBack(tester);
    expect(find.text('open person'), findsOneWidget);
  });

  testWidgets('opens 09 Requests', (tester) async {
    final (:api, store: _) = signedInFakeApi();
    await pumpLauncher(tester, api);

    await tapOn(tester, find.text('open requests'));
    expect(find.text('Requests'), findsOneWidget);
    expect(find.text('Screen 09 is on its way'), findsOneWidget);
  });

  testWidgets('opens 11 Chat thread', (tester) async {
    final (:api, store: _) = signedInFakeApi();
    await pumpLauncher(tester, api);

    await tapOn(tester, find.text('open chat'));
    final screen = tester.widget<ChatThreadScreen>(
      find.byType(ChatThreadScreen),
    );
    expect(screen.eventSlug, 'knighthacks-ix');
    expect(screen.conversationId, '6716a3f2c9e700000000010a');
    expect(find.byType(BackButton), findsOneWidget);
  });
}
