import 'dart:convert';

import 'package:path/path.dart' as p;

import '../models/architecture.dart';
import 'import_resolver.dart';

/// Conservative, deterministic extraction. Repository code is never executed.
class RepositoryAnalyzer {
  static const _manifests = {
    'package.json',
    'pubspec.yaml',
    'requirements.txt',
    'pyproject.toml',
    'Cargo.toml',
    'go.mod',
    'pom.xml',
    'Gemfile',
    'composer.json',
  };
  static bool _source(String path) =>
      RegExp(r'\.(dart|tsx?|jsx?|mjs|cjs|py|go|rs|java|rb|php|vue|svelte)$')
          .hasMatch(path);

  static int priority(String path) {
    final lower = path.toLowerCase();
    if (path
        .split('/')
        .any(
          (part) => {
            'node_modules',
            'vendor',
            'dist',
            'build',
            '.git',
            '.next',
            '.dart_tool',
            'coverage',
            'test',
            'tests',
            '__tests__',
            'fixtures',
            'examples',
            'docs',
          }.contains(part),
        )) {
      return 0;
    }
    if (lower.contains('.min.') ||
        lower.contains('.generated.') ||
        lower.endsWith('.g.dart') ||
        lower.contains('.test.') ||
        lower.contains('.spec.')) {
      return 0;
    }
    final name = p.posix.basename(path);
    final depth = path.split('/').length;
    if (depth == 1 && lower.startsWith('readme')) return 100;
    if (_manifests.contains(name)) return depth == 1 ? 95 : 75 - depth;
    if (!_source(path)) return 0;
    if (RegExp(r'^(main|index|app|server|manage|__init__)\.').hasMatch(name)) {
      return 90 - depth;
    }
    if (RegExp(
      r'(^|/)(routes?|controllers?|services?|models?|pages|api|components)(/|\.)',
    ).hasMatch(lower)) {
      return 65 - depth;
    }
    return 40 - depth;
  }

  static Architecture build({
    required String repository,
    String? description,
    String? language,
    required String sha,
    required String branch,
    required List<SourceFile> files,
    required int fileCount,
    required List<String> warnings,
  }) {
    final technologies = <String>{?language};
    for (final file in files) {
      if (p.posix.basename(file.path) == 'package.json') {
        try {
          final json = jsonDecode(file.content);
          if (json is! Map) continue;
          final deps = {
            if (json['dependencies'] is Map) ...json['dependencies'] as Map,
            if (json['devDependencies'] is Map)
              ...json['devDependencies'] as Map,
          };
          for (final dep in [
            'next',
            'react',
            'vue',
            'express',
            'fastify',
            '@nestjs/core',
            'mongoose',
            'pg',
            'prisma',
            'typescript',
          ]) {
            if (deps.containsKey(dep)) technologies.add(dep);
          }
        } on FormatException {
          /* The raw manifest remains available as evidence. */
        }
      }
      if (p.posix.basename(file.path) == 'pubspec.yaml' &&
          RegExp(r'^\s+flutter\s*:', multiLine: true).hasMatch(file.content)) {
        technologies.add('Flutter');
      }
      if ([
        'requirements.txt',
        'pyproject.toml',
      ].contains(p.posix.basename(file.path))) {
        for (final dep in ['django', 'flask', 'fastapi', 'sqlalchemy']) {
          if (RegExp(
            '(^|[\\s"\'])$dep([\\s=<>~\\["\']|\$)',
            caseSensitive: false,
            multiLine: true,
          ).hasMatch(file.content)) {
            technologies.add(dep);
          }
        }
      }
    }
    final nodes = <ArchitectureNode>[
      ArchitectureNode(
        'overview',
        'Repository overview',
        'GITHUB METADATA',
        description?.trim().isNotEmpty == true
            ? description!
            : 'No repository description was provided on GitHub.',
        const [],
      ),
    ];
    for (final file in files) {
      final name = p.posix.basename(file.path);
      final isReadme = name.toLowerCase().startsWith('readme');
      final manifest = _manifests.contains(name);
      final role = isReadme
          ? 'DOCUMENTATION'
          : manifest
          ? 'DEPENDENCY MANIFEST'
          : 'SOURCE · INFERRED ROLE';
      String explanation;
      if (isReadme) {
        explanation = 'The project’s own documentation. Read the source excerpt for setup, usage, and the author’s description.';
      } else if (manifest) {
        explanation = 'Declares project configuration and dependencies. A dependency declaration does not prove that it is used at runtime.';
      } else if (RegExp(r'(^|/)(routes?|controllers?|api)(/|\.)')
          .hasMatch(file.path)) {
        explanation = 'Its path suggests a request-handling component. Confirm the handlers and calls in the source; a complete request flow has not been traced.';
      } else if (RegExp(r'(^|/)(models?|db|database)(/|\.)')
          .hasMatch(file.path)) {
        explanation = 'Its path suggests data definitions or persistence code. This alone does not establish a database connection.';
      } else if (RegExp(r'^(main|index|app|server|manage)\.').hasMatch(name)) {
        explanation = 'Its filename suggests an entry point or module export. Inspect its imports and initialization code to confirm its responsibility.';
      } else {
        explanation = 'A source file selected from the repository. Inspect its implementation and observed imports to understand its responsibility.';
      }
      nodes.add(
        ArchitectureNode(file.path, name, role, explanation, [file.path]),
      );
    }
    final edges = ImportResolver.resolve(files);
    return Architecture(
      repository: repository,
      summary:
          '${description?.trim().isNotEmpty == true ? description : 'Public repository $repository.'} Analyzed ${files.length} selected files at commit ${sha.substring(0, 7)}. This is an evidence-backed code tour, not a verified execution trace.',
      nodes: nodes,
      steps: nodes
          .map((node) => StoryStep(node.label, node.description, node.id))
          .toList(),
      commitSha: sha,
      branch: branch,
      files: files,
      edges: edges,
      warnings: warnings,
      technologies: technologies.toList(),
      fileCount: fileCount,
    );
  }
}
