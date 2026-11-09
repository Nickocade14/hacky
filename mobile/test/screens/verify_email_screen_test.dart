import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/models/auth.dart';
import 'package:mobile/auth/error_text.dart';
import 'package:mobile/api/fake/fake_api_client.dart';
import 'package:mobile/routes.dart';
import 'package:mobile/screens/verify_email_screen.dart';

import '../support/screen_harness.dart';

final verifyButton = find.widgetWithText(FilledButton, 'Verify and continue');

Future<void> typeCode(WidgetTester tester, String code) =>
    tester.enterText(find.byKey(const Key('verify-code')), code);

/// A fake API with a sign-up waiting for its code.
Future<({FakeApiClient api, MemoryTokenStore store})> pendingSignUp(
  WidgetTester tester, {
  String email = 'ethan@example.com',
  String handle = 'ethan_z',
}) async {
  final fake = fakeApi();
  await tester.runAsync(
    () => fake.api.register(
      RegisterBody(
        name: 'Ethan Zeng',
        handle: handle,
        email: email,
        password: 'correct-password',
      ),
    ),
  );
  return fake;
}

void main() {
  testWidgets('names the email and asks for the code', (tester) async {
    final (:api, store: _) = fakeApi();
    await pumpScreen(
      tester,
      VerifyEmailScreen(api: api, email: 'ethan@example.com'),
    );

    expect(find.text('ONE QUICK STEP'), findsOneWidget);
    expect(find.text('Check your inbox.'), findsOneWidget);
    expect(
      find.textContaining('We sent a 6-digit code to ethan@example.com.'),
      findsOneWidget,
    );
    expect(find.text('The code expires in 10 minutes.'), findsOneWidget);
  });

  testWidgets('checks the code locally before calling the server', (
    tester,
  ) async {
    final (:api, store: _) = fakeApi();
    final visits = await pumpScreen(
      tester,
      VerifyEmailScreen(api: api, email: 'ethan@example.com'),
    );

    await typeCode(tester, '12a');
    await tapOn(tester, verifyButton);

    expect(find.text('Enter the 6-digit code from the email.'), findsOneWidget);
    expect(visits, isEmpty);
  });

  testWidgets('the right code logs in and opens Home', (tester) async {
    final (:api, :store) = await pendingSignUp(tester);
    final visits = await pumpScreen(
      tester,
      VerifyEmailScreen(api: api, email: 'ethan@example.com'),
    );

    await typeCode(tester, FakeApiClient.testCode);
    await tapOn(tester, verifyButton);

    expect(visits.single.route, Routes.home);
    expect((visits.single.arguments! as Me).profile.handle, 'ethan_z');
    expect(store.token, isNotNull);
  });

  testWidgets('a wrong code shows the server message', (tester) async {
    final (:api, :store) = await pendingSignUp(tester);
    final visits = await pumpScreen(
      tester,
      VerifyEmailScreen(api: api, email: 'ethan@example.com'),
    );

    await typeCode(tester, '000000');
    await tapOn(tester, verifyButton);

    expect(
      find.text(
        'That code is wrong or expired. Check the email or ask for a new code.',
      ),
      findsOneWidget,
    );
    expect(visits, isEmpty);
    expect(store.token, isNull);
  });

  testWidgets('a taken username offers to go back to create account', (
    tester,
  ) async {
    final (:api, store: _) = await pendingSignUp(tester, handle: 'dee');
    // Someone else signs up as @dee and verifies first.
    await tester.runAsync(() async {
      await api.register(
        const RegisterBody(
          name: 'Dee',
          handle: 'dee',
          email: 'dee@example.com',
          password: 'password123',
        ),
      );
      await api.verifyEmail(
        const VerifyCodeBody(
          email: 'dee@example.com',
          code: FakeApiClient.testCode,
        ),
      );
    });
    await pumpScreen(
      tester,
      VerifyEmailScreen(api: api, email: 'ethan@example.com'),
    );

    await typeCode(tester, FakeApiClient.testCode);
    await tapOn(tester, verifyButton);

    expect(
      find.text('That username is taken. Try another one.'),
      findsOneWidget,
    );
    expect(find.text('Back to create account'), findsOneWidget);
  });

  testWidgets('sends a new code', (tester) async {
    final (:api, store: _) = await pendingSignUp(tester);
    await pumpScreen(
      tester,
      VerifyEmailScreen(api: api, email: 'ethan@example.com'),
    );

    await tapOn(tester, find.text('Send a new code'));
    expect(find.textContaining('A new code is on its way.'), findsOneWidget);
  });

  testWidgets('shows the connection message when offline', (tester) async {
    final (:api, store: _) = fakeApi();
    await pumpScreen(
      tester,
      VerifyEmailScreen(api: api, email: FakeApiClient.offlineEmail),
    );

    await typeCode(tester, FakeApiClient.testCode);
    await tapOn(tester, verifyButton);
    expect(find.text(ErrorText.unreachable), findsOneWidget);
  });

  testWidgets('goes back to log in', (tester) async {
    final (:api, store: _) = fakeApi();
    final visits = await pumpScreen(
      tester,
      VerifyEmailScreen(api: api, email: 'ethan@example.com'),
    );

    await tapOn(tester, find.text('Back to log in'));
    expect(visits.single.route, Routes.login);
  });
}
