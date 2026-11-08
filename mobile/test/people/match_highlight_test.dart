import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/people/match_highlight.dart';
import 'package:mobile/people/person_labels.dart';

/// The bold parts of [spans].
List<String> boldParts(List<TextSpan> spans) => [
  for (final span in spans)
    if (span.style == MatchHighlight.bold) span.text!,
];

void main() {
  test('bolds the matching part, ignoring case', () {
    final spans = MatchHighlight.spans('Andrea Lopez', 'REA');

    expect(spans.map((s) => s.text).join(), 'Andrea Lopez');
    expect(boldParts(spans), ['rea']);
  });

  test('bolds every match, at the start and the end', () {
    expect(boldParts(MatchHighlight.spans('React and Rea', 'rea')), [
      'Rea',
      'Rea',
    ]);
  });

  test('without a match or query it is one plain span', () {
    expect(MatchHighlight.spans('Leo Nguyen', 'xyz').single.style, isNull);
    expect(MatchHighlight.spans('Leo Nguyen', '  ').single.text, 'Leo Nguyen');
  });

  test('labels roles, counts and first names', () {
    expect(PersonLabels.resultCount(5, 'Knight Hacks IX'),
        '5 people in Knight Hacks IX');
    expect(PersonLabels.resultCount(1, null), '1 person found');
    expect(PersonLabels.firstName('  Maya Patel '), 'Maya');
  });
}
