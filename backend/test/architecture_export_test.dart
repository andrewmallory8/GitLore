import 'package:test/test.dart';
import 'package:gitlore_core/models/architecture.dart';
import 'package:gitlore_core/services/architecture_export.dart';

void main() {
  const a = Architecture(
    repository: 'owner/repo',
    summary: '<script>bad</script>',
    commitSha: 'abc123',
    nodes: [
      ArchitectureNode('unsafe-id', '"] --> injected', 'file', '', [
        'src/a.dart',
      ]),
      ArchitectureNode('b', 'B', 'file', '', []),
    ],
    steps: [
      StoryStep(
        'Chapter',
        'Explanation',
        'unsafe-id',
        evidence: [SourceEvidence('src/a.dart', 2, 4)],
      ),
    ],
    edges: [
      ArchitectureEdge('unsafe-id', 'b'),
      ArchitectureEdge('missing', 'b'),
    ],
    warnings: ['Limited sample'],
  );
  test('Mermaid encodes labels and excludes invalid references', () {
    final text = ArchitectureExport.mermaid(a);
    expect(text, contains('n0 -->|imports| n1'));
    expect(text, isNot(contains('injected')));
    expect(text, isNot(contains('missing')));
    expect(text, contains('Commit: abc123'));
  });
  test('Markdown preserves pinned citations and escapes raw HTML', () {
    final text = ArchitectureExport.markdown(a);
    expect(
      text,
      contains('https://github.com/owner/repo/blob/abc123/src/a.dart#L2-L4'),
    );
    expect(text, contains('&lt;script&gt;'));
    expect(text, contains('Limited sample'));
    expect(text, contains('```mermaid'));
  });
  test('Demo export does not invent source citations', () {
    const demo = Architecture(
      repository: 'demo/project',
      summary: '',
      nodes: [],
      steps: [],
    );
    expect(
      ArchitectureExport.markdown(demo),
      contains('Demonstration content'),
    );
    expect(ArchitectureExport.markdown(demo), isNot(contains('/blob/HEAD')));
  });
}
