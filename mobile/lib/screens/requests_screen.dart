import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../widgets/app_widgets.dart';

/// 09 Requests (pushed from 05 and 10, mobile/design/requests-wireframes.svg).
/// Opened with `Navigate.toRequests`.
///
/// Placeholder. The finished screen loads `GET /api/events/{slug}/requests`
/// (`ApiClient.listRequests`) into Incoming and Outgoing tabs. Accept →
/// `acceptRequest`, then the chat opens (`Navigate.toChatThread`); Not now →
/// `hideRequest`. A person's name opens 07 (`Navigate.toPerson`).
class RequestsScreen extends StatelessWidget {
  const RequestsScreen({
    super.key,
    required this.api,
    required this.eventSlug,
  });

  final ApiClient api;
  final String eventSlug;

  @override
  Widget build(BuildContext context) {
    return const SignedInPage(
      title: 'Requests',
      body: ScreenPlaceholder(
        number: '09',
        summary: 'Requests people sent you, and the ones you sent.',
      ),
    );
  }
}
