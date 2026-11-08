import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../widgets/app_widgets.dart';

/// 07 Person profile (pushed from 05, 06, 09 and 12;
/// mobile/design/people-wireframes.svg). Opened with `Navigate.toPerson`.
///
/// Placeholder. The finished screen loads
/// `GET /api/events/{slug}/people/{handle}` (`ApiClient.getPerson`); its
/// `relation.state` decides the button: Connect (intro sheet, then
/// `sendRequest`), Request sent, Accept / Not now, or Message → 11
/// (`Navigate.toChatThread`). ••• → Block.
class PersonProfileScreen extends StatelessWidget {
  const PersonProfileScreen({
    super.key,
    required this.api,
    required this.eventSlug,
    required this.handle,
  });

  final ApiClient api;
  final String eventSlug;

  /// Whose profile, without the "@".
  final String handle;

  @override
  Widget build(BuildContext context) {
    return SignedInPage(
      title: 'Profile',
      body: ScreenPlaceholder(
        number: '07',
        summary: 'The profile of @$handle: about, skills, track and idea, '
            'and a button to connect.',
      ),
    );
  }
}
