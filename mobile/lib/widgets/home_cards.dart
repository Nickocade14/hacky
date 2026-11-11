// The blocks of 05 Home (mobile/design/home-wireframes.svg), top to bottom.
// The wordmark, my avatar and Ask Hacky moved to the shell's header and
// button, which every page shares.

import 'package:flutter/material.dart';

import '../api/models/events.dart';
import '../api/models/search.dart';
import '../api/models/teams.dart';
import '../home/event_dates.dart';
import '../theme.dart';
import 'app_widgets.dart';
import 'auth_widgets.dart';

const _bold = FontWeight.w700;

String _capitalize(String word) =>
    word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}';

/// YOUR EVENT: my role, the event, its dates and tracks, then "Looking for a
/// team" and my availability, which save right away.
class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.event,
    required this.membership,
    required this.onLookingChanged,
    required this.onAvailabilityChanged,
  });

  final EventInfo event;
  final EventMe membership;
  final ValueChanged<bool> onLookingChanged;
  final ValueChanged<Availability> onAvailabilityChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: SectionLabel('Your event')),
              TagChip(_capitalize(membership.role.name), strong: true),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            event.name,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 24,
              fontWeight: _bold,
              letterSpacing: -0.6,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            EventDates.format(event.startsAt, event.endsAt),
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          if (event.tracks.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final track in event.tracks) TagChip(track)],
            ),
          ],
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 8),
          MergeSemantics(
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Looking for a team',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 14,
                      fontWeight: _bold,
                    ),
                  ),
                ),
                Switch(
                  key: const Key('home-looking'),
                  value: membership.looking,
                  onChanged: onLookingChanged,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          AvailabilityPicker(
            value: membership.availability,
            onChanged: onAvailabilityChanged,
          ),
        ],
      ),
    );
  }
}

/// Available · Busy · Offline, in the same style as the log in tab switch.
class AvailabilityPicker extends StatelessWidget {
  const AvailabilityPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final Availability value;
  final ValueChanged<Availability> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: AppTheme.borderRadius,
      ),
      child: Row(
        children: [
          for (final option in Availability.values)
            Expanded(child: _option(option)),
        ],
      ),
    );
  }

  Widget _option(Availability option) {
    final active = option == value;
    return Semantics(
      selected: active,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: active ? null : () => onChanged(option),
        child: AnimatedContainer(
          duration: AuthTabs.duration,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active ? AppColors.white : null,
            borderRadius: AppTheme.borderRadius,
            boxShadow: active
                ? const [
                    BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 5,
                      offset: Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            _capitalize(option.name),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? AppColors.ink : AppColors.muted,
              fontSize: 13,
              fontWeight: _bold,
            ),
          ),
        ),
      ),
    );
  }
}

/// Requests with the number of new ones (→ 09).
class RequestsRow extends StatelessWidget {
  const RequestsRow({super.key, required this.newCount, required this.onOpen});

  final int newCount;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onOpen,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        spacing: 10,
        children: [
          const Icon(Icons.mail_outline, color: AppColors.ink, size: 20),
          const Expanded(
            child: Text(
              'Requests',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 15,
                fontWeight: _bold,
              ),
            ),
          ),
          if (newCount > 0) CountBadge('$newCount new'),
          const Icon(Icons.chevron_right, color: AppColors.muted, size: 20),
        ],
      ),
    );
  }
}

/// MY TEAM: my team's name and size, or "No team yet" with Create team.
class MyTeamCard extends StatelessWidget {
  const MyTeamCard({super.key, required this.team, required this.onCreate});

  final MyTeam? team;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final team = this.team;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          const SectionLabel('My team'),
          if (team == null) ...[
            const Text(
              'No team yet',
              style: TextStyle(color: AppColors.muted, fontSize: 14),
            ),
            SecondaryButton(label: 'Create team', onPressed: onCreate),
          ] else ...[
            Text(
              team.name,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 17,
                fontWeight: _bold,
              ),
            ),
            Text(
              '${team.size} of ${team.maxSize} members'
              '${team.isOwner ? ' · You lead it' : ''}',
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

/// PEOPLE YOU MIGHT LIKE: people who know the skill I want to learn (→ 07).
/// Without wanted skills, a nudge to add some on my profile (→ 08).
class PeopleSuggestionsSection extends StatelessWidget {
  const PeopleSuggestionsSection({
    super.key,
    required this.skill,
    required this.people,
    required this.onOpenPerson,
    required this.onOpenMe,
  });

  /// The skill searched for; null when I haven't added wanted skills.
  final String? skill;
  final List<SearchHit> people;
  final ValueChanged<SearchHit> onOpenPerson;
  final VoidCallback onOpenMe;

  static String subtitle(SearchHit person) => [
    '@${person.handle}',
    if (person.skills.isNotEmpty) person.skills.take(3).join(', '),
  ].join(' · ');

  @override
  Widget build(BuildContext context) {
    final skill = this.skill;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        const SectionLabel('People you might like'),
        if (skill == null)
          AppCard(
            onTap: onOpenMe,
            child: const Text(
              'Add skills you want to learn on your profile, and people who '
              'know them show up here.',
              style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.5),
            ),
          )
        else if (people.isEmpty)
          Text(
            'No one here knows $skill yet.',
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          )
        else
          for (final person in people)
            PersonRow(
              person: person,
              subtitle: subtitle(person),
              onTap: () => onOpenPerson(person),
            ),
      ],
    );
  }
}
