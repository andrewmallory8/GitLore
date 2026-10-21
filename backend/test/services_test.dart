import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../lib/models/architecture.dart';
import '../../lib/services/architecture_codec.dart';
import '../../lib/services/bookshelf_service.dart';
import '../../lib/services/server_architecture_service.dart';
import '../lib/gemini_narrator.dart';
import '../lib/analysis_server.dart';

const fixture = Architecture(
  repository: 'team/repo',
  summary: 'A fixture',
  commitSha: '1234567890abcdef1234567890abcdef12345678',
  branch: 'main',
  fileCount: 1,
  files: [SourceFile('main.js', "import './lib.js';\nconsole.log('hello');")],
  nodes: [
    ArchitectureNode('main.js', 'main.js', 'SOURCE', 'Entry point', [
      'main.js',
    ]),
  ],
  steps: [StoryStep('Start', 'Read the source', 'main.js')],
);

class MemoryStorage implements ShelfStorage {
  String? value;
  bool failWrite = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String v) async {
    if (failWrite) throw StateError('full');
    value = v;
  }
}

Map<String, dynamic> chapter({String path = 'main.js', int end = 2}) => {
  'title': 'Start',
  'body': 'This file imports a module and logs a greeting.',
  'nodeId': 'main.js',
  'evidence': [
    {'path': path, 'startLine': 1, 'endLine': end},
  ],
};
http.Response aiResponse(Map<String, dynamic> c) => http.Response(
  jsonEncode({
    'candidates': [
      {
        'finishReason': 'STOP',
        'content': {
          'parts': [
            {
              'text': jsonEncode({
                'chapters': [c],
              }),
            },
          ],
        },
      },
    ],
  }),
  200,
);

void main() {
  test('versioned analysis round-trips evidence, timestamp and AI labels', () {
    final a = fixture.withNarrative(
      chapters: [
        const StoryStep(
          'Start',
          'Read code',
          'main.js',
          evidence: [SourceEvidence('main.js', 1, 2)],
        ),
      ],
      notices: ['AI is inferred'],
      aiModel: 'fixture-model',
    );
    final result = ArchitectureCodec.decode(ArchitectureCodec.encode(a));
    expect(result.commitSha, fixture.commitSha);
    expect(result.steps.single.evidence.single.endLine, 2);
    expect(result.analysisKind, 'ai');
    expect(result.generatedAt, a.generatedAt);
  });
  test('rejects wrong versions, unknown nodes and invalid evidence', () {
    for (final j in [
      {...ArchitectureCodec.encode(fixture), 'schemaVersion': 2},
      {...ArchitectureCodec.encode(fixture), 'nodes': []},
      {
        ...ArchitectureCodec.encode(fixture),
        'steps': [
          {'title': 'x', 'body': 'x', 'nodeId': 'missing', 'evidence': []},
        ],
      },
      {
        ...ArchitectureCodec.encode(fixture),
        'steps': [chapter(path: 'missing.js')],
      },
      {
        ...ArchitectureCodec.encode(fixture),
        'steps': [chapter(end: 99)],
      },
    ]) {
      expect(() => ArchitectureCodec.decode(j), throwsFormatException);
    }
  });
  test('save survives recreation; replacement and delete persist', () async {
    final store = MemoryStorage();
    final shelf = BookshelfService(store);
    await shelf.load();
    await shelf.save(fixture);
    await shelf.save(fixture);
    final next = BookshelfService(store);
    final loaded = await next.load();
    expect(loaded.projects, hasLength(1));
    expect(
      loaded.projects.single.architecture.files.single.content,
      fixture.files.single.content,
    );
    await next.delete('team/repo');
    expect((await BookshelfService(store).load()).projects, isEmpty);
  });
  test('bad records are skipped; valid snapshots survive', () async {
    final store = MemoryStorage()
      ..value = jsonEncode({
        'schemaVersion': 1,
        'projects': [
          {
            'savedAt': '2026-10-20T00:00:00Z',
            'analysis': ArchitectureCodec.encode(fixture),
          },
          {'savedAt': 'invalid', 'analysis': {}},
        ],
      });
    final result = await BookshelfService(store).load();
    expect(result.projects, hasLength(1));
    expect(result.warning, isNotNull);
  });
  test('corrupt envelope is retained until explicit clear', () async {
    final store = MemoryStorage()..value = 'broken';
    final shelf = BookshelfService(store);
    expect((await shelf.load()).warning, isNotNull);
    await expectLater(shelf.save(fixture), throwsStateError);
    expect(store.value, 'broken');
    await shelf.clear();
    await shelf.save(fixture);
    expect((await shelf.load()).projects, hasLength(1));
  });
  test('failed write does not change visible or stored state', () async {
    final store = MemoryStorage();
    final shelf = BookshelfService(store);
    await shelf.load();
    await shelf.save(fixture);
    final original = store.value;
    store.failWrite = true;
    await expectLater(shelf.delete('team/repo'), throwsStateError);
    expect(store.value, original);
    expect((await shelf.load()).projects, hasLength(1));
  });
  test('Gemini validates evidence and caches by commit', () async {
    var calls = 0;
    final narrator = GeminiNarrator(
      apiKey: 'fixture-key',
      client: MockClient((req) async {
        calls++;
        expect(req.url.host, 'generativelanguage.googleapis.com');
        expect(req.url.query, isEmpty);
        expect(req.headers['x-goog-api-key'], 'fixture-key');
        expect(
          jsonDecode(req.body)['generationConfig']['responseMimeType'],
          'application/json',
        );
        return aiResponse(chapter());
      }),
    );
    final first = await narrator.enhance(fixture);
    expect(first.analysisKind, 'ai');
    expect((await narrator.enhance(fixture)).analysisKind, 'ai');
    expect(calls, 1);
  });
  test('bad AI references fall back to original static chapters', () async {
    final narrator = GeminiNarrator(
      apiKey: 'fixture',
      client: MockClient((_) async => aiResponse(chapter(end: 99))),
    );
    final result = await narrator.enhance(fixture);
    expect(result.analysisKind, 'static');
    expect(result.steps.single.body, 'Read the source');
    expect(result.warnings.last, contains('validation'));
  });
  test('quota, provider errors and absent key remain usable', () async {
    for (final code in [400, 401, 403, 404, 429, 500, 502, 503, 504]) {
      final result = await GeminiNarrator(
        apiKey: 'fixture',
        client: MockClient(
          (_) async => http.Response('private diagnostic', code),
        ),
      ).enhance(fixture);
      expect(result.analysisKind, 'static');
      expect(result.warnings.join(), isNot(contains('private diagnostic')));
      expect(result.warnings.last, contains('HTTP $code'));
    }
    expect(
      (await GeminiNarrator(apiKey: '').enhance(fixture)).analysisKind,
      'static',
    );
  });
  test('server adapter rejects malformed success responses', () async {
    final service = ServerArchitectureService(
      'http://localhost:8087',
      client: MockClient((_) async => http.Response('{}', 200)),
    );
    await expectLater(
      service.analyze('https://github.com/team/repo'),
      throwsException,
    );
  });

  group('HTTP endpoint', () {
    late HttpServer server;
    late Uri endpoint;
    late http.Client client;
    var calls = 0;
    setUp(() async {
      calls = 0;
      final api = AnalysisServer(
        narrator: GeminiNarrator(apiKey: ''),
        origins: {'http://localhost:8086'},
        accessToken: 'team-code',
        analyze: (url) async {
          calls++;
          return fixture;
        },
      );
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen(api.handle);
      endpoint = Uri.parse('http://127.0.0.1:${server.port}/v1/analyze');
      client = http.Client();
    });
    tearDown(() async {
      client.close();
      await server.close(force: true);
    });
    Future<http.Response> post(
      Object body, {
      String? origin,
      String token = 'team-code',
    }) => client.post(
      endpoint,
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer $token',
        if (origin != null) 'origin': origin,
      },
      body: jsonEncode(body),
    );
    test(
      'valid request returns contract and explicit static fallback',
      () async {
        final response = await post({
          'schemaVersion': 1,
          'url': 'https://github.com/team/repo',
          'ai': true,
        });
        expect(response.statusCode, 200);
        final result = ArchitectureCodec.decode(jsonDecode(response.body));
        expect(result.warnings.last, contains('not configured'));
        expect(calls, 1);
      },
    );
    test('bad auth, origins, schema and URLs never crawl', () async {
      final body = {'schemaVersion': 1, 'url': 'https://github.com/team/repo'};
      expect((await post(body, token: 'bad')).statusCode, 401);
      expect(
        (await post(body, origin: 'https://evil.example')).statusCode,
        403,
      );
      expect(
        (await post({
          'schemaVersion': 2,
          'url': 'https://github.com/team/repo',
        })).statusCode,
        400,
      );
      expect(
        (await post({'schemaVersion': 1, 'url': 'http://localhost/private'}))
            .statusCode,
        400,
      );
      expect(calls, 0);
    });
    test(
      'oversized requests rejected; CORS allows only known origin',
      () async {
        expect(
          (await post({'schemaVersion': 1, 'url': 'a' * 5000})).statusCode,
          400,
        );
        final req = http.Request('OPTIONS', endpoint)
          ..headers['origin'] = 'http://localhost:8086';
        final response = await client.send(req);
        expect(response.statusCode, 204);
        expect(
          response.headers['access-control-allow-origin'],
          'http://localhost:8086',
        );
        expect(calls, 0);
      },
    );
  });
}
