// The parts of 11 Chat thread (mobile/design/messages-wireframes.svg), in the
// original Hacky look (react/src/social/Thread.jsx, social.css,
// public/app/hacky.css): my bubbles on the right in the action blue, theirs on
// the left in white, system notes centered on a grey wash. Colors and fonts
// come from lib/theme.dart.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/models/conversations.dart';
import '../chats/conversation_text.dart';
import '../chats/thread_messages.dart';
import '../theme.dart';
import 'conversation_widgets.dart';

const _bold = FontWeight.w700;

/// The title of 11: avatar, name and a muted line (role, "Team chat" or the
/// help request). Tapping it opens the person's profile (→ 07) when
/// [onOpenProfile] is set.
class ChatThreadHeader extends StatelessWidget {
  const ChatThreadHeader({
    super.key,
    required this.conversation,
    this.onOpenProfile,
  });

  /// Null while it isn't known (the chat left the list).
  final ConversationSummary? conversation;
  final VoidCallback? onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    if (c == null) return const Text('Chat');
    final subtitle = ConversationText.subtitle(c);
    return Semantics(
      button: onOpenProfile != null,
      child: InkWell(
        onTap: onOpenProfile,
        borderRadius: AppTheme.borderRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            spacing: 10,
            children: [
              ConversationAvatar(conversation: c, size: 34),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ConversationText.title(c),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 16,
                        fontWeight: _bold,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A system message ("You and Priya are connected. Say hi!"), centered.
class SystemNote extends StatelessWidget {
  const SystemNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.wash,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 12,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

/// One message bubble, with an optional line under it ("Seen", "Sending…",
/// or a failed note with Retry).
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.text,
    required this.mine,
    this.faded = false,
    this.below,
    this.onLongPress,
  });

  final String text;

  /// Mine go on the right in blue; theirs on the left in white.
  final bool mine;

  /// Not saved yet (sending or failed).
  final bool faded;
  final Widget? below;

  /// Long-press on my saved message: Unsend.
  final VoidCallback? onLongPress;

  static const _radius = Radius.circular(20);
  static const _tail = Radius.circular(6);

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: mine ? AppColors.action : AppColors.white,
        border: mine ? null : Border.all(color: AppColors.line),
        borderRadius: BorderRadius.only(
          topLeft: _radius,
          topRight: _radius,
          bottomLeft: mine ? _radius : _tail,
          bottomRight: mine ? _tail : _radius,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: mine ? AppColors.onAction : AppColors.ink,
          fontSize: 15,
          height: 1.45,
        ),
      ),
    );
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: 0.8,
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: mine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          spacing: 4,
          children: [
            GestureDetector(
              onLongPress: onLongPress,
              child: Opacity(opacity: faded ? 0.65 : 1, child: bubble),
            ),
            ?below,
          ],
        ),
      ),
    );
  }
}

/// What a long-press on my message offers: "Unsend for everyone". Closes
/// with true when it was picked.
class UnsendSheet extends StatelessWidget {
  const UnsendSheet({super.key});

  static const label = 'Unsend for everyone';

  static Future<bool> show(BuildContext context) async {
    final picked = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (_) => const UnsendSheet(),
    );
    return picked ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: const Icon(Icons.undo, color: AppColors.danger),
          title: const Text(
            label,
            style: TextStyle(color: AppColors.danger, fontWeight: _bold),
          ),
          subtitle: const Text('It’s removed for everyone in this chat.'),
          onTap: () => Navigator.of(context).pop(true),
        ),
      ),
    );
  }
}

/// A muted line under a bubble ("Seen", "Sending…").
class BubbleNote extends StatelessWidget {
  const BubbleNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: AppColors.muted, fontSize: 12),
    );
  }
}

/// My message before the server saved it: "Sending…", or the error with
/// Retry and Remove.
class PendingBubble extends StatelessWidget {
  const PendingBubble({
    super.key,
    required this.message,
    required this.onRetry,
    required this.onDiscard,
  });

  final PendingMessage message;

  /// Null while another message is sending.
  final VoidCallback? onRetry;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final failed = message.state == PendingState.failed;
    return MessageBubble(
      text: message.body,
      mine: true,
      faded: true,
      below: failed
          ? _FailedNote(
              error: message.error ?? 'Not sent.',
              onRetry: onRetry,
              onDiscard: onDiscard,
            )
          : const BubbleNote('Sending…'),
    );
  }
}

class _FailedNote extends StatelessWidget {
  const _FailedNote({
    required this.error,
    required this.onRetry,
    required this.onDiscard,
  });

  final String error;
  final VoidCallback? onRetry;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'Not sent. $error',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppColors.danger,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(onPressed: onRetry, child: const Text('Retry')),
              TextButton(onPressed: onDiscard, child: const Text('Remove')),
            ],
          ),
        ],
      ),
    );
  }
}

/// The top of the feed while older messages are on the server: a button
/// (scrolling up also loads them), a spinner, or the error with Try again.
class OlderMessagesBar extends StatelessWidget {
  const OlderMessagesBar({
    super.key,
    required this.loading,
    required this.problem,
    required this.onLoad,
  });

  final bool loading;
  final String? problem;
  final VoidCallback onLoad;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 10,
            children: [
              SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              BubbleNote('Loading earlier messages…'),
            ],
          ),
        ),
      );
    }
    final problem = this.problem;
    return Column(
      children: [
        if (problem != null)
          Text(
            problem,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.danger, fontSize: 13),
          ),
        TextButton(
          onPressed: onLoad,
          child: Text(problem == null ? 'Load earlier messages' : 'Try again'),
        ),
      ],
    );
  }
}

/// "Message…" and the send button, which shows a spinner while [busy].
class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.busy,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSend;

  static const fieldKey = Key('chat-composer');
  static const sendKey = Key('chat-send');

  /// `SendMessageBody.body` is 1 to 4000 characters.
  static const maxLength = 4000;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: 8,
        children: [
          Expanded(
            child: TextField(
              key: fieldKey,
              controller: controller,
              minLines: 1,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [
                LengthLimitingTextInputFormatter(maxLength),
              ],
              decoration: const InputDecoration(
                hintText: 'Message…',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final canSend = !busy && value.text.trim().isNotEmpty;
              return IconButton.filled(
                key: sendKey,
                tooltip: busy ? 'Sending' : 'Send',
                onPressed: canSend ? onSend : null,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.disabledInk,
                        ),
                      )
                    : const Icon(Icons.arrow_upward),
              );
            },
          ),
        ],
      ),
    );
  }
}
