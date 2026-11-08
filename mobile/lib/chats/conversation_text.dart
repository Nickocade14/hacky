import '../api/models/auth.dart';
import '../api/models/conversations.dart';

/// The words 10 Conversations and the 11 header show for a conversation,
/// as in the original Hacky (react/src/social/Lists.jsx and Thread.jsx).
abstract final class ConversationText {
  /// The other person's name, or the team's name in a team chat.
  static String title(ConversationSummary c) =>
      c.team?.name ?? c.peer?.name ?? 'Chat';

  /// The muted line under the name in the 11 header: the role in a direct
  /// message, the help request in a mentor chat.
  static String subtitle(ConversationSummary c) => switch (c.kind) {
    ConversationKind.team => 'Team chat',
    ConversationKind.mentor => c.helpRequest == null
        ? 'Mentor chat'
        : 'Help: ${c.helpRequest!.title}',
    ConversationKind.dm => c.peer == null ? '' : roleLabel(c.peer!.role),
  };

  /// The last message as the row's preview, "You: " first when I sent it.
  static String preview(ConversationSummary c, String myUserId) {
    final last = c.lastMessage;
    if (last == null) {
      return switch (c.kind) {
        ConversationKind.mentor => c.helpRequest == null
            ? 'Mentor chat started'
            : 'Help: ${c.helpRequest!.title}',
        _ => 'Say hi',
      };
    }
    if (last.kind == MessageKind.system) return last.body;
    final mine = last.senderId == myUserId ? 'You: ' : '';
    return '$mine${body(last)}';
  }

  /// What a message says. Cards hold JSON, so they get a short line instead.
  static String body(Message m) =>
      m.kind == MessageKind.card ? 'Shared a card' : m.body;

  /// The unread badge: "99+" past 99.
  static String unread(int count) => count > 99 ? '99+' : '$count';

  static String roleLabel(MemberRole role) => switch (role) {
    MemberRole.hacker => 'Hacker',
    MemberRole.mentor => 'Mentor',
    MemberRole.sponsor => 'Sponsor',
    MemberRole.organizer => 'Organizer',
  };
}
