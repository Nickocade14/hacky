import '../api/models/conversations.dart';

/// Where a message I wrote is before the server saved it.
enum PendingState { sending, failed }

/// My instant copy of a message, shown with "Sending…" until the server
/// saves it, or with the error and Retry when it fails.
class PendingMessage {
  PendingMessage({required this.clientId, required this.body});

  /// Sent again on Retry, so the server never saves it twice.
  final String clientId;
  final String body;
  PendingState state = PendingState.sending;

  /// Why the last try failed, for the bubble.
  String? error;
}

/// The messages of one 11 Chat thread: the saved ones oldest first, then my
/// pending copies in the order I wrote them (like react/src/social/messages.js).
class ThreadMessages {
  ThreadMessages(MessagePage newest)
    : _saved = [...newest.messages],
      hasMore = newest.hasMore,
      syncedId = newest.messages.lastOrNull?.id;

  final List<Message> _saved;
  final List<PendingMessage> _pending = [];

  /// Older messages are still on the server.
  bool hasMore;

  /// The newest message id seen in a page from `listMessages`: the `after`
  /// cursor for the next refresh. Messages I just sent don't move it, so a
  /// message someone else sent just before mine isn't skipped.
  String? syncedId;

  List<Message> get saved => List.unmodifiable(_saved);
  List<PendingMessage> get pending => List.unmodifiable(_pending);
  bool get isEmpty => _saved.isEmpty && _pending.isEmpty;

  /// The `before` cursor for the next older page.
  String? get oldestId => _saved.firstOrNull?.id;

  /// Adds a page loaded with `before` above what's on screen.
  void addOlder(MessagePage page) {
    _merge(page.messages);
    hasMore = page.hasMore;
  }

  /// Adds a page loaded with `after: syncedId` (or the newest page when the
  /// thread was empty). Returns the messages that weren't on screen yet.
  List<Message> addNewer(MessagePage page) {
    if (syncedId == null) hasMore = page.hasMore;
    final added = _merge(page.messages);
    final last = page.messages.lastOrNull?.id;
    if (last != null && (syncedId == null || last.compareTo(syncedId!) > 0)) {
      syncedId = last;
    }
    return added;
  }

  /// Adds my pending copy of a message I just wrote.
  PendingMessage write(String clientId, String body) {
    final message = PendingMessage(clientId: clientId, body: body);
    _pending.add(message);
    return message;
  }

  /// The server saved [message]: it replaces my pending copy.
  void sent(Message message) => _merge([message]);

  void failed(String clientId, String error) {
    final message = _pendingOf(clientId);
    if (message == null) return;
    message
      ..state = PendingState.failed
      ..error = error;
  }

  void retrying(String clientId) {
    final message = _pendingOf(clientId);
    if (message == null) return;
    message
      ..state = PendingState.sending
      ..error = null;
  }

  /// Drops a pending copy that failed and won't be retried.
  void discard(String clientId) =>
      _pending.removeWhere((m) => m.clientId == clientId);

  /// Takes out a saved message I unsent. The cursors stay, since ids keep
  /// growing.
  void remove(String messageId) =>
      _saved.removeWhere((m) => m.id == messageId);

  /// My newest saved message, for "Seen".
  Message? lastSavedFrom(String userId) {
    for (final m in _saved.reversed) {
      if (m.senderId == userId) return m;
    }
    return null;
  }

  PendingMessage? _pendingOf(String clientId) =>
      _pending.where((m) => m.clientId == clientId).firstOrNull;

  /// Adds saved messages it doesn't have, in id order (the server orders by
  /// ObjectId), and drops the pending copies they replace.
  List<Message> _merge(Iterable<Message> messages) {
    final known = {for (final m in _saved) m.id};
    final added = [
      for (final m in messages)
        if (known.add(m.id)) m,
    ];
    final sent = {for (final m in messages) ?m.clientId};
    _pending.removeWhere((m) => sent.contains(m.clientId));
    if (added.isNotEmpty) {
      _saved
        ..addAll(added)
        ..sort((a, b) => a.id.compareTo(b.id));
    }
    return added;
  }
}
