import '../api/api_client.dart';
import '../api/models/events.dart';
import '../api/models/requests.dart';
import '../api/models/search.dart';
import '../api/models/teams.dart';

/// Everything 05 Home shows for one event, loaded together
/// (mobile/design/home-wireframes.svg).
class HomeData {
  const HomeData({
    required this.event,
    required this.membership,
    required this.team,
    required this.requests,
  });

  /// `GET /api/events/{slug}`.
  final EventInfo event;

  /// `GET /api/events/{slug}/me`: role, looking, availability and intake.
  final EventMe membership;

  /// `GET /api/events/{slug}/me/team`; null when I'm on no team.
  final MyTeam? team;

  /// `GET /api/events/{slug}/requests`, for the "N new" badge.
  final List<ConnectionRequest> requests;

  /// Incoming requests still waiting for me (not accepted, not hidden).
  int get newRequestCount => requests
      .where(
        (r) =>
            r.direction == RequestDirection.incoming &&
            r.status == ConnectionStatus.pending &&
            r.hiddenAt == null,
      )
      .length;

  static Future<HomeData> load(ApiClient api, String slug) async {
    // Future.wait reports the first failure and handles the others.
    final results = await Future.wait<Object?>([
      api.getEvent(slug),
      api.getEventMe(slug),
      api.getMyTeam(slug),
      api.listRequests(slug),
    ]);
    return HomeData(
      event: results[0] as EventInfo,
      membership: results[1] as EventMe,
      team: results[2] as MyTeam?,
      requests: results[3] as List<ConnectionRequest>,
    );
  }

  HomeData withMembership(EventMe membership) => HomeData(
    event: event,
    membership: membership,
    team: team,
    requests: requests,
  );

  HomeData withTeam(MyTeam team) => HomeData(
    event: event,
    membership: membership,
    team: team,
    requests: requests,
  );
}

/// "People you might like" on Home: people who know the first skill I want
/// to learn, from the server search (`GET /api/search`). The contract has no
/// recommendations endpoint, so this is the closest honest match.
class PeopleSuggestions {
  const PeopleSuggestions({required this.skill, required this.people});

  /// The skill searched for, or null when my intake has no wanted skills.
  final String? skill;
  final List<SearchHit> people;

  static const none = PeopleSuggestions(skill: null, people: []);

  /// How many people Home shows.
  static const limit = 3;

  static Future<PeopleSuggestions> load(
    ApiClient api,
    String slug,
    Intake intake,
  ) async {
    final skill = intake.skillsWanted
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s.length <= 100)
        .firstOrNull;
    if (skill == null) return none;
    final results = await api.search(event: slug, q: skill, limit: limit);
    return PeopleSuggestions(skill: skill, people: results.results);
  }
}

/// The optimistic copy Home shows while a change saves.
extension EventMeEdits on EventMe {
  EventMe copyWith({Availability? availability, bool? looking}) => EventMe(
    role: role,
    verified: verified,
    availability: availability ?? this.availability,
    looking: looking ?? this.looking,
    intake: intake,
  );
}
