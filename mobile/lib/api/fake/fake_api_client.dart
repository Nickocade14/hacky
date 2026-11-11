import '../api_client.dart';
import '../api_exception.dart';
import '../models/auth.dart';
import '../token_store.dart';
import 'fake_endpoints.dart';

/// An in-memory stand-in for [ApiClient] while the server's routes don't
/// exist. Turn it on with `--dart-define=FAKE_API=true`.
///
/// Auth lives here; every other endpoint comes from [FakeEndpoints].
///
/// Test accounts (password for all: `password123`):
/// - `demo@hacky.dev`: logs in.
/// - `offline@hacky.dev`: any request with this email fails as if there were
///   no connection.
///
/// Every emailed code is [testCode]. Like the server, registering only saves
/// a pending sign-up; the account exists once [verifyEmail] gets the code.
/// Accounts you create live until the app restarts.
class FakeApiClient with FakeEndpoints implements ApiClient {
  FakeApiClient({
    required this._tokenStore,
    this.delay = const Duration(milliseconds: 700),
  }) {
    _add('Demo Hacker', 'demo_hacker', demoEmail);
  }

  static const demoEmail = 'demo@hacky.dev';
  static const offlineEmail = 'offline@hacky.dev';
  static const testPassword = 'password123';

  /// The code "emailed" for every sign-up and password reset.
  static const testCode = '123456';

  static const _tokenPrefix = 'fake-jwt:';

  final TokenStore _tokenStore;

  /// How long each fake request takes, so loading states can be seen.
  final Duration delay;

  final _accounts = <String, _FakeAccount>{};

  /// Sign-ups waiting for their code, by email.
  final _pending = <String, _FakeAccount>{};

  /// Emails that asked for a reset code.
  final _resets = <String>{};

  @override
  Duration get timeout => delay;

  @override
  Future<void> register(RegisterBody body) async {
    await _respond(body.email);
    if (_accounts.containsKey(body.email)) {
      throw _error(
        409,
        'email_taken',
        'That email already has an account. Log in instead.',
      );
    }
    if (_handleTaken(body.handle)) throw _handleTakenError();
    _pending[body.email] = _FakeAccount(
      name: body.name,
      handle: body.handle,
      email: body.email,
      password: body.password,
    );
  }

  @override
  Future<LoginResult> verifyEmail(VerifyCodeBody body) async {
    await _respond(body.email);
    final pending = _pending[body.email];
    if (pending == null || body.code != testCode) throw _invalidCode();
    _pending.remove(body.email);
    // Someone took the username while this sign-up waited.
    if (_handleTaken(pending.handle)) throw _handleTakenError();
    _accounts[body.email] = pending;
    return _signIn(pending);
  }

  @override
  Future<void> resendVerification(EmailBody body) => _respond(body.email);

  @override
  Future<LoginResult> login(LoginBody body) async {
    await _respond(body.login);
    // Like the server: an @ after the first character means an email.
    final login = body.login.trim().toLowerCase();
    final handle = login.startsWith('@') ? login.substring(1) : login;
    final account = login.indexOf('@') > 0
        ? _accounts[login]
        : _accounts.values.where((a) => a.handle == handle).firstOrNull;
    if (account == null || account.password != body.password) {
      throw _error(
        401,
        'invalid_credentials',
        'Wrong email, username or password.',
      );
    }
    return _signIn(account);
  }

  @override
  Future<void> forgotPassword(EmailBody body) async {
    await _respond(body.email);
    if (_accounts.containsKey(body.email)) _resets.add(body.email);
  }

  @override
  Future<LoginResult> resetPassword(ResetCodeBody body) async {
    await _respond(body.email);
    final account = _accounts[body.email];
    if (account == null ||
        !_resets.contains(body.email) ||
        body.code != testCode) {
      throw _invalidCode();
    }
    _resets.remove(body.email);
    account.password = body.password;
    return _signIn(account);
  }

  bool _handleTaken(String handle) =>
      _accounts.values.any((a) => a.handle == handle);

  Future<LoginResult> _signIn(_FakeAccount account) async {
    final token = '$_tokenPrefix${account.email}';
    await _tokenStore.write(token);
    return LoginResult(
      token: token,
      expiresAt: DateTime.now().add(const Duration(days: 7)),
      me: account.me,
    );
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
    if (account == null) {
      // Same as ApiClient: a 401 forgets the token.
      await _tokenStore.clear();
      throw _error(401, 'unauthorized', 'Your session expired. Log in again.');
    }
    return fakeApplyChanges(account.me);
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

  void _add(String name, String handle, String email) {
    _accounts[email] = _FakeAccount(
      name: name,
      handle: handle,
      email: email,
      password: testPassword,
    );
  }

  static ApiException _error(int status, String code, String message) =>
      ApiException(statusCode: status, code: code, message: message);

  static ApiException _invalidCode() => _error(
    400,
    'invalid_code',
    'That code is wrong or expired. Check the email or ask for a new code.',
  );

  static ApiException _handleTakenError() =>
      _error(409, 'handle_taken', 'That username is taken. Try another one.');
}

class _FakeAccount {
  _FakeAccount({
    required this.name,
    required this.handle,
    required this.email,
    required this.password,
  });

  final String name;
  final String handle;
  final String email;
  String password;

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
