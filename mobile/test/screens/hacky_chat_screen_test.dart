import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/api_exception.dart';
import 'package:mobile/api/fake/fake_api_client.dart';
import 'package:mobile/api/fake/fake_world.dart';
import 'package:mobile/api/models/chat.dart';
import 'package:mobile/api/models/requests.dart';
import 'package:mobile/auth/error_text.dart';
import 'package:mobile/routes.dart';
import 'package:mobile/screens/hacky_chat_screen.dart';
import 'package:mobile/widgets/confirm_action_dialog.dart';
import 'package:mobile/widgets/hacky_chat_widgets.dart';
import 'package:mobile/widgets/hacky_intro.dart';

import '../hacky/hacky_fixtures.dart';
import '../support/screen_harness.dart';

const offline = ApiException(
  statusCode: null,
  code: 'network_error',
  message: 'x',
);

/// The fake client, signed in as the demo user, with a chat the test can
/// script: a stored [history], a [reply], a [gate] that holds the answer
/// back, and errors.
class ScriptedChatApi extends FakeApiClient {
  ScriptedChatApi()
    : super(
        tokenStore: MemoryTokenStore()
          ..token = 'fake-jwt:${FakeApiClient.demoEmail}',
        delay: Duration.zero,
      );

  List<ChatMessage>? history;
  ApiException? historyError;
  ChatMessage? reply;
  ApiException? sendError;
  Completer<void>? gate;
  final sent = <String>[];

  @override
  Future<List<ChatMessage>> getChatHistory(String slug) async {
    if (historyError case final error?) throw error;
    return history ?? super.getChatHistory(slug);
  }

  @override
  Future<ChatMessage> sendChat(String slug, ChatBody body) async {
    sent.add(body.message.parts.single['text'] as String);
    await gate?.future;
    if (sendError case final error?) throw error;
    return reply ?? super.sendChat(slug, body);
  }
}

ChatMessage user(String text, {String? id}) => ChatMessage(
  id: id ?? 'u-$text',
  role: ChatRole.user,
  parts: [textPart(text)],
);

ChatMessage hacky(List<Map<String, dynamic>> parts, {String id = 'a1'}) =>
    ChatMessage(id: id, role: ChatRole.assistant, parts: parts);

Widget chat(FakeApiClient api) =>
    HackyChatScreen(api: api, me: demoMe, eventSlug: fakeEventSlug);

/// A fake person as a card's `PersonSummary` JSON, with their real id.
Future<Map<String, dynamic>> fakePerson(
  WidgetTester tester,
  FakeApiClient api,
  String handle,
) async {
  final person = await tester.runAsync(
    () => api.getPerson(fakeEventSlug, handle),
  );
  return personJson(
    userId: person!.userId,
    handle: person.handle,
    name: person.name,
    role: person.role.name,
  );
}

Future<void> typeAndSend(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(ChatComposer.fieldKey), text);
  await tester.pump();
  await tester.tap(find.byKey(ChatComposer.sendKey));
}

IconButton sendButton(WidgetTester tester) =>
    tester.widget<IconButton>(find.byKey(ChatComposer.sendKey));

TextButton newChatButton(WidgetTester tester) =>
    tester.widget<TextButton>(find.byKey(NewChatButton.buttonKey));

void main() {
  testWidgets('first time: the brief with its starting points', (
    tester,
  ) async {
    final api = ScriptedChatApi();
    await pumpScreen(tester, chat(api));

    expect(find.text('Loading your chat…'), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.text(HackyBrief.title), findsOneWidget);
    for (final starter in HackyStarter.all) {
      expect(find.text(starter.label), findsOneWidget);
    }
    expect(find.text(ChatComposer.note), findsOneWidget);
    expect(sendButton(tester).onPressed, isNull);
    expect(newChatButton(tester).onPressed, isNull);

    await tapOn(tester, find.text('Find mentor'));

    expect(api.sent, ['Find a mentor']);
    expect(find.text('Find a mentor'), findsOneWidget);
    expect(find.textContaining('I didn\'t find anyone'), findsOneWidget);
    // The brief stays above the history.
    expect(find.byType(HackyBrief, skipOffstage: false), findsOneWidget);
    expect(newChatButton(tester).onPressed, isNotNull);
  });

  testWidgets('New chat clears the screen after asking', (tester) async {
    final api = ScriptedChatApi()
      ..history = [
        user('Find me a backend teammate'),
        hacky([textPart('Priya does Go and Postgres.')]),
      ];
    await pumpScreen(tester, chat(api));
    await tester.pumpAndSettle();

    await tapOn(tester, find.byKey(NewChatButton.buttonKey));
    expect(find.text('Start a new chat?'), findsOneWidget);
    await tapOn(tester, find.byKey(ConfirmActionDialog.cancelKey));
    expect(find.text('Find me a backend teammate'), findsOneWidget);

    await tapOn(tester, find.byKey(NewChatButton.buttonKey));
    await tapOn(tester, find.byKey(ConfirmActionDialog.confirmKey));

    expect(find.text('Find me a backend teammate'), findsNothing);
    expect(find.textContaining('Priya does Go'), findsNothing);
    expect(find.text(HackyBrief.title), findsOneWidget);
    expect(newChatButton(tester).onPressed, isNull);
  });

  testWidgets('loads my history on open', (tester) async {
    final api = ScriptedChatApi()
      ..history = [
        user('Find me a backend teammate'),
        hacky([textPart('Priya does Go and Postgres (@priya_codes).')]),
      ];
    await pumpScreen(tester, chat(api));
    await tester.pumpAndSettle();

    expect(find.text('Find me a backend teammate'), findsOneWidget);
    expect(find.textContaining('Priya does Go and Postgres'), findsOneWidget);
    expect(find.byType(HackyBrief, skipOffstage: false), findsOneWidget);
  });

  testWidgets('a failed history load can be retried', (tester) async {
    final api = ScriptedChatApi()..historyError = offline;
    await pumpScreen(tester, chat(api));
    await tester.pumpAndSettle();

    expect(find.text(ErrorText.unreachable), findsOneWidget);
    expect(sendButton(tester).onPressed, isNull);

    api.historyError = null;
    await tapOn(tester, find.text('Try again'));

    expect(find.text(ErrorText.unreachable), findsNothing);
    expect(find.text(HackyBrief.title), findsOneWidget);
  });

  testWidgets('sends what I type and shows the answer', (tester) async {
    final api = ScriptedChatApi();
    await pumpScreen(tester, chat(api));
    await tester.pumpAndSettle();

    await typeAndSend(tester, '  Find a teammate who knows React ');
    await tester.pumpAndSettle();

    expect(api.sent, ['Find a teammate who knows React']);
    expect(find.text('Find a teammate who knows React'), findsOneWidget);
    expect(find.textContaining('Here\'s who could help'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(ChatComposer.fieldKey))
          .controller!
          .text,
      isEmpty,
    );
    final history = await tester.runAsync(
      () => api.getChatHistory(fakeEventSlug),
    );
    expect(history!.map((m) => m.role), [ChatRole.user, ChatRole.assistant]);
  });

  testWidgets('shows Hacky is thinking while it answers, and Send waits', (
    tester,
  ) async {
    final api = ScriptedChatApi()
      ..gate = Completer<void>()
      ..reply = hacky([textPart('Sam Rivera mentors Flutter.')]);
    await pumpScreen(tester, chat(api));
    await tester.pumpAndSettle();

    await typeAndSend(tester, 'Find a Flutter mentor');
    await tester.pump();

    expect(find.text('Find a Flutter mentor'), findsOneWidget);
    expect(find.byType(ThinkingRow), findsOneWidget);
    expect(find.bySemanticsLabel(ThinkingRow.label), findsOneWidget);
    await tester.enterText(find.byKey(ChatComposer.fieldKey), 'And a designer');
    await tester.pump();
    expect(sendButton(tester).onPressed, isNull);

    api.gate!.complete();
    await tester.pumpAndSettle();

    expect(find.byType(ThinkingRow), findsNothing);
    expect(find.text('Sam Rivera mentors Flutter.'), findsOneWidget);
    expect(sendButton(tester).onPressed, isNotNull);
  });

  testWidgets('a message that fails can be retried', (tester) async {
    final api = ScriptedChatApi()
      ..sendError = offline
      ..reply = hacky([textPart('Got it!')]);
    await pumpScreen(tester, chat(api));
    await tester.pumpAndSettle();

    await typeAndSend(tester, 'Help me pick a track');
    await tester.pumpAndSettle();

    expect(find.text('Not sent. ${ErrorText.unreachable}'), findsOneWidget);
    expect(find.text('Help me pick a track'), findsOneWidget);
    expect(find.text('Got it!'), findsNothing);

    api.sendError = null;
    await tapOn(tester, find.text('Retry'));

    expect(api.sent, ['Help me pick a track', 'Help me pick a track']);
    expect(find.textContaining('Not sent.'), findsNothing);
    expect(find.text('Help me pick a track'), findsOneWidget);
    expect(find.text('Got it!'), findsOneWidget);
  });

  testWidgets('an expired session goes back to log in', (tester) async {
    final api = ScriptedChatApi()
      ..sendError = const ApiException(
        statusCode: 401,
        code: 'unauthorized',
        message: 'Log in again.',
      );
    final visits = await pumpScreen(tester, chat(api));
    await tester.pumpAndSettle();

    await typeAndSend(tester, 'Hi');
    await tester.pumpAndSettle();

    expect(visits.single.route, Routes.login);
  });

  testWidgets('scrolls to the newest message', (tester) async {
    final api = ScriptedChatApi()
      ..history = [
        for (var i = 0; i < 20; i++) ...[
          user('Question $i'),
          hacky([textPart('Answer $i')], id: 'a$i'),
        ],
      ]
      ..reply = hacky([textPart('Newest answer')], id: 'new');
    await pumpScreen(tester, chat(api));
    await tester.pumpAndSettle();

    expect(find.text('Answer 19').hitTestable(), findsOneWidget);
    expect(find.text('Question 0'), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, 1500));
    await tester.pumpAndSettle();
    expect(find.text('Answer 19').hitTestable(), findsNothing);

    await typeAndSend(tester, 'One more');
    await tester.pumpAndSettle();

    expect(find.text('One more').hitTestable(), findsOneWidget);
    expect(find.text('Newest answer').hitTestable(), findsOneWidget);
  });

  testWidgets('an @handle in Hacky\'s text opens 07', (tester) async {
    final api = ScriptedChatApi()
      ..history = [
        user('Who knows Go?'),
        hacky([textPart('Try Priya Shah (@priya_codes).')]),
      ];
    final visits = await pumpScreen(tester, chat(api));
    await tester.pumpAndSettle();

    await tapOn(tester, find.text('@priya_codes'));

    expect(visits.single.route, Routes.person);
    final args = visits.single.arguments as PersonArgs;
    expect(args.eventSlug, fakeEventSlug);
    expect(args.handle, 'priya_codes');
  });

  testWidgets('a suggested person opens 07', (tester) async {
    final api = ScriptedChatApi();
    final leo = await fakePerson(tester, api, 'leo_builds');
    final sam = await fakePerson(tester, api, 'sam_mentor');
    api.history = [
      user('Find a React dev'),
      hacky([
        textPart('Here are two people who match:'),
        searchPart(person: leo, mentor: sam),
      ]),
    ];
    final visits = await pumpScreen(tester, chat(api));
    await tester.pumpAndSettle();

    expect(find.text('2 PEOPLE'), findsOneWidget);
    expect(find.text('Leo Nguyen'), findsOneWidget);
    expect(find.text('@leo_builds · Hacker'), findsOneWidget);
    expect(find.text('Knows react'), findsOneWidget);
    expect(find.text('@sam_mentor · Mentor'), findsOneWidget);

    await tapOn(tester, find.text('View').first);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    await tapOn(tester, find.text('Sam Rivera'));

    expect(visits.map((v) => (v.arguments as PersonArgs).handle), [
      'leo_builds',
      'sam_mentor',
    ]);
  });

  testWidgets('a card in my history knows who I\'m already connected with', (
    tester,
  ) async {
    final api = ScriptedChatApi();
    // Priya and the demo user are connected before the chat opens.
    final priya = await fakePerson(tester, api, 'priya_codes');
    api.history = [
      user('Who knows Go?'),
      hacky([searchPart(person: priya)]),
    ];
    final visits = await pumpScreen(tester, chat(api));
    await tester.pumpAndSettle();

    expect(find.text('You’re connected with Priya'), findsOneWidget);
    expect(find.text('Connect'), findsNothing);

    await tapOn(tester, find.text('Open chat'));
    expect(visits.single.route, Routes.chatThread);
  });

  testWidgets('Connect sends a request; a mutual one opens the chat', (
    tester,
  ) async {
    final api = ScriptedChatApi();
    final maya = await fakePerson(tester, api, 'maya_ml');
    final jordan = await fakePerson(tester, api, 'jordan_ux');
    api.history = [
      user('Find people'),
      hacky([searchPart(person: maya, mentor: jordan)]),
    ];
    final visits = await pumpScreen(tester, chat(api));
    await tester.pumpAndSettle();

    await tapOn(tester, find.text('Connect').first);
    expect(find.text('Intro to Maya Patel'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(IntroComposer.fieldKey))
          .controller!
          .text,
      startsWith('Hi Maya! I’m Demo.'),
    );
    await tapOn(tester, find.text('Send request'));

    expect(find.text('Intro to Maya Patel'), findsNothing);
    expect(find.text('Request sent'), findsOneWidget);
    final requests = await tester.runAsync(
      () => api.listRequests(fakeEventSlug),
    );
    expect(
      requests!.where(
        (r) =>
            r.direction == RequestDirection.outgoing &&
            r.person.handle == 'maya_ml' &&
            r.source == ConnectionSource.agent,
      ),
      hasLength(1),
    );

    // Jordan already asked me, so this connects us right away.
    await tapOn(tester, find.text('Connect'));
    await tapOn(tester, find.text('Send request'));

    expect(find.text('You’re connected with Jordan'), findsOneWidget);
    await tapOn(tester, find.text('Open chat'));
    expect(visits.single.route, Routes.chatThread);
    expect(
      (visits.single.arguments as ChatThreadArgs).conversationId,
      isNotEmpty,
    );
  });

  testWidgets('a team card asks its lead to join', (tester) async {
    final api = ScriptedChatApi();
    final maya = await fakePerson(tester, api, 'maya_ml');
    api.history = [
      user('Open teams?'),
      hacky([teamSearchPart(maya)]),
    ];
    await pumpScreen(tester, chat(api));
    await tester.pumpAndSettle();

    expect(find.text('Rash Decisions'), findsOneWidget);
    expect(find.text('2 spots left · Led by Maya Patel'), findsOneWidget);

    await tapOn(tester, find.text('Ask to join'));

    expect(find.text('Intro to Rash Decisions'), findsOneWidget);
    expect(find.text('Goes to Maya, the team lead'), findsOneWidget);
  });

  testWidgets('Hacky\'s drafted intro can be edited and sent', (tester) async {
    final api = ScriptedChatApi();
    final maya = await fakePerson(tester, api, 'maya_ml');
    api.history = [
      user('Write Maya an intro'),
      hacky([textPart('Here is a draft:'), draftPart(maya)]),
    ];
    await pumpScreen(tester, chat(api));
    await tester.pumpAndSettle();

    final field = find.byKey(IntroComposer.fieldKey);
    final send = find.widgetWithText(FilledButton, 'Send request');
    await tester.enterText(field, 'See www.example.com');
    await tester.pump();
    expect(find.text('Intros can’t contain links.'), findsOneWidget);
    expect(tester.widget<FilledButton>(send).onPressed, isNull);

    await tester.enterText(field, 'Hi Maya! I do Flutter. Want a mobile dev?');
    await tester.pump();
    await tapOn(tester, send);

    expect(find.text('Request sent'), findsOneWidget);
    expect(field, findsNothing);
  });

  testWidgets('answer chips on the newest question send my answer', (
    tester,
  ) async {
    final api = ScriptedChatApi()
      ..history = [
        user('I\'m building a health app'),
        hacky([questionPart()]),
      ]
      ..reply = hacky([textPart('Got it, a designer.')], id: 'a2');
    await pumpScreen(tester, chat(api));
    await tester.pumpAndSettle();

    expect(find.text('Nice, a health app!'), findsOneWidget);
    expect(find.text('What role do you need most?'), findsOneWidget);

    await tapOn(tester, find.text('Designer'));

    expect(api.sent, ['Designer']);
    expect(find.text('Got it, a designer.'), findsOneWidget);
    // The question is closed now: its chips are gone, my answer stays.
    expect(find.text('Backend dev'), findsNothing);
    expect(find.text('Designer'), findsOneWidget);
  });
}
