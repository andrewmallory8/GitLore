import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:gitlore_core/models/architecture.dart';
import 'package:gitlore_core/services/architecture_service.dart';
import 'package:gitlore_core/services/architecture_codec.dart';
import 'package:gitlore_core/services/github_architecture_service.dart';

import 'gemini_narrator.dart';

class AnalysisServer {
  AnalysisServer({
    required this.narrator,
    required this.origins,
    this.analyze,
    this.accessToken = '',
    this.allowedHosts = const {'localhost', '127.0.0.1', '10.0.2.2'},
  });
  final GeminiNarrator narrator;
  final String accessToken;
  final Set<String> allowedHosts;
  final Set<String> origins;
  final Future<Architecture> Function(String)? analyze;
  int _active = 0;
  final _recent = <DateTime>[];

  Future<void> handle(HttpRequest request) async {
    void respond(int status, Object data) {
      request.response.statusCode = status;
      request.response.headers.contentType = ContentType.json;
      request.response.headers.set('Cache-Control', 'no-store');
      request.response.write(jsonEncode(data));
    }

    void error(int status, String code, String message) => respond(status, {
      'schemaVersion': 1,
      'error': {'code': code, 'message': message},
    });
    try {
      // Local development server: disallow DNS rebinding and unsolicited web origins.
      final host = request.headers.host?.split(':').first;
      if (!allowedHosts.contains(host)) {
        error(403, 'forbidden_host', 'This is a local development server.');
        return;
      }
      final origin = request.headers.value('origin');
      if (origin != null && !origins.contains(origin)) {
        error(403, 'forbidden_origin', 'This browser origin is not allowed.');
        return;
      }
      if (origin != null) {
        request.response.headers.set('Access-Control-Allow-Origin', origin);
        request.response.headers.set('Vary', 'Origin');
        request.response.headers.set(
          'Access-Control-Allow-Methods',
          'POST, GET, OPTIONS',
        );
        request.response.headers.set(
          'Access-Control-Allow-Headers',
          'Content-Type, Authorization',
        );
      }
      if (request.method == 'OPTIONS') {
        request.response.statusCode = 204;
        return;
      }
      if (request.method == 'GET' && request.uri.path == '/health') {
        respond(200, {
          'status': 'ok',
          'aiConfigured': narrator.apiKey.trim().isNotEmpty,
        });
        return;
      }
      if (accessToken.isNotEmpty &&
          request.headers.value('authorization') != 'Bearer $accessToken') {
        error(
          401,
          'unauthorized',
          'Enter the team access code in Server settings.',
        );
        return;
      }
      if (request.method != 'POST' || request.uri.path != '/v1/analyze') {
        error(404, 'not_found', 'Use POST /v1/analyze.');
        return;
      }
      if (request.headers.contentType?.mimeType != 'application/json') {
        error(415, 'content_type', 'Send application/json.');
        return;
      }
      final now = DateTime.now();
      _recent.removeWhere(
        (d) => now.difference(d) > const Duration(minutes: 1),
      );
      if (_active >= 2 || _recent.length >= 10) {
        request.response.headers.set('Retry-After', '60');
        error(429, 'busy', 'Analysis limit reached. Try again in a minute.');
        return;
      }
      _active++;
      _recent.add(now);
      try {
        final raw = await _body(request).timeout(const Duration(seconds: 10));
        final data = jsonDecode(raw);
        if (data is! Map ||
            data['schemaVersion'] != 1 ||
            data.keys.any((k) => !['schemaVersion', 'url', 'ai'].contains(k)) ||
            data['url'] is! String ||
            (data.containsKey('ai') && data['ai'] is! bool)) {
          throw const FormatException(
            'Send schemaVersion: 1, url, and optional boolean ai.',
          );
        }
        final repo = DemoArchitectureService.repositoryFromUrl(
          data['url'] as String,
        );
        final result = await _crawl('https://github.com/$repo');
        final output = data['ai'] == true
            ? await narrator.enhance(result)
            : result;
        final json = ArchitectureCodec.encode(output);
        ArchitectureCodec.decode(json);
        respond(200, json);
      } on FormatException catch (e) {
        error(
          400,
          'invalid_request',
          e.message.isEmpty ? 'Invalid request.' : e.message,
        );
      } on TimeoutException {
        request.response.persistentConnection = false;
        error(504, 'timeout', 'Analysis took too long. Try again.');
      } on AnalysisException catch (e) {
        error(502, 'github_error', e.message);
      } finally {
        _active--;
      }
    } catch (_) {
      error(
        500,
        'internal_error',
        'Analysis could not be completed. Try again.',
      );
    } finally {
      await request.response.close();
    }
  }

  Future<Architecture> _crawl(String url) async {
    if (analyze != null) {
      return analyze!(url).timeout(const Duration(seconds: 90));
    }
    final client = http.Client();
    try {
      return await GitHubArchitectureService(client: client)
          .analyze(url)
          .timeout(const Duration(seconds: 90));
    } finally {
      client.close();
    }
  }

  Future<String> _body(HttpRequest request) async {
    final bytes = <int>[];
    final result = Completer<String>();
    // Cancelling HttpRequest while reading can tear down the socket before the
    // JSON error is sent. Close it only after the response has been flushed.
    final subscription = request.listen(
      (chunk) {
        if (result.isCompleted) return;
        if (bytes.length + chunk.length > 4096) {
          request.response.persistentConnection = false;
          result.completeError(
            const FormatException('Request body exceeds 4096 bytes.'),
          );
          return;
        }
        bytes.addAll(chunk);
      },
      onError: (Object error, StackTrace stack) {
        if (!result.isCompleted) result.completeError(error, stack);
      },
      onDone: () {
        if (result.isCompleted) return;
        try {
          result.complete(utf8.decode(bytes));
        } on FormatException catch (error) {
          result.completeError(error);
        }
      },
    );
    unawaited(
      request.response.done.then(
        (_) => subscription.cancel(),
        onError: (Object _) => subscription.cancel(),
      ),
    );
    return result.future;
  }
}
