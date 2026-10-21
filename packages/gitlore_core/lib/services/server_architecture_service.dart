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
  });
  final String baseUrl;
  final http.Client? client;
  final bool ai;
  final String accessToken;
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

  Future<Architecture> _request(http.Client transport, String url) async {
    final request = http.Request(
      'POST',
      Uri.parse(baseUrl).resolve('/v1/analyze'),
    );
    request.headers['content-type'] = 'application/json';
    if (accessToken.isNotEmpty) {
      request.headers['authorization'] = 'Bearer $accessToken';
    }
    request.body = jsonEncode({'schemaVersion': 1, 'url': url, 'ai': ai});
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
      final message = ArchitectureCodec.text(body['error']['message'], 3000);
      throw AnalysisException(message);
    }
    return ArchitectureCodec.decode(body);
  }
}
