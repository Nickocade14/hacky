import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/models/auth.dart';
import 'package:mobile/auth/error_text.dart';
import 'package:mobile/dev/fake_api_client.dart';
import 'package:mobile/routes.dart';
import 'package:mobile/screens/check_email_screen.dart';

import '../support/screen_harness.dart';

final resendButton = find.widgetWithText(
  FilledButton,
  'Resend verification link',
);

String fieldText(WidgetTester tester) => tester
    .widget<TextFormField>(find.byKey(const Key('resend-email')))
    .controller!
    .text;

void main() {
  testWidgets('names the email and prefills the resend form', (tester) async {
    final (:api, store: _) = fakeApi();
    await pumpScreen(
      tester,
      CheckEmailScreen(api: api, email: 'ethan@example.com'),
    );

    expect(find.text('ONE QUICK STEP'), findsOneWidget);
    expect(find.text('Check your inbox.'), findsOneWidget);
    expect(
      find.textContaining('We sent a verification link to ethan@example.com.'),
      findsOneWidget,
    );
    expect(fieldText(tester), 'ethan@example.com');
    expect(
      find.text('Can’t find the email? Take a quick look in your spam folder.'),
      findsOneWidget,
    );
  });

  testWidgets('without an email, asks for one', (tester) async {
    final (:api, store: _) = fakeApi();
    await pumpScreen(tester, CheckEmailScreen(api: api));

    expect(
      find.text(
        'Open the verification link in your email, or request a new one below.',
      ),
      findsOneWidget,
    );
    expect(fieldText(tester), isEmpty);
    await tapOn(tester, resendButton);
    expect(find.text('Enter your email address.'), findsOneWidget);
  });

  testWidgets('resends and confirms without revealing the account', (
    tester,
  ) async {
    final (:api, store: _) = fakeApi();
    await pumpScreen(
      tester,
      CheckEmailScreen(api: api, email: FakeApiClient.unverifiedEmail),
    );

    await tapOn(tester, resendButton);

    expect(
      find.textContaining('If this address has an unverified account'),
      findsOneWidget,
    );
    // In the fake, resending verifies the account, so it can log in now.
    await tester.runAsync(
      () => api.login(
        const LoginBody(
          email: FakeApiClient.unverifiedEmail,
          password: FakeApiClient.testPassword,
        ),
      ),
    );
  });

  testWidgets('shows the connection message when offline', (tester) async {
    final (:api, store: _) = fakeApi();
    await pumpScreen(
      tester,
      CheckEmailScreen(api: api, email: FakeApiClient.offlineEmail),
    );

    await tapOn(tester, resendButton);
    expect(find.text(ErrorText.unreachable), findsOneWidget);
  });

  testWidgets('goes back to log in', (tester) async {
    final (:api, store: _) = fakeApi();
    final visits = await pumpScreen(tester, CheckEmailScreen(api: api));

    await tapOn(tester, find.text('Back to log in'));
    expect(visits.single.route, Routes.login);
  });
}
