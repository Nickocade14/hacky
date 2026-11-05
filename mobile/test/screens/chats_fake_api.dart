import 'dart:async';

import 'package:mobile/api/api_exception.dart';
import 'package:mobile/api/fake/fake_api_client.dart';
import 'package:mobile/api/fake/fake_world.dart';
import 'package:mobile/api/models/conversations.dart';

import '../support/screen_harness.dart';

const offline = ApiException(
  statusCode: null,
  code: 'network_error',
  message: 'x',
);

/// The demo user's fake API, where the 10 and 11 tests can make the chat
/// calls fail or return something else, and see what was sent.
class ChatsFakeApi extends FakeApiClient {
  ChatsFakeApi() : super(tokenStore: _signedIn(), delay: Duration.zero);

  static MemoryTokenStore _signedIn() =>
      MemoryTokenStore()..token = 'fake-jwt:${FakeApiClient.demoEmail}';

  /// Thrown by `listConversations` while set.
  ApiException? listError;

  /// Returned by `listConversations` instead of the fake's, while set.
  List<ConversationSummary>? conversations;

  /// Thrown by `listMessages` without cursors (opening the chat) while set.
  ApiException? openError;

  /// Thrown by `listMessages` with `before` (older pages) while set.
  ApiException? olderError;

  /// Returned by `listMessages` instead of the fake's, while set.
  MessagePage? page;

  /// Thrown by `sendMessage` while set.
  ApiException? sendError;

  /// `sendMessage` waits for it while set, so the busy state can be seen.
  Completer<void>? sendGate;

  final sent = <SendMessageBody>[];
  int pageLoads = 0;
  final olderCursors = <String>[];
  int markReads = 0;

  @override
  Future<List<ConversationSummary>> listConversations(String slug) async {
    final error = listError;
    if (error != null) throw error;
    return conversations ?? super.listConversations(slug);
  }

  @override
  Future<MessagePage> listMessages(
    String conversationId, {
    String? before,
    String? after,
    int? limit,
  }) async {
    pageLoads++;
    if (before == null && after == null && openError != null) {
      throw openError!;
    }
    if (before != null) {
      olderCursors.add(before);
      if (olderError != null) throw olderError!;
    }
    return page ??
        super.listMessages(
          conversationId,
          before: before,
          after: after,
          limit: limit,
        );
  }

  @override
  Future<Message> sendMessage(
    String conversationId,
    SendMessageBody body,
  ) async {
    sent.add(body);
    await sendGate?.future;
    final error = sendError;
    if (error != null) throw error;
    return super.sendMessage(conversationId, body);
  }

  @override
  Future<DateTime> markRead(String conversationId) {
    markReads++;
    return super.markRead(conversationId);
  }

  /// The demo user's one conversation: the DM with Priya.
  Future<String> priyaChatId() async =>
      (await super.listConversations(fakeEventSlug)).single.id;
}
