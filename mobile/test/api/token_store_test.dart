import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/token_store.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('SecureTokenStore writes, reads and clears the JWT', () async {
    final store = SecureTokenStore();

    expect(await store.read(), isNull);
    await store.write('my-jwt');
    expect(await store.read(), 'my-jwt');
    expect(await const FlutterSecureStorage().read(key: 'hacky_jwt'), 'my-jwt');
    await store.clear();
    expect(await store.read(), isNull);
  });
}
