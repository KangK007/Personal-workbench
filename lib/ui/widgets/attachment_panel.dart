import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/models/attachment.dart';
import '../../core/models/workspace_record.dart';
import '../../core/theme/app_theme.dart';
import '../../state/workbench_controller.dart';
import 'common.dart';

class AttachmentPanel extends StatefulWidget {
  const AttachmentPanel({
    super.key,
    required this.owner,
    required this.controller,
  });

  final WorkspaceRecord owner;
  final WorkbenchController controller;

  @override
  State<AttachmentPanel> createState() => _AttachmentPanelState();
}

class _AttachmentPanelState extends State<AttachmentPanel> {
  late Future<List<Attachment>> attachments;
  int totalBytes = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant AttachmentPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.owner.id != widget.owner.id) _reload();
  }

  void _reload() {
    attachments = widget.controller.attachmentService.forRecord(
      widget.owner.id,
    );
    widget.controller.attachmentService.totalBytes().then((value) {
      if (mounted) setState(() => totalBytes = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Attachment>>(
      future: attachments,
      builder: (context, snapshot) {
        final values = snapshot.data ?? const <Attachment>[];
        final loading = snapshot.connectionState != ConnectionState.done;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '附件 · ${formatAttachmentBytes(totalBytes)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _importImage,
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('添加图片'),
                ),
              ],
            ),
            if (loading)
              const Column(
                children: [SkeletonListTile(), SkeletonListTile()],
              )
            else if (values.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '暂无附件',
                  style: TextStyle(color: context.tokens.mutedText),
                ),
              ),
            for (final attachment in values)
              FutureBuilder<File?>(
                future: widget.controller.attachmentService.resolve(attachment),
                builder: (context, fileSnapshot) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: fileSnapshot.data == null
                      ? const SizedBox.square(
                          dimension: 48,
                          child: Icon(Icons.cloud_off_outlined),
                        )
                      : InkWell(
                          onTap: () => _preview(attachment, fileSnapshot.data!),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.file(
                              fileSnapshot.data!,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const SizedBox.square(
                                    dimension: 48,
                                    child: Icon(Icons.broken_image_outlined),
                                  ),
                            ),
                          ),
                        ),
                  title: Text(attachment.fileName),
                  subtitle: Text(
                    fileSnapshot.data == null
                        ? '附件未下载 · ${formatAttachmentBytes(attachment.sizeBytes)}'
                        : '${formatAttachmentBytes(attachment.sizeBytes)} · '
                              'SHA-256 ${attachment.sha256.substring(0, 12)}…',
                  ),
                  trailing: IconButton(
                    onPressed: () => _delete(attachment),
                    tooltip: '删除附件',
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _importImage() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: false,
    );
    final path = result?.files.single.path;
    if (path == null) return;
    try {
      await widget.controller.attachmentService.importImage(
        owner: widget.owner,
        source: File(path),
      );
      if (mounted) setState(_reload);
    } on FormatException catch (error) {
      if (mounted) {
        showWorkbenchSnackBar(context, SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _delete(Attachment attachment) async {
    await widget.controller.attachmentService.delete(attachment);
    if (mounted) setState(_reload);
  }

  Future<void> _preview(Attachment attachment, File file) {
    return showWorkbenchDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(attachment.fileName),
                subtitle: Text(formatAttachmentBytes(attachment.sizeBytes)),
                trailing: IconButton(
                  tooltip: '关闭预览',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ),
              Flexible(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 5,
                  child: Image.file(file, fit: BoxFit.contain),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String formatAttachmentBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '$bytes B';
}
