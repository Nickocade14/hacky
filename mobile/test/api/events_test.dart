import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/api_exception.dart';
import 'package:mobile/api/models/auth.dart';
import 'package:mobile/api/models/events.dart';
import 'package:mobile/api/models/nullable.dart';

import 'fixtures.dart';
import 'support.dart';

void main() {
  late ApiHarness api;

  setUp(() => api = ApiHarness());

  group('listEvents', () {
    test('GETs /api/events with the bearer token and unwraps events', () async {
      api.respond({
        'events': [eventInfoJson],
      });

      final events = await api.client.listEvents();

      expect(api.lastCall, 'GET /api/events');
      expect(api.lastAuth, 'Bearer $testToken');
      final event = events.single;
      expect(event.slug, 'knighthacks-ix');
      expect(event.tracks, ['AI', 'Health', 'Fintech']);
      expect(event.startsAt, DateTime.utc(2026, 11, 14, 13));
      expect(event.endsAt, isNull);
      expect(event.theme.brand, '#5b3df5');
      expect(event.theme.brandContrast, isNull);
      expect(event.theme.raw['heroImage'], '/assets/kh-hero.png');
    });
  });

  group('getEvent', () {
    test('GETs the event by slug', () async {
      api.respond(eventInfoJson);

      final event = await api.client.getEvent('knighthacks-ix');

      expect(api.lastCall, 'GET /api/events/knighthacks-ix');
      expect(event.name, 'Knight Hacks IX');
    });

    test('encodes the slug so it stays one path segment', () async {
      api.respond(eventInfoJson);

      await api.client.getEvent('../me');

      expect(api.last.url.pathSegments, ['api', 'events', '../me']);
    });

    test('throws not_found for an unknown event', () async {
      api.fail(404, 'not_found');

      await expectLater(
        api.client.getEvent('nope'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'not_found')),
      );
    });
  });

  group('joinEvent', () {
    test('POSTs an empty body by default and parses EventMe', () async {
      api.respond(eventMeJson);

      final me = await api.client.joinEvent('knighthacks-ix');

      expect(api.lastCall, 'POST /api/events/knighthacks-ix/join');
      expect(api.lastBody, <String, dynamic>{});
      expect(me.role, MemberRole.hacker);
      expect(me.availability, Availability.available);
      expect(me.intake.experience, Experience.intermediate);
      expect(me.intake.goal, isNull);
      expect(me.intake.motivations, [Motivation.build, Motivation.meet]);
    });

    test('sends the role when given', () async {
      api.respond({...eventMeJson, 'role': 'mentor', 'verified': false});

      final me = await api.client.joinEvent(
        'knighthacks-ix',
        const JoinEventBody(role: JoinRole.mentor),
      );

      expect(api.lastBody, {'role': 'mentor'});
      expect(me.role, MemberRole.mentor);
      expect(me.verified, isFalse);
    });
  });

  group('getEventMe', () {
    test('GETs my membership', () async {
      api.respond(eventMeJson);

      final me = await api.client.getEventMe('knighthacks-ix');

      expect(api.lastCall, 'GET /api/events/knighthacks-ix/me');
      expect(me.intake.skills, ['flutter', 'firebase']);
      expect(me.intake.complete, isFalse);
    });

    test('throws forbidden when I am not a member', () async {
      api.fail(403, 'forbidden');

      await expectLater(
        api.client.getEventMe('knighthacks-ix'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)),
      );
    });
  });

  group('updateEventMe', () {
    test('PATCHes only the fields that are set', () async {
      api.respond(eventMeJson);

      await api.client.updateEventMe(
        'knighthacks-ix',
        const UpdateEventMeBody(
          skills: ['dart'],
          looking: false,
          availability: Availability.busy,
          motivations: [Motivation.learn],
          experience: Nullable(Experience.beginner),
        ),
      );

      expect(api.lastCall, 'PATCH /api/events/knighthacks-ix/me');
      expect(api.lastBody, {
        'skills': ['dart'],
        'looking': false,
        'availability': 'busy',
        'motivations': ['learn'],
        'experience': 'beginner',
      });
    });

    test('sends null to clear a nullable field', () async {
      api.respond(eventMeJson);

      await api.client.updateEventMe(
        'knighthacks-ix',
        const UpdateEventMeBody(goal: Nullable(null), idea: Nullable(null)),
      );

      expect(api.lastBody, {'goal': null, 'idea': null});
    });
  });

  test('an unknown Availability is an invalid_response', () async {
    api.respond({...eventMeJson, 'availability': 'asleep'});

    await expectLater(
      api.client.getEventMe('knighthacks-ix'),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'invalid_response'),
      ),
    );
  });
}
