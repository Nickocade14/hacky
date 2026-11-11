import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where "New chat" in 12 Hacky chat starts: the id of the last message
/// before it, per user and event. The server keeps the whole history, so the
/// chat shows only what came after. Same as the web's `hacky-chat-start`
/// (web/src/HackyPage.tsx).
abstract interface class ChatStartStore {
  Future<String?> read(String userId, String eventSlug);
  Future<void> write(String userId, String eventSlug, String messageId);
}

/// On the phone, so a new chat stays new after the app restarts.
class DeviceChatStartStore implements ChatStartStore {
  DeviceChatStartStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static String _key(String userId, String slug) =>
      'hacky_chat_start_${userId}_$slug';

  @override
  Future<String?> read(String userId, String eventSlug) =>
      _storage.read(key: _key(userId, eventSlug));

  @override
  Future<void> write(String userId, String eventSlug, String messageId) =>
      _storage.write(key: _key(userId, eventSlug), value: messageId);
}

/// Lasts while the app runs. The default, and what tests use.
class MemoryChatStartStore implements ChatStartStore {
  final _starts = <String, String>{};

  @override
  Future<String?> read(String userId, String eventSlug) async =>
      _starts['$userId/$eventSlug'];

  @override
  Future<void> write(String userId, String eventSlug, String messageId) async =>
      _starts['$userId/$eventSlug'] = messageId;
}
