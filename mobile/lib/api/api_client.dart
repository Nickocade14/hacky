import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'api_exception.dart';
import 'models/auth.dart';
import 'models/events.dart';
import 'models/json_read.dart';
import 'models/me.dart';
import 'models/people.dart';
import 'models/teams.dart';
import 'token_store.dart';

/// The one place the app talks to the Hacky API (docs/openapi.yaml).
///
/// Every method throws [ApiException] on failure.
class ApiClient {
  ApiClient({
    required this._tokenStore,
    http.Client? httpClient,
    String baseUrl = ApiConfig.baseUrl,
    this.timeout = const Duration(seconds: 15),
  }) : _http = httpClient ?? http.Client(),
       _baseUrl = baseUrl.endsWith('/')
           ? baseUrl.substring(0, baseUrl.length - 1)
           : baseUrl;

  final TokenStore _tokenStore;
  final http.Client _http;
  final String _baseUrl;
  final Duration timeout;

  // ---------------------------------------------------------------- auth

  /// Creates the account and sends the verification email.
  Future<void> register(RegisterBody body) =>
      _send('POST', '/api/auth/register', body: body.toJson(), auth: false);

  Future<void> verifyEmail(TokenBody body) =>
      _send('POST', '/api/auth/verify-email', body: body.toJson(), auth: false);

  Future<void> resendVerification(EmailBody body) => _send(
    'POST',
    '/api/auth/resend-verification',
    body: body.toJson(),
    auth: false,
  );

  /// Logs in and saves the JWT for later requests.
  Future<LoginResult> login(LoginBody body) async {
    final json = await _send(
      'POST',
      '/api/auth/login',
      body: body.toJson(),
      auth: false,
    );
    final result = _parse(json, LoginResult.fromJson);
    await _tokenStore.write(result.token);
    return result;
  }

  Future<void> forgotPassword(EmailBody body) => _send(
    'POST',
    '/api/auth/forgot-password',
    body: body.toJson(),
    auth: false,
  );

  Future<void> resetPassword(ResetPasswordBody body) => _send(
    'POST',
    '/api/auth/reset-password',
    body: body.toJson(),
    auth: false,
  );

  /// There's no logout endpoint; the JWT is forgotten on the device.
  Future<void> logout() => _tokenStore.clear();

  Future<bool> get isLoggedIn async => (await _tokenStore.read()) != null;

  // ---------------------------------------------------------------- me

  /// The signed-in user's profile and events.
  Future<Me> getMe() async =>
      _parse(await _send('GET', '/api/me'), Me.fromJson);

  /// Updates my public profile and returns it. [body] must set at least one
  /// field (the contract's `minProperties: 1`).
  Future<PublicProfile> updateProfile(UpdateProfileBody body) async {
    if (body.isEmpty) {
      throw ArgumentError.value(body, 'body', 'Set at least one field');
    }
    return _parse(
      await _send('PATCH', '/api/me/profile', body: body.toJson()),
      PublicProfile.fromJson,
    );
  }

  // ---------------------------------------------------------------- events

  /// Events a user can join.
  Future<List<EventInfo>> listEvents() async => _parseList(
    await _send('GET', '/api/events'),
    'events',
    EventInfo.fromJson,
  );

  /// Event info and theme.
  Future<EventInfo> getEvent(String slug) async => _parse(
    await _send('GET', '/api/events/${_seg(slug)}'),
    EventInfo.fromJson,
  );

  /// Joins the event. Joining again returns the same membership. Mentors
  /// start unverified until an organizer verifies them.
  Future<EventMe> joinEvent(
    String slug, [
    JoinEventBody body = const JoinEventBody(),
  ]) async => _parse(
    await _send('POST', '/api/events/${_seg(slug)}/join', body: body.toJson()),
    EventMe.fromJson,
  );

  /// My membership and intake in this event.
  Future<EventMe> getEventMe(String slug) async => _parse(
    await _send('GET', '/api/events/${_seg(slug)}/me'),
    EventMe.fromJson,
  );

  /// Updates my intake, availability or looking flag (partial update).
  Future<EventMe> updateEventMe(String slug, UpdateEventMeBody body) async =>
      _parse(
        await _send(
          'PATCH',
          '/api/events/${_seg(slug)}/me',
          body: body.toJson(),
        ),
        EventMe.fromJson,
      );

  // ---------------------------------------------------------------- people

  /// A person's full profile in this event. 404 if they aren't in the event
  /// or either person blocked the other.
  Future<PersonDetail> getPerson(String slug, String handle) async => _parse(
    await _send('GET', '/api/events/${_seg(slug)}/people/${_seg(handle)}'),
    PersonDetail.fromJson,
  );

  // ---------------------------------------------------------------- teams

  /// The team I lead or belong to in this event, or null when I'm on none.
  Future<MyTeam?> getMyTeam(String slug) async =>
      _parse(await _send('GET', '/api/events/${_seg(slug)}/me/team'), (json) {
        if (!json.containsKey('team')) {
          throw const FormatException('"team" is missing');
        }
        final team = readNullableObject(json, 'team');
        return team == null ? null : MyTeam.fromJson(team);
      });

  /// Creates my team; I become its owner and first member. 409 if I'm
  /// already on a team in this event.
  Future<TeamDetail> createTeam(String slug, CreateTeamBody body) async =>
      _parse(
        await _send(
          'POST',
          '/api/events/${_seg(slug)}/teams',
          body: body.toJson(),
        ),
        TeamDetail.fromJson,
      );

  /// Team details with its members.
  Future<TeamDetail> getTeam(String slug, String teamId) async => _parse(
    await _send('GET', '/api/events/${_seg(slug)}/teams/${_seg(teamId)}'),
    TeamDetail.fromJson,
  );

  void close() => _http.close();

  // ---------------------------------------------------------------- internals

  /// Sends a JSON request and returns the decoded body (null when empty).
  /// With [auth], sends `Authorization: Bearer <jwt>` and forgets the token
  /// when the server answers 401.
  Future<Object?> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool auth = true,
  }) async {
    var url = Uri.parse('$_baseUrl$path');
    if (query != null && query.isNotEmpty) {
      url = url.replace(queryParameters: query);
    }
    final request = http.Request(method, url)
      ..headers['Accept'] = 'application/json';
    if (auth) {
      final token = await _tokenStore.read();
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
    }
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _http.send(request).timeout(timeout),
      ).timeout(timeout);
    } on TimeoutException {
      throw const ApiException(
        statusCode: null,
        code: 'timeout',
        message: 'The server took too long to answer',
      );
    } on http.ClientException catch (e) {
      throw ApiException(
        statusCode: null,
        code: 'network_error',
        message: e.message,
      );
    }

    final status = response.statusCode;
    final text = utf8.decode(response.bodyBytes, allowMalformed: true);
    final Object? json;
    try {
      json = text.isEmpty ? null : jsonDecode(text);
    } on FormatException {
      if (status >= 200 && status < 300) throw _invalidResponse(status);
      throw ApiException.fromResponse(status, null);
    }

    if (status >= 200 && status < 300) return json;
    if (auth && status == 401) await _tokenStore.clear();
    throw ApiException.fromResponse(status, json);
  }

  /// Encodes a path parameter (slug, handle, id) so it can't change the path.
  static String _seg(String value) => Uri.encodeComponent(value);

  /// Parses a `{ "<key>": [ ... ] }` wrapper into its list.
  List<T> _parseList<T>(
    Object? json,
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) => _parse(json, (map) => readList(map, key, fromJson));

  T _parse<T>(Object? json, T Function(Map<String, dynamic>) fromJson) {
    if (json is! Map<String, dynamic>) throw _invalidResponse(200);
    try {
      return fromJson(json);
    } on FormatException catch (e) {
      throw ApiException(
        statusCode: 200,
        code: 'invalid_response',
        message: e.message,
      );
    }
  }

  ApiException _invalidResponse(int status) => ApiException(
    statusCode: status,
    code: 'invalid_response',
    message: "The server's response doesn't match the API contract",
  );
}
