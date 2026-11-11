import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/api_exception.dart';
import 'package:mobile/api/fake/fake_api_client.dart';
import 'package:mobile/api/fake/fake_world.dart';
import 'package:mobile/api/models/events.dart';
import 'package:mobile/auth/error_text.dart';
import 'package:mobile/home/event_dates.dart';
import 'package:mobile/routes.dart';
import 'package:mobile/screens/home_screen.dart';
import 'package:mobile/shell/app_tab.dart';

import '../support/screen_harness.dart';

/// A signed-in fake whose `GET /api/events/{slug}` fails while [failing].
class FailingEventApi extends FakeApiClient {
  FailingEventApi(MemoryTokenStore store)
    : super(tokenStore: store, delay: Duration.zero);

  bool failing = true;

  @override
  Future<EventInfo> getEvent(String slug) async {
    if (failing) {
      throw const ApiException(
        statusCode: null,
        code: 'network_error',
        message: 'x',
      );
    }
    return super.getEvent(slug);
  }
}

/// The tabs Home asked the shell to open.
final openedTabs = <AppTab>[];

Widget home(FakeApiClient api) => HomeScreen(
  api: api,
  eventSlug: fakeEventSlug,
  onOpenTab: openedTabs.add,
);

void main() {
  setUp(openedTabs.clear);

  testWidgets('shows loading, then the event', (tester) async {
    final (:api, store: _) = signedInFakeApi();
    await pumpScreen(tester, home(api));

    expect(find.text('Loading your event…'), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.text('YOUR EVENT'), findsOneWidget);
    expect(find.text('Hacker'), findsOneWidget);
    expect(find.text('Knight Hacks IX'), findsOneWidget);
    final event = await tester.runAsync(() => api.getEvent(fakeEventSlug));
    expect(
      find.text(EventDates.format(event!.startsAt, event.endsAt)),
      findsOneWidget,
    );
    for (final track in ['AI', 'Health', 'Fintech', 'Education']) {
      expect(find.text(track), findsOneWidget);
    }
    expect(find.text('1 new'), findsOneWidget);
    expect(find.text('MY TEAM'), findsOneWidget);
    expect(find.text('No team yet'), findsOneWidget);
    expect(find.text('PEOPLE YOU MIGHT LIKE'), findsOneWidget);
  });

  testWidgets('a failed load can be retried', (tester) async {
    final store = MemoryTokenStore()
      ..token = 'fake-jwt:${FakeApiClient.demoEmail}';
    final api = FailingEventApi(store);
    await pumpScreen(tester, home(api));
    await tester.pumpAndSettle();

    expect(find.text(ErrorText.unreachable), findsOneWidget);
    expect(find.text('YOUR EVENT'), findsNothing);

    api.failing = false;
    await tapOn(tester, find.text('Try again'));

    expect(find.text(ErrorText.unreachable), findsNothing);
    expect(find.text('Knight Hacks IX'), findsOneWidget);
  });

  testWidgets('an expired session goes back to log in', (tester) async {
    final (:api, :store) = fakeApi();
    store.token = 'fake-jwt:nobody@example.com';
    final visits = await pumpScreen(tester, home(api));
    await tester.pumpAndSettle();

    expect(visits.single.route, Routes.login);
  });

  testWidgets('saves looking for a team and availability right away', (
    tester,
  ) async {
    final (:api, store: _) = signedInFakeApi();
    await pumpScreen(tester, home(api));
    await tester.pumpAndSettle();

    await tapOn(tester, find.byKey(const Key('home-looking')));
    await tapOn(tester, find.text('Busy'));

    final saved = await tester.runAsync(() => api.getEventMe(fakeEventSlug));
    expect(saved!.looking, isFalse);
    expect(saved.availability, Availability.busy);
    expect(
      tester.widget<Switch>(find.byKey(const Key('home-looking'))).value,
      isFalse,
    );
  });

  testWidgets('creates a team from the sheet', (tester) async {
    final (:api, store: _) = signedInFakeApi();
    await pumpScreen(tester, home(api));
    await tester.pumpAndSettle();

    await tapOn(tester, find.text('Create team'));
    expect(find.text('Create a team'), findsOneWidget);

    final create = find.widgetWithText(FilledButton, 'Create team');
    await tapOn(tester, create);
    expect(find.text('Give your team a name.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('team-name')), 'Byte Me');
    await tapOn(tester, create);

    expect(find.text('Create a team'), findsNothing);
    expect(find.text('Byte Me'), findsOneWidget);
    expect(find.text('1 of 4 members · You lead it'), findsOneWidget);
  });

  testWidgets('Requests opens 09 for this event', (tester) async {
    final (:api, store: _) = signedInFakeApi();
    final visits = await pumpScreen(tester, home(api));
    await tester.pumpAndSettle();

    await tapOn(tester, find.text('Requests'));

    expect(visits.single.route, Routes.requests);
    expect(
      (visits.single.arguments as RequestsArgs).eventSlug,
      fakeEventSlug,
    );
  });

  testWidgets('without wanted skills it asks for some, which opens Me', (
    tester,
  ) async {
    final (:api, store: _) = signedInFakeApi();
    await pumpScreen(tester, home(api));
    await tester.pumpAndSettle();

    await tapOn(tester, find.textContaining('Add skills you want to learn'));

    expect(openedTabs, [AppTab.me]);
  });

  testWidgets('suggests people who know a wanted skill and opens 07', (
    tester,
  ) async {
    final (:api, store: _) = signedInFakeApi();
    await tester.runAsync(
      () => api.updateEventMe(
        fakeEventSlug,
        const UpdateEventMeBody(skillsWanted: ['flutter']),
      ),
    );
    final visits = await pumpScreen(tester, home(api));
    await tester.pumpAndSettle();

    expect(find.text('Sam Rivera'), findsOneWidget);
    expect(find.text('@sam_mentor · flutter, firebase, dart'), findsOneWidget);

    await tapOn(tester, find.text('Sam Rivera'));

    expect(visits.single.route, Routes.person);
    final args = visits.single.arguments as PersonArgs;
    expect(args.eventSlug, fakeEventSlug);
    expect(args.handle, 'sam_mentor');
  });
}
