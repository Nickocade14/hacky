import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../api/models/auth.dart';
import '../api/models/search.dart';

/// What the user is searching for: the trimmed text and an optional role.
@immutable
class SearchQuery {
  const SearchQuery(this.text, {this.role});

  static const empty = SearchQuery('');

  final String text;

  /// Only people with this role; null for everyone.
  final MemberRole? role;

  bool get isEmpty => text.isEmpty;

  SearchQuery withText(String text) => SearchQuery(text, role: role);

  SearchQuery withRole(MemberRole? role) => SearchQuery(text, role: role);

  @override
  bool operator ==(Object other) =>
      other is SearchQuery && other.text == text && other.role == role;

  @override
  int get hashCode => Object.hash(text, role);
}

/// Where a [PeopleSearch] is: one of the four states below.
sealed class SearchState {
  const SearchState(this.query);

  final SearchQuery query;
}

/// Nothing typed yet, so nothing was asked.
class SearchIdle extends SearchState {
  const SearchIdle(super.query);
}

/// Waiting for the debounce or the server. [previous] are the results still
/// on screen from the last search.
class SearchLoading extends SearchState {
  const SearchLoading(super.query, {this.previous = const []});

  final List<SearchHit> previous;
}

/// The server answered; [results] is empty when no one matches.
class SearchFound extends SearchState {
  const SearchFound(super.query, this.results);

  final List<SearchHit> results;
}

/// The search failed with [error] (usually an `ApiException`).
class SearchFailed extends SearchState {
  const SearchFailed(super.query, this.error);

  final Object error;
}

/// Searches people on the server as the user types
/// (`GET /api/search?event=&q=&role=`, partial match on name, handle and
/// skills). Never filters on the device.
///
/// Typing waits [debounce] before asking, so each pause sends one request.
/// Every change starts a new generation; an answer from an older generation
/// is dropped, so a slow reply never overwrites a newer one.
class PeopleSearch extends ChangeNotifier {
  PeopleSearch({
    required this.api,
    required this.eventSlug,
    this.debounce = const Duration(milliseconds: 300),
  });

  /// The contract's `maxLength` for `q`.
  static const maxLength = 100;

  final ApiClient api;
  final String eventSlug;
  final Duration debounce;

  SearchState _state = const SearchIdle(SearchQuery.empty);
  Timer? _timer;
  int _generation = 0;
  bool _disposed = false;

  SearchState get state => _state;

  /// The results to keep showing while a new search runs.
  List<SearchHit> get _shown => switch (_state) {
    SearchFound(:final results) => results,
    SearchLoading(:final previous) => previous,
    _ => const [],
  };

  /// The search box changed. Waits [debounce], then asks the server.
  void setText(String text) {
    var trimmed = text.trim();
    if (trimmed.length > maxLength) trimmed = trimmed.substring(0, maxLength);
    _change(_state.query.withText(trimmed), wait: true);
  }

  /// The role filter changed. Asks right away.
  void setRole(MemberRole? role) =>
      _change(_state.query.withRole(role), wait: false);

  /// Enter on the keyboard: skips the rest of the debounce.
  void submit() {
    if (_timer?.isActive ?? false) {
      _timer!.cancel();
      _send(_state.query, _generation);
    }
  }

  /// "Try again" after a failure.
  void retry() {
    if (_state is! SearchFailed) return;
    _change(_state.query, wait: false, force: true);
  }

  void _change(SearchQuery query, {required bool wait, bool force = false}) {
    if (!force && query == _state.query) return;
    _timer?.cancel();
    final generation = ++_generation;
    if (query.isEmpty) {
      _set(SearchIdle(query));
      return;
    }
    _set(SearchLoading(query, previous: _shown));
    if (wait) {
      _timer = Timer(debounce, () => _send(query, generation));
    } else {
      _send(query, generation);
    }
  }

  Future<void> _send(SearchQuery query, int generation) async {
    SearchState next;
    try {
      final found = await api.search(
        event: eventSlug,
        q: query.text,
        role: query.role,
      );
      next = SearchFound(query, found.results);
    } catch (e) {
      next = SearchFailed(query, e);
    }
    // A newer search started while this one was out: drop the answer.
    if (generation != _generation) return;
    _set(next);
  }

  void _set(SearchState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
