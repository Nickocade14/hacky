/// When a chat last moved, as the short label on the right of a 10
/// Conversations row: "now", "2m", "1h", "Yesterday", "Mon", "Oct 3".
/// In the phone's time zone. No intl package: English names, like the web.
abstract final class ChatTime {
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String ago(DateTime at, DateTime now) {
    final then = at.toLocal();
    final today = now.toLocal();
    final elapsed = today.difference(then);
    if (elapsed.inMinutes < 1) return 'now';
    if (elapsed.inHours < 1) return '${elapsed.inMinutes}m';
    final days = _daysBetween(then, today);
    if (days == 0) return '${elapsed.inHours}h';
    if (days == 1) return 'Yesterday';
    if (days < 7) return _days[then.weekday - 1];
    return '${_months[then.month - 1]} ${then.day}';
  }

  /// Calendar days from [a] to [b]. Rounded, so a daylight saving change
  /// (a 23 or 25 hour day) still counts as one day.
  static int _daysBetween(DateTime a, DateTime b) {
    final from = DateTime(a.year, a.month, a.day);
    final to = DateTime(b.year, b.month, b.day);
    return (to.difference(from).inHours / 24).round();
  }
}
