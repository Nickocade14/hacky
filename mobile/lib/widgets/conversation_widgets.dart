// The parts of 10 Chats, laid out like the web's Chats panel
// (web/src/workspace/Sidebar.tsx; original: react/src/social/Lists.jsx): the
// event badge, a row per request with Accept and Not now, and a row per
// conversation. Colors and fonts come from lib/theme.dart.

import 'package:flutter/material.dart';

import '../api/models/auth.dart';
import '../api/models/conversations.dart';
import '../api/models/requests.dart';
import '../chats/chat_time.dart';
import '../chats/conversation_text.dart';
import '../people/person_labels.dart';
import '../theme.dart';
import 'app_widgets.dart';

const _bold = FontWeight.w700;

/// The event at the top of Chats: its initials on a blue tile, its name and
/// "You’re here as a hacker".
class EventBadge extends StatelessWidget {
  const EventBadge({super.key, required this.event});

  final MyEvent event;

  /// "KH" for "Knight Hacks IX".
  static String initials(String name) => PersonAvatar.initials(name);

  @override
  Widget build(BuildContext context) {
    final role = PersonLabels.role(event.role).toLowerCase();
    final verified = event.verified && event.role != MemberRole.hacker;
    return Row(
      spacing: 12,
      children: [
        Container(
          constraints: const BoxConstraints(minWidth: 40),
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.action,
            borderRadius: BorderRadius.circular(7),
          ),
          child: ExcludeSemantics(
            child: Text(
              initials(event.name),
              style: TextStyle(
                color: AppColors.onAction,
                fontSize: 13,
                fontWeight: _bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        Container(width: 1, height: 26, color: AppColors.line),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              Text(
                'You’re here as a $role${verified ? ' · Verified' : ''}',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A request in Chats: who, their role, the team and "Pending" tags, the
/// intro, and Accept / Not now on the ones sent to me. Tapping the avatar
/// opens the person's profile (→ 07).
class InboxRequestRow extends StatelessWidget {
  const InboxRequestRow({
    super.key,
    required this.request,
    required this.busy,
    required this.onOpenPerson,
    required this.onAccept,
    required this.onHide,
  });

  /// The key of the row for request [id], for tests.
  static Key keyOf(String id) => ValueKey('inbox-request-$id');

  final ConnectionRequest request;

  /// Accept or Not now is on its way: both buttons wait.
  final bool busy;
  final VoidCallback onOpenPerson;
  final VoidCallback onAccept;

  /// "Not now".
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    final person = request.person;
    final team = request.team;
    final incoming = request.direction == RequestDirection.incoming;
    final intro = request.intro.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Semantics(
            button: true,
            label: 'View ${person.name}’s profile',
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onOpenPerson,
              child: PersonAvatar.of(person, size: 44),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  person.name,
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: _bold,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    RoleChip(person.role),
                    if (team != null) QuietTag('Team ${team.name}'),
                    if (!incoming)
                      QuietTag(
                        'Pending',
                        ink: AppColors.link,
                        wash: AppColors.hover,
                      ),
                  ],
                ),
                if (intro.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    intro,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 14.5,
                      height: 1.5,
                    ),
                  ),
                ],
                if (incoming) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton(
                        onPressed: busy ? null : onAccept,
                        child: const Text('Accept'),
                      ),
                      OutlinedButton(
                        onPressed: busy ? null : onHide,
                        child: const Text('Not now'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A team chat's avatar: two knit Hackys, one over the other, so it reads
/// apart from a person's.
class TeamAvatar extends StatelessWidget {
  const TeamAvatar({super.key, required this.seed, this.size = 44});

  /// Picks the two colors; the conversation's id, as on the web.
  final String seed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final each = size * 0.66;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          children: [
            PersonAvatar(name: seed, userId: '${seed}a', size: each),
            Positioned(
              left: size - each,
              top: size - each,
              child: PersonAvatar(name: seed, userId: '${seed}b', size: each),
            ),
          ],
        ),
      ),
    );
  }
}

/// The other person's avatar, or two Hackys for a team.
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
    final peer = conversation.peer;
    return peer == null
        ? TeamAvatar(seed: conversation.id, size: size)
        : PersonAvatar.of(peer, size: size);
  }
}

/// One chat: avatar, name, the role or "Team chat", the last message, when,
/// and the unread badge. Unread chats show the preview in ink and bold.
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
    final peer = c.peer;
    final unread = c.unreadCount > 0;
    final title = c.kind == ConversationKind.mentor && peer != null
        ? 'Mentor · ${peer.name}'
        : ConversationText.title(c);
    return Semantics(
      button: true,
      label: unread
          ? '$title, ${ConversationText.unread(c.unreadCount)} unread'
          : title,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.borderRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            spacing: 12,
            children: [
              ConversationAvatar(conversation: c),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 16,
                        fontWeight: _bold,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: peer == null
                          ? const QuietTag('Team chat')
                          : RoleChip(peer.role),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      ConversationText.preview(c, myUserId),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: unread ? AppColors.ink : AppColors.muted,
                        fontSize: 14,
                        fontWeight: unread ? _bold : FontWeight.w400,
                        height: 1.4,
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
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  if (unread)
                    CountBadge(ConversationText.unread(c.unreadCount)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
