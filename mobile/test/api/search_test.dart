import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/api_exception.dart';
import 'package:mobile/api/models/auth.dart';
import 'package:mobile/api/models/people.dart';

import 'fixtures.dart';
import 'support.dart';

void main() {
  late ApiHarness api;

  setUp(() => api = ApiHarness());

  group('search', () {
    test('GETs /api/search with event and q', () async {
      api.respond({
        'results': [
          {
            ...personSummaryJson,
            'skills': ['python', 'pytorch'],
            'matchedSkills': ['pytorch'],
          },
        ],
      });

      final found = await api.client.search(event: 'knighthacks-ix', q: 'tor');

      expect(api.lastCall, 'GET /api/search?event=knighthacks-ix&q=tor');
      expect(api.lastAuth, 'Bearer $testToken');
      final hit = found.results.single;
      expect(hit, isA<PersonSummary>());
      expect(hit.handle, 'maya_ml');
      expect(hit.skills, ['python', 'pytorch']);
      expect(hit.matchedSkills, ['pytorch']);
    });

    test('sends role and limit when given, and encodes q', () async {
      api.respond({'results': <Object>[]});

      final found = await api.client.search(
        event: 'knighthacks-ix',
        q: 'c++ & go',
        role: MemberRole.mentor,
        limit: 5,
      );

      expect(api.last.url.queryParameters, {
        'event': 'knighthacks-ix',
        'q': 'c++ & go',
        'role': 'mentor',
        'limit': '5',
      });
      expect(found.results, isEmpty);
    });

    test('refuses an empty or too long q without calling the server', () {
      expect(
        () => api.client.search(event: 'knighthacks-ix', q: ''),
        throwsArgumentError,
      );
      expect(
        () => api.client.search(event: 'knighthacks-ix', q: 'a' * 101),
        throwsArgumentError,
      );
      expect(api.requests, isEmpty);
    });

    test('refuses a limit outside 1 to 50', () {
      expect(
        () => api.client.search(event: 'knighthacks-ix', q: 'a', limit: 0),
        throwsRangeError,
      );
      expect(
        () => api.client.search(event: 'knighthacks-ix', q: 'a', limit: 51),
        throwsRangeError,
      );
      expect(api.requests, isEmpty);
    });

    test('throws forbidden when I am not in the event', () async {
      api.fail(403, 'forbidden');

      await expectLater(
        api.client.search(event: 'other-event', q: 'a'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'forbidden')),
      );
    });
  });
}
