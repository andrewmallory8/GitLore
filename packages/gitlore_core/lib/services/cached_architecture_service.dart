import '../models/architecture.dart';
import 'architecture_service.dart';

/// Session-only, bounded LRU cache. No repository content is written to disk.
class CachedArchitectureService implements ArchitectureService {
  CachedArchitectureService(
    this.delegate, {
    this.maxEntries = 10,
    this.timeToLive = const Duration(minutes: 10),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    if (maxEntries < 1 || timeToLive <= Duration.zero) {
      throw ArgumentError('Cache capacity and lifetime must be positive.');
    }
  }

  final ArchitectureService delegate;
  final int maxEntries;
  final Duration timeToLive;
  final DateTime Function() _clock;
  final _entries = <String, ({Architecture result, DateTime expiresAt})>{};
  final _pending = <String, Future<Architecture>>{};

  @override
  Future<Architecture> analyze(String url) => _load(url, refresh: false);

  /// Rechecks GitHub even when a successful analysis is still cached.
  /// An in-flight request for the same repository is shared by all callers.
  Future<Architecture> refresh(String url) => _load(url, refresh: true);

  Future<Architecture> _load(String url, {required bool refresh}) async {
    final repository = DemoArchitectureService.repositoryFromUrl(url);
    final key = repository.toLowerCase();
    final pending = _pending[key];
    if (pending != null) return pending;

    final now = _clock();
    _entries.removeWhere((_, entry) => !now.isBefore(entry.expiresAt));
    final cached = _entries.remove(key);
    if (!refresh && cached != null) {
      // Reinsertion makes this the most recently used entry.
      _entries[key] = cached;
      return cached.result;
    }

    final request = Future<Architecture>.sync(
      () => delegate.analyze('https://github.com/$repository'),
    );
    _pending[key] = request;
    try {
      final result = await request;
      _entries[key] = (result: result, expiresAt: _clock().add(timeToLive));
      while (_entries.length > maxEntries) {
        _entries.remove(_entries.keys.first);
      }
      return result;
    } finally {
      // Errors are never cached; a later attempt can retry normally.
      _pending.remove(key);
    }
  }
}
