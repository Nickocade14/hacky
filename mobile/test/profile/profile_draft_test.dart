import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/api_exception.dart';
import 'package:mobile/api/models/auth.dart';
import 'package:mobile/api/models/events.dart';
import 'package:mobile/profile/field_errors.dart';
import 'package:mobile/profile/hacky_style.dart';
import 'package:mobile/profile/profile_draft.dart';

const profile = PublicProfile(
  userId: '6717a3f2c9e1b04d2a5e8f10',
  handle: 'ethan_z',
  name: 'Ethan Zeng',
  hackyStyle: {'color': 'mint', 'avatar': 'hacky'},
  photoUrl: null,
  bio: 'Backend person',
  links: ProfileLinks(github: 'https://github.com/ethan'),
  isDemo: false,
);

const eventMe = EventMe(
  role: MemberRole.hacker,
  verified: true,
  availability: Availability.available,
  looking: true,
  intake: Intake(
    skills: ['React'],
    skillsWanted: [],
    experience: Experience.beginner,
    wantsExperienced: false,
    goal: null,
    track: 'AI',
    interests: [],
    idea: null,
    motivations: [],
    summary: null,
    complete: false,
  ),
);

ProfileDraft editProfile({
  String? name,
  String? bio,
  String? github,
  String? website,
  Map<String, dynamic>? hackyStyle,
}) {
  final saved = ProfileDraft.of(profile);
  return ProfileDraft(
    name: name ?? saved.name,
    bio: bio ?? saved.bio,
    github: github ?? saved.github,
    linkedin: saved.linkedin,
    website: website ?? saved.website,
    hackyStyle: hackyStyle ?? saved.hackyStyle,
  );
}

void main() {
  final saved = ProfileDraft.of(profile);
  final savedIntake = IntakeDraft.of(eventMe);

  group('ProfileDraft', () {
    test('no changes means no body', () {
      expect(editProfile().changesFrom(saved), isNull);
      // Spaces around the same value aren't a change.
      expect(editProfile(name: ' Ethan Zeng ').changesFrom(saved), isNull);
    });

    test('sends only the changed fields, trimmed', () {
      final body = editProfile(name: ' Ethan Z ').changesFrom(saved)!;
      expect(body.toJson(), {'name': 'Ethan Z'});
    });

    test('an empty bio clears it with null', () {
      expect(editProfile(bio: '  ').changesFrom(saved)!.toJson(), {
        'bio': null,
      });
    });

    test('links go as one object, normalized, without cleared ones', () {
      final body = editProfile(
        github: '',
        website: 'ethan.dev',
      ).changesFrom(saved)!;
      expect(body.toJson(), {
        'links': {'website': 'https://ethan.dev'},
      });
    });

    test('a new Hacky look keeps the other style keys', () {
      final style = const HackyLook(color: 'rose').applyTo(saved.hackyStyle);
      final body = editProfile(hackyStyle: style).changesFrom(saved)!;
      expect(body.toJson()['hackyStyle'], {
        'color': 'rose',
        'avatar': 'hacky',
        'look': 'knit',
        'flair': 'none',
        'move': 'idle',
      });
    });

    test('validate lists each bad field', () {
      final errors = editProfile(name: '', github: 'http://x.dev').validate();
      expect(errors.keys, [ProfileField.name, ProfileField.github]);
    });
  });

  group('IntakeDraft', () {
    IntakeDraft edit({
      List<String>? skills,
      Experience? experience,
      bool clearTrack = false,
      String? idea,
      bool? looking,
    }) => IntakeDraft(
      skills: skills ?? savedIntake.skills,
      skillsWanted: savedIntake.skillsWanted,
      interests: savedIntake.interests,
      experience: experience ?? savedIntake.experience,
      goal: savedIntake.goal,
      track: clearTrack ? null : savedIntake.track,
      idea: idea ?? savedIntake.idea,
      looking: looking ?? savedIntake.looking,
    );

    test('no changes means no body', () {
      expect(edit().changesFrom(savedIntake), isNull);
      expect(edit(idea: '   ').changesFrom(savedIntake), isNull);
    });

    test('sends only the changed fields, with null to clear', () {
      final body = edit(
        skills: ['React', 'Node'],
        experience: Experience.advanced,
        clearTrack: true,
        idea: ' A study app ',
        looking: false,
      ).changesFrom(savedIntake)!;
      expect(body.toJson(), {
        'skills': ['React', 'Node'],
        'experience': 'advanced',
        'track': null,
        'idea': 'A study app',
        'looking': false,
      });
    });

    test('validate catches a too long idea', () {
      expect(edit(idea: 'a' * 2001).validate().keys, [ProfileField.idea]);
    });
  });

  group('HackyLook', () {
    test('reads a saved style, with defaults for unknown values', () {
      expect(HackyLook.of(const {}), const HackyLook());
      expect(
        HackyLook.of(const {'color': 'berry', 'flair': 'sparks', 'move': 'x'}),
        const HackyLook(color: 'berry', flair: 'stars'),
      );
    });

    test('only tints colors other than the original', () {
      expect(const HackyLook().filter, isNull);
      expect(const HackyLook(color: 'ice').filter, isNotNull);
    });
  });

  group('FieldErrors', () {
    test('maps list, dotted and pointer paths to fields', () {
      final errors = FieldErrors.of(const [
        ApiErrorDetail(path: ['links', 'github'], message: 'Bad link'),
        ApiErrorDetail(path: 'name', message: 'Too long'),
        ApiErrorDetail(path: '/skills/3', message: 'Too long'),
        ApiErrorDetail(path: ['links'], message: 'Ignored'),
        ApiErrorDetail(path: null, message: 'Ignored'),
        ApiErrorDetail(path: ['bio']),
      ]);
      expect(errors, {
        ProfileField.github: 'Bad link',
        ProfileField.name: 'Too long',
        ProfileField.skills: 'Too long',
        ProfileField.bio: 'Check this field.',
      });
    });
  });
}
