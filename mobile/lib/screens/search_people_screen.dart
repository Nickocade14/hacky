import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../api/models/search.dart';
import '../auth/error_text.dart';
import '../people/people_search.dart';
import '../routes.dart';
import '../shell/screen_load.dart';
import '../widgets/app_widgets.dart';
import '../widgets/people_search_widgets.dart';

/// 06 Search people (People tab, mobile/design/people-wireframes.svg).
///
/// Searches the server as the user types (`GET /api/search?event=&q=&role=`,
/// `ApiClient.search`) through [PeopleSearch]: partial, case-insensitive
/// matches on name, handle and skills, most relevant first. Each hit shows
/// the matching part in bold and opens 07 on tap with `Navigate.toPerson`.
class SearchPeopleScreen extends StatefulWidget {
  const SearchPeopleScreen({
    super.key,
    required this.api,
    required this.eventSlug,
  });

  final ApiClient api;

  /// The event to search in.
  final String eventSlug;

  @override
  State<SearchPeopleScreen> createState() => _SearchPeopleScreenState();
}

class _SearchPeopleScreenState extends State<SearchPeopleScreen> {
  late final PeopleSearch _search = PeopleSearch(
    api: widget.api,
    eventSlug: widget.eventSlug,
  );
  final _text = TextEditingController();

  /// For "5 people in Knight Hacks IX"; the line just says "found" without it.
  String? _eventName;

  @override
  void initState() {
    super.initState();
    _search.addListener(_onSearchChanged);
    _loadEventName();
  }

  @override
  void dispose() {
    _search.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _loadEventName() async {
    try {
      final event = await widget.api.getEvent(widget.eventSlug);
      if (mounted) setState(() => _eventName = event.name);
    } catch (_) {
      // Only a label; the search works without it.
    }
  }

  /// An expired session goes back to log in, like every other screen.
  void _onSearchChanged() {
    final state = _search.state;
    if (state is SearchFailed &&
        state.error is ApiException &&
        (state.error as ApiException).statusCode == 401) {
      ScreenLoad.toLogin(context);
    }
  }

  void _openPerson(SearchHit hit) => Navigate.toPerson(
    context,
    eventSlug: widget.eventSlug,
    handle: hit.handle,
  );

  @override
  Widget build(BuildContext context) {
    return SignedInPage(
      title: 'People',
      body: ListenableBuilder(
        listenable: _search,
        builder: (context, _) {
          final state = _search.state;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SearchHeader(
                text: _text,
                search: _search,
                busy: state is SearchLoading && state.previous.isNotEmpty,
              ),
              Expanded(child: _body(state)),
            ],
          );
        },
      ),
    );
  }

  Widget _body(SearchState state) => switch (state) {
    SearchIdle() => const PageColumn(
      children: [
        MascotMessage(
          title: 'Find your people',
          body: 'Search by name, handle or skill. Try “React” or “Python”.',
        ),
      ],
    ),
    SearchLoading(previous: final hits) when hits.isEmpty => const LoadingView(
      label: 'Searching…',
    ),
    SearchLoading(:final query, previous: final hits) => _results(query, hits),
    SearchFound(:final query, results: final hits) when hits.isEmpty =>
      PageColumn(
        children: [
          MascotMessage(
            title: 'No one matches “${query.text}” yet.',
            body: 'Try a skill like React.',
          ),
        ],
      ),
    SearchFound(:final query, results: final hits) => _results(query, hits),
    SearchFailed(:final error) => ProblemView(
      message: ErrorText.of(error),
      onRetry: _search.retry,
    ),
  };

  Widget _results(SearchQuery query, List<SearchHit> hits) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: hits.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == 0) {
          return ResultCountLine(count: hits.length, eventName: _eventName);
        }
        final hit = hits[index - 1];
        return SearchHitRow(
          key: ValueKey(hit.userId),
          hit: hit,
          query: query.text,
          onTap: () => _openPerson(hit),
        );
      },
    );
  }
}

/// The search box and role filter above the results. A thin bar shows while
/// a new search runs over results already on screen.
class _SearchHeader extends StatelessWidget {
  const _SearchHeader({
    required this.text,
    required this.search,
    required this.busy,
  });

  final TextEditingController text;
  final PeopleSearch search;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          PeopleSearchField(
            controller: text,
            onChanged: search.setText,
            onSubmitted: search.submit,
          ),
          RoleFilterBar(
            selected: search.state.query.role,
            onChanged: search.setRole,
          ),
          SizedBox(
            height: 2,
            child: busy
                ? const LinearProgressIndicator(semanticsLabel: 'Searching')
                : null,
          ),
        ],
      ),
    );
  }
}

