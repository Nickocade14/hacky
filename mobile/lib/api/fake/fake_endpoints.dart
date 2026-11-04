import '../api_exception.dart';
import '../models/auth.dart';
import '../models/chat.dart';
import '../models/conversations.dart';
import '../models/events.dart';
import '../models/me.dart';
import '../models/people.dart';
import '../models/requests.dart';
import '../models/search.dart';
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

  // ---------------------------------------------------------------- search

  Future<SearchResults> search({
    required String event,
    required String q,
    MemberRole? role,
    int? limit,
  }) async {
    if (q.isEmpty || q.length > 100) {
      throw ArgumentError.value(q, 'q', 'Must be 1 to 100 characters');
    }
    if (limit != null && (limit < 1 || limit > 50)) {
      throw RangeError.range(limit, 1, 50, 'limit');
    }
    final world = await fakeWorld();
    fakeMembership(world, event);
    final needle = q.toLowerCase();

    // Same order as the contract: handle or name starting with q, then
    // containing q, then skill matches. Ties keep the seed order.
    final ranked = <(int, SearchHit)>[];
    for (final person in world.people.values) {
      final m = person.membership;
      if (m == null || (role != null && m.role != role)) continue;
      final handle = person.handle.toLowerCase();
      final name = person.name.toLowerCase();
      final matched = [
        for (final skill in m.intake.skills)
          if (skill.toLowerCase().contains(needle)) skill,
      ];
      final int rank;
      if (handle.startsWith(needle) || name.startsWith(needle)) {
        rank = 0;
      } else if (handle.contains(needle) || name.contains(needle)) {
        rank = 1;
      } else if (matched.isNotEmpty) {
        rank = 2;
      } else {
        continue;
      }
      ranked.add((rank, person.searchHit(rank == 2 ? matched : const [])));
    }
    final sorted = [...ranked]..sort((a, b) => a.$1.compareTo(b.$1));
    return SearchResults(
      results: [for (final (_, hit) in sorted.take(limit ?? 20)) hit],
    );
  }

  // ---------------------------------------------------------------- requests

  Future<RequestResult> sendRequest(String slug, SendRequestBody body) async {
    final world = await fakeWorld();
    fakeMembership(world, slug);
    final me = world.me.userId;
    final intro = body.intro;
    if (intro.trim().isEmpty || intro.length > 500) {
      throw fakeInvalid('intro', 'Must be 1 to 500 characters');
    }
    if (RegExp(r'https?://|www\.', caseSensitive: false).hasMatch(intro)) {
      throw fakeInvalid('intro', 'No links allowed');
    }
    final to = world.byId(body.toUserId);
    if (to == null || to.membership == null) {
      throw fakeError(404, 'not_found', 'That person isn\'t here.');
    }
    if (to.userId == me) {
      throw fakeInvalid('toUserId', 'You can\'t send a request to yourself');
    }
    final teamId = body.teamId;
    if (teamId != null) {
      final team = world.teams[teamId];
      if (team == null) throw fakeError(404, 'not_found', 'No such team.');
      if (team.ownerId != to.userId) {
        throw fakeInvalid('toUserId', 'Must be the team owner');
      }
      if (world.teamOf(me) != null) {
        throw fakeError(409, 'conflict', 'You are already on a team.');
      }
    }
    // One request per direction and purpose.
    final duplicate = world.requests.values.any(
      (r) => r.fromId == me && r.toId == to.userId && r.teamId == teamId,
    );
    if (duplicate) {
      throw fakeError(409, 'conflict', 'You already sent this request.');
    }
    // A personal request back to someone who asked me first is accepted
    // right away, with one DM.
    if (teamId == null) {
      final mutual = world.requests.values
          .where(
            (r) =>
                r.fromId == to.userId &&
                r.toId == me &&
                r.teamId == null &&
                r.status == ConnectionStatus.pending,
          )
          .firstOrNull;
      if (mutual != null) {
        _accept(world, mutual);
        return RequestResult(request: world.connectionRequest(mutual));
      }
    }
    final request = FakeRequest(
      id: world.newId(),
      fromId: me,
      toId: to.userId,
      intro: intro,
      source: body.source ?? ConnectionSource.agent,
      teamId: teamId,
      createdAt: world.now(),
    );
    world.requests[request.id] = request;
    return RequestResult(request: world.connectionRequest(request));
  }

  Future<RequestResult> acceptRequest(String requestId) async {
    final world = await fakeWorld();
    final request = _incomingRequest(world, requestId);
    if (request.status != ConnectionStatus.accepted) {
      final teamId = request.teamId;
      if (teamId != null) {
        final team = world.teams[teamId];
        if (team == null || team.ownerId != world.me.userId) {
          throw fakeError(409, 'conflict', 'You no longer own that team.');
        }
        if (team.memberIds.length >= team.maxSize) {
          throw fakeError(409, 'conflict', 'The team is full.');
        }
        if (world.teamOf(request.fromId) != null) {
          throw fakeError(409, 'conflict', 'They are already on a team.');
        }
        team.memberIds.add(request.fromId);
      }
      _accept(world, request);
    }
    return RequestResult(request: world.connectionRequest(request));
  }

  Future<void> hideRequest(String requestId) async {
    final world = await fakeWorld();
    _incomingRequest(world, requestId).hiddenAt ??= world.now();
  }

  FakeRequest _incomingRequest(FakeWorld world, String requestId) {
    final request = world.requests[requestId];
    if (request == null) throw fakeError(404, 'not_found', 'No such request.');
    if (request.toId != world.me.userId) {
      throw fakeError(403, 'forbidden', 'Only the recipient can do that.');
    }
    return request;
  }

  void _accept(FakeWorld world, FakeRequest request) {
    final other = request.fromId == world.me.userId
        ? request.toId
        : request.fromId;
    request
      ..status = ConnectionStatus.accepted
      ..respondedAt = world.now()
      ..conversationId = world.openDm(other).id;
  }

  // ---------------------------------------------------------------- conversations

  Future<List<ConversationSummary>> listConversations(String slug) async {
    final world = await fakeWorld();
    fakeMembership(world, slug);
    final me = world.me.userId;
    final summaries = [
      for (final c in world.conversations.values)
        if (c.memberIds.contains(me)) _summary(world, c),
    ];
    // Newest activity first, then id descending.
    return summaries..sort((a, b) {
      final byTime = b.lastMessageAt.compareTo(a.lastMessageAt);
      return byTime != 0 ? byTime : b.id.compareTo(a.id);
    });
  }

  Future<MessagePage> listMessages(
    String conversationId, {
    String? before,
    String? after,
    int? limit,
  }) async {
    if (before != null && after != null) {
      throw ArgumentError('Use before or after, not both');
    }
    if (limit != null && (limit < 1 || limit > 100)) {
      throw RangeError.range(limit, 1, 100, 'limit');
    }
    final world = await fakeWorld();
    final all = _conversation(world, conversationId).messages;
    final size = limit ?? 30;
    // Ids grow with time, so comparing them orders messages. Cursors are
    // exclusive.
    if (after != null) {
      final newer = [
        for (final m in all)
          if (m.id.compareTo(after) > 0) m,
      ];
      return MessagePage(
        messages: newer.take(size).toList(),
        hasMore: newer.length > size,
      );
    }
    final older = [
      for (final m in all)
        if (before == null || m.id.compareTo(before) < 0) m,
    ];
    final start = older.length > size ? older.length - size : 0;
    return MessagePage(messages: older.sublist(start), hasMore: start > 0);
  }

  Future<Message> sendMessage(
    String conversationId,
    SendMessageBody body,
  ) async {
    final world = await fakeWorld();
    final conversation = _conversation(world, conversationId);
    final me = world.me.userId;
    if (body.body.trim().isEmpty || body.body.length > 4000) {
      throw fakeInvalid('body', 'Must be 1 to 4000 characters');
    }
    // A retry with the same clientId returns the same message.
    final retry = conversation.messages
        .where((m) => m.senderId == me && m.clientId == body.clientId)
        .firstOrNull;
    if (retry != null) return retry;
    final message = Message(
      id: world.newId(),
      conversationId: conversation.id,
      senderId: me,
      clientId: body.clientId,
      body: body.body,
      kind: MessageKind.text,
      createdAt: world.now(),
    );
    conversation.messages.add(message);
    conversation.lastReadAt[me] = message.createdAt;
    return message;
  }

  Future<DateTime> markRead(String conversationId) async {
    final world = await fakeWorld();
    final conversation = _conversation(world, conversationId);
    return conversation.lastReadAt[world.me.userId] = world.now();
  }

  FakeConversation _conversation(FakeWorld world, String id) {
    final conversation = world.conversations[id];
    if (conversation == null) {
      throw fakeError(404, 'not_found', 'No such conversation.');
    }
    if (!conversation.memberIds.contains(world.me.userId)) {
      throw fakeError(403, 'forbidden', 'Not your conversation.');
    }
    return conversation;
  }

  ConversationSummary _summary(FakeWorld world, FakeConversation c) {
    final me = world.me.userId;
    final peerId = c.kind == ConversationKind.team
        ? null
        : c.memberIds.firstWhere((id) => id != me);
    final team = c.teamId == null ? null : world.teams[c.teamId];
    final last = c.messages.lastOrNull;
    final readAt = c.lastReadAt[me];
    return ConversationSummary(
      id: c.id,
      kind: c.kind,
      peer: peerId == null ? null : world.byId(peerId)!.summary,
      team: team == null ? null : TeamRef(id: team.id, name: team.name),
      helpRequest: null,
      lastMessage: last,
      lastMessageAt: last?.createdAt ?? c.createdAt,
      unreadCount: c.messages
          .where(
            (m) =>
                m.senderId != me &&
                (readAt == null || m.createdAt.isAfter(readAt)),
          )
          .length,
      peerLastReadAt: peerId == null ? null : c.lastReadAt[peerId],
      createdAt: c.createdAt,
    );
  }

  // ---------------------------------------------------------------- chat

  /// Answers with the people whose skills match words in the message. The
  /// contract doesn't define part shapes; the fake reads and writes AI SDK
  /// text parts (`{type: text, text}`) and never sends cards.
  Future<ChatMessage> sendChat(String slug, ChatBody body) async {
    final world = await fakeWorld();
    fakeMembership(world, slug);
    final message = body.message;
    if (message.role != ChatRole.user) {
      throw fakeInvalid('message.role', 'Must be user');
    }
    world.chat.add(message);

    final text = [
      for (final part in message.parts)
        if (part['type'] == 'text' && part['text'] is String) part['text'],
    ].join(' ').toLowerCase();
    final words = text
        .split(RegExp(r'[^a-z0-9+#]+'))
        .where((w) => w.length > 1);
    final matches = [
      for (final p in world.people.values)
        if (p.membership!.intake.skills.any(
          (s) => words.any((w) => s.toLowerCase().contains(w)),
        ))
          p,
    ];
    final reply = matches.isEmpty
        ? 'I didn\'t find anyone for that yet. Try a skill, like "flutter" or '
              '"python".'
        : 'Here\'s who could help: '
              '${matches.map((p) => '${p.name} (@${p.handle})').join(', ')}.';

    final answer = ChatMessage(
      id: 'fake-assistant-${world.newId()}',
      role: ChatRole.assistant,
      parts: [
        {'type': 'text', 'text': reply},
      ],
    );
    world.chat.add(answer);
    return answer;
  }

  Future<List<ChatMessage>> getChatHistory(String slug) async {
    final world = await fakeWorld();
    fakeMembership(world, slug);
    return List.unmodifiable(world.chat);
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
