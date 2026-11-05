import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/api_exception.dart';
import 'package:mobile/api/fake/fake_world.dart';
import 'package:mobile/api/models/auth.dart';
import 'package:mobile/people/people_search.dart';

import '../support/screen_harness.dart';
import 'controlled_search_api.dart';

const _wait = Duration(milliseconds: 300);

// testWidgets runs in fake time, so `tester.pump(duration)` moves the
// debounce timer forward without really waiting.
void main() {
  late ControlledSearchApi api;
  late PeopleSearch search;

  setUp(() {
    api = ControlledSearchApi();
    search = PeopleSearch(api: api, eventSlug: fakeEventSlug);
  });
  tearDown(() => search.dispose());

  testWidgets('starts idle and sends nothing for empty or blank text', (
    tester,
  ) async {
    expect(search.state, isA<SearchIdle>());
    search.setText('   ');
    await tester.pump(_wait);

    expect(search.state, isA<SearchIdle>());
    expect(api.calls, isEmpty);
  });

  testWidgets('waits 300 ms after the last keystroke, then asks once', (
    tester,
  ) async {
    search.setText('r');
    await tester.pump(const Duration(milliseconds: 100));
    search.setText('re');
    await tester.pump(const Duration(milliseconds: 100));
    search.setText('rea');
    expect(search.state, isA<SearchLoading>());
    await tester.pump(const Duration(milliseconds: 299));
    expect(api.calls, isEmpty);

    await tester.pump(const Duration(milliseconds: 1));
    expect(api.calls.map((c) => c.q), ['rea']);

    api.calls.single.answer([hit('Leo Nguyen', 'leo_builds')]);
    await tester.pump();
    final found = search.state as SearchFound;
    expect(found.query.text, 'rea');
    expect(found.results.single.handle, 'leo_builds');
  });

  testWidgets('trims the text and caps it at 100 characters', (tester) async {
    search.setText('  rea  ');
    await tester.pump(_wait);
    search.setText('x' * 120);
    await tester.pump(_wait);

    expect(api.calls.map((c) => c.q), ['rea', 'x' * 100]);
  });

  testWidgets('an older answer never overwrites a newer one', (tester) async {
    search.setText('re');
    await tester.pump(_wait);
    search.setText('rea');
    await tester.pump(_wait);
    expect(api.calls.map((c) => c.q), ['re', 'rea']);

    // The newer search answers first, then the old one arrives late.
    api.calls[1].answer([hit('Reagan Smith', 'reagan')]);
    await tester.pump();
    api.calls[0].answer([hit('Andrea Lopez', 'andrea_l')]);
    await tester.pump();

    final found = search.state as SearchFound;
    expect(found.query.text, 'rea');
    expect(found.results.map((h) => h.handle), ['reagan']);
  });

  testWidgets('a reply for text the user already changed is dropped', (
    tester,
  ) async {
    search.setText('re');
    await tester.pump(_wait);
    search.setText('rea');

    // "re" answers during the debounce of "rea": still loading "rea".
    api.calls.single.answer([hit('Andrea Lopez', 'andrea_l')]);
    await tester.pump();
    expect(search.state, isA<SearchLoading>());
    expect(search.state.query.text, 'rea');

    // A late failure of an old search is ignored too.
    await tester.pump(_wait);
    search.setText('reag');
    await tester.pump(_wait);
    api.calls[1].fail(
      const ApiException(statusCode: null, code: 'timeout', message: 'x'),
    );
    await tester.pump();
    expect(search.state, isA<SearchLoading>());
  });

  testWidgets('clearing the text goes idle and drops the pending answer', (
    tester,
  ) async {
    search.setText('rea');
    await tester.pump(_wait);
    search.setText('');
    api.calls.single.answer([hit('Leo Nguyen', 'leo_builds')]);
    await tester.pump();

    expect(search.state, isA<SearchIdle>());
  });

  testWidgets('keeps the shown results while the next search runs', (
    tester,
  ) async {
    search.setText('re');
    await tester.pump(_wait);
    api.calls.single.answer([hit('Leo Nguyen', 'leo_builds')]);
    await tester.pump();

    search.setText('rea');
    final loading = search.state as SearchLoading;
    expect(loading.previous.single.handle, 'leo_builds');
  });

  testWidgets('the role filter asks right away with the same text', (
    tester,
  ) async {
    search.setText('fl');
    await tester.pump(_wait);
    search.setRole(MemberRole.mentor);
    await tester.pump();

    expect(api.calls.map((c) => (c.q, c.role)), [
      ('fl', null),
      ('fl', MemberRole.mentor),
    ]);
    expect(search.state.query.role, MemberRole.mentor);
  });

  testWidgets('a role without text stays idle', (tester) async {
    search.setRole(MemberRole.mentor);
    await tester.pump(_wait);

    expect(search.state, isA<SearchIdle>());
    expect(search.state.query.role, MemberRole.mentor);
    expect(api.calls, isEmpty);
  });

  testWidgets('submit skips the rest of the debounce', (tester) async {
    search.setText('rea');
    search.submit();
    await tester.pump();
    expect(api.calls.map((c) => c.q), ['rea']);

    await tester.pump(_wait);
    expect(api.calls, hasLength(1));
  });

  testWidgets('a failure can be retried', (tester) async {
    search.setText('rea');
    await tester.pump(_wait);
    api.calls.single.fail(
      const ApiException(statusCode: null, code: 'network_error', message: 'x'),
    );
    await tester.pump();
    expect(search.state, isA<SearchFailed>());

    search.retry();
    await tester.pump();
    expect(search.state, isA<SearchLoading>());
    api.calls[1].answer([]);
    await tester.pump();

    expect((search.state as SearchFound).results, isEmpty);
    expect(api.calls.map((c) => c.q), ['rea', 'rea']);
  });

  testWidgets('searches the fake server with partial matches', (tester) async {
    final (:api, store: _) = signedInFakeApi();
    final real = PeopleSearch(api: api, eventSlug: fakeEventSlug);
    addTearDown(real.dispose);

    real.setText('rea');
    await tester.pump(_wait);
    // The fake answers after a few zero-length delays.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    final found = real.state as SearchFound;
    expect(found.results.map((h) => h.name), ['Leo Nguyen', 'Jordan Lee']);
    expect(found.results.first.matchedSkills, ['react']);
  });
}
