import 'dart:io';

import 'package:gitlore/services/architecture_service.dart';
import 'package:gitlore/services/github_architecture_service.dart';
import 'package:gitlore/services/server_architecture_service.dart';

/// Smoke-test the same public API flow used by the Flutter application.
Future<void> main(List<String> args) async {
  try {
    // These are runtime CLI settings, never Flutter build defines for secrets.
    final server = Platform.environment['GITLORE_API_URL'];
    final ArchitectureService service = server == null || server.isEmpty
        ? GitHubArchitectureService()
        : ServerArchitectureService(
            server,
            accessToken:
                Platform.environment['GITLORE_TEAM_ACCESS_TOKEN'] ?? '',
            ai: Platform.environment['GITLORE_AI'] == 'true',
          );
    final result = await service.analyze(
      args.isEmpty ? 'https://github.com/expressjs/express' : args.first,
    );
    stdout.writeln(result.summary);
    stdout.writeln('Analysis kind: ${result.analysisKind}');
    stdout.writeln('Model: ${result.model ?? "none"}');
    stdout.writeln('Commit: ${result.commitSha ?? "none"}');
    stdout.writeln(
      'Generated: ${result.generatedAt?.toIso8601String() ?? "none"}',
    );
    stdout.writeln('Chapters: ${result.steps.length}');
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
    if (Platform.environment['GITLORE_REQUIRE_AI'] == 'true' &&
        result.analysisKind != 'ai') {
      stderr.writeln(
        'AI acceptance failed: the server returned static fallback.',
      );
      exitCode = 1;
    }
  } catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}
