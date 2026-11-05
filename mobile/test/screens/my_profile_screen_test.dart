import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/api_exception.dart';
import 'package:mobile/api/fake/fake_api_client.dart';
import 'package:mobile/api/fake/fake_world.dart';
import 'package:mobile/api/models/auth.dart';
import 'package:mobile/api/models/events.dart';
import 'package:mobile/api/models/me.dart';
import 'package:mobile/auth/error_text.dart';
import 'package:mobile/routes.dart';
import 'package:mobile/screens/my_profile_screen.dart';
import 'package:mobile/widgets/hacky_style_sheet.dart';

import '../support/screen_harness.dart';

const _network = ApiException(
  statusCode: null,
  code: 'network_error',
  message: 'x',
);

/// A signed-in fake whose calls can be made to fail.
class FlakyApi extends FakeApiClient {
  FlakyApi({Duration delay = Duration.zero})
    : super(tokenStore: _signedIn(), delay: delay);

  static MemoryTokenStore _signedIn() =>
      MemoryTokenStore()..token = 'fake-jwt:${FakeApiClient.demoEmail}';

  ApiException? eventMeError;
  ApiException? profileError;
  ApiException? intakeError;

  @override
  Future<EventMe> getEventMe(String slug) async {
    if (eventMeError case final e?) throw e;
    return super.getEventMe(slug);
  }

  @override
  Future<PublicProfile> updateProfile(UpdateProfileBody body) async {
    if (profileError case final e?) throw e;
    return super.updateProfile(body);
  }

  @override
  Future<EventMe> updateEventMe(String slug, UpdateEventMeBody body) async {
    if (intakeError case final e?) throw e;
    return super.updateEventMe(slug, body);
  }
}

/// Profiles the screen passed to `onProfileChanged`.
final changed = <PublicProfile>[];

Widget profileScreen(FakeApiClient api, {String? eventSlug = fakeEventSlug}) =>
    MyProfileScreen(
      api: api,
      me: demoMe,
      eventSlug: eventSlug,
      onProfileChanged: changed.add,
    );

final save = find.byKey(MyProfileScreen.saveKey);

bool canSave(WidgetTester tester) =>
    tester.widget<FilledButton>(save).onPressed != null;

Future<void> typeInto(WidgetTester tester, String id, String text) async {
  final field = find.byKey(Key(id));
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

void main() {
  setUp(changed.clear);

  testWidgets('shows the profile, then the event part', (tester) async {
    await pumpScreen(tester, profileScreen(FlakyApi()));

    expect(find.text('Demo Hacker\n@demo_hacker'), findsOneWidget);
    expect(find.text('Change Hacky style'), findsOneWidget);
    expect(find.text('Loading your event details…'), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.text('KNIGHT HACKS IX'), findsOneWidget);
    expect(find.text('Hacker'), findsOneWidget);
    for (final label in [
      'Name',
      'Bio',
      'GitHub',
      'Skills',
      'Skills you want to learn',
      'Experience',
      'Goal',
      'Track',
      'Interests',
      'Idea',
      'Looking for a team',
      'Sign out',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(canSave(tester), isFalse);
  });

  testWidgets('saves a changed name and tells the shell', (tester) async {
    final api = FlakyApi();
    await pumpScreen(tester, profileScreen(api));
    await tester.pumpAndSettle();

    await typeInto(tester, 'profile-name', 'Demo Hacker');
    expect(canSave(tester), isFalse, reason: 'same as saved');

    await typeInto(tester, 'profile-name', '  Ethan Zeng ');
    await typeInto(tester, 'profile-bio', 'I like backends.');
    expect(canSave(tester), isTrue);
    await tapOn(tester, save);

    expect(find.text('Profile saved.'), findsOneWidget);
    expect(changed.single.name, 'Ethan Zeng');
    expect(changed.single.bio, 'I like backends.');
    expect(canSave(tester), isFalse);
    final me = await tester.runAsync(api.getMe);
    expect(me!.profile.name, 'Ethan Zeng');
  });

  testWidgets('shows Saving… while the save runs', (tester) async {
    final api = FlakyApi(delay: const Duration(milliseconds: 300));
    await pumpScreen(tester, profileScreen(api));
    await tester.pumpAndSettle();

    await typeInto(tester, 'profile-name', 'Ethan Zeng');
    await tester.tap(save);
    await tester.pump();
    expect(find.text('Saving…'), findsOneWidget);
    expect(canSave(tester), isFalse);

    await tester.pumpAndSettle();
    expect(find.text('Saving…'), findsNothing);
    expect(changed.single.name, 'Ethan Zeng');
  });

  testWidgets('field errors show under each field and nothing is sent', (
    tester,
  ) async {
    await pumpScreen(tester, profileScreen(FlakyApi()));
    await tester.pumpAndSettle();

    await typeInto(tester, 'profile-name', '   ');
    await typeInto(tester, 'profile-github', 'http://github.com/me');
    await tapOn(tester, save);

    const nameError =
        'Enter your name so your teammates know what to call you.';
    expect(find.text(nameError), findsOneWidget);
    expect(find.text('Use an https:// link.'), findsOneWidget);
    expect(changed, isEmpty);

    // Fixed as you type, once Save was tapped.
    await typeInto(tester, 'profile-name', 'Demo');
    expect(find.text(nameError), findsNothing);
    expect(find.text('Use an https:// link.'), findsOneWidget);
  });

  testWidgets('links get https:// when it is left out', (tester) async {
    final api = FlakyApi();
    await pumpScreen(tester, profileScreen(api));
    await tester.pumpAndSettle();

    await typeInto(tester, 'profile-github', 'github.com/demo');
    await tapOn(tester, save);

    expect(changed.single.links.github, 'https://github.com/demo');
    final github = tester.widget<TextField>(find.byKey(const Key('profile-github')));
    expect(github.controller!.text, 'https://github.com/demo');
  });

  testWidgets('server field errors show under their field', (tester) async {
    final api = FlakyApi()
      ..profileError = const ApiException(
        statusCode: 400,
        code: 'invalid_input',
        message: 'Invalid input',
        details: [
          ApiErrorDetail(path: ['links', 'github'], message: 'Not a GitHub URL'),
        ],
      );
    await pumpScreen(tester, profileScreen(api));
    await tester.pumpAndSettle();

    await typeInto(tester, 'profile-github', 'https://example.com/me');
    await tapOn(tester, save);

    expect(find.text('Not a GitHub URL'), findsOneWidget);
    expect(find.text('Invalid input'), findsOneWidget);
    expect(changed, isEmpty);

    // The next edit clears it.
    await typeInto(tester, 'profile-github', 'https://github.com/me');
    expect(find.text('Not a GitHub URL'), findsNothing);
  });

  testWidgets('adds and removes skills as chips', (tester) async {
    final api = FlakyApi();
    await pumpScreen(tester, profileScreen(api));
    await tester.pumpAndSettle();

    Future<void> add(String skill) async {
      await tapOn(tester, find.byKey(const Key('profile-skills-add')));
      await typeInto(tester, 'profile-skills-input', skill);
      await tapOn(tester, find.byKey(const Key('profile-skills-confirm')));
    }

    await add('React');
    await typeInto(tester, 'profile-skills-input', 'Node');
    await tapOn(tester, find.byKey(const Key('profile-skills-confirm')));
    await typeInto(tester, 'profile-skills-input', 'react');
    await tapOn(tester, find.byKey(const Key('profile-skills-confirm')));
    expect(find.text('That’s already on the list.'), findsOneWidget);

    expect(find.widgetWithText(InputChip, 'React'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'Node'), findsOneWidget);
    await tapOn(tester, find.byTooltip('Remove Node'));
    expect(find.widgetWithText(InputChip, 'Node'), findsNothing);

    await tapOn(tester, save);
    final saved = await tester.runAsync(() => api.getEventMe(fakeEventSlug));
    expect(saved!.intake.skills, ['React']);
  });

  testWidgets('saves experience, goal, track, idea and looking', (
    tester,
  ) async {
    final api = FlakyApi();
    await pumpScreen(tester, profileScreen(api));
    await tester.pumpAndSettle();

    await tapOn(tester, find.text('Advanced'));
    await tapOn(tester, find.text('Ship a project'));
    await tapOn(tester, find.text('Fintech'));
    await typeInto(tester, 'profile-idea', 'A budgeting app for students');
    await tapOn(tester, find.byKey(const Key('profile-looking')));
    await tapOn(tester, save);

    expect(find.text('Profile saved.'), findsOneWidget);
    expect(changed, isEmpty, reason: 'only the event part changed');
    final saved = await tester.runAsync(() => api.getEventMe(fakeEventSlug));
    expect(saved!.intake.experience, Experience.advanced);
    expect(saved.intake.goal, HackGoal.ship);
    expect(saved.intake.track, 'Fintech');
    expect(saved.intake.idea, 'A budgeting app for students');
    expect(saved.looking, isFalse);

    // Tapping the chosen track again clears it.
    await tapOn(tester, find.text('Fintech'));
    await tapOn(tester, save);
    final cleared = await tester.runAsync(() => api.getEventMe(fakeEventSlug));
    expect(cleared!.intake.track, isNull);
  });

  testWidgets('says so when only the profile part saved', (tester) async {
    final api = FlakyApi()..intakeError = _network;
    await pumpScreen(tester, profileScreen(api));
    await tester.pumpAndSettle();

    await typeInto(tester, 'profile-name', 'Ethan Zeng');
    await tapOn(tester, find.text('Beginner'));
    await tapOn(tester, save);

    expect(
      find.text(
        'Your profile was saved, but your event details weren’t. '
        '${ErrorText.unreachable}',
      ),
      findsOneWidget,
    );
    expect(changed.single.name, 'Ethan Zeng');
    expect(canSave(tester), isTrue, reason: 'the event part is still unsaved');

    api.intakeError = null;
    await tapOn(tester, save);
    expect(find.text('Profile saved.'), findsOneWidget);
    expect(changed, hasLength(1), reason: 'the profile was not sent again');
  });

  testWidgets('a failed event load can be retried', (tester) async {
    final api = FlakyApi()..eventMeError = _network;
    await pumpScreen(tester, profileScreen(api));
    await tester.pumpAndSettle();

    expect(find.text(ErrorText.unreachable), findsOneWidget);
    expect(find.text('Name'), findsOneWidget, reason: 'profile still edits');

    api.eventMeError = null;
    await tapOn(tester, find.text('Try again'));
    expect(find.text(ErrorText.unreachable), findsNothing);
    expect(find.text('Skills'), findsOneWidget);
  });

  testWidgets('an expired session goes back to log in', (tester) async {
    final (:api, :store) = fakeApi();
    store.token = 'fake-jwt:nobody@example.com';
    final visits = await pumpScreen(tester, profileScreen(api));
    await tester.pumpAndSettle();

    expect(visits.single.route, Routes.login);
  });

  testWidgets('without an event only the profile part shows', (tester) async {
    await pumpScreen(tester, profileScreen(FlakyApi(), eventSlug: null));
    await tester.pumpAndSettle();

    expect(find.textContaining('Join an event on Home'), findsOneWidget);
    expect(find.text('Skills'), findsNothing);

    await typeInto(tester, 'profile-name', 'Ethan Zeng');
    await tapOn(tester, save);
    expect(changed.single.name, 'Ethan Zeng');
  });

  testWidgets('changes the Hacky style and saves it', (tester) async {
    await pumpScreen(tester, profileScreen(FlakyApi()));
    await tester.pumpAndSettle();

    await tapOn(tester, find.text('Change Hacky style'));
    expect(find.text('Make Hacky yours'), findsOneWidget);
    await tapOn(tester, find.text('Berry'));
    await tapOn(tester, find.text('Love bug'));
    await tapOn(tester, find.byKey(HackyStyleSheet.doneKey));

    expect(find.text('Make Hacky yours'), findsNothing);
    expect(canSave(tester), isTrue);
    await tapOn(tester, save);

    expect(changed.single.hackyStyle, containsPair('color', 'berry'));
    expect(changed.single.hackyStyle, containsPair('flair', 'hearts'));
  });

  testWidgets('sign out forgets the token and returns to log in', (
    tester,
  ) async {
    final (:api, :store) = signedInFakeApi();
    final visits = await pumpScreen(tester, profileScreen(api));
    await tester.pumpAndSettle();

    await tapOn(tester, find.text('Sign out'));

    expect(store.token, isNull);
    expect(visits.single.route, Routes.login);
  });

  testWidgets('sign out with unsaved changes asks first', (tester) async {
    final (:api, :store) = signedInFakeApi();
    final visits = await pumpScreen(tester, profileScreen(api));
    await tester.pumpAndSettle();

    await typeInto(tester, 'profile-name', 'Ethan Zeng');
    await tapOn(tester, find.text('Sign out'));
    expect(find.text('Discard your changes?'), findsOneWidget);

    await tapOn(tester, find.text('Keep editing'));
    expect(store.token, isNotNull);
    expect(visits, isEmpty);

    await tapOn(tester, find.text('Sign out'));
    await tapOn(tester, find.widgetWithText(TextButton, 'Sign out'));
    expect(store.token, isNull);
    expect(visits.single.route, Routes.login);
  });
}
