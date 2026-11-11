// Sending a connection request from 12 Hacky chat: the intro form, the
// Connect sheet that people and team cards open, Hacky's drafted intro card,
// and the "Request sent" line that replaces them. Every send goes through
// HackyCardActions.sendRequest (`POST /api/events/{slug}/requests`).

import 'package:flutter/material.dart';

import '../api/models/people.dart';
import '../api/models/requests.dart';
import '../api/models/teams.dart';
import '../auth/submit_action.dart';
import '../hacky/hacky_card_actions.dart';
import '../theme.dart';
import 'app_widgets.dart';
import 'auth_widgets.dart';

const _bold = FontWeight.w700;

/// An editable intro and "Send request". Checks [IntroRules] as I type and
/// shows the server's error when the send fails.
class IntroComposer extends StatefulWidget {
  const IntroComposer({
    super.key,
    required this.initialIntro,
    required this.onSend,
  });

  static const fieldKey = Key('hacky-intro');

  final String initialIntro;
  final Future<void> Function(String intro) onSend;

  @override
  State<IntroComposer> createState() => _IntroComposerState();
}

class _IntroComposerState extends State<IntroComposer>
    with SubmitAction<IntroComposer> {
  late final _intro = TextEditingController(text: widget.initialIntro);

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  void _send() => runAction(() => widget.onSend(_intro.text.trim()));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _intro,
      builder: (context, _) {
        final problem = IntroRules.problem(_intro.text);
        final count = _intro.text.trim().length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            TextField(
              key: IntroComposer.fieldKey,
              controller: _intro,
              enabled: !busy,
              minLines: 3,
              maxLines: 6,
              maxLength: 600,
              decoration: const InputDecoration(
                labelText: 'Your intro',
                counterText: '',
                fillColor: AppColors.paper,
              ),
            ),
            if (error case final message?) Notice(message, error: true),
            Row(
              spacing: 12,
              children: [
                FilledButton(
                  onPressed: problem == null && !busy ? _send : null,
                  child: Text(busy ? 'Sending…' : 'Send request'),
                ),
                Expanded(
                  child: Text(
                    problem ?? (count > 400 ? '$count/500' : ''),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// The bottom sheet a card's Connect (or Ask to join) opens.
class ConnectSheet extends StatelessWidget {
  const ConnectSheet({
    super.key,
    required this.to,
    required this.team,
    required this.actions,
  });

  final PersonSummary to;

  /// Set for a request to join this team; [to] is its lead.
  final TeamRef? team;
  final HackyCardActions actions;

  /// Opens the sheet; returns the request once it's sent, or null.
  static Future<RequestResult?> show(
    BuildContext context, {
    required PersonSummary to,
    TeamRef? team,
    required HackyCardActions actions,
  }) => showModalBottomSheet<RequestResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.white,
    builder: (_) => ConnectSheet(to: to, team: team, actions: actions),
  );

  @override
  Widget build(BuildContext context) {
    final team = this.team;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          spacing: 14,
          children: [
            IntroHead(to: to, team: team),
            IntroComposer(
              initialIntro: IntroRules.opening(
                myName: actions.myName,
                to: to,
                team: team,
              ),
              onSend: (intro) async {
                final result = await actions.sendRequest(
                  SendRequestBody(
                    toUserId: to.userId,
                    intro: intro,
                    source: ConnectionSource.agent,
                    teamId: team?.id,
                  ),
                );
                if (context.mounted) Navigator.of(context).pop(result);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// "Intro to Leo Nguyen" with who gets it.
class IntroHead extends StatelessWidget {
  const IntroHead({super.key, required this.to, required this.team});

  final PersonSummary to;
  final TeamRef? team;

  @override
  Widget build(BuildContext context) {
    final team = this.team;
    return Row(
      spacing: 12,
      children: [
        PersonAvatar.of(to, size: 44),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Text(
                'Intro to ${team?.name ?? to.name}',
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 16,
                  fontWeight: _bold,
                ),
              ),
              Text(
                team == null
                    ? '@${to.handle}'
                    : 'Goes to ${IntroRules.firstName(to.name)}, the team lead',
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Hacky's drafted intro: I can edit it, then send it. Kept alive while it
/// scrolls out of view, so my edits stay.
class IntroDraftCard extends StatefulWidget {
  const IntroDraftCard({
    super.key,
    required this.to,
    required this.team,
    required this.intro,
    required this.source,
    required this.actions,
  });

  final PersonSummary to;
  final TeamRef? team;
  final String intro;
  final ConnectionSource source;
  final HackyCardActions actions;

  @override
  State<IntroDraftCard> createState() => _IntroDraftCardState();
}

class _IntroDraftCardState extends State<IntroDraftCard>
    with AutomaticKeepAliveClientMixin<IntroDraftCard> {
  @override
  bool get wantKeepAlive => true;

  Future<void> _send(String intro) async {
    await widget.actions.sendRequest(
      SendRequestBody(
        toUserId: widget.to.userId,
        intro: intro,
        source: widget.source,
        teamId: widget.team?.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final sent = widget.actions.sentRequest(widget.to.userId, widget.team?.id);
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          IntroHead(to: widget.to, team: widget.team),
          if (sent == null)
            IntroComposer(initialIntro: widget.intro, onSend: _send)
          else
            RequestStatusLine(
              result: sent,
              to: widget.to,
              actions: widget.actions,
            ),
        ],
      ),
    );
  }
}

/// Where a request I sent from this chat stands: sent, or connected with
/// "Open chat" (→ 11) when they had asked me first.
class RequestStatusLine extends StatelessWidget {
  const RequestStatusLine({
    super.key,
    required this.result,
    required this.to,
    required this.actions,
  });

  final RequestResult result;
  final PersonSummary to;
  final HackyCardActions actions;

  @override
  Widget build(BuildContext context) {
    final request = result.request;
    final conversationId = request.status == ConnectionStatus.accepted
        ? request.conversationId
        : null;
    return Semantics(
      liveRegion: true,
      child: Row(
        spacing: 6,
        children: [
          const Icon(Icons.check, color: AppColors.action, size: 18),
          Expanded(
            child: Text(
              conversationId != null
                  ? 'You’re connected with ${IntroRules.firstName(to.name)}'
                  : 'Request sent',
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 14,
                fontWeight: _bold,
              ),
            ),
          ),
          if (conversationId != null)
            TextButton(
              onPressed: () => actions.openChat(conversationId),
              child: const Text('Open chat'),
            ),
        ],
      ),
    );
  }
}
