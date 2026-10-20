import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitlore/models/architecture.dart';
import 'package:gitlore/widgets/architecture_canvas.dart';

const nodes = [
  ArchitectureNode('index.js', 'index.js', 'SOURCE', '', ['index.js']),
  ArchitectureNode('lib/express.js', 'express.js', 'SOURCE', '', [
    'lib/express.js',
  ]),
  ArchitectureNode('README.md', 'README.md', 'DOCS', '', ['README.md']),
];

void main() {
  testWidgets('renders directed imports and keeps node selection', (
    tester,
  ) async {
    String selected = 'index.js';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => ArchitectureCanvas(
              nodes: nodes,
              selected: selected,
              edges: const [
                ArchitectureEdge('index.js', 'lib/express.js'),
                ArchitectureEdge('lib/express.js', 'index.js'),
              ],
              onSelect: (id) => setState(() => selected = id),
            ),
          ),
        ),
      ),
    );
    expect(find.text('imports'), findsNWidgets(2));
    final semantics = tester.ensureSemantics();
    expect(
      find.bySemanticsLabel('index.js imports lib/express.js'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('lib/express.js imports index.js'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'express.js'));
    await tester.pump();
    expect(selected, 'lib/express.js');
    expect(find.widgetWithText(OutlinedButton, 'README.md'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets(
    'ignores unknown, duplicate, and self edges without inventing links',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArchitectureCanvas(
              nodes: nodes,
              selected: 'index.js',
              onSelect: (_) {},
              edges: const [
                ArchitectureEdge('index.js', 'lib/express.js'),
                ArchitectureEdge('index.js', 'lib/express.js'),
                ArchitectureEdge('missing', 'lib/express.js'),
                ArchitectureEdge('index.js', 'missing'),
                ArchitectureEdge('index.js', 'index.js'),
              ],
            ),
          ),
        ),
      );
      expect(find.text('imports'), findsOneWidget);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArchitectureCanvas(
              nodes: nodes,
              selected: 'index.js',
              onSelect: (_) {},
            ),
          ),
        ),
      );
      expect(find.text('imports'), findsNothing);
      expect(
        find.text('No import connections found between these nodes.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final screenWidth in [320.0, 1100.0]) {
    testWidgets('graph fits, zooms, resets and selects at width $screenWidth', (
      tester,
    ) async {
      tester.view.physicalSize = Size(screenWidth, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? selected;
      final manyNodes = List.generate(
        9,
        (i) => ArchitectureNode('$i', 'File $i', 'SOURCE', '', ['$i.js']),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArchitectureCanvas(
              nodes: manyNodes,
              selected: '0',
              onSelect: (id) => selected = id,
              edges: List.generate(8, (i) => ArchitectureEdge('0', '${i + 1}')),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Fit to view'));
      await tester.pumpAndSettle();
      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      final controller = viewer.transformationController!;
      final fitScale = controller.value.getMaxScaleOnAxis();
      expect(fitScale, lessThan(1));
      final viewport = tester.getRect(find.byType(InteractiveViewer));
      for (var i = 0; i < 9; i++) {
        final rect = tester.getRect(
          find.widgetWithText(OutlinedButton, 'File $i'),
        );
        expect(viewport.contains(rect.topLeft), isTrue);
        expect(viewport.contains(rect.bottomRight), isTrue);
      }
      await tester.tap(find.widgetWithText(OutlinedButton, 'File 8'));
      expect(selected, '8');
      await tester.tap(find.byTooltip('Zoom in'));
      await tester.pump();
      expect(controller.value.getMaxScaleOnAxis(), greaterThan(fitScale));
      await tester.tap(find.byTooltip('Zoom out'));
      await tester.pump();
      expect(controller.value.getMaxScaleOnAxis(), closeTo(fitScale, .0001));
      await tester.tap(find.text('Reset'));
      await tester.pump();
      expect(controller.value, Matrix4.identity());
      await tester.drag(
        find.byType(InteractiveViewer),
        const Offset(-80, -100),
      );
      await tester.pumpAndSettle();
      expect(controller.value.storage[13], lessThan(0));
      expect(tester.takeException(), isNull);
    });
  }
}
