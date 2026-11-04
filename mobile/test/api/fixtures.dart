// Response bodies shaped like docs/openapi.yaml, for the client tests.

const publicProfileJson = {
  'userId': '6716a3f2c9e77b0012ab34cd',
  'handle': 'nico_c',
  'name': 'Nicolas Cadena',
  'hackyStyle': {'look': 'knit', 'avatar': 'hacky'},
  'photoUrl': null,
  'bio': 'Flutter and coffee.',
  'links': {'github': 'https://github.com/Nickocade14'},
  'isDemo': false,
};

const meJson = {
  'profile': publicProfileJson,
  'events': [
    {
      'slug': 'knighthacks-ix',
      'name': 'Knight Hacks IX',
      'role': 'hacker',
      'verified': true,
    },
  ],
};

const personSummaryJson = {
  'userId': '6716a3f2c9e77b0012ab0001',
  'handle': 'maya_ml',
  'name': 'Maya Patel',
  'hackyStyle': {'look': 'knit', 'color': 'teal'},
  'photoUrl': '/assets/people/maya.png',
  'role': 'hacker',
};

const personDetailJson = {
  ...personSummaryJson,
  'bio': 'ML student, loves health tech.',
  'links': {'linkedin': 'https://linkedin.com/in/maya'},
  'isDemo': true,
  'verified': true,
  'availability': 'busy',
  'looking': true,
  'skills': ['python', 'pytorch'],
  'skillsWanted': ['flutter'],
  'experience': 'advanced',
  'goal': 'win',
  'track': 'Health',
  'interests': ['health'],
  'idea': 'Skin rash triage from a photo',
  'summary': null,
  'motivations': ['compete'],
  'relation': {
    'state': 'incoming',
    'requestId': '6716a3f2c9e77b0012ab0101',
    'conversationId': null,
  },
};

const teamDetailJson = {
  'id': '6716a3f2c9e77b0012ab0201',
  'name': 'Rash Decisions',
  'idea': 'Skin rash triage from a photo',
  'track': null,
  'wantedSkills': ['flutter'],
  'size': 2,
  'maxSize': 4,
  'owner': personSummaryJson,
  'members': [
    personSummaryJson,
    {
      'userId': '6716a3f2c9e77b0012ab0002',
      'handle': 'leo_builds',
      'name': 'Leo Nguyen',
      'hackyStyle': <String, dynamic>{},
      'photoUrl': null,
      'role': 'hacker',
    },
  ],
};

const connectionRequestJson = {
  'id': '6716a3f2c9e77b0012ab0101',
  'direction': 'outgoing',
  'status': 'pending',
  'intro': 'Want to build the rash triage app together?',
  'source': 'profile',
  'person': personSummaryJson,
  'team': {'id': '6716a3f2c9e77b0012ab0201', 'name': 'Rash Decisions'},
  'conversationId': null,
  'createdAt': '2026-11-14T15:30:00.000Z',
  'respondedAt': null,
};

const eventInfoJson = {
  'slug': 'knighthacks-ix',
  'name': 'Knight Hacks IX',
  'theme': {
    'brand': '#5b3df5',
    'accent': '#ffb000',
    'displayFont': 'Lato',
    'heroImage': '/assets/kh-hero.png',
  },
  'tracks': ['AI', 'Health', 'Fintech'],
  'startsAt': '2026-11-14T13:00:00.000Z',
  'endsAt': null,
};

const intakeJson = {
  'skills': ['flutter', 'firebase'],
  'skillsWanted': ['backend'],
  'experience': 'intermediate',
  'wantsExperienced': true,
  'goal': null,
  'track': 'AI',
  'interests': ['education'],
  'idea': null,
  'motivations': ['build', 'meet'],
  'summary': 'Mobile dev looking for a backend partner.',
  'complete': false,
};

const eventMeJson = {
  'role': 'hacker',
  'verified': true,
  'availability': 'available',
  'looking': true,
  'intake': intakeJson,
};
