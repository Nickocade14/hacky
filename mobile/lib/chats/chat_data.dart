import '../api/api_client.dart';
import '../api/models/auth.dart';
import '../api/models/conversations.dart';

/// What 10 Conversations shows, loaded together.
class ConversationsData {
  const ConversationsData({
    required this.myUserId,
    required this.conversations,
  });

  /// From `GET /api/me`, to mark my last messages "You: ".
  final String myUserId;

  /// `GET /api/events/{slug}/conversations`, newest activity first.
  final List<ConversationSummary> conversations;

  static Future<ConversationsData> load(ApiClient api, String slug) async {
    // Future.wait reports the first failure and handles the others.
    final results = await Future.wait<Object>([
      api.getMe(),
      api.listConversations(slug),
    ]);
    return ConversationsData(
      myUserId: (results[0] as Me).profile.userId,
      conversations: results[1] as List<ConversationSummary>,
    );
  }
}

/// What 11 Chat thread needs when it opens, loaded together.
class ChatThreadData {
  const ChatThreadData({
    required this.myUserId,
    required this.conversation,
    required this.newest,
  });

  /// From `GET /api/me`: my messages go on the right.
  final String myUserId;

  /// The header (peer or team) and "Seen", from the event's conversations.
  /// Null if the list doesn't have it anymore.
  final ConversationSummary? conversation;

  /// The newest page of messages.
  final MessagePage newest;

  static Future<ChatThreadData> load(
    ApiClient api,
    String slug,
    String conversationId,
  ) async {
    final results = await Future.wait<Object>([
      api.getMe(),
      api.listConversations(slug),
      api.listMessages(conversationId),
    ]);
    return ChatThreadData(
      myUserId: (results[0] as Me).profile.userId,
      conversation: find(
        results[1] as List<ConversationSummary>,
        conversationId,
      ),
      newest: results[2] as MessagePage,
    );
  }

  static ConversationSummary? find(
    List<ConversationSummary> conversations,
    String id,
  ) => conversations.where((c) => c.id == id).firstOrNull;
}
