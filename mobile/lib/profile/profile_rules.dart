// Field checks for 08 My profile. The limits are the contract's
// (docs/openapi.yaml: UpdateProfileBody, ProfileLinks, IntakeFields, Tag, Tags).

/// The limits and messages for each field of the profile form. Each check
/// returns the problem, or null when the value is fine.
abstract final class ProfileRules {
  static const nameMax = 80;
  static const bioMax = 500;
  static const linkMax = 300;
  static const tagMax = 40;
  static const tagsMax = 30;
  static const trackMax = 80;
  static const ideaMax = 2000;

  static const linkHint = 'Starts with https://. We add it if you leave it out.';

  static String? name(String value) {
    final name = value.trim();
    if (name.isEmpty) {
      return 'Enter your name so your teammates know what to call you.';
    }
    if (name.length > nameMax) return 'Use at most $nameMax characters.';
    return null;
  }

  static String? bio(String value) => value.trim().length > bioMax
      ? 'Keep your bio to $bioMax characters.'
      : null;

  /// The link as it's sent: trimmed, with `https://` added when it has no
  /// scheme ("github.com/you"). Empty stays empty (no link).
  static String normalizeLink(String value) {
    final link = value.trim();
    if (link.isEmpty || link.contains('://')) return link;
    return 'https://$link';
  }

  static String? link(String value) {
    final link = normalizeLink(value);
    if (link.isEmpty) return null;
    if (!link.startsWith('https://')) return 'Use an https:// link.';
    if (link.length > linkMax) return 'Use at most $linkMax characters.';
    final uri = Uri.tryParse(link);
    if (uri == null || !uri.host.contains('.') || link.contains(' ')) {
      return 'Enter a full link, like https://github.com/you.';
    }
    return null;
  }

  /// Whether [value] can be added to [tags]: 1 to 40 characters, not already
  /// there (ignoring case), and at most 30 in the list.
  static String? newTag(String value, List<String> tags) {
    final tag = value.trim();
    if (tag.isEmpty) return 'Type something to add.';
    if (tag.length > tagMax) return 'Keep each one to $tagMax characters.';
    if (tags.any((t) => t.toLowerCase() == tag.toLowerCase())) {
      return 'That’s already on the list.';
    }
    if (tags.length >= tagsMax) return 'You can add up to $tagsMax.';
    return null;
  }

  /// A whole list, as saved: the server's data can't break these, but a
  /// list built some other way could.
  static String? tags(List<String> tags) {
    if (tags.length > tagsMax) return 'Add up to $tagsMax.';
    if (tags.any((t) => t.trim().isEmpty || t.length > tagMax)) {
      return 'Keep each one to 1–$tagMax characters.';
    }
    return null;
  }

  static String? track(String? value) => (value?.length ?? 0) > trackMax
      ? 'Use at most $trackMax characters.'
      : null;

  static String? idea(String value) => value.trim().length > ideaMax
      ? 'Keep your idea to 2,000 characters.'
      : null;
}
