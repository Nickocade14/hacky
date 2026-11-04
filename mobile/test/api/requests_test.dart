import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/api_exception.dart';
import 'package:mobile/api/models/requests.dart';

import 'fixtures.dart';
import 'support.dart';

void main() {
  late ApiHarness api;

  setUp(() => api = ApiHarness());

  group('sendRequest', () {
    test('POSTs toUserId and intro, plus source and teamId when set', () async {
      api.respond({'request': connectionRequestJson}, 201);

      final result = await api.client.sendRequest(
        'knighthacks-ix',
        const SendRequestBody(
          toUserId: '6716a3f2c9e77b0012ab0001',
          intro: 'Want to build the rash triage app together?',
          source: ConnectionSource.profile,
          teamId: '6716a3f2c9e77b0012ab0201',
        ),
      );

      expect(api.lastCall, 'POST /api/events/knighthacks-ix/requests');
      expect(api.lastAuth, 'Bearer $testToken');
      expect(api.lastBody, {
        'toUserId': '6716a3f2c9e77b0012ab0001',
        'intro': 'Want to build the rash triage app together?',
        'source': 'profile',
        'teamId': '6716a3f2c9e77b0012ab0201',
      });
      final request = result.request;
      expect(request.direction, RequestDirection.outgoing);
      expect(request.status, ConnectionStatus.pending);
      expect(request.source, ConnectionSource.profile);
      expect(request.person.handle, 'maya_ml');
      expect(request.team!.name, 'Rash Decisions');
      expect(request.createdAt, DateTime.utc(2026, 11, 14, 15, 30));
      expect(request.respondedAt, isNull);
      expect(request.hiddenAt, isNull);
    });

    test('leaves out source and teamId when not set', () async {
      api.respond({'request': connectionRequestJson}, 201);

      await api.client.sendRequest(
        'knighthacks-ix',
        const SendRequestBody(toUserId: 'u1', intro: 'Hi!'),
      );

      expect(api.lastBody, {'toUserId': 'u1', 'intro': 'Hi!'});
    });

    test('a mutual request comes back accepted with a conversation', () async {
      api.respond({
        'request': {
          ...connectionRequestJson,
          'status': 'accepted',
          'team': null,
          'conversationId': '6716a3f2c9e77b0012ab0301',
          'respondedAt': '2026-11-14T15:31:00.000Z',
        },
      }, 201);

      final result = await api.client.sendRequest(
        'knighthacks-ix',
        const SendRequestBody(toUserId: 'u1', intro: 'Hi!'),
      );

      expect(result.request.status, ConnectionStatus.accepted);
      expect(result.request.team, isNull);
      expect(result.request.conversationId, '6716a3f2c9e77b0012ab0301');
    });

    test('throws conflict when already requested', () async {
      api.fail(409, 'conflict');

      await expectLater(
        api.client.sendRequest(
          'knighthacks-ix',
          const SendRequestBody(toUserId: 'u1', intro: 'Hi!'),
        ),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'conflict')),
      );
    });
  });

  group('acceptRequest', () {
    test('POSTs to the accept route with no body', () async {
      api.respond({
        'request': {
          ...connectionRequestJson,
          'direction': 'incoming',
          'status': 'accepted',
          'conversationId': '6716a3f2c9e77b0012ab0301',
          'respondedAt': '2026-11-14T16:00:00.000Z',
          'hiddenAt': null,
        },
      });

      final result = await api.client.acceptRequest('6716a3f2c9e77b0012ab0101');

      expect(
        api.lastCall,
        'POST /api/requests/6716a3f2c9e77b0012ab0101/accept',
      );
      expect(api.lastBody, isNull);
      expect(result.request.direction, RequestDirection.incoming);
      expect(result.request.conversationId, '6716a3f2c9e77b0012ab0301');
    });

    test('throws conflict when the team is full', () async {
      api.fail(409, 'conflict', 'The team is full');

      await expectLater(
        api.client.acceptRequest('6716a3f2c9e77b0012ab0101'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'The team is full',
          ),
        ),
      );
    });
  });

  group('hideRequest', () {
    test('POSTs to the hide route', () async {
      api.respond({'ok': true});

      await api.client.hideRequest('6716a3f2c9e77b0012ab0101');

      expect(api.lastCall, 'POST /api/requests/6716a3f2c9e77b0012ab0101/hide');
      expect(api.lastAuth, 'Bearer $testToken');
    });

    test('throws not_found for an unknown request', () async {
      api.fail(404, 'not_found');

      await expectLater(
        api.client.hideRequest('6716a3f2c9e77b0012ab9999'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
      );
    });
  });

  test('hiddenAt is read when present', () {
    final request = ConnectionRequest.fromJson({
      ...connectionRequestJson,
      'direction': 'incoming',
      'hiddenAt': '2026-11-14T17:00:00.000Z',
    });

    expect(request.hiddenAt, DateTime.utc(2026, 11, 14, 17));
  });
}
