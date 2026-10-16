import 'dart:io';

import 'package:gitlore/services/github_architecture_service.dart';

/// Smoke-test the same public API flow used by the Flutter application.
Future<void> main(List<String> args) async {
  try {
    final result = await GitHubArchitectureService().analyze(
      args.isEmpty ? 'https://github.com/expressjs/express' : args.first,
    );
    stdout.writeln(result.summary);
    stdout.writeln('Technologies: ${result.technologies.join(', ')}');
    for (final file in result.files) {
      stdout.writeln('Read ${file.path} (${file.content.length} characters)');
    }
    for (final edge in result.edges) {
      stdout.writeln('Import: ${edge.from} -> ${edge.to}');
    }
    for (final warning in result.warnings) {
      stdout.writeln('Scope: $warning');
    }
  } catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}
