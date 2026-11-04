// Search schemas from docs/openapi.yaml: SearchHit, SearchResults.

import 'json_read.dart';
import 'people.dart';

/// `SearchHit`: a person matching the search.
class SearchHit extends PersonSummary {
  const SearchHit({
    required super.userId,
    required super.handle,
    required super.name,
    required super.hackyStyle,
    required super.photoUrl,
    required super.role,
    required this.skills,
    required this.matchedSkills,
  });

  final List<String> skills;

  /// Skills that matched `q` (empty when the match was on name or handle).
  final List<String> matchedSkills;

  factory SearchHit.fromJson(Map<String, dynamic> json) {
    final person = PersonSummary.fromJson(json);
    return SearchHit(
      userId: person.userId,
      handle: person.handle,
      name: person.name,
      hackyStyle: person.hackyStyle,
      photoUrl: person.photoUrl,
      role: person.role,
      skills: readStringList(json, 'skills'),
      matchedSkills: readStringList(json, 'matchedSkills'),
    );
  }
}

/// `SearchResults`: most relevant first, empty when nothing matches.
class SearchResults {
  const SearchResults({required this.results});

  final List<SearchHit> results;

  factory SearchResults.fromJson(Map<String, dynamic> json) =>
      SearchResults(results: readList(json, 'results', SearchHit.fromJson));
}
