import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/api_exception.dart';
import 'package:mobile/api/fake/fake_api_client.dart';
import 'package:mobile/api/fake/fake_world.dart';
import 'package:mobile/api/models/requests.dart';
import 'package:mobile/auth/error_text.dart';
import 'package:mobile/people/block_person.dart';
import 'package:mobile/screens/person_profile_screen.dart';
import 'package:mobile/theme.dart';
import 'package:mobile/widgets/confirm_action_dialog.dart';

import '../support/screen_harness.dart';

const _offline = ApiException(
  statusCode: null,
  code: 'network_error',
  message: 'x',
);

/// The demo user's fake, where blocking can wait or fail.
class BlockingApi extends FakeApiClient {
  BlockingApi()
    : super(
        tokenStore: MemoryTokenStore()
          ..token = 'fake-jwt:${FakeApiClient.demoEmail}',
        delay: Duration.zero,
      );

  ApiException? blockError;
  Completer<void>? blockGate;
  final blocked = <String>[];

  @override
  Future<void> blockUser(BlockBody body) async {
    blocked.add(body.userId);
    await blockGate?.future;
    if (blockError case final error?) throw error;
    return super.blockUser(body);
  }
}

/// A page with a button that pushes 07 for [handle], so 07 has somewhere to
/// go back to.
Future<void> openFromList(
  WidgetTester tester,
  FakeApiClient api,
  String handle,
) async {
  tester.view.physicalSize = const Size(1200, 2700);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PersonProfileScreen(
                    api: api,
                    eventSlug: fakeEventSlug,
                    handle: handle,
                  ),
                ),
              ),
              child: const Text('People list'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('People list'));
  await tester.pumpAndSettle();
}

Future<void> openBlockDialog(WidgetTester tester) async {
  await tapOn(tester, find.byKey(PersonProfileScreen.menuKey));
  await tapOn(tester, find.text(BlockPerson.menuLabel));
}

void main() {
  testWidgets('••• → Block explains what happens; Cancel keeps the page', (
    tester,
  ) async {
    final api = BlockingApi();
    await openFromList(tester, api, 'maya_ml');

    await openBlockDialog(tester);

    expect(find.text('Block Maya Patel?'), findsOneWidget);
    expect(find.text(BlockPerson.message('Maya Patel')), findsOneWidget);
    expect(find.textContaining('every event'), findsOneWidget);

    await tapOn(tester, find.byKey(ConfirmActionDialog.cancelKey));

    expect(find.text('Block Maya Patel?'), findsNothing);
    expect(find.text('@maya_ml · Hacker'), findsOneWidget);
    expect(api.blocked, isEmpty);
  });

  testWidgets('blocking shows Blocking…, then goes back with a snackbar', (
    tester,
  ) async {
    final api = BlockingApi()..blockGate = Completer<void>();
    await openFromList(tester, api, 'maya_ml');
    final maya = await tester.runAsync(
      () => api.getPerson(fakeEventSlug, 'maya_ml'),
    );

    await openBlockDialog(tester);
    await tester.tap(find.byKey(ConfirmActionDialog.confirmKey));
    await tester.pump();

    expect(find.text('Blocking…'), findsOneWidget);
    final cancel = tester.widget<TextButton>(
      find.byKey(ConfirmActionDialog.cancelKey),
    );
    expect(cancel.onPressed, isNull);

    api.blockGate!.complete();
    await tester.pumpAndSettle();

    expect(api.blocked, [maya!.userId]);
    expect(find.byType(PersonProfileScreen), findsNothing);
    expect(find.text('People list'), findsOneWidget);
    expect(find.text(BlockPerson.done('Maya Patel')), findsOneWidget);
    final results = await tester.runAsync(
      () => api.search(event: fakeEventSlug, q: 'maya'),
    );
    expect(results!.results, isEmpty);
  });

  testWidgets('a failed block stays in the dialog and can be retried', (
    tester,
  ) async {
    final api = BlockingApi()..blockError = _offline;
    await openFromList(tester, api, 'priya_codes');

    await openBlockDialog(tester);
    await tapOn(tester, find.byKey(ConfirmActionDialog.confirmKey));

    expect(find.text(ErrorText.unreachable), findsOneWidget);
    expect(find.text('Block Priya Shah?'), findsOneWidget);
    expect(find.byType(PersonProfileScreen), findsOneWidget);

    api.blockError = null;
    await tapOn(tester, find.byKey(ConfirmActionDialog.confirmKey));

    expect(find.byType(PersonProfileScreen), findsNothing);
    expect(find.text(BlockPerson.done('Priya Shah')), findsOneWidget);
  });

  testWidgets('a missing profile has no ••• menu', (tester) async {
    final api = BlockingApi();
    await openFromList(tester, api, 'nobody_here');

    expect(find.text('This profile isn’t available'), findsOneWidget);
    expect(find.byKey(PersonProfileScreen.menuKey), findsNothing);
  });
}
