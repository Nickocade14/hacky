import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../api/models/conversations.dart';
import '../api/models/people.dart';
import '../auth/error_text.dart';
import '../chats/chat_data.dart';
import '../chats/client_id.dart';
import '../chats/conversation_text.dart';
import '../chats/thread_messages.dart';
import '../people/block_person.dart';
import '../routes.dart';
import '../shell/screen_load.dart';
import '../widgets/app_widgets.dart';
import '../widgets/confirm_action_dialog.dart';
import '../widgets/thread_widgets.dart';

/// 11 Chat thread (pushed from 07, 09 and 10,
/// mobile/design/messages-wireframes.svg). Opened with
/// `Navigate.toChatThread`.
///
/// Loads [ChatThreadData]: the newest page of messages (oldest first, mine on
/// the right), and the header from the event's conversations. Scrolling up
/// loads older pages (`listMessages` with `before`). Send shows my message
/// right away with "Sending…" (`sendMessage` with a clientId); a failed one
/// shows the error with Retry, which reuses the clientId. Opening the chat
/// marks it read (`markRead`); "Seen" comes from the peer's last read time.
///
/// There are no live updates yet (Socket.IO): while the screen is open it
/// asks for new messages every [pollInterval] (`listMessages` with `after`).
/// The header and ••• → View profile open 07.
///
/// Long-press on my message → Unsend for everyone: a confirm step, then
/// `deleteMessage`; the message leaves the thread (the contract deletes it,
/// and a 404 means it's already gone). In a DM, ••• → Block confirms, calls
/// `blockUser` and goes back with a snackbar ([BlockPerson]).
class ChatThreadScreen extends StatefulWidget {
  const ChatThreadScreen({
    super.key,
    required this.api,
    required this.eventSlug,
    required this.conversationId,
    this.pollInterval = const Duration(seconds: 3),
  });

  final ApiClient api;
  final String eventSlug;
  final String conversationId;
  final Duration pollInterval;

  static const menuKey = Key('thread-menu');
  static const unsentNote = 'Message unsent.';

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen>
    with ScreenLoad<ChatThreadScreen> {
  final _composer = TextEditingController();
  final _scroll = ScrollController();

  String _myUserId = '';
  ConversationSummary? _conversation;
  ThreadMessages? _thread;

  bool _loadingOlder = false;
  String? _olderProblem;
  bool _sending = false;
  bool _polling = false;
  Timer? _pollTimer;

  /// Older pages load when the top of the feed is this close.
  static const _olderEdge = 300.0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    runLoad(_load);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _scroll.dispose();
    _composer.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await ChatThreadData.load(
      widget.api,
      widget.eventSlug,
      widget.conversationId,
    );
    if (!mounted) return;
    setState(() {
      _myUserId = data.myUserId;
      _conversation = data.conversation;
      _thread = ThreadMessages(data.newest);
    });
    _markRead();
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(widget.pollInterval, (_) => _poll());
  }

  /// Read receipts are extra: a failure leaves the unread count as it was.
  Future<void> _markRead() async {
    try {
      await widget.api.markRead(widget.conversationId);
    } catch (_) {
      // The next open or refresh marks it read.
    }
  }

  /// New messages and "Seen". A failed refresh waits for the next tick.
  Future<void> _poll() async {
    final thread = _thread;
    if (thread == null || _polling) return;
    _polling = true;
    try {
      final results = await Future.wait<Object>([
        widget.api.listMessages(
          widget.conversationId,
          after: thread.syncedId,
          limit: 100,
        ),
        widget.api.listConversations(widget.eventSlug),
      ]);
      if (!mounted) return;
      var fromOthers = false;
      setState(() {
        final added = thread.addNewer(results[0] as MessagePage);
        fromOthers = added.any((m) => m.senderId != _myUserId);
        _conversation =
            ChatThreadData.find(
              results[1] as List<ConversationSummary>,
              widget.conversationId,
            ) ??
            _conversation;
      });
      if (fromOthers) _markRead();
    } catch (_) {
      // Tried again on the next tick.
    } finally {
      _polling = false;
    }
  }

  void _onScroll() {
    final position = _scroll.position;
    // The feed is reversed: its top is the end of the scroll.
    if (_olderProblem == null &&
        position.pixels >= position.maxScrollExtent - _olderEdge) {
      _loadOlder();
    }
  }

  Future<void> _loadOlder() async {
    final thread = _thread;
    if (thread == null || !thread.hasMore || _loadingOlder) return;
    setState(() {
      _loadingOlder = true;
      _olderProblem = null;
    });
    try {
      final page = await widget.api.listMessages(
        widget.conversationId,
        before: thread.oldestId,
      );
      if (mounted) setState(() => thread.addOlder(page));
    } catch (e) {
      if (mounted) setState(() => _olderProblem = ErrorText.of(e));
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  void _send() {
    final thread = _thread;
    final text = _composer.text.trim();
    if (thread == null || text.isEmpty || _sending) return;
    final message = thread.write(ClientId.next(), text);
    _composer.clear();
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _deliver(message);
  }

  /// Sends [message], the first time or on Retry (same clientId).
  Future<void> _deliver(PendingMessage message) async {
    final thread = _thread!;
    setState(() {
      _sending = true;
      thread.retrying(message.clientId);
    });
    try {
      final saved = await widget.api.sendMessage(
        widget.conversationId,
        SendMessageBody(clientId: message.clientId, body: message.body),
      );
      if (mounted) setState(() => thread.sent(saved));
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        ScreenLoad.toLogin(context);
      } else {
        setState(() => thread.failed(message.clientId, ErrorText.of(e)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => thread.failed(message.clientId, ErrorText.of(e)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _discard(PendingMessage message) =>
      setState(() => _thread?.discard(message.clientId));

  Future<void> _openProfile() async {
    final handle = _conversation?.peer?.handle;
    if (handle == null) return;
    await Navigate.toPerson(
      context,
      eventSlug: widget.eventSlug,
      handle: handle,
    );
  }

  /// Long-press → Unsend for everyone → confirm → `deleteMessage`.
  Future<void> _unsend(Message message) async {
    if (!await UnsendSheet.show(context) || !mounted) return;
    final unsent = await ConfirmActionDialog.show(
      context,
      title: 'Unsend this message?',
      message: 'It’s removed for everyone in this chat. This can’t be undone.',
      confirmLabel: 'Unsend',
      busyLabel: 'Unsending…',
      action: () => _deleteMessage(message.id),
    );
    if (!unsent || !mounted) return;
    setState(() => _thread?.remove(message.id));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text(ChatThreadScreen.unsentNote)),
      );
  }

  /// A 404 means it's already gone, which is what I asked for.
  Future<void> _deleteMessage(String messageId) async {
    try {
      await widget.api.deleteMessage(widget.conversationId, messageId);
    } on ApiException catch (e) {
      if (e.statusCode != 404) rethrow;
    }
  }

  Future<void> _block(PersonSummary peer) => BlockPerson.confirmAndLeave(
    context,
    api: widget.api,
    userId: peer.userId,
    name: peer.name,
  );

  @override
  Widget build(BuildContext context) {
    final peer = _conversation?.peer;
    final isDm = _conversation?.kind == ConversationKind.dm;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: ChatThreadHeader(
          conversation: _conversation,
          onOpenProfile: peer == null ? null : _openProfile,
        ),
        actions: [
          if (peer != null)
            _ThreadMenu(
              onViewProfile: _openProfile,
              onBlock: isDm ? () => _block(peer) : null,
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: switch ((_thread, problem)) {
          (null, final String message) => ProblemView(
            message: message,
            onRetry: () => runLoad(_load),
          ),
          (null, _) => const LoadingView(label: 'Loading messages…'),
          (final ThreadMessages thread, _) => Column(
            children: [
              Expanded(
                child: thread.isEmpty ? _emptyThread() : _feed(thread),
              ),
              ChatComposer(
                controller: _composer,
                busy: _sending,
                onSend: _send,
              ),
            ],
          ),
        },
      ),
    );
  }

  Widget _emptyThread() {
    final mentor = _conversation?.kind == ConversationKind.mentor;
    return PageColumn(
      children: [
        MascotMessage(
          title: 'No messages yet',
          body: mentor
              ? 'Say where you’re stuck and what you’ve tried.'
              : 'Say hi and share what you’re building.',
        ),
      ],
    );
  }

  Widget _feed(ThreadMessages thread) {
    final rows = _rows(thread);
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      itemCount: rows.length,
      itemBuilder: (_, index) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: rows[rows.length - 1 - index],
      ),
    );
  }

  /// Oldest first: the older-messages bar, the saved messages, then mine
  /// that aren't saved yet.
  List<Widget> _rows(ThreadMessages thread) {
    final seen = _seenMessageId(thread);
    return [
      if (thread.hasMore)
        OlderMessagesBar(
          loading: _loadingOlder,
          problem: _olderProblem,
          onLoad: _loadOlder,
        ),
      for (final m in thread.saved)
        if (m.kind == MessageKind.system)
          SystemNote(m.body, key: ValueKey(m.id))
        else
          MessageBubble(
            // Keeps the widget of my instant copy when the saved one lands.
            key: ValueKey(m.clientId ?? m.id),
            text: ConversationText.body(m),
            mine: m.senderId == _myUserId,
            below: m.id == seen ? const BubbleNote('Seen') : null,
            onLongPress: m.senderId == _myUserId ? () => _unsend(m) : null,
          ),
      for (final p in thread.pending)
        PendingBubble(
          key: ValueKey(p.clientId),
          message: p,
          onRetry: _sending ? null : () => _deliver(p),
          onDiscard: () => _discard(p),
        ),
    ];
  }

  /// My newest saved message, if the peer has read it. Not in team chats.
  String? _seenMessageId(ThreadMessages thread) {
    final readAt = _conversation?.peerLastReadAt;
    if (readAt == null || _conversation?.kind == ConversationKind.team) {
      return null;
    }
    final mine = thread.lastSavedFrom(_myUserId);
    if (mine == null || readAt.isBefore(mine.createdAt)) return null;
    return mine.id;
  }
}

/// ••• on 11: View profile, and Block in a DM.
class _ThreadMenu extends StatelessWidget {
  const _ThreadMenu({required this.onViewProfile, required this.onBlock});

  final VoidCallback onViewProfile;

  /// Null outside DMs.
  final VoidCallback? onBlock;

  @override
  Widget build(BuildContext context) {
    final onBlock = this.onBlock;
    return PopupMenuButton<VoidCallback>(
      key: ChatThreadScreen.menuKey,
      tooltip: 'More',
      icon: const Icon(Icons.more_horiz),
      // Runs after the menu closed, so a pushed page or dialog lands on top.
      onSelected: (action) => action(),
      itemBuilder: (_) => [
        PopupMenuItem<VoidCallback>(
          value: onViewProfile,
          child: const Text('View profile'),
        ),
        if (onBlock != null)
          PopupMenuItem<VoidCallback>(
            value: onBlock,
            child: const Text(BlockPerson.menuLabel),
          ),
      ],
    );
  }
}
