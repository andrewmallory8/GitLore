import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gitlore/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gitlore/models/architecture.dart';
import 'package:gitlore/services/github_architecture_service.dart';
import 'package:gitlore/services/architecture_service.dart';
import 'package:gitlore/services/repository_analyzer.dart';

const sha = '1234567890abcdef1234567890abcdef12345678';
final fixtureFiles = {
  'README.md': '# Orchard\n\nA small task API.',
  'package.json': '{"dependencies":{"express":"^5.0.0","pg":"^8.0.0"}}',
  'src/index.js': "const service = require('./service');\nservice.run();",
  'src/service.js': "exports.run = () => 'ok';",
};

http.Response jsonResponse(Object body) => http.Response(jsonEncode(body), 200);
MockClient repositoryClient({
  List<String>? requests,
  bool truncated = false,
  Map<String, String>? files,
}) {
  final contents = files ?? fixtureFiles;
  return MockClient((request) async {
    requests?.add(request.url.toString());
    expect(request.url.host, 'api.github.com');
    final path = request.url.path;
    if (path == '/repos/team/orchard') {
      return jsonResponse({
        'full_name': 'team/orchard',
        'description': 'A task API',
        'language': 'JavaScript',
        'default_branch': 'feature/main',
      });
    }
    if (path.contains('/commits/')) {
      return jsonResponse({
        'sha': sha,
        'commit': {
          'tree': {'sha': 'tree-sha'},
        },
      });
    }
    if (path.contains('/git/trees/')) {
      return jsonResponse({
        'truncated': truncated,
        'tree': [
          for (final entry in contents.entries)
            {
              'path': entry.key,
              'sha': 'blob-${contents.keys.toList().indexOf(entry.key)}',
              'type': 'blob',
              'mode': '100644',
              'size': utf8.encode(entry.value).length,
            },
          {
            'path': 'node_modules/bad/index.js',
            'sha': 'bad',
            'type': 'blob',
            'size': 10,
          },
          {'path': 'large.js', 'sha': 'large', 'type': 'blob', 'size': 999999},
          {
            'path': 'linked.js',
            'sha': 'link',
            'type': 'blob',
            'mode': '120000',
            'size': 20,
          },
        ],
      });
    }
    final id = int.parse(path.split('blob-').last);
    return jsonResponse({
      'encoding': 'base64',
      'content': base64Encode(utf8.encode(contents.values.elementAt(id))),
    });
  });
}

class _ResolvedService implements ArchitectureService {
  _ResolvedService(this.result);
  final Architecture result;
  @override
  Future<Architecture> analyze(String url) async => result;
}

void main() {
  testWidgets('live results show evidence and navigate on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final result = await tester.runAsync(
      () =>
          GitHubArchitectureService(client: repositoryClient())
              .analyze('https://github.com/team/orchard'),
    );
    await tester.pumpWidget(GitLoreApp(service: _ResolvedService(result!)));
    await tester.enterText(
      find.byType(TextField),
      'https://github.com/team/orchard',
    );
    await tester.ensureVisible(find.text('Analyze repository'));
    await tester.tap(find.text('Analyze repository'));
    await tester.pumpAndSettle();
    expect(find.text('SOURCE-BACKED'), findsOneWidget);
    expect(find.text('imports'), findsOneWidget);
    expect(find.textContaining('COMMIT 1234567'), findsOneWidget);
    await tester.ensureVisible(
      find.widgetWithText(OutlinedButton, 'README.md'),
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'README.md'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1  # Orchard'), findsOneWidget);
    expect(find.text('Observed relative imports'), findsOneWidget);
    await tester.ensureVisible(find.text('Next chapter →'));
    await tester.tap(find.text('Next chapter →'));
    await tester.pumpAndSettle();
    expect(find.text('CHAPTER 2 OF 5'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'fetches actual content and pins links to the analyzed commit',
    () async {
      final requests = <String>[];
      final result = await GitHubArchitectureService(
        client: repositoryClient(requests: requests),
      ).analyze('https://github.com/team/orchard');
      expect(result.repository, 'team/orchard');
      expect(result.commitSha, sha);
      expect(result.files.length, 4);
      expect(result.technologies, containsAll(['JavaScript', 'express', 'pg']));
      expect(result.nodes.any((node) => node.label == 'Database'), isFalse);
      expect(result.edges.single.from, 'src/index.js');
      expect(result.edges.single.to, 'src/service.js');
      expect(
        result.sourceUrl('src/index.js').toString(),
        'https://github.com/team/orchard/blob/$sha/src/index.js',
      );
      expect(
        result.steps.map((step) => step.nodeId),
        result.nodes.map((node) => node.id),
      );
      expect(requests.length, 7);
      expect(
        requests.any(
          (url) =>
              url.contains('bad') ||
              url.contains('/large') ||
              url.contains('/link'),
        ),
        isFalse,
      );
      expect(requests[1], contains('feature%2Fmain'));
    },
  );

  test('rejects invalid input without making requests', () async {
    final requests = <String>[];
    final service = GitHubArchitectureService(
      client: repositoryClient(requests: requests),
    );
    for (final url in [
      'http://github.com/team/orchard',
      'https://evil.com/team/orchard',
      'https://github.com/team/.git',
      'https://user@github.com/team/orchard',
    ]) {
      await expectLater(service.analyze(url), throwsFormatException);
    }
    expect(requests, isEmpty);
  });

  test('caps file fetches and surfaces truncated trees', () async {
    final contents = {
      for (var i = 0; i < 20; i++) 'src/file$i.js': 'export const value = 1;',
    };
    final requests = <String>[];
    final result = await GitHubArchitectureService(
      client: repositoryClient(
        requests: requests,
        files: contents,
        truncated: true,
      ),
    ).analyze('https://github.com/team/orchard');
    expect(result.files.length, GitHubArchitectureService.maxFiles);
    expect(requests.length, 3 + GitHubArchitectureService.maxFiles);
    expect(result.warnings, contains(contains('truncated')));
  });

  test('metadata-only repositories produce an honest usable tour', () async {
    final result = await GitHubArchitectureService(
      client: repositoryClient(files: {}),
    ).analyze('https://github.com/team/orchard');
    expect(result.files, isEmpty);
    expect(result.nodes.single.kind, 'GITHUB METADATA');
    expect(result.steps, hasLength(1));
    expect(result.warnings, contains(contains('No supported')));
  });

  for (final status in [403, 404, 409, 429, 500]) {
    test('HTTP $status has a readable error', () async {
      final service = GitHubArchitectureService(
        client: MockClient((_) async => http.Response('{}', status)),
      );
      await expectLater(
        service.analyze('https://github.com/team/orchard'),
        throwsA(
          isA<AnalysisException>().having(
            (error) => error.message,
            'message',
            isNotEmpty,
          ),
        ),
      );
    });
  }

  test('malformed manifests do not invent technologies or break analysis', () {
    for (final content in ['invalid json', '[]', '{"dependencies":42}']) {
      final result = RepositoryAnalyzer.build(
        repository: 'team/orchard',
        sha: sha,
        branch: 'main',
        files: [SourceFile('package.json', content)],
        fileCount: 1,
        warnings: [],
      );
      expect(result.technologies, isEmpty);
      expect(result.files.single.content, content);
    }
  });

  test('read budget is enforced across selected files', () async {
    final contents = {for (var i = 0; i < 8; i++) 'src/file$i.js': 'a' * 39000};
    final result = await GitHubArchitectureService(
      client: repositoryClient(files: contents),
    ).analyze('https://github.com/team/orchard');
    expect(
      result.files.fold<int>(
        0,
        (total, file) => total + utf8.encode(file.content).length,
      ),
      lessThanOrEqualTo(GitHubArchitectureService.maxTotalBytes),
    );
    expect(result.warnings, contains(contains('content budget')));
  });
}
