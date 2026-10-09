import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/models/attachment.dart';
import '../../core/models/workspace_record.dart';
import '../../core/theme/app_theme.dart';
import '../../services/attachment_service.dart';
import '../../state/workbench_controller.dart';
import 'common.dart';

class _LoadResult<T> {
  const _LoadResult.value(this.value) : error = null;
  const _LoadResult.error(this.error) : value = null;

  final T? value;
  final Object? error;
}

Future<_LoadResult<T>> _capture<T>(Future<T> Function() load) async {
  try {
    return _LoadResult.value(await load());
  } catch (error) {
    return _LoadResult.error(error);
  }
}

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
  late Future<_LoadResult<List<Attachment>>> attachments;
  late Future<_LoadResult<int>> attachmentBytes;
  final FocusNode _addImageFocusNode = FocusNode(
    debugLabel: 'AttachmentPanel.addImage',
  );

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

  @override
  void dispose() {
    _addImageFocusNode.dispose();
    super.dispose();
  }

  void _reload() {
    attachments = _capture(
      () => widget.controller.attachmentService.forRecord(widget.owner.id),
    );
    attachmentBytes = _capture(widget.controller.attachmentService.totalBytes);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_LoadResult<List<Attachment>>>(
      future: attachments,
      builder: (context, snapshot) {
        final values = snapshot.data?.value ?? const <Attachment>[];
        final failed = snapshot.data?.error != null;
        final loading = snapshot.connectionState != ConnectionState.done;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            if (loading)
              const Column(children: [SkeletonListTile(), SkeletonListTile()])
            else if (failed)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: const Text('附件加载失败'),
                subtitle: const Text('无法读取这条记录的附件，请重试。'),
                trailing: TextButton(
                  onPressed: () => setState(_reload),
                  child: const Text('重试'),
                ),
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
              _AttachmentTile(
                key: ValueKey('attachment:${attachment.id}'),
                attachment: attachment,
                service: widget.controller.attachmentService,
                onPreview: (file) => _preview(attachment, file),
                onDelete: () => _delete(attachment),
              ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) => FutureBuilder<_LoadResult<int>>(
    future: attachmentBytes,
    builder: (context, snapshot) {
      final failed = snapshot.data?.error != null;
      final bytes = snapshot.data?.value;
      return Row(
        children: [
          Expanded(
            child: Text(
              failed
                  ? '附件 · 容量读取失败'
                  : bytes != null
                  ? '附件 · ${formatAttachmentBytes(bytes)}'
                  : '附件 · 统计中',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (failed)
            IconButton(
              tooltip: '重试容量统计',
              onPressed: () => setState(() {
                attachmentBytes = _capture(
                  widget.controller.attachmentService.totalBytes,
                );
              }),
              icon: const Icon(Icons.refresh),
            ),
          OutlinedButton.icon(
            focusNode: _addImageFocusNode,
            onPressed: _importImage,
            icon: const Icon(Icons.image_outlined),
            label: const Text('添加图片'),
          ),
        ],
      );
    },
  );

  Future<void> _importImage() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: false,
        lockParentWindow: true,
      );
      if (mounted) _addImageFocusNode.requestFocus();
      final path = result?.files.single.path;
      if (path == null) return;
      await widget.controller.attachmentService.importImage(
        owner: widget.owner,
        source: File(path),
      );
      if (mounted) {
        setState(_reload);
        showWorkbenchSnackBar(context, const SnackBar(content: Text('图片已添加')));
      }
    } catch (error) {
      if (mounted) {
        showWorkbenchSnackBar(
          context,
          SnackBar(
            content: Text(
              error is FormatException ? error.message : '添加图片失败：$error',
            ),
          ),
        );
      }
    }
  }

  Future<void> _delete(Attachment attachment) async {
    final confirmed = await showWorkbenchDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除附件？'),
        content: Text('“${attachment.fileName}”将从本机永久删除，无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('保留附件'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.controller.attachmentService.delete(attachment);
      if (mounted) {
        setState(_reload);
        showWorkbenchSnackBar(context, const SnackBar(content: Text('附件已删除')));
      }
    } catch (error) {
      if (mounted) {
        showWorkbenchSnackBar(
          context,
          SnackBar(content: Text('删除附件失败：$error')),
        );
      }
    }
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
                  child: Image.file(
                    file,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const Center(child: Text('图片无法显示，请检查原文件。')),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachmentTile extends StatefulWidget {
  const _AttachmentTile({
    super.key,
    required this.attachment,
    required this.service,
    required this.onPreview,
    required this.onDelete,
  });

  final Attachment attachment;
  final AttachmentService service;
  final ValueChanged<File> onPreview;
  final VoidCallback onDelete;

  @override
  State<_AttachmentTile> createState() => _AttachmentTileState();
}

class _AttachmentTileState extends State<_AttachmentTile> {
  late Future<_LoadResult<File?>> resolved;

  @override
  void initState() {
    super.initState();
    resolved = _capture(() => widget.service.resolve(widget.attachment));
  }

  @override
  void didUpdateWidget(covariant _AttachmentTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attachment.id != widget.attachment.id ||
        oldWidget.service != widget.service) {
      resolved = _capture(() => widget.service.resolve(widget.attachment));
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_LoadResult<File?>>(
    future: resolved,
    builder: (context, snapshot) {
      final file = snapshot.data?.value;
      final failed = snapshot.data?.error != null;
      final unavailable =
          snapshot.connectionState == ConnectionState.done &&
          file == null &&
          !failed;
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: file == null
            ? SizedBox.square(
                dimension: 48,
                child: Icon(
                  failed
                      ? Icons.broken_image_outlined
                      : Icons.cloud_off_outlined,
                ),
              )
            : InkWell(
                onTap: () => widget.onPreview(file),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.file(
                    file,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Tooltip(
                      message: '图片无法显示，请检查原文件',
                      child: SizedBox.square(
                        dimension: 48,
                        child: Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                ),
              ),
        title: Text(
          widget.attachment.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          failed
              ? '图片读取失败，请重试'
              : unavailable
              ? '附件未下载 · ${formatAttachmentBytes(widget.attachment.sizeBytes)}'
              : file == null
              ? '正在读取图片'
              : '${formatAttachmentBytes(widget.attachment.sizeBytes)} · '
                    'SHA-256 ${widget.attachment.sha256.substring(0, 12)}…',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (failed || unavailable)
              IconButton(
                onPressed: () => setState(() {
                  resolved = _capture(
                    () => widget.service.resolve(widget.attachment),
                  );
                }),
                tooltip: '重试附件读取',
                icon: const Icon(Icons.refresh),
              ),
            IconButton(
              onPressed: widget.onDelete,
              tooltip: '删除附件',
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      );
    },
  );
}

String formatAttachmentBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '$bytes B';
}
