import 'package:path/path.dart' as p;

import '../models/architecture.dart';

/// A bounded lexical subset, not a JavaScript/TypeScript or Dart parser.
class ImportResolver {
  static List<ArchitectureEdge> resolve(List<SourceFile> files) {
    final paths = files.map((f) => f.path).toSet();
    final pairs = <(String, String)>{};
    for (final file in files) {
      final dart = file.path.endsWith('.dart');
      if (!dart && !RegExp(r'\.(js|jsx|ts|tsx|mjs|cjs)$').hasMatch(file.path)) {
        continue;
      }
      final tokens = _tokens(file.content);
      final specs = <String>[];
      for (var i = 0; i < tokens.length; i++) {
        final token = tokens[i];
        if (token.string) continue;
        final previous = i == 0 ? '' : tokens[i - 1].value;
        if (previous == '.' || previous == '?') continue;
        if (!dart &&
            token.value == 'require' &&
            i + 3 < tokens.length &&
            tokens[i + 1].value == '(' &&
            tokens[i + 2].string &&
            tokens[i + 3].value == ')') {
          specs.add(tokens[i + 2].value);
        }
        if (token.value != 'import' && token.value != 'export') continue;
        if (i + 1 >= tokens.length) continue;
        if (tokens[i + 1].string) {
          specs.add(tokens[i + 1].value);
          continue;
        }
        if (dart || tokens[i + 1].value == '(' || tokens[i + 1].value == '.') {
          continue;
        }
        // Stop at statement boundaries; don't interpret arbitrary `from` calls.
        for (var j = i + 1; j < tokens.length; j++) {
          if ([';', '=', '(', 'import', 'export'].contains(tokens[j].value)) {
            break;
          }
          if (!tokens[j].string &&
              tokens[j].value == 'from' &&
              j + 1 < tokens.length &&
              tokens[j + 1].string) {
            specs.add(tokens[j + 1].value);
            break;
          }
        }
      }
      for (final spec in specs) {
        if (dart) {
          if (spec.contains(':') || spec.startsWith('/')) continue;
        } else if (!spec.startsWith('./') && !spec.startsWith('../')) {
          continue;
        }
        if (spec.contains('\\') || spec.contains('?') || spec.contains('#')) {
          continue;
        }
        final target = p.posix.normalize(
          p.posix.join(p.posix.dirname(file.path), spec),
        );
        final extensions = dart
            ? ['.dart']
            : ['.ts', '.tsx', '.js', '.jsx', '.mjs', '.cjs'];
        final candidates = [
          target,
          if (p.posix.extension(target).isEmpty) ...[
            for (final ext in extensions) '$target$ext',
            if (!dart)
              for (final ext in extensions) '$target/index$ext',
          ],
          // Common TS source convention: .js specifiers refer to .ts/.tsx.
          if (!dart && target.endsWith('.js')) ...[
            '${target.substring(0, target.length - 3)}.ts',
            '${target.substring(0, target.length - 3)}.tsx',
          ],
        ];
        final resolved = candidates.where(paths.contains).firstOrNull;
        if (resolved != null && resolved != file.path) {
          pairs.add((file.path, resolved));
        }
      }
    }
    return [for (final pair in pairs) ArchitectureEdge(pair.$1, pair.$2)];
  }

  static List<_Token> _tokens(String source) {
    final result = <_Token>[];
    var i = 0;
    while (i < source.length) {
      final c = source[i];
      if (RegExp(r'\s').hasMatch(c)) {
        i++;
        continue;
      }
      if (source.startsWith('//', i)) {
        final end = source.indexOf('\n', i + 2);
        i = end < 0 ? source.length : end + 1;
        continue;
      }
      if (source.startsWith('/*', i)) {
        final end = source.indexOf('*/', i + 2);
        i = end < 0 ? source.length : end + 2;
        continue;
      }
      if (c == '"' || c == "'" || c == '`') {
        final quote = c;
        final start = ++i;
        var escaped = false;
        while (i < source.length && source[i] != quote) {
          if (source[i] == '\\') {
            escaped = true;
            i += 2;
          } else {
            i++;
          }
        }
        final closed = i < source.length;
        final value = source.substring(start, i.clamp(start, source.length));
        // Templates and escaped paths are intentionally unsupported. Keep a
        // sentinel token so adjacent syntax cannot join across a skipped string.
        result.add(
          _Token(closed && !escaped && quote != '`' ? value : '', true),
        );
        if (closed) i++;
        continue;
      }
      // Skip regex literals conservatively, including character classes.
      if (c == '/' &&
          (result.isEmpty ||
              [
                '=',
                '(',
                ':',
                ',',
                'return',
                '=>',
                '!',
                '[',
                ';',
              ].contains(result.last.value))) {
        i++;
        var inClass = false;
        while (i < source.length) {
          final r = source[i++];
          if (r == '\\') {
            i++;
            continue;
          }
          if (r == '[') inClass = true;
          if (r == ']') inClass = false;
          if (r == '/' && !inClass) break;
          if (r == '\n') break;
        }
        result.add(const _Token('', true));
        continue;
      }
      if (RegExp(r'[a-zA-Z0-9_$]').hasMatch(c)) {
        final start = i++;
        while (i < source.length &&
            RegExp(r'[a-zA-Z0-9_$]').hasMatch(source[i])) {
          i++;
        }
        result.add(_Token(source.substring(start, i), false));
      } else {
        result.add(_Token(c, false));
        i++;
      }
    }
    return result;
  }
}

class _Token {
  const _Token(this.value, this.string);
  final String value;
  final bool string;
}
