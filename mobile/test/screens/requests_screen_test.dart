import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/api_exception.dart';
import 'package:mobile/api/fake/fake_api_client.dart';
import 'package:mobile/api/fake/fake_world.dart';
import 'package:mobile/api/models/auth.dart';
import 'package:mobile/api/models/requests.dart';
import 'package:mobile/api/models/teams.dart';
import 'package:mobile/auth/error_text.dart';
import 'package:mobile/requests/request_lists.dart';
import 'package:mobile/routes.dart';
import 'package:mobile/screens/requests_screen.dart';
import 'package:mobile/widgets/app_widgets.dart';
import 'package:mobile/widgets/request_cards.dart';

import '../requests/request_fixtures.dart';
import '../support/screen_harness.dart';

/// A signed-in fake whose requests the test sets, with switches to make
/// each call fail or wait.
class ScriptedRequestsApi extends FakeApiClient {
  ScriptedRequestsApi(this.requests)
    : super(
        tokenStore: MemoryTokenStore()
          ..token = 'fake-jwt:${FakeApiClient.demoEmail}',
        delay: Duration.zero,
      );

  List<ConnectionRequest> requests;
  ApiException? loadError;
  ApiException? actionError;

  /// While set, accept and hide wait for it.
  Completer<void>? gate;
  int acceptCalls = 0;
  int hideCalls = 0;
  int loads = 0;

  @override
  Future<List<ConnectionRequest>> listRequests(String slug) async {
    loads++;
    final error = loadError;
    if (error != null) throw error;
    return requests;
  }

  @override
  Future<RequestResult> acceptRequest(String requestId) async {
    acceptCalls++;
    await gate?.future;
    final error = actionError;
    if (error != null) throw error;
    final accepted = acceptedCopy(
      requests.firstWhere((r) => r.id == requestId),
      'conv-$requestId',
    );
    requests = requests.replacing(accepted);
    return RequestResult(request: accepted);
  }

  @override
  Future<void> hideRequest(String requestId) async {
    hideCalls++;
    await gate?.future;
    final error = actionError;
    if (error != null) throw error;
  }
}

const conflict = ApiException(
  statusCode: 409,
  code: 'conflict',
  message: 'The team is full.',
);

Widget requestsScreen(FakeApiClient api) =>
    RequestsScreen(api: api, eventSlug: fakeEventSlug);

Finder inCard(String id, Finder finder) =>
    find.descendant(of: find.byKey(RequestCard.keyOf(id)), matching: finder);

Finder acceptButton([String? id]) {
  final button = find.widgetWithText(FilledButton, 'Accept');
  return id == null ? button : inCard(id, button);
}

Finder hideButton([String? id]) {
  final button = find.widgetWithText(OutlinedButton, 'Not now');
  return id == null ? button : inCard(id, button);
}

bool enabled(WidgetTester tester, Finder button) =>
    tester.widget<ButtonStyleButton>(button).onPressed != null;

Future<void> goBack(WidgetTester tester) async {
  tester.state<NavigatorState>(find.byType(Navigator)).pop();
  await tester.pumpAndSettle();
}

void main() {
  group('with the demo data', () {
    testWidgets('shows loading, then incoming, hidden and accepted requests', (
      tester,
    ) async {
      final (:api, store: _) = signedInFakeApi();
      await pumpScreen(tester, requestsScreen(api));

      expect(find.text('Loading your requests…'), findsOneWidget);
      await tester.pumpAndSettle();

      expect(find.text('Requests'), findsOneWidget);
      expect(find.text('Incoming (1)'), findsOneWidget);
      expect(find.text('Outgoing (0)'), findsOneWidget);

      // Jordan is waiting for an answer.
      expect(find.text('Jordan Lee'), findsOneWidget);
      expect(
        find.text('“Hi! I design in Figma and would love to pair on an app.”'),
        findsOneWidget,
      );
      expect(find.text('Teammate'), findsWidgets);
      expect(find.text('via Hacky'), findsOneWidget);
      expect(acceptButton(), findsOneWidget);
      expect(hideButton(), findsOneWidget);

      // Leo was hidden: folded away, and only Accept once opened.
      expect(find.text('Hidden (1)'), findsOneWidget);
      expect(find.text('Leo Nguyen'), findsNothing);

      // Priya is accepted, with Message.
      expect(find.text('ACCEPTED'), findsOneWidget);
      expect(find.text('Priya Shah'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Message'), findsOneWidget);

      await tapOn(tester, find.text('Hidden (1)'));
      expect(find.textContaining('Need another JavaScript person?'),
          findsOneWidget);
      expect(acceptButton(), findsNWidgets(2));
      expect(hideButton(), findsOneWidget);
    });

    testWidgets('Accept opens the new chat and the list updates', (
      tester,
    ) async {
      final (:api, store: _) = signedInFakeApi();
      final visits = await pumpScreen(tester, requestsScreen(api));
      await tester.pumpAndSettle();

      await tapOn(tester, acceptButton());

      final requests = await tester.runAsync(
        () => api.listRequests(fakeEventSlug),
      );
      final jordan = requests!.firstWhere((r) => r.person.name == 'Jordan Lee');
      expect(jordan.status, ConnectionStatus.accepted);
      expect(visits.single.route, Routes.chatThread);
      final args = visits.single.arguments as ChatThreadArgs;
      expect(args.eventSlug, fakeEventSlug);
      expect(args.conversationId, jordan.conversationId);

      await goBack(tester);
      expect(find.text('Incoming (0)'), findsOneWidget);
      expect(find.text('No new requests right now.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Message'), findsNWidgets(2));
    });

    testWidgets('Not now hides the request and says the sender isn’t told', (
      tester,
    ) async {
      final (:api, store: _) = signedInFakeApi();
      await pumpScreen(tester, requestsScreen(api));
      await tester.pumpAndSettle();

      await tapOn(tester, hideButton());

      expect(find.text('Hidden. Jordan Lee isn’t told.'), findsOneWidget);
      expect(find.text('Incoming (0)'), findsOneWidget);
      expect(find.text('Hidden (2)'), findsOneWidget);
      expect(find.text('Jordan Lee'), findsNothing);

      final requests = await tester.runAsync(
        () => api.listRequests(fakeEventSlug),
      );
      final jordan = requests!.firstWhere((r) => r.person.name == 'Jordan Lee');
      expect(jordan.hiddenAt, isNotNull);
      expect(jordan.status, ConnectionStatus.pending);
    });

    testWidgets('a name opens their profile', (tester) async {
      final (:api, store: _) = signedInFakeApi();
      final visits = await pumpScreen(tester, requestsScreen(api));
      await tester.pumpAndSettle();

      await tapOn(tester, find.text('Jordan Lee'));

      expect(visits.single.route, Routes.person);
      final args = visits.single.arguments as PersonArgs;
      expect(args.eventSlug, fakeEventSlug);
      expect(args.handle, 'jordan_ux');
    });

    testWidgets('Message on an accepted request opens its chat', (
      tester,
    ) async {
      final (:api, store: _) = signedInFakeApi();
      final visits = await pumpScreen(tester, requestsScreen(api));
      await tester.pumpAndSettle();

      await tapOn(tester, find.widgetWithText(FilledButton, 'Message'));

      final requests = await tester.runAsync(
        () => api.listRequests(fakeEventSlug),
      );
      final priya = requests!.firstWhere((r) => r.person.name == 'Priya Shah');
      expect(visits.single.route, Routes.chatThread);
      expect(
        (visits.single.arguments as ChatThreadArgs).conversationId,
        priya.conversationId,
      );
    });

    testWidgets('an expired session goes back to log in', (tester) async {
      final (:api, :store) = fakeApi();
      store.token = 'fake-jwt:nobody@example.com';
      final visits = await pumpScreen(tester, requestsScreen(api));
      await tester.pumpAndSettle();

      expect(visits.single.route, Routes.login);
    });
  });

  group('with scripted requests', () {
    final maya = request('maya', from: person('maya_ml', 'Maya Chen'));
    final teamJoin = request(
      'team',
      from: person('andrea_l', 'Andrea Lopez'),
      team: const TeamRef(id: 't1', name: 'Byte Me'),
      intro: 'Can I join? I do Flutter.',
      source: ConnectionSource.profile,
    );
    final toMentor = request(
      'sam',
      from: person('sam_mentor', 'Sam Rivera', role: MemberRole.mentor),
      direction: RequestDirection.outgoing,
      intro: 'Could you look at our Firebase rules?',
      source: ConnectionSource.qr,
    );

    testWidgets('shows a team join request and the outgoing tab', (
      tester,
    ) async {
      final api = ScriptedRequestsApi([maya, teamJoin, toMentor]);
      await pumpScreen(tester, requestsScreen(api));
      await tester.pumpAndSettle();

      expect(find.text('Incoming (2)'), findsOneWidget);
      expect(find.text('Outgoing (1)'), findsOneWidget);
      expect(inCard('team', find.text('Team join')), findsOneWidget);
      expect(inCard('team', find.text('Team Byte Me')), findsOneWidget);
      expect(inCard('team', find.text('Wants to join Byte Me')), findsOneWidget);
      expect(inCard('team', find.text('from profile')), findsOneWidget);
      expect(acceptButton('team'), findsOneWidget);

      await tapOn(tester, find.text('Outgoing (1)'));

      expect(find.text('Sam Rivera'), findsOneWidget);
      expect(inCard('sam', find.text('Mentor')), findsOneWidget);
      expect(inCard('sam', find.text('Pending')), findsOneWidget);
      expect(inCard('sam', find.text('via QR code')), findsOneWidget);
      expect(acceptButton('sam'), findsNothing);
      expect(hideButton('sam'), findsNothing);
      expect(inCard('sam', find.byType(ButtonStyleButton)), findsNothing);
    });

    testWidgets('a row is busy while its action runs and ignores more taps', (
      tester,
    ) async {
      final api = ScriptedRequestsApi([maya, teamJoin])..gate = Completer();
      final visits = await pumpScreen(tester, requestsScreen(api));
      await tester.pumpAndSettle();

      await tester.tap(acceptButton('maya'));
      await tester.pump();

      expect(enabled(tester, acceptButton('maya')), isFalse);
      expect(enabled(tester, hideButton('maya')), isFalse);
      expect(inCard('maya', find.byType(CircularProgressIndicator)),
          findsOneWidget);
      // The other row still works.
      expect(enabled(tester, acceptButton('team')), isTrue);

      await tester.tap(acceptButton('maya'), warnIfMissed: false);
      await tester.tap(hideButton('maya'), warnIfMissed: false);
      await tester.pump();
      expect(api.acceptCalls, 1);
      expect(api.hideCalls, 0);

      api.gate!.complete();
      await tester.pumpAndSettle();

      expect(api.acceptCalls, 1);
      expect(visits.single.route, Routes.chatThread);
      expect(
        (visits.single.arguments as ChatThreadArgs).conversationId,
        'conv-maya',
      );
    });

    testWidgets('a failed Accept shows the error and reloads the list', (
      tester,
    ) async {
      final api = ScriptedRequestsApi([teamJoin])..actionError = conflict;
      final visits = await pumpScreen(tester, requestsScreen(api));
      await tester.pumpAndSettle();
      expect(api.loads, 1);

      await tapOn(tester, acceptButton('team'));

      expect(find.text('The team is full.'), findsOneWidget);
      expect(visits, isEmpty);
      expect(api.loads, 2);
      expect(enabled(tester, acceptButton('team')), isTrue);
      expect(enabled(tester, hideButton('team')), isTrue);
    });

    testWidgets('a failed Not now shows the error and keeps the request', (
      tester,
    ) async {
      final api = ScriptedRequestsApi([maya])
        ..actionError = const ApiException(
          statusCode: null,
          code: 'network_error',
          message: 'x',
        );
      await pumpScreen(tester, requestsScreen(api));
      await tester.pumpAndSettle();

      await tapOn(tester, hideButton('maya'));

      expect(find.text(ErrorText.unreachable), findsOneWidget);
      expect(find.text('Incoming (1)'), findsOneWidget);
      expect(find.text('Hidden (1)'), findsNothing);
      expect(enabled(tester, hideButton('maya')), isTrue);
    });

    testWidgets('a failed load can be retried', (tester) async {
      final api = ScriptedRequestsApi([maya])
        ..loadError = const ApiException(
          statusCode: null,
          code: 'network_error',
          message: 'x',
        );
      await pumpScreen(tester, requestsScreen(api));
      await tester.pumpAndSettle();

      expect(find.text(ErrorText.unreachable), findsOneWidget);
      expect(find.text('Maya Chen'), findsNothing);

      api.loadError = null;
      await tapOn(tester, find.text('Try again'));

      expect(find.text(ErrorText.unreachable), findsNothing);
      expect(find.text('Maya Chen'), findsOneWidget);
    });

    testWidgets('empty tabs show the knit Hacky', (tester) async {
      final api = ScriptedRequestsApi([]);
      await pumpScreen(tester, requestsScreen(api));
      await tester.pumpAndSettle();

      expect(find.text('Incoming (0)'), findsOneWidget);
      expect(find.text('No requests yet'), findsOneWidget);
      expect(find.byType(KnitHacky), findsOneWidget);

      await tapOn(tester, find.text('Outgoing (0)'));

      expect(find.text('You haven’t sent any requests'), findsOneWidget);
    });

    testWidgets('pull to refresh loads new requests', (tester) async {
      final api = ScriptedRequestsApi([]);
      await pumpScreen(tester, requestsScreen(api));
      await tester.pumpAndSettle();
      expect(find.text('No requests yet'), findsOneWidget);

      api.requests = [maya];
      await tester.fling(
        find.text('No requests yet'),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();

      expect(api.loads, 2);
      expect(find.text('Maya Chen'), findsOneWidget);
      expect(find.text('Incoming (1)'), findsOneWidget);
    });

    testWidgets('a failed refresh keeps the list and shows the error', (
      tester,
    ) async {
      final api = ScriptedRequestsApi([maya]);
      await pumpScreen(tester, requestsScreen(api));
      await tester.pumpAndSettle();

      api.loadError = const ApiException(
        statusCode: null,
        code: 'network_error',
        message: 'x',
      );
      await tester.fling(find.text('Maya Chen'), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      expect(find.text(ErrorText.unreachable), findsOneWidget);
      expect(find.text('Maya Chen'), findsOneWidget);
    });
  });
}
