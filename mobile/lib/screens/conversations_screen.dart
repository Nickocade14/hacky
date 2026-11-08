import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../routes.dart';
import '../widgets/app_widgets.dart';

/// 10 Conversations (Chats tab, mobile/design/messages-wireframes.svg).
///
/// Placeholder with a working Requests → 09 button. The finished screen loads
/// `GET /api/events/{slug}/conversations` (`ApiClient.listConversations`),
/// newest first, with unread badges; a row opens 11 with
/// `Navigate.toChatThread`.
class ConversationsScreen extends StatelessWidget {
  const ConversationsScreen({
    super.key,
    required this.api,
    required this.eventSlug,
  });

  final ApiClient api;
  final String eventSlug;

  @override
  Widget build(BuildContext context) {
    return SignedInPage(
      title: 'Chats',
      actions: [
        TextButton(
          onPressed: () => Navigate.toRequests(context, eventSlug: eventSlug),
          child: const Text('Requests'),
        ),
        const SizedBox(width: 8),
      ],
      body: const ScreenPlaceholder(
        number: '10',
        summary: 'Your direct messages, team chats and mentor help.',
      ),
    );
  }
}
