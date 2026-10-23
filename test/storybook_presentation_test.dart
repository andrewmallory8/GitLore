import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitlore/models/architecture.dart';
import 'package:gitlore/widgets/architecture_canvas.dart';
import 'package:gitlore/widgets/storybook_presentation.dart';

void main() {
  for (final width in [390.0, 1200.0]) {
    testWidgets('storybook navigation, selection and citation at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Uri? opened;
      const a = Architecture(
        repository: 'team/repo',
        summary: 'Fixture',
        nodes: [
          ArchitectureNode('a', 'Entry', 'SOURCE', 'Entry module', ['a.js']),
          ArchitectureNode('b', 'Service', 'SOURCE', 'Service module', [
            'b.js',
          ]),
        ],
        steps: [
          StoryStep(
            'Start',
            'Read entry',
            'a',
            evidence: [SourceEvidence('a.js', 1, 2)],
          ),
          StoryStep('Continue', 'Read service', 'b'),
        ],
        commitSha: '1234567890123456789012345678901234567890',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: StorybookPresentation(
            architecture: a,
            onOpenSource: (uri) => opened = uri,
          ),
        ),
      );
      await tester.tap(find.text('a.js:1–2'));
      expect(opened!.fragment, 'L1-L2');
      expect(opened!.path, contains(a.commitSha!));
      await tester.ensureVisible(find.text('Next panel'));
      await tester.tap(find.text('Next panel'));
      await tester.pumpAndSettle();
      // ensureVisible aligns navigation at the top; the lazy ListView can
      // dispose the panel counter above it. Return to the header to assert it.
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('Panel 2 of 2'), findsOneWidget);
      expect(
        tester
            .widget<ArchitectureCanvas>(find.byType(ArchitectureCanvas))
            .selected,
        'b',
      );
      await tester.ensureVisible(find.text('Previous panel'));
      await tester.tap(find.text('Previous panel'));
      await tester.pumpAndSettle();
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('Panel 1 of 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
