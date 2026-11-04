// Hacky chat schemas from docs/openapi.yaml: ChatMessage, ChatBody.

import 'json_read.dart';

/// `ChatMessage.role`.
enum ChatRole { user, assistant, system }

/// `ChatMessage`: an AI SDK UIMessage. The contract leaves the shape of each
/// part open (text and tool results, i.e. cards), so [parts] stay maps.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.parts,
  });

  final String id;
  final ChatRole role;
  final List<Map<String, dynamic>> parts;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: readString(json, 'id'),
    role: readEnum(json, 'role', ChatRole.values),
    parts: readObjectList(json, 'parts'),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role.name,
    'parts': parts,
  };
}

/// `ChatBody`: `POST /api/events/{slug}/chat`. Send only the newest message;
/// the server loads the history itself.
class ChatBody {
  const ChatBody({required this.message});

  final ChatMessage message;

  Map<String, dynamic> toJson() => {'message': message.toJson()};
}
