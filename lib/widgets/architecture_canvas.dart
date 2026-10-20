import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/architecture.dart';

/// File nodes with directed, literal import references. Unconnected nodes remain
/// visible; vertical ordering does not imply a relationship.
class ArchitectureCanvas extends StatefulWidget {
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
  State<ArchitectureCanvas> createState() => _ArchitectureCanvasState();
}

class _ArchitectureCanvasState extends State<ArchitectureCanvas> {
  final _transform = TransformationController();
  Size _viewport = Size.zero;
  Size _scene = Size.zero;
  List<ArchitectureNode> get nodes => widget.nodes;
  List<ArchitectureEdge> get edges => widget.edges;
  String get selected => widget.selected;
  ValueChanged<String> get onSelect => widget.onSelect;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ArchitectureCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nodes != widget.nodes || oldWidget.edges != widget.edges) {
      _transform.value = Matrix4.identity();
    }
  }

  double get _fitScale => math.min(
    1.0,
    math.min(_viewport.width / _scene.width, _viewport.height / _scene.height),
  );

  void _fit() {
    final scale = _fitScale;
    _transform.value = Matrix4.identity()
      ..translateByDouble(
        (_viewport.width - _scene.width * scale) / 2,
        (_viewport.height - _scene.height * scale) / 2,
        0,
        1,
      )
      ..scaleByDouble(scale, scale, scale, 1);
  }

  void _zoom(double factor) {
    final current = _transform.value.getMaxScaleOnAxis();
    final next = (current * factor)
        .clamp(math.min(.05, _fitScale), 4.0)
        .toDouble();
    final center = _viewport.center(Offset.zero);
    final point = _transform.toScene(center);
    _transform.value = Matrix4.identity()
      ..translateByDouble(
        center.dx - point.dx * next,
        center.dy - point.dy * next,
        0,
        1,
      )
      ..scaleByDouble(next, next, next, 1);
  }

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
              : 'Arrows point from importing file to imported file. Drag to pan. Pinch to zoom.',
          style: const TextStyle(fontSize: 11, color: Color(0xFF748078)),
        ),
        Wrap(
          children: [
            IconButton(
              tooltip: 'Zoom in',
              onPressed: () => _zoom(1.25),
              icon: const Icon(Icons.zoom_in),
            ),
            IconButton(
              tooltip: 'Zoom out',
              onPressed: () => _zoom(.8),
              icon: const Icon(Icons.zoom_out),
            ),
            TextButton.icon(
              onPressed: _fit,
              icon: const Icon(Icons.fit_screen),
              label: const Text('Fit to view'),
            ),
            TextButton(
              onPressed: () => _transform.value = Matrix4.identity(),
              child: const Text('Reset'),
            ),
          ],
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
              _viewport = Size(constraints.maxWidth, 340);
              _scene = Size(width, height);
              return InteractiveViewer(
                key: const ValueKey('architecture-viewport'),
                transformationController: _transform,
                constrained: false,
                minScale: math.min(.05, _fitScale),
                maxScale: 4,
                boundaryMargin: const EdgeInsets.all(340),
                child: SizedBox(
                  width: width,
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
                                    foregroundColor: const Color(0xFF346B50),
                                    side: BorderSide(
                                      color: node.id == selected
                                          ? const Color(0xFF346B50)
                                          : const Color(0xFFD7DFD0),
                                      width: node.id == selected ? 2 : 1,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
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
                        for (var index = 0; index < connections.length; index++)
                          Positioned(
                            left: 270 + .75 * (60 + index * 84) - 28,
                            top:
                                (positions[connections[index].from]!.center.dy +
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
