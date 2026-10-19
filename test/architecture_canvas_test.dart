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

  testWidgets('graph scrolls horizontally and vertically on mobile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
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
    await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'File 8'));
    await tester.tap(find.widgetWithText(OutlinedButton, 'File 8'));
    expect(selected, '8');
    final horizontal = find.byWidgetPredicate(
      (widget) =>
          widget is SingleChildScrollView &&
          widget.scrollDirection == Axis.horizontal,
    );
    await tester.drag(horizontal, const Offset(-250, 0));
    await tester.pumpAndSettle();
    final horizontalScroll = tester.state<ScrollableState>(
      find.descendant(of: horizontal, matching: find.byType(Scrollable)).first,
    );
    expect(horizontalScroll.position.pixels, greaterThan(0));
    expect(tester.takeException(), isNull);
  });
}
