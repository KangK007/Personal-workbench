import 'package:flutter/material.dart';

import '../../core/models/workspace_record.dart';
import '../../state/workbench_controller.dart';
import 'common.dart';

Future<WorkspaceRecord?> showTaskGroupEditor({
  required BuildContext context,
  required WorkbenchController controller,
  WorkspaceRecord? group,
  String? initialProjectId,
}) {
  return showWorkbenchDialog<WorkspaceRecord>(
    context: context,
    barrierDismissible: false,
    builder: (context) => TaskGroupEditorDialog(
      controller: controller,
      group: group,
      initialProjectId: initialProjectId,
    ),
  );
}

class TaskGroupEditorDialog extends StatefulWidget {
  const TaskGroupEditorDialog({
    super.key,
    required this.controller,
    this.group,
    this.initialProjectId,
  });

  final WorkbenchController controller;
  final WorkspaceRecord? group;
  final String? initialProjectId;

  @override
  State<TaskGroupEditorDialog> createState() => _TaskGroupEditorDialogState();
}

class _TaskGroupEditorDialogState extends State<TaskGroupEditorDialog> {
  late final TextEditingController titleController;
  late final TextEditingController timeLimitController;
  late bool sequential;
  late String projectId;
  bool saving = false;
  String? error;

  bool get modeLocked =>
      widget.group != null &&
      widget.controller.taskGroupModeLocked(widget.group!);

  @override
  void initState() {
    super.initState();
    final group = widget.group;
    titleController = TextEditingController(text: group?.title ?? '');
    timeLimitController = TextEditingController(
      text: (group?.data['timeLimitMinutes'] as num?)?.toInt().toString() ?? '',
    );
    sequential = group?.data['mode'] == 'sequential';
    projectId = group?.projectId ?? widget.initialProjectId ?? '';
  }

  @override
  void dispose() {
    titleController.dispose();
    timeLimitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !saving,
      child: AlertDialog(
        title: Text(widget.group == null ? '新建任务群' : '编辑任务群'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExternalField(
                  label: '名称',
                  child: TextField(
                    controller: titleController,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: projectId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '主项目（可选）'),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('未归属')),
                    for (final project in widget.controller.projects)
                      DropdownMenuItem(
                        value: project.id,
                        child: Text(
                          project.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: saving
                      ? null
                      : (value) => setState(() => projectId = value ?? ''),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('按顺序执行'),
                  subtitle: Text(
                    modeLocked ? '已有成员开始执行，当前模式已锁定' : '关闭时，群内任务可以并行执行',
                  ),
                  value: sequential,
                  onChanged: saving || modeLocked
                      ? null
                      : (value) => setState(() => sequential = value),
                ),
                const SizedBox(height: 4),
                ExternalField(
                  label: '总时限（分钟，可选）',
                  child: TextField(
                    controller: timeLimitController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: '1–43200'),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actionsOverflowDirection: VerticalDirection.down,
        actionsOverflowAlignment: OverflowBarAlignment.end,
        actionsOverflowButtonSpacing: 8,
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
            label: Text(saving ? '保存中' : '保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final limitText = timeLimitController.text.trim();
      final timeLimit = limitText.isEmpty ? null : int.tryParse(limitText);
      if (limitText.isNotEmpty && timeLimit == null) {
        throw const FormatException('总时限必须填写整数分钟。');
      }
      final selectedProjectId = projectId.isEmpty ? null : projectId;
      final saved = widget.group == null
          ? await widget.controller.createTaskGroup(
              title: titleController.text,
              sequential: sequential,
              timeLimitMinutes: timeLimit,
              projectId: selectedProjectId,
            )
          : await widget.controller.updateTaskGroup(
              group: widget.group!,
              title: titleController.text,
              sequential: sequential,
              timeLimitMinutes: timeLimit,
              projectId: selectedProjectId,
            );
      if (mounted) Navigator.pop(context, saved);
    } on FormatException catch (exception) {
      if (!mounted) return;
      setState(() {
        error = exception.message.toString();
        saving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        error = '任务群保存失败，请重试。';
        saving = false;
      });
    }
  }
}
