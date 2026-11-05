import 'package:flutter/painting.dart';

/// Bolds the part of a name, handle or skill that matches the search, like
/// the wireframe for 06 ("**Rea**gan", "**Rea**ct").
abstract final class MatchHighlight {
  static const bold = TextStyle(fontWeight: FontWeight.w700);

  /// [text] split into spans, with every case-insensitive match of [query]
  /// in [matchStyle]. Without a match it's one plain span.
  static List<TextSpan> spans(
    String text,
    String query, {
    TextStyle matchStyle = bold,
  }) {
    final ranges = matches(text, query);
    if (ranges.isEmpty) return [TextSpan(text: text)];
    final spans = <TextSpan>[];
    var at = 0;
    for (final (start, end) in ranges) {
      if (start > at) spans.add(TextSpan(text: text.substring(at, start)));
      spans.add(TextSpan(text: text.substring(start, end), style: matchStyle));
      at = end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return spans;
  }

  /// Where [query] appears in [text], ignoring case, as `(start, end)`
  /// pairs that don't overlap.
  static List<(int, int)> matches(String text, String query) {
    final needle = query.trim().toLowerCase();
    final haystack = text.toLowerCase();
    // Some letters change length when lowercased; then indexes wouldn't line
    // up, so skip the highlight rather than bold the wrong letters.
    if (needle.isEmpty || haystack.length != text.length) return const [];
    final ranges = <(int, int)>[];
    var from = 0;
    while (true) {
      final start = haystack.indexOf(needle, from);
      if (start < 0) break;
      ranges.add((start, start + needle.length));
      from = start + needle.length;
    }
    return ranges;
  }
}
