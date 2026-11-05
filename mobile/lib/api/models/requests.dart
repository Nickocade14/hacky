// Connection request schemas from docs/openapi.yaml: ConnectionRequest,
// SendRequestBody, RequestResult, plus their enums.

import 'json_read.dart';
import 'people.dart';
import 'teams.dart';

/// `ConnectionStatus`.
enum ConnectionStatus { pending, accepted }

/// `ConnectionSource`.
enum ConnectionSource { agent, qr, profile }

/// `ConnectionRequest.direction`, relative to the viewer.
enum RequestDirection { incoming, outgoing }

/// `ConnectionRequest`. [direction] and [person] are relative to the viewer.
class ConnectionRequest {
  const ConnectionRequest({
    required this.id,
    required this.direction,
    required this.status,
    required this.intro,
    required this.source,
    required this.person,
    required this.team,
    required this.conversationId,
    required this.createdAt,
    required this.respondedAt,
    this.hiddenAt,
  });

  final String id;
  final RequestDirection direction;
  final ConnectionStatus status;
  final String intro;
  final ConnectionSource source;
  final PersonSummary person;

  /// Set when this is a request to join a team.
  final TeamRef? team;
  final String? conversationId;
  final DateTime createdAt;
  final DateTime? respondedAt;

  /// Only on incoming requests, when I hid it ("Not now").
  final DateTime? hiddenAt;

  factory ConnectionRequest.fromJson(Map<String, dynamic> json) {
    final team = readNullableObject(json, 'team');
    return ConnectionRequest(
      id: readString(json, 'id'),
      direction: readEnum(json, 'direction', RequestDirection.values),
      status: readEnum(json, 'status', ConnectionStatus.values),
      intro: readString(json, 'intro'),
      source: readEnum(json, 'source', ConnectionSource.values),
      person: PersonSummary.fromJson(readObject(json, 'person')),
      team: team == null ? null : TeamRef.fromJson(team),
      conversationId: readNullableString(json, 'conversationId'),
      createdAt: readDateTime(json, 'createdAt'),
      respondedAt: readNullableDateTime(json, 'respondedAt'),
      hiddenAt: readNullableDateTime(json, 'hiddenAt'),
    );
  }
}

/// `SendRequestBody`: `POST /api/events/{slug}/requests`.
class SendRequestBody {
  const SendRequestBody({
    required this.toUserId,
    required this.intro,
    this.source,
    this.teamId,
  });

  final String toUserId;

  /// 1 to 500 characters, no links.
  final String intro;

  /// The server uses `agent` when it isn't sent.
  final ConnectionSource? source;

  /// Request to join this team; [toUserId] must be its owner.
  final String? teamId;

  Map<String, dynamic> toJson() => {
    'toUserId': toUserId,
    'intro': intro,
    if (source != null) 'source': source!.name,
    'teamId': ?teamId,
  };
}

/// `RequestResult`.
class RequestResult {
  const RequestResult({required this.request});

  final ConnectionRequest request;

  factory RequestResult.fromJson(Map<String, dynamic> json) => RequestResult(
    request: ConnectionRequest.fromJson(readObject(json, 'request')),
  );
}
