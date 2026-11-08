import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../api/models/requests.dart';
import '../auth/error_text.dart';
import '../requests/request_lists.dart';
import '../routes.dart';
import '../shell/screen_load.dart';
import '../widgets/app_widgets.dart';
import '../widgets/request_cards.dart';

/// 09 Requests (pushed from 05 and 10, mobile/design/requests-wireframes.svg).
/// Opened with `Navigate.toRequests`.
///
/// Loads `GET /api/events/{slug}/requests` (`ApiClient.listRequests`) into
/// Incoming and Outgoing tabs ([RequestLists]). Accept → `acceptRequest`,
/// then the chat opens (`Navigate.toChatThread`); Not now → `hideRequest`
/// (the sender isn't told). A person's name opens 07 (`Navigate.toPerson`).
/// Home counts the same incoming requests for its "N new" badge and reloads
/// when the user comes back.
class RequestsScreen extends StatefulWidget {
  const RequestsScreen({
    super.key,
    required this.api,
    required this.eventSlug,
  });

  final ApiClient api;
  final String eventSlug;

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen>
    with ScreenLoad<RequestsScreen> {
  List<ConnectionRequest>? _requests;

  /// Requests with an Accept or Not now still on its way.
  final _busy = <String>{};

  @override
  void initState() {
    super.initState();
    runLoad(_load);
  }

  Future<void> _load() async {
    final requests = await widget.api.listRequests(widget.eventSlug);
    if (mounted) setState(() => _requests = requests);
  }

  /// Pull to refresh, and coming back from 07 or 11: reloads without the
  /// spinner and keeps what's on screen if it fails.
  Future<void> _refresh() async {
    try {
      await _load();
    } catch (e) {
      _showProblem(e);
    }
  }

  void _say(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _showProblem(Object error) {
    if (!mounted) return;
    if (error is ApiException && error.statusCode == 401) {
      ScreenLoad.toLogin(context);
      return;
    }
    _say(ErrorText.of(error));
  }

  /// Runs one action on request [id], at most one at a time per request.
  /// Returns null if it was already running or failed (the error shows in a
  /// snackbar). A request that is gone or changed (404, 409) reloads the list.
  Future<T?> _run<T extends Object>(String id, Future<T> Function() call) async {
    if (_busy.contains(id)) return null;
    setState(() => _busy.add(id));
    try {
      return await call();
    } catch (e) {
      _showProblem(e);
      if (e is ApiException && (e.statusCode == 404 || e.statusCode == 409)) {
        unawaited(_refresh());
      }
      return null;
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _accept(ConnectionRequest request) async {
    final result = await _run(
      request.id,
      () => widget.api.acceptRequest(request.id),
    );
    if (result == null || !mounted) return;
    final accepted = result.request;
    setState(() => _requests = _requests!.replacing(accepted));
    final conversationId = accepted.conversationId;
    if (conversationId == null) {
      _say('You and ${accepted.person.name} are connected.');
      return;
    }
    await _openChat(conversationId);
  }

  Future<void> _hide(ConnectionRequest request) async {
    final hidden = await _run(request.id, () async {
      await widget.api.hideRequest(request.id);
      return request.hiddenOn(DateTime.now().toUtc());
    });
    if (hidden == null || !mounted) return;
    setState(() => _requests = _requests!.replacing(hidden));
    _say('Hidden. ${request.person.name} isn’t told.');
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

  @override
  Widget build(BuildContext context) {
    return SignedInPage(
      title: 'Requests',
      body: switch ((_requests, problem)) {
        (null, final String message) => ProblemView(
          message: message,
          onRetry: () => runLoad(_load),
        ),
        (null, _) => const LoadingView(label: 'Loading your requests…'),
        (final List<ConnectionRequest> loaded, _) => _tabs(
          RequestLists.from(loaded),
        ),
      },
    );
  }

  Widget _tabs(RequestLists lists) {
    final now = DateTime.now().toUtc();
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          RequestsTabBar(
            incomingCount: lists.incoming.length,
            outgoingCount: lists.outgoing.length,
          ),
          Expanded(
            child: TabBarView(
              children: [
                _tab(_incoming(lists, now)),
                _tab(_outgoing(lists, now)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tab(List<Widget> children) => RefreshIndicator(
    onRefresh: _refresh,
    child: PageColumn(children: children),
  );

  List<Widget> _incoming(RequestLists lists, DateTime now) {
    if (lists.incomingTabEmpty) {
      return const [
        MascotMessage(
          title: 'No requests yet',
          body: 'When someone wants to team up, their request shows up '
              'here. Ask Hacky to find people for you.',
        ),
      ];
    }
    return [
      if (lists.incoming.isEmpty)
        const RequestsNote('No new requests right now.')
      else
        for (final r in lists.incoming) _card(r, now),
      if (lists.hidden.isNotEmpty)
        HiddenRequestsSection(
          children: [for (final r in lists.hidden) _card(r, now)],
        ),
      if (lists.acceptedIncoming.isNotEmpty) ...[
        const SectionLabel('Accepted'),
        for (final r in lists.acceptedIncoming) _card(r, now),
      ],
    ];
  }

  List<Widget> _outgoing(RequestLists lists, DateTime now) {
    if (lists.outgoingTabEmpty) {
      return const [
        MascotMessage(
          title: 'You haven’t sent any requests',
          body: 'Find someone on People or ask Hacky, then send them a '
              'request. It waits here until they answer.',
        ),
      ];
    }
    return [
      if (lists.outgoing.isEmpty)
        const RequestsNote('Nothing waiting for an answer.')
      else
        for (final r in lists.outgoing) _card(r, now),
      if (lists.acceptedOutgoing.isNotEmpty) ...[
        const SectionLabel('Accepted'),
        for (final r in lists.acceptedOutgoing) _card(r, now),
      ],
    ];
  }

  /// A card with the buttons that apply: Accept and Not now on incoming
  /// pending requests (only Accept once hidden), Message once accepted, none
  /// on my own pending ones.
  Widget _card(ConnectionRequest r, DateTime now) {
    final waitingForMe =
        r.direction == RequestDirection.incoming &&
        r.status == ConnectionStatus.pending;
    final conversationId = r.conversationId;
    return RequestCard(
      key: RequestCard.keyOf(r.id),
      request: r,
      now: now,
      busy: _busy.contains(r.id),
      onOpenPerson: () => _openPerson(r.person.handle),
      onAccept: waitingForMe ? () => _accept(r) : null,
      onHide: waitingForMe && r.hiddenAt == null ? () => _hide(r) : null,
      onMessage:
          r.status == ConnectionStatus.accepted && conversationId != null
          ? () => _openChat(conversationId)
          : null,
    );
  }
}
