// The little markup Hacky's text keeps: **bold** runs and @handle mentions,
// which open the person's profile (07). Everything else shows as typed, like
// the original Hacky (react/src/hacky/rich.js).

/// One run of a Hacky text bubble.
class HackyTextRun {
  const HackyTextRun(this.text, {this.bold = false, this.handle});

  final String text;
  final bool bold;

  /// Set when the run is an @handle mention (without the "@").
  final String? handle;

  bool get isMention => handle != null;

  @override
  bool operator ==(Object other) =>
      other is HackyTextRun &&
      other.text == text &&
      other.bold == bold &&
      other.handle == handle;

  @override
  int get hashCode => Object.hash(text, bold, handle);

  @override
  String toString() =>
      'HackyTextRun(${[text, if (bold) 'bold', ?handle].join(', ')})';
}

/// Splits Hacky's text into [HackyTextRun]s.
abstract final class HackyText {
  /// `Handle` in docs/openapi.yaml: `^[a-z0-9_]{3,30}$`. The "@" must not
  /// follow a letter, digit, "_" or "." so emails aren't mentions.
  static final _mention = RegExp(
    r'(?<![A-Za-z0-9_.])@([a-z0-9_]{3,30})(?![A-Za-z0-9_])',
  );
  static final _bold = RegExp(r'\*\*(.+?)\*\*');

  static List<HackyTextRun> parse(String text) => [
    for (final (segment, bold) in _boldSegments(text))
      ..._mentions(segment, bold),
  ];

  static Iterable<(String, bool)> _boldSegments(String text) sync* {
    var at = 0;
    for (final match in _bold.allMatches(text)) {
      if (match.start > at) yield (text.substring(at, match.start), false);
      yield (match.group(1)!, true);
      at = match.end;
    }
    if (at < text.length) yield (text.substring(at), false);
  }

  static Iterable<HackyTextRun> _mentions(String text, bool bold) sync* {
    var at = 0;
    for (final match in _mention.allMatches(text)) {
      if (match.start > at) {
        yield HackyTextRun(text.substring(at, match.start), bold: bold);
      }
      yield HackyTextRun(match.group(0)!, bold: bold, handle: match.group(1));
      at = match.end;
    }
    if (at < text.length) yield HackyTextRun(text.substring(at), bold: bold);
  }
}
