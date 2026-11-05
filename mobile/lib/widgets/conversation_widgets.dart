// The rows of 10 Conversations (mobile/design/messages-wireframes.svg), in the
// original Hacky look (react/src/social/Lists.jsx, social.css). Colors and
// fonts come from lib/theme.dart.

import 'package:flutter/material.dart';

import '../api/models/conversations.dart';
import '../chats/chat_time.dart';
import '../chats/conversation_text.dart';
import '../theme.dart';
import 'app_widgets.dart';

const _bold = FontWeight.w700;

/// A team chat's avatar: the team's initials in a rounded square, so it
/// reads apart from the round avatars of people.
class TeamAvatar extends StatelessWidget {
  const TeamAvatar({super.key, required this.name, this.size = 44});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final letters = PersonAvatar.initials(name);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.wash,
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        child: Text(
          letters.isEmpty ? '#' : letters,
          style: TextStyle(
            color: AppColors.action,
            fontSize: size * 0.36,
            fontWeight: _bold,
          ),
        ),
      ),
    );
  }
}

/// Round for a person, square for a team.
class ConversationAvatar extends StatelessWidget {
  const ConversationAvatar({
    super.key,
    required this.conversation,
    this.size = 44,
  });

  final ConversationSummary conversation;
  final double size;

  @override
  Widget build(BuildContext context) {
    final name = ConversationText.title(conversation);
    return conversation.kind == ConversationKind.team
        ? TeamAvatar(name: name, size: size)
        : PersonAvatar(name: name, size: size);
  }
}

/// One chat: avatar, name, the last message, when, and the unread badge.
/// Unread chats show the preview in ink and bold.
class ConversationRow extends StatelessWidget {
  const ConversationRow({
    super.key,
    required this.conversation,
    required this.myUserId,
    required this.now,
    required this.onTap,
  });

  final ConversationSummary conversation;
  final String myUserId;

  /// For "2m", "Yesterday"; passed in so all rows agree.
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final unread = c.unreadCount > 0;
    final title = c.kind == ConversationKind.mentor && c.peer != null
        ? 'Mentor · ${c.peer!.name}'
        : ConversationText.title(c);
    return Semantics(
      button: true,
      label: unread
          ? '$title, ${ConversationText.unread(c.unreadCount)} unread'
          : title,
      excludeSemantics: true,
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          spacing: 14,
          children: [
            ConversationAvatar(conversation: c),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 15,
                      fontWeight: _bold,
                    ),
                  ),
                  Text(
                    ConversationText.preview(c, myUserId),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: unread ? AppColors.ink : AppColors.muted,
                      fontSize: 13,
                      fontWeight: unread ? _bold : FontWeight.w400,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              spacing: 6,
              children: [
                Text(
                  ChatTime.ago(c.lastMessageAt, now),
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                if (unread) CountBadge(ConversationText.unread(c.unreadCount)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
