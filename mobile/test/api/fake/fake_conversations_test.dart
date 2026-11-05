import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/api_exception.dart';
import 'package:mobile/api/fake/fake_world.dart';
import 'package:mobile/api/models/conversations.dart';
import 'package:mobile/api/models/requests.dart';

import 'fake_host.dart';

const slug = 'knighthacks-ix';

Matcher apiError(int status) =>
    throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', status));

void main() {
  late FakeHost fake;
  late FakeWorld world;
  late String dmId;

  setUp(() async {
    fake = FakeHost();
    world = await fake.fakeWorld();
    dmId = world.conversations.keys.single;
  });

  group('listConversations', () {
    test('has the DM with Priya, with one unread message', () async {
      final dm = (await fake.listConversations(slug)).single;

      expect(dm.kind, ConversationKind.dm);
      expect(dm.peer!.handle, 'priya_codes');
      expect(dm.team, isNull);
      expect(dm.helpRequest, isNull);
      expect(dm.unreadCount, 1);
      expect(dm.lastMessage!.body, contains('food tables'));
      expect(dm.lastMessageAt, dm.lastMessage!.createdAt);
      expect(dm.peerLastReadAt, isNotNull);
    });

    test('puts the newest activity first', () async {
      final jordan = world.requests.values.firstWhere(
        (r) => r.fromId == world.byHandle('jordan_ux')!.userId,
      );
      await fake.acceptRequest(jordan.id);

      final list = await fake.listConversations(slug);

      expect(list.map((c) => c.peer!.handle), ['jordan_ux', 'priya_codes']);
    });

    test('403s outside my events', () async {
      await expectLater(fake.listConversations('other'), apiError(403));
    });
  });

  group('listMessages', () {
    test('returns the newest page oldest first', () async {
      final page = await fake.listMessages(dmId);

      expect(page.hasMore, isFalse);
      expect(page.messages.map((m) => m.kind), [
        MessageKind.system,
        MessageKind.text,
        MessageKind.text,
      ]);
      expect(page.messages.first.senderId, isNull);
    });

    test('pages with limit, before and after', () async {
      for (var i = 0; i < 5; i++) {
        await fake.sendMessage(
          dmId,
          SendMessageBody(clientId: 'c$i', body: 'Message $i'),
        );
      }

      final newest = await fake.listMessages(dmId, limit: 3);
      expect(newest.messages.map((m) => m.body), [
        'Message 2',
        'Message 3',
        'Message 4',
      ]);
      expect(newest.hasMore, isTrue);

      final older = await fake.listMessages(
        dmId,
        before: newest.messages.first.id,
        limit: 3,
      );
      expect(older.messages.last.body, 'Message 1');
      expect(older.hasMore, isTrue);

      final after = await fake.listMessages(
        dmId,
        after: older.messages.last.id,
        limit: 2,
      );
      expect(after.messages.map((m) => m.body), ['Message 2', 'Message 3']);
      expect(after.hasMore, isTrue);
    });

    test('404s for unknown conversations', () async {
      await expectLater(fake.listMessages('nope'), apiError(404));
    });
  });

  group('sendMessage', () {
    test('adds my message and keeps it read for me', () async {
      final sent = await fake.sendMessage(
        dmId,
        const SendMessageBody(clientId: 'abc', body: 'See you at 3!'),
      );

      expect(sent.senderId, world.me.userId);
      expect(sent.kind, MessageKind.text);
      final dm = (await fake.listConversations(slug)).single;
      expect(dm.lastMessage!.id, sent.id);
      expect(dm.unreadCount, 0);
    });

    test('a retry with the same clientId returns the same message', () async {
      const body = SendMessageBody(clientId: 'same', body: 'Hi');
      final first = await fake.sendMessage(dmId, body);
      final second = await fake.sendMessage(dmId, body);

      expect(second.id, first.id);
      expect((await fake.listMessages(dmId)).messages, hasLength(4));
    });

    test('rejects an empty body', () async {
      await expectLater(
        fake.sendMessage(dmId, const SendMessageBody(clientId: 'x', body: ' ')),
        apiError(400),
      );
    });
  });

  group('deleteMessage', () {
    Message mine() => world.conversations[dmId]!.messages.firstWhere(
      (m) => m.senderId == world.me.userId,
    );

    test('removes my message from the pages and the list', () async {
      final sent = await fake.sendMessage(
        dmId,
        const SendMessageBody(clientId: 'oops', body: 'Wrong chat'),
      );

      await fake.deleteMessage(dmId, sent.id);

      final page = await fake.listMessages(dmId);
      expect(page.messages.map((m) => m.id), isNot(contains(sent.id)));
      expect(page.messages, hasLength(3));
      final dm = (await fake.listConversations(slug)).single;
      expect(dm.lastMessage!.body, contains('food tables'));
    });

    test('404s when it is already gone', () async {
      final id = mine().id;
      await fake.deleteMessage(dmId, id);

      await expectLater(fake.deleteMessage(dmId, id), apiError(404));
    });

    test('403s for their messages and system messages', () async {
      final messages = world.conversations[dmId]!.messages;
      final system = messages.firstWhere((m) => m.kind == MessageKind.system);
      final theirs = messages.firstWhere(
        (m) => m.senderId != null && m.senderId != world.me.userId,
      );

      await expectLater(fake.deleteMessage(dmId, system.id), apiError(403));
      await expectLater(fake.deleteMessage(dmId, theirs.id), apiError(403));
      expect(messages, hasLength(3));
    });
  });

  test('after a block the DM stays listed but sending 403s', () async {
    final priya = world.byHandle('priya_codes')!.userId;
    await fake.blockUser(BlockBody(userId: priya));

    expect((await fake.listConversations(slug)).single.id, dmId);
    await expectLater(
      fake.sendMessage(dmId, const SendMessageBody(clientId: 'b', body: 'Hi')),
      apiError(403),
    );
  });

  group('markRead', () {
    test('clears the unread count', () async {
      final readAt = await fake.markRead(dmId);

      final dm = (await fake.listConversations(slug)).single;
      expect(dm.unreadCount, 0);
      expect(readAt.isUtc, isTrue);
    });

    test('403s for a conversation I am not in', () async {
      final other = FakeConversation(
        id: world.newId(),
        kind: ConversationKind.dm,
        memberIds: ['someone', 'else'],
        createdAt: world.now(),
      );
      world.conversations[other.id] = other;

      await expectLater(fake.markRead(other.id), apiError(403));
    });
  });

  test('a mutual request opens a DM that shows up in the list', () async {
    await fake.sendRequest(
      slug,
      SendRequestBody(
        toUserId: world.byHandle('jordan_ux')!.userId,
        intro: 'Yes!',
      ),
    );

    final list = await fake.listConversations(slug);
    expect(list, hasLength(2));
    expect(list.first.lastMessage!.kind, MessageKind.system);
  });
}
