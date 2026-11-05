import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../widgets/app_widgets.dart';

/// 06 Search people (People tab, mobile/design/people-wireframes.svg).
///
/// Placeholder. The finished screen searches the server as the user types
/// (`GET /api/search?q=&event=`, `ApiClient.search`), shows each hit as a
/// [PersonRow] with the matching part in bold, and opens 07 on tap with
/// `Navigate.toPerson`.
class SearchPeopleScreen extends StatelessWidget {
  const SearchPeopleScreen({
    super.key,
    required this.api,
    required this.eventSlug,
  });

  final ApiClient api;

  /// The event to search in.
  final String eventSlug;

  @override
  Widget build(BuildContext context) {
    return const SignedInPage(
      title: 'People',
      body: ScreenPlaceholder(
        number: '06',
        summary: 'Search people in your event by name, handle or skill.',
      ),
    );
  }
}
