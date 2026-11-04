import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/api_exception.dart';
import 'package:mobile/api/models/teams.dart';

import 'fake_host.dart';

const slug = 'knighthacks-ix';

Matcher apiError(int status) =>
    throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', status));

void main() {
  late FakeHost fake;

  setUp(() => fake = FakeHost());

  test('I start on no team', () async {
    expect(await fake.getMyTeam(slug), isNull);
  });

  test('the seeded team has Maya as owner and Leo as member', () async {
    final world = await fake.fakeWorld();
    final teamId = world.teams.keys.single;

    final team = await fake.getTeam(slug, teamId);

    expect(team.name, 'Rash Decisions');
    expect(team.owner.handle, 'maya_ml');
    expect(team.members.map((m) => m.handle), ['maya_ml', 'leo_builds']);
    expect(team.size, 2);
    expect(team.maxSize, 4);
  });

  test('createTeam makes me owner and first member', () async {
    final team = await fake.createTeam(
      slug,
      const CreateTeamBody(name: 'Rent Split', wantedSkills: ['go']),
    );

    expect(team.owner.handle, 'demo_hacker');
    expect(team.members.single.handle, 'demo_hacker');
    expect(team.maxSize, 4);
    expect(team.wantedSkills, ['go']);

    final mine = await fake.getMyTeam(slug);
    expect(mine!.id, team.id);
    expect(mine.isOwner, isTrue);
    expect(mine.size, 1);
    expect((await fake.getTeam(slug, team.id)).name, 'Rent Split');
  });

  test('a second team is a conflict', () async {
    await fake.createTeam(slug, const CreateTeamBody(name: 'One'));

    await expectLater(
      fake.createTeam(slug, const CreateTeamBody(name: 'Two')),
      apiError(409),
    );
  });

  test('createTeam validates like the server', () async {
    await expectLater(
      fake.createTeam(slug, const CreateTeamBody(name: '')),
      apiError(400),
    );
    await expectLater(
      fake.createTeam(slug, const CreateTeamBody(name: 'Big', maxSize: 9)),
      apiError(400),
    );
  });

  test('getTeam 404s for an unknown team', () async {
    await expectLater(
      fake.getTeam(slug, '6716a3f2c9e7000000009999'),
      apiError(404),
    );
  });
}
