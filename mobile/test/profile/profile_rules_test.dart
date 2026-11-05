import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/profile/profile_rules.dart';

void main() {
  group('ProfileRules (limits from docs/openapi.yaml)', () {
    test('name is 1 to 80 characters after trimming', () {
      expect(ProfileRules.name('   '), contains('Enter your name'));
      expect(ProfileRules.name(' ${'a' * 80} '), isNull);
      expect(ProfileRules.name('a' * 81), 'Use at most 80 characters.');
    });

    test('bio is at most 500 characters', () {
      expect(ProfileRules.bio(''), isNull);
      expect(ProfileRules.bio('a' * 500), isNull);
      expect(ProfileRules.bio('a' * 501), contains('500'));
    });

    test('links get https:// added and must be full https links', () {
      expect(ProfileRules.normalizeLink(' github.com/me '), 'https://github.com/me');
      expect(ProfileRules.normalizeLink('https://x.dev'), 'https://x.dev');
      expect(ProfileRules.normalizeLink('  '), '');
      expect(ProfileRules.link(''), isNull);
      expect(ProfileRules.link('github.com/me'), isNull);
      expect(ProfileRules.link('http://x.dev'), 'Use an https:// link.');
      expect(ProfileRules.link('nope'), contains('full link'));
      expect(ProfileRules.link('https://'), contains('full link'));
      expect(ProfileRules.link('https://x.dev/${'a' * 300}'), contains('300'));
    });

    test('a new tag must be new, short and fit in the list', () {
      expect(ProfileRules.newTag(' ', const []), 'Type something to add.');
      expect(ProfileRules.newTag('a' * 41, const []), contains('40'));
      expect(ProfileRules.newTag('react', const ['React']), contains('already'));
      expect(
        ProfileRules.newTag('go', List.generate(30, (i) => 't$i')),
        contains('up to 30'),
      );
      expect(ProfileRules.newTag(' Go ', const ['React']), isNull);
    });

    test('a saved list has at most 30 tags of 1 to 40 characters', () {
      expect(ProfileRules.tags(const ['React']), isNull);
      expect(ProfileRules.tags(List.generate(31, (i) => 't$i')), isNotNull);
      expect(ProfileRules.tags(['a' * 41]), isNotNull);
    });

    test('track is at most 80 and idea at most 2000 characters', () {
      expect(ProfileRules.track(null), isNull);
      expect(ProfileRules.track('a' * 81), isNotNull);
      expect(ProfileRules.idea('a' * 2000), isNull);
      expect(ProfileRules.idea('a' * 2001), contains('2,000'));
    });
  });
}
