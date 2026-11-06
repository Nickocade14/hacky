import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../api/models/people.dart';
import '../routes.dart';
import '../shell/screen_load.dart';
import '../widgets/app_widgets.dart';
import '../widgets/person_profile_widgets.dart';
import '../widgets/relation_actions.dart';

/// 07 Person profile (pushed from 05, 06, 09 and 12;
/// mobile/design/people-wireframes.svg). Opened with `Navigate.toPerson`.
///
/// Loads `GET /api/events/{slug}/people/{handle}` (`ApiClient.getPerson`);
/// its `relation.state` decides the button in [RelationActions]: Connect
/// (intro sheet, then `sendRequest`), Request sent, Accept / Not now, or
/// Message → 11 (`Navigate.toChatThread`).
///
/// The wireframe's ••• → Block isn't here yet: `ApiClient` has no
/// `POST /api/blocks` method.
class PersonProfileScreen extends StatefulWidget {
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
  State<PersonProfileScreen> createState() => _PersonProfileScreenState();
}

class _PersonProfileScreenState extends State<PersonProfileScreen>
    with ScreenLoad<PersonProfileScreen> {
  PersonDetail? _person;

  /// Where I stand with them; changes after each action.
  Relation? _relation;

  /// 404: they aren't in the event, or one of us blocked the other.
  bool _missing = false;

  @override
  void initState() {
    super.initState();
    runLoad(_load);
  }

  Future<void> _load() async {
    try {
      final person = await widget.api.getPerson(
        widget.eventSlug,
        widget.handle,
      );
      if (!mounted) return;
      setState(() {
        _person = person;
        _relation = person.relation;
        _missing = false;
      });
    } on ApiException catch (e) {
      if (e.statusCode != 404) rethrow;
      if (mounted) setState(() => _missing = true);
    }
  }

  Future<void> _openChat(String conversationId) => Navigate.toChatThread(
    context,
    eventSlug: widget.eventSlug,
    conversationId: conversationId,
  );

  @override
  Widget build(BuildContext context) {
    final person = _person;
    final problem = this.problem;
    return SignedInPage(
      title: 'Profile',
      body: switch ((person, problem)) {
        _ when _missing => const PageColumn(
          children: [
            MascotMessage(
              title: 'This profile isn’t available',
              body: 'They may have left the event.',
            ),
          ],
        ),
        (null, final String message) => ProblemView(
          message: message,
          onRetry: () => runLoad(_load),
        ),
        (null, _) => const LoadingView(label: 'Loading profile…'),
        (final PersonDetail loaded, _) => _content(loaded),
      },
    );
  }

  Widget _content(PersonDetail person) {
    final sections = profileSections(person);
    return PageColumn(
      children: [
        ProfileHeaderCard(
          person: person,
          action: RelationActions(
            api: widget.api,
            eventSlug: widget.eventSlug,
            person: person,
            relation: _relation ?? person.relation,
            onChanged: (relation) => setState(() => _relation = relation),
            onMessage: _openChat,
          ),
        ),
        if (sections.isNotEmpty)
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 22,
              children: sections,
            ),
          ),
      ],
    );
  }
}
