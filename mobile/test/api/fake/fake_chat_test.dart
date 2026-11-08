import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/api_exception.dart';
import 'package:mobile/api/models/chat.dart';
import 'package:mobile/api/models/requests.dart';

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

String textOf(ChatMessage message) =>
    message.parts.firstWhere((p) => p['type'] == 'text')['text'] as String;

/// The cards of the answer's `search_people` tool part.
List<Map<String, dynamic>> cardsOf(ChatMessage message) {
  final tool = message.parts.singleWhere(
    (p) => p['type'] == 'tool-search_people',
  );
  expect(tool['state'], 'output-available');
  final output = tool['output'] as Map<String, dynamic>;
  expect(output['status'], 'matches');
  return [...(output['cards'] as List).cast<Map<String, dynamic>>()];
}

List<String> handlesOf(ChatMessage message) => [
  for (final card in cardsOf(message))
    (card['person'] as Map<String, dynamic>)['handle'] as String,
];

Matcher apiError(int status) =>
    throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', status));

void main() {
  late FakeHost fake;

  setUp(() => fake = FakeHost());

  test('the history starts empty', () async {
    expect(await fake.getChatHistory(slug), isEmpty);
  });

  test('answers with text and a card per person whose skills match', () async {
    final answer = await fake.sendChat(
      slug,
      ask('Find a teammate who knows React'),
    );

    expect(answer.role, ChatRole.assistant);
    expect(answer.parts, hasLength(2));
    expect(textOf(answer), startsWith('Here\'s who could help'));
    expect(handlesOf(answer), ['leo_builds', 'jordan_ux']);
    final leo = cardsOf(answer).first;
    final world = await fake.fakeWorld();
    expect(leo['card'], 'person');
    expect(leo['person'], {
      'userId': world.byHandle('leo_builds')!.userId,
      'handle': 'leo_builds',
      'name': 'Leo Nguyen',
      'hackyStyle': <String, dynamic>{},
      'photoUrl': null,
      'role': 'hacker',
    });
    expect(leo['skills'], ['react', 'node', 'mongodb']);
    expect(leo['evidence'], {
      'matchedSkills': ['react'],
    });
    expect(leo['reason'], isNotEmpty);
  });

  test('asking for a mentor only shows mentors, as mentor cards', () async {
    final answer = await fake.sendChat(slug, ask('Find a Flutter mentor'));

    expect(handlesOf(answer), ['sam_mentor']);
    final sam = cardsOf(answer).single;
    expect(sam['card'], 'mentor');
    expect(sam['verified'], isTrue);
    expect(sam['evidence'], {
      'matchedSkills': ['flutter'],
      'availability': 'busy',
    });
  });

  test('short words only match whole skills', () async {
    final answer = await fake.sendChat(slug, ask('Who can do Go on a team?'));

    expect(handlesOf(answer), ['priya_codes']);
  });

  test('leaves out people I blocked', () async {
    final world = await fake.fakeWorld();
    final leo = world.byHandle('leo_builds')!.userId;
    await fake.blockUser(BlockBody(userId: leo));

    final answer = await fake.sendChat(slug, ask('react people?'));

    expect(handlesOf(answer), ['jordan_ux']);
  });

  test('says so in text only when nobody matches', () async {
    final answer = await fake.sendChat(slug, ask('Anyone into COBOL?'));

    expect(answer.parts, hasLength(1));
    expect(textOf(answer), startsWith('I didn\'t find anyone'));
  });

  test('keeps the history, oldest first', () async {
    await fake.sendChat(slug, ask('python people?'));

    final history = await fake.getChatHistory(slug);

    expect(history.map((m) => m.role), [ChatRole.user, ChatRole.assistant]);
    expect(handlesOf(history.last), ['maya_ml']);
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
