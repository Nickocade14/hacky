// People schemas from docs/openapi.yaml: PersonSummary, PersonDetail, Relation.

import 'auth.dart';
import 'events.dart';
import 'json_read.dart';

/// `PersonSummary`: the compact person used in lists, cards, requests and chats.
class PersonSummary {
  const PersonSummary({
    required this.userId,
    required this.handle,
    required this.name,
    required this.hackyStyle,
    required this.photoUrl,
    required this.role,
  });

  final String userId;
  final String handle;
  final String name;

  /// `HackyStyle`: avatar options. Unknown keys pass through.
  final Map<String, dynamic> hackyStyle;
  final String? photoUrl;
  final MemberRole role;

  factory PersonSummary.fromJson(Map<String, dynamic> json) => PersonSummary(
    userId: readString(json, 'userId'),
    handle: readString(json, 'handle'),
    name: readString(json, 'name'),
    hackyStyle: readObject(json, 'hackyStyle'),
    photoUrl: readNullableString(json, 'photoUrl'),
    role: readEnum(json, 'role', MemberRole.values),
  );
}

/// `Relation.state`.
enum RelationState { none, outgoing, incoming, accepted }

/// `Relation`: where the viewer stands with this person.
class Relation {
  const Relation({
    required this.state,
    required this.requestId,
    required this.conversationId,
  });

  final RelationState state;
  final String? requestId;
  final String? conversationId;

  factory Relation.fromJson(Map<String, dynamic> json) => Relation(
    state: readEnum(json, 'state', RelationState.values),
    requestId: readNullableString(json, 'requestId'),
    conversationId: readNullableString(json, 'conversationId'),
  );
}

/// `PersonDetail`: a person's full profile in an event
/// (PublicProfile + Membership + their intake and my relation to them).
class PersonDetail extends PublicProfile implements Membership {
  const PersonDetail({
    required super.userId,
    required super.handle,
    required super.name,
    required super.hackyStyle,
    required super.photoUrl,
    required super.bio,
    required super.links,
    required super.isDemo,
    required this.role,
    required this.verified,
    required this.availability,
    required this.looking,
    required this.skills,
    required this.skillsWanted,
    required this.experience,
    required this.goal,
    required this.track,
    required this.interests,
    required this.idea,
    required this.summary,
    required this.motivations,
    required this.relation,
  });

  @override
  final MemberRole role;
  @override
  final bool verified;
  @override
  final Availability availability;
  @override
  final bool looking;

  final List<String> skills;
  final List<String> skillsWanted;
  final Experience? experience;
  final HackGoal? goal;
  final String? track;
  final List<String> interests;
  final String? idea;
  final String? summary;
  final List<Motivation> motivations;
  final Relation relation;

  factory PersonDetail.fromJson(Map<String, dynamic> json) {
    final profile = PublicProfile.fromJson(json);
    final membership = Membership.fromJson(json);
    return PersonDetail(
      userId: profile.userId,
      handle: profile.handle,
      name: profile.name,
      hackyStyle: profile.hackyStyle,
      photoUrl: profile.photoUrl,
      bio: profile.bio,
      links: profile.links,
      isDemo: profile.isDemo,
      role: membership.role,
      verified: membership.verified,
      availability: membership.availability,
      looking: membership.looking,
      skills: readStringList(json, 'skills'),
      skillsWanted: readStringList(json, 'skillsWanted'),
      experience: readNullableEnum(json, 'experience', Experience.values),
      goal: readNullableEnum(json, 'goal', HackGoal.values),
      track: readNullableString(json, 'track'),
      interests: readStringList(json, 'interests'),
      idea: readNullableString(json, 'idea'),
      summary: readNullableString(json, 'summary'),
      motivations: readEnumList(json, 'motivations', Motivation.values),
      relation: Relation.fromJson(readObject(json, 'relation')),
    );
  }
}
