import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/api_exception.dart';
import 'package:mobile/api/fake/fake_world.dart';
import 'package:mobile/api/models/people.dart';
import 'package:mobile/api/models/requests.dart';
import 'package:mobile/api/models/teams.dart';

import 'fake_host.dart';

const slug = 'knighthacks-ix';

Matcher apiError(int status) =>
    throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', status));

void main() {
  late FakeHost fake;
  late FakeWorld world;

  String idOf(String handle) => world.byHandle(handle)!.userId;

  setUp(() async {
    fake = FakeHost();
    world = await fake.fakeWorld();
  });

  group('listRequests', () {
    test('lists the seeded requests newest first', () async {
      final requests = await fake.listRequests(slug);

      expect(requests.map((r) => r.person.handle), [
        'jordan_ux',
        'leo_builds',
        'priya_codes',
      ]);
      final jordan = requests[0];
      expect(jordan.direction, RequestDirection.incoming);
      expect(jordan.status, ConnectionStatus.pending);
      expect(jordan.hiddenAt, isNull);
      final leo = requests[1];
      expect(leo.status, ConnectionStatus.pending);
      expect(leo.hiddenAt, isNotNull);
      expect(leo.source, ConnectionSource.qr);
      final priya = requests[2];
      expect(priya.status, ConnectionStatus.accepted);
      expect(priya.conversationId, isNotNull);
    });

    test('includes what I send and hide', () async {
      final sent = await fake.sendRequest(
        slug,
        SendRequestBody(toUserId: idOf('sam_mentor'), intro: 'Hi Sam'),
      );
      final jordanId = (await fake.listRequests(slug))
          .firstWhere((r) => r.person.handle == 'jordan_ux')
          .id;
      await fake.hideRequest(jordanId);

      final requests = await fake.listRequests(slug);

      expect(requests.first.id, sent.request.id);
      expect(requests.first.direction, RequestDirection.outgoing);
      expect(requests.first.hiddenAt, isNull);
      expect(requests.firstWhere((r) => r.id == jordanId).hiddenAt, isNotNull);
    });

    test('Leo\'s hidden request makes him an incoming relation', () async {
      final leo = await fake.getPerson(slug, 'leo_builds');

      expect(leo.relation.state, RelationState.incoming);
    });

    test('403s outside my events', () async {
      await expectLater(fake.listRequests('other'), apiError(403));
    });
  });

  group('sendRequest', () {
    test('creates a pending outgoing request', () async {
      final result = await fake.sendRequest(
        slug,
        SendRequestBody(toUserId: idOf('sam_mentor'), intro: 'Can you help?'),
      );

      final request = result.request;
      expect(request.direction, RequestDirection.outgoing);
      expect(request.status, ConnectionStatus.pending);
      expect(request.source, ConnectionSource.agent);
      expect(request.person.handle, 'sam_mentor');
      expect(request.conversationId, isNull);
      final sam = await fake.getPerson(slug, 'sam_mentor');
      expect(sam.relation.state, RelationState.outgoing);
    });

    test('a request back to Jordan accepts theirs and opens a DM', () async {
      final result = await fake.sendRequest(
        slug,
        SendRequestBody(toUserId: idOf('jordan_ux'), intro: 'Yes, let\'s!'),
      );

      expect(result.request.status, ConnectionStatus.accepted);
      expect(result.request.direction, RequestDirection.incoming);
      expect(result.request.conversationId, isNotNull);
      expect(world.conversations[result.request.conversationId], isNotNull);
    });

    test('sending the same request twice is a conflict', () async {
      final body = SendRequestBody(toUserId: idOf('sam_mentor'), intro: 'Hi');
      await fake.sendRequest(slug, body);

      await expectLater(fake.sendRequest(slug, body), apiError(409));
    });

    test('rejects links, empty intros, unknown people and myself', () async {
      await expectLater(
        fake.sendRequest(
          slug,
          SendRequestBody(
            toUserId: idOf('sam_mentor'),
            intro: 'See https://x.dev',
          ),
        ),
        apiError(400),
      );
      await expectLater(
        fake.sendRequest(
          slug,
          SendRequestBody(toUserId: idOf('sam_mentor'), intro: ' '),
        ),
        apiError(400),
      );
      await expectLater(
        fake.sendRequest(
          slug,
          const SendRequestBody(toUserId: 'nobody', intro: 'Hi'),
        ),
        apiError(404),
      );
      await expectLater(
        fake.sendRequest(
          slug,
          SendRequestBody(toUserId: world.me.userId, intro: 'Hi'),
        ),
        apiError(400),
      );
    });

    test('a team request must go to the owner', () async {
      final teamId = world.teams.keys.single;

      await expectLater(
        fake.sendRequest(
          slug,
          SendRequestBody(
            toUserId: idOf('leo_builds'),
            intro: 'Can I join?',
            teamId: teamId,
          ),
        ),
        apiError(400),
      );

      final result = await fake.sendRequest(
        slug,
        SendRequestBody(
          toUserId: idOf('maya_ml'),
          intro: 'Can I join?',
          teamId: teamId,
        ),
      );
      expect(result.request.team!.name, 'Rash Decisions');
      expect(result.request.status, ConnectionStatus.pending);
    });

    test('I can\'t ask to join a team while on one', () async {
      await fake.createTeam(slug, const CreateTeamBody(name: 'Mine'));

      await expectLater(
        fake.sendRequest(
          slug,
          SendRequestBody(
            toUserId: idOf('maya_ml'),
            intro: 'Can I join?',
            teamId: world.teams.values.first.id,
          ),
        ),
        apiError(409),
      );
    });
  });

  group('acceptRequest', () {
    String jordanRequestId() => world.requests.values
        .firstWhere((r) => r.fromId == idOf('jordan_ux'))
        .id;

    test('accepts Jordan\'s request and opens a DM', () async {
      final result = await fake.acceptRequest(jordanRequestId());

      expect(result.request.status, ConnectionStatus.accepted);
      expect(result.request.respondedAt, isNotNull);
      final dm = world.conversations[result.request.conversationId]!;
      expect(dm.messages.single.body, contains('Jordan Lee'));
    });

    test('accepting twice returns the same conversation', () async {
      final first = await fake.acceptRequest(jordanRequestId());
      final second = await fake.acceptRequest(jordanRequestId());

      expect(second.request.conversationId, first.request.conversationId);
    });

    test('a team join request adds them to my team', () async {
      final team = await fake.createTeam(slug, const CreateTeamBody(name: 'T'));
      final request = FakeRequest(
        id: world.newId(),
        fromId: idOf('jordan_ux'),
        toId: world.me.userId,
        intro: 'Let me in!',
        source: ConnectionSource.profile,
        teamId: team.id,
        createdAt: world.now(),
      );
      world.requests[request.id] = request;

      await fake.acceptRequest(request.id);

      final updated = await fake.getTeam(slug, team.id);
      expect(updated.members.map((m) => m.handle), [
        'demo_hacker',
        'jordan_ux',
      ]);
    });

    test('a full team is a conflict', () async {
      final team = await fake.createTeam(
        slug,
        const CreateTeamBody(name: 'Solo', maxSize: 1),
      );
      final request = FakeRequest(
        id: world.newId(),
        fromId: idOf('priya_codes'),
        toId: world.me.userId,
        intro: 'Room for one more?',
        source: ConnectionSource.profile,
        teamId: team.id,
        createdAt: world.now(),
      );
      world.requests[request.id] = request;

      await expectLater(fake.acceptRequest(request.id), apiError(409));
    });

    test('only the recipient can accept, and unknown ids 404', () async {
      final mine = await fake.sendRequest(
        slug,
        SendRequestBody(toUserId: idOf('sam_mentor'), intro: 'Hi'),
      );

      await expectLater(fake.acceptRequest(mine.request.id), apiError(403));
      await expectLater(fake.acceptRequest('nope'), apiError(404));
    });
  });

  group('hideRequest', () {
    test('sets hiddenAt on an incoming request', () async {
      final request = world.requests.values.firstWhere(
        (r) => r.fromId == idOf('jordan_ux'),
      );

      await fake.hideRequest(request.id);

      expect(world.connectionRequest(request).hiddenAt, isNotNull);
      expect(request.status, ConnectionStatus.pending);
    });

    test('can\'t hide my own outgoing request', () async {
      final mine = await fake.sendRequest(
        slug,
        SendRequestBody(toUserId: idOf('sam_mentor'), intro: 'Hi'),
      );

      await expectLater(fake.hideRequest(mine.request.id), apiError(403));
    });
  });
}
