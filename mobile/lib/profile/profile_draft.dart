// What the 08 My profile form holds, as plain values: the public profile
// (`PATCH /api/me/profile`) and the event intake (`PATCH /api/events/{slug}/me`).
// Each draft checks itself and turns into a PATCH body of only what changed.

import 'package:flutter/foundation.dart';

import '../api/models/auth.dart';
import '../api/models/events.dart';
import '../api/models/me.dart';
import '../api/models/nullable.dart';
import 'profile_rules.dart';

/// A field of the form. [path] is where the contract puts it in the PATCH
/// body, to match the server's `error.details[].path`.
enum ProfileField {
  name('name'),
  bio('bio'),
  github('links.github'),
  linkedin('links.linkedin'),
  website('links.website'),
  hackyStyle('hackyStyle'),
  skills('skills'),
  skillsWanted('skillsWanted'),
  interests('interests'),
  experience('experience'),
  goal('goal'),
  track('track'),
  idea('idea'),
  looking('looking');

  const ProfileField(this.path);

  /// Dotted path, e.g. `links.github`.
  final String path;
}

/// The public profile part of the form.
class ProfileDraft {
  const ProfileDraft({
    required this.name,
    required this.bio,
    required this.github,
    required this.linkedin,
    required this.website,
    required this.hackyStyle,
  });

  factory ProfileDraft.of(PublicProfile profile) => ProfileDraft(
    name: profile.name,
    bio: profile.bio ?? '',
    github: profile.links.github ?? '',
    linkedin: profile.links.linkedin ?? '',
    website: profile.links.website ?? '',
    hackyStyle: profile.hackyStyle,
  );

  /// As typed (not trimmed).
  final String name;
  final String bio;
  final String github;
  final String linkedin;
  final String website;
  final Map<String, dynamic> hackyStyle;

  Map<ProfileField, String> validate() => {
    ProfileField.name: ?ProfileRules.name(name),
    ProfileField.bio: ?ProfileRules.bio(bio),
    ProfileField.github: ?ProfileRules.link(github),
    ProfileField.linkedin: ?ProfileRules.link(linkedin),
    ProfileField.website: ?ProfileRules.link(website),
  };

  /// The PATCH body for what differs from [saved], or null when nothing does.
  /// Links go as one object with every link that's set, so a cleared link is
  /// left out (the contract has no null for a link).
  UpdateProfileBody? changesFrom(ProfileDraft saved) {
    final name = this.name.trim();
    final bio = _bio;
    final links = _links;
    final body = UpdateProfileBody(
      name: name == saved.name.trim() ? null : name,
      bio: bio == saved._bio ? null : Nullable(bio),
      hackyStyle: mapEquals(hackyStyle, saved.hackyStyle) ? null : hackyStyle,
      links: mapEquals(links.toJson(), saved._links.toJson()) ? null : links,
    );
    return body.isEmpty ? null : body;
  }

  String? get _bio => bio.trim().isEmpty ? null : bio.trim();

  ProfileLinks get _links => ProfileLinks(
    github: _link(github),
    linkedin: _link(linkedin),
    website: _link(website),
  );

  static String? _link(String value) {
    final link = ProfileRules.normalizeLink(value);
    return link.isEmpty ? null : link;
  }
}

/// The event intake part of the form, plus "Looking for a team".
class IntakeDraft {
  const IntakeDraft({
    required this.skills,
    required this.skillsWanted,
    required this.interests,
    required this.experience,
    required this.goal,
    required this.track,
    required this.idea,
    required this.looking,
  });

  factory IntakeDraft.of(EventMe eventMe) {
    final intake = eventMe.intake;
    return IntakeDraft(
      skills: intake.skills,
      skillsWanted: intake.skillsWanted,
      interests: intake.interests,
      experience: intake.experience,
      goal: intake.goal,
      track: intake.track,
      idea: intake.idea ?? '',
      looking: eventMe.looking,
    );
  }

  final List<String> skills;
  final List<String> skillsWanted;
  final List<String> interests;
  final Experience? experience;
  final HackGoal? goal;
  final String? track;

  /// As typed (not trimmed).
  final String idea;
  final bool looking;

  Map<ProfileField, String> validate() => {
    ProfileField.skills: ?ProfileRules.tags(skills),
    ProfileField.skillsWanted: ?ProfileRules.tags(skillsWanted),
    ProfileField.interests: ?ProfileRules.tags(interests),
    ProfileField.track: ?ProfileRules.track(track),
    ProfileField.idea: ?ProfileRules.idea(idea),
  };

  /// The PATCH body for what differs from [saved], or null when nothing does.
  UpdateEventMeBody? changesFrom(IntakeDraft saved) {
    final idea = _idea;
    final body = UpdateEventMeBody(
      skills: listEquals(skills, saved.skills) ? null : skills,
      skillsWanted: listEquals(skillsWanted, saved.skillsWanted)
          ? null
          : skillsWanted,
      interests: listEquals(interests, saved.interests) ? null : interests,
      experience: experience == saved.experience ? null : Nullable(experience),
      goal: goal == saved.goal ? null : Nullable(goal),
      track: track == saved.track ? null : Nullable(track),
      idea: idea == saved._idea ? null : Nullable(idea),
      looking: looking == saved.looking ? null : looking,
    );
    return body.toJson().isEmpty ? null : body;
  }

  String? get _idea => idea.trim().isEmpty ? null : idea.trim();
}
