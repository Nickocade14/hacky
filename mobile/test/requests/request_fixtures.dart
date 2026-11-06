import 'package:mobile/api/models/auth.dart';
import 'package:mobile/api/models/people.dart';
import 'package:mobile/api/models/requests.dart';
import 'package:mobile/api/models/teams.dart';

final requestTime = DateTime.utc(2026, 11, 14, 15);

PersonSummary person(
  String handle,
  String name, {
  MemberRole role = MemberRole.hacker,
}) => PersonSummary(
  userId: '6716a3f2c9e7000000000${handle.length.toString().padLeft(3, '0')}',
  handle: handle,
  name: name,
  hackyStyle: const {},
  photoUrl: null,
  role: role,
);

/// A request as the API returns it, pending and incoming unless told.
ConnectionRequest request(
  String id, {
  PersonSummary? from,
  RequestDirection direction = RequestDirection.incoming,
  ConnectionStatus status = ConnectionStatus.pending,
  String intro = 'Want to build something together?',
  ConnectionSource source = ConnectionSource.agent,
  TeamRef? team,
  String? conversationId,
  DateTime? createdAt,
  DateTime? respondedAt,
  DateTime? hiddenAt,
}) => ConnectionRequest(
  id: id,
  direction: direction,
  status: status,
  intro: intro,
  source: source,
  person: from ?? person('maya_ml', 'Maya Chen'),
  team: team,
  conversationId: conversationId,
  createdAt: createdAt ?? requestTime,
  respondedAt: respondedAt,
  hiddenAt: hiddenAt,
);

/// [r] as the server returns it once accepted.
ConnectionRequest acceptedCopy(ConnectionRequest r, String conversationId) =>
    ConnectionRequest(
      id: r.id,
      direction: r.direction,
      status: ConnectionStatus.accepted,
      intro: r.intro,
      source: r.source,
      person: r.person,
      team: r.team,
      conversationId: conversationId,
      createdAt: r.createdAt,
      respondedAt: requestTime.add(const Duration(minutes: 5)),
      hiddenAt: r.hiddenAt,
    );
