import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/models/auth.dart';
import 'package:mobile/api/models/chat.dart';
import 'package:mobile/api/models/people.dart';
import 'package:mobile/hacky/hacky_parts.dart';

import 'hacky_fixtures.dart';

ChatMessage assistant(List<Map<String, dynamic>> parts) =>
    ChatMessage(id: 'a1', role: ChatRole.assistant, parts: parts);

void main() {
  test('reads text parts and skips empty and unknown ones', () {
    final parts = HackyParts.of(
      assistant([
        textPart('  Here you go  '),
        textPart('   '),
        {'type': 'step-start'},
        {'type': 'reasoning', 'text': 'hmm'},
        {'type': 'tool-update_profile', 'output': <String, dynamic>{}},
      ]),
    );

    expect(parts, hasLength(1));
    expect((parts.single as HackyTextPart).text, 'Here you go');
  });

  test('reads people and mentors from search_people', () {
    final part =
        HackyParts.of(
              assistant([
                searchPart(
                  mentor: personJson(
                    userId: 'm1',
                    handle: 'sam_mentor',
                    name: 'Sam Rivera',
                    role: 'mentor',
                  ),
                ),
              ]),
            ).single
            as HackyMatchesPart;

    expect(part.closest, isFalse);
    final [leo, sam] = part.matches.cast<PersonMatch>();
    expect(leo.person.handle, 'leo_builds');
    expect(leo.isMentor, isFalse);
    expect(leo.why, 'Knows react');
    expect(leo.shownSkills, ['react', 'node', 'mongodb']);
    expect(sam.isMentor, isTrue);
    expect(sam.person.role, MemberRole.mentor);
    expect(sam.why, 'Mobile mentor');
  });

  test('a closest search keeps its note; noMatch is a note', () {
    final closest =
        HackyParts.of(assistant([searchPart(status: 'closest')])).single
            as HackyMatchesPart;
    expect(closest.closest, isTrue);
    expect(closest.note, 'No one lists Svelte; these are close.');

    final none = HackyParts.of(
      assistant([
        {
          'type': 'tool-search_people',
          'state': 'output-available',
          'output': {
            'status': 'noMatch',
            'kind': 'mentor',
            'reason': 'No mentor lists Rust yet.',
          },
        },
      ]),
    );
    expect((none.single as HackyNotePart).text, 'No mentor lists Rust yet.');
  });

  test('reads team cards with spots left', () {
    final part =
        HackyParts.of(assistant([teamSearchPart(personJson())])).single
            as HackyMatchesPart;
    final team = part.matches.single as TeamMatch;

    expect(team.team.name, 'Rash Decisions');
    expect(team.owner.handle, 'leo_builds');
    expect(team.spotsText, '2 spots left');
    expect(team.wantedSkills, ['flutter', 'ux']);
  });

  test('skips a card that does not fit, keeps the rest', () {
    final search = searchPart();
    final output = search['output'] as Map<String, dynamic>;
    (output['cards'] as List).add({
      'card': 'person',
      'person': {'handle': 'no_id'},
    });

    final part =
        HackyParts.of(assistant([search])).single as HackyMatchesPart;
    expect(part.matches, hasLength(1));
  });

  test('reads a profile and a draft intro', () {
    final parts = HackyParts.of(
      assistant([
        {
          'type': 'tool-get_profile',
          'state': 'output-available',
          'output': {
            ...personJson(),
            'bio': 'Full-stack JS.',
            'skills': ['react'],
            'relation': {'state': 'outgoing'},
          },
        },
        draftPart(personJson()),
      ]),
    );

    final profile = parts[0] as HackyProfilePart;
    expect(profile.person.name, 'Leo Nguyen');
    expect(profile.bio, 'Full-stack JS.');
    expect(profile.relation, RelationState.outgoing);
    final draft = parts[1] as HackyIntroDraftPart;
    expect(draft.to.handle, 'leo_builds');
    expect(draft.team, isNull);
    expect(draft.intro, startsWith('Hi Leo!'));
  });

  test('a failed tool is a note', () {
    final parts = HackyParts.of(
      assistant([
        {'type': 'tool-search_people', 'state': 'output-error'},
      ]),
    );
    expect((parts.single as HackyNotePart).text, 'Couldn’t load that. Try again.');
  });

  test('a question shows its say line, options and answer', () {
    final open = HackyParts.of(assistant([questionPart()]));
    expect((open[0] as HackyTextPart).text, 'Nice, a health app!');
    final question = open[1] as HackyQuestionPart;
    expect(question.question, 'What role do you need most?');
    expect(question.options, ['Designer', 'Backend dev']);
    expect(question.answer, isNull);

    final answered = HackyParts.of(
      assistant([
        questionPart(output: {'answer': 'Designer'}),
      ]),
    );
    expect((answered[1] as HackyQuestionPart).answer, 'Designer');

    final skipped = HackyParts.of(
      assistant([
        questionPart(output: {'answer': 'x', 'skipped': true}),
      ]),
    );
    expect((skipped[1] as HackyQuestionPart).answer, isNull);
  });

  test('textOf joins the text parts', () {
    expect(
      HackyParts.textOf(
        ChatMessage(
          id: 'u1',
          role: ChatRole.user,
          parts: [textPart('Find a mentor'), textPart(' for Flutter ')],
        ),
      ),
      'Find a mentor\nfor Flutter',
    );
  });
}
