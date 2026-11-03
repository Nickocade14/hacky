import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/models/auth.dart';
import 'package:mobile/auth/field_rules.dart';
import 'package:mobile/dev/fake_api_client.dart';
import 'package:mobile/routes.dart';
import 'package:mobile/screens/register_screen.dart';

import '../support/screen_harness.dart';

Future<void> fillRegister(
  WidgetTester tester, {
  String name = 'Ethan Zeng',
  String handle = 'ethan_z',
  String email = 'ETHAN@EXAMPLE.COM',
  String password = 'correct-password',
}) async {
  await tester.enterText(find.byKey(const Key('register-name')), name);
  await tester.enterText(find.byKey(const Key('register-handle')), handle);
  await tester.enterText(find.byKey(const Key('register-email')), email);
  await tester.enterText(find.byKey(const Key('register-password')), password);
}

final createButton = find.widgetWithText(FilledButton, 'Create account');

void main() {
  testWidgets('shows the web texts and hints', (tester) async {
    final (:api, store: _) = fakeApi();
    await pumpScreen(tester, RegisterScreen(api: api));

    expect(find.text('YOUR PEOPLE ARE HERE'), findsOneWidget);
    expect(find.text('Let’s make it happen.'), findsOneWidget);
    expect(find.text(FieldRules.handleHint), findsOneWidget);
    expect(find.text(FieldRules.passwordHint), findsOneWidget);
    expect(
      find.text(
        'We’ll send a verification link to your inbox before you log in.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('registers and opens Check your inbox with the email', (
    tester,
  ) async {
    final (:api, store: _) = fakeApi();
    final visits = await pumpScreen(tester, RegisterScreen(api: api));

    await fillRegister(tester);
    await tapOn(tester, createButton);

    expect(visits.single.route, Routes.checkEmail);
    expect(visits.single.arguments, 'ethan@example.com');
    // The account exists now but can't log in until it's verified.
    await tester.runAsync(
      () => expectLater(
        api.login(
          const LoginBody(
            email: 'ethan@example.com',
            password: 'correct-password',
          ),
        ),
        throwsA(anything),
      ),
    );
  });

  testWidgets('applies the web password rules before calling the server', (
    tester,
  ) async {
    final (:api, store: _) = fakeApi();
    final visits = await pumpScreen(tester, RegisterScreen(api: api));

    await fillRegister(tester, password: '🦄' * 7);
    await tapOn(tester, createButton);
    expect(
      find.text('Use at least 8 characters for your password.'),
      findsOneWidget,
    );

    await fillRegister(tester, password: '${'🦄' * 18}a');
    await tapOn(tester, createButton);
    expect(find.textContaining('at most 72 UTF-8 bytes'), findsOneWidget);
    expect(visits, isEmpty);
  });

  testWidgets('checks the name and handle', (tester) async {
    final (:api, store: _) = fakeApi();
    final visits = await pumpScreen(tester, RegisterScreen(api: api));

    await fillRegister(tester, name: '   ', handle: 'No Spaces');
    await tapOn(tester, createButton);

    expect(
      find.text('Enter your name so your teammates know what to call you.'),
      findsOneWidget,
    );
    // The hint under the field plus the error message.
    expect(find.text(FieldRules.handleHint), findsNWidgets(2));
    expect(visits, isEmpty);
  });

  testWidgets('shows the server message when the email is taken', (
    tester,
  ) async {
    final (:api, store: _) = fakeApi();
    await pumpScreen(tester, RegisterScreen(api: api));

    await fillRegister(tester, email: FakeApiClient.demoEmail);
    await tapOn(tester, createButton);

    expect(find.text('That email already has an account.'), findsOneWidget);
  });

  testWidgets('switches to log in', (tester) async {
    final (:api, store: _) = fakeApi();
    final visits = await pumpScreen(tester, RegisterScreen(api: api));

    await tapOn(tester, find.widgetWithText(TextButton, 'Log in'));
    expect(visits.single.route, Routes.login);
  });
}
