import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/models/auth.dart';
import 'package:mobile/auth/error_text.dart';
import 'package:mobile/api/fake/fake_api_client.dart';
import 'package:mobile/forms/login_form.dart';
import 'package:mobile/routes.dart';

import '../support/screen_harness.dart';

/// Taps on "Create an account" are counted here.
int createAccountTaps = 0;

Widget loginPage(FakeApiClient api) =>
    inPage(LoginForm(api: api, onCreateAccount: () => createAccountTaps++));

Future<void> fillLogin(
  WidgetTester tester,
  String email,
  String password,
) async {
  await tester.enterText(find.byKey(const Key('login-email')), email);
  await tester.enterText(find.byKey(const Key('login-password')), password);
}

final logInButton = find.widgetWithText(FilledButton, 'Log in');

void main() {
  testWidgets('shows the web texts and checks empty fields locally', (
    tester,
  ) async {
    final (:api, store: _) = fakeApi();
    await pumpScreen(tester, loginPage(api));

    expect(find.text('GOOD TO SEE YOU'), findsOneWidget);
    expect(find.text('Welcome back.'), findsOneWidget);
    expect(find.text('New around here? '), findsOneWidget);

    await tapOn(tester, logInButton);
    expect(find.text('Enter your email address.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
  });

  testWidgets('logs in with a normalized email and opens the account', (
    tester,
  ) async {
    final (:api, :store) = fakeApi();
    final visits = await pumpScreen(tester, loginPage(api));

    await fillLogin(tester, '  DEMO@hacky.dev ', FakeApiClient.testPassword);
    await tapOn(tester, logInButton);

    expect(visits.single.route, Routes.account);
    expect((visits.single.arguments as Me).profile.name, 'Demo Hacker');
    expect(store.token, isNotNull);
  });

  testWidgets('shows the server message for a wrong password', (tester) async {
    final (:api, :store) = fakeApi();
    final visits = await pumpScreen(tester, loginPage(api));

    await fillLogin(tester, FakeApiClient.demoEmail, 'wrong-password');
    await tapOn(tester, logInButton);

    expect(find.text('Wrong email or password.'), findsOneWidget);
    expect(visits, isEmpty);
    expect(store.token, isNull);
  });

  testWidgets('offers a resend link to an unverified user', (tester) async {
    final (:api, store: _) = fakeApi();
    final visits = await pumpScreen(tester, loginPage(api));

    await fillLogin(
      tester,
      FakeApiClient.unverifiedEmail,
      FakeApiClient.testPassword,
    );
    await tapOn(tester, logInButton);
    await tapOn(tester, find.text('Resend your verification email'));

    expect(visits.single.route, Routes.checkEmail);
    expect(visits.single.arguments, FakeApiClient.unverifiedEmail);
  });

  testWidgets('shows the connection message when offline', (tester) async {
    final (:api, store: _) = fakeApi();
    await pumpScreen(tester, loginPage(api));

    await fillLogin(
      tester,
      FakeApiClient.offlineEmail,
      FakeApiClient.testPassword,
    );
    await tapOn(tester, logInButton);

    expect(find.text(ErrorText.unreachable), findsOneWidget);
  });

  testWidgets('opens forgot password, and asks to switch tabs', (tester) async {
    final (:api, store: _) = fakeApi();
    final visits = await pumpScreen(tester, loginPage(api));

    await tapOn(tester, find.text('Forgot password?'));
    expect(visits.single.route, Routes.forgotPassword);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    createAccountTaps = 0;
    await tapOn(tester, find.text('Create an account'));
    expect(createAccountTaps, 1);
    expect(visits, hasLength(1), reason: 'switching tabs is not a new page');
  });

  testWidgets('the password field can be shown and hidden', (tester) async {
    final (:api, store: _) = fakeApi();
    await pumpScreen(tester, loginPage(api));

    EditableText password() => tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('login-password')),
        matching: find.byType(EditableText),
      ),
    );
    expect(password().obscureText, isTrue);
    await tapOn(tester, find.text('Show'));
    expect(password().obscureText, isFalse);
    expect(find.text('Hide'), findsOneWidget);
  });
}
