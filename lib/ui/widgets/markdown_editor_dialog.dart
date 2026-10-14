import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../core/models/workspace_record.dart';
import '../../core/theme/app_theme.dart';
import '../../state/workbench_controller.dart';
import 'attachment_panel.dart';
import 'common.dart';
import 'relation_picker_dialog.dart';
import 'workbench_markdown_style.dart';

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
  final titleFocusNode = FocusNode(debugLabel: 'MarkdownNoteEditor.title');
  final bodyFocusNode = FocusNode(debugLabel: 'MarkdownNoteEditor.body');
  late final Set<String> taskIds;
  late final Set<String> projectIds;
  late final Set<String> goalIds;
  late final Set<String> noteIds;
  final FocusNode relationFocusNode = FocusNode(
    debugLabel: 'MarkdownNoteEditor.relations',
  );
  bool preview = false;
  bool saving = false;
  String? error;
  String previewText = '';
  Timer? previewDebounce;
  late final String _initialSnapshot;

  String _snapshot() => jsonEncode([
    titleController.text,
    bodyController.text,
    taskIds.toList()..sort(),
    projectIds.toList()..sort(),
    goalIds.toList()..sort(),
    noteIds.toList()..sort(),
  ]);

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.note?.title ?? '');
    titleController.addListener(_clearTitleError);
    bodyController = TextEditingController(text: widget.note?.body ?? '');
    previewText = bodyController.text;
    bodyController.addListener(_schedulePreview);
    taskIds = _ids(widget.note?.data['relatedTaskIds']);
    projectIds = _ids(widget.note?.data['relatedProjectIds']);
    goalIds = _ids(widget.note?.data['relatedGoalIds']);
    noteIds = _ids(widget.note?.data['relatedNoteIds']);
    if (widget.note == null && widget.initialProjectId != null) {
      projectIds.add(widget.initialProjectId!);
    }
    _initialSnapshot = _snapshot();
  }

  @override
  void dispose() {
    previewDebounce?.cancel();
    bodyController.removeListener(_schedulePreview);
    titleController.removeListener(_clearTitleError);
    titleController.dispose();
    bodyController.dispose();
    titleFocusNode.dispose();
    bodyFocusNode.dispose();
    relationFocusNode.dispose();
    super.dispose();
  }

  void _schedulePreview() {
    previewDebounce?.cancel();
    previewDebounce = Timer(const Duration(milliseconds: 180), () {
      if (mounted && previewText != bodyController.text) {
        setState(() => previewText = bodyController.text);
      }
    });
  }

  void _clearTitleError() {
    if (error == '请填写笔记标题。' && titleController.text.trim().isNotEmpty) {
      setState(() => error = null);
    }
  }

  void _setPreview(bool value) {
    previewDebounce?.cancel();
    setState(() {
      previewText = bodyController.text;
      preview = value;
    });
    if (!value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) bodyFocusNode.requestFocus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return UnsavedChangesGuard(
      hasChanges: () => _snapshot() != _initialSnapshot,
      isBusy: () => saving,
      onSave: _save,
      child: AlertDialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: size.width < 700 ? 8 : 24,
          vertical: size.height < 600 ? 8 : 24,
        ),
        title: Text(widget.note == null ? '新建笔记' : '编辑笔记'),
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        content: SizedBox(
          width: size.width >= 1100 ? 1080 : AppLayout.readingMax,
          height: (size.height * 0.72).clamp(260.0, 680.0),
          child: AbsorbPointer(
            absorbing: saving,
            child: LayoutBuilder(builder: _content),
          ),
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.maybePop(context),
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
      ),
    );
  }

  Widget _content(BuildContext context, BoxConstraints constraints) {
    final wide = constraints.maxWidth >= 900;
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final minimumHeight = 400.0 * textScale.clamp(1.0, 1.5);
    final errorStyle = TextStyle(color: Theme.of(context).colorScheme.error);
    return SingleChildScrollView(
      child: SizedBox(
        height: constraints.maxHeight < minimumHeight
            ? minimumHeight
            : constraints.maxHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExternalField(
              label: '标题',
              child: TextField(
                controller: titleController,
                focusNode: titleFocusNode,
                autofocus: true,
                decoration: const InputDecoration(),
              ),
            ),
            if (error == '请填写笔记标题。') ...[
              const SizedBox(height: 4),
              Text(error!, style: errorStyle),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (wide)
                  Expanded(
                    child: Text(
                      '编辑与预览',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  )
                else
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
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
                        onSelectionChanged: (value) => _setPreview(value.first),
                      ),
                    ),
                  ),
                IconButton(
                  focusNode: relationFocusNode,
                  onPressed: () => _showRelations(context),
                  tooltip: '关联记录',
                  icon: Badge(
                    isLabelVisible:
                        taskIds.isNotEmpty ||
                        projectIds.isNotEmpty ||
                        goalIds.isNotEmpty ||
                        noteIds.isNotEmpty,
                    label: Text(
                      '${taskIds.length + projectIds.length + goalIds.length + noteIds.length}',
                    ),
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
            const SizedBox(height: 12),
            if (wide || !preview) ...[
              MarkdownToolbar(controller: bodyController),
              const SizedBox(height: 12),
            ],
            Expanded(
              child: wide
                  ? Row(
                      children: [
                        Expanded(child: _editorPane()),
                        const SizedBox(width: 16),
                        Expanded(child: _previewPane()),
                      ],
                    )
                  : AnimatedSwitcher(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      child: preview ? _previewPane() : _editorPane(),
                    ),
            ),
            if (error != null && error != '请填写笔记标题。') ...[
              const SizedBox(height: 8),
              Text(error!, style: errorStyle),
            ],
          ],
        ),
      ),
    );
  }

  Widget _editorPane() => TextField(
    key: const ValueKey('markdown-edit-pane'),
    controller: bodyController,
    focusNode: bodyFocusNode,
    expands: true,
    minLines: null,
    maxLines: null,
    textAlignVertical: TextAlignVertical.top,
    style: Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(fontSize: 16, height: 1.65),
    decoration: const InputDecoration(
      hintText: '使用 Markdown 记录正文…',
      alignLabelWithHint: true,
    ),
  );

  Widget _previewPane() => ListView(
    key: const ValueKey('markdown-preview-pane'),
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
    children: [
      MarkdownBody(
        data: previewText.isEmpty ? '*暂无正文*' : previewText,
        selectable: true,
        styleSheet: workbenchMarkdownStyle(context),
      ),
      const SizedBox(height: 24),
      if (widget.note != null)
        AttachmentPanel(owner: widget.note!, controller: widget.controller)
      else
        Row(
          children: [
            const Icon(Icons.attach_file_outlined, size: 18),
            const SizedBox(width: 8),
            Text('保存后可添加附件', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
    ],
  );

  Future<void> _showRelations(BuildContext parentContext) async {
    final selection = await showRelationPickerDialog(
      context: parentContext,
      controller: widget.controller,
      initialTaskIds: taskIds,
      initialProjectIds: projectIds,
      initialGoalIds: goalIds,
      initialNoteIds: noteIds,
      excludedNoteIds: {if (widget.note != null) widget.note!.id},
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
      goalIds
        ..clear()
        ..addAll(selection.goalIds);
      noteIds
        ..clear()
        ..addAll(selection.noteIds);
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
    if (selected == null || !mounted) return;
    bodyController.text = selected['body']?.toString() ?? '';
    _setPreview(false);
  }

  Future<void> _save() async {
    if (saving) return;
    final title = titleController.text.trim();
    if (title.isEmpty) {
      setState(() => error = '请填写笔记标题。');
      titleFocusNode.requestFocus();
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
      'relatedGoalIds': goalIds.toList(),
      'relatedNoteIds': noteIds.toList(),
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
      if (mounted) {
        showWorkbenchSnackBar(context, const SnackBar(content: Text('笔记已保存')));
        Navigator.pop(context, record);
      }
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
