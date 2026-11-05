import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/home/event_dates.dart';

void main() {
  test('shows a weekend event as its first and last day', () {
    expect(
      EventDates.format(DateTime(2026, 11, 14, 9), DateTime(2026, 11, 15, 15)),
      'Sat Nov 14 – Sun Nov 15',
    );
  });

  test('shows a one-day event once', () {
    expect(
      EventDates.format(DateTime(2026, 10, 24, 9), DateTime(2026, 10, 24, 21)),
      'Sat Oct 24',
    );
    expect(EventDates.format(DateTime(2026, 1, 1), null), 'Thu Jan 1');
  });

  test('says when the dates are not set yet', () {
    expect(EventDates.format(null, null), EventDates.unknown);
  });
}
