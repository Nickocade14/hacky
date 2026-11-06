import '../api/models/auth.dart';
import '../api/models/requests.dart';

/// What a request is about, for the tag on its card.
enum RequestKind {
  /// A personal request between hackers.
  teammate('Teammate'),

  /// A personal request with a mentor.
  mentor('Mentor'),

  /// A request to join a team (`team` is set).
  teamJoin('Team join'),

  /// A personal request with a sponsor or an organizer.
  contact('Contact');

  const RequestKind(this.label);

  final String label;

  static RequestKind of(ConnectionRequest request) {
    if (request.team != null) return teamJoin;
    return switch (request.person.role) {
      MemberRole.hacker => teammate,
      MemberRole.mentor => mentor,
      MemberRole.sponsor || MemberRole.organizer => contact,
    };
  }
}

/// `GET /api/events/{slug}/requests` split the way 09 Requests shows it,
/// like the original Hacky (react/src/social/messages.js `splitRequests`).
/// Each list keeps the server's order.
class RequestLists {
  const RequestLists({
    required this.incoming,
    required this.hidden,
    required this.outgoing,
    required this.acceptedIncoming,
    required this.acceptedOutgoing,
  });

  factory RequestLists.from(List<ConnectionRequest> requests) {
    final incoming = <ConnectionRequest>[];
    final hidden = <ConnectionRequest>[];
    final outgoing = <ConnectionRequest>[];
    final acceptedIncoming = <ConnectionRequest>[];
    final acceptedOutgoing = <ConnectionRequest>[];
    for (final r in requests) {
      final isIncoming = r.direction == RequestDirection.incoming;
      final list = switch (r.status) {
        ConnectionStatus.accepted =>
          isIncoming ? acceptedIncoming : acceptedOutgoing,
        ConnectionStatus.pending when !isIncoming => outgoing,
        ConnectionStatus.pending when r.hiddenAt != null => hidden,
        ConnectionStatus.pending => incoming,
      };
      list.add(r);
    }
    return RequestLists(
      incoming: incoming,
      hidden: hidden,
      outgoing: outgoing,
      acceptedIncoming: acceptedIncoming,
      acceptedOutgoing: acceptedOutgoing,
    );
  }

  /// Incoming and waiting for me: Accept or Not now. Home's "N new" badge
  /// counts the same requests.
  final List<ConnectionRequest> incoming;

  /// Incoming ones I answered "Not now". They can still be accepted.
  final List<ConnectionRequest> hidden;

  /// Sent by me and still pending.
  final List<ConnectionRequest> outgoing;

  final List<ConnectionRequest> acceptedIncoming;
  final List<ConnectionRequest> acceptedOutgoing;

  bool get incomingTabEmpty =>
      incoming.isEmpty && hidden.isEmpty && acceptedIncoming.isEmpty;

  bool get outgoingTabEmpty => outgoing.isEmpty && acceptedOutgoing.isEmpty;
}

/// Local updates after an action, so the list changes before the next load.
extension RequestListUpdates on List<ConnectionRequest> {
  /// This list with the request that has [updated]'s id replaced by it.
  List<ConnectionRequest> replacing(ConnectionRequest updated) => [
    for (final r in this) r.id == updated.id ? updated : r,
  ];
}

/// A copy of a request with [ConnectionRequest.hiddenAt] set ("Not now").
extension HiddenCopy on ConnectionRequest {
  ConnectionRequest hiddenOn(DateTime at) => ConnectionRequest(
    id: id,
    direction: direction,
    status: status,
    intro: intro,
    source: source,
    person: person,
    team: team,
    conversationId: conversationId,
    createdAt: createdAt,
    respondedAt: respondedAt,
    hiddenAt: at,
  );
}

/// Short English texts for a request's card.
abstract final class RequestTexts {
  /// "via Hacky", "via QR code", "from their profile".
  static String source(ConnectionSource source) => switch (source) {
    ConnectionSource.agent => 'via Hacky',
    ConnectionSource.qr => 'via QR code',
    ConnectionSource.profile => 'from profile',
  };

  /// How long ago [time] was, e.g. "just now", "5 min ago", "2 h ago",
  /// "yesterday", "3 days ago".
  static String ago(DateTime time, DateTime now) {
    final elapsed = now.difference(time);
    if (elapsed.inMinutes < 1) return 'just now';
    if (elapsed.inHours < 1) return '${elapsed.inMinutes} min ago';
    if (elapsed.inDays < 1) return '${elapsed.inHours} h ago';
    if (elapsed.inDays == 1) return 'yesterday';
    return '${elapsed.inDays} days ago';
  }

  /// The muted line under the name: "@maya · 2 h ago", or
  /// "@maya · accepted yesterday" once accepted.
  static String subtitle(ConnectionRequest request, DateTime now) {
    final responded = request.respondedAt;
    final when = request.status == ConnectionStatus.accepted && responded != null
        ? 'accepted ${ago(responded, now)}'
        : ago(request.createdAt, now);
    return '@${request.person.handle} · $when';
  }

  /// Team join requests: who wants what, e.g. "Wants to join Byte Me".
  static String? team(ConnectionRequest request) {
    final team = request.team;
    if (team == null) return null;
    return request.direction == RequestDirection.incoming
        ? 'Wants to join ${team.name}'
        : 'You asked to join ${team.name}';
  }
}
