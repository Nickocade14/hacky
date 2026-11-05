// The blocks of 07 Person profile (mobile/design/people-wireframes.svg), top
// to bottom: who they are with the action button, then About, Skills,
// Wants to learn, Track · Idea and Links.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/models/auth.dart';
import '../api/models/people.dart';
import '../people/person_labels.dart';
import '../theme.dart';
import 'app_widgets.dart';

const _bold = FontWeight.w700;

/// Avatar, name, "@handle · Hacker", their availability and "Looking for a
/// team", and [action] (the [RelationActions] button) underneath.
class ProfileHeaderCard extends StatelessWidget {
  const ProfileHeaderCard({
    super.key,
    required this.person,
    required this.action,
  });

  final PersonDetail person;
  final Widget action;

  /// "@maya_ml · Hacker", or "@sam · Mentor · Verified".
  static String handleLine(PersonDetail person) => [
    '@${person.handle}',
    PersonLabels.role(person.role),
    if (person.verified && person.role != MemberRole.hacker) 'Verified',
  ].join(' · ');

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: PersonAvatar(name: person.name, size: 76)),
          const SizedBox(height: 14),
          Semantics(
            header: true,
            child: Text(
              person.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 22,
                fontWeight: _bold,
                letterSpacing: -0.4,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            handleLine(person),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              TagChip(
                PersonLabels.availability(person.availability),
                strong: person.availability == Availability.available,
              ),
              if (person.looking) const TagChip('Looking for a team'),
            ],
          ),
          const SizedBox(height: 18),
          action,
        ],
      ),
    );
  }
}

/// A muted label over one block of the profile.
class ProfileSection extends StatelessWidget {
  const ProfileSection({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [SectionLabel(label), child],
    );
  }
}

/// A paragraph in a profile section.
class ProfileText extends StatelessWidget {
  const ProfileText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: AppColors.ink, fontSize: 15, height: 1.55),
    );
  }
}

/// Skills or wanted skills as chips.
class ChipList extends StatelessWidget {
  const ChipList(this.items, {super.key, this.strong = false});

  final List<String> items;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [for (final item in items) TagChip(item, strong: strong)],
    );
  }
}

/// GitHub · LinkedIn · Website. The app has no browser plugin, so a tap
/// copies the link and says so.
class ProfileLinksRow extends StatelessWidget {
  const ProfileLinksRow({super.key, required this.links});

  final ProfileLinks links;

  static List<(String, String)> entries(ProfileLinks links) => [
    if (links.github case final url?) ('GitHub', url),
    if (links.linkedin case final url?) ('LinkedIn', url),
    if (links.website case final url?) ('Website', url),
  ];

  static bool hasAny(ProfileLinks links) => entries(links).isNotEmpty;

  Future<void> _copy(BuildContext context, String label, String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label link copied: $url')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (label, url) in entries(links))
          ActionChip(
            key: Key('person-link-${label.toLowerCase()}'),
            avatar: const Icon(Icons.link, size: 16, color: AppColors.action),
            label: Text(label),
            tooltip: url,
            onPressed: () => _copy(context, label, url),
            backgroundColor: AppColors.white,
            side: const BorderSide(color: AppColors.line),
            shape: const StadiumBorder(),
            labelStyle: const TextStyle(
              color: AppColors.action,
              fontSize: 13,
              fontWeight: _bold,
            ),
          ),
      ],
    );
  }
}

/// Every section of [person] that has something in it, in wireframe order.
/// About falls back to Hacky's summary when there's no bio.
List<Widget> profileSections(PersonDetail person) {
  final about = person.bio ?? person.summary;
  final trackIdea = [?person.track, ?person.idea].join(' · ');
  return [
    if (about != null && about.trim().isNotEmpty)
      ProfileSection(label: 'About', child: ProfileText(about)),
    if (person.skills.isNotEmpty)
      ProfileSection(
        label: 'Skills',
        child: ChipList(person.skills, strong: true),
      ),
    if (person.skillsWanted.isNotEmpty)
      ProfileSection(
        label: 'Wants to learn',
        child: ChipList(person.skillsWanted),
      ),
    if (trackIdea.isNotEmpty)
      ProfileSection(label: 'Track · Idea', child: ProfileText(trackIdea)),
    if (ProfileLinksRow.hasAny(person.links))
      ProfileSection(
        label: 'Links',
        child: ProfileLinksRow(links: person.links),
      ),
  ];
}
