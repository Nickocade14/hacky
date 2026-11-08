import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/chats/chat_time.dart';
import 'package:mobile/chats/client_id.dart';

void main() {
  group('ChatTime.ago', () {
    final now = DateTime(2026, 11, 5, 15, 30);

    test('says now under a minute', () {
      expect(ChatTime.ago(now.subtract(const Duration(seconds: 20)), now), 'now');
    });

    test('counts minutes, then hours today', () {
      expect(ChatTime.ago(now.subtract(const Duration(minutes: 2)), now), '2m');
      expect(ChatTime.ago(now.subtract(const Duration(minutes: 59)), now), '59m');
      expect(ChatTime.ago(now.subtract(const Duration(minutes: 75)), now), '1h');
    });

    test('says Yesterday, then the weekday, then the date', () {
      expect(ChatTime.ago(DateTime(2026, 11, 4, 23, 50), now), 'Yesterday');
      expect(ChatTime.ago(DateTime(2026, 11, 2, 9), now), 'Mon');
      expect(ChatTime.ago(DateTime(2026, 10, 3, 9), now), 'Oct 3');
    });
  });

  test('ClientId.next makes distinct UUID v4s', () {
    final uuid = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    final a = ClientId.next();
    final b = ClientId.next();
    expect(a, matches(uuid));
    expect(b, matches(uuid));
    expect(a, isNot(b));
  });
}
