import 'package:flutter/material.dart';

import '../models/architecture.dart';
import 'architecture_canvas.dart';

/// A focused, sequential presentation of the existing evidence-backed chapters.
class StorybookPresentation extends StatefulWidget {
  const StorybookPresentation({
    super.key,
    required this.architecture,
    required this.onOpenSource,
  });
  final Architecture architecture;
  final void Function(Uri) onOpenSource;
  @override
  State<StorybookPresentation> createState() => _StorybookPresentationState();
}

class _StorybookPresentationState extends State<StorybookPresentation> {
  int index = 0;
  @override
  Widget build(BuildContext context) {
    final a = widget.architecture;
    final step = a.steps[index];
    final node = a.nodes.firstWhere((n) => n.id == step.nodeId);
    return Scaffold(
      appBar: AppBar(title: const Text('Storybook presentation')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(a.repository, style: Theme.of(context).textTheme.titleLarge),
            Text(
              a.analysisKind == 'ai'
                  ? 'AI interpretation · verify the cited source'
                  : a.isLive
                  ? 'Static code tour · inferred file roles'
                  : 'Demo story · not an analysis of this repository',
            ),
            const Text(
              'Map arrows show imports, not verified runtime data flow.',
            ),
            const SizedBox(height: 20),
            LinearProgressIndicator(value: (index + 1) / a.steps.length),
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Text(
                'Panel ${index + 1} of ${a.steps.length}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      step.body,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    Chip(
                      avatar: const Icon(Icons.account_tree_outlined),
                      label: Text(node.label),
                    ),
                    Text(node.description),
                    for (final e in step.evidence)
                      TextButton(
                        onPressed: () => widget.onOpenSource(
                          a
                              .sourceUrl(e.path)
                              .replace(
                                fragment: 'L${e.startLine}-L${e.endLine}',
                              ),
                        ),
                        child: Text('${e.path}:${e.startLine}–${e.endLine}'),
                      ),
                    if (step.evidence.isEmpty && a.isLive)
                      for (final path in node.files)
                        TextButton(
                          onPressed: () =>
                              widget.onOpenSource(a.sourceUrl(path)),
                          child: Text('Source: $path'),
                        ),
                  ],
                ),
              ),
            ),
            Wrap(
              spacing: 12,
              children: [
                OutlinedButton(
                  onPressed: index == 0 ? null : () => setState(() => index--),
                  child: const Text('Previous panel'),
                ),
                FilledButton(
                  onPressed: () =>
                      setState(() => index = (index + 1) % a.steps.length),
                  child: Text(
                    index == a.steps.length - 1 ? 'Start again' : 'Next panel',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Highlighted component: ${node.label}'),
            const SizedBox(height: 8),
            ArchitectureCanvas(
              nodes: a.nodes,
              edges: a.edges,
              selected: step.nodeId,
              onSelect: (id) {
                final next = a.steps.indexWhere((s) => s.nodeId == id);
                if (next >= 0) setState(() => index = next);
              },
            ),
          ],
        ),
      ),
    );
  }
}
