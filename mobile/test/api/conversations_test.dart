import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/api_exception.dart';
import 'package:mobile/api/models/conversations.dart';

import 'fixtures.dart';
import 'support.dart';

const conversationId = '6716a3f2c9e77b0012ab0301';

void main() {
  late ApiHarness api;

  setUp(() => api = ApiHarness());

  group('listConversations', () {
    test('GETs my conversations in the event', () async {
      api.respond({
        'conversations': [conversationSummaryJson],
      });

      final conversations = await api.client.listConversations(
        'knighthacks-ix',
      );

      expect(api.lastCall, 'GET /api/events/knighthacks-ix/conversations');
      expect(api.lastAuth, 'Bearer $testToken');
      final dm = conversations.single;
      expect(dm.kind, ConversationKind.dm);
      expect(dm.peer!.handle, 'maya_ml');
      expect(dm.team, isNull);
      expect(dm.helpRequest, isNull);
      expect(dm.lastMessage!.body, startsWith('Hey!'));
      expect(dm.unreadCount, 1);
      expect(dm.peerLastReadAt, isNull);
    });

    test('parses a mentor chat with its help request', () async {
      api.respond({
        'conversations': [
          {
            ...conversationSummaryJson,
            'kind': 'mentor',
            'helpRequest': {
              'id': '6716a3f2c9e77b0012ab0501',
              'title': 'Firebase auth keeps failing',
              'status': 'claimed',
            },
            'lastMessage': null,
            'unreadCount': 0,
            'peerLastReadAt': '2026-11-14T16:10:00.000Z',
          },
        ],
      });

      final mentor = (await api.client.listConversations('knighthacks-ix'))
          .single;

      expect(mentor.kind, ConversationKind.mentor);
      expect(mentor.helpRequest!.status, HelpStatus.claimed);
      expect(mentor.lastMessage, isNull);
      expect(mentor.peerLastReadAt, DateTime.utc(2026, 11, 14, 16, 10));
    });

    test('parses a team chat without a peer', () async {
      api.respond({
        'conversations': [
          {
            ...conversationSummaryJson,
            'kind': 'team',
            'peer': null,
            'team': {
              'id': '6716a3f2c9e77b0012ab0201',
              'name': 'Rash Decisions',
            },
          },
        ],
      });

      final team = (await api.client.listConversations('knighthacks-ix'))
          .single;

      expect(team.peer, isNull);
      expect(team.team!.name, 'Rash Decisions');
    });
  });

  group('listMessages', () {
    test('GETs the newest page without cursors', () async {
      api.respond({
        'messages': [systemMessageJson, messageJson],
        'hasMore': false,
      });

      final page = await api.client.listMessages(conversationId);

      expect(api.lastCall, 'GET /api/conversations/$conversationId/messages');
      expect(page.hasMore, isFalse);
      expect(page.messages.first.kind, MessageKind.system);
      expect(page.messages.first.senderId, isNull);
      expect(page.messages.first.clientId, isNull);
      expect(page.messages.last.kind, MessageKind.text);
      expect(page.messages.last.createdAt, DateTime.utc(2026, 11, 14, 16, 5));
    });

    test('sends before and limit', () async {
      api.respond({'messages': <Object>[], 'hasMore': true});

      await api.client.listMessages(
        conversationId,
        before: '6716a3f2c9e77b0012ab0400',
        limit: 50,
      );

      expect(api.last.url.queryParameters, {
        'before': '6716a3f2c9e77b0012ab0400',
        'limit': '50',
      });
    });

    test('sends after', () async {
      api.respond({'messages': <Object>[], 'hasMore': false});

      await api.client.listMessages(
        conversationId,
        after: '6716a3f2c9e77b0012ab0401',
      );

      expect(api.last.url.queryParameters, {
        'after': '6716a3f2c9e77b0012ab0401',
      });
    });

    test('refuses before and after together, and a bad limit', () {
      expect(
        () => api.client.listMessages(conversationId, before: 'a', after: 'b'),
        throwsArgumentError,
      );
      expect(
        () => api.client.listMessages(conversationId, limit: 101),
        throwsRangeError,
      );
      expect(api.requests, isEmpty);
    });
  });

  group('sendMessage', () {
    test('POSTs clientId and body and unwraps the message', () async {
      api.respond({'message': messageJson}, 201);

      final message = await api.client.sendMessage(
        conversationId,
        const SendMessageBody(
          clientId: '3f1c2a5e-8b7d-4e6f-9a01-23456789abcd',
          body: 'Hey! Saw you do Flutter. Want to team up?',
        ),
      );

      expect(api.lastCall, 'POST /api/conversations/$conversationId/messages');
      expect(api.lastBody, {
        'clientId': '3f1c2a5e-8b7d-4e6f-9a01-23456789abcd',
        'body': 'Hey! Saw you do Flutter. Want to team up?',
      });
      expect(message.id, '6716a3f2c9e77b0012ab0401');
      expect(message.clientId, '3f1c2a5e-8b7d-4e6f-9a01-23456789abcd');
    });

    test('throws forbidden when blocked', () async {
      api.fail(403, 'forbidden');

      await expectLater(
        api.client.sendMessage(
          conversationId,
          const SendMessageBody(clientId: 'c', body: 'hi'),
        ),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'forbidden')),
      );
    });
  });

  group('deleteMessage', () {
    const messageId = '6716a3f2c9e77b0012ab0401';

    test('DELETEs the message', () async {
      api.respond({'ok': true});

      await api.client.deleteMessage(conversationId, messageId);

      expect(
        api.lastCall,
        'DELETE /api/conversations/$conversationId/messages/$messageId',
      );
      expect(api.lastAuth, 'Bearer $testToken');
      expect(api.lastBody, isNull);
    });

    test('throws forbidden for someone else\'s message', () async {
      api.fail(403, 'forbidden');

      await expectLater(
        api.client.deleteMessage(conversationId, messageId),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'forbidden')),
      );
    });

    test('throws not_found when it is already gone', () async {
      api.fail(404, 'not_found');

      await expectLater(
        api.client.deleteMessage(conversationId, messageId),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
      );
    });
  });

  group('markRead', () {
    test('POSTs to the read route and returns lastReadAt', () async {
      api.respond({'lastReadAt': '2026-11-14T16:20:00.000Z'});

      final lastReadAt = await api.client.markRead(conversationId);

      expect(api.lastCall, 'POST /api/conversations/$conversationId/read');
      expect(api.lastBody, isNull);
      expect(lastReadAt, DateTime.utc(2026, 11, 14, 16, 20));
    });

    test('throws not_found for an unknown conversation', () async {
      api.fail(404, 'not_found');

      await expectLater(
        api.client.markRead('6716a3f2c9e77b0012ab9999'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'not_found')),
      );
    });
  });
}
