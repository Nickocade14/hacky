import 'dart:async';

import 'package:mobile/api/fake/fake_api_client.dart';
import 'package:mobile/api/models/auth.dart';
import 'package:mobile/api/models/search.dart';

import '../support/screen_harness.dart';

/// One `GET /api/search` the test answers by hand.
class SearchCall {
  SearchCall(this.q, this.role);

  final String q;
  final MemberRole? role;
  final reply = Completer<SearchResults>();

  void answer(List<SearchHit> hits) =>
      reply.complete(SearchResults(results: hits));

  void fail(Object error) => reply.completeError(error);
}

/// A fake whose search waits until the test answers each call, so replies
/// can arrive late and out of order.
class ControlledSearchApi extends FakeApiClient {
  ControlledSearchApi()
    : super(tokenStore: MemoryTokenStore(), delay: Duration.zero);

  final calls = <SearchCall>[];

  @override
  Future<SearchResults> search({
    required String event,
    required String q,
    MemberRole? role,
    int? limit,
  }) {
    final call = SearchCall(q, role);
    calls.add(call);
    return call.reply.future;
  }
}

/// A search hit with just what the screens show.
SearchHit hit(
  String name,
  String handle, {
  List<String> skills = const [],
  List<String> matched = const [],
  MemberRole role = MemberRole.hacker,
}) => SearchHit(
  userId: 'id-$handle',
  handle: handle,
  name: name,
  hackyStyle: const {},
  photoUrl: null,
  role: role,
  skills: skills,
  matchedSkills: matched,
);
