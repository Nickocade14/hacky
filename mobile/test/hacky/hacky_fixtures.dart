// Tool parts in the shape the original Hacky sends (shared/contract.ts
// `toolOutputs`). docs/openapi.yaml leaves part shapes open, so these are
// only test data. The people are the fake world's, with their real ids
// filled in by the tests that send requests.

Map<String, dynamic> personJson({
  String userId = '6716a3f2c9e7000000000101',
  String handle = 'leo_builds',
  String name = 'Leo Nguyen',
  String role = 'hacker',
}) => {
  'userId': userId,
  'handle': handle,
  'name': name,
  'hackyStyle': <String, dynamic>{},
  'photoUrl': null,
  'role': role,
};

Map<String, dynamic> searchPart({
  Map<String, dynamic>? person,
  Map<String, dynamic>? mentor,
  String status = 'matches',
}) => {
  'type': 'tool-search_people',
  'toolCallId': 'call-1',
  'state': 'output-available',
  'input': {'query': 'react'},
  'output': {
    'status': status,
    'kind': 'hacker',
    if (status == 'closest') 'note': 'No one lists Svelte; these are close.',
    'cards': [
      {
        'card': 'person',
        'person': person ?? personJson(),
        'skills': ['react', 'node', 'mongodb'],
        'score': 0.8,
        'evidence': {
          'matchedSkills': ['react'],
        },
        'reason': 'Knows React; also on Health.',
      },
      if (mentor != null)
        {
          'card': 'mentor',
          'person': mentor,
          'verified': true,
          'skills': ['flutter', 'firebase'],
          'evidence': {'matchedSkills': <String>[]},
          'reason': 'Mobile mentor. Available later.',
        },
    ],
  },
};

Map<String, dynamic> teamSearchPart(Map<String, dynamic> owner) => {
  'type': 'tool-search_people',
  'state': 'output-available',
  'output': {
    'status': 'matches',
    'kind': 'team',
    'cards': [
      {
        'card': 'team',
        'team': {
          'id': '6716a3f2c9e7000000000999',
          'name': 'Rash Decisions',
          'idea': null,
          'track': 'Health',
          'wantedSkills': ['flutter', 'ux'],
          'size': 2,
          'maxSize': 4,
          'owner': owner,
        },
        'reason': 'Wants Flutter.',
      },
    ],
  },
};

Map<String, dynamic> draftPart(Map<String, dynamic> to, {String? intro}) => {
  'type': 'tool-draft_intro',
  'state': 'output-available',
  'output': {
    'card': 'draft',
    'to': to,
    'team': null,
    'intro': intro ?? 'Hi Leo! Want to build a health app together?',
    'source': 'agent',
  },
};

Map<String, dynamic> questionPart({Object? output}) => {
  'type': 'tool-ask_with_options',
  'toolCallId': 'call-q',
  'state': output == null ? 'input-available' : 'output-available',
  'input': {
    'say': 'Nice, a health app!',
    'question': 'What role do you need most?',
    'options': ['Designer', 'Backend dev'],
  },
  'output': ?output,
};

Map<String, dynamic> textPart(String text) => {'type': 'text', 'text': text};
