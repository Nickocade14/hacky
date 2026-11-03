// Auth request and response bodies from docs/openapi.yaml.
// Class names match the contract's schema names. Change the contract first.

import 'json_read.dart';

/// `RegisterBody`: `POST /api/auth/register`.
class RegisterBody {
  const RegisterBody({
    required this.name,
    required this.handle,
    required this.email,
    required this.password,
  });

  final String name;
  final String handle;
  final String email;
  final String password;

  Map<String, dynamic> toJson() => {
    'name': name,
    'handle': handle,
    'email': email,
    'password': password,
  };
}

/// `LoginBody`: `POST /api/auth/login`.
class LoginBody {
  const LoginBody({required this.email, required this.password});

  final String email;
  final String password;

  Map<String, dynamic> toJson() => {'email': email, 'password': password};
}

/// `TokenBody`: `POST /api/auth/verify-email`.
class TokenBody {
  const TokenBody({required this.token});

  final String token;

  Map<String, dynamic> toJson() => {'token': token};
}

/// `EmailBody`: `POST /api/auth/resend-verification` and `/api/auth/forgot-password`.
class EmailBody {
  const EmailBody({required this.email});

  final String email;

  Map<String, dynamic> toJson() => {'email': email};
}

/// `ResetPasswordBody`: `POST /api/auth/reset-password`.
class ResetPasswordBody {
  const ResetPasswordBody({required this.token, required this.password});

  final String token;
  final String password;

  Map<String, dynamic> toJson() => {'token': token, 'password': password};
}

/// `LoginResult`: the 200 response of `POST /api/auth/login`.
class LoginResult {
  const LoginResult({
    required this.token,
    required this.expiresAt,
    required this.me,
  });

  /// The JWT, sent as `Authorization: Bearer <token>`.
  final String token;
  final DateTime expiresAt;
  final Me me;

  factory LoginResult.fromJson(Map<String, dynamic> json) => LoginResult(
    token: readString(json, 'token'),
    expiresAt: readDateTime(json, 'expiresAt'),
    me: Me.fromJson(readObject(json, 'me')),
  );
}

/// `Me`: the signed-in user, returned in `LoginResult` and by `GET /api/me`.
class Me {
  const Me({required this.profile, required this.events});

  final PublicProfile profile;
  final List<MyEvent> events;

  factory Me.fromJson(Map<String, dynamic> json) => Me(
    profile: PublicProfile.fromJson(readObject(json, 'profile')),
    events: readList(json, 'events', MyEvent.fromJson),
  );
}

/// `PublicProfile`. Never includes email.
class PublicProfile {
  const PublicProfile({
    required this.userId,
    required this.handle,
    required this.name,
    required this.hackyStyle,
    required this.photoUrl,
    required this.bio,
    required this.links,
    required this.isDemo,
  });

  final String userId;
  final String handle;
  final String name;

  /// `HackyStyle`: avatar options. Unknown keys pass through, so it stays a map.
  final Map<String, dynamic> hackyStyle;

  /// An `/assets/` path or an https URL.
  final String? photoUrl;
  final String? bio;
  final ProfileLinks links;
  final bool isDemo;

  factory PublicProfile.fromJson(Map<String, dynamic> json) => PublicProfile(
    userId: readString(json, 'userId'),
    handle: readString(json, 'handle'),
    name: readString(json, 'name'),
    hackyStyle: readObject(json, 'hackyStyle'),
    photoUrl: readNullableString(json, 'photoUrl'),
    bio: readNullableString(json, 'bio'),
    links: ProfileLinks.fromJson(readObject(json, 'links')),
    isDemo: readBool(json, 'isDemo'),
  );
}

/// `ProfileLinks`. Every link is optional.
class ProfileLinks {
  const ProfileLinks({this.github, this.linkedin, this.website});

  final String? github;
  final String? linkedin;
  final String? website;

  factory ProfileLinks.fromJson(Map<String, dynamic> json) => ProfileLinks(
    github: readNullableString(json, 'github'),
    linkedin: readNullableString(json, 'linkedin'),
    website: readNullableString(json, 'website'),
  );
}

/// `MemberRole`.
enum MemberRole { hacker, mentor, sponsor, organizer }

/// `MyEvent`: one of the signed-in user's events.
class MyEvent {
  const MyEvent({
    required this.slug,
    required this.name,
    required this.role,
    required this.verified,
  });

  final String slug;
  final String name;
  final MemberRole role;
  final bool verified;

  factory MyEvent.fromJson(Map<String, dynamic> json) => MyEvent(
    slug: readString(json, 'slug'),
    name: readString(json, 'name'),
    role: readEnum(json, 'role', MemberRole.values),
    verified: readBool(json, 'verified'),
  );
}
