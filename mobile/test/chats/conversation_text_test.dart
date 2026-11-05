import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/models/auth.dart';
import 'package:mobile/api/models/conversations.dart';
import 'package:mobile/api/models/people.dart';
import 'package:mobile/api/models/teams.dart';
import 'package:mobile/chats/conversation_text.dart';

const me = 'aaaaaaaaaaaaaaaaaaaaaaaa';
const maya = PersonSummary(
  userId: 'bbbbbbbbbbbbbbbbbbbbbbbb',
  handle: 'maya_ml',
  name: 'Maya Chen',
  hackyStyle: {},
  photoUrl: null,
  role: MemberRole.hacker,
);
final at = DateTime.utc(2026, 11, 5, 12);

Message message(String? senderId, String body, {MessageKind? kind}) => Message(
  id: 'cccccccccccccccccccccccc',
  conversationId: 'dddddddddddddddddddddddd',
  senderId: senderId,
  clientId: null,
  body: body,
  kind: kind ?? (senderId == null ? MessageKind.system : MessageKind.text),
  createdAt: at,
);

ConversationSummary conversation({
  ConversationKind kind = ConversationKind.dm,
  PersonSummary? peer = maya,
  TeamRef? team,
  ConversationHelpRequest? help,
  Message? last,
}) => ConversationSummary(
  id: 'dddddddddddddddddddddddd',
  kind: kind,
  peer: peer,
  team: team,
  helpRequest: help,
  lastMessage: last,
  lastMessageAt: at,
  unreadCount: 0,
  peerLastReadAt: null,
  createdAt: at,
);

void main() {
  test('title is the peer, or the team in a team chat', () {
    expect(ConversationText.title(conversation()), 'Maya Chen');
    final team = conversation(
      kind: ConversationKind.team,
      peer: null,
      team: const TeamRef(id: 'eeeeeeeeeeeeeeeeeeeeeeee', name: 'Byte Me'),
    );
    expect(ConversationText.title(team), 'Byte Me');
    expect(ConversationText.subtitle(team), 'Team chat');
  });

  test('subtitle is the role, or the help request in a mentor chat', () {
    expect(ConversationText.subtitle(conversation()), 'Hacker');
    final mentor = conversation(
      kind: ConversationKind.mentor,
      help: const ConversationHelpRequest(
        id: 'ffffffffffffffffffffffff',
        title: 'Flutter build fails',
        status: HelpStatus.claimed,
      ),
    );
    expect(ConversationText.subtitle(mentor), 'Help: Flutter build fails');
    expect(ConversationText.preview(mentor, me), 'Help: Flutter build fails');
  });

  test('preview marks my messages and keeps system ones as they are', () {
    expect(
      ConversationText.preview(conversation(last: message(me, 'thanks!')), me),
      'You: thanks!',
    );
    expect(
      ConversationText.preview(
        conversation(last: message(maya.userId, 'See you!')),
        me,
      ),
      'See you!',
    );
    expect(
      ConversationText.preview(
        conversation(last: message(null, 'You and Maya are connected.')),
        me,
      ),
      'You and Maya are connected.',
    );
    expect(
      ConversationText.preview(
        conversation(
          last: message(maya.userId, '{"x":1}', kind: MessageKind.card),
        ),
        me,
      ),
      'Shared a card',
    );
    expect(ConversationText.preview(conversation(), me), 'Say hi');
  });

  test('unread caps at 99+', () {
    expect(ConversationText.unread(2), '2');
    expect(ConversationText.unread(120), '99+');
  });
}
