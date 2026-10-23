import 'package:flutter/material.dart';

import 'project_filter.dart';

class ExploreProject {
  const ExploreProject(this.repository, this.description, this.tags);
  final String repository, description;
  final List<String> tags;
}

const exploreProjects = [
  ExploreProject(
    'expressjs/express',
    'Explore a Node.js web framework and its request-handling modules.',
    ['JavaScript', 'Node.js'],
  ),
  ExploreProject(
    'jonschlinkert/is-number',
    'Start small with a utility that checks whether a value is a number.',
    ['JavaScript'],
  ),
  ExploreProject(
    'andrewmallory8/GitLore',
    'Explore the Flutter app and repository-analysis project you are using.',
    ['Dart', 'Flutter', 'TypeScript'],
  ),
];

class ExplorePanel extends StatelessWidget {
  const ExplorePanel({super.key, required this.busy, required this.onAnalyze});
  final bool busy;
  final ValueChanged<String> onAnalyze;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Explore repositories',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 12),
        const Text(
          'Curated starting points, not pre-analyzed demos. Tags describe the projects, not verified analysis results. Each selection requests a fresh analysis using your current AI setting; server caching and quotas may apply.',
        ),
        const SizedBox(height: 16),
        ProjectFilter<ExploreProject>(
          items: exploreProjects,
          grid: true,
          nameOf: (p) => '${p.repository} ${p.description}',
          tagsOf: (p) => p.tags,
          itemBuilder: (p) => Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.repository,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(p.description),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final tag in p.tags) Chip(label: Text(tag)),
                    ],
                  ),
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () => onAnalyze('https://github.com/${p.repository}'),
                    child: const Text('Analyze this repository'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
