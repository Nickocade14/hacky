import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../widgets/app_widgets.dart';

/// 11 Chat thread (pushed from 07, 09 and 10,
/// mobile/design/messages-wireframes.svg). Opened with
/// `Navigate.toChatThread`.
///
/// Placeholder. The finished screen loads
/// `GET /api/conversations/{id}/messages` (`ApiClient.listMessages`, oldest
/// first, paged), sends with `sendMessage` and a clientId, and marks the chat
/// read (`markRead`). The header (peer name) comes from the conversation in
/// `listConversations(eventSlug)`; ••• → View profile 07 · Block.
class ChatThreadScreen extends StatelessWidget {
  const ChatThreadScreen({
    super.key,
    required this.api,
    required this.eventSlug,
    required this.conversationId,
  });

  final ApiClient api;
  final String eventSlug;
  final String conversationId;

  @override
  Widget build(BuildContext context) {
    return const SignedInPage(
      title: 'Chat',
      body: ScreenPlaceholder(
        number: '11',
        summary: 'Your messages with one person or team.',
      ),
    );
  }
}
