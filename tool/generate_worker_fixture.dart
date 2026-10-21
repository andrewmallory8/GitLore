import 'dart:convert';
import 'dart:io';

import 'package:gitlore_core/models/architecture.dart';
import 'package:gitlore_core/services/architecture_codec.dart';
import 'package:gitlore_core/services/repository_analyzer.dart';

/// Run from repo root. Only analyzes the committed fixture, never live code.
void main(List<String> args) {
  const folder = 'backend/worker/test/fixtures';
  final input = jsonDecode(
    File('$folder/repository.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final result = RepositoryAnalyzer.build(
    repository: input['repository'] as String,
    description: input['description'] as String,
    language: input['language'] as String,
    sha: input['sha'] as String,
    branch: input['branch'] as String,
    files: [
      for (final f in input['files'] as List)
        SourceFile(f['path'] as String, f['content'] as String),
    ],
    fileCount: input['fileCount'] as int,
    warnings: (input['warnings'] as List).cast<String>(),
  );
  final encoded = ArchitectureCodec.encode(result);
  ArchitectureCodec.decode(encoded);
  final output = '${const JsonEncoder.withIndent('  ').convert(encoded)}\n';
  final file = File('$folder/static-analysis.json');
  if (args.contains('--check')) {
    if (jsonEncode(jsonDecode(file.readAsStringSync())) !=
        jsonEncode(encoded)) {
      stderr.writeln(
        'Worker parity fixture is stale. Regenerate and review it.',
      );
      exitCode = 1;
    }
  } else {
    file.writeAsStringSync(output);
  }
}
