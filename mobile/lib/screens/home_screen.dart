import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models/events.dart';
import '../api/models/teams.dart';
import '../auth/error_text.dart';
import '../home/home_data.dart';
import '../routes.dart';
import '../shell/app_tab.dart';
import '../shell/screen_load.dart';
import '../widgets/app_widgets.dart';
import '../widgets/create_team_sheet.dart';
import '../widgets/home_cards.dart';

/// 05 Home with event (mobile/design/home-wireframes.svg): my event, my
/// team, my requests and people I might like.
///
/// Loads [HomeData] for [eventSlug]. "Looking for a team" and availability
/// save right away (`PATCH /api/events/{slug}/me`). Requests and people push
/// 09 and 07; "Add skills you want to learn" opens Me through [onOpenTab].
/// The shell's header and Ask Hacky button lead everywhere else.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.api,
    required this.eventSlug,
    required this.onOpenTab,
  });

  final ApiClient api;
  final String eventSlug;

  /// Switches the shell's page (the suggestions' nudge → Me).
  final ValueChanged<AppTab> onOpenTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with ScreenLoad<HomeScreen> {
  HomeData? _data;
  PeopleSuggestions _suggestions = PeopleSuggestions.none;

  @override
  void initState() {
    super.initState();
    runLoad(_load);
  }

  Future<void> _load() async {
    final data = await HomeData.load(widget.api, widget.eventSlug);
    if (!mounted) return;
    setState(() => _data = data);
    _loadSuggestions(data.membership.intake);
  }

  /// Suggestions are extra: if the search fails, the section just stays empty.
  Future<void> _loadSuggestions(Intake intake) async {
    try {
      final suggestions = await PeopleSuggestions.load(
        widget.api,
        widget.eventSlug,
        intake,
      );
      if (mounted) setState(() => _suggestions = suggestions);
    } catch (_) {
      if (mounted) setState(() => _suggestions = PeopleSuggestions.none);
    }
  }

  /// Pull to refresh, and coming back from 07 or 09: reloads without the
  /// spinner and keeps what's on screen if it fails.
  Future<void> _refresh() async {
    try {
      await _load();
    } catch (e) {
      _showProblem(e);
    }
  }

  void _showProblem(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(ErrorText.of(error))));
  }

  Future<void> _saveMembership(
    EventMe optimistic,
    UpdateEventMeBody body,
  ) async {
    final before = _data!.membership;
    setState(() => _data = _data!.withMembership(optimistic));
    try {
      final saved = await widget.api.updateEventMe(widget.eventSlug, body);
      if (mounted) setState(() => _data = _data!.withMembership(saved));
    } catch (e) {
      if (!mounted) return;
      setState(() => _data = _data!.withMembership(before));
      _showProblem(e);
    }
  }

  void _setLooking(bool looking) => _saveMembership(
    _data!.membership.copyWith(looking: looking),
    UpdateEventMeBody(looking: looking),
  );

  void _setAvailability(Availability availability) => _saveMembership(
    _data!.membership.copyWith(availability: availability),
    UpdateEventMeBody(availability: availability),
  );

  Future<void> _createTeam() async {
    final team = await CreateTeamSheet.show(
      context,
      api: widget.api,
      eventSlug: widget.eventSlug,
    );
    if (team == null || !mounted) return;
    setState(
      () => _data = _data!.withTeam(
        MyTeam(
          id: team.id,
          name: team.name,
          isOwner: true,
          size: team.size,
          maxSize: team.maxSize,
        ),
      ),
    );
  }

  Future<void> _openRequests() async {
    await Navigate.toRequests(context, eventSlug: widget.eventSlug);
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
    final data = _data;
    return SignedInPage(
      title: 'Home',
      body: switch ((data, problem)) {
        (null, final String message) => ProblemView(
          message: message,
          onRetry: () => runLoad(_load),
        ),
        (null, _) => const LoadingView(label: 'Loading your event…'),
        (final HomeData loaded, _) => RefreshIndicator(
          onRefresh: _refresh,
          child: _content(loaded),
        ),
      },
    );
  }

  Widget _content(HomeData data) {
    return PageColumn(
      children: [
        EventCard(
          event: data.event,
          membership: data.membership,
          onLookingChanged: _setLooking,
          onAvailabilityChanged: _setAvailability,
        ),
        RequestsRow(newCount: data.newRequestCount, onOpen: _openRequests),
        MyTeamCard(team: data.team, onCreate: _createTeam),
        PeopleSuggestionsSection(
          skill: _suggestions.skill,
          people: _suggestions.people,
          onOpenPerson: (person) => _openPerson(person.handle),
          onOpenMe: () => widget.onOpenTab(AppTab.me),
        ),
      ],
    );
  }
}
