import '../api_exception.dart';
import '../models/auth.dart';
import '../models/me.dart';
import 'fake_world.dart';

/// In-memory versions of the non-auth [ApiClient] endpoints, with realistic
/// data (see fake_world.dart). Add it to a fake client that implements the
/// auth routes:
///
/// ```dart
/// class FakeApiClient with FakeEndpoints implements ApiClient { ... }
/// ```
///
/// The host's [getMe] says who is signed in (it should throw a 401
/// [ApiException] when nobody is, and wait to simulate latency). Each user
/// gets their own copy of the data. To show profile edits and joined events
/// in the host's own `getMe`, pass its result through [fakeApplyChanges].
mixin FakeEndpoints {
  /// Implemented by the host fake.
  Future<Me> getMe();

  final _worlds = <String, FakeWorld>{};

  /// The signed-in user's world. Throws what the host's [getMe] throws.
  Future<FakeWorld> fakeWorld() async {
    final me = await getMe();
    return _worlds.putIfAbsent(
      me.profile.userId,
      () => FakeWorld(me.profile, me.events),
    );
  }

  /// [me] with the profile edits and event joins made through the fake.
  Me fakeApplyChanges(Me me) {
    final world = _worlds[me.profile.userId];
    if (world == null) return me;
    final membership = world.me.membership;
    return Me(
      profile: world.me.profile,
      events: [
        for (final e in me.events)
          if (e.slug != fakeEventSlug) e,
        if (membership != null)
          MyEvent(
            slug: fakeEventSlug,
            name: world.event.name,
            role: membership.role,
            verified: membership.verified,
          ),
      ],
    );
  }

  // ---------------------------------------------------------------- me

  Future<PublicProfile> updateProfile(UpdateProfileBody body) async {
    if (body.isEmpty) {
      throw ArgumentError.value(body, 'body', 'Set at least one field');
    }
    final me = (await fakeWorld()).me;
    final name = body.name;
    if (name != null && (name.trim().isEmpty || name.length > 80)) {
      throw fakeInvalid('name', 'Must be 1 to 80 characters');
    }
    final bio = body.bio;
    if (bio != null && (bio.value?.length ?? 0) > 500) {
      throw fakeInvalid('bio', 'Must be at most 500 characters');
    }
    if (name != null) me.name = name;
    if (bio != null) me.bio = bio.value;
    if (body.hackyStyle != null) me.hackyStyle = body.hackyStyle!;
    if (body.links != null) me.links = body.links!;
    return me.profile;
  }
}

/// An error shaped like the server's.
ApiException fakeError(int status, String code, String message) =>
    ApiException(statusCode: status, code: code, message: message);

/// A 400 `invalid_input` with one field detail.
ApiException fakeInvalid(String field, String message) => ApiException(
  statusCode: 400,
  code: 'invalid_input',
  message: 'Invalid input',
  details: [
    ApiErrorDetail(path: [field], message: message),
  ],
);
