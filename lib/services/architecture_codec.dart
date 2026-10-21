import 'dart:convert';

import '../models/architecture.dart';
import 'architecture_service.dart';

/// Versioned contract shared by HTTP and the local bookshelf.
class ArchitectureCodec {
  static const maxBytes = 1500000;
  static Map<String, dynamic> encode(Architecture a) => {
    'schemaVersion': 1,
    'repository': a.repository,
    'summary': a.summary,
    'commitSha': a.commitSha,
    'branch': a.branch,
    'fileCount': a.fileCount,
    'analysisKind': a.analysisKind,
    'analysisVersion': a.analysisVersion,
    'model': a.model,
    'generatedAt': a.generatedAt?.toUtc().toIso8601String(),
    'technologies': a.technologies,
    'warnings': a.warnings,
    'files': [
      for (final f in a.files) {'path': f.path, 'content': f.content},
    ],
    'nodes': [
      for (final n in a.nodes)
        {
          'id': n.id,
          'label': n.label,
          'kind': n.kind,
          'description': n.description,
          'files': n.files,
        },
    ],
    'edges': [
      for (final e in a.edges) {'from': e.from, 'to': e.to, 'kind': 'imports'},
    ],
    'steps': [
      for (final s in a.steps)
        {
          'title': s.title,
          'body': s.body,
          'nodeId': s.nodeId,
          'evidence': [
            for (final e in s.evidence)
              {'path': e.path, 'startLine': e.startLine, 'endLine': e.endLine},
          ],
        },
    ],
  };

  static Architecture decode(Object? raw) {
    try {
      if (utf8.encode(jsonEncode(raw)).length > maxBytes) fail();
      final j = raw as Map<String, dynamic>;
      if (j['schemaVersion'] != 1) fail();
      final repo = text(j['repository'], 250);
      if (DemoArchitectureService.repositoryFromUrl(
            'https://github.com/$repo',
          ) !=
          repo) {
        fail();
      }
      final sha = j['commitSha'] == null ? null : text(j['commitSha'], 64);
      if (sha != null && !RegExp(r'^[a-fA-F0-9]{40}$').hasMatch(sha)) fail();
      final files = [
        for (final f in list(j['files'], 8))
          SourceFile(path(f['path']), text(f['content'], 40000, empty: true)),
      ];
      if (files.map((f) => f.path).toSet().length != files.length ||
          files.fold<int>(0, (n, f) => n + utf8.encode(f.content).length) >
              180000) {
        fail();
      }
      final paths = files.map((f) => f.path).toSet();
      final nodes = [
        for (final n in list(j['nodes'], 100))
          ArchitectureNode(
            text(n['id'], 500),
            text(n['label'], 500),
            text(n['kind'], 100),
            text(n['description'], 12000, empty: true),
            [for (final p in list(n['files'], 8)) path(p)],
          ),
      ];
      final ids = nodes.map((n) => n.id).toSet();
      if (nodes.isEmpty || ids.length != nodes.length) fail();
      if (sha != null && nodes.any((n) => !paths.containsAll(n.files))) fail();
      final edges = [
        for (final e in list(j['edges'], 1000))
          if (e['kind'] == 'imports' &&
              ids.contains(e['from']) &&
              ids.contains(e['to']))
            ArchitectureEdge(e['from'] as String, e['to'] as String)
          else
            throw const FormatException('Invalid edge'),
      ];
      final kind = text(j['analysisKind'], 20);
      if (!['static', 'ai'].contains(kind)) fail();
      final steps = [
        for (final s in list(j['steps'], 100))
          StoryStep(
            text(s['title'], 500),
            text(s['body'], 12000),
            text(s['nodeId'], 500),
            evidence: [
              for (final e in list(s['evidence'], 16))
                SourceEvidence(
                  path(e['path']),
                  integer(e['startLine'], 1, 40000),
                  integer(e['endLine'], 1, 40000),
                ),
            ],
          ),
      ];
      if (steps.isEmpty || steps.any((s) => !ids.contains(s.nodeId))) fail();
      for (final s in steps) {
        if (kind == 'ai' && s.evidence.isEmpty) fail();
        for (final e in s.evidence) {
          final f = files.where((f) => f.path == e.path).firstOrNull;
          if (f == null ||
              e.endLine < e.startLine ||
              e.endLine > f.content.split('\n').length) {
            fail();
          }
          if (!nodes
              .firstWhere((n) => n.id == s.nodeId)
              .files
              .contains(e.path)) {
            fail();
          }
        }
      }
      final model = j['model'] == null ? null : text(j['model'], 100);
      if (kind == 'ai' && (sha == null || model == null)) fail();
      final date = j['generatedAt'] == null
          ? null
          : DateTime.parse(text(j['generatedAt'], 50));
      return Architecture(
        repository: repo,
        summary: text(j['summary'], 12000),
        nodes: nodes,
        edges: edges,
        steps: steps,
        files: files,
        commitSha: sha,
        branch: j['branch'] == null ? null : text(j['branch'], 500),
        warnings: [for (final w in list(j['warnings'], 100)) text(w, 3000)],
        technologies: [
          for (final t in list(j['technologies'], 100)) text(t, 200),
        ],
        fileCount: integer(j['fileCount'], 0, 10000000),
        analysisKind: kind,
        analysisVersion: text(j['analysisVersion'], 100),
        model: model,
        generatedAt: date,
      );
    } catch (_) {
      throw const FormatException(
        'Unsupported or damaged analysis. Analyze this repository again.',
      );
    }
  }

  static Never fail() => throw const FormatException('Invalid analysis');
  static String text(Object? v, int max, {bool empty = false}) {
    if (v is! String || v.length > max || (!empty && v.trim().isEmpty)) fail();
    return v;
  }

  static String path(Object? v) {
    final s = text(v, 500);
    if (s.startsWith('/') ||
        s.contains('\\') ||
        s.split('/').any((p) => p == '..' || p == '.' || p.isEmpty)) {
      fail();
    }
    return s;
  }

  static List<dynamic> list(Object? v, int max) {
    if (v is! List || v.length > max) fail();
    return v;
  }

  static int integer(Object? v, int min, int max) {
    if (v is! int || v < min || v > max) fail();
    return v;
  }
}
