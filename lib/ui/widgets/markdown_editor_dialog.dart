import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../core/models/workspace_record.dart';
import '../../state/workbench_controller.dart';
import 'common.dart';
import 'relation_picker_dialog.dart';

Future<WorkspaceRecord?> showMarkdownNoteEditor(
  BuildContext context,
  WorkbenchController controller, {
  WorkspaceRecord? note,
  String? initialProjectId,
}) {
  return showWorkbenchDialog<WorkspaceRecord>(
    context: context,
    builder: (context) => _MarkdownNoteEditor(
      controller: controller,
      note: note,
      initialProjectId: initialProjectId,
    ),
  );
}

class _MarkdownNoteEditor extends StatefulWidget {
  const _MarkdownNoteEditor({
    required this.controller,
    this.note,
    this.initialProjectId,
  });

  final WorkbenchController controller;
  final WorkspaceRecord? note;
  final String? initialProjectId;

  @override
  State<_MarkdownNoteEditor> createState() => _MarkdownNoteEditorState();
}

class _MarkdownNoteEditorState extends State<_MarkdownNoteEditor> {
  late final TextEditingController titleController;
  late final TextEditingController bodyController;
  late final Set<String> taskIds;
  late final Set<String> projectIds;
  final FocusNode relationFocusNode = FocusNode(
    debugLabel: 'MarkdownNoteEditor.relations',
  );
  bool preview = false;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.note?.title ?? '');
    bodyController = TextEditingController(text: widget.note?.body ?? '');
    taskIds = _ids(widget.note?.data['relatedTaskIds']);
    projectIds = _ids(widget.note?.data['relatedProjectIds']);
    if (widget.note == null && widget.initialProjectId != null) {
      projectIds.add(widget.initialProjectId!);
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    bodyController.dispose();
    relationFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.note == null ? '新建笔记' : '编辑笔记'),
      content: SizedBox(
        width: 760,
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExternalField(
              label: '标题',
              child: TextField(
                controller: titleController,
                autofocus: true,
                decoration: const InputDecoration(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        icon: Icon(Icons.edit_outlined),
                        label: Text('编辑'),
                      ),
                      ButtonSegment(
                        value: true,
                        icon: Icon(Icons.visibility_outlined),
                        label: Text('预览'),
                      ),
                    ],
                    selected: {preview},
                    onSelectionChanged: (value) =>
                        setState(() => preview = value.first),
                  ),
                ),
                IconButton(
                  focusNode: relationFocusNode,
                  onPressed: () => _showRelations(context),
                  tooltip: '关联任务和项目',
                  icon: Badge(
                    isLabelVisible: taskIds.isNotEmpty || projectIds.isNotEmpty,
                    label: Text('${taskIds.length + projectIds.length}'),
                    child: const Icon(Icons.account_tree_outlined),
                  ),
                ),
                if ((widget.note?.data['versions'] as List<dynamic>? ??
                        const [])
                    .isNotEmpty)
                  IconButton(
                    onPressed: () => _showVersions(context),
                    tooltip: '恢复正文版本',
                    icon: const Icon(Icons.history_outlined),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (!preview) MarkdownToolbar(controller: bodyController),
            Expanded(
              child: preview
                  ? Markdown(
                      data: bodyController.text.isEmpty
                          ? '*暂无正文*'
                          : bodyController.text,
                      selectable: true,
                    )
                  : TextField(
                      controller: bodyController,
                      expands: true,
                      minLines: null,
                      maxLines: null,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: const InputDecoration(
                        hintText: '使用 Markdown 记录正文…',
                        alignLabelWithHint: true,
                      ),
                    ),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: saving ? null : _save,
          icon: saving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: const Text('保存'),
        ),
      ],
    );
  }

  Future<void> _showRelations(BuildContext parentContext) async {
    final selection = await showRelationPickerDialog(
      context: parentContext,
      controller: widget.controller,
      initialTaskIds: taskIds,
      initialProjectIds: projectIds,
      returnFocusNode: relationFocusNode,
    );
    if (selection == null || !mounted) return;
    setState(() {
      taskIds
        ..clear()
        ..addAll(selection.taskIds);
      projectIds
        ..clear()
        ..addAll(selection.projectIds);
    });
  }

  Future<void> _showVersions(BuildContext parentContext) async {
    final versions =
        (widget.note?.data['versions'] as List<dynamic>? ?? const [])
            .map((value) => Map<String, dynamic>.from(value as Map))
            .toList()
            .reversed
            .toList();
    final selected = await showWorkbenchSheet<Map<String, dynamic>>(
      context: parentContext,
      showDragHandle: true,
      builder: (context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Text('正文版本', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final version in versions)
            ListTile(
              leading: const Icon(Icons.history_outlined),
              title: Text(
                version['body']
                            ?.toString()
                            .split('\n')
                            .firstOrNull
                            ?.trim()
                            .isNotEmpty ==
                        true
                    ? version['body'].toString().split('\n').first
                    : '空正文',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(version['savedAt']?.toString() ?? ''),
              trailing: const Text('载入'),
              onTap: () => Navigator.pop(context, version),
            ),
        ],
      ),
    );
    if (selected == null) return;
    setState(() {
      bodyController.text = selected['body']?.toString() ?? '';
      preview = false;
    });
  }

  Future<void> _save() async {
    final title = titleController.text.trim();
    if (title.isEmpty) {
      setState(() => error = '请填写笔记标题。');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    final versions =
        (widget.note?.data['versions'] as List<dynamic>? ?? const [])
            .map((value) => Map<String, dynamic>.from(value as Map))
            .toList();
    if (widget.note != null && widget.note!.body != bodyController.text) {
      versions.add({
        'body': widget.note!.body,
        'savedAt': widget.note!.updatedAt.toUtc().toIso8601String(),
      });
      if (versions.length > 10) versions.removeRange(0, versions.length - 10);
    }
    final data = {
      ...?widget.note?.data,
      'recordType': 'markdownNote',
      'relatedTaskIds': taskIds.toList(),
      'relatedProjectIds': projectIds.toList(),
      'versions': versions,
    };
    final record = widget.note == null
        ? WorkspaceRecord.create(
            kind: RecordKind.note,
            title: title,
            body: bodyController.text,
            projectId: widget.initialProjectId,
            data: data,
          )
        : widget.note!.copyWith(
            title: title,
            body: bodyController.text,
            data: data,
          );
    try {
      if (widget.note == null) {
        await widget.controller.addRecord(record);
      } else {
        await widget.controller.updateRecord(record);
      }
      if (mounted) Navigator.pop(context, record);
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error = '保存失败，请检查本地存储后重试。';
        });
      }
    }
  }
}

class MarkdownToolbar extends StatelessWidget {
  const MarkdownToolbar({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      children: [
        IconButton(
          onPressed: () => _insert('**', '**'),
          tooltip: '加粗',
          icon: const Icon(Icons.format_bold),
        ),
        IconButton(
          onPressed: () => _insert('_', '_'),
          tooltip: '斜体',
          icon: const Icon(Icons.format_italic),
        ),
        IconButton(
          onPressed: () => _insert('## ', ''),
          tooltip: '标题',
          icon: const Icon(Icons.title),
        ),
        IconButton(
          onPressed: () => _insert('- ', ''),
          tooltip: '列表',
          icon: const Icon(Icons.format_list_bulleted),
        ),
        IconButton(
          onPressed: () => _insert('[', '](https://)'),
          tooltip: '链接',
          icon: const Icon(Icons.link),
        ),
      ],
    );
  }

  void _insert(String before, String after) {
    final selection = controller.selection;
    final start = selection.isValid ? selection.start : controller.text.length;
    final end = selection.isValid ? selection.end : controller.text.length;
    final selected = controller.text.substring(start, end);
    controller.text = controller.text.replaceRange(
      start,
      end,
      '$before$selected$after',
    );
    controller.selection = TextSelection.collapsed(
      offset: start + before.length + selected.length,
    );
  }
}

Set<String> _ids(Object? value) => (value as List<dynamic>? ?? const [])
    .map((item) => item.toString())
    .toSet();
