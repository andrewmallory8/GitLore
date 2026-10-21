import 'dart:io';

import '../lib/analysis_server.dart';
import '../lib/gemini_narrator.dart';

Future<void> main() async {
  final env = <String, String>{};
  final file = File('backend/.env');
  if (await file.exists()) {
    for (final line in await file.readAsLines()) {
      if (line.trim().startsWith('#') || !line.contains('=')) continue;
      final index = line.indexOf('=');
      env[line.substring(0, index).trim()] = line.substring(index + 1).trim();
    }
  }
  env.addAll(Platform.environment);
  final model = env['GEMINI_MODEL'] ?? 'gemini-3.8-flash';
  if (!RegExp(r'^gemini-[a-z0-9.-]+$').hasMatch(model)) {
    stderr.writeln('Invalid GEMINI_MODEL.');
    exitCode = 1;
    return;
  }
  final host = env['HOST'] ?? '127.0.0.1';
  final accessToken = env['TEAM_ACCESS_TOKEN'] ?? '';
  if (host != '127.0.0.1' && accessToken.length < 32) {
    stderr.writeln(
      'Public binding requires TEAM_ACCESS_TOKEN of at least 32 characters.',
    );
    exitCode = 1;
    return;
  }
  final api = AnalysisServer(
    accessToken: accessToken,
    allowedHosts: (env['ALLOWED_HOSTS'] ?? 'localhost,127.0.0.1,10.0.2.2')
        .split(',')
        .map((s) => s.trim())
        .toSet(),
    narrator: GeminiNarrator(apiKey: env['GEMINI_API_KEY'] ?? '', model: model),
    origins:
        (env['ALLOWED_ORIGINS'] ??
                'http://127.0.0.1:8086,http://localhost:8086')
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toSet(),
  );
  final server = await HttpServer.bind(
    host,
    int.tryParse(env['PORT'] ?? '') ?? 8087,
  );
  server.idleTimeout = const Duration(seconds: 15);
  stdout.writeln(
    'GitLore backend listening on http://127.0.0.1:${server.port}',
  );
  stdout.writeln(
    'AI configured: ${(env['GEMINI_API_KEY'] ?? '').isNotEmpty}. Keys and provider responses are never logged.',
  );
  await for (final request in server) {
    api.handle(request);
  }
}
