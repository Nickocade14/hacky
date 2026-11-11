import '../api/api_client.dart';
import '../api/models/auth.dart';
import '../api/models/conversations.dart';
import '../api/models/requests.dart';
import '../requests/request_lists.dart';

/// What 10 Chats shows, loaded together: my event, the requests and the
/// conversations.
class ConversationsData {
  const ConversationsData({
    required this.myUserId,
    required this.event,
    required this.conversations,
    required this.requests,
  });

  /// From `GET /api/me`, to mark my last messages "You: ".
  final String myUserId;

  /// The event as `Me.events` lists it (its name, my role), for the badge at
  /// the top. Null if the list doesn't have it.
  final MyEvent? event;

  /// `GET /api/events/{slug}/conversations`, newest activity first.
  final List<ConversationSummary> conversations;

  /// `GET /api/events/{slug}/requests`: the ones waiting on me or on them
  /// show above the chats.
  final List<ConnectionRequest> requests;

  /// Requests for me to answer plus unread messages: what the dot on the
  /// header's Chats button stands for.
  int get waiting =>
      RequestLists.from(requests).incoming.length +
      conversations.fold<int>(0, (sum, c) => sum + c.unreadCount);

  static Future<ConversationsData> load(ApiClient api, String slug) async {
    // Future.wait reports the first failure and handles the others.
    final results = await Future.wait<Object>([
      api.getMe(),
      api.listConversations(slug),
      api.listRequests(slug),
    ]);
    final me = results[0] as Me;
    return ConversationsData(
      myUserId: me.profile.userId,
      event: me.events.where((event) => event.slug == slug).firstOrNull,
      conversations: results[1] as List<ConversationSummary>,
      requests: results[2] as List<ConnectionRequest>,
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
