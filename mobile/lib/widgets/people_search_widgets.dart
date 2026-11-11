// The pieces of 06 Search people (mobile/design/people-wireframes.svg): the
// search box, the role filter and one row per person found.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/models/auth.dart';
import '../api/models/search.dart';
import '../people/match_highlight.dart';
import '../people/people_search.dart';
import '../people/person_labels.dart';
import '../theme.dart';
import 'app_widgets.dart';

const _bold = FontWeight.w700;

/// The search box with a × to clear it. Every change goes to [onChanged];
/// the screen's [PeopleSearch] debounces it.
class PeopleSearchField extends StatelessWidget {
  const PeopleSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
  });

  static const fieldKey = Key('people-search');
  static const clearKey = Key('people-search-clear');

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;

  void _clear() {
    controller.clear();
    onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
      controller: controller,
      onChanged: onChanged,
      onSubmitted: (_) => onSubmitted(),
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: TextInputAction.search,
      inputFormatters: [
        LengthLimitingTextInputFormatter(PeopleSearch.maxLength),
      ],
      style: const TextStyle(color: AppColors.ink, fontSize: 16),
      decoration: InputDecoration(
        hintText: 'Search name, handle or skill',
        hintStyle: const TextStyle(color: AppColors.muted),
        prefixIcon: const Icon(Icons.search, color: AppColors.muted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        suffixIcon: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => controller.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  key: clearKey,
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close, color: AppColors.muted),
                  onPressed: _clear,
                ),
        ),
      ),
    );
  }
}

/// Everyone · Hackers · Mentors · Sponsors · Organizers: the contract's
/// `role` filter for `GET /api/search`.
class RoleFilterBar extends StatelessWidget {
  const RoleFilterBar({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final MemberRole? selected;
  final ValueChanged<MemberRole?> onChanged;

  static Key keyOf(MemberRole? role) => Key('role-${role?.name ?? 'all'}');

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        spacing: 8,
        children: [
          _chip('Everyone', null),
          for (final role in MemberRole.values)
            _chip(PersonLabels.rolePlural(role), role),
        ],
      ),
    );
  }

  Widget _chip(String label, MemberRole? role) {
    final active = role == selected;
    return ChoiceChip(
      key: keyOf(role),
      label: Text(label),
      selected: active,
      showCheckmark: false,
      onSelected: (_) => onChanged(role),
      backgroundColor: AppColors.white,
      selectedColor: AppColors.hover,
      side: BorderSide(color: active ? AppColors.action : AppColors.line),
      shape: const StadiumBorder(),
      labelStyle: TextStyle(
        color: active ? AppColors.action : AppColors.ink,
        fontSize: 13,
        fontWeight: _bold,
      ),
    );
  }
}

/// One person found: avatar, name and "@handle · skills" with the matching
/// part in bold, and their role on the right. Tapping opens 07.
class SearchHitRow extends StatelessWidget {
  const SearchHitRow({
    super.key,
    required this.hit,
    required this.query,
    required this.onTap,
  });

  final SearchHit hit;

  /// The text that found [hit], to bold.
  final String query;
  final VoidCallback onTap;

  /// Up to three skills, the ones that matched first.
  static List<String> shownSkills(SearchHit hit) => [
    ...hit.matchedSkills,
    for (final skill in hit.skills)
      if (!hit.matchedSkills.contains(skill)) skill,
  ].take(3).toList();

  @override
  Widget build(BuildContext context) {
    final skills = shownSkills(hit);
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        spacing: 14,
        children: [
          PersonAvatar.of(hit, size: 44),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Text.rich(
                  TextSpan(
                    children: MatchHighlight.spans(
                      hit.name,
                      query,
                      matchStyle: const TextStyle(
                        color: AppColors.action,
                        fontWeight: _bold,
                      ),
                    ),
                  ),
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 15,
                    fontWeight: _bold,
                  ),
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      ...MatchHighlight.spans('@${hit.handle}', query),
                      for (final (i, skill) in skills.indexed) ...[
                        TextSpan(text: i == 0 ? ' · ' : ', '),
                        ...MatchHighlight.spans(skill, query),
                      ],
                    ],
                  ),
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          TagChip(PersonLabels.role(hit.role)),
        ],
      ),
    );
  }
}

/// "5 people in Knight Hacks IX", over the results.
class ResultCountLine extends StatelessWidget {
  const ResultCountLine({
    super.key,
    required this.count,
    required this.eventName,
  });

  final int count;
  final String? eventName;

  @override
  Widget build(BuildContext context) {
    return Text(
      PersonLabels.resultCount(count, eventName),
      style: const TextStyle(color: AppColors.muted, fontSize: 13),
    );
  }
}
