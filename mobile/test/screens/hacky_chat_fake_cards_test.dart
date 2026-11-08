import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/fake/fake_world.dart';
import 'package:mobile/routes.dart';
import 'package:mobile/screens/hacky_chat_screen.dart';
import 'package:mobile/widgets/hacky_cards.dart';
import 'package:mobile/widgets/hacky_chat_widgets.dart';

import '../support/screen_harness.dart';

// The plain fake client (what `flutter run --dart-define=FAKE_API=true`
// uses), not a scripted reply: its answers must render as 12's cards.
void main() {
  testWidgets('the fake answers a teammate search with person cards', (
    tester,
  ) async {
    final api = signedInFakeApi().api;
    final visits = await pumpScreen(
      tester,
      HackyChatScreen(api: api, me: demoMe, eventSlug: fakeEventSlug),
    );
    await tester.pumpAndSettle();

    await tapOn(tester, find.text('Find a teammate who knows React'));

    expect(find.textContaining('Here\'s who could help', skipOffstage: false), findsOneWidget);
    expect(find.byType(PersonMatchCard, skipOffstage: false), findsNWidgets(2));
    expect(find.text('2 PEOPLE', skipOffstage: false), findsOneWidget);
    expect(find.text('@leo_builds · Hacker', skipOffstage: false), findsOneWidget);
    expect(find.text('@jordan_ux · Hacker', skipOffstage: false), findsOneWidget);
    expect(find.text('Knows react', skipOffstage: false), findsNWidgets(2));

    await tapOn(tester, find.text('Leo Nguyen', skipOffstage: false));

    expect(visits.single.route, Routes.person);
    expect((visits.single.arguments as PersonArgs).handle, 'leo_builds');
  });

  testWidgets('the fake answers a mentor search with a mentor card', (
    tester,
  ) async {
    final api = signedInFakeApi().api;
    await pumpScreen(
      tester,
      HackyChatScreen(api: api, me: demoMe, eventSlug: fakeEventSlug),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(ChatComposer.fieldKey),
      'Find a Flutter mentor',
    );
    await tester.pump();
    await tapOn(tester, find.byKey(ChatComposer.sendKey));

    expect(find.byType(PersonMatchCard, skipOffstage: false), findsOneWidget);
    expect(find.text('@sam_mentor · Mentor', skipOffstage: false), findsOneWidget);
  });
}
