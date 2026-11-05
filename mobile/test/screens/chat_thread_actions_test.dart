import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/api_exception.dart';
import 'package:mobile/api/fake/fake_world.dart';
import 'package:mobile/api/models/conversations.dart';
import 'package:mobile/api/models/requests.dart';
import 'package:mobile/auth/error_text.dart';
import 'package:mobile/people/block_person.dart';
import 'package:mobile/screens/chat_thread_screen.dart';
import 'package:mobile/theme.dart';
import 'package:mobile/widgets/confirm_action_dialog.dart';
import 'package:mobile/widgets/thread_widgets.dart';

import '../support/screen_harness.dart';
import 'chats_fake_api.dart';

const iSaid = 'Hey Priya! Rent splitting sounds fun. I can do the app.';
const priyaSays =
    'Awesome! I\'ll start the Go API. Meet at the food tables at 3?';

/// [ChatsFakeApi] where unsending and blocking can wait or fail.
class ThreadActionsApi extends ChatsFakeApi {
  ApiException? deleteError;
  Completer<void>? deleteGate;
  final deleted = <String>[];
  final blocked = <String>[];

  @override
  Future<void> deleteMessage(String conversationId, String messageId) async {
    deleted.add(messageId);
    await deleteGate?.future;
    if (deleteError case final error?) throw error;
    return super.deleteMessage(conversationId, messageId);
  }

  @override
  Future<void> blockUser(BlockBody body) async {
    blocked.add(body.userId);
    return super.blockUser(body);
  }

  Future<List<String>> bodiesOnServer(String id) async => [
    for (final m in (await super.listMessages(id)).messages) m.body,
  ];
}

/// Pushes 11 for the DM with Priya from a stand-in for 10, so 11 has
/// somewhere to go back to.
Future<String> openPriya(WidgetTester tester, ThreadActionsApi api) async {
  final id = (await tester.runAsync(api.priyaChatId))!;
  tester.view.physicalSize = const Size(1200, 2700);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ChatThreadScreen(
                    api: api,
                    eventSlug: fakeEventSlug,
                    conversationId: id,
                  ),
                ),
              ),
              child: const Text('Chats list'),
            ),
          ),
        ),
      ),
      // ••• → View profile and the header push 07; not under test here.
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('profile')),
      ),
    ),
  );
  await tester.tap(find.text('Chats list'));
  await tester.pumpAndSettle();
  return id;
}

/// Long-press my message, pick Unsend for everyone, and wait for the confirm.
Future<void> askToUnsend(WidgetTester tester, String text) async {
  await tester.longPress(find.text(text));
  await tester.pumpAndSettle();
  await tapOn(tester, find.text(UnsendSheet.label));
}

void main() {
  testWidgets('long-press my message → confirm → it is gone for everyone', (
    tester,
  ) async {
    final api = ThreadActionsApi()..deleteGate = Completer<void>();
    final id = await openPriya(tester, api);

    await askToUnsend(tester, iSaid);

    expect(find.text('Unsend this message?'), findsOneWidget);
    await tester.tap(find.byKey(ConfirmActionDialog.confirmKey));
    await tester.pump();
    expect(find.text('Unsending…'), findsOneWidget);

    api.deleteGate!.complete();
    await tester.pumpAndSettle();

    expect(api.deleted, hasLength(1));
    expect(find.text(iSaid), findsNothing);
    expect(find.text(priyaSays), findsOneWidget);
    expect(find.text(ChatThreadScreen.unsentNote), findsOneWidget);
    final onServer = await tester.runAsync(() => api.bodiesOnServer(id));
    expect(onServer, isNot(contains(iSaid)));
  });

  testWidgets('Cancel keeps the message', (tester) async {
    final api = ThreadActionsApi();
    await openPriya(tester, api);

    await askToUnsend(tester, iSaid);
    await tapOn(tester, find.byKey(ConfirmActionDialog.cancelKey));

    expect(api.deleted, isEmpty);
    expect(find.text(iSaid), findsOneWidget);
  });

  testWidgets('long-pressing their message offers nothing', (tester) async {
    final api = ThreadActionsApi();
    await openPriya(tester, api);

    await tester.longPress(find.text(priyaSays));
    await tester.pumpAndSettle();

    expect(find.text(UnsendSheet.label), findsNothing);
  });

  testWidgets('a failed unsend shows the error and keeps the message', (
    tester,
  ) async {
    final api = ThreadActionsApi()..deleteError = offline;
    await openPriya(tester, api);

    await askToUnsend(tester, iSaid);
    await tapOn(tester, find.byKey(ConfirmActionDialog.confirmKey));

    expect(find.text(ErrorText.unreachable), findsOneWidget);
    await tapOn(tester, find.byKey(ConfirmActionDialog.cancelKey));
    expect(find.text(iSaid), findsOneWidget);
    expect(find.text(ChatThreadScreen.unsentNote), findsNothing);
  });

  testWidgets('a 404 means it was already gone, so it leaves the thread', (
    tester,
  ) async {
    final api = ThreadActionsApi()
      ..deleteError = const ApiException(
        statusCode: 404,
        code: 'not_found',
        message: 'Gone',
      );
    await openPriya(tester, api);

    await askToUnsend(tester, iSaid);
    await tapOn(tester, find.byKey(ConfirmActionDialog.confirmKey));

    expect(find.text('Gone'), findsNothing);
    expect(find.text(iSaid), findsNothing);
  });

  testWidgets('••• → Block confirms, blocks Priya and goes back', (
    tester,
  ) async {
    final api = ThreadActionsApi();
    await openPriya(tester, api);

    await tapOn(tester, find.byKey(ChatThreadScreen.menuKey));
    await tapOn(tester, find.text(BlockPerson.menuLabel));

    expect(find.text('Block Priya Shah?'), findsOneWidget);
    await tapOn(tester, find.byKey(ConfirmActionDialog.confirmKey));

    expect(api.blocked, hasLength(1));
    expect(find.byType(ChatThreadScreen), findsNothing);
    expect(find.text('Chats list'), findsOneWidget);
    expect(find.text(BlockPerson.done('Priya Shah')), findsOneWidget);
  });

  testWidgets('a mentor chat has View profile but no Block', (tester) async {
    final api = ThreadActionsApi();
    final dm = (await tester.runAsync(
      () => api.listConversations(fakeEventSlug),
    ))!.single;
    api.conversations = [
      ConversationSummary(
        id: dm.id,
        kind: ConversationKind.mentor,
        peer: dm.peer,
        team: null,
        helpRequest: null,
        lastMessage: dm.lastMessage,
        lastMessageAt: dm.lastMessageAt,
        unreadCount: 0,
        peerLastReadAt: null,
        createdAt: dm.createdAt,
      ),
    ];
    await openPriya(tester, api);

    await tapOn(tester, find.byKey(ChatThreadScreen.menuKey));

    expect(find.text('View profile'), findsOneWidget);
    expect(find.text(BlockPerson.menuLabel), findsNothing);
  });
}
