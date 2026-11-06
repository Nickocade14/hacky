import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/api_exception.dart';
import 'package:mobile/api/fake/fake_api_client.dart';
import 'package:mobile/api/fake/fake_world.dart';
import 'package:mobile/api/models/auth.dart';
import 'package:mobile/api/models/search.dart';
import 'package:mobile/auth/error_text.dart';
import 'package:mobile/routes.dart';
import 'package:mobile/screens/search_people_screen.dart';
import 'package:mobile/widgets/people_search_widgets.dart';

import '../people/controlled_search_api.dart';
import '../support/screen_harness.dart';

const _debounce = Duration(milliseconds: 300);

final _field = find.byKey(PeopleSearchField.fieldKey);

/// A signed-in fake that records each search and fails while [failing].
class RecordingSearchApi extends FakeApiClient {
  RecordingSearchApi(MemoryTokenStore store)
    : super(tokenStore: store, delay: Duration.zero);

  final queries = <(String, MemberRole?)>[];
  ApiException? failing;

  @override
  Future<SearchResults> search({
    required String event,
    required String q,
    MemberRole? role,
    int? limit,
  }) async {
    queries.add((q, role));
    final error = failing;
    if (error != null) throw error;
    return super.search(event: event, q: q, role: role, limit: limit);
  }
}

RecordingSearchApi recordingApi() => RecordingSearchApi(
  MemoryTokenStore()..token = 'fake-jwt:${FakeApiClient.demoEmail}',
);

Widget screen(FakeApiClient api) =>
    SearchPeopleScreen(api: api, eventSlug: fakeEventSlug);

/// Types [text] and lets the debounce and the fake answer run.
Future<void> typeAndWait(WidgetTester tester, String text) async {
  await tester.enterText(_field, text);
  await tester.pump(_debounce);
  await tester.pumpAndSettle();
}

/// The plain text of every rich text on screen.
List<String> richTexts(WidgetTester tester) => [
  for (final widget in tester.widgetList<RichText>(find.byType(RichText)))
    widget.text.toPlainText(),
];

void main() {
  testWidgets('starts with the empty-query state and asks nothing', (
    tester,
  ) async {
    final api = recordingApi();
    await pumpScreen(tester, screen(api));
    await tester.pumpAndSettle();

    expect(find.text('People'), findsOneWidget);
    expect(find.text('Find your people'), findsOneWidget);
    expect(find.text('Search name, handle or skill'), findsOneWidget);
    expect(api.queries, isEmpty);
  });

  testWidgets('partial text finds people on the server, matches in bold', (
    tester,
  ) async {
    final api = recordingApi();
    await pumpScreen(tester, screen(api));
    await tester.pumpAndSettle();

    await tester.enterText(_field, 'rea');
    await tester.pump();
    expect(find.text('Searching…'), findsOneWidget);

    await tester.pump(_debounce);
    await tester.pumpAndSettle();

    expect(api.queries, [('rea', null)]);
    expect(find.text('2 people in Knight Hacks IX'), findsOneWidget);
    expect(find.text('Leo Nguyen'), findsOneWidget);
    expect(find.text('Jordan Lee'), findsOneWidget);
    expect(richTexts(tester), contains('@leo_builds · react, node, mongodb'));

    final react = find.byWidgetPredicate(
      (w) =>
          w is RichText &&
          w.text.toPlainText().startsWith('@leo_builds') &&
          _hasBold(w.text, 'rea'),
    );
    expect(react, findsOneWidget);
  });

  testWidgets('typing fast sends one search for the last text', (
    tester,
  ) async {
    final api = recordingApi();
    await pumpScreen(tester, screen(api));
    await tester.pumpAndSettle();

    for (final text in ['p', 'pr', 'pri']) {
      await tester.enterText(_field, text);
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(_debounce);
    await tester.pumpAndSettle();

    expect(api.queries, [('pri', null)]);
    expect(find.text('Priya Shah'), findsOneWidget);
  });

  testWidgets('a slow older reply never replaces newer results', (
    tester,
  ) async {
    final api = ControlledSearchApi();
    await pumpScreen(tester, screen(api));
    await tester.pumpAndSettle();

    await tester.enterText(_field, 're');
    await tester.pump(_debounce);
    await tester.enterText(_field, 'rea');
    await tester.pump(_debounce);
    expect(api.calls.map((c) => c.q), ['re', 'rea']);

    api.calls[1].answer([hit('Reagan Smith', 'reagan')]);
    await tester.pump();
    api.calls[0].answer([hit('Andrea Lopez', 'andrea_l')]);
    await tester.pump();

    expect(find.text('Reagan Smith'), findsOneWidget);
    expect(find.text('Andrea Lopez'), findsNothing);
  });

  testWidgets('shows the no-results state', (tester) async {
    final api = recordingApi();
    await pumpScreen(tester, screen(api));
    await tester.pumpAndSettle();

    await typeAndWait(tester, 'xyz');

    expect(find.text('No one matches “xyz” yet.'), findsOneWidget);
    expect(find.text('Try a skill like React.'), findsOneWidget);
  });

  testWidgets('the role filter searches again with that role', (tester) async {
    final api = recordingApi();
    await pumpScreen(tester, screen(api));
    await tester.pumpAndSettle();

    await typeAndWait(tester, 'fl');
    await tapOn(tester, find.byKey(RoleFilterBar.keyOf(MemberRole.mentor)));

    expect(api.queries, [('fl', null), ('fl', MemberRole.mentor)]);
    expect(find.text('Sam Rivera'), findsOneWidget);
    expect(find.text('1 person in Knight Hacks IX'), findsOneWidget);

    await tapOn(tester, find.byKey(RoleFilterBar.keyOf(MemberRole.sponsor)));
    expect(find.text('No one matches “fl” yet.'), findsOneWidget);
  });

  testWidgets('× clears the text and goes back to the empty state', (
    tester,
  ) async {
    final api = recordingApi();
    await pumpScreen(tester, screen(api));
    await tester.pumpAndSettle();

    await typeAndWait(tester, 'pri');
    await tapOn(tester, find.byKey(PeopleSearchField.clearKey));

    expect(find.text('Find your people'), findsOneWidget);
    expect(find.text('Priya Shah'), findsNothing);
    expect(api.queries, [('pri', null)]);
  });

  testWidgets('a failed search shows the error and can be retried', (
    tester,
  ) async {
    final api = recordingApi()
      ..failing = const ApiException(
        statusCode: null,
        code: 'network_error',
        message: 'x',
      );
    await pumpScreen(tester, screen(api));
    await tester.pumpAndSettle();

    await typeAndWait(tester, 'pri');
    expect(find.text(ErrorText.unreachable), findsOneWidget);

    api.failing = null;
    await tapOn(tester, find.text('Try again'));

    expect(find.text(ErrorText.unreachable), findsNothing);
    expect(find.text('Priya Shah'), findsOneWidget);
    expect(api.queries, [('pri', null), ('pri', null)]);
  });

  testWidgets('an expired session goes back to log in', (tester) async {
    final api = recordingApi()
      ..failing = const ApiException(
        statusCode: 401,
        code: 'unauthorized',
        message: 'x',
      );
    final visits = await pumpScreen(tester, screen(api));
    await tester.pumpAndSettle();

    await typeAndWait(tester, 'pri');

    expect(visits.single.route, Routes.login);
  });

  testWidgets('tapping a person opens 07 with their handle', (tester) async {
    final api = recordingApi();
    final visits = await pumpScreen(tester, screen(api));
    await tester.pumpAndSettle();

    await typeAndWait(tester, 'pri');
    await tapOn(tester, find.text('Priya Shah'));

    expect(visits.single.route, Routes.person);
    final args = visits.single.arguments as PersonArgs;
    expect(args.eventSlug, fakeEventSlug);
    expect(args.handle, 'priya_codes');
  });
}

/// Whether [span] has a bold child whose text is [part], ignoring case.
bool _hasBold(InlineSpan span, String part) {
  var found = false;
  span.visitChildren((child) {
    if (child is TextSpan &&
        child.style?.fontWeight == FontWeight.w700 &&
        child.text?.toLowerCase() == part) {
      found = true;
    }
    return !found;
  });
  return found;
}
