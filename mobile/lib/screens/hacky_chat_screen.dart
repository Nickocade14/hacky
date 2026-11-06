import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models/auth.dart';
import '../widgets/app_widgets.dart';

/// 12 Hacky chat (Hacky tab, also from 05;
/// mobile/design/hacky-chat-wireframes.svg).
///
/// Placeholder. The finished screen loads the history
/// (`GET /api/events/{slug}/chat`, `ApiClient.getChatHistory`) and sends with
/// `sendChat`. People cards open 07 (`Navigate.toPerson`); suggestion chips
/// fill the composer.
class HackyChatScreen extends StatelessWidget {
  const HackyChatScreen({
    super.key,
    required this.api,
    required this.me,
    required this.eventSlug,
  });

  final ApiClient api;

  /// The signed-in user, for the greeting ("Hi Ethan!").
  final Me me;
  final String eventSlug;

  @override
  Widget build(BuildContext context) {
    return const SignedInPage(
      title: 'Hacky',
      body: ScreenPlaceholder(
        number: '12',
        summary: 'Ask Hacky to find teammates and mentors, or to help you '
            'pick a track.',
      ),
    );
  }
}
