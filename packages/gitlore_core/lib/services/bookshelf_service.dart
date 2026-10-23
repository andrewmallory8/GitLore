import 'dart:convert';

import '../models/architecture.dart';
import 'architecture_codec.dart';

abstract class ShelfStorage {
  Future<String?> read();
  Future<void> write(String value);
}

class SavedProject {
  const SavedProject(this.architecture, this.savedAt);
  final Architecture architecture;
  final DateTime savedAt;
}

class ShelfResult {
  const ShelfResult(this.projects, this.warning);
  final List<SavedProject> projects;
  final String? warning;
}

class BookshelfService {
  BookshelfService(this.storage);
  final ShelfStorage storage;
  static const maxBytes = 4000000;
  static const maxProjects = 10;
  List<SavedProject> _projects = [];
  bool _ready = false;
  bool _busy = false;

  Future<ShelfResult> load() async {
    try {
      final value = await storage.read();
      if (value == null) {
        _ready = true;
        return const ShelfResult([], null);
      }
      if (utf8.encode(value).length > maxBytes) throw const FormatException();
      final data = jsonDecode(value) as Map;
      if (data['schemaVersion'] != 1) throw const FormatException();
      final records = ArchitectureCodec.list(data['projects'], maxProjects);
      var skipped = 0;
      final projects = <SavedProject>[];
      for (final r in records) {
        try {
          final a = ArchitectureCodec.decode(r['analysis']);
          final date = DateTime.parse(r['savedAt'] as String);
          projects.removeWhere(
            (p) =>
                p.architecture.repository.toLowerCase() ==
                a.repository.toLowerCase(),
          );
          projects.add(SavedProject(a, date));
        } catch (_) {
          skipped++;
        }
      }
      _projects = projects;
      _ready = true;
      return ShelfResult(
        List.unmodifiable(projects),
        skipped == 0
            ? null
            : '$skipped outdated or damaged saved projects could not be opened.',
      );
    } catch (_) {
      // Keep unreadable storage intact until an explicit user reset.
      _ready = false;
      return const ShelfResult(
        [],
        'Saved projects could not be read. Retry, or clear local saves to start again.',
      );
    }
  }

  Future<List<SavedProject>> save(Architecture a) => _change(
    () => [
      ..._projects.where(
        (p) =>
            p.architecture.repository.toLowerCase() !=
            a.repository.toLowerCase(),
      ),
      SavedProject(
        ArchitectureCodec.decode(ArchitectureCodec.encode(a)),
        DateTime.now().toUtc(),
      ),
    ],
  );
  Future<List<SavedProject>> delete(String repo) => _change(
    () => _projects.where((p) => p.architecture.repository != repo).toList(),
  );
  Future<List<SavedProject>> clear() async {
    if (_busy) throw StateError('A save is already in progress.');
    final wasReady = _ready;
    _ready = true;
    try {
      return await _change(() => []);
    } catch (_) {
      _ready = wasReady;
      rethrow;
    }
  }

  Future<List<SavedProject>> _change(
    List<SavedProject> Function() update,
  ) async {
    if (!_ready || _busy) {
      throw StateError('Saved projects are not ready. Retry loading first.');
    }
    _busy = true;
    try {
      final next = update();
      if (next.length > maxProjects) {
        throw StateError(
          'Bookshelf is full (10 projects). Delete one before saving.',
        );
      }
      final value = jsonEncode({
        'schemaVersion': 1,
        'projects': [
          for (final p in next)
            {
              'savedAt': p.savedAt.toUtc().toIso8601String(),
              'analysis': ArchitectureCodec.encode(p.architecture),
            },
        ],
      });
      if (utf8.encode(value).length > maxBytes) {
        throw StateError(
          'Local storage limit reached. Delete a saved project first.',
        );
      }
      await storage.write(value);
      _projects = next;
      return List.unmodifiable(next);
    } finally {
      _busy = false;
    }
  }
}
