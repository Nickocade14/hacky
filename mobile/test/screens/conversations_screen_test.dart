import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/fake/fake_world.dart';
import 'package:mobile/api/models/auth.dart';
import 'package:mobile/api/models/conversations.dart';
import 'package:mobile/api/models/people.dart';
import 'package:mobile/api/models/teams.dart';
import 'package:mobile/auth/error_text.dart';
import 'package:mobile/routes.dart';
import 'package:mobile/screens/conversations_screen.dart';
import 'package:mobile/widgets/app_widgets.dart';
import 'package:mobile/widgets/conversation_widgets.dart';

import '../support/screen_harness.dart';
import 'chats_fake_api.dart';

Widget chats(ChatsFakeApi api) =>
    ConversationsScreen(api: api, eventSlug: fakeEventSlug);

const priyaLast =
    'Awesome! I\'ll start the Go API. Meet at the food tables at 3?';

ConversationSummary summary({
  required String id,
  required ConversationKind kind,
  PersonSummary? peer,
  TeamRef? team,
  ConversationHelpRequest? help,
}) {
  final at = DateTime.now().toUtc().subtract(const Duration(minutes: 5));
  return ConversationSummary(
    id: id,
    kind: kind,
    peer: peer,
    team: team,
    helpRequest: help,
    lastMessage: null,
    lastMessageAt: at,
    unreadCount: 0,
    peerLastReadAt: null,
    createdAt: at,
  );
}

void main() {
  testWidgets('shows loading, then my chats with unread badges', (
    tester,
  ) async {
    final api = ChatsFakeApi();
    await pumpScreen(tester, chats(api));

    expect(find.text('Loading your chats…'), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.text('Chats'), findsOneWidget);
    expect(find.text('Priya Shah'), findsOneWidget);
    expect(find.text(priyaLast), findsOneWidget);
    expect(find.widgetWithText(CountBadge, '1'), findsOneWidget);
  });

  testWidgets('lists the newest activity first, with "You:" on mine', (
    tester,
  ) async {
    final api = ChatsFakeApi();
    final id = await tester.runAsync(api.priyaChatId);
    await tester.runAsync(
      () => api.sendMessage(
        id!,
        const SendMessageBody(clientId: 'c-1', body: 'On my way'),
      ),
    );
    final requests = await tester.runAsync(
      () => api.listRequests(fakeEventSlug),
    );
    // Accepting Jordan's request opens a newer chat.
    await tester.runAsync(
      () => api.acceptRequest(
        requests!.firstWhere((r) => r.person.name == 'Jordan Lee').id,
      ),
    );
    await pumpScreen(tester, chats(api));
    await tester.pumpAndSettle();

    final names = [
      for (final row in tester.widgetList<ConversationRow>(
        find.byType(ConversationRow),
      ))
        row.conversation.peer!.name,
    ];
    expect(names, ['Jordan Lee', 'Priya Shah']);
    expect(find.text('You: On my way'), findsOneWidget);
  });

  testWidgets('shows team and mentor chats', (tester) async {
    final api = ChatsFakeApi()
      ..conversations = [
        summary(
          id: '6716a3f2c9e7000000000f01',
          kind: ConversationKind.team,
          team: const TeamRef(id: '6716a3f2c9e7000000000f02', name: 'Byte Me'),
        ),
        summary(
          id: '6716a3f2c9e7000000000f03',
          kind: ConversationKind.mentor,
          peer: const PersonSummary(
            userId: '6716a3f2c9e7000000000f04',
            handle: 'sam_ortiz',
            name: 'Sam Ortiz',
            hackyStyle: {},
            photoUrl: null,
            role: MemberRole.mentor,
          ),
          help: const ConversationHelpRequest(
            id: '6716a3f2c9e7000000000f05',
            title: 'Flutter build fails',
            status: HelpStatus.claimed,
          ),
        ),
      ];
    await pumpScreen(tester, chats(api));
    await tester.pumpAndSettle();

    expect(find.text('Byte Me'), findsOneWidget);
    expect(find.byType(TeamAvatar), findsOneWidget);
    expect(find.text('Say hi'), findsOneWidget);
    expect(find.text('Mentor · Sam Ortiz'), findsOneWidget);
    expect(find.text('Help: Flutter build fails'), findsOneWidget);
    expect(find.byType(CountBadge), findsNothing);
  });

  testWidgets('shows the empty state', (tester) async {
    final api = ChatsFakeApi()..conversations = const [];
    await pumpScreen(tester, chats(api));
    await tester.pumpAndSettle();

    expect(find.text('No chats yet'), findsOneWidget);
    expect(
      find.text('Accept a request or ask Hacky to find people.'),
      findsOneWidget,
    );
  });

  testWidgets('a failed load can be retried', (tester) async {
    final api = ChatsFakeApi()..listError = offline;
    await pumpScreen(tester, chats(api));
    await tester.pumpAndSettle();

    expect(find.text(ErrorText.unreachable), findsOneWidget);

    api.listError = null;
    await tapOn(tester, find.text('Try again'));
    expect(find.text('Priya Shah'), findsOneWidget);
  });

  testWidgets('an expired session goes back to log in', (tester) async {
    final (:api, :store) = fakeApi();
    store.token = 'fake-jwt:nobody@example.com';
    final visits = await pumpScreen(
      tester,
      ConversationsScreen(api: api, eventSlug: fakeEventSlug),
    );
    await tester.pumpAndSettle();

    expect(visits.single.route, Routes.login);
  });

  testWidgets('pull to refresh shows new messages', (tester) async {
    final api = ChatsFakeApi();
    final id = await tester.runAsync(api.priyaChatId);
    await pumpScreen(tester, chats(api));
    await tester.pumpAndSettle();

    await tester.runAsync(
      () => api.sendMessage(
        id!,
        const SendMessageBody(clientId: 'c-2', body: 'Table 14'),
      ),
    );
    await tester.fling(find.text('Priya Shah'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(find.text('You: Table 14'), findsOneWidget);
  });

  testWidgets('a failed refresh keeps the list and says why', (tester) async {
    final api = ChatsFakeApi();
    await pumpScreen(tester, chats(api));
    await tester.pumpAndSettle();

    api.listError = offline;
    await tester.fling(find.text('Priya Shah'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Priya Shah'), findsOneWidget);
    expect(find.text(ErrorText.unreachable), findsOneWidget);
  });

  testWidgets('a row opens 11, and the badge goes when I come back', (
    tester,
  ) async {
    final api = ChatsFakeApi();
    final id = await tester.runAsync(api.priyaChatId);
    final visits = await pumpScreen(tester, chats(api));
    await tester.pumpAndSettle();

    await tapOn(tester, find.text('Priya Shah'));

    expect(visits.single.route, Routes.chatThread);
    final args = visits.single.arguments as ChatThreadArgs;
    expect(args.eventSlug, fakeEventSlug);
    expect(args.conversationId, id);

    // 11 marks it read; then the user comes back.
    await tester.runAsync(() => api.markRead(id!));
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();

    expect(find.text('Priya Shah'), findsOneWidget);
    expect(find.byType(CountBadge), findsNothing);
  });

  testWidgets('Requests opens 09', (tester) async {
    final api = ChatsFakeApi();
    final visits = await pumpScreen(tester, chats(api));
    await tester.pumpAndSettle();

    await tapOn(tester, find.byKey(ConversationsScreen.seeAllKey));

    expect(visits.single.route, Routes.requests);
    expect(
      (visits.single.arguments as RequestsArgs).eventSlug,
      fakeEventSlug,
    );
  });

  testWidgets('shows my event and the requests waiting on me', (tester) async {
    final api = ChatsFakeApi();
    await pumpScreen(tester, chats(api));
    await tester.pumpAndSettle();

    expect(find.byType(EventBadge), findsOneWidget);
    expect(find.text('Knight Hacks IX'), findsOneWidget);
    expect(find.text('You’re here as a hacker'), findsOneWidget);
    expect(find.text('REQUESTS'), findsOneWidget);
    expect(find.byType(InboxRequestRow), findsOneWidget);
    expect(find.text('Jordan Lee'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Accept'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Not now'), findsOneWidget);
    // The one I answered "Not now" before waits under See all.
    expect(find.text('See all · 1 hidden'), findsOneWidget);
  });

  testWidgets('Accept opens the new chat and the request leaves', (
    tester,
  ) async {
    final api = ChatsFakeApi();
    final visits = await pumpScreen(tester, chats(api));
    await tester.pumpAndSettle();

    await tapOn(tester, find.widgetWithText(FilledButton, 'Accept'));

    expect(visits.single.route, Routes.chatThread);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();

    expect(find.byType(InboxRequestRow), findsNothing);
    final names = [
      for (final row in tester.widgetList<ConversationRow>(
        find.byType(ConversationRow),
      ))
        row.conversation.peer!.name,
    ];
    expect(names, ['Jordan Lee', 'Priya Shah']);
  });

  testWidgets('Not now hides the request without telling them', (tester) async {
    final api = ChatsFakeApi();
    await pumpScreen(tester, chats(api));
    await tester.pumpAndSettle();

    await tapOn(tester, find.widgetWithText(OutlinedButton, 'Not now'));

    expect(find.byType(InboxRequestRow), findsNothing);
    expect(find.text('Hidden. Jordan Lee isn’t told.'), findsOneWidget);
    expect(find.text('See all · 2 hidden'), findsOneWidget);
    expect(find.textContaining('Nothing waiting.'), findsOneWidget);
  });

  testWidgets('reloads by itself and tells the shell what is waiting', (
    tester,
  ) async {
    final api = ChatsFakeApi();
    final id = await tester.runAsync(api.priyaChatId);
    final waiting = <int>[];
    await pumpScreen(
      tester,
      ConversationsScreen(
        api: api,
        eventSlug: fakeEventSlug,
        onWaitingChanged: waiting.add,
      ),
    );
    await tester.pumpAndSettle();
    // Jordan's request and Priya's unread message.
    expect(waiting, [2]);

    await tester.runAsync(() => api.markRead(id!));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(waiting, [2, 1]);
    expect(find.byType(CountBadge), findsNothing);
  });
}
