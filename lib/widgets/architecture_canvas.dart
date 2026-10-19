import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/architecture.dart';

/// File nodes with directed, literal import references. Unconnected nodes remain
/// visible; vertical ordering does not imply a relationship.
class ArchitectureCanvas extends StatelessWidget {
  const ArchitectureCanvas({
    super.key,
    required this.nodes,
    required this.selected,
    required this.onSelect,
    this.edges = const [],
  });
  final List<ArchitectureNode> nodes;
  final List<ArchitectureEdge> edges;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final ids = nodes.map((node) => node.id).toSet();
    final seen = <(String, String)>{};
    final connections = edges
        .where(
          (edge) =>
              ids.contains(edge.from) &&
              ids.contains(edge.to) &&
              edge.from != edge.to &&
              seen.add((edge.from, edge.to)),
        )
        .toList();
    final positions = <String, Rect>{
      for (var index = 0; index < nodes.length; index++)
        nodes[index].id: Rect.fromLTWH(20, 24 + index * 100, 250, 64),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          connections.isEmpty
              ? 'No import connections found between these nodes.'
              : 'Arrows point from importing file to imported file. Scroll to explore.',
          style: const TextStyle(fontSize: 11, color: Color(0xFF748078)),
        ),
        const SizedBox(height: 10),
        Container(
          height: 340,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = math.max(
                constraints.maxWidth,
                connections.isEmpty ? 290.0 : 355.0 + connections.length * 84,
              );
              final height = math.max(340.0, nodes.length * 100.0 + 20);
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: width,
                  child: SingleChildScrollView(
                    child: SizedBox(
                      height: height,
                      child: CustomPaint(
                        painter: ImportConnectionsPainter(
                          connections: connections,
                          positions: positions,
                          selected: selected,
                        ),
                        child: Stack(
                          children: [
                            for (final node in nodes)
                              Positioned.fromRect(
                                rect: positions[node.id]!,
                                child: Semantics(
                                  selected: node.id == selected,
                                  child: Tooltip(
                                    message: node.files.isEmpty
                                        ? node.label
                                        : node.files.join(', '),
                                    child: OutlinedButton.icon(
                                      onPressed: () => onSelect(node.id),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        backgroundColor: node.id == selected
                                            ? const Color(0xFFE5EEDC)
                                            : Colors.white,
                                        foregroundColor: const Color(
                                          0xFF346B50,
                                        ),
                                        side: BorderSide(
                                          color: node.id == selected
                                              ? const Color(0xFF346B50)
                                              : const Color(0xFFD7DFD0),
                                          width: node.id == selected ? 2 : 1,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      icon: const Icon(Icons.code, size: 17),
                                      label: Text(
                                        node.label,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            for (
                              var index = 0;
                              index < connections.length;
                              index++
                            )
                              Positioned(
                                left: 270 + .75 * (60 + index * 84) - 28,
                                top:
                                    (positions[connections[index].from]!
                                                .center
                                                .dy +
                                            positions[connections[index].to]!
                                                .center
                                                .dy) /
                                        2 -
                                    11,
                                child: Semantics(
                                  label:
                                      '${connections[index].from} imports ${connections[index].to}',
                                  child: Tooltip(
                                    message:
                                        '${connections[index].from} → ${connections[index].to}',
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8F9F5),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const ExcludeSemantics(
                                        child: Text(
                                          'imports',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFF346B50),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Each edge uses its own curved lane, avoiding intermediate file cards.
class ImportConnectionsPainter extends CustomPainter {
  const ImportConnectionsPainter({
    required this.connections,
    required this.positions,
    required this.selected,
  });
  final List<ArchitectureEdge> connections;
  final Map<String, Rect> positions;
  final String selected;

  @override
  void paint(Canvas canvas, Size size) {
    final dots = Paint()..color = const Color(0xFFDDE3D7);
    for (double x = 12; x < size.width; x += 18) {
      for (double y = 12; y < size.height; y += 18) {
        canvas.drawCircle(Offset(x, y), .7, dots);
      }
    }
    for (var index = 0; index < connections.length; index++) {
      final edge = connections[index];
      final from = positions[edge.from]!.centerRight;
      final to = positions[edge.to]!.centerRight;
      final lane = from.dx + 60 + index * 84;
      final active = edge.from == selected || edge.to == selected;
      final color = active ? const Color(0xFF346B50) : const Color(0xFF98A98E);
      final paint = Paint()
        ..color = color
        ..strokeWidth = active ? 2.5 : 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawPath(
        Path()
          ..moveTo(from.dx, from.dy)
          ..cubicTo(lane, from.dy, lane, to.dy, to.dx, to.dy),
        paint,
      );
      // The terminal tangent points left into the imported file's right edge.
      canvas.drawPath(
        Path()
          ..moveTo(to.dx, to.dy)
          ..lineTo(to.dx + 9, to.dy - 5)
          ..lineTo(to.dx + 9, to.dy + 5)
          ..close(),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ImportConnectionsPainter oldDelegate) =>
      oldDelegate.selected != selected ||
      oldDelegate.connections != connections ||
      oldDelegate.positions != positions;
}
