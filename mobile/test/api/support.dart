import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api/api_client.dart';
import 'package:mobile/api/token_store.dart';

const testBaseUrl = 'https://api.test';
const testToken = 'test-jwt';

class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([this.token]);

  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String token) async => this.token = token;

  @override
  Future<void> clear() async => token = null;
}

/// An [ApiClient] on a mocked HTTP client that records every request and
/// answers with whatever [respond] or [fail] set last. Logged in by default.
class ApiHarness {
  ApiHarness() {
    client = ApiClient(
      tokenStore: store,
      baseUrl: testBaseUrl,
      httpClient: MockClient((request) async {
        requests.add(request);
        return _response;
      }),
    );
  }

  final store = MemoryTokenStore(testToken);
  final requests = <http.Request>[];
  late final ApiClient client;
  http.Response _response = http.Response('', 204);

  /// The next responses are [body] as JSON with [status].
  void respond(Object body, [int status = 200]) => _response = http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  /// The next responses are a contract error.
  void fail(int status, String code, [String message = 'Nope']) => respond({
    'error': {'code': code, 'message': message},
  }, status);

  http.Request get last => requests.last;

  /// The last request's method and path with query, e.g. `GET /api/search?q=a`.
  String get lastCall =>
      '${last.method} ${last.url.path}'
      '${last.url.hasQuery ? '?${last.url.query}' : ''}';

  Object? get lastBody => last.body.isEmpty ? null : jsonDecode(last.body);

  String? get lastAuth => last.headers['Authorization'];
}
