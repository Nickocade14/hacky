import '../api/models/auth.dart';

/// Which event the signed-in screens show. Every event screen takes its slug
/// by constructor; the shell picks it once from `GET /api/me`.
///
/// The app shows one event at a time: the first one in `Me.events`. With no
/// event yet, Home lists the events to join and the shell switches to the one
/// the user joins.
abstract final class CurrentEvent {
  /// The slug to open for [me], or null when they haven't joined an event.
  static String? slugFor(Me me) => me.events.firstOrNull?.slug;
}
