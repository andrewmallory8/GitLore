import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gitlore_core/services/architecture_export.dart';

import '../models/architecture.dart';

class ExportDialog extends StatefulWidget {
  const ExportDialog({super.key, required this.architecture});
  final Architecture architecture;
  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  bool diagram = false;
  bool busy = false;
  String? status;
  String get content => diagram
      ? ArchitectureExport.mermaid(widget.architecture)
      : ArchitectureExport.markdown(widget.architecture);
  Future<void> deliver(bool copy) async {
    setState(() {
      busy = true;
      status = null;
    });
    try {
      if (copy) {
        await Clipboard.setData(ClipboardData(text: content));
        if (mounted) setState(() => status = 'Copied to clipboard.');
      } else {
        final filename =
            '${widget.architecture.repository.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '-')}.${diagram ? 'mmd' : 'md'}';
        final box = context.findRenderObject() as RenderBox;
        final result = await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile.fromData(
                Uint8List.fromList(utf8.encode(content)),
                mimeType: 'text/plain',
              ),
            ],
            fileNameOverrides: [filename],
            sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
            downloadFallbackEnabled: true,
          ),
        );
        if (mounted) {
          setState(
            () => status = result.status == ShareResultStatus.dismissed
                ? 'Export dismissed. You can try again or copy the text.'
                : 'Export handed to your browser or device.',
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => status = 'Could not export. Try Copy text instead.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Export analysis'),
    content: SizedBox(
      width: 640,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Markdown walkthrough'),
                selected: !diagram,
                onSelected: busy
                    ? null
                    : (_) => setState(() {
                        diagram = false;
                        status = null;
                      }),
              ),
              ChoiceChip(
                label: const Text('Mermaid diagram'),
                selected: diagram,
                onSelected: busy
                    ? null
                    : (_) => setState(() {
                        diagram = true;
                        status = null;
                      }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Exports the current snapshot without another API request. Markdown includes the diagram, chapters, source references and limitations.',
          ),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              child: SelectableText(
                content,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
          if (status != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(status!),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Close'),
      ),
      TextButton(
        onPressed: busy ? null : () => deliver(true),
        child: const Text('Copy text'),
      ),
      FilledButton(
        onPressed: busy ? null : () => deliver(false),
        child: Text(kIsWeb ? 'Download / share' : 'Share file'),
      ),
    ],
  );
}
