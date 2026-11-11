import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app.dart';
import 'package:mobile/api/fake/fake_api_client.dart';
import 'package:mobile/shell/app_tab.dart';
import 'package:mobile/shell/shell_header.dart';
import 'package:mobile/theme.dart';
import 'package:mobile/widgets/hacky_chat_widgets.dart';

import 'support/screen_harness.dart';

Future<void> pumpApp(WidgetTester tester, FakeApiClient api) async {
  HackyFilm.debugStill = true;
  tester.view.physicalSize = const Size(1200, 2700);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(HackyApp(api: api));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('starts at log in without a saved session, with the theme', (
    tester,
  ) async {
    final (:api, store: _) = fakeApi();
    await pumpApp(tester, api);

    expect(find.text('Welcome back.'), findsOneWidget);
    expect(find.text('GOOD TO SEE YOU'), findsOneWidget);
    final theme = Theme.of(tester.element(find.text('Welcome back.')));
    expect(theme.colorScheme.primary, AppColors.action);
    expect(theme.textTheme.bodyMedium?.fontFamily, AppTheme.fontFamily);
  });

  testWidgets('skips log in when the saved token is still valid', (
    tester,
  ) async {
    final (:api, :store) = fakeApi();
    store.token = 'fake-jwt:${FakeApiClient.demoEmail}';
    await pumpApp(tester, api);

    // Lands on Hacky; the header shows the event.
    expect(find.text('Knight Hacks IX'), findsOneWidget);
    expect(find.text(HackyBrief.title), findsOneWidget);
    expect(find.byKey(ShellHeader.keyOf(AppTab.home)), findsOneWidget);
  });

  testWidgets('drops a saved token the server rejects', (tester) async {
    final (:api, :store) = fakeApi();
    store.token = 'fake-jwt:nobody@example.com';
    await pumpApp(tester, api);

    expect(find.text('Welcome back.'), findsOneWidget);
    expect(store.token, isNull);
  });

  testWidgets('register, enter the code, open Me and sign out end to end', (
    tester,
  ) async {
    final (:api, :store) = fakeApi();
    await pumpApp(tester, api);

    await tapOn(tester, find.text('Create an account'));
    await tester.enterText(
      find.byKey(const Key('register-name')),
      'Ethan Zeng',
    );
    await tester.enterText(find.byKey(const Key('register-handle')), 'ethan_z');
    await tester.enterText(
      find.byKey(const Key('register-email')),
      'ethan@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('register-password')),
      'correct-password',
    );
    await tapOn(tester, find.widgetWithText(FilledButton, 'Create account'));

    // The code logs in, so there's no extra log in step.
    expect(find.text('Check your inbox.'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('verify-code')),
      FakeApiClient.testCode,
    );
    await tapOn(
      tester,
      find.widgetWithText(FilledButton, 'Verify and continue'),
    );

    expect(find.text('Knight Hacks IX'), findsOneWidget);
    expect(store.token, isNotNull);

    await tapOn(tester, find.byKey(ShellHeader.keyOf(AppTab.me)));
    expect(find.text('Ethan Zeng\n@ethan_z'), findsOneWidget);
    await tapOn(tester, find.text('Sign out'));
    expect(find.text('Welcome back.'), findsOneWidget);
    expect(store.token, isNull);
  });
}
