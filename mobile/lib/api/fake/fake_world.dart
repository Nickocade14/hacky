// The in-memory data behind FakeEndpoints: one event, a few people, a team,
// one conversation and one incoming request. Each signed-in user gets their
// own copy, made the first time they call a fake endpoint.

import '../models/auth.dart';
import '../models/chat.dart';
import '../models/conversations.dart';
import '../models/events.dart';
import '../models/people.dart';
import '../models/requests.dart';
import '../models/search.dart';
import '../models/teams.dart';

/// The one fake event. Same slug and name as the auth fake's `MyEvent`.
const fakeEventSlug = 'knighthacks-ix';

/// A person's membership in the fake event.
class FakeMembership {
  FakeMembership({
    required this.role,
    required this.verified,
    this.availability = Availability.available,
    this.looking = true,
    Intake? intake,
  }) : intake = intake ?? emptyIntake;

  MemberRole role;
  bool verified;
  Availability availability;
  bool looking;
  Intake intake;

  static const emptyIntake = Intake(
    skills: [],
    skillsWanted: [],
    experience: null,
    wantsExperienced: false,
    goal: null,
    track: null,
    interests: [],
    idea: null,
    motivations: [],
    summary: null,
    complete: false,
  );

  EventMe get eventMe => EventMe(
    role: role,
    verified: verified,
    availability: availability,
    looking: looking,
    intake: intake,
  );
}

/// A person in the fake world, the signed-in user included.
class FakePerson {
  FakePerson({
    required this.userId,
    required this.handle,
    required this.name,
    this.hackyStyle = const {},
    this.photoUrl,
    this.bio,
    this.links = const ProfileLinks(),
    this.isDemo = true,
    this.membership,
  });

  factory FakePerson.fromProfile(PublicProfile p) => FakePerson(
    userId: p.userId,
    handle: p.handle,
    name: p.name,
    hackyStyle: p.hackyStyle,
    photoUrl: p.photoUrl,
    bio: p.bio,
    links: p.links,
    isDemo: p.isDemo,
  );

  final String userId;
  final String handle;
  String name;
  Map<String, dynamic> hackyStyle;
  String? photoUrl;
  String? bio;
  ProfileLinks links;
  final bool isDemo;

  /// Null until they join the fake event.
  FakeMembership? membership;

  PublicProfile get profile => PublicProfile(
    userId: userId,
    handle: handle,
    name: name,
    hackyStyle: hackyStyle,
    photoUrl: photoUrl,
    bio: bio,
    links: links,
    isDemo: isDemo,
  );

  PersonSummary get summary => PersonSummary(
    userId: userId,
    handle: handle,
    name: name,
    hackyStyle: hackyStyle,
    photoUrl: photoUrl,
    role: membership?.role ?? MemberRole.hacker,
  );

  SearchHit searchHit(List<String> matchedSkills) => SearchHit(
    userId: userId,
    handle: handle,
    name: name,
    hackyStyle: hackyStyle,
    photoUrl: photoUrl,
    role: membership?.role ?? MemberRole.hacker,
    skills: membership?.intake.skills ?? const [],
    matchedSkills: matchedSkills,
  );

  PersonDetail detail(Relation relation) {
    final m = membership!;
    final i = m.intake;
    return PersonDetail(
      userId: userId,
      handle: handle,
      name: name,
      hackyStyle: hackyStyle,
      photoUrl: photoUrl,
      bio: bio,
      links: links,
      isDemo: isDemo,
      role: m.role,
      verified: m.verified,
      availability: m.availability,
      looking: m.looking,
      skills: i.skills,
      skillsWanted: i.skillsWanted,
      experience: i.experience,
      goal: i.goal,
      track: i.track,
      interests: i.interests,
      idea: i.idea,
      summary: i.summary,
      motivations: i.motivations,
      relation: relation,
    );
  }
}

class FakeTeam {
  FakeTeam({
    required this.id,
    required this.name,
    required this.idea,
    required this.track,
    required this.wantedSkills,
    required this.maxSize,
    required this.ownerId,
    required this.memberIds,
  });

  final String id;
  final String name;
  final String? idea;
  final String? track;
  final List<String> wantedSkills;
  final int maxSize;
  final String ownerId;

  /// Owner first.
  final List<String> memberIds;
}

class FakeRequest {
  FakeRequest({
    required this.id,
    required this.fromId,
    required this.toId,
    required this.intro,
    required this.source,
    required this.teamId,
    required this.createdAt,
  });

  final String id;
  final String fromId;
  final String toId;
  final String intro;
  final ConnectionSource source;
  final String? teamId;
  final DateTime createdAt;
  ConnectionStatus status = ConnectionStatus.pending;
  String? conversationId;
  DateTime? respondedAt;
  DateTime? hiddenAt;
}

class FakeConversation {
  FakeConversation({
    required this.id,
    required this.kind,
    required this.memberIds,
    required this.createdAt,
    this.teamId,
  });

  final String id;
  final ConversationKind kind;
  final List<String> memberIds;
  final String? teamId;
  final DateTime createdAt;

  /// Oldest first.
  final messages = <Message>[];

  /// When each member last marked it read.
  final lastReadAt = <String, DateTime>{};
}

/// One signed-in user's copy of the fake data.
class FakeWorld {
  FakeWorld(PublicProfile me, List<MyEvent> myEvents)
    : me = FakePerson.fromProfile(me) {
    _seed(myEvents);
  }

  final FakePerson me;
  final people = <String, FakePerson>{};
  final teams = <String, FakeTeam>{};
  final requests = <String, FakeRequest>{};
  final conversations = <String, FakeConversation>{};
  final chat = <ChatMessage>[];

  int _nextId = 0x100;

  /// A fresh 24-hex-character id, like a MongoDB ObjectId. Ids increase, so
  /// sorting by id is sorting by creation.
  String newId() =>
      '6716a3f2c9e7${(_nextId++).toRadixString(16).padLeft(12, '0')}';

  DateTime now() => DateTime.now().toUtc();

  final event = EventInfo(
    slug: fakeEventSlug,
    name: 'Knight Hacks IX',
    theme: const EventTheme(
      brand: '#5b3df5',
      brandContrast: '#ffffff',
      accent: '#ffb000',
      surface: '#f7f5ff',
      displayFont: 'Lato',
      raw: {
        'brand': '#5b3df5',
        'brandContrast': '#ffffff',
        'accent': '#ffb000',
        'surface': '#f7f5ff',
        'displayFont': 'Lato',
      },
    ),
    tracks: const ['AI', 'Health', 'Fintech', 'Education'],
    startsAt: DateTime.utc(2026, 11, 14, 13),
    endsAt: DateTime.utc(2026, 11, 15, 19),
  );

  FakePerson? byHandle(String handle) => handle == me.handle
      ? me
      : people.values.where((p) => p.handle == handle).firstOrNull;

  FakePerson? byId(String id) => id == me.userId ? me : people[id];

  /// Where I stand with [userId], from our personal (non-team) requests.
  Relation relationTo(String userId) {
    final between = requests.values.where(
      (r) =>
          r.teamId == null &&
          ((r.fromId == me.userId && r.toId == userId) ||
              (r.fromId == userId && r.toId == me.userId)),
    );
    final accepted = between
        .where((r) => r.status == ConnectionStatus.accepted)
        .firstOrNull;
    if (accepted != null) {
      return Relation(
        state: RelationState.accepted,
        requestId: accepted.id,
        conversationId: accepted.conversationId,
      );
    }
    final pending = between.firstOrNull;
    if (pending == null) {
      return const Relation(
        state: RelationState.none,
        requestId: null,
        conversationId: null,
      );
    }
    return Relation(
      state: pending.fromId == me.userId
          ? RelationState.outgoing
          : RelationState.incoming,
      requestId: pending.id,
      conversationId: null,
    );
  }

  /// [request] as I see it: direction and person are relative to me.
  ConnectionRequest connectionRequest(FakeRequest request) {
    final incoming = request.toId == me.userId;
    final team = request.teamId == null ? null : teams[request.teamId];
    return ConnectionRequest(
      id: request.id,
      direction: incoming
          ? RequestDirection.incoming
          : RequestDirection.outgoing,
      status: request.status,
      intro: request.intro,
      source: request.source,
      person: byId(incoming ? request.fromId : request.toId)!.summary,
      team: team == null ? null : TeamRef(id: team.id, name: team.name),
      conversationId: request.conversationId,
      createdAt: request.createdAt,
      respondedAt: request.respondedAt,
      hiddenAt: incoming ? request.hiddenAt : null,
    );
  }

  /// The DM between me and [userId], opened with a system message when new.
  FakeConversation openDm(String userId) {
    final existing = conversations.values.where(
      (c) =>
          c.kind == ConversationKind.dm &&
          c.memberIds.contains(me.userId) &&
          c.memberIds.contains(userId),
    );
    if (existing.isNotEmpty) return existing.first;
    final dm = FakeConversation(
      id: newId(),
      kind: ConversationKind.dm,
      memberIds: [me.userId, userId],
      createdAt: now(),
    );
    dm.messages.add(
      Message(
        id: newId(),
        conversationId: dm.id,
        senderId: null,
        clientId: null,
        body: 'You and ${byId(userId)!.name} are connected. Say hi!',
        kind: MessageKind.system,
        createdAt: dm.createdAt,
      ),
    );
    conversations[dm.id] = dm;
    return dm;
  }

  TeamDetail teamDetail(FakeTeam team) => TeamDetail(
    id: team.id,
    name: team.name,
    idea: team.idea,
    track: team.track,
    wantedSkills: team.wantedSkills,
    size: team.memberIds.length,
    maxSize: team.maxSize,
    owner: byId(team.ownerId)!.summary,
    members: [for (final id in team.memberIds) byId(id)!.summary],
  );

  FakeTeam? teamOf(String userId) =>
      teams.values.where((t) => t.memberIds.contains(userId)).firstOrNull;

  void _seed(List<MyEvent> myEvents) {
    final mine = myEvents.where((e) => e.slug == fakeEventSlug).firstOrNull;
    if (mine != null) {
      me.membership = FakeMembership(role: mine.role, verified: mine.verified);
    }

    FakePerson add(
      String handle,
      String name, {
      required MemberRole role,
      required Intake intake,
      String? bio,
      String? photoUrl,
      ProfileLinks links = const ProfileLinks(),
      Map<String, dynamic> hackyStyle = const {},
      Availability availability = Availability.available,
      bool looking = true,
    }) {
      final person = FakePerson(
        userId: newId(),
        handle: handle,
        name: name,
        bio: bio,
        photoUrl: photoUrl,
        links: links,
        hackyStyle: hackyStyle,
        membership: FakeMembership(
          role: role,
          verified: true,
          availability: availability,
          looking: looking,
          intake: intake,
        ),
      );
      people[person.userId] = person;
      return person;
    }

    final maya = add(
      'maya_ml',
      'Maya Patel',
      role: MemberRole.hacker,
      bio: 'ML student at UCF. Health tech nerd.',
      links: const ProfileLinks(github: 'https://github.com/maya-ml'),
      hackyStyle: const {'look': 'knit', 'color': 'teal', 'avatar': 'hacky'},
      intake: const Intake(
        skills: ['python', 'pytorch', 'computer vision'],
        skillsWanted: ['flutter', 'ux'],
        experience: Experience.advanced,
        wantsExperienced: false,
        goal: HackGoal.win,
        track: 'Health',
        interests: ['health', 'accessibility'],
        idea: 'Skin rash triage from a phone photo',
        motivations: [Motivation.compete, Motivation.build],
        summary: 'Builds the ML model, needs a mobile dev and a designer.',
        complete: true,
      ),
    );
    final leo = add(
      'leo_builds',
      'Leo Nguyen',
      role: MemberRole.hacker,
      looking: false,
      intake: const Intake(
        skills: ['react', 'node', 'mongodb'],
        skillsWanted: ['python'],
        experience: Experience.intermediate,
        wantsExperienced: false,
        goal: HackGoal.ship,
        track: 'Health',
        interests: ['web'],
        idea: null,
        motivations: [Motivation.build],
        summary: 'Full-stack JavaScript, on Maya\'s team.',
        complete: true,
      ),
    );
    final priya = add(
      'priya_codes',
      'Priya Shah',
      role: MemberRole.hacker,
      bio: 'Backend and databases. First hackathon in a while!',
      links: const ProfileLinks(
        github: 'https://github.com/priya-codes',
        linkedin: 'https://www.linkedin.com/in/priya-shah',
      ),
      hackyStyle: const {'look': 'knit', 'color': 'coral'},
      intake: const Intake(
        skills: ['go', 'postgres', 'docker'],
        skillsWanted: ['flutter', 'react'],
        experience: Experience.intermediate,
        wantsExperienced: true,
        goal: HackGoal.learn,
        track: 'Fintech',
        interests: ['finance', 'open source'],
        idea: 'Split rent and bills with roommates',
        motivations: [Motivation.learn, Motivation.meet],
        summary: 'Backend dev looking for a mobile partner for a fintech idea.',
        complete: true,
      ),
    );
    add(
      'sam_mentor',
      'Sam Rivera',
      role: MemberRole.mentor,
      availability: Availability.busy,
      looking: false,
      bio: 'Mobile engineer. Ask me about Flutter and Firebase.',
      photoUrl: '/assets/people/sam.png',
      intake: const Intake(
        skills: ['flutter', 'firebase', 'dart'],
        skillsWanted: [],
        experience: Experience.advanced,
        wantsExperienced: false,
        goal: null,
        track: null,
        interests: ['mobile'],
        idea: null,
        motivations: [Motivation.meet],
        summary: null,
        complete: true,
      ),
    );
    final jordan = add(
      'jordan_ux',
      'Jordan Lee',
      role: MemberRole.hacker,
      intake: const Intake(
        skills: ['figma', 'ux research', 'react'],
        skillsWanted: ['python'],
        experience: Experience.beginner,
        wantsExperienced: true,
        goal: HackGoal.learn,
        track: 'Education',
        interests: ['education', 'design'],
        idea: null,
        motivations: [Motivation.learn, Motivation.fun],
        summary: 'Designer who can prototype in React.',
        complete: false,
      ),
    );

    final team = FakeTeam(
      id: newId(),
      name: 'Rash Decisions',
      idea: 'Skin rash triage from a phone photo',
      track: 'Health',
      wantedSkills: const ['flutter', 'ux'],
      maxSize: 4,
      ownerId: maya.userId,
      memberIds: [maya.userId, leo.userId],
    );
    teams[team.id] = team;

    final started = now().subtract(const Duration(hours: 2));

    // Jordan asked to connect with me and is waiting.
    final request = FakeRequest(
      id: newId(),
      fromId: jordan.userId,
      toId: me.userId,
      intro: 'Hi! I design in Figma and would love to pair on an app.',
      source: ConnectionSource.agent,
      teamId: null,
      createdAt: started.add(const Duration(minutes: 30)),
    );
    requests[request.id] = request;

    // Priya and I are already connected and chatting.
    final accepted = FakeRequest(
      id: newId(),
      fromId: priya.userId,
      toId: me.userId,
      intro: 'Your profile says Flutter. Want to build a fintech app?',
      source: ConnectionSource.profile,
      teamId: null,
      createdAt: started,
    );
    final dm = FakeConversation(
      id: newId(),
      kind: ConversationKind.dm,
      memberIds: [me.userId, priya.userId],
      createdAt: started.add(const Duration(minutes: 5)),
    );
    accepted
      ..status = ConnectionStatus.accepted
      ..respondedAt = dm.createdAt
      ..conversationId = dm.id;
    requests[accepted.id] = accepted;
    conversations[dm.id] = dm;
    dm.messages.addAll([
      Message(
        id: newId(),
        conversationId: dm.id,
        senderId: null,
        clientId: null,
        body: 'You and Priya are connected. Say hi!',
        kind: MessageKind.system,
        createdAt: dm.createdAt,
      ),
      Message(
        id: newId(),
        conversationId: dm.id,
        senderId: me.userId,
        clientId: '00000000-0000-4000-8000-000000000001',
        body: 'Hey Priya! Rent splitting sounds fun. I can do the app.',
        kind: MessageKind.text,
        createdAt: dm.createdAt.add(const Duration(minutes: 3)),
      ),
      Message(
        id: newId(),
        conversationId: dm.id,
        senderId: priya.userId,
        clientId: '00000000-0000-4000-8000-000000000002',
        body: 'Awesome! I\'ll start the Go API. Meet at the food tables at 3?',
        kind: MessageKind.text,
        createdAt: dm.createdAt.add(const Duration(minutes: 9)),
      ),
    ]);
    dm.lastReadAt[me.userId] = dm.createdAt.add(const Duration(minutes: 3));
    dm.lastReadAt[priya.userId] = dm.createdAt.add(const Duration(minutes: 9));
  }
}
