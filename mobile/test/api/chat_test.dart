import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/api_exception.dart';
import 'package:mobile/api/models/chat.dart';

import 'support.dart';

// Part shapes here are only test data; the contract leaves them open.
const userMessage = ChatMessage(
  id: 'm-user-1',
  role: ChatRole.user,
  parts: [
    {'type': 'text', 'text': 'Find me a backend teammate'},
  ],
);

const assistantJson = {
  'id': 'm-assistant-1',
  'role': 'assistant',
  'parts': [
    {'type': 'text', 'text': 'Maya does Python and wants a Flutter dev.'},
    {
      'type': 'tool-showPeople',
      'output': {
        'handles': ['maya_ml'],
      },
    },
  ],
};

void main() {
  late ApiHarness api;

  setUp(() => api = ApiHarness());

  group('sendChat', () {
    test('POSTs the newest message with format=json', () async {
      api.respond({'message': assistantJson});

      final answer = await api.client.sendChat(
        'knighthacks-ix',
        const ChatBody(message: userMessage),
      );

      expect(api.lastCall, 'POST /api/events/knighthacks-ix/chat?format=json');
      expect(api.lastAuth, 'Bearer $testToken');
      expect(api.lastBody, {
        'message': {
          'id': 'm-user-1',
          'role': 'user',
          'parts': [
            {'type': 'text', 'text': 'Find me a backend teammate'},
          ],
        },
      });
      expect(answer.role, ChatRole.assistant);
      expect(answer.parts, hasLength(2));
      expect(answer.parts.last['output'], {
        'handles': ['maya_ml'],
      });
    });

    test('throws rate_limited when sending too fast', () async {
      api.fail(429, 'rate_limited');

      await expectLater(
        api.client.sendChat(
          'knighthacks-ix',
          const ChatBody(message: userMessage),
        ),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'rate_limited'),
        ),
      );
    });

    test('a message without parts is an invalid_response', () async {
      api.respond({
        'message': {'id': 'x', 'role': 'assistant'},
      });

      await expectLater(
        api.client.sendChat(
          'knighthacks-ix',
          const ChatBody(message: userMessage),
        ),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'invalid_response'),
        ),
      );
    });
  });

  group('getChatHistory', () {
    test('GETs the history oldest first', () async {
      api.respond({
        'messages': [userMessage.toJson(), assistantJson],
      });

      final history = await api.client.getChatHistory('knighthacks-ix');

      expect(api.lastCall, 'GET /api/events/knighthacks-ix/chat');
      expect(history.map((m) => m.role), [ChatRole.user, ChatRole.assistant]);
      expect(history.first.parts.single['text'], 'Find me a backend teammate');
    });

    test('throws forbidden when I am not in the event', () async {
      api.fail(403, 'forbidden');

      await expectLater(
        api.client.getChatHistory('knighthacks-ix'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)),
      );
    });
  });
}
