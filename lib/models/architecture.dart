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
  const StoryStep(this.title, this.body, this.nodeId);
  final String title;
  final String body;
  final String nodeId;
}

class Architecture {
  const Architecture({
    required this.repository,
    required this.summary,
    required this.nodes,
    required this.steps,
  });
  final String repository;
  final String summary;
  final List<ArchitectureNode> nodes;
  final List<StoryStep> steps;
}
