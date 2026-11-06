import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/hacky/hacky_text.dart';

void main() {
  test('plain text is one run', () {
    expect(HackyText.parse('Hi there!'), const [HackyTextRun('Hi there!')]);
  });

  test('finds @handle mentions', () {
    expect(
      HackyText.parse('Try Leo Nguyen (@leo_builds), or @maya_ml.'),
      const [
        HackyTextRun('Try Leo Nguyen ('),
        HackyTextRun('@leo_builds', handle: 'leo_builds'),
        HackyTextRun('), or '),
        HackyTextRun('@maya_ml', handle: 'maya_ml'),
        HackyTextRun('.'),
      ],
    );
  });

  test('emails and too-short handles are not mentions', () {
    expect(
      HackyText.parse('Mail sam@ucf.edu or @ab'),
      const [HackyTextRun('Mail sam@ucf.edu or @ab')],
    );
  });

  test('keeps **bold** runs, with mentions inside them', () {
    expect(HackyText.parse('Ask **@sam_mentor** now'), const [
      HackyTextRun('Ask '),
      HackyTextRun('@sam_mentor', bold: true, handle: 'sam_mentor'),
      HackyTextRun(' now'),
    ]);
    expect(HackyText.parse('**Flutter** help'), const [
      HackyTextRun('Flutter', bold: true),
      HackyTextRun(' help'),
    ]);
  });
}
