import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/api_exception.dart';
import 'package:mobile/api/models/auth.dart';
import 'package:mobile/api/models/events.dart';
import 'package:mobile/api/models/nullable.dart';

import 'fake_host.dart';

const slug = 'knighthacks-ix';

/// A host user who hasn't joined any event.
Me newcomer() => Me(profile: hostMe.profile, events: const []);

Matcher apiError(int status) =>
    throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', status));

void main() {
  late FakeHost fake;

  setUp(() => fake = FakeHost());

  test('listEvents and getEvent return Knight Hacks IX', () async {
    final events = await fake.listEvents();

    expect(events.single.slug, slug);
    expect(events.single.tracks, contains('Health'));
    expect((await fake.getEvent(slug)).name, 'Knight Hacks IX');
    await expectLater(fake.getEvent('nope'), apiError(404));
  });

  test('a member from the host getMe can read their membership', () async {
    final me = await fake.getEventMe(slug);

    expect(me.role, MemberRole.hacker);
    expect(me.verified, isFalse);
    expect(me.intake.complete, isFalse);
  });

  test('a non-member gets 403 until they join', () async {
    fake.me = newcomer();

    await expectLater(fake.getEventMe(slug), apiError(403));

    final joined = await fake.joinEvent(slug);
    expect(joined.role, MemberRole.hacker);
    expect(joined.verified, isTrue);
    expect((await fake.getEventMe(slug)).role, MemberRole.hacker);
  });

  test(
    'mentors join unverified, and joining again keeps the membership',
    () async {
      fake.me = newcomer();

      final mentor = await fake.joinEvent(
        slug,
        const JoinEventBody(role: JoinRole.mentor),
      );
      final again = await fake.joinEvent(slug);

      expect(mentor.role, MemberRole.mentor);
      expect(mentor.verified, isFalse);
      expect(again.role, MemberRole.mentor);
    },
  );

  test('joining shows up in fakeApplyChanges', () async {
    fake.me = newcomer();
    await fake.joinEvent(slug);

    final me = fake.fakeApplyChanges(fake.me);

    expect(me.events.single.slug, slug);
  });

  test('joinEvent 404s for an unknown event', () async {
    await expectLater(fake.joinEvent('nope'), apiError(404));
  });

  test('updateEventMe applies a partial update', () async {
    await fake.updateEventMe(
      slug,
      const UpdateEventMeBody(
        skills: ['flutter', 'dart'],
        experience: Nullable(Experience.intermediate),
        goal: Nullable(HackGoal.ship),
        availability: Availability.busy,
      ),
    );
    final me = await fake.updateEventMe(
      slug,
      const UpdateEventMeBody(
        looking: false,
        idea: Nullable('Study buddy app'),
      ),
    );

    expect(me.intake.skills, ['flutter', 'dart']);
    expect(me.intake.experience, Experience.intermediate);
    expect(me.intake.idea, 'Study buddy app');
    expect(me.intake.complete, isTrue);
    expect(me.availability, Availability.busy);
    expect(me.looking, isFalse);
  });

  test('updateEventMe clears a field with Nullable(null)', () async {
    await fake.updateEventMe(
      slug,
      const UpdateEventMeBody(goal: Nullable(HackGoal.win)),
    );
    final me = await fake.updateEventMe(
      slug,
      const UpdateEventMeBody(goal: Nullable(null)),
    );

    expect(me.intake.goal, isNull);
  });
}
