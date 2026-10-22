import 'package:flutter/material.dart';

class ProjectFilter<T> extends StatefulWidget {
  const ProjectFilter({
    super.key,
    required this.items,
    required this.nameOf,
    required this.tagsOf,
    required this.itemBuilder,
  });
  final List<T> items;
  final String Function(T) nameOf;
  final List<String> Function(T) tagsOf;
  final Widget Function(T) itemBuilder;
  @override
  State<ProjectFilter<T>> createState() => _ProjectFilterState<T>();
}

class _ProjectFilterState<T> extends State<ProjectFilter<T>> {
  final controller = TextEditingController();
  String? tag;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tags = widget.items.expand(widget.tagsOf).toSet().toList()..sort();
    final selected = tags.contains(tag) ? tag : null;
    final query = controller.text.trim().toLowerCase();
    final matches = widget.items
        .where(
          (item) =>
              widget.nameOf(item).toLowerCase().contains(query) &&
              (selected == null || widget.tagsOf(item).contains(selected)),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Search projects',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('All technologies'),
              selected: selected == null,
              onSelected: (_) => setState(() => tag = null),
            ),
            for (final t in tags)
              ChoiceChip(
                label: Text(t),
                selected: selected == t,
                onSelected: (_) => setState(() => tag = t),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text('${matches.length} of ${widget.items.length} projects'),
        ),
        if (matches.isEmpty)
          const Text('No matching projects. Try another search or technology.'),
        if (query.isNotEmpty || selected != null)
          TextButton(
            onPressed: () => setState(() {
              controller.clear();
              tag = null;
            }),
            child: const Text('Clear filters'),
          ),
        for (final item in matches) widget.itemBuilder(item),
      ],
    );
  }
}
