import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/api_exception.dart';
import 'package:mobile/api/models/chat.dart';

import 'fake_host.dart';

const slug = 'knighthacks-ix';

ChatBody ask(String text, {ChatRole role = ChatRole.user}) => ChatBody(
  message: ChatMessage(
    id: 'user-${text.hashCode}',
    role: role,
    parts: [
      {'type': 'text', 'text': text},
    ],
  ),
);

String textOf(ChatMessage message) => message.parts.single['text'] as String;

Matcher apiError(int status) =>
    throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', status));

void main() {
  late FakeHost fake;

  setUp(() => fake = FakeHost());

  test('the history starts empty', () async {
    expect(await fake.getChatHistory(slug), isEmpty);
  });

  test('suggests people whose skills match the message', () async {
    final answer = await fake.sendChat(slug, ask('Who knows Flutter?'));

    expect(answer.role, ChatRole.assistant);
    expect(textOf(answer), contains('@sam_mentor'));
    expect(textOf(answer), isNot(contains('@maya_ml')));
  });

  test('says so when nobody matches', () async {
    final answer = await fake.sendChat(slug, ask('Anyone into COBOL?'));

    expect(textOf(answer), startsWith('I didn\'t find anyone'));
  });

  test('keeps the history, oldest first', () async {
    await fake.sendChat(slug, ask('python people?'));

    final history = await fake.getChatHistory(slug);

    expect(history.map((m) => m.role), [ChatRole.user, ChatRole.assistant]);
    expect(textOf(history.last), contains('@maya_ml'));
  });

  test('only accepts user messages', () async {
    await expectLater(
      fake.sendChat(slug, ask('hi', role: ChatRole.assistant)),
      apiError(400),
    );
  });

  test('403s outside my events', () async {
    await expectLater(fake.sendChat('other', ask('hi')), apiError(403));
    await expectLater(fake.getChatHistory('other'), apiError(403));
  });
}
