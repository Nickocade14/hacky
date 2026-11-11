import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../api/models/requests.dart';
import '../auth/error_text.dart';
import '../chats/chat_data.dart';
import '../requests/request_lists.dart';
import '../routes.dart';
import '../shell/screen_load.dart';
import '../theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/conversation_widgets.dart';

/// 10 Chats, laid out like the web's Chats panel
/// (web/src/workspace/Sidebar.tsx).
///
/// Loads [ConversationsData] for [eventSlug]: my event, the requests waiting
/// on me (Accept, Not now) or on them (Pending), and my direct messages,
/// team chats and mentor help, newest activity first, with unread badges.
/// It reloads by itself every [refreshEvery] and on pull to refresh, and
/// tells the shell how much is waiting ([onWaitingChanged]) for the dot on
/// the header. A row opens 11 with `Navigate.toChatThread`; See all opens 09.
class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({
    super.key,
    required this.api,
    required this.eventSlug,
    this.onWaitingChanged,
    this.refreshEvery = const Duration(seconds: 5),
  });

  final ApiClient api;
  final String eventSlug;

  /// Called after each load with [ConversationsData.waiting].
  final ValueChanged<int>? onWaitingChanged;

  /// How often the list reloads while the screen exists.
  final Duration refreshEvery;

  static const seeAllKey = Key('chats-see-all-requests');

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen>
    with ScreenLoad<ConversationsScreen> {
  ConversationsData? _data;
  Timer? _timer;

  /// A load is on its way; the timer skips its turn.
  bool _reloading = false;

  /// Requests with Accept or Not now on its way.
  final _busy = <String>{};

  @override
  void initState() {
    super.initState();
    runLoad(_load);
    _timer = Timer.periodic(widget.refreshEvery, (_) => _refresh(quiet: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    _reloading = true;
    try {
      final data = await ConversationsData.load(widget.api, widget.eventSlug);
      if (!mounted) return;
      setState(() => _data = data);
      widget.onWaitingChanged?.call(data.waiting);
    } finally {
      _reloading = false;
    }
  }

  /// The timer, pull to refresh, and coming back from 09 or 11: reloads
  /// without the spinner and keeps what's on screen if it fails. [quiet]
  /// (the timer) doesn't mention a failure either.
  Future<void> _refresh({bool quiet = false}) async {
    if (quiet && (_reloading || !mounted)) return;
    try {
      await _load();
    } catch (e) {
      if (!mounted) return;
      if (e is ApiException && e.statusCode == 401) {
        _timer?.cancel();
        ScreenLoad.toLogin(context);
      } else if (!quiet) {
        _say(ErrorText.of(e));
      }
    }
  }

  void _say(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _openRequests() async {
    await Navigate.toRequests(context, eventSlug: widget.eventSlug);
    await _refresh();
  }

  Future<void> _openChat(String conversationId) async {
    await Navigate.toChatThread(
      context,
      eventSlug: widget.eventSlug,
      conversationId: conversationId,
    );
    await _refresh();
  }

  Future<void> _openPerson(String handle) async {
    await Navigate.toPerson(
      context,
      eventSlug: widget.eventSlug,
      handle: handle,
    );
    await _refresh();
  }

  /// Runs Accept or Not now on [request], once at a time per request. False
  /// when it failed (the error shows in a snackbar) or was already running.
  Future<bool> _act(ConnectionRequest request, Future<void> Function() call) async {
    if (_busy.contains(request.id)) return false;
    setState(() => _busy.add(request.id));
    try {
      await call();
      return true;
    } catch (e) {
      if (!mounted) return false;
      if (e is ApiException && e.statusCode == 401) {
        ScreenLoad.toLogin(context);
      } else {
        _say(ErrorText.of(e));
        // Gone or already answered somewhere else: show what's true now.
        unawaited(_refresh(quiet: true));
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy.remove(request.id));
    }
  }

  Future<void> _accept(ConnectionRequest request) async {
    String? conversationId;
    final accepted = await _act(request, () async {
      final result = await widget.api.acceptRequest(request.id);
      conversationId = result.request.conversationId;
    });
    if (!accepted || !mounted) return;
    final id = conversationId;
    if (id == null) {
      _say('You and ${request.person.name} are connected.');
      await _refresh();
    } else {
      await _openChat(id);
    }
  }

  Future<void> _hide(ConnectionRequest request) async {
    final hidden = await _act(
      request,
      () => widget.api.hideRequest(request.id),
    );
    if (!hidden || !mounted) return;
    _say('Hidden. ${request.person.name} isn’t told.');
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return SignedInPage(
      title: 'Chats',
      body: switch ((data, problem)) {
        (null, final String message) => ProblemView(
          message: message,
          onRetry: () => runLoad(_load),
        ),
        (null, _) => const LoadingView(label: 'Loading your chats…'),
        (final ConversationsData loaded, _) => RefreshIndicator(
          onRefresh: _refresh,
          child: _content(loaded),
        ),
      },
    );
  }

  Widget _content(ConversationsData data) {
    final now = DateTime.now();
    final event = data.event;
    final requests = RequestLists.from(data.requests);
    final waiting = [...requests.incoming, ...requests.outgoing];
    final hidden = requests.hidden.length;
    return PageColumn(
      children: [
        if (event != null) EventBadge(event: event),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(child: SectionLabel('Requests')),
                TextButton(
                  key: ConversationsScreen.seeAllKey,
                  onPressed: _openRequests,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.muted,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(
                    hidden > 0 ? 'See all · $hidden hidden' : 'See all',
                  ),
                ),
              ],
            ),
            if (waiting.isEmpty)
              const _QuietLine(
                'Nothing waiting. Ask Hacky to find someone and send a '
                'request.',
              )
            else
              for (final request in waiting)
                InboxRequestRow(
                  key: InboxRequestRow.keyOf(request.id),
                  request: request,
                  busy: _busy.contains(request.id),
                  onOpenPerson: () => _openPerson(request.person.handle),
                  onAccept: () => _accept(request),
                  onHide: () => _hide(request),
                ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: SectionLabel('Chats'),
            ),
            if (data.conversations.isEmpty)
              const _NoChats()
            else
              for (final c in data.conversations)
                ConversationRow(
                  conversation: c,
                  myUserId: data.myUserId,
                  now: now,
                  onTap: () => _openChat(c.id),
                ),
          ],
        ),
      ],
    );
  }
}

/// A muted line where a block has nothing to show.
class _QuietLine extends StatelessWidget {
  const _QuietLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.muted,
          fontSize: 14,
          height: 1.6,
        ),
      ),
    );
  }
}

/// The empty state from the wireframe.
class _NoChats extends StatelessWidget {
  const _NoChats();

  @override
  Widget build(BuildContext context) {
    return const MascotMessage(
      title: 'No chats yet',
      body: 'Accept a request or ask Hacky to find people.',
    );
  }
}
