import 'package:flutter/widgets.dart';

/// Route names. Screens navigate by name so they don't import each other.
/// For the signed-in screens, use the [Navigate] helpers below.
abstract final class Routes {
  static const login = '/login';
  static const register = '/register';

  /// Type the emailed sign-up code. Argument: the email it went to (`String`).
  static const verifyEmail = '/verify-email';

  /// Ask for a reset code, then type it with the new password.
  static const forgotPassword = '/forgot-password';

  /// The signed-in shell: the header and its pages (12 Hacky first).
  /// Argument: the signed-in user (`Me?`). Loaded from the API when null.
  static const home = '/home';

  /// 07 Person profile. Argument: [PersonArgs].
  static const person = '/person';

  /// 09 Requests. Argument: [RequestsArgs].
  static const requests = '/requests';

  /// 11 Chat thread. Argument: [ChatThreadArgs].
  static const chatThread = '/chat-thread';
}

/// What [Routes.person] opens: someone's profile in an event.
class PersonArgs {
  const PersonArgs({required this.eventSlug, required this.handle});

  final String eventSlug;
  final String handle;
}

/// What [Routes.requests] opens: my requests in an event.
class RequestsArgs {
  const RequestsArgs({required this.eventSlug});

  final String eventSlug;
}

/// What [Routes.chatThread] opens: one conversation in an event.
class ChatThreadArgs {
  const ChatThreadArgs({required this.eventSlug, required this.conversationId});

  final String eventSlug;
  final String conversationId;
}

/// Opens the pushed signed-in screens (07, 09, 11) on top of the shell.
/// Each one returns when the user comes back, so the caller can reload.
abstract final class Navigate {
  static Future<void> toPerson(
    BuildContext context, {
    required String eventSlug,
    required String handle,
  }) => Navigator.of(context).pushNamed<void>(
    Routes.person,
    arguments: PersonArgs(eventSlug: eventSlug, handle: handle),
  );

  static Future<void> toRequests(
    BuildContext context, {
    required String eventSlug,
  }) => Navigator.of(context).pushNamed<void>(
    Routes.requests,
    arguments: RequestsArgs(eventSlug: eventSlug),
  );

  static Future<void> toChatThread(
    BuildContext context, {
    required String eventSlug,
    required String conversationId,
  }) => Navigator.of(context).pushNamed<void>(
    Routes.chatThread,
    arguments: ChatThreadArgs(
      eventSlug: eventSlug,
      conversationId: conversationId,
    ),
  );
}
