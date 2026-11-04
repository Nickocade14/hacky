import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/api_exception.dart';
import 'package:mobile/api/models/auth.dart';
import 'package:mobile/api/models/me.dart';
import 'package:mobile/api/models/nullable.dart';

import 'fake_host.dart';

void main() {
  late FakeHost fake;

  setUp(() => fake = FakeHost());

  test('updateProfile changes only the fields that are set', () async {
    final profile = await fake.updateProfile(
      const UpdateProfileBody(
        name: 'Demo H.',
        links: ProfileLinks(github: 'https://github.com/demo'),
      ),
    );

    expect(profile.name, 'Demo H.');
    expect(profile.handle, 'demo_hacker');
    expect(profile.links.github, 'https://github.com/demo');
    expect(profile.bio, isNull);
  });

  test('updateProfile sets and clears the bio', () async {
    final set = await fake.updateProfile(
      const UpdateProfileBody(bio: Nullable('Hi there')),
    );
    expect(set.bio, 'Hi there');

    final cleared = await fake.updateProfile(
      const UpdateProfileBody(bio: Nullable(null)),
    );
    expect(cleared.bio, isNull);
  });

  test('updateProfile rejects invalid input like the server', () async {
    await expectLater(
      fake.updateProfile(const UpdateProfileBody(name: '  ')),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', 'invalid_input')
            .having((e) => e.details.single.path, 'path', ['name']),
      ),
    );
    expect(
      () => fake.updateProfile(const UpdateProfileBody()),
      throwsArgumentError,
    );
  });

  test('fakeApplyChanges shows edits in the host getMe result', () async {
    expect(fake.fakeApplyChanges(hostMe), same(hostMe));

    await fake.updateProfile(const UpdateProfileBody(name: 'New Name'));
    final me = fake.fakeApplyChanges(hostMe);

    expect(me.profile.name, 'New Name');
    expect(me.events.single.slug, 'knighthacks-ix');
  });

  test('a signed-out user gets the host 401', () async {
    fake.loggedIn = false;

    await expectLater(
      fake.updateProfile(const UpdateProfileBody(name: 'X')),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
    );
  });

  test('each user gets their own data', () async {
    await fake.updateProfile(const UpdateProfileBody(name: 'First User'));

    fake.me = Me(
      profile: PublicProfile(
        userId: '6716a3f2c9e70000000b0b0b',
        handle: 'other',
        name: 'Other',
        hackyStyle: const {},
        photoUrl: null,
        bio: null,
        links: const ProfileLinks(),
        isDemo: true,
      ),
      events: const [],
    );
    final world = await fake.fakeWorld();

    expect(world.me.name, 'Other');
    expect(world.me.membership, isNull);
  });
}
