import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/api_exception.dart';
import 'package:mobile/api/fake/fake_api_client.dart';
import 'package:mobile/api/fake/fake_world.dart';
import 'package:mobile/api/models/people.dart';
import 'package:mobile/api/models/requests.dart';
import 'package:mobile/auth/error_text.dart';
import 'package:mobile/routes.dart';
import 'package:mobile/screens/person_profile_screen.dart';
import 'package:mobile/widgets/connect_sheet.dart';
import 'package:mobile/widgets/relation_actions.dart';

import '../support/screen_harness.dart';

const _offline = ApiException(
  statusCode: null,
  code: 'network_error',
  message: 'x',
);

/// A signed-in fake where each call can be made to fail.
class ScriptedProfileApi extends FakeApiClient {
  ScriptedProfileApi()
    : super(
        tokenStore: MemoryTokenStore()
          ..token = 'fake-jwt:${FakeApiClient.demoEmail}',
        delay: Duration.zero,
      );

  ApiException? getPersonError;
  ApiException? sendError;
  ApiException? acceptError;

  @override
  Future<PersonDetail> getPerson(String slug, String handle) async {
    if (getPersonError case final error?) throw error;
    return super.getPerson(slug, handle);
  }

  @override
  Future<RequestResult> sendRequest(String slug, SendRequestBody body) async {
    if (sendError case final error?) throw error;
    return super.sendRequest(slug, body);
  }

  @override
  Future<RequestResult> acceptRequest(String requestId) async {
    if (acceptError case final error?) throw error;
    return super.acceptRequest(requestId);
  }
}

Widget profile(FakeApiClient api, String handle) =>
    PersonProfileScreen(api: api, eventSlug: fakeEventSlug, handle: handle);

Future<List<Visit>> openProfile(
  WidgetTester tester,
  FakeApiClient api,
  String handle,
) async {
  final visits = await pumpScreen(tester, profile(api, handle));
  await tester.pumpAndSettle();
  return visits;
}

/// The request I have with [handle], as the server sees it.
Future<ConnectionRequest?> requestWith(
  WidgetTester tester,
  FakeApiClient api,
  String handle,
) async {
  final requests = await tester.runAsync(
    () => api.listRequests(fakeEventSlug),
  );
  return requests!.where((r) => r.person.handle == handle).firstOrNull;
}

void main() {
  testWidgets('shows loading, then the profile and its sections', (
    tester,
  ) async {
    final api = ScriptedProfileApi();
    await pumpScreen(tester, profile(api, 'maya_ml'));

    expect(find.text('Loading profile…'), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Maya Patel'), findsOneWidget);
    expect(find.text('@maya_ml · Hacker'), findsOneWidget);
    expect(find.text('Available'), findsOneWidget);
    expect(find.text('Looking for a team'), findsOneWidget);
    expect(find.text('ABOUT'), findsOneWidget);
    expect(find.text('ML student at UCF. Health tech nerd.'), findsOneWidget);
    expect(find.text('SKILLS'), findsOneWidget);
    expect(find.text('pytorch'), findsOneWidget);
    expect(find.text('WANTS TO LEARN'), findsOneWidget);
    expect(find.text('flutter'), findsOneWidget);
    expect(find.text('TRACK · IDEA'), findsOneWidget);
    expect(
      find.text('Health · Skin rash triage from a phone photo'),
      findsOneWidget,
    );
    expect(find.text('LINKS'), findsOneWidget);
    expect(find.text('GitHub'), findsOneWidget);
    expect(find.text('Connect with Maya'), findsOneWidget);
  });

  testWidgets('a verified mentor shows it, and empty sections are left out', (
    tester,
  ) async {
    await openProfile(tester, ScriptedProfileApi(), 'sam_mentor');

    expect(find.text('@sam_mentor · Mentor · Verified'), findsOneWidget);
    expect(find.text('Busy'), findsOneWidget);
    expect(find.text('Looking for a team'), findsNothing);
    expect(find.text('WANTS TO LEARN'), findsNothing);
    expect(find.text('TRACK · IDEA'), findsNothing);
    expect(find.text('LINKS'), findsNothing);
  });

  testWidgets('a link tap copies it', (tester) async {
    Object? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') copied = call.arguments;
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await openProfile(tester, ScriptedProfileApi(), 'maya_ml');

    await tapOn(tester, find.byKey(const Key('person-link-github')));

    expect(copied, {'text': 'https://github.com/maya-ml'});
    expect(
      find.text('GitHub link copied: https://github.com/maya-ml'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('Connect checks the intro, sends it and shows Request sent', (
    tester,
  ) async {
    final api = ScriptedProfileApi();
    await openProfile(tester, api, 'maya_ml');

    await tapOn(tester, find.byKey(RelationActions.connectKey));
    expect(find.text('Say hi to Maya'), findsOneWidget);

    final send = find.widgetWithText(FilledButton, 'Send request');
    await tapOn(tester, send);
    expect(find.text('Write a short intro first.'), findsOneWidget);

    await tester.enterText(
      find.byKey(ConnectSheet.introKey),
      'See www.example.com',
    );
    await tapOn(tester, send);
    expect(find.text('Intros can’t contain links.'), findsOneWidget);

    await tester.enterText(
      find.byKey(ConnectSheet.introKey),
      '  I can build the Flutter app for your triage idea!  ',
    );
    await tapOn(tester, send);

    expect(find.text('Say hi to Maya'), findsNothing);
    expect(find.byKey(RelationActions.sentKey), findsOneWidget);
    expect(find.byKey(RelationActions.connectKey), findsNothing);
    expect(
      find.text('Request sent. You’ll get a chat when Maya accepts.'),
      findsOneWidget,
    );

    final sent = await requestWith(tester, api, 'maya_ml');
    expect(sent!.direction, RequestDirection.outgoing);
    expect(sent.intro, 'I can build the Flutter app for your triage idea!');
    expect(sent.source, ConnectionSource.profile);
  });

  testWidgets('a failed send stays in the sheet with the error', (
    tester,
  ) async {
    final api = ScriptedProfileApi()..sendError = _offline;
    await openProfile(tester, api, 'maya_ml');

    await tapOn(tester, find.byKey(RelationActions.connectKey));
    await tester.enterText(find.byKey(ConnectSheet.introKey), 'Hi Maya!');
    await tapOn(tester, find.widgetWithText(FilledButton, 'Send request'));

    expect(find.text('Say hi to Maya'), findsOneWidget);
    expect(find.text(ErrorText.unreachable), findsOneWidget);
    expect(await requestWith(tester, api, 'maya_ml'), isNull);
  });

  testWidgets('Accept connects, then Message opens 11', (tester) async {
    final api = ScriptedProfileApi();
    final visits = await openProfile(tester, api, 'jordan_ux');

    expect(find.text('Jordan wants to connect with you.'), findsOneWidget);
    await tapOn(tester, find.byKey(RelationActions.acceptKey));

    expect(find.byKey(RelationActions.acceptKey), findsNothing);
    expect(find.text('Message Jordan'), findsOneWidget);
    expect(find.text('You and Jordan are connected. Say hi!'), findsOneWidget);

    await tapOn(tester, find.byKey(RelationActions.messageKey));

    final accepted = await requestWith(tester, api, 'jordan_ux');
    expect(accepted!.status, ConnectionStatus.accepted);
    expect(visits.single.route, Routes.chatThread);
    final args = visits.single.arguments as ChatThreadArgs;
    expect(args.eventSlug, fakeEventSlug);
    expect(args.conversationId, accepted.conversationId);
  });

  testWidgets('a failed accept shows the error and keeps the buttons', (
    tester,
  ) async {
    final api = ScriptedProfileApi()..acceptError = _offline;
    await openProfile(tester, api, 'jordan_ux');

    await tapOn(tester, find.byKey(RelationActions.acceptKey));

    expect(find.text(ErrorText.unreachable), findsOneWidget);
    expect(find.byKey(RelationActions.acceptKey), findsOneWidget);
    expect(find.byKey(RelationActions.notNowKey), findsOneWidget);
  });

  testWidgets('Not now hides the request and keeps Accept', (tester) async {
    final api = ScriptedProfileApi();
    await openProfile(tester, api, 'jordan_ux');

    await tapOn(tester, find.byKey(RelationActions.notNowKey));

    expect(find.byKey(RelationActions.notNowKey), findsNothing);
    expect(find.byKey(RelationActions.acceptKey), findsOneWidget);
    expect(
      find.text('Hidden. You can still accept it from Requests.'),
      findsOneWidget,
    );
    final hidden = await requestWith(tester, api, 'jordan_ux');
    expect(hidden!.hiddenAt, isNotNull);
  });

  testWidgets('someone I am connected with gets Message → 11', (
    tester,
  ) async {
    final api = ScriptedProfileApi();
    final visits = await openProfile(tester, api, 'priya_codes');

    await tapOn(tester, find.text('Message Priya'));

    final request = await requestWith(tester, api, 'priya_codes');
    expect(visits.single.route, Routes.chatThread);
    expect(
      (visits.single.arguments as ChatThreadArgs).conversationId,
      request!.conversationId,
    );
  });

  testWidgets('an unknown handle says the profile is not available', (
    tester,
  ) async {
    await openProfile(tester, ScriptedProfileApi(), 'nobody_here');

    expect(find.text('This profile isn’t available'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('a failed load can be retried', (tester) async {
    final api = ScriptedProfileApi()..getPersonError = _offline;
    await openProfile(tester, api, 'maya_ml');

    expect(find.text(ErrorText.unreachable), findsOneWidget);

    api.getPersonError = null;
    await tapOn(tester, find.text('Try again'));

    expect(find.text('Maya Patel'), findsOneWidget);
  });

  testWidgets('an expired session goes back to log in', (tester) async {
    final api = ScriptedProfileApi()
      ..getPersonError = const ApiException(
        statusCode: 401,
        code: 'unauthorized',
        message: 'x',
      );
    final visits = await openProfile(tester, api, 'maya_ml');

    expect(visits.single.route, Routes.login);
  });
}
