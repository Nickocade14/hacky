// What Hacky's cards can do, handed down from 12 Hacky chat. Cards never call
// the API or navigate themselves; they ask these callbacks, like CardActions
// in the original Hacky (react/src/hacky/cards.jsx).

import '../api/models/people.dart';
import '../api/models/requests.dart';
import '../api/models/teams.dart';

/// The rules `SendRequestBody.intro` has in docs/openapi.yaml.
abstract final class IntroRules {
  static const maxLength = 500;
  static final _link = RegExp(r'https?://|www\.', caseSensitive: false);

  /// Why [intro] can't be sent yet, or null when it can.
  static String? problem(String intro) {
    final text = intro.trim();
    if (text.isEmpty) return 'Write a short intro first.';
    if (text.length > maxLength) return 'Keep it under $maxLength characters.';
    if (_link.hasMatch(text)) return 'Intros can’t contain links.';
    return null;
  }

  /// The intro the Connect sheet starts with.
  static String opening({
    required String myName,
    required PersonSummary to,
    TeamRef? team,
  }) {
    final them = firstName(to.name);
    final me = firstName(myName);
    return team == null
        ? 'Hi $them! I’m $me. Hacky thought we could team up. Want to chat?'
        : 'Hi $them! I’m $me. I’d like to join ${team.name}. Is there room?';
  }

  static String firstName(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    return words.first.isEmpty ? 'there' : words.first;
  }
}

/// The callbacks and state Hacky's cards share.
class HackyCardActions {
  const HackyCardActions({
    required this.myName,
    required this.busy,
    required this.openPerson,
    required this.openChat,
    required this.ask,
    required this.sendRequest,
    required this.sentRequest,
  });

  /// My name, for the intros I write.
  final String myName;

  /// True while Hacky answers; answer chips wait.
  final bool busy;

  /// Opens 07 for this handle.
  final void Function(String handle) openPerson;

  /// Opens 11 for this conversation.
  final void Function(String conversationId) openChat;

  /// Sends this text to Hacky as my next message.
  final void Function(String text) ask;

  /// `POST /api/events/{slug}/requests`; remembered by [sentRequest].
  final Future<RequestResult> Function(SendRequestBody body) sendRequest;

  /// The request I sent from this chat to [userId] (for [teamId]), if any.
  final RequestResult? Function(String userId, String? teamId) sentRequest;
}

/// The requests sent from this chat, so a card that scrolls away and back
/// still shows "Request sent".
class SentRequests {
  final _sent = <String, RequestResult>{};

  static String _key(String userId, String? teamId) => '$userId:${teamId ?? ''}';

  RequestResult? find(String userId, String? teamId) =>
      _sent[_key(userId, teamId)];

  void remember(SendRequestBody body, RequestResult result) =>
      _sent[_key(body.toUserId, body.teamId)] = result;

  /// Brings back what `GET /api/events/{slug}/requests` already knows when
  /// the chat opens: the requests I sent and the people I'm connected with.
  /// Without it, the cards in my history would offer Connect again after a
  /// restart.
  void restore(Iterable<ConnectionRequest> requests) {
    for (final request in requests) {
      if (request.status == ConnectionStatus.accepted ||
          request.direction == RequestDirection.outgoing) {
        _sent.putIfAbsent(
          _key(request.person.userId, request.team?.id),
          () => RequestResult(request: request),
        );
      }
    }
  }
}
