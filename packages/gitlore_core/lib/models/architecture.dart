class SourceEvidence {
  const SourceEvidence(this.path, this.startLine, this.endLine);
  final String path;
  final int startLine;
  final int endLine;
}

class ArchitectureNode {
  const ArchitectureNode(
    this.id,
    this.label,
    this.kind,
    this.description,
    this.files,
  );
  final String id;
  final String label;
  final String kind;
  final String description;
  final List<String> files;
}

class StoryStep {
  const StoryStep(
    this.title,
    this.body,
    this.nodeId, {
    this.evidence = const [],
  });
  final String title;
  final String body;
  final String nodeId;
  final List<SourceEvidence> evidence;
}

class SourceFile {
  const SourceFile(this.path, this.content);
  final String path;
  final String content;
}

class ArchitectureEdge {
  const ArchitectureEdge(this.from, this.to);
  final String from;
  final String to;
}

class Architecture {
  const Architecture({
    required this.repository,
    required this.summary,
    required this.nodes,
    required this.steps,
    this.commitSha,
    this.branch,
    this.files = const [],
    this.edges = const [],
    this.warnings = const [],
    this.technologies = const [],
    this.fileCount = 0,
    this.analysisKind = 'static',
    this.model,
    this.generatedAt,
    this.analysisVersion = 'static-v2',
  });
  final String repository;
  final String summary;
  final List<ArchitectureNode> nodes;
  final List<StoryStep> steps;
  final String? commitSha;
  final String? branch;
  final List<SourceFile> files;
  final List<ArchitectureEdge> edges;
  final List<String> warnings;
  final List<String> technologies;
  final int fileCount;
  final String analysisKind;
  final String? model;
  final DateTime? generatedAt;
  final String analysisVersion;

  Architecture withNarrative({
    required List<StoryStep> chapters,
    required List<String> notices,
    String? aiModel,
  }) => Architecture(
    repository: repository,
    summary: summary,
    nodes: nodes,
    steps: chapters,
    commitSha: commitSha,
    branch: branch,
    files: files,
    edges: edges,
    warnings: notices,
    technologies: technologies,
    fileCount: fileCount,
    analysisKind: aiModel == null ? 'static' : 'ai',
    model: aiModel,
    generatedAt: DateTime.now().toUtc(),
    analysisVersion: aiModel == null ? 'static-v2' : 'gemini-story-v1',
  );
  bool get isLive => commitSha != null;

  Uri sourceUrl(String path) => Uri(
    scheme: 'https',
    host: 'github.com',
    pathSegments: [
      ...repository.split('/'),
      'blob',
      commitSha ?? 'HEAD',
      ...path.split('/'),
    ],
  );
}
