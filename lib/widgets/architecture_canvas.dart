import 'package:flutter/material.dart';

import '../models/architecture.dart';

/// A native Flutter canvas keeps the starter usable on web and desktop.
/// Replace with a graph layout or Mermaid web renderer for arbitrary edges.
class ArchitectureCanvas extends StatelessWidget {
  const ArchitectureCanvas({
    super.key,
    required this.nodes,
    required this.selected,
    required this.onSelect,
    this.showDemoFlow = false,
  });
  final bool showDemoFlow;
  final List<ArchitectureNode> nodes;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => Container(
    height: 278,
    width: double.infinity,
    decoration: BoxDecoration(
      color: const Color(0xFFF8F9F5),
      borderRadius: BorderRadius.circular(12),
    ),
    child: CustomPaint(
      painter: _DotGrid(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            for (var index = 0; index < nodes.length; index++) ...[
              if (index > 0)
                showDemoFlow
                    ? const Icon(
                        Icons.south,
                        color: Color(0xFFABB7A6),
                        size: 22,
                      )
                    : const SizedBox(height: 12),
              Semantics(
                selected: nodes[index].id == selected,
                child: OutlinedButton.icon(
                  onPressed: () => onSelect(nodes[index].id),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: nodes[index].id == selected
                        ? const Color(0xFFE5EEDC)
                        : Colors.white,
                    foregroundColor: const Color(0xFF346B50),
                    minimumSize: const Size(210, 42),
                    side: BorderSide(
                      color: nodes[index].id == selected
                          ? const Color(0xFF346B50)
                          : const Color(0xFFD7DFD0),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: Icon(Icons.code, size: 17),
                  label: Text(nodes[index].label),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _DotGrid extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFDDE3D7);
    for (double x = 12; x < size.width; x += 18) {
      for (double y = 12; y < size.height; y += 18) {
        canvas.drawCircle(Offset(x, y), .7, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
