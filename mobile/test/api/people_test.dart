import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/api_exception.dart';
import 'package:mobile/api/models/auth.dart';
import 'package:mobile/api/models/events.dart';
import 'package:mobile/api/models/people.dart';

import 'fixtures.dart';
import 'support.dart';

void main() {
  late ApiHarness api;

  setUp(() => api = ApiHarness());

  group('getPerson', () {
    test('GETs the person by event and handle', () async {
      api.respond(personDetailJson);

      final person = await api.client.getPerson('knighthacks-ix', 'maya_ml');

      expect(api.lastCall, 'GET /api/events/knighthacks-ix/people/maya_ml');
      expect(api.lastAuth, 'Bearer $testToken');
      expect(person.name, 'Maya Patel');
      expect(person.photoUrl, '/assets/people/maya.png');
      expect(person.links.linkedin, 'https://linkedin.com/in/maya');
      expect(person.role, MemberRole.hacker);
      expect(person.availability, Availability.busy);
      expect(person.experience, Experience.advanced);
      expect(person.goal, HackGoal.win);
      expect(person.summary, isNull);
      expect(person.motivations, [Motivation.compete]);
      expect(person.relation.state, RelationState.incoming);
      expect(person.relation.requestId, '6716a3f2c9e77b0012ab0101');
      expect(person.relation.conversationId, isNull);
    });

    test('is both a PublicProfile and a Membership', () async {
      api.respond(personDetailJson);

      final person = await api.client.getPerson('knighthacks-ix', 'maya_ml');

      expect(person, isA<PublicProfile>());
      expect(person, isA<Membership>());
    });

    test('throws not_found when blocked or not in the event', () async {
      api.fail(404, 'not_found');

      await expectLater(
        api.client.getPerson('knighthacks-ix', 'ghost'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'not_found')),
      );
    });

    test('a missing relation is an invalid_response', () async {
      api.respond({...personDetailJson}..remove('relation'));

      await expectLater(
        api.client.getPerson('knighthacks-ix', 'maya_ml'),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'invalid_response'),
        ),
      );
    });
  });

  test('PersonSummary parses the compact person', () {
    final person = PersonSummary.fromJson(personSummaryJson);

    expect(person.handle, 'maya_ml');
    expect(person.hackyStyle['color'], 'teal');
    expect(person.role, MemberRole.hacker);
  });
}
