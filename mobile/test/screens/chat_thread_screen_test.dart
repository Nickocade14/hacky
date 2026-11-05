import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/api_exception.dart';
import 'package:mobile/api/fake/fake_world.dart';
import 'package:mobile/api/models/conversations.dart';
import 'package:mobile/auth/error_text.dart';
import 'package:mobile/routes.dart';
import 'package:mobile/screens/chat_thread_screen.dart';
import 'package:mobile/widgets/thread_widgets.dart';

import '../support/screen_harness.dart';
import 'chats_fake_api.dart';

const priyaSays =
    'Awesome! I\'ll start the Go API. Meet at the food tables at 3?';
const iSaid = 'Hey Priya! Rent splitting sounds fun. I can do the app.';
const connected = 'You and Priya are connected. Say hi!';

Widget thread(ChatsFakeApi api, String id) => ChatThreadScreen(
  api: api,
  eventSlug: fakeEventSlug,
  conversationId: id,
);

/// Opens the DM with Priya and waits for it to load.
Future<({ChatsFakeApi api, String id, List<Visit> visits})> openPriya(
  WidgetTester tester, {
  ChatsFakeApi? api,
  int seed = 0,
}) async {
  final fake = api ?? ChatsFakeApi();
  final id = (await tester.runAsync(fake.priyaChatId))!;
  for (var n = 1; n <= seed; n++) {
    await tester.runAsync(
      () => fake.sendMessage(
        id,
        SendMessageBody(clientId: 'seed-$n', body: 'Seed $n'),
      ),
    );
  }
  fake.sent.clear();
  final visits = await pumpScreen(tester, thread(fake, id));
  await tester.pumpAndSettle();
  return (api: fake, id: id, visits: visits);
}

MessageBubble bubbleOf(WidgetTester tester, String text) =>
    tester.widget<MessageBubble>(find.widgetWithText(MessageBubble, text));

Future<void> write(WidgetTester tester, String text) =>
    tester.enterText(find.byKey(ChatComposer.fieldKey), text);

IconButton sendButton(WidgetTester tester) =>
    tester.widget<IconButton>(find.byKey(ChatComposer.sendKey));

void main() {
  testWidgets('shows loading, then the messages with mine on the right', (
    tester,
  ) async {
    final api = ChatsFakeApi();
    final id = (await tester.runAsync(api.priyaChatId))!;
    await pumpScreen(tester, thread(api, id));

    expect(find.text('Loading messages…'), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.text('Priya Shah'), findsOneWidget);
    expect(find.text('Hacker'), findsOneWidget);
    expect(find.text(connected), findsOneWidget);
    expect(bubbleOf(tester, iSaid).mine, isTrue);
    expect(bubbleOf(tester, priyaSays).mine, isFalse);
    // Priya read up to her own reply, after my message.
    expect(find.text('Seen'), findsOneWidget);
    final topOf = tester.getTopLeft;
    expect(topOf(find.text(iSaid)).dy, lessThan(topOf(find.text(priyaSays)).dy));
  });

  testWidgets('marks the chat read when it opens', (tester) async {
    final (:api, :id, visits: _) = await openPriya(tester);

    expect(api.markReads, 1);
    final list = await tester.runAsync(
      () => api.listConversations(fakeEventSlug),
    );
    expect(list!.single.id, id);
    expect(list.single.unreadCount, 0);
  });

  testWidgets('shows an empty thread, and the first message', (tester) async {
    final api = ChatsFakeApi()
      ..page = const MessagePage(messages: [], hasMore: false);
    await openPriya(tester, api: api);

    expect(find.text('No messages yet'), findsOneWidget);
    expect(find.text('Say hi and share what you’re building.'), findsOneWidget);
    expect(sendButton(tester).onPressed, isNull);

    await write(tester, 'Hi Priya!');
    await tapOn(tester, find.byKey(ChatComposer.sendKey));

    expect(find.text('No messages yet'), findsNothing);
    expect(bubbleOf(tester, 'Hi Priya!').mine, isTrue);
  });

  testWidgets('sends with a busy state, then shows it saved', (tester) async {
    final gate = Completer<void>();
    final api = ChatsFakeApi()..sendGate = gate;
    final opened = await openPriya(tester, api: api);

    expect(sendButton(tester).onPressed, isNull);
    await write(tester, '  On my way  ');
    expect(sendButton(tester).onPressed, isNotNull);

    await tester.tap(find.byKey(ChatComposer.sendKey));
    await tester.pump();

    expect(find.text('On my way'), findsOneWidget);
    expect(find.text('Sending…'), findsOneWidget);
    expect(find.byKey(ChatComposer.sendKey), findsOneWidget);
    expect(sendButton(tester).onPressed, isNull);
    expect(sendButton(tester).tooltip, 'Sending');
    expect(
      tester.widget<TextField>(find.byKey(ChatComposer.fieldKey)).controller!.text,
      isEmpty,
    );

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.text('Sending…'), findsNothing);
    expect(bubbleOf(tester, 'On my way').mine, isTrue);
    final body = api.sent.single;
    expect(body.body, 'On my way');
    final page = await tester.runAsync(() => api.listMessages(opened.id));
    expect(page!.messages.last.body, 'On my way');
    expect(page.messages.last.clientId, body.clientId);
  });

  testWidgets('a failed send shows why, and Retry sends it once', (
    tester,
  ) async {
    final api = ChatsFakeApi()..sendError = offline;
    final opened = await openPriya(tester, api: api);

    await write(tester, 'Table 14, by the stage');
    await tapOn(tester, find.byKey(ChatComposer.sendKey));

    expect(find.text('Not sent. ${ErrorText.unreachable}'), findsOneWidget);
    expect(find.text('Sending…'), findsNothing);

    api.sendError = null;
    await tapOn(tester, find.text('Retry'));

    expect(find.text('Retry'), findsNothing);
    expect(bubbleOf(tester, 'Table 14, by the stage').mine, isTrue);
    expect(api.sent, hasLength(2));
    expect(api.sent[0].clientId, api.sent[1].clientId);
    final page = await tester.runAsync(() => api.listMessages(opened.id));
    expect(
      page!.messages.where((m) => m.body == 'Table 14, by the stage'),
      hasLength(1),
    );
  });

  testWidgets('a failed message can be removed', (tester) async {
    final api = ChatsFakeApi()
      ..sendError = const ApiException(
        statusCode: 403,
        code: 'forbidden',
        message: 'You can’t message this person.',
      );
    await openPriya(tester, api: api);

    await write(tester, 'Hello?');
    await tapOn(tester, find.byKey(ChatComposer.sendKey));
    expect(find.text('Not sent. You can’t message this person.'), findsOneWidget);

    await tapOn(tester, find.text('Remove'));
    expect(find.text('Hello?'), findsNothing);
  });

  testWidgets('scrolling up loads older messages', (tester) async {
    final (:api, id: _, visits: _) = await openPriya(tester, seed: 40);

    expect(find.text('Seed 40'), findsOneWidget);
    expect(find.text('Seed 1'), findsNothing);
    expect(api.olderCursors, isEmpty);

    await tester.dragUntilVisible(
      find.text('Seed 1'),
      find.byType(ListView),
      const Offset(0, 600),
    );
    await tester.pumpAndSettle();

    expect(api.olderCursors, hasLength(1));
    await tester.dragUntilVisible(
      find.text(connected),
      find.byType(ListView),
      const Offset(0, 600),
    );
    expect(find.text('Load earlier messages'), findsNothing);
  });

  testWidgets('a failed older page can be tried again', (tester) async {
    final api = ChatsFakeApi()..olderError = offline;
    await openPriya(tester, api: api, seed: 40);

    await tester.dragUntilVisible(
      find.text(ErrorText.unreachable),
      find.byType(ListView),
      const Offset(0, 600),
    );
    await tester.pumpAndSettle();
    expect(api.olderCursors, hasLength(1));

    api.olderError = null;
    await tapOn(tester, find.text('Try again'));
    await tester.dragUntilVisible(
      find.text('Seed 1'),
      find.byType(ListView),
      const Offset(0, 600),
    );
    expect(api.olderCursors, hasLength(2));
  });

  testWidgets('checks for new messages every 10 seconds until it closes', (
    tester,
  ) async {
    final (:api, :id, visits: _) = await openPriya(tester);
    // A message sent from another device.
    await tester.runAsync(
      () => api.sendMessage(
        id,
        const SendMessageBody(clientId: 'other-device', body: 'From my laptop'),
      ),
    );
    expect(find.text('From my laptop'), findsNothing);

    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(find.text('From my laptop'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    final loads = api.pageLoads;
    await tester.pump(const Duration(seconds: 30));
    expect(api.pageLoads, loads);
  });

  testWidgets('a failed load can be retried', (tester) async {
    final api = ChatsFakeApi()..openError = offline;
    await openPriya(tester, api: api);

    expect(find.text(ErrorText.unreachable), findsOneWidget);
    expect(find.byKey(ChatComposer.fieldKey), findsNothing);

    api.openError = null;
    await tapOn(tester, find.text('Try again'));
    expect(find.text(priyaSays), findsOneWidget);
  });

  testWidgets('an expired session goes back to log in', (tester) async {
    final (:api, :store) = fakeApi();
    store.token = 'fake-jwt:nobody@example.com';
    final visits = await pumpScreen(
      tester,
      ChatThreadScreen(
        api: api,
        eventSlug: fakeEventSlug,
        conversationId: '6716a3f2c9e7000000000109',
      ),
    );
    await tester.pumpAndSettle();

    expect(visits.single.route, Routes.login);
  });

  testWidgets('the header opens 07 Person profile', (tester) async {
    final (api: _, id: _, :visits) = await openPriya(tester);

    await tapOn(tester, find.byType(ChatThreadHeader));

    expect(visits.single.route, Routes.person);
    final args = visits.single.arguments as PersonArgs;
    expect(args.handle, 'priya_codes');
    expect(args.eventSlug, fakeEventSlug);
  });

  testWidgets('••• → View profile opens 07', (tester) async {
    final (api: _, id: _, :visits) = await openPriya(tester);

    await tapOn(tester, find.byTooltip('More'));
    await tapOn(tester, find.text('View profile'));

    expect(visits.single.route, Routes.person);
    expect((visits.single.arguments as PersonArgs).handle, 'priya_codes');
  });
}
