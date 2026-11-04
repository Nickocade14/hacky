import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/api_exception.dart';
import 'package:mobile/api/models/auth.dart';
import 'package:mobile/api/models/events.dart';
import 'package:mobile/api/models/people.dart';

import 'fake_host.dart';

const slug = 'knighthacks-ix';

Matcher apiError(int status) =>
    throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', status));

void main() {
  late FakeHost fake;

  setUp(() => fake = FakeHost());

  test('getPerson returns a full, realistic profile', () async {
    final maya = await fake.getPerson(slug, 'maya_ml');

    expect(maya.name, 'Maya Patel');
    expect(maya.role, MemberRole.hacker);
    expect(maya.skills, contains('pytorch'));
    expect(maya.goal, HackGoal.win);
    expect(maya.links.github, startsWith('https://'));
    expect(maya.relation.state, RelationState.none);
  });

  test('the mentor is a mentor', () async {
    final sam = await fake.getPerson(slug, 'sam_mentor');

    expect(sam.role, MemberRole.mentor);
    expect(sam.availability, Availability.busy);
  });

  test('relations come from the seeded requests', () async {
    final priya = await fake.getPerson(slug, 'priya_codes');
    final jordan = await fake.getPerson(slug, 'jordan_ux');

    expect(priya.relation.state, RelationState.accepted);
    expect(priya.relation.conversationId, isNotNull);
    expect(jordan.relation.state, RelationState.incoming);
    expect(jordan.relation.requestId, isNotNull);
    expect(jordan.relation.conversationId, isNull);
  });

  test('getPerson 404s for an unknown handle', () async {
    await expectLater(fake.getPerson(slug, 'ghost'), apiError(404));
  });

  test('getPerson 403s outside my events', () async {
    fake.me = Me(profile: hostMe.profile, events: const []);

    await expectLater(fake.getPerson(slug, 'maya_ml'), apiError(403));
  });
}
