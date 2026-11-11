import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../api/models/auth.dart';
import '../api/models/chat.dart';
import '../api/models/requests.dart';
import '../auth/error_text.dart';
import '../hacky/hacky_card_actions.dart';
import '../hacky/hacky_parts.dart';
import '../routes.dart';
import '../shell/screen_load.dart';
import '../widgets/app_widgets.dart';
import '../widgets/confirm_action_dialog.dart';
import '../widgets/hacky_cards.dart';
import '../widgets/hacky_chat_widgets.dart';

/// 12 Hacky chat, where the signed-in app opens. Laid out like the web's
/// Hacky pane (web/src/HackyPage.tsx).
///
/// Loads my history with Hacky (`GET /api/events/{slug}/chat`,
/// `ApiClient.getChatHistory`) and sends each message with `sendChat`
/// (`?format=json`: the whole answer at once, no streaming). The brief (the
/// clip, "What can I help you with?" and four starting points) opens the
/// chat and stays above the history. While Hacky answers, the thinking clip
/// shows and Send waits. A message that fails stays with Retry. Hacky's
/// cards open 07 (`Navigate.toPerson`) and send connection requests
/// (`sendRequest`). "New chat" clears what's on screen; Hacky keeps the
/// history.
class HackyChatScreen extends StatefulWidget {
  const HackyChatScreen({
    super.key,
    required this.api,
    required this.me,
    required this.eventSlug,
  });

  final ApiClient api;

  /// The signed-in user: their name goes in the intros Hacky's cards send.
  final Me me;
  final String eventSlug;

  @override
  State<HackyChatScreen> createState() => _HackyChatScreenState();
}

class _HackyChatScreenState extends State<HackyChatScreen>
    with ScreenLoad<HackyChatScreen> {
  final _messages = <ChatMessage>[];

  /// Why each of my messages that Hacky didn't get failed, by message id.
  final _failures = <String, String>{};
  final _sent = SentRequests();
  final _composer = TextEditingController();
  final _scroll = ScrollController();
  bool _thinking = false;
  int _nextId = 0;

  /// How many of the oldest messages "New chat" took off the screen.
  int _cleared = 0;

  /// The messages on screen, oldest first.
  Iterable<ChatMessage> get _shown => _messages.skip(_cleared);

  @override
  void initState() {
    super.initState();
    runLoad(_loadHistory);
    _restoreSent();
  }

  /// Marks the people I already asked or connected with, so their cards
  /// show where the request stands. If it fails the cards just offer
  /// Connect, and the server refuses a repeated request (409).
  Future<void> _restoreSent() async {
    try {
      final requests = await widget.api.listRequests(widget.eventSlug);
      if (mounted) setState(() => _sent.restore(requests));
    } catch (_) {
      // Nothing to show: the history itself reports a failed load.
    }
  }

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final history = await widget.api.getChatHistory(widget.eventSlug);
    if (!mounted) return;
    setState(() {
      _cleared = 0;
      _messages
        ..clear()
        ..addAll(history);
    });
  }

  /// "New chat": asks first, then clears the screen and keeps the history.
  Future<void> _startNew() async {
    final confirmed = await ConfirmActionDialog.show(
      context,
      title: 'Start a new chat?',
      message:
          'This clears the messages on this screen. Hacky keeps your '
          'history, profile and requests.',
      confirmLabel: 'Start new',
      busyLabel: 'Starting…',
      action: () async {},
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _cleared = _messages.length;
      _failures.clear();
    });
  }

  /// Sends [text] as my next message.
  void _ask(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _thinking) return;
    _composer.clear();
    _send(
      ChatMessage(
        // The AI SDK lets the client name its messages.
        id: 'mobile-${DateTime.now().microsecondsSinceEpoch}-${_nextId++}',
        role: ChatRole.user,
        parts: [
          {'type': 'text', 'text': trimmed},
        ],
      ),
    );
  }

  /// Sends a message that failed again; it moves to the end of the chat.
  void _retry(ChatMessage message) {
    if (_thinking) return;
    setState(() {
      _messages.remove(message);
      _failures.remove(message.id);
    });
    _send(message);
  }

  Future<void> _send(ChatMessage message) async {
    setState(() {
      _messages.add(message);
      _thinking = true;
    });
    _scrollToNewest();
    try {
      final answer = await widget.api.sendChat(
        widget.eventSlug,
        ChatBody(message: message),
      );
      if (mounted) setState(() => _messages.add(answer));
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        ScreenLoad.toLogin(context);
        return;
      }
      setState(() => _failures[message.id] = ErrorText.of(e));
    } catch (e) {
      if (mounted) setState(() => _failures[message.id] = ErrorText.of(e));
    } finally {
      if (mounted) setState(() => _thinking = false);
    }
    _scrollToNewest();
  }

  /// The thread is reversed, so the newest message sits at offset 0.
  void _scrollToNewest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<RequestResult> _sendRequest(SendRequestBody body) async {
    final result = await widget.api.sendRequest(widget.eventSlug, body);
    if (mounted) setState(() => _sent.remember(body, result));
    return result;
  }

  HackyCardActions get _actions => HackyCardActions(
    myName: widget.me.profile.name,
    busy: _thinking,
    openPerson: (handle) => Navigate.toPerson(
      context,
      eventSlug: widget.eventSlug,
      handle: handle,
    ),
    openChat: (id) => Navigate.toChatThread(
      context,
      eventSlug: widget.eventSlug,
      conversationId: id,
    ),
    ask: _ask,
    sendRequest: _sendRequest,
    sentRequest: _sent.find,
  );

  @override
  Widget build(BuildContext context) {
    final busy = _thinking || loading || problem != null;
    return SignedInPage(
      title: 'Hacky',
      headingInShell: false,
      body: Column(
        children: [
          NewChatButton(onPressed: busy || _shown.isEmpty ? null : _startNew),
          Expanded(child: _thread()),
          ChatComposer(controller: _composer, busy: busy, onSend: _ask),
        ],
      ),
    );
  }

  Widget _thread() {
    if (loading) return const LoadingView(label: 'Loading your chat…');
    if (problem case final message?) {
      return ProblemView(
        message: message,
        onRetry: () => runLoad(_loadHistory),
      );
    }
    final brief = HackyBrief(
      key: const ValueKey('brief'),
      onPick: _thinking ? null : _ask,
    );
    if (_shown.isEmpty) {
      // Nothing said yet: the brief sits in the middle of the page.
      return LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (box.maxHeight - 16).clamp(0.0, double.infinity).toDouble(),
            ),
            child: Center(child: brief),
          ),
        ),
      );
    }
    final rows = _rows(brief);
    return Semantics(
      label: 'Conversation with Hacky',
      child: ListView.separated(
        controller: _scroll,
        reverse: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: rows.length,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        // Reversed: index 0 is the newest row.
        itemBuilder: (_, index) => rows[rows.length - 1 - index],
      ),
    );
  }

  /// The thread, oldest first: the brief, each message on screen, and the
  /// thinking row while Hacky answers.
  List<Widget> _rows(Widget brief) {
    final actions = _actions;
    final last = _messages.last;
    return [
      Padding(padding: const EdgeInsets.only(bottom: 8), child: brief),
      for (final message in _shown) ?_row(message, actions, message == last),
      if (_thinking) const ThinkingRow(key: ValueKey('thinking')),
    ];
  }

  Widget? _row(ChatMessage message, HackyCardActions actions, bool latest) {
    final key = ValueKey(message.id);
    switch (message.role) {
      case ChatRole.user:
        final text = HackyParts.textOf(message);
        if (text.isEmpty) return null;
        final failure = _failures[message.id];
        return Column(
          key: key,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 4,
          children: [
            UserBubble(text: text, failed: failure != null),
            if (failure != null)
              SendFailedNote(
                message: failure,
                onRetry: _thinking ? null : () => _retry(message),
              ),
          ],
        );
      case ChatRole.assistant:
        final parts = HackyParts.of(message);
        if (parts.isEmpty) return null;
        return HackyTurn(
          key: key,
          children: [
            for (final part in parts)
              HackyPartView(
                part: part,
                actions: actions,
                latest: latest && !_thinking,
              ),
          ],
        );
      case ChatRole.system:
        return null;
    }
  }
}
