import 'package:flutter_test/flutter_test.dart';
import 'package:gitlore/models/architecture.dart';
import 'package:gitlore/services/import_resolver.dart';

Set<String> targets(String content, {String path = 'src/main.ts'}) =>
    ImportResolver.resolve([
      SourceFile(path, content),
      const SourceFile('src/a.ts', ''),
      const SourceFile('src/b/index.tsx', ''),
      const SourceFile('src/c.cjs', ''),
      const SourceFile('src/d.dart', ''),
    ]).map((edge) => edge.to).toSet();

void main() {
  test('resolves declarations, reexports, require, index and TS js suffix', () {
    expect(
      targets('''
import type { A } from './a.js';
export { B } from './b';
const c = require('./c');
import './a';
export * from './a';
'''),
      {'src/a.ts', 'src/b/index.tsx', 'src/c.cjs'},
    );
  });
  test('ignores comments, ordinary strings, templates and regex', () {
    expect(
      targets(r'''
// import A from './a';
/* require('./c') */
const text = "import B from './b'";
const other = 'require("./c")';
const template = `import './a'`;
const regex = /require('./c')/;
'''),
      isEmpty,
    );
  });
  test('ignores aliases, computed and dynamic imports and property calls', () {
    expect(
      targets('''
import a from '@/a';
import('./a');
require('./a' + suffix);
object.require('./c');
const from = './b';
'''),
      isEmpty,
    );
  });
  test('handles interleaved comments and multiline imports', () {
    expect(
      targets('''
import /* note */ {
 A
} from /* note */ './a';
const b = require /* note */ ('./b');
'''),
      {'src/a.ts', 'src/b/index.tsx'},
    );
  });
  test('preserves relative Dart directives and ignores other languages', () {
    expect(
      targets("import 'd.dart'; export './d.dart';", path: 'src/main.dart'),
      {'src/d.dart'},
    );
    expect(targets("import './a'", path: 'src/main.py'), isEmpty);
  });
  test('rejects missing, self, escaped paths and unterminated strings', () {
    expect(
      targets(
        r"import './missing'; import './main.ts'; import './\x61'; import './a",
      ),
      isEmpty,
    );
  });
}
