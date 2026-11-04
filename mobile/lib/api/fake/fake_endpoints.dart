import '../api_exception.dart';
import '../models/auth.dart';
import '../models/events.dart';
import '../models/me.dart';
import '../models/people.dart';
import '../models/teams.dart';
import 'fake_world.dart';

/// In-memory versions of the non-auth [ApiClient] endpoints, with realistic
/// data (see fake_world.dart). Add it to a fake client that implements the
/// auth routes:
///
/// ```dart
/// class FakeApiClient with FakeEndpoints implements ApiClient { ... }
/// ```
///
/// The host's [getMe] says who is signed in (it should throw a 401
/// [ApiException] when nobody is, and wait to simulate latency). Each user
/// gets their own copy of the data. To show profile edits and joined events
/// in the host's own `getMe`, pass its result through [fakeApplyChanges].
mixin FakeEndpoints {
  /// Implemented by the host fake.
  Future<Me> getMe();

  final _worlds = <String, FakeWorld>{};

  /// The signed-in user's world. Throws what the host's [getMe] throws.
  Future<FakeWorld> fakeWorld() async {
    final me = await getMe();
    return _worlds.putIfAbsent(
      me.profile.userId,
      () => FakeWorld(me.profile, me.events),
    );
  }

  /// [me] with the profile edits and event joins made through the fake.
  Me fakeApplyChanges(Me me) {
    final world = _worlds[me.profile.userId];
    if (world == null) return me;
    final membership = world.me.membership;
    return Me(
      profile: world.me.profile,
      events: [
        for (final e in me.events)
          if (e.slug != fakeEventSlug) e,
        if (membership != null)
          MyEvent(
            slug: fakeEventSlug,
            name: world.event.name,
            role: membership.role,
            verified: membership.verified,
          ),
      ],
    );
  }

  // ---------------------------------------------------------------- me

  Future<PublicProfile> updateProfile(UpdateProfileBody body) async {
    if (body.isEmpty) {
      throw ArgumentError.value(body, 'body', 'Set at least one field');
    }
    final me = (await fakeWorld()).me;
    final name = body.name;
    if (name != null && (name.trim().isEmpty || name.length > 80)) {
      throw fakeInvalid('name', 'Must be 1 to 80 characters');
    }
    final bio = body.bio;
    if (bio != null && (bio.value?.length ?? 0) > 500) {
      throw fakeInvalid('bio', 'Must be at most 500 characters');
    }
    if (name != null) me.name = name;
    if (bio != null) me.bio = bio.value;
    if (body.hackyStyle != null) me.hackyStyle = body.hackyStyle!;
    if (body.links != null) me.links = body.links!;
    return me.profile;
  }

  // ---------------------------------------------------------------- events

  Future<List<EventInfo>> listEvents() async => [(await fakeWorld()).event];

  Future<EventInfo> getEvent(String slug) async {
    final world = await fakeWorld();
    _eventOr404(slug);
    return world.event;
  }

  Future<EventMe> joinEvent(
    String slug, [
    JoinEventBody body = const JoinEventBody(),
  ]) async {
    final world = await fakeWorld();
    _eventOr404(slug);
    final role = body.role ?? JoinRole.hacker;
    // Joining again returns the same membership. Mentors wait for an
    // organizer to verify them.
    final membership = world.me.membership ??= FakeMembership(
      role: role == JoinRole.mentor ? MemberRole.mentor : MemberRole.hacker,
      verified: role != JoinRole.mentor,
    );
    return membership.eventMe;
  }

  Future<EventMe> getEventMe(String slug) async =>
      fakeMembership(await fakeWorld(), slug).eventMe;

  Future<EventMe> updateEventMe(String slug, UpdateEventMeBody body) async {
    final m = fakeMembership(await fakeWorld(), slug);
    final old = m.intake;
    final experience = body.experience == null
        ? old.experience
        : body.experience!.value;
    final goal = body.goal == null ? old.goal : body.goal!.value;
    final skills = body.skills ?? old.skills;
    m.intake = Intake(
      skills: skills,
      skillsWanted: body.skillsWanted ?? old.skillsWanted,
      experience: experience,
      wantsExperienced: body.wantsExperienced ?? old.wantsExperienced,
      goal: goal,
      track: body.track == null ? old.track : body.track!.value,
      interests: body.interests ?? old.interests,
      idea: body.idea == null ? old.idea : body.idea!.value,
      motivations: body.motivations ?? old.motivations,
      summary: old.summary,
      // The server decides this; the fake calls it complete once the
      // matching basics are there.
      complete: skills.isNotEmpty && experience != null && goal != null,
    );
    if (body.availability != null) m.availability = body.availability!;
    if (body.looking != null) m.looking = body.looking!;
    return m.eventMe;
  }

  // ---------------------------------------------------------------- people

  Future<PersonDetail> getPerson(String slug, String handle) async {
    final world = await fakeWorld();
    fakeMembership(world, slug);
    final person = world.byHandle(handle);
    if (person == null || person.membership == null) {
      throw fakeError(404, 'not_found', 'No one called @$handle here.');
    }
    return person.detail(world.relationTo(person.userId));
  }

  // ---------------------------------------------------------------- teams

  Future<MyTeam?> getMyTeam(String slug) async {
    final world = await fakeWorld();
    fakeMembership(world, slug);
    final team = world.teamOf(world.me.userId);
    if (team == null) return null;
    return MyTeam(
      id: team.id,
      name: team.name,
      isOwner: team.ownerId == world.me.userId,
      size: team.memberIds.length,
      maxSize: team.maxSize,
    );
  }

  Future<TeamDetail> createTeam(String slug, CreateTeamBody body) async {
    final world = await fakeWorld();
    fakeMembership(world, slug);
    if (body.name.trim().isEmpty || body.name.length > 80) {
      throw fakeInvalid('name', 'Must be 1 to 80 characters');
    }
    final maxSize = body.maxSize ?? 4;
    if (maxSize < 1 || maxSize > 8) {
      throw fakeInvalid('maxSize', 'Must be 1 to 8');
    }
    if (world.teamOf(world.me.userId) != null) {
      throw fakeError(409, 'conflict', 'You are already on a team.');
    }
    final team = FakeTeam(
      id: world.newId(),
      name: body.name,
      idea: body.idea,
      track: body.track,
      wantedSkills: body.wantedSkills ?? const [],
      maxSize: maxSize,
      ownerId: world.me.userId,
      memberIds: [world.me.userId],
    );
    world.teams[team.id] = team;
    return world.teamDetail(team);
  }

  Future<TeamDetail> getTeam(String slug, String teamId) async {
    final world = await fakeWorld();
    fakeMembership(world, slug);
    final team = world.teams[teamId];
    if (team == null) throw fakeError(404, 'not_found', 'No such team.');
    return world.teamDetail(team);
  }

  /// My membership in [slug]; 403 when I'm not a member, like the server.
  FakeMembership fakeMembership(FakeWorld world, String slug) {
    final membership = slug == fakeEventSlug ? world.me.membership : null;
    if (membership == null) {
      throw fakeError(403, 'forbidden', 'Join the event first.');
    }
    return membership;
  }

  void _eventOr404(String slug) {
    if (slug != fakeEventSlug) {
      throw fakeError(404, 'not_found', 'No event "$slug".');
    }
  }
}

/// An error shaped like the server's.
ApiException fakeError(int status, String code, String message) =>
    ApiException(statusCode: status, code: code, message: message);

/// A 400 `invalid_input` with one field detail.
ApiException fakeInvalid(String field, String message) => ApiException(
  statusCode: 400,
  code: 'invalid_input',
  message: 'Invalid input',
  details: [
    ApiErrorDetail(path: [field], message: message),
  ],
);
