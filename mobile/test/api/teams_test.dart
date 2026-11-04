import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/api_exception.dart';
import 'package:mobile/api/models/teams.dart';

import 'fixtures.dart';
import 'support.dart';

void main() {
  late ApiHarness api;

  setUp(() => api = ApiHarness());

  group('getMyTeam', () {
    test('GETs my team in the event', () async {
      api.respond({
        'team': {
          'id': '6716a3f2c9e77b0012ab0201',
          'name': 'Rash Decisions',
          'isOwner': false,
          'size': 2,
          'maxSize': 4,
        },
      });

      final team = await api.client.getMyTeam('knighthacks-ix');

      expect(api.lastCall, 'GET /api/events/knighthacks-ix/me/team');
      expect(api.lastAuth, 'Bearer $testToken');
      expect(team!.name, 'Rash Decisions');
      expect(team.isOwner, isFalse);
      expect(team.size, 2);
    });

    test('returns null when I am on no team', () async {
      api.respond({'team': null});

      expect(await api.client.getMyTeam('knighthacks-ix'), isNull);
    });

    test('a body without team is an invalid_response', () async {
      api.respond(<String, dynamic>{});

      await expectLater(
        api.client.getMyTeam('knighthacks-ix'),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'invalid_response'),
        ),
      );
    });
  });

  group('createTeam', () {
    test('POSTs the name and only the optional fields that are set', () async {
      api.respond(teamDetailJson, 201);

      final team = await api.client.createTeam(
        'knighthacks-ix',
        const CreateTeamBody(name: 'Rash Decisions', maxSize: 4),
      );

      expect(api.lastCall, 'POST /api/events/knighthacks-ix/teams');
      expect(api.lastBody, {'name': 'Rash Decisions', 'maxSize': 4});
      expect(team.owner.handle, 'maya_ml');
      expect(team.members.first.handle, 'maya_ml');
    });

    test('sends every field when given', () async {
      api.respond(teamDetailJson, 201);

      await api.client.createTeam(
        'knighthacks-ix',
        const CreateTeamBody(
          name: 'Rash Decisions',
          idea: 'Skin rash triage',
          track: 'Health',
          wantedSkills: ['flutter'],
          maxSize: 3,
        ),
      );

      expect(api.lastBody, {
        'name': 'Rash Decisions',
        'idea': 'Skin rash triage',
        'track': 'Health',
        'wantedSkills': ['flutter'],
        'maxSize': 3,
      });
    });

    test('throws conflict when I am already on a team', () async {
      api.fail(409, 'conflict', 'You are already on a team');

      await expectLater(
        api.client.createTeam(
          'knighthacks-ix',
          const CreateTeamBody(name: 'Second'),
        ),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'conflict')),
      );
    });
  });

  group('getTeam', () {
    test('GETs the team with its members', () async {
      api.respond(teamDetailJson);

      final team = await api.client.getTeam(
        'knighthacks-ix',
        '6716a3f2c9e77b0012ab0201',
      );

      expect(
        api.lastCall,
        'GET /api/events/knighthacks-ix/teams/6716a3f2c9e77b0012ab0201',
      );
      expect(team, isA<TeamSummary>());
      expect(team.track, isNull);
      expect(team.wantedSkills, ['flutter']);
      expect(team.members.map((m) => m.handle), ['maya_ml', 'leo_builds']);
      expect(team.members.last.photoUrl, isNull);
    });
  });

  test('TeamRef parses id and name', () {
    final ref = TeamRef.fromJson({'id': 'abc', 'name': 'Team'});

    expect(ref.id, 'abc');
    expect(ref.name, 'Team');
  });
}
