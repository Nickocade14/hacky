// What Hacky's turns show in 12 Hacky chat: text bubbles, answer chips, and
// a card per tool result (mobile/design/hacky-chat-wireframes.svg; original:
// react/src/hacky/cards.jsx). A card reads in about two seconds: who, one
// "why" line, up to three skills, View (→ 07) and Connect.

import 'package:flutter/material.dart';

import '../api/models/auth.dart';
import '../api/models/people.dart';
import '../api/models/teams.dart';
import '../hacky/hacky_card_actions.dart';
import '../hacky/hacky_parts.dart';
import '../theme.dart';
import 'app_widgets.dart';
import 'hacky_chat_widgets.dart';
import 'hacky_intro.dart';

const _bold = FontWeight.w700;

/// One [HackyPart] of an assistant message.
class HackyPartView extends StatelessWidget {
  const HackyPartView({
    super.key,
    required this.part,
    required this.actions,
    required this.latest,
  });

  final HackyPart part;
  final HackyCardActions actions;

  /// The part is in the newest message, so an open question can be answered.
  final bool latest;

  @override
  Widget build(BuildContext context) {
    return switch (part) {
      HackyTextPart(:final text) => HackyBubble(
        child: HackyRichText(text, onOpenHandle: actions.openPerson),
      ),
      HackyNotePart(:final text) => QuietLine(text),
      final HackyMatchesPart matches => MatchesView(
        part: matches,
        actions: actions,
      ),
      final HackyProfilePart profile => ProfileResultCard(
        part: profile,
        actions: actions,
      ),
      final HackyIntroDraftPart draft => IntroDraftCard(
        to: draft.to,
        team: draft.team,
        intro: draft.intro,
        source: draft.source,
        actions: actions,
      ),
      final HackyQuestionPart question => QuestionView(
        part: question,
        onAnswer: latest && !actions.busy ? actions.ask : null,
      ),
    };
  }
}

/// A muted line under Hacky's bubbles.
class QuietLine extends StatelessWidget {
  const QuietLine(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(color: AppColors.muted, fontSize: 14, height: 1.5),
    );
  }
}

/// Hacky's question, then my answer or the answer chips. Tapping a chip
/// sends it as my next message.
class QuestionView extends StatelessWidget {
  const QuestionView({super.key, required this.part, required this.onAnswer});

  final HackyQuestionPart part;

  /// Null when the question is closed or Hacky is busy.
  final ValueChanged<String>? onAnswer;

  @override
  Widget build(BuildContext context) {
    final answer = part.answer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        HackyBubble(child: Text(part.question, style: HackyRichText.style)),
        if (answer != null)
          UserBubble(text: answer)
        else if (onAnswer != null)
          SuggestionChips(prompts: part.options, onPick: onAnswer),
      ],
    );
  }
}

/// A search's results: the note when nothing fit strongly, then the cards.
class MatchesView extends StatelessWidget {
  const MatchesView({super.key, required this.part, required this.actions});

  final HackyMatchesPart part;
  final HackyCardActions actions;

  String get _label {
    final count = part.matches.length;
    final teams = part.matches.every((match) => match is TeamMatch);
    final noun = teams ? 'team' : 'person';
    final plural = teams ? 'teams' : 'people';
    return '$count${part.closest ? ' closest' : ''} ${count == 1 ? noun : plural}';
  }

  @override
  Widget build(BuildContext context) {
    if (part.matches.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        if (part.note case final note?) QuietLine(note),
        SectionLabel(_label),
        for (final match in part.matches)
          switch (match) {
            final PersonMatch person => PersonMatchCard(
              match: person,
              closest: part.closest,
              actions: actions,
            ),
            final TeamMatch team => TeamMatchCard(
              match: team,
              closest: part.closest,
              actions: actions,
            ),
          },
      ],
    );
  }
}

/// The head of a result card: avatar, name, an optional tag and one quiet
/// line of facts.
class CardHead extends StatelessWidget {
  const CardHead({
    super.key,
    required this.person,
    required this.title,
    required this.facts,
    this.closest = false,
  });

  final PersonSummary person;
  final String title;
  final List<String> facts;

  /// A closest fit, not a strong match.
  final bool closest;

  static String roleLabel(MemberRole role) => switch (role) {
    MemberRole.hacker => 'Hacker',
    MemberRole.mentor => 'Mentor',
    MemberRole.sponsor => 'Sponsor',
    MemberRole.organizer => 'Organizer',
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 12,
      children: [
        PersonAvatar.of(person, size: 52),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 15,
                      fontWeight: _bold,
                    ),
                  ),
                  if (closest) const _ClosestTag(),
                ],
              ),
              Text(
                facts.join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ClosestTag extends StatelessWidget {
  const _ClosestTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        'Closest fit',
        style: TextStyle(
          color: AppColors.muted,
          fontSize: 12,
          fontWeight: _bold,
        ),
      ),
    );
  }
}

/// Up to three skills; the ones I asked for are blue.
class SkillTags extends StatelessWidget {
  const SkillTags({super.key, required this.skills, this.matched = const []});

  final List<String> skills;
  final List<String> matched;

  @override
  Widget build(BuildContext context) {
    final hit = {for (final skill in matched) skill.toLowerCase()};
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final skill in skills.take(3))
          TagChip(skill, strong: hit.contains(skill.toLowerCase())),
      ],
    );
  }
}

/// View (→ 07) and Connect, or where my request stands once it's sent.
class CardActionsRow extends StatelessWidget {
  const CardActionsRow({
    super.key,
    required this.viewLabel,
    required this.onView,
    required this.to,
    required this.actions,
    this.team,
    this.connectLabel = 'Connect',
    this.canConnect = true,
  });

  final String viewLabel;
  final VoidCallback onView;
  final PersonSummary to;
  final TeamRef? team;
  final HackyCardActions actions;
  final String connectLabel;

  /// False when there's nothing to send (a full team, already connected).
  final bool canConnect;

  @override
  Widget build(BuildContext context) {
    final sent = actions.sentRequest(to.userId, team?.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        if (sent != null)
          RequestStatusLine(result: sent, to: to, actions: actions),
        // Wraps on narrow phones instead of overflowing.
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            OutlinedButton(onPressed: onView, child: Text(viewLabel)),
            if (sent == null && canConnect)
              FilledButton(
                onPressed: () => ConnectSheet.show(
                  context,
                  to: to,
                  team: team,
                  actions: actions,
                ),
                child: Text(connectLabel),
              ),
          ],
        ),
      ],
    );
  }
}

/// A hacker or mentor from a search.
class PersonMatchCard extends StatelessWidget {
  const PersonMatchCard({
    super.key,
    required this.match,
    required this.closest,
    required this.actions,
  });

  final PersonMatch match;
  final bool closest;
  final HackyCardActions actions;

  @override
  Widget build(BuildContext context) {
    final person = match.person;
    final why = match.why;
    void view() => actions.openPerson(person.handle);
    return AppCard(
      onTap: view,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          CardHead(
            person: person,
            title: person.name,
            facts: ['@${person.handle}', CardHead.roleLabel(person.role)],
            closest: closest,
          ),
          if (why.isNotEmpty)
            Text(
              why,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.ink, fontSize: 14),
            ),
          if (match.shownSkills.isNotEmpty)
            SkillTags(skills: match.shownSkills, matched: match.matchedSkills),
          CardActionsRow(
            viewLabel: 'View',
            onView: view,
            to: person,
            actions: actions,
          ),
        ],
      ),
    );
  }
}

/// An open team from a search: Ask to join goes to its lead.
class TeamMatchCard extends StatelessWidget {
  const TeamMatchCard({
    super.key,
    required this.match,
    required this.closest,
    required this.actions,
  });

  final TeamMatch match;
  final bool closest;
  final HackyCardActions actions;

  @override
  Widget build(BuildContext context) {
    final owner = match.owner;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          CardHead(
            person: owner,
            title: match.team.name,
            facts: [match.spotsText, 'Led by ${owner.name}'],
            closest: closest,
          ),
          Text(
            match.wantedSkills.isEmpty
                ? 'Looking for any skills'
                : 'Looking for',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          if (match.wantedSkills.isNotEmpty)
            SkillTags(skills: match.wantedSkills),
          CardActionsRow(
            viewLabel: 'View lead',
            onView: () => actions.openPerson(owner.handle),
            to: owner,
            team: match.team,
            connectLabel: 'Ask to join',
            canConnect: match.spotsLeft > 0,
            actions: actions,
          ),
        ],
      ),
    );
  }
}

/// A person Hacky looked up, with where I stand with them.
class ProfileResultCard extends StatelessWidget {
  const ProfileResultCard({
    super.key,
    required this.part,
    required this.actions,
  });

  final HackyProfilePart part;
  final HackyCardActions actions;

  static String? relationText(RelationState state) => switch (state) {
    RelationState.none => null,
    RelationState.outgoing => 'You sent a request',
    RelationState.incoming => 'Wants to connect with you',
    RelationState.accepted => 'You’re connected',
  };

  @override
  Widget build(BuildContext context) {
    final person = part.person;
    final line = relationText(part.relation) ?? part.bio;
    void view() => actions.openPerson(person.handle);
    return AppCard(
      onTap: view,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          CardHead(
            person: person,
            title: person.name,
            facts: ['@${person.handle}', CardHead.roleLabel(person.role)],
          ),
          if (line != null)
            Text(
              line,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.ink, fontSize: 14),
            ),
          if (part.skills.isNotEmpty) SkillTags(skills: part.skills),
          CardActionsRow(
            viewLabel: 'View profile',
            onView: view,
            to: person,
            canConnect: part.relation == RelationState.none,
            actions: actions,
          ),
        ],
      ),
    );
  }
}
