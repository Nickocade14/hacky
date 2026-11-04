import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/main.dart';
import 'package:mobile/theme.dart';

void main() {
  testWidgets('shows the placeholder home with the Hacky theme',
      (WidgetTester tester) async {
    await tester.pumpWidget(const HackyApp());

    expect(find.text('hacky.'), findsOneWidget);
    expect(find.text('Great things start with the right people.'),
        findsOneWidget);

    final theme = Theme.of(tester.element(find.byType(PlaceholderHome)));
    expect(theme.colorScheme.primary, AppColors.action);
    expect(theme.scaffoldBackgroundColor, AppColors.paper);
    expect(theme.textTheme.bodyMedium?.fontFamily, AppTheme.fontFamily);
  });
}
