// The pieces of 09 Requests (mobile/design/requests-wireframes.svg), in the
// original Hacky look (react/src/social/Lists.jsx RequestRow, social.css):
// a card per request with who sent it, tags, the intro and its buttons.

import 'package:flutter/material.dart';

import '../api/models/people.dart';
import '../api/models/requests.dart';
import '../requests/request_lists.dart';
import '../theme.dart';
import 'app_widgets.dart';

const _bold = FontWeight.w700;

/// The Incoming / Outgoing switch with each tab's count. Drives the
/// surrounding [DefaultTabController].
class RequestsTabBar extends StatelessWidget {
  const RequestsTabBar({
    super.key,
    required this.incomingCount,
    required this.outgoingCount,
  });

  final int incomingCount;
  final int outgoingCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.wash,
              borderRadius: AppTheme.borderRadius,
            ),
            child: TabBar(
              tabs: [
                Tab(height: 38, text: 'Incoming ($incomingCount)'),
                Tab(height: 38, text: 'Outgoing ($outgoingCount)'),
              ],
              indicator: BoxDecoration(
                color: AppColors.white,
                borderRadius: AppTheme.borderRadius,
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 5,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerHeight: 0,
              splashBorderRadius: AppTheme.borderRadius,
              labelColor: AppColors.ink,
              unselectedLabelColor: AppColors.muted,
              labelStyle: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 13,
                fontWeight: _bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One request: who, its tags, the intro and the buttons that apply.
/// A button shows only when its callback is set. While [busy], every button
/// is disabled so a second tap does nothing.
class RequestCard extends StatelessWidget {
  const RequestCard({
    super.key,
    required this.request,
    required this.now,
    required this.onOpenPerson,
    this.busy = false,
    this.onAccept,
    this.onHide,
    this.onMessage,
  });

  /// The key of the card for request [id], for tests.
  static Key keyOf(String id) => ValueKey('request-$id');

  final ConnectionRequest request;

  /// For "2 h ago".
  final DateTime now;

  /// Opens the person's profile (→ 07).
  final VoidCallback onOpenPerson;
  final bool busy;
  final VoidCallback? onAccept;

  /// "Not now".
  final VoidCallback? onHide;

  /// Opens the chat of an accepted request (→ 11).
  final VoidCallback? onMessage;

  bool get _hasActions => onAccept != null || onHide != null || onMessage != null;

  @override
  Widget build(BuildContext context) {
    final team = RequestTexts.team(request);
    final intro = request.intro.trim();
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          RequestSender(
            person: request.person,
            subtitle: RequestTexts.subtitle(request, now),
            onTap: onOpenPerson,
          ),
          RequestTags(request: request),
          if (team != null)
            Text(
              team,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 14,
                fontWeight: _bold,
              ),
            ),
          if (intro.isNotEmpty)
            Text(
              '“$intro”',
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          if (_hasActions)
            RequestActions(
              busy: busy,
              onAccept: onAccept,
              onHide: onHide,
              onMessage: onMessage,
            ),
        ],
      ),
    );
  }
}

/// Avatar, name and the muted line. Tapping it opens the person's profile.
class RequestSender extends StatelessWidget {
  const RequestSender({
    super.key,
    required this.person,
    required this.subtitle,
    required this.onTap,
  });

  final PersonSummary person;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'View ${person.name}’s profile',
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.borderRadius,
        child: Row(
          spacing: 12,
          children: [
            PersonAvatar(name: person.name, size: 44),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 3,
                children: [
                  Text(
                    person.name,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 15,
                      fontWeight: _bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted, size: 20),
          ],
        ),
      ),
    );
  }
}

/// The kind ("Teammate", "Mentor", "Team join"), the team, where it came
/// from ("via Hacky") and, on my own or accepted requests, the status.
class RequestTags extends StatelessWidget {
  const RequestTags({super.key, required this.request});

  final ConnectionRequest request;

  @override
  Widget build(BuildContext context) {
    final team = request.team;
    final status = switch (request.status) {
      ConnectionStatus.accepted => 'Accepted',
      ConnectionStatus.pending
          when request.direction == RequestDirection.outgoing =>
        'Pending',
      ConnectionStatus.pending => null,
    };
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        TagChip(RequestKind.of(request).label, strong: true),
        if (team != null) TagChip('Team ${team.name}'),
        TagChip(RequestTexts.source(request.source)),
        if (status != null) TagChip(status, strong: true),
      ],
    );
  }
}

/// Accept, Not now and Message. A small spinner shows while [busy].
class RequestActions extends StatelessWidget {
  const RequestActions({
    super.key,
    required this.busy,
    this.onAccept,
    this.onHide,
    this.onMessage,
  });

  final bool busy;
  final VoidCallback? onAccept;
  final VoidCallback? onHide;
  final VoidCallback? onMessage;

  static const _size = WidgetStatePropertyAll(Size(0, 40));
  static const _padding = WidgetStatePropertyAll(
    EdgeInsets.symmetric(horizontal: 18),
  );
  static const _text = WidgetStatePropertyAll(
    TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 13, fontWeight: _bold),
  );

  @override
  Widget build(BuildContext context) {
    VoidCallback? unlessBusy(VoidCallback? action) => busy ? null : action;
    final filled = ButtonStyle(
      minimumSize: _size,
      padding: _padding,
      textStyle: _text,
    );
    final outlined = OutlinedButton.styleFrom(
      backgroundColor: AppColors.white,
      foregroundColor: AppColors.ink,
      side: const BorderSide(color: AppColors.line),
      shape: RoundedRectangleBorder(borderRadius: AppTheme.borderRadius),
    ).merge(filled);
    return Row(
      spacing: 8,
      children: [
        if (onAccept != null)
          FilledButton(
            onPressed: unlessBusy(onAccept),
            style: filled,
            child: const Text('Accept'),
          ),
        if (onHide != null)
          OutlinedButton(
            onPressed: unlessBusy(onHide),
            style: outlined,
            child: const Text('Not now'),
          ),
        if (onMessage != null)
          FilledButton(
            onPressed: unlessBusy(onMessage),
            style: filled,
            child: const Text('Message'),
          ),
        if (busy)
          const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              semanticsLabel: 'Working…',
            ),
          ),
      ],
    );
  }
}

/// "Hidden (N)": the requests I answered "Not now", folded away until
/// tapped, like the original's `<details>`.
class HiddenRequestsSection extends StatefulWidget {
  const HiddenRequestsSection({super.key, required this.children});

  final List<Widget> children;

  @override
  State<HiddenRequestsSection> createState() => _HiddenRequestsSectionState();
}

class _HiddenRequestsSectionState extends State<HiddenRequestsSection> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        Semantics(
          expanded: _open,
          child: TextButton.icon(
            onPressed: () => setState(() => _open = !_open),
            icon: Icon(_open ? Icons.expand_less : Icons.expand_more, size: 20),
            label: Text('Hidden (${widget.children.length})'),
            style: TextButton.styleFrom(
              alignment: Alignment.centerLeft,
              foregroundColor: AppColors.muted,
              textStyle: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 13,
                fontWeight: _bold,
              ),
            ),
          ),
        ),
        if (_open) ...widget.children,
      ],
    );
  }
}

/// A muted line inside a tab, e.g. "No new requests right now."
class RequestsNote extends StatelessWidget {
  const RequestsNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: AppColors.muted, fontSize: 14, height: 1.5),
    );
  }
}
