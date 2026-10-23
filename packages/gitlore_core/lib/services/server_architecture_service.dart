import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/architecture.dart';
import 'architecture_service.dart';
import 'architecture_codec.dart';
import 'github_architecture_service.dart';

class ServerArchitectureService implements ArchitectureService {
  ServerArchitectureService(
    this.baseUrl, {
    this.client,
    this.ai = true,
    this.accessToken = '',
    this.snapshotService,
    this.onProgress,
  });
  final void Function(String)? onProgress;
  final String baseUrl;
  final http.Client? client;
  final bool ai;
  final String accessToken;

  /// Injectable bounded crawler used only when the server's GitHub quota fails.
  final ArchitectureService? snapshotService;
  @override
  Future<Architecture> analyze(String url) async {
    DemoArchitectureService.repositoryFromUrl(url);
    final transport = client ?? http.Client();
    try {
      return await _request(
        transport,
        url,
      ).timeout(const Duration(seconds: 145));
    } on AnalysisException {
      rethrow;
    } on TimeoutException {
      throw const AnalysisException(
        'The analysis server timed out. Retry or use static analysis.',
      );
    } catch (_) {
      throw const AnalysisException(
        'Could not reach or read the analysis server. Start it, or use static analysis.',
      );
    } finally {
      if (client == null) transport.close();
    }
  }

  Future<Architecture> _request(
    http.Client transport,
    String url, {
    Architecture? snapshot,
  }) async {
    final request = http.Request(
      'POST',
      Uri.parse(baseUrl)
          .resolve(snapshot == null ? '/v1/analyze' : '/v1/explain-snapshot'),
    );
    request.headers['content-type'] = 'application/json';
    if (accessToken.isNotEmpty) {
      request.headers['authorization'] = 'Bearer $accessToken';
    }
    request.body = jsonEncode(
      snapshot == null
          ? {'schemaVersion': 1, 'url': url, 'ai': ai}
          : {
              'schemaVersion': 1,
              'url': 'https://github.com/${snapshot.repository}',
              'commitSha': snapshot.commitSha,
              'branch': snapshot.branch,
              'fileCount': snapshot.fileCount,
              'files': [
                for (final file in snapshot.files)
                  {'path': file.path, 'content': file.content},
              ],
            },
    );
    onProgress?.call(
      snapshot == null
          ? 'Waiting for server analysis and AI explanation'
          : 'Sending sampled source for server explanation',
    );
    final response = await transport.send(request);
    final bytes = <int>[];
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 145),
    )) {
      if (bytes.length + chunk.length > ArchitectureCodec.maxBytes) {
        throw const FormatException();
      }
      bytes.addAll(chunk);
    }
    final body = jsonDecode(utf8.decode(bytes));
    if (response.statusCode != 200) {
      if (ai && snapshot == null && body['error']['code'] == 'github_limit') {
        final source =
            await (snapshotService ??
                    GitHubArchitectureService(onProgress: onProgress))
                .analyze(url);
        return _request(transport, url, snapshot: source);
      }
      final message = ArchitectureCodec.text(body['error']['message'], 3000);
      final seconds = int.tryParse(response.headers['retry-after'] ?? '');
      throw AnalysisException(
        message,
        retryAt: seconds == null
            ? null
            : DateTime.now().toUtc().add(Duration(seconds: seconds)),
      );
    }
    onProgress?.call('Validating the server result');
    return ArchitectureCodec.decode(body);
  }
}
