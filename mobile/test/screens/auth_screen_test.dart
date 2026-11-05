import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/screens/auth_screen.dart';
import 'package:mobile/widgets/auth_widgets.dart';

import '../support/screen_harness.dart';

Finder tab(String label) =>
    find.descendant(of: find.byType(AuthTabs), matching: find.text(label));

Alignment indicator(WidgetTester tester) =>
    tester
            .widget<AnimatedAlign>(
              find.descendant(
                of: find.byType(AuthTabs),
                matching: find.byType(AnimatedAlign),
              ),
            )
            .alignment
        as Alignment;

void main() {
  testWidgets('shows the mascot and wordmark on top, without the h. logo', (
    tester,
  ) async {
    final (:api, store: _) = fakeApi();
    await pumpScreen(tester, AuthScreen(api: api));

    final mascot = tester.widget<Image>(find.byType(Image));
    expect((mascot.image as AssetImage).assetName, MascotHeader.image);
    expect(find.byType(Wordmark), findsOneWidget);
    expect(find.text('h.'), findsNothing);
    expect(find.text('Welcome back.'), findsOneWidget);
    expect(indicator(tester), Alignment.centerLeft);
  });

  testWidgets('switching tabs crossfades only the form, in place', (
    tester,
  ) async {
    final (:api, store: _) = fakeApi();
    final visits = await pumpScreen(tester, AuthScreen(api: api));
    final header = tester.element(find.byType(MascotHeader));

    await tester.tap(tab('Create account'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Halfway: both forms are visible, fading, but there's one header and one
    // tab switch, and the indicator is on its way to the right.
    expect(find.text('Welcome back.'), findsOneWidget);
    expect(find.text('Let’s make it happen.'), findsOneWidget);
    expect(find.byType(MascotHeader), findsOneWidget);
    expect(find.byType(AuthTabs), findsOneWidget);
    expect(indicator(tester), Alignment.centerRight);
    final indicatorBox = tester.getRect(
      find.descendant(
        of: find.byType(AnimatedAlign),
        matching: find.byType(DecoratedBox),
      ),
    );
    final tabsBox = tester.getRect(find.byType(AuthTabs));
    expect(indicatorBox.left, greaterThan(tabsBox.left + 4));
    expect(indicatorBox.left, lessThan(tabsBox.center.dx));

    // About 200 ms later the old form is gone.
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('Welcome back.'), findsNothing);
    expect(find.text('Let’s make it happen.'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(visits, isEmpty, reason: 'no page transition');
    expect(
      tester.element(find.byType(MascotHeader)),
      same(header),
      reason: 'the header is never rebuilt from scratch',
    );
  });

  testWidgets('the links under each form switch tabs too', (tester) async {
    final (:api, store: _) = fakeApi();
    await pumpScreen(tester, AuthScreen(api: api));

    await tapOn(tester, find.text('Create an account'));
    expect(find.text('Let’s make it happen.'), findsOneWidget);
    expect(indicator(tester), Alignment.centerRight);

    await tapOn(tester, find.widgetWithText(TextButton, 'Log in'));
    expect(find.text('Welcome back.'), findsOneWidget);
    expect(indicator(tester), Alignment.centerLeft);
  });

  testWidgets('can open on the create account tab', (tester) async {
    final (:api, store: _) = fakeApi();
    await pumpScreen(
      tester,
      AuthScreen(api: api, initialTab: AuthTab.register),
    );

    expect(find.text('Let’s make it happen.'), findsOneWidget);
    expect(indicator(tester), Alignment.centerRight);
  });
}
