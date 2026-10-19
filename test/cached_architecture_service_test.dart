import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gitlore/models/architecture.dart';
import 'package:gitlore/services/architecture_service.dart';
import 'package:gitlore/services/cached_architecture_service.dart';

class _Service implements ArchitectureService {
  final calls = <String>[];
  Future<Architecture> Function(String url)? handler;

  @override
  Future<Architecture> analyze(String url) {
    calls.add(url);
    return handler?.call(url) ?? Future.value(_result(url));
  }
}

Architecture _result(String url) => Architecture(
  repository: DemoArchitectureService.repositoryFromUrl(url),
  summary: 'A fixture',
  nodes: const [],
  steps: const [],
);

void main() {
  const url = 'https://github.com/team/repo';

  test(
    'normalizes repository URLs and rejects invalid URLs before calls',
    () async {
      final source = _Service();
      final cache = CachedArchitectureService(source);
      final first = await cache.analyze(' https://github.com/Team/Repo.git/ ');
      expect(await cache.analyze(url), same(first));
      expect(source.calls, ['https://github.com/Team/Repo']);
      await expectLater(
        cache.analyze('https://example.com/team/repo'),
        throwsFormatException,
      );
      expect(source.calls, hasLength(1));
    },
  );

  test(
    'expires exactly at the lifetime without extending it on reads',
    () async {
      var now = DateTime.utc(2026, 10, 19);
      final source = _Service();
      final cache = CachedArchitectureService(source, clock: () => now);
      final first = await cache.analyze(url);
      now = now.add(const Duration(minutes: 9));
      expect(await cache.analyze(url), same(first));
      now = now.add(const Duration(minutes: 1));
      expect(await cache.analyze(url), isNot(same(first)));
      expect(source.calls, hasLength(2));
    },
  );

  test('refresh bypasses cache and replaces the previous result', () async {
    final source = _Service();
    final cache = CachedArchitectureService(source);
    final first = await cache.analyze(url);
    final updated = await cache.refresh(url);
    expect(updated, isNot(same(first)));
    expect(await cache.analyze(url), same(updated));
    expect(source.calls, hasLength(2));
  });

  test('evicts the least recently used repository at capacity', () async {
    final source = _Service();
    final cache = CachedArchitectureService(source, maxEntries: 2);
    await cache.analyze(url);
    await cache.analyze('https://github.com/team/other');
    await cache.analyze(url);
    await cache.analyze('https://github.com/team/third');
    await cache.analyze(url);
    expect(source.calls, hasLength(3));
    await cache.analyze('https://github.com/team/other');
    expect(source.calls, hasLength(4));
  });

  test(
    'shares concurrent analysis and refresh requests for one repository',
    () async {
      final completion = Completer<Architecture>();
      final source = _Service()..handler = (_) => completion.future;
      final cache = CachedArchitectureService(source);
      final first = cache.analyze(url);
      final second = cache.analyze(url);
      final refresh = cache.refresh(url);
      expect(source.calls, hasLength(1));
      final result = _result(url);
      completion.complete(result);
      expect(await first, same(result));
      expect(await second, same(result));
      expect(await refresh, same(result));
      expect(await cache.analyze(url), same(result));
      expect(source.calls, hasLength(1));
    },
  );

  test(
    'failed refresh removes stale data and allows a subsequent retry',
    () async {
      final source = _Service();
      final cache = CachedArchitectureService(source);
      final first = await cache.analyze(url);
      source.handler = (_) => Future.error(StateError('offline'));
      await expectLater(cache.refresh(url), throwsStateError);
      source.handler = null;
      expect(await cache.analyze(url), isNot(same(first)));
      expect(source.calls, hasLength(3));
    },
  );

  test(
    'synchronous delegate errors do not leave a stuck pending request',
    () async {
      final source = _Service()..handler = (_) => throw StateError('offline');
      final cache = CachedArchitectureService(source);
      await expectLater(cache.analyze(url), throwsStateError);
      source.handler = null;
      await cache.analyze(url);
      expect(source.calls, hasLength(2));
    },
  );
}
