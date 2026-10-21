import 'package:flutter/material.dart';

import '../services/bookshelf_service.dart';

class BookshelfPanel extends StatelessWidget {
  const BookshelfPanel({
    super.key,
    required this.projects,
    required this.loading,
    required this.busy,
    required this.warning,
    required this.onRetry,
    required this.onDelete,
    required this.onClear,
    required this.onOpen,
  });
  final List<SavedProject> projects;
  final bool loading, busy;
  final String? warning;
  final VoidCallback onRetry, onClear;
  final ValueChanged<SavedProject> onDelete, onOpen;

  Future<void> _confirm(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear local saves?'),
        content: const Text(
          'This removes all saved analyses on this device, including unreadable records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear saves'),
          ),
        ],
      ),
    );
    if (confirmed == true) onClear();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your bookshelf',
          style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text(
          'Saved on this device. Opening a snapshot does not call GitHub or Gemini. Browser saves belong to this site address.',
        ),
        if (loading) const LinearProgressIndicator(),
        if (warning != null) ...[
          Text(warning!, style: const TextStyle(color: Colors.deepOrange)),
          Wrap(
            children: [
              TextButton(
                onPressed: busy || loading ? null : onRetry,
                child: const Text('Retry loading'),
              ),
              TextButton(
                onPressed: busy || loading ? null : () => _confirm(context),
                child: const Text('Clear local saves'),
              ),
            ],
          ),
        ],
        const SizedBox(height: 26),
        if (!loading && projects.isEmpty)
          const Text(
            'No stories saved yet. Analyze a repository, then save your project.',
          ),
        for (final project in projects)
          Card(
            child: ListTile(
              title: Text(project.architecture.repository),
              subtitle: Text(
                '${project.architecture.analysisKind == 'ai'
                    ? 'AI chapters'
                    : project.architecture.isLive
                    ? 'Static analysis'
                    : 'Demo'} · '
                '${project.architecture.commitSha?.substring(0, 7) ?? 'fixture'}\nSaved ${project.savedAt.toLocal().toString().split('.').first}',
              ),
              isThreeLine: true,
              onTap: () => onOpen(project),
              trailing: IconButton(
                tooltip: 'Delete ${project.architecture.repository}',
                onPressed: busy ? null : () => onDelete(project),
                icon: const Icon(Icons.delete_outline),
              ),
            ),
          ),
      ],
    ),
  );
}
