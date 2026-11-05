import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/api_exception.dart';
import 'package:mobile/api/models/auth.dart';

import 'fake_host.dart';

const slug = 'knighthacks-ix';

void main() {
  late FakeHost fake;

  setUp(() => fake = FakeHost());

  Future<List<String>> handles(String q, {MemberRole? role, int? limit}) async {
    final found = await fake.search(
      event: slug,
      q: q,
      role: role,
      limit: limit,
    );
    return [for (final hit in found.results) hit.handle];
  }

  test('matches part of a name or handle, case-insensitive', () async {
    expect(await handles('MAY'), ['maya_ml']);
    expect(await handles('shah'), ['priya_codes']);
  });

  test('ranks starts-with, then contains, then skills', () async {
    // "le": Leo starts with it, Jordan Lee contains it.
    final byName = await fake.search(event: slug, q: 'le');
    expect(
      [for (final h in byName.results) h.handle],
      ['leo_builds', 'jordan_ux'],
    );
    expect(byName.results.first.matchedSkills, isEmpty);

    // "ma": Maya starts with it; Jordan only matches through "figma".
    final mixed = await fake.search(event: slug, q: 'ma');
    expect([for (final h in mixed.results) h.handle], ['maya_ml', 'jordan_ux']);
    expect(mixed.results.last.matchedSkills, ['figma']);
  });

  test('skill matches list the matched skills', () async {
    final found = await fake.search(event: slug, q: 'torch');

    expect(found.results.single.handle, 'maya_ml');
    expect(found.results.single.matchedSkills, ['pytorch']);
    expect(found.results.single.skills, contains('python'));
  });

  test('filters by role and respects limit', () async {
    expect(await handles('a', role: MemberRole.mentor), ['sam_mentor']);
    expect(await handles('a', limit: 2), hasLength(2));
  });

  test('leaves me out', () async {
    expect(await handles('demo'), isEmpty);
  });

  test('returns an empty list when nothing matches', () async {
    expect(await handles('zzz'), isEmpty);
  });

  test('validates q and limit like the real client', () {
    expect(() => fake.search(event: slug, q: ''), throwsArgumentError);
    expect(() => fake.search(event: slug, q: 'a', limit: 51), throwsRangeError);
  });

  test('403s outside my events', () async {
    await expectLater(
      fake.search(event: 'other', q: 'a'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)),
    );
  });
}
