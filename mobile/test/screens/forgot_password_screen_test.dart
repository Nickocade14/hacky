import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/models/auth.dart';
import 'package:mobile/auth/error_text.dart';
import 'package:mobile/api/fake/fake_api_client.dart';
import 'package:mobile/routes.dart';
import 'package:mobile/screens/forgot_password_screen.dart';
import 'package:mobile/widgets/auth_widgets.dart';

import '../support/screen_harness.dart';

Future<void> typeEmail(WidgetTester tester, String email) =>
    tester.enterText(find.byKey(const Key('forgot-email')), email);

Future<void> typeReset(WidgetTester tester, String code, String password) async {
  await tester.enterText(find.byKey(const Key('reset-code')), code);
  await tester.enterText(find.byKey(const Key('reset-password')), password);
}

final sendCode = find.widgetWithText(FilledButton, 'Send code');
final resetButton = find.widgetWithText(FilledButton, 'Reset password');

void main() {
  testWidgets('shows the web texts and checks the email locally', (
    tester,
  ) async {
    final (:api, store: _) = fakeApi();
    await pumpScreen(tester, ForgotPasswordScreen(api: api));

    expect(find.text('IT HAPPENS TO THE BEST OF US'), findsOneWidget);
    expect(find.text('Forgot your password?'), findsOneWidget);
    // No "↺" icon: it looked like a reload button that did nothing.
    expect(find.byType(StatusIcon), findsNothing);
    expect(
      find.text(
        'No worries. We’ll email you a code to get back to your people.',
      ),
      findsOneWidget,
    );

    await typeEmail(tester, 'not-an-email');
    await tapOn(tester, sendCode);
    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });

  testWidgets('asks for the code the same way whether or not the account exists', (
    tester,
  ) async {
    final (:api, store: _) = fakeApi();
    await pumpScreen(tester, ForgotPasswordScreen(api: api));

    await typeEmail(tester, 'Unknown@Example.com ');
    await tapOn(tester, sendCode);

    expect(find.text('Check your inbox.'), findsOneWidget);
    expect(
      find.textContaining('If an account exists for unknown@example.com'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('reset-code')), findsOneWidget);
    expect(find.byKey(const Key('reset-password')), findsOneWidget);
  });

  testWidgets('the code and a new password log in and open Home', (
    tester,
  ) async {
    final (:api, :store) = fakeApi();
    final visits = await pumpScreen(tester, ForgotPasswordScreen(api: api));

    await typeEmail(tester, FakeApiClient.demoEmail);
    await tapOn(tester, sendCode);
    await typeReset(tester, FakeApiClient.testCode, 'brand-new-pass');
    await tapOn(tester, resetButton);

    expect(visits.single.route, Routes.home);
    expect((visits.single.arguments! as Me).profile.handle, 'demo_hacker');
    expect(store.token, isNotNull);
  });

  testWidgets('checks the code and password before calling the server', (
    tester,
  ) async {
    final (:api, store: _) = fakeApi();
    final visits = await pumpScreen(tester, ForgotPasswordScreen(api: api));

    await typeEmail(tester, FakeApiClient.demoEmail);
    await tapOn(tester, sendCode);
    await typeReset(tester, '12', 'short');
    await tapOn(tester, resetButton);

    expect(find.text('Enter the 6-digit code from the email.'), findsOneWidget);
    expect(
      find.text('Use at least 8 characters for your password.'),
      findsOneWidget,
    );
    expect(visits, isEmpty);
  });

  testWidgets('a wrong code shows the server message', (tester) async {
    final (:api, store: _) = fakeApi();
    final visits = await pumpScreen(tester, ForgotPasswordScreen(api: api));

    await typeEmail(tester, FakeApiClient.demoEmail);
    await tapOn(tester, sendCode);
    await typeReset(tester, '000000', 'brand-new-pass');
    await tapOn(tester, resetButton);

    expect(find.textContaining('That code is wrong or expired.'), findsOneWidget);
    expect(visits, isEmpty);
  });

  testWidgets('can go back and use a different email', (tester) async {
    final (:api, store: _) = fakeApi();
    await pumpScreen(tester, ForgotPasswordScreen(api: api));

    await typeEmail(tester, 'first@example.com');
    await tapOn(tester, sendCode);
    await tapOn(tester, find.text('Use a different email'));

    expect(find.text('Forgot your password?'), findsOneWidget);
    expect(find.byKey(const Key('forgot-email')), findsOneWidget);
  });

  testWidgets('shows the connection message when offline', (tester) async {
    final (:api, store: _) = fakeApi();
    await pumpScreen(tester, ForgotPasswordScreen(api: api));

    await typeEmail(tester, FakeApiClient.offlineEmail);
    await tapOn(tester, sendCode);

    expect(find.text(ErrorText.unreachable), findsOneWidget);
    expect(find.text('Forgot your password?'), findsOneWidget);
  });

  testWidgets('goes back to log in', (tester) async {
    final (:api, store: _) = fakeApi();
    final visits = await pumpScreen(tester, ForgotPasswordScreen(api: api));

    await tapOn(tester, find.text('Back to log in'));
    expect(visits.single.route, Routes.login);
  });
}
