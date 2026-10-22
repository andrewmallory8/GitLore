import 'dart:math' as math;

import '../models/architecture.dart';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

class GraphInteractionNotification extends Notification {
  GraphInteractionNotification(this.active);
  final bool active;
}

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
  bool _hover = false;
  final Set<int> _pointers = {};
  void _notifyInteraction() =>
      GraphInteractionNotification(_hover || _pointers.isNotEmpty)
          .dispatch(context);
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
    final colors = Theme.of(context).colorScheme;
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
          style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
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
          height: (MediaQuery.sizeOf(context).height * .52).clamp(300.0, 640.0),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = math.max(
                constraints.maxWidth,
                connections.isEmpty ? 290.0 : 355.0 + connections.length * 84,
              );
              final height = math.max(
                constraints.maxHeight,
                nodes.length * 100.0 + 20,
              );
              _viewport = constraints.biggest;
              _scene = Size(width, height);
              return CustomPaint(
                painter: ViewportGridPainter(_transform, colors.outlineVariant),
                child: MouseRegion(
                  onEnter: (_) {
                    _hover = true;
                    _notifyInteraction();
                  },
                  onExit: (_) {
                    _hover = false;
                    _notifyInteraction();
                  },
                  child: Listener(
                    onPointerDown: (e) {
                      _pointers.add(e.pointer);
                      _notifyInteraction();
                    },
                    onPointerUp: (e) {
                      _pointers.remove(e.pointer);
                      _notifyInteraction();
                    },
                    onPointerCancel: (e) {
                      _pointers.remove(e.pointer);
                      _notifyInteraction();
                    },
                    onPointerSignal: (e) {
                      if (e is PointerScrollEvent) {
                        GestureBinding.instance.pointerSignalResolver.register(
                          e,
                          (_) {},
                        );
                      }
                    },
                    child: InteractiveViewer(
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
                                              ? colors.primaryContainer
                                              : colors.surface,
                                          foregroundColor: colors.onSurface,
                                          side: BorderSide(
                                            color: node.id == selected
                                                ? colors.primary
                                                : colors.outlineVariant,
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
                                          color: colors.surfaceContainerLow,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: const ExcludeSemantics(
                                          child: Text(
                                            'imports',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Color(0xFF719EFA),
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
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Paint in viewport coordinates so panning never exposes a grid boundary.
class ViewportGridPainter extends CustomPainter {
  ViewportGridPainter(this.transform, this.color) : super(repaint: transform);
  final TransformationController transform;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final matrix = transform.value;
    final spacing = (18 * matrix.getMaxScaleOnAxis()).clamp(10.0, 54.0);
    final offset = matrix.getTranslation();
    final paint = Paint()..color = color;
    for (double x = offset.x % spacing; x < size.width; x += spacing) {
      for (double y = offset.y % spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), .8, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant ViewportGridPainter oldDelegate) =>
      oldDelegate.transform != transform || oldDelegate.color != color;
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
    for (var index = 0; index < connections.length; index++) {
      final edge = connections[index];
      final from = positions[edge.from]!.centerRight;
      final to = positions[edge.to]!.centerRight;
      final lane = from.dx + 60 + index * 84;
      final active = edge.from == selected || edge.to == selected;
      final color = active ? const Color(0xFF719EFA) : const Color(0xFF8193AF);
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
