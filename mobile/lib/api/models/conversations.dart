// Conversation schemas from docs/openapi.yaml: Message, SendMessageBody,
// MessagePage, ConversationSummary, plus their enums.

import 'json_read.dart';
import 'people.dart';
import 'teams.dart';

/// `ConversationKind`.
enum ConversationKind { dm, mentor, team }

/// `MessageKind`.
enum MessageKind { text, card, system }

/// `HelpStatus`.
enum HelpStatus { open, claimed, resolved }

/// `Message`.
class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.clientId,
    required this.body,
    required this.kind,
    required this.createdAt,
  });

  final String id;
  final String conversationId;

  /// Null for system messages.
  final String? senderId;

  /// The UUID the sender's app made, so it can swap its instant copy for
  /// this message.
  final String? clientId;
  final String body;
  final MessageKind kind;
  final DateTime createdAt;

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    id: readString(json, 'id'),
    conversationId: readString(json, 'conversationId'),
    senderId: readNullableString(json, 'senderId'),
    clientId: readNullableString(json, 'clientId'),
    body: readString(json, 'body'),
    kind: readEnum(json, 'kind', MessageKind.values),
    createdAt: readDateTime(json, 'createdAt'),
  );
}

/// `SendMessageBody`: `POST /api/conversations/{id}/messages`.
class SendMessageBody {
  const SendMessageBody({required this.clientId, required this.body});

  /// A UUID made by the app. Retrying with the same one returns the same
  /// message instead of sending it twice.
  final String clientId;

  /// 1 to 4000 characters.
  final String body;

  Map<String, dynamic> toJson() => {'clientId': clientId, 'body': body};
}

/// `MessagePage`: messages oldest first, and whether there are more.
class MessagePage {
  const MessagePage({required this.messages, required this.hasMore});

  final List<Message> messages;
  final bool hasMore;

  factory MessagePage.fromJson(Map<String, dynamic> json) => MessagePage(
    messages: readList(json, 'messages', Message.fromJson),
    hasMore: readBool(json, 'hasMore'),
  );
}

/// `ConversationSummary.helpRequest`: the help request a mentor chat is about.
class ConversationHelpRequest {
  const ConversationHelpRequest({
    required this.id,
    required this.title,
    required this.status,
  });

  final String id;
  final String title;
  final HelpStatus status;

  factory ConversationHelpRequest.fromJson(Map<String, dynamic> json) =>
      ConversationHelpRequest(
        id: readString(json, 'id'),
        title: readString(json, 'title'),
        status: readEnum(json, 'status', HelpStatus.values),
      );
}

/// `ConversationSummary`: one row of my conversations list.
class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.kind,
    required this.peer,
    required this.team,
    required this.helpRequest,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
    required this.peerLastReadAt,
    required this.createdAt,
  });

  final String id;
  final ConversationKind kind;

  /// The other person (DM partner, or the mentor/hacker in a mentor chat).
  /// Null in team chats.
  final PersonSummary? peer;
  final TeamRef? team;
  final ConversationHelpRequest? helpRequest;
  final Message? lastMessage;

  /// Last message activity; creation time while the conversation is empty.
  final DateTime lastMessageAt;
  final int unreadCount;
  final DateTime? peerLastReadAt;
  final DateTime createdAt;

  factory ConversationSummary.fromJson(Map<String, dynamic> json) {
    final peer = readNullableObject(json, 'peer');
    final team = readNullableObject(json, 'team');
    final help = readNullableObject(json, 'helpRequest');
    final last = readNullableObject(json, 'lastMessage');
    return ConversationSummary(
      id: readString(json, 'id'),
      kind: readEnum(json, 'kind', ConversationKind.values),
      peer: peer == null ? null : PersonSummary.fromJson(peer),
      team: team == null ? null : TeamRef.fromJson(team),
      helpRequest: help == null ? null : ConversationHelpRequest.fromJson(help),
      lastMessage: last == null ? null : Message.fromJson(last),
      lastMessageAt: readDateTime(json, 'lastMessageAt'),
      unreadCount: readInt(json, 'unreadCount'),
      peerLastReadAt: readNullableDateTime(json, 'peerLastReadAt'),
      createdAt: readDateTime(json, 'createdAt'),
    );
  }
}
