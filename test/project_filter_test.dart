import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitlore/widgets/explore_panel.dart';

void main() {
  testWidgets(
    'Explore combines search and technology and clears empty results',
    (tester) async {
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ExplorePanel(
                busy: false,
                onAnalyze: (url) => selected = url,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Dart').first);
      await tester.pumpAndSettle();
      expect(find.text('1 of 3 projects'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'express');
      await tester.pumpAndSettle();
      expect(find.text('0 of 3 projects'), findsOneWidget);
      expect(find.textContaining('No matching projects'), findsOneWidget);
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(find.text('3 of 3 projects'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'is-number');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Analyze this repository'));
      await tester.tap(find.text('Analyze this repository'));
      expect(selected, 'https://github.com/jonschlinkert/is-number');
    },
  );
}
