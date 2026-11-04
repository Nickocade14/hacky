import 'package:flutter/material.dart';

import 'api/api_client.dart';
import 'api/token_store.dart';
import 'app.dart';
import 'dev/fake_api_client.dart';

/// `flutter run --dart-define=FAKE_API=true` uses the in-memory fake client
/// (see lib/dev/fake_api_client.dart for its test accounts). The default is
/// the real server.
const useFakeApi = bool.fromEnvironment('FAKE_API');

void main() {
  final tokenStore = SecureTokenStore();
  final api = useFakeApi
      ? FakeApiClient(tokenStore: tokenStore)
      : ApiClient(tokenStore: tokenStore);
  runApp(HackyApp(api: api));
}
