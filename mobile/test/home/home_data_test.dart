import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/fake/fake_world.dart';
import 'package:mobile/api/models/events.dart';
import 'package:mobile/home/home_data.dart';

import '../support/screen_harness.dart';

void main() {
  test('loads the event, my membership, my team and my requests', () async {
    final (:api, store: _) = signedInFakeApi();

    final data = await HomeData.load(api, fakeEventSlug);

    expect(data.event.name, 'Knight Hacks IX');
    expect(data.membership.looking, isTrue);
    expect(data.team, isNull);
    // Jordan is waiting; Leo's request is hidden and Priya's is accepted.
    expect(data.requests, hasLength(3));
    expect(data.newRequestCount, 1);
  });

  test('copyWith changes only looking or availability', () async {
    final (:api, store: _) = signedInFakeApi();
    final membership = await api.getEventMe(fakeEventSlug);

    final busy = membership.copyWith(availability: Availability.busy);
    expect(busy.availability, Availability.busy);
    expect(busy.looking, membership.looking);
    expect(busy.copyWith(looking: false).looking, isFalse);
  });

  test('suggests people who know the first skill I want to learn', () async {
    final (:api, store: _) = signedInFakeApi();
    final membership = await api.updateEventMe(
      fakeEventSlug,
      const UpdateEventMeBody(skillsWanted: ['flutter', 'go']),
    );

    final suggestions = await PeopleSuggestions.load(
      api,
      fakeEventSlug,
      membership.intake,
    );

    expect(suggestions.skill, 'flutter');
    expect(suggestions.people.map((p) => p.handle), ['sam_mentor']);
  });

  test('suggests no one without wanted skills', () async {
    final (:api, store: _) = signedInFakeApi();
    final membership = await api.getEventMe(fakeEventSlug);

    final suggestions = await PeopleSuggestions.load(
      api,
      fakeEventSlug,
      membership.intake,
    );

    expect(suggestions.skill, isNull);
    expect(suggestions.people, isEmpty);
  });
}
