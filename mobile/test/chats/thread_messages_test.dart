import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/models/conversations.dart';
import 'package:mobile/chats/thread_messages.dart';

const me = 'aaaaaaaaaaaaaaaaaaaaaaaa';
const peer = 'bbbbbbbbbbbbbbbbbbbbbbbb';

/// Message number [n]; ids grow with n, like ObjectIds.
Message m(int n, {String sender = peer, String? clientId}) => Message(
  id: '6716a3f2c9e7${n.toRadixString(16).padLeft(12, '0')}',
  conversationId: 'dddddddddddddddddddddddd',
  senderId: sender,
  clientId: clientId,
  body: 'message $n',
  kind: MessageKind.text,
  createdAt: DateTime.utc(2026, 11, 5, 12, n),
);

List<String> bodies(ThreadMessages t) => [for (final x in t.saved) x.body];

void main() {
  test('starts from the newest page', () {
    final t = ThreadMessages(MessagePage(messages: [m(4), m(5)], hasMore: true));
    expect(bodies(t), ['message 4', 'message 5']);
    expect(t.hasMore, isTrue);
    expect(t.oldestId, m(4).id);
    expect(t.syncedId, m(5).id);
    expect(t.isEmpty, isFalse);
  });

  test('adds older pages on top, once', () {
    final t = ThreadMessages(MessagePage(messages: [m(4), m(5)], hasMore: true));
    t.addOlder(MessagePage(messages: [m(2), m(3), m(4)], hasMore: false));
    expect(bodies(t), ['message 2', 'message 3', 'message 4', 'message 5']);
    expect(t.hasMore, isFalse);
    expect(t.syncedId, m(5).id);
  });

  test('adds newer pages and moves the cursor', () {
    final t = ThreadMessages(const MessagePage(messages: [], hasMore: false));
    expect(t.isEmpty, isTrue);
    expect(t.syncedId, isNull);

    final added = t.addNewer(MessagePage(messages: [m(1), m(2)], hasMore: false));
    expect(added, hasLength(2));
    expect(t.syncedId, m(2).id);
    expect(t.addNewer(MessagePage(messages: [m(2)], hasMore: false)), isEmpty);
  });

  test('a sent message replaces its pending copy but keeps the cursor', () {
    final t = ThreadMessages(MessagePage(messages: [m(1)], hasMore: false));
    final pending = t.write('c-1', 'hello');
    expect(t.pending.single.state, PendingState.sending);

    t.sent(m(3, sender: me, clientId: 'c-1'));
    expect(t.pending, isEmpty);
    expect(bodies(t), ['message 1', 'message 3']);
    expect(pending.body, 'hello');
    // Message 2 came from the peer just before mine: the next refresh still
    // asks after message 1, so it isn't skipped.
    expect(t.syncedId, m(1).id);
    t.addNewer(MessagePage(messages: [m(2), m(3, sender: me)], hasMore: false));
    expect(bodies(t), ['message 1', 'message 2', 'message 3']);
  });

  test('a refresh that brings my message first also clears the copy', () {
    final t = ThreadMessages(MessagePage(messages: [m(1)], hasMore: false));
    t.write('c-1', 'hello');
    t.addNewer(
      MessagePage(messages: [m(2, sender: me, clientId: 'c-1')], hasMore: false),
    );
    expect(t.pending, isEmpty);
    t.sent(m(2, sender: me, clientId: 'c-1'));
    expect(bodies(t), ['message 1', 'message 2']);
  });

  test('failed, retrying and discard', () {
    final t = ThreadMessages(const MessagePage(messages: [], hasMore: false));
    t.write('c-1', 'hello');
    t.failed('c-1', 'No connection');
    expect(t.pending.single.state, PendingState.failed);
    expect(t.pending.single.error, 'No connection');

    t.retrying('c-1');
    expect(t.pending.single.state, PendingState.sending);
    expect(t.pending.single.error, isNull);

    t.discard('c-1');
    expect(t.isEmpty, isTrue);
  });

  test('lastSavedFrom finds my newest saved message', () {
    final t = ThreadMessages(
      MessagePage(
        messages: [m(1, sender: me), m(2, sender: me), m(3)],
        hasMore: false,
      ),
    );
    expect(t.lastSavedFrom(me)!.id, m(2).id);
    expect(t.lastSavedFrom('cccccccccccccccccccccccc'), isNull);
  });

  test('remove takes out an unsent message and keeps the cursors', () {
    final t = ThreadMessages(
      MessagePage(messages: [m(1), m(2, sender: me), m(3)], hasMore: true),
    );

    t.remove(m(2).id);

    expect(bodies(t), ['message 1', 'message 3']);
    expect(t.lastSavedFrom(me), isNull);
    expect(t.syncedId, m(3).id);
    final added = t.addNewer(MessagePage(messages: [m(4)], hasMore: false));
    expect(added.map((x) => x.id), [m(4).id]);
  });
}
