/// An event's dates as one short line, e.g. "Sat Nov 14 – Sun Nov 15", in
/// the phone's time zone. No intl package: English names, like the web.
abstract final class EventDates {
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// Shown when the event has no start date yet.
  static const unknown = 'Dates coming soon';

  static String format(DateTime? startsAt, DateTime? endsAt) {
    if (startsAt == null) return unknown;
    final start = startsAt.toLocal();
    final end = endsAt?.toLocal();
    if (end == null || _sameDay(start, end)) return day(start);
    return '${day(start)} – ${day(end)}';
  }

  /// "Sat Nov 14".
  static String day(DateTime date) =>
      '${_days[date.weekday - 1]} ${_months[date.month - 1]} ${date.day}';

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
