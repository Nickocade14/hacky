// What Hacky's messages show, read from the AI SDK parts of a ChatMessage.
//
// docs/openapi.yaml leaves the part shapes open. These follow the original
// Hacky (seeko-codes/hacky shared/contract.ts `toolOutputs`): text parts
// `{type: text, text}`, and tool parts `{type: tool-<name>, state, input,
// output}` whose output becomes a card. A part that doesn't fit its shape
// (or a tool Hacky has no card for) is skipped, so one bad part never takes
// the chat down.

import '../api/models/auth.dart';
import '../api/models/chat.dart';
import '../api/models/json_read.dart';
import '../api/models/people.dart';
import '../api/models/requests.dart';
import '../api/models/teams.dart';

/// One thing an assistant message shows.
sealed class HackyPart {
  const HackyPart();
}

/// A text bubble.
class HackyTextPart extends HackyPart {
  const HackyTextPart(this.text);

  final String text;
}

/// A quiet line under the bubbles: "no one fits", "couldn't load that".
class HackyNotePart extends HackyPart {
  const HackyNotePart(this.text);

  final String text;
}

/// `search_people`: the people (or teams) that match.
class HackyMatchesPart extends HackyPart {
  const HackyMatchesPart({
    required this.matches,
    this.closest = false,
    this.note,
  });

  final List<HackyMatch> matches;

  /// Nothing matched strongly; these are the nearest few.
  final bool closest;

  /// What's missing, when [closest] ("No mentor lists Solidity…").
  final String? note;
}

/// `get_profile`: one person Hacky looked up.
class HackyProfilePart extends HackyPart {
  const HackyProfilePart({
    required this.person,
    required this.skills,
    required this.bio,
    required this.relation,
  });

  final PersonSummary person;
  final List<String> skills;
  final String? bio;
  final RelationState relation;
}

/// `draft_intro`: an intro Hacky wrote for me to edit and send.
class HackyIntroDraftPart extends HackyPart {
  const HackyIntroDraftPart({
    required this.to,
    required this.team,
    required this.intro,
    required this.source,
  });

  /// The person, or the team's lead for a request to join [team].
  final PersonSummary to;
  final TeamRef? team;
  final String intro;
  final ConnectionSource source;
}

/// `ask_with_options`: a question with answer chips.
class HackyQuestionPart extends HackyPart {
  const HackyQuestionPart({
    required this.question,
    required this.options,
    required this.answer,
  });

  final String question;
  final List<String> options;

  /// What I answered; null while the question is open (or was skipped).
  final String? answer;
}

/// One result in a [HackyMatchesPart].
sealed class HackyMatch {
  const HackyMatch();
}

/// A hacker or mentor who fits.
class PersonMatch extends HackyMatch {
  const PersonMatch({
    required this.person,
    required this.skills,
    required this.matchedSkills,
    required this.reason,
  });

  final PersonSummary person;
  final List<String> skills;

  /// The skills I asked for that they have.
  final List<String> matchedSkills;
  final String reason;

  bool get isMentor => person.role == MemberRole.mentor;

  /// The card's one "why" line: the matched skills, else the search's reason
  /// cut at its first point.
  String get why => matchedSkills.isNotEmpty
      ? 'Knows ${matchedSkills.take(3).join(', ')}'
      : reason.split(RegExp(r';|\.(?:\s|$)')).first.trim();

  /// Up to three skills, the matched ones first.
  List<String> get shownSkills {
    final seen = <String>{};
    return [
      for (final skill in [...matchedSkills, ...skills])
        if (seen.add(skill.toLowerCase())) skill,
    ].take(3).toList();
  }
}

/// An open team I could join.
class TeamMatch extends HackyMatch {
  const TeamMatch({
    required this.team,
    required this.owner,
    required this.size,
    required this.maxSize,
    required this.wantedSkills,
  });

  final TeamRef team;

  /// The team's lead, who gets the request to join.
  final PersonSummary owner;
  final int size;
  final int maxSize;
  final List<String> wantedSkills;

  int get spotsLeft => maxSize - size < 0 ? 0 : maxSize - size;

  String get spotsText => switch (spotsLeft) {
    0 => 'Full',
    1 => '1 spot left',
    final n => '$n spots left',
  };
}

/// Reads the [HackyPart]s of an assistant message.
abstract final class HackyParts {
  static List<HackyPart> of(ChatMessage message) => [
    for (final part in message.parts) ..._read(part),
  ];

  /// The text of a message (my own messages are text only).
  static String textOf(ChatMessage message) => [
    for (final part in message.parts)
      if (part['type'] == 'text' && part['text'] is String)
        (part['text'] as String).trim(),
  ].where((text) => text.isNotEmpty).join('\n');

  static List<HackyPart> _read(Map<String, dynamic> part) {
    try {
      return _readPart(part);
    } on FormatException {
      return const [];
    } on TypeError {
      return const [];
    }
  }

  static List<HackyPart> _readPart(Map<String, dynamic> part) {
    final type = part['type'];
    if (type == 'text') {
      final text = part['text'];
      return text is String && text.trim().isNotEmpty
          ? [HackyTextPart(text.trim())]
          : const [];
    }
    if (type is! String || !type.startsWith('tool-')) return const [];
    final tool = type.substring('tool-'.length);
    if (tool == 'ask_with_options') return _question(part);
    if (!_tools.contains(tool)) return const [];
    if (part['state'] == 'output-error') {
      return const [HackyNotePart('Couldn’t load that. Try again.')];
    }
    final output = part['output'];
    if (output is! Map<String, dynamic>) return const [];
    return switch (tool) {
      'search_people' => [_matches(output)],
      'get_profile' => [_profile(output)],
      _ => [_draft(output)],
    };
  }

  static const _tools = {'search_people', 'get_profile', 'draft_intro'};

  static List<HackyPart> _question(Map<String, dynamic> part) {
    final input = part['input'];
    if (input is! Map<String, dynamic>) return const [];
    final say = input['say'];
    final output = part['output'];
    final answer = output is String
        ? output
        : output is Map<String, dynamic> && output['skipped'] != true
        ? output['answer']
        : null;
    return [
      if (say is String && say.trim().isNotEmpty) HackyTextPart(say.trim()),
      HackyQuestionPart(
        question: readString(input, 'question'),
        options: readStringList(input, 'options'),
        answer: answer is String && answer.trim().isNotEmpty ? answer : null,
      ),
    ];
  }

  static HackyPart _matches(Map<String, dynamic> output) {
    final status = output['status'];
    if (status == 'noMatch') {
      final reason = output['reason'];
      return HackyNotePart(
        reason is String && reason.isNotEmpty
            ? reason
            : 'No one fits that search yet.',
      );
    }
    final matches = <HackyMatch>[
      for (final card in readObjectList(output, 'cards')) ?_match(card),
    ];
    final note = output['note'];
    return HackyMatchesPart(
      matches: matches,
      closest: status == 'closest',
      note: note is String && note.isNotEmpty ? note : null,
    );
  }

  /// One card of a search, or null when it doesn't fit its shape.
  static HackyMatch? _match(Map<String, dynamic> card) {
    try {
      if (card['card'] == 'team') {
        final team = readObject(card, 'team');
        return TeamMatch(
          team: TeamRef.fromJson(team),
          owner: _person(readObject(team, 'owner')),
          size: readInt(team, 'size'),
          maxSize: readInt(team, 'maxSize'),
          wantedSkills: _strings(team, 'wantedSkills'),
        );
      }
      final evidence = card['evidence'];
      final reason = card['reason'];
      return PersonMatch(
        person: _person(readObject(card, 'person')),
        skills: _strings(card, 'skills'),
        matchedSkills: evidence is Map<String, dynamic>
            ? _strings(evidence, 'matchedSkills')
            : const [],
        reason: reason is String ? reason : '',
      );
    } on FormatException {
      return null;
    }
  }

  static HackyPart _profile(Map<String, dynamic> output) {
    final relation = output['relation'];
    final state = relation is Map<String, dynamic> ? relation['state'] : null;
    final bio = output['bio'];
    return HackyProfilePart(
      person: _person(output),
      skills: _strings(output, 'skills'),
      bio: bio is String && bio.trim().isNotEmpty ? bio.trim() : null,
      relation: RelationState.values.firstWhere(
        (value) => value.name == state,
        orElse: () => RelationState.none,
      ),
    );
  }

  static HackyPart _draft(Map<String, dynamic> output) {
    final team = readNullableObject(output, 'team');
    final source = output['source'];
    return HackyIntroDraftPart(
      to: _person(readObject(output, 'to')),
      team: team == null ? null : TeamRef.fromJson(team),
      intro: readString(output, 'intro'),
      source: ConnectionSource.values.firstWhere(
        (value) => value.name == source,
        orElse: () => ConnectionSource.agent,
      ),
    );
  }

  /// A `PersonSummary`, forgiving about the fields cards don't need.
  static PersonSummary _person(Map<String, dynamic> json) {
    final style = json['hackyStyle'];
    final photo = json['photoUrl'];
    final role = json['role'];
    return PersonSummary(
      userId: readString(json, 'userId'),
      handle: readString(json, 'handle'),
      name: readString(json, 'name'),
      hackyStyle: style is Map<String, dynamic> ? style : const {},
      photoUrl: photo is String ? photo : null,
      role: MemberRole.values.firstWhere(
        (value) => value.name == role,
        orElse: () => MemberRole.hacker,
      ),
    );
  }

  static List<String> _strings(Map<String, dynamic> json, String key) {
    final list = json[key];
    return list is List ? [...list.whereType<String>()] : const [];
  }
}
