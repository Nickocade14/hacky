import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models/conversations.dart';
import '../auth/error_text.dart';
import '../chats/chat_data.dart';
import '../routes.dart';
import '../shell/screen_load.dart';
import '../widgets/app_widgets.dart';
import '../widgets/conversation_widgets.dart';

/// 10 Conversations (Chats tab, mobile/design/messages-wireframes.svg).
///
/// Loads [ConversationsData] for [eventSlug]: my direct messages, team chats
/// and mentor help, newest activity first, with unread badges. Pull to
/// refresh. A row opens 11 with `Navigate.toChatThread` and the list reloads
/// on the way back (unread counts); Requests opens 09.
class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({
    super.key,
    required this.api,
    required this.eventSlug,
  });

  final ApiClient api;
  final String eventSlug;

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen>
    with ScreenLoad<ConversationsScreen> {
  ConversationsData? _data;

  @override
  void initState() {
    super.initState();
    runLoad(_load);
  }

  Future<void> _load() async {
    final data = await ConversationsData.load(widget.api, widget.eventSlug);
    if (mounted) setState(() => _data = data);
  }

  /// Pull to refresh, and coming back from 09 or 11: reloads without the
  /// spinner and keeps what's on screen if it fails.
  Future<void> _refresh() async {
    try {
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ErrorText.of(e))));
    }
  }

  Future<void> _openRequests() async {
    await Navigate.toRequests(context, eventSlug: widget.eventSlug);
    await _refresh();
  }

  Future<void> _openChat(ConversationSummary conversation) async {
    await Navigate.toChatThread(
      context,
      eventSlug: widget.eventSlug,
      conversationId: conversation.id,
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return SignedInPage(
      title: 'Chats',
      actions: [
        TextButton(onPressed: _openRequests, child: const Text('Requests')),
        const SizedBox(width: 8),
      ],
      body: switch ((data, problem)) {
        (null, final String message) => ProblemView(
          message: message,
          onRetry: () => runLoad(_load),
        ),
        (null, _) => const LoadingView(label: 'Loading your chats…'),
        (final ConversationsData loaded, _) => RefreshIndicator(
          onRefresh: _refresh,
          child: loaded.conversations.isEmpty
              ? const _NoChats()
              : _list(loaded),
        ),
      },
    );
  }

  Widget _list(ConversationsData data) {
    final now = DateTime.now();
    return PageColumn(
      children: [
        for (final c in data.conversations)
          ConversationRow(
            conversation: c,
            myUserId: data.myUserId,
            now: now,
            onTap: () => _openChat(c),
          ),
      ],
    );
  }
}

/// The empty state from the wireframe.
class _NoChats extends StatelessWidget {
  const _NoChats();

  @override
  Widget build(BuildContext context) {
    return const PageColumn(
      children: [
        MascotMessage(
          title: 'No chats yet',
          body: 'Accept a request or ask Hacky to find people.',
        ),
      ],
    );
  }
}
