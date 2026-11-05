// Event schemas from docs/openapi.yaml: EventInfo, EventTheme, JoinEventBody,
// Membership, EventMe, Intake and UpdateEventMeBody, plus their enums.
// `IntakeFields` has no class of its own: Intake (response, every field
// required) and UpdateEventMeBody (request, every field optional) each list it.

import 'auth.dart';
import 'json_read.dart';
import 'nullable.dart';

/// `Availability`.
enum Availability { available, busy, offline }

/// `Experience`.
enum Experience { beginner, intermediate, advanced }

/// `HackGoal`.
enum HackGoal { win, learn, ship }

/// `Motivation`.
enum Motivation { build, learn, meet, career, compete, fun }

/// `EventTheme`: colors and fonts the app turns into its theme. Every field is
/// optional and unknown keys pass through, kept in [raw].
class EventTheme {
  const EventTheme({
    this.brand,
    this.brandContrast,
    this.accent,
    this.surface,
    this.logoUrl,
    this.displayFont,
    this.raw = const {},
  });

  final String? brand;
  final String? brandContrast;
  final String? accent;
  final String? surface;
  final String? logoUrl;
  final String? displayFont;

  /// The whole theme object as the server sent it, unknown keys included.
  final Map<String, dynamic> raw;

  factory EventTheme.fromJson(Map<String, dynamic> json) => EventTheme(
    brand: readNullableString(json, 'brand'),
    brandContrast: readNullableString(json, 'brandContrast'),
    accent: readNullableString(json, 'accent'),
    surface: readNullableString(json, 'surface'),
    logoUrl: readNullableString(json, 'logoUrl'),
    displayFont: readNullableString(json, 'displayFont'),
    raw: json,
  );
}

/// `EventInfo`: `GET /api/events` and `GET /api/events/{slug}`.
class EventInfo {
  const EventInfo({
    required this.slug,
    required this.name,
    required this.theme,
    required this.tracks,
    required this.startsAt,
    required this.endsAt,
  });

  final String slug;
  final String name;
  final EventTheme theme;
  final List<String> tracks;
  final DateTime? startsAt;
  final DateTime? endsAt;

  factory EventInfo.fromJson(Map<String, dynamic> json) => EventInfo(
    slug: readString(json, 'slug'),
    name: readString(json, 'name'),
    theme: EventTheme.fromJson(readObject(json, 'theme')),
    tracks: readStringList(json, 'tracks'),
    startsAt: readNullableDateTime(json, 'startsAt'),
    endsAt: readNullableDateTime(json, 'endsAt'),
  );
}

/// The roles `JoinEventBody.role` allows (a subset of [MemberRole]).
enum JoinRole { hacker, mentor }

/// `JoinEventBody`: `POST /api/events/{slug}/join`. Without a role the server
/// uses `hacker`.
class JoinEventBody {
  const JoinEventBody({this.role});

  final JoinRole? role;

  Map<String, dynamic> toJson() => {if (role != null) 'role': role!.name};
}

/// `Membership`: my role and status in an event.
class Membership {
  const Membership({
    required this.role,
    required this.verified,
    required this.availability,
    required this.looking,
  });

  final MemberRole role;
  final bool verified;
  final Availability availability;

  /// Looking for a team.
  final bool looking;

  factory Membership.fromJson(Map<String, dynamic> json) => Membership(
    role: readEnum(json, 'role', MemberRole.values),
    verified: readBool(json, 'verified'),
    availability: readEnum(json, 'availability', Availability.values),
    looking: readBool(json, 'looking'),
  );
}

/// `Intake`: what Hacky knows about me for matching. The server sets
/// [summary] and [complete].
class Intake {
  const Intake({
    required this.skills,
    required this.skillsWanted,
    required this.experience,
    required this.wantsExperienced,
    required this.goal,
    required this.track,
    required this.interests,
    required this.idea,
    required this.motivations,
    required this.summary,
    required this.complete,
  });

  final List<String> skills;
  final List<String> skillsWanted;
  final Experience? experience;
  final bool wantsExperienced;
  final HackGoal? goal;
  final String? track;
  final List<String> interests;
  final String? idea;
  final List<Motivation> motivations;
  final String? summary;
  final bool complete;

  factory Intake.fromJson(Map<String, dynamic> json) => Intake(
    skills: readStringList(json, 'skills'),
    skillsWanted: readStringList(json, 'skillsWanted'),
    experience: readNullableEnum(json, 'experience', Experience.values),
    wantsExperienced: readBool(json, 'wantsExperienced'),
    goal: readNullableEnum(json, 'goal', HackGoal.values),
    track: readNullableString(json, 'track'),
    interests: readStringList(json, 'interests'),
    idea: readNullableString(json, 'idea'),
    motivations: readEnumList(json, 'motivations', Motivation.values),
    summary: readNullableString(json, 'summary'),
    complete: readBool(json, 'complete'),
  );
}

/// `EventMe`: my membership and intake in an event.
class EventMe extends Membership {
  const EventMe({
    required super.role,
    required super.verified,
    required super.availability,
    required super.looking,
    required this.intake,
  });

  final Intake intake;

  factory EventMe.fromJson(Map<String, dynamic> json) {
    final membership = Membership.fromJson(json);
    return EventMe(
      role: membership.role,
      verified: membership.verified,
      availability: membership.availability,
      looking: membership.looking,
      intake: Intake.fromJson(readObject(json, 'intake')),
    );
  }
}

/// `UpdateEventMeBody`: `PATCH /api/events/{slug}/me`. Partial update: only the
/// fields that aren't null are sent. Use [Nullable] to clear a nullable field.
/// `role` and `verified` can't be changed here.
class UpdateEventMeBody {
  const UpdateEventMeBody({
    this.skills,
    this.skillsWanted,
    this.experience,
    this.wantsExperienced,
    this.goal,
    this.track,
    this.interests,
    this.idea,
    this.motivations,
    this.availability,
    this.looking,
  });

  final List<String>? skills;
  final List<String>? skillsWanted;
  final Nullable<Experience>? experience;
  final bool? wantsExperienced;
  final Nullable<HackGoal>? goal;
  final Nullable<String>? track;
  final List<String>? interests;
  final Nullable<String>? idea;
  final List<Motivation>? motivations;
  final Availability? availability;
  final bool? looking;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'skills': ?skills,
      'skillsWanted': ?skillsWanted,
      'wantsExperienced': ?wantsExperienced,
      'interests': ?interests,
      if (motivations != null)
        'motivations': [for (final m in motivations!) m.name],
      if (availability != null) 'availability': availability!.name,
      'looking': ?looking,
    };
    putNullable(json, 'experience', experience);
    putNullable(json, 'goal', goal);
    putNullable(json, 'track', track);
    putNullable(json, 'idea', idea);
    return json;
  }
}
