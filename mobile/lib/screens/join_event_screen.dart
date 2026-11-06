import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models/events.dart';
import '../auth/error_text.dart';
import '../home/event_dates.dart';
import '../shell/screen_load.dart';
import '../theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/auth_widgets.dart';

/// 05 Home before the user is in an event: the events to join
/// (`GET /api/events`), each with Join (`POST /api/events/{slug}/join`).
/// After joining, [onJoined] tells the shell which event to open.
class JoinEventScreen extends StatefulWidget {
  const JoinEventScreen({super.key, required this.api, required this.onJoined});

  final ApiClient api;
  final ValueChanged<String> onJoined;

  @override
  State<JoinEventScreen> createState() => _JoinEventScreenState();
}

class _JoinEventScreenState extends State<JoinEventScreen>
    with ScreenLoad<JoinEventScreen> {
  List<EventInfo> _events = const [];

  /// The slug being joined, while the request runs.
  String? _joining;
  String? _joinError;

  @override
  void initState() {
    super.initState();
    runLoad(_load);
  }

  Future<void> _load() async {
    final events = await widget.api.listEvents();
    if (mounted) setState(() => _events = events);
  }

  Future<void> _join(String slug) async {
    setState(() {
      _joining = slug;
      _joinError = null;
    });
    try {
      await widget.api.joinEvent(slug);
      if (mounted) widget.onJoined(slug);
    } catch (e) {
      if (mounted) setState(() => _joinError = ErrorText.of(e));
    } finally {
      if (mounted) setState(() => _joining = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SignedInPage(
      title: 'Home',
      body: switch ((loading, problem)) {
        (true, _) => const LoadingView(label: 'Loading events…'),
        (_, final String message) => ProblemView(
          message: message,
          onRetry: () => runLoad(_load),
        ),
        _ => PageColumn(
          children: [
            const MascotMessage(
              title: 'Pick your hackathon',
              body: 'Join an event to meet people, find a team and chat '
                  'with Hacky.',
            ),
            if (_joinError != null) Notice(_joinError!, error: true),
            if (_events.isEmpty)
              const Text(
                'No events to join right now. Check back soon.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted),
              ),
            for (final event in _events)
              JoinEventCard(
                event: event,
                busy: _joining == event.slug,
                onJoin: _joining == null ? () => _join(event.slug) : null,
              ),
          ],
        ),
      },
    );
  }
}

/// One event to join: name, dates and a Join button.
class JoinEventCard extends StatelessWidget {
  const JoinEventCard({
    super.key,
    required this.event,
    required this.busy,
    required this.onJoin,
  });

  final EventInfo event;
  final bool busy;

  /// Null while another join runs.
  final VoidCallback? onJoin;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        spacing: 12,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Text(
                  event.name,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  EventDates.format(event.startsAt, event.endsAt),
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: busy ? null : onJoin,
            child: Text(busy ? 'Joining…' : 'Join'),
          ),
        ],
      ),
    );
  }
}
