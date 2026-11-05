// Team schemas from docs/openapi.yaml: CreateTeamBody, MyTeam, TeamRef,
// TeamSummary, TeamDetail.

import 'json_read.dart';
import 'people.dart';

/// `CreateTeamBody`: `POST /api/events/{slug}/teams`. Only [name] is
/// required; the server uses `maxSize` 4 when it isn't sent.
class CreateTeamBody {
  const CreateTeamBody({
    required this.name,
    this.idea,
    this.track,
    this.wantedSkills,
    this.maxSize,
  });

  final String name;
  final String? idea;
  final String? track;
  final List<String>? wantedSkills;

  /// 1 to 8, owner included.
  final int? maxSize;

  Map<String, dynamic> toJson() => {
    'name': name,
    'idea': ?idea,
    'track': ?track,
    'wantedSkills': ?wantedSkills,
    'maxSize': ?maxSize,
  };
}

/// `MyTeam`: the team I lead or belong to in an event.
class MyTeam {
  const MyTeam({
    required this.id,
    required this.name,
    required this.isOwner,
    required this.size,
    required this.maxSize,
  });

  final String id;
  final String name;
  final bool isOwner;
  final int size;
  final int maxSize;

  factory MyTeam.fromJson(Map<String, dynamic> json) => MyTeam(
    id: readString(json, 'id'),
    name: readString(json, 'name'),
    isOwner: readBool(json, 'isOwner'),
    size: readInt(json, 'size'),
    maxSize: readInt(json, 'maxSize'),
  );
}

/// `TeamRef`: a team's id and name.
class TeamRef {
  const TeamRef({required this.id, required this.name});

  final String id;
  final String name;

  factory TeamRef.fromJson(Map<String, dynamic> json) =>
      TeamRef(id: readString(json, 'id'), name: readString(json, 'name'));
}

/// `TeamSummary`.
class TeamSummary {
  const TeamSummary({
    required this.id,
    required this.name,
    required this.idea,
    required this.track,
    required this.wantedSkills,
    required this.size,
    required this.maxSize,
    required this.owner,
  });

  final String id;
  final String name;
  final String? idea;
  final String? track;
  final List<String> wantedSkills;
  final int size;
  final int maxSize;
  final PersonSummary owner;

  factory TeamSummary.fromJson(Map<String, dynamic> json) => TeamSummary(
    id: readString(json, 'id'),
    name: readString(json, 'name'),
    idea: readNullableString(json, 'idea'),
    track: readNullableString(json, 'track'),
    wantedSkills: readStringList(json, 'wantedSkills'),
    size: readInt(json, 'size'),
    maxSize: readInt(json, 'maxSize'),
    owner: PersonSummary.fromJson(readObject(json, 'owner')),
  );
}

/// `TeamDetail`: a team with its members (lead first, blocked people left out).
class TeamDetail extends TeamSummary {
  const TeamDetail({
    required super.id,
    required super.name,
    required super.idea,
    required super.track,
    required super.wantedSkills,
    required super.size,
    required super.maxSize,
    required super.owner,
    required this.members,
  });

  final List<PersonSummary> members;

  factory TeamDetail.fromJson(Map<String, dynamic> json) {
    final summary = TeamSummary.fromJson(json);
    return TeamDetail(
      id: summary.id,
      name: summary.name,
      idea: summary.idea,
      track: summary.track,
      wantedSkills: summary.wantedSkills,
      size: summary.size,
      maxSize: summary.maxSize,
      owner: summary.owner,
      members: readList(json, 'members', PersonSummary.fromJson),
    );
  }
}
