import '../api/models/auth.dart';
import '../api/models/events.dart';

/// The words 06 and 07 show for people's roles and status.
abstract final class PersonLabels {
  static String role(MemberRole role) => switch (role) {
    MemberRole.hacker => 'Hacker',
    MemberRole.mentor => 'Mentor',
    MemberRole.sponsor => 'Sponsor',
    MemberRole.organizer => 'Organizer',
  };

  /// The plural for the role filter ("Mentors").
  static String rolePlural(MemberRole role) => '${PersonLabels.role(role)}s';

  static String availability(Availability availability) =>
      switch (availability) {
        Availability.available => 'Available',
        Availability.busy => 'Busy',
        Availability.offline => 'Offline',
      };

  /// "Maya" from "Maya Patel".
  static String firstName(String name) {
    final first = name.trim().split(RegExp(r'\s+')).first;
    return first.isEmpty ? name : first;
  }

  /// "1 person" or "5 people", plus " in Knight Hacks IX" when the event's
  /// name is known.
  static String resultCount(int count, String? eventName) {
    final people = count == 1 ? '1 person' : '$count people';
    return eventName == null ? '$people found' : '$people in $eventName';
  }
}
