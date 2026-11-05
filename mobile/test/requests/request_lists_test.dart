import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/models/auth.dart';
import 'package:mobile/api/models/requests.dart';
import 'package:mobile/api/models/teams.dart';
import 'package:mobile/requests/request_lists.dart';

import 'request_fixtures.dart';

void main() {
  group('RequestLists.from', () {
    test('splits requests the way the tabs show them, in order', () {
      final lists = RequestLists.from([
        request('a'),
        request('b', hiddenAt: requestTime),
        request('c', direction: RequestDirection.outgoing),
        request('d', status: ConnectionStatus.accepted, conversationId: 'x'),
        request(
          'e',
          direction: RequestDirection.outgoing,
          status: ConnectionStatus.accepted,
          conversationId: 'y',
        ),
        request('f'),
      ]);

      List<String> ids(List<ConnectionRequest> list) => [
        for (final r in list) r.id,
      ];
      expect(ids(lists.incoming), ['a', 'f']);
      expect(ids(lists.hidden), ['b']);
      expect(ids(lists.outgoing), ['c']);
      expect(ids(lists.acceptedIncoming), ['d']);
      expect(ids(lists.acceptedOutgoing), ['e']);
      expect(lists.incomingTabEmpty, isFalse);
      expect(lists.outgoingTabEmpty, isFalse);
    });

    test('an accepted request that was hidden counts as accepted', () {
      final lists = RequestLists.from([
        request(
          'a',
          status: ConnectionStatus.accepted,
          hiddenAt: requestTime,
          conversationId: 'x',
        ),
      ]);
      expect(lists.hidden, isEmpty);
      expect(lists.acceptedIncoming.single.id, 'a');
    });

    test('no requests means both tabs are empty', () {
      final lists = RequestLists.from(const []);
      expect(lists.incomingTabEmpty, isTrue);
      expect(lists.outgoingTabEmpty, isTrue);
    });
  });

  test('replacing swaps one request by id and keeps the order', () {
    final list = [request('a'), request('b'), request('c')];
    final updated = acceptedCopy(list[1], 'conv');
    final result = list.replacing(updated);
    expect([for (final r in result) r.id], ['a', 'b', 'c']);
    expect(result[1].status, ConnectionStatus.accepted);
    expect(result[0], same(list[0]));
  });

  test('hiddenOn copies the request with hiddenAt set', () {
    final r = request('a', intro: 'Hi!');
    final at = requestTime.add(const Duration(hours: 1));
    final hidden = r.hiddenOn(at);
    expect(hidden.hiddenAt, at);
    expect(hidden.id, 'a');
    expect(hidden.intro, 'Hi!');
    expect(hidden.status, ConnectionStatus.pending);
    expect(r.hiddenAt, isNull);
  });

  group('RequestKind.of', () {
    test('a request with a team is a team join', () {
      final r = request(
        'a',
        from: person('sam', 'Sam Rivera', role: MemberRole.mentor),
        team: const TeamRef(id: 't', name: 'Byte Me'),
      );
      expect(RequestKind.of(r), RequestKind.teamJoin);
    });

    test('personal requests follow the other person’s role', () {
      RequestKind of(MemberRole role) =>
          RequestKind.of(request('a', from: person('p', 'P', role: role)));
      expect(of(MemberRole.hacker), RequestKind.teammate);
      expect(of(MemberRole.mentor), RequestKind.mentor);
      expect(of(MemberRole.sponsor), RequestKind.contact);
      expect(of(MemberRole.organizer), RequestKind.contact);
      expect(RequestKind.teamJoin.label, 'Team join');
    });
  });

  group('RequestTexts', () {
    test('ago gives a short relative time', () {
      final now = requestTime;
      String ago(Duration d) => RequestTexts.ago(now.subtract(d), now);
      expect(ago(const Duration(seconds: 20)), 'just now');
      expect(ago(const Duration(minutes: 5)), '5 min ago');
      expect(ago(const Duration(hours: 2)), '2 h ago');
      expect(ago(const Duration(hours: 30)), 'yesterday');
      expect(ago(const Duration(days: 3)), '3 days ago');
    });

    test('subtitle shows the handle and when it was sent or accepted', () {
      final now = requestTime.add(const Duration(hours: 2));
      expect(RequestTexts.subtitle(request('a'), now), '@maya_ml · 2 h ago');
      final accepted = acceptedCopy(request('a'), 'conv');
      expect(
        RequestTexts.subtitle(accepted, now),
        '@maya_ml · accepted 1 h ago',
      );
    });

    test('source and team lines', () {
      expect(RequestTexts.source(ConnectionSource.agent), 'via Hacky');
      expect(RequestTexts.source(ConnectionSource.qr), 'via QR code');
      expect(RequestTexts.source(ConnectionSource.profile), 'from profile');

      const team = TeamRef(id: 't', name: 'Byte Me');
      expect(RequestTexts.team(request('a')), isNull);
      expect(
        RequestTexts.team(request('a', team: team)),
        'Wants to join Byte Me',
      );
      expect(
        RequestTexts.team(
          request('a', team: team, direction: RequestDirection.outgoing),
        ),
        'You asked to join Byte Me',
      );
    });
  });
}
