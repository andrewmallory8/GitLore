import '../models/architecture.dart';

/// Exports only the loaded snapshot; never requests additional analysis.
class ArchitectureExport {
  static String _text(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAllMapped(RegExp(r'[\\`*_{}\[\]()#!|]'), (m) => '\\${m[0]}');

  static String mermaid(Architecture a) {
    final out = StringBuffer('flowchart TD\n');
    out.writeln('%% Repository: ${Uri.encodeComponent(a.repository)}');
    out.writeln('%% Commit: ${Uri.encodeComponent(a.commitSha ?? 'demo')}');
    out.writeln('%% Sampled import relationships only, not runtime data flow.');
    final ids = <String, String>{};
    for (var i = 0; i < a.nodes.length; i++) {
      final node = a.nodes[i];
      ids[node.id] = 'n$i';
      // Numeric entities prevent repository text from becoming Mermaid syntax.
      final label = node.label.runes.map((r) => '#$r;').join();
      out.writeln('  n$i["$label"]');
      if (a.isLive) {
        for (final path in node.files) {
          out.writeln('%% Source n$i: ${a.sourceUrl(path)}');
        }
      }
    }
    for (final edge in a.edges) {
      if (ids.containsKey(edge.from) && ids.containsKey(edge.to)) {
        out.writeln('  ${ids[edge.from]} -->|imports| ${ids[edge.to]}');
      }
    }
    for (final warning in a.warnings) {
      out.writeln('%% Limitation: ${Uri.encodeComponent(warning)}');
    }
    return out.toString();
  }

  static String markdown(Architecture a) {
    final out = StringBuffer('# ${_text(a.repository)}\n\n');
    out.writeln(
      'Repository: https://github.com/${Uri.encodeFull(a.repository)}\n',
    );
    out.writeln(
      'Commit: ${_text(a.commitSha ?? 'Demo fixture — not a live repository snapshot')}\n',
    );
    out.writeln('Branch: ${_text(a.branch ?? 'Not recorded')}\n');
    out.writeln(
      'Analysis: ${a.isLive ? _text(a.analysisKind) : 'demo'}; version ${_text(a.analysisVersion)}\n',
    );
    if (a.model != null) out.writeln('AI model: ${_text(a.model!)}\n');
    if (a.generatedAt != null) {
      out.writeln('Generated: ${a.generatedAt!.toUtc().toIso8601String()}\n');
    }
    out.writeln(
      'Coverage: ${a.files.length} sampled files / ${a.fileCount} tree entries\n',
    );
    out.writeln('${_text(a.summary)}\n');
    out.writeln('## Architecture map\n\n```mermaid\n${mermaid(a)}```\n');
    out.writeln('## Walkthrough\n');
    for (var i = 0; i < a.steps.length; i++) {
      final step = a.steps[i];
      out.writeln(
        '### ${i + 1}. ${_text(step.title)}\n\n${_text(step.body)}\n',
      );
      if (a.isLive) {
        if (step.evidence.isNotEmpty) {
          for (final e in step.evidence) {
            final url = a
                .sourceUrl(e.path)
                .replace(fragment: 'L${e.startLine}-L${e.endLine}');
            out.writeln(
              '- [${_text(e.path)}:${e.startLine}–${e.endLine}]($url)',
            );
          }
        } else {
          out.writeln('Related source files (not claim-level citations):');
          for (final node in a.nodes.where((n) => n.id == step.nodeId)) {
            for (final path in node.files) {
              out.writeln('- [${_text(path)}](${a.sourceUrl(path)})');
            }
          }
        }
      }
      out.writeln();
    }
    out.writeln('## Limitations\n');
    out.writeln(
      '- Sampled import relationships are not verified runtime data flow.',
    );
    out.writeln(
      '- AI interpretations may be incorrect; citations identify source excerpts, not proof of every claim.',
    );
    if (!a.isLive) {
      out.writeln(
        '- Demonstration content; no verified commit or source citations.',
      );
    }
    for (final warning in a.warnings) {
      out.writeln('- ${_text(warning)}');
    }
    return out.toString();
  }
}
