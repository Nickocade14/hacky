import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/api_exception.dart';
import 'package:mobile/api/models/auth.dart';
import 'package:mobile/api/models/me.dart';
import 'package:mobile/api/models/nullable.dart';

import 'fixtures.dart';
import 'support.dart';

void main() {
  late ApiHarness api;

  setUp(() => api = ApiHarness());

  group('getMe', () {
    test('GETs /api/me with the bearer token', () async {
      api.respond(meJson);

      final me = await api.client.getMe();

      expect(api.lastCall, 'GET /api/me');
      expect(api.lastAuth, 'Bearer $testToken');
      expect(me.profile.bio, 'Flutter and coffee.');
      expect(me.events.single.verified, isTrue);
    });
  });

  group('updateProfile', () {
    test('PATCHes only the fields that are set', () async {
      api.respond({...publicProfileJson, 'name': 'Nico'});

      final profile = await api.client.updateProfile(
        const UpdateProfileBody(
          name: 'Nico',
          hackyStyle: {'look': 'knit', 'color': 'teal'},
          links: ProfileLinks(website: 'https://nico.dev'),
        ),
      );

      expect(api.lastCall, 'PATCH /api/me/profile');
      expect(api.lastBody, {
        'name': 'Nico',
        'hackyStyle': {'look': 'knit', 'color': 'teal'},
        'links': {'website': 'https://nico.dev'},
      });
      expect(profile.name, 'Nico');
    });

    test('sends bio: null to clear the bio', () async {
      api.respond({...publicProfileJson, 'bio': null});

      final profile = await api.client.updateProfile(
        const UpdateProfileBody(bio: Nullable(null)),
      );

      expect(api.lastBody, {'bio': null});
      expect(profile.bio, isNull);
    });

    test('refuses an empty body without calling the server', () async {
      expect(
        () => api.client.updateProfile(const UpdateProfileBody()),
        throwsArgumentError,
      );
      expect(api.requests, isEmpty);
    });

    test('throws the field details on invalid input', () async {
      api.respond({
        'error': {
          'code': 'invalid_input',
          'message': 'Invalid input',
          'details': [
            {
              'path': ['links', 'github'],
              'message': 'Must start with https://',
            },
          ],
        },
      }, 400);

      await expectLater(
        api.client.updateProfile(
          const UpdateProfileBody(links: ProfileLinks(github: 'http://x')),
        ),
        throwsA(
          isA<ApiException>().having((e) => e.details.single.path, 'path', [
            'links',
            'github',
          ]),
        ),
      );
    });
  });
}
