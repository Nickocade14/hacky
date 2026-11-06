/// The contract's rules for a connection request's intro
/// (`SendRequestBody.intro`: 1 to 500 characters, no links).
abstract final class IntroRules {
  static const maxLength = 500;

  static final _link = RegExp(r'https?://|www\.', caseSensitive: false);

  /// The problem with [value], or null when it can be sent.
  static String? validate(String? value) {
    final intro = value?.trim() ?? '';
    if (intro.isEmpty) return 'Write a short intro first.';
    if (intro.length > maxLength) return 'Keep it under 500 characters.';
    if (_link.hasMatch(intro)) return 'Intros can’t contain links.';
    return null;
  }
}
