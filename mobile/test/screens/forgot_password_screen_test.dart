import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/auth/error_text.dart';
import 'package:mobile/api/fake/fake_api_client.dart';
import 'package:mobile/routes.dart';
import 'package:mobile/screens/forgot_password_screen.dart';
import 'package:mobile/widgets/auth_widgets.dart';

import '../support/screen_harness.dart';

Future<void> typeEmail(WidgetTester tester, String email) =>
    tester.enterText(find.byKey(const Key('forgot-email')), email);

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
        'No worries. We’ll send you a link to get back to your people.',
      ),
      findsOneWidget,
    );

    await typeEmail(tester, 'not-an-email');
    await tapOn(tester, find.text('Send reset link'));
    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });

  testWidgets('confirms the same way whether or not the account exists', (
    tester,
  ) async {
    final (:api, store: _) = fakeApi();
    await pumpScreen(tester, ForgotPasswordScreen(api: api));

    await typeEmail(tester, 'unknown@example.com');
    await tapOn(tester, find.text('Send reset link'));

    expect(find.text('Check your inbox.'), findsOneWidget);
    expect(
      find.text(
        'If an account exists for that email, a password reset link is on its way.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Check your email and spam folder.'),
      findsOneWidget,
    );
    expect(find.text('Send another link'), findsOneWidget);
  });

  testWidgets('shows the connection message when offline', (tester) async {
    final (:api, store: _) = fakeApi();
    await pumpScreen(tester, ForgotPasswordScreen(api: api));

    await typeEmail(tester, FakeApiClient.offlineEmail);
    await tapOn(tester, find.text('Send reset link'));

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
