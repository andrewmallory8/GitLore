import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/architecture.dart';
import 'architecture_service.dart';
import 'repository_analyzer.dart';

class AnalysisException implements Exception {
  const AnalysisException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Public GitHub access only. Never put a private GitHub or LLM key in this app.
class GitHubArchitectureService implements ArchitectureService {
  GitHubArchitectureService({this.client});
  final http.Client? client;
  static const maxFiles = 8;
  static const maxFileBytes = 40000;
  static const maxTotalBytes = 180000;

  @override
  Future<Architecture> analyze(String url) async {
    final repository = DemoArchitectureService.repositoryFromUrl(url);
    final transport = client ?? http.Client();
    try {
      return await _analyze(transport, repository);
    } on TimeoutException {
      throw const AnalysisException(
        'GitHub took too long to respond. Please try again.',
      );
    } on http.ClientException {
      throw const AnalysisException(
        'Could not reach GitHub. Check your connection and try again.',
      );
    } on FormatException {
      throw const AnalysisException(
        'GitHub returned data that could not be read. Please try another repository.',
      );
    } finally {
      if (client == null) transport.close();
    }
  }

  Future<Architecture> _analyze(http.Client client, String repository) async {
    final base = '/repos/$repository';
    final metadata = await _json(client, base);
    final canonical = metadata['full_name'] as String? ?? repository;
    final branch = metadata['default_branch'] as String?;
    if (branch == null) {
      throw const AnalysisException('This repository has no default branch.');
    }
    final commit = await _json(
      client,
      '$base/commits/${Uri.encodeComponent(branch)}',
    );
    final sha = commit['sha'] as String;
    final treeSha = ((commit['commit'] as Map)['tree'] as Map)['sha'] as String;
    final tree = await _json(
      client,
      '$base/git/trees/$treeSha',
      query: {'recursive': '1'},
    );
    final entries = (tree['tree'] as List).cast<Map<String, dynamic>>();
    final blobs = entries
        .where((entry) => entry['type'] == 'blob' && entry['mode'] != '120000')
        .toList();
    final warnings = <String>[
      'Static code tour: roles are inferred from filenames and content. Import links are not proof of runtime data flow. No LLM is used.',
      if (tree['truncated'] == true)
        'GitHub returned a truncated tree; the inventory is incomplete.',
    ];
    final candidates =
        blobs
            .where(
              (entry) =>
                  RepositoryAnalyzer.priority(entry['path'] as String) > 0 &&
                  (entry['size'] as num? ?? maxFileBytes + 1) <= maxFileBytes,
            )
            .toList()
          ..sort((a, b) {
            final order = RepositoryAnalyzer.priority(b['path'] as String)
                .compareTo(RepositoryAnalyzer.priority(a['path'] as String));
            return order == 0
                ? (a['path'] as String).compareTo(b['path'] as String)
                : order;
          });
    final files = <SourceFile>[];
    var totalBytes = 0;
    for (final entry in candidates.take(maxFiles)) {
      final path = entry['path'] as String;
      if (totalBytes + (entry['size'] as num).toInt() > maxTotalBytes) {
        warnings.add('Skipped $path to stay within the content budget.');
        continue;
      }
      try {
        final blob = await _json(
          client,
          '$base/git/blobs/${entry['sha']}',
          maxBytes: 70000,
        );
        if (blob['encoding'] != 'base64') {
          warnings.add('Skipped $path: unsupported file encoding.');
          continue;
        }
        final bytes = base64.decode(
          (blob['content'] as String).replaceAll(RegExp(r'\s'), ''),
        );
        if (bytes.length > maxFileBytes || bytes.contains(0)) {
          warnings.add('Skipped $path: binary or too large.');
          continue;
        }
        totalBytes += bytes.length;
        files.add(SourceFile(path, utf8.decode(bytes)));
      } on AnalysisException catch (error) {
        // Stop on rate limits / permission failures instead of spending more calls.
        if (!error.message.startsWith('Repository or file not found')) rethrow;
        warnings.add('Could not fetch $path.');
      } on FormatException {
        warnings.add('Skipped $path: not valid UTF-8 text.');
      }
    }
    if (files.isEmpty) {
      warnings.add(
        'No supported small text files were available; only repository metadata could be analyzed.',
      );
    }
    warnings.add(
      'Read ${files.length} selected files out of ${blobs.length} tree entries. Files over 40 KB, generated files, and lockfiles are excluded.',
    );
    return RepositoryAnalyzer.build(
      repository: canonical,
      description: metadata['description'] as String?,
      language: metadata['language'] as String?,
      sha: sha,
      branch: branch,
      files: files,
      fileCount: blobs.length,
      warnings: warnings,
    );
  }

  Future<Map<String, dynamic>> _json(
    http.Client client,
    String path, {
    Map<String, String>? query,
    int maxBytes = 8000000,
  }) async {
    final request = http.Request(
      'GET',
      Uri.parse('https://api.github.com$path').replace(queryParameters: query),
    );
    request.headers.addAll({
      'Accept': 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
    });
    final response = await client
        .send(request)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 404) {
      throw const AnalysisException(
        'Repository or file not found. Use an existing public GitHub repository.',
      );
    }
    if (response.statusCode == 409) {
      throw const AnalysisException(
        'This repository is empty. Try one with committed source files.',
      );
    }
    if (response.statusCode == 403 || response.statusCode == 429) {
      throw const AnalysisException(
        'GitHub denied the request or its public API limit was reached. Wait before trying again.',
      );
    }
    if (response.statusCode != 200) {
      throw AnalysisException(
        'GitHub returned HTTP ${response.statusCode}. Please try again later.',
      );
    }
    final bytes = <int>[];
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 20),
    )) {
      if (bytes.length + chunk.length > maxBytes) {
        throw const AnalysisException(
          'GitHub response exceeded the safe size limit. Try a smaller repository.',
        );
      }
      bytes.addAll(chunk);
    }
    return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  }
}
