// Response bodies shaped like docs/openapi.yaml, for the client tests.

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
