import '../api_client.dart';
import '../api_exception.dart';
import '../models/auth.dart';
import '../token_store.dart';

/// An in-memory stand-in for [ApiClient] while the server's auth routes don't
/// exist. Turn it on with `--dart-define=FAKE_API=true`.
///
/// Test accounts (password for all: `password123`):
/// - `demo@hacky.dev`: verified, logs in.
/// - `new@hacky.dev`: not verified yet. Resending the verification email
///   verifies it, as if the user had clicked the link.
/// - `offline@hacky.dev`: any request with this email fails as if there were
///   no connection.
///
/// Accounts you register live until the app restarts. They start unverified;
/// resend the verification email to verify them.
class FakeApiClient implements ApiClient {
  FakeApiClient({
    required this._tokenStore,
    this.delay = const Duration(milliseconds: 700),
  }) {
    _add('Demo Hacker', 'demo_hacker', demoEmail, verified: true);
    _add('New Person', 'new_person', unverifiedEmail, verified: false);
  }

  static const demoEmail = 'demo@hacky.dev';
  static const unverifiedEmail = 'new@hacky.dev';
  static const offlineEmail = 'offline@hacky.dev';
  static const testPassword = 'password123';

  static const _tokenPrefix = 'fake-jwt:';

  final TokenStore _tokenStore;

  /// How long each fake request takes, so loading states can be seen.
  final Duration delay;

  final _accounts = <String, _FakeAccount>{};

  @override
  Duration get timeout => delay;

  @override
  Future<void> register(RegisterBody body) async {
    await _respond(body.email);
    if (_accounts.containsKey(body.email)) {
      throw _error(409, 'email_taken', 'That email already has an account.');
    }
    if (_accounts.values.any((a) => a.handle == body.handle)) {
      throw _error(409, 'handle_taken', 'That handle is already taken.');
    }
    _add(body.name, body.handle, body.email, password: body.password);
  }

  @override
  Future<void> verifyEmail(TokenBody body) async {
    await _respond();
    throw _error(400, 'invalid_token', 'Verification happens on the web.');
  }

  @override
  Future<void> resendVerification(EmailBody body) async {
    await _respond(body.email);
    _accounts[body.email]?.verified = true;
  }

  @override
  Future<LoginResult> login(LoginBody body) async {
    await _respond(body.email);
    final account = _accounts[body.email];
    if (account == null || account.password != body.password) {
      throw _error(401, 'invalid_credentials', 'Wrong email or password.');
    }
    if (!account.verified) {
      throw _error(
        403,
        'email_not_verified',
        'Verify your email before logging in. Check your inbox.',
      );
    }
    final token = '$_tokenPrefix${account.email}';
    await _tokenStore.write(token);
    return LoginResult(
      token: token,
      expiresAt: DateTime.now().add(const Duration(days: 7)),
      me: account.me,
    );
  }

  @override
  Future<void> forgotPassword(EmailBody body) => _respond(body.email);

  @override
  Future<void> resetPassword(ResetPasswordBody body) async {
    await _respond();
    throw _error(400, 'invalid_token', 'Password reset happens on the web.');
  }

  @override
  Future<void> logout() => _tokenStore.clear();

  @override
  Future<bool> get isLoggedIn async => (await _tokenStore.read()) != null;

  @override
  Future<Me> getMe() async {
    await _respond();
    final token = await _tokenStore.read();
    final email = token != null && token.startsWith(_tokenPrefix)
        ? token.substring(_tokenPrefix.length)
        : null;
    final account = _accounts[email];
    if (account == null || !account.verified) {
      // Same as ApiClient: a 401 forgets the token.
      await _tokenStore.clear();
      throw _error(401, 'unauthorized', 'Your session expired. Log in again.');
    }
    return account.me;
  }

  @override
  void close() {}

  Future<void> _respond([String? email]) async {
    await Future<void>.delayed(delay);
    if (email == offlineEmail) {
      throw const ApiException(
        statusCode: null,
        code: 'network_error',
        message: 'Fake: no connection',
      );
    }
  }

  void _add(
    String name,
    String handle,
    String email, {
    String password = testPassword,
    bool verified = false,
  }) {
    _accounts[email] = _FakeAccount(
      name: name,
      handle: handle,
      email: email,
      password: password,
      verified: verified,
    );
  }

  static ApiException _error(int status, String code, String message) =>
      ApiException(statusCode: status, code: code, message: message);
}

class _FakeAccount {
  _FakeAccount({
    required this.name,
    required this.handle,
    required this.email,
    required this.password,
    required this.verified,
  });

  final String name;
  final String handle;
  final String email;
  final String password;
  bool verified;

  Me get me => Me(
    profile: PublicProfile(
      userId: email.hashCode.toRadixString(16).padLeft(24, '0'),
      handle: handle,
      name: name,
      hackyStyle: const {},
      photoUrl: null,
      bio: null,
      links: const ProfileLinks(),
      isDemo: true,
    ),
    events: const [
      MyEvent(
        slug: 'knighthacks-ix',
        name: 'Knight Hacks IX',
        role: MemberRole.hacker,
        verified: false,
      ),
    ],
  );
}
