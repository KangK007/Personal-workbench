import 'package:flutter/material.dart';

import '../../core/models/workspace_record.dart';
import '../../state/workbench_controller.dart';
import 'common.dart';

class BatchTaskToolbar extends StatefulWidget {
  const BatchTaskToolbar({
    super.key,
    required this.controller,
    required this.visibleTasks,
    required this.selectedTasks,
    required this.onSelectionChanged,
    required this.onExit,
  });

  final WorkbenchController controller;
  final List<WorkspaceRecord> visibleTasks;
  final List<WorkspaceRecord> selectedTasks;
  final ValueChanged<Set<String>> onSelectionChanged;
  final VoidCallback onExit;

  @override
  State<BatchTaskToolbar> createState() => _BatchTaskToolbarState();
}

class _BatchTaskToolbarState extends State<BatchTaskToolbar> {
  static const _clearProjectValue = '__clear_project__';
  static const _clearGroupValue = '__clear_group__';

  bool busy = false;

  bool get hasSelection => widget.selectedTasks.isNotEmpty;

  bool get allSelected =>
      widget.visibleTasks.isNotEmpty &&
      widget.selectedTasks.length == widget.visibleTasks.length;

  void _toggleAll(bool value) {
    widget.onSelectionChanged(
      value ? widget.visibleTasks.map((task) => task.id).toSet() : <String>{},
    );
  }

  Future<void> _run(
    Future<BatchOperationResult> Function() operation,
    BatchTaskAction action,
  ) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final result = await operation();
      if (!mounted) return;
      final suffix = result.failed == 0 ? '' : '，失败 ${result.failed} 项';
      showWorkbenchSnackBar(
        context,
        SnackBar(
          content: Text(
            '${_actionMessage(action)} ${result.succeeded} 项$suffix',
          ),
        ),
      );
      if (result.isSuccessful) {
        widget.onExit();
      } else {
        _retainFailedSelection(result);
      }
    } catch (error) {
      if (mounted) {
        showWorkbenchSnackBar(
          context,
          SnackBar(content: Text('批量操作失败：$error')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 58,
          child: Row(
            children: [
              IconButton(
                tooltip: '退出多选',
                onPressed: busy ? null : widget.onExit,
                icon: const Icon(Icons.close),
              ),
              Checkbox(
                value: widget.selectedTasks.isEmpty
                    ? false
                    : (allSelected ? true : null),
                tristate: true,
                onChanged: busy ? null : (value) => _toggleAll(value == true),
              ),
              Text('${widget.selectedTasks.length} 项'),
              const SizedBox(width: 4),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      PopupMenuButton<String>(
                        enabled: !busy && hasSelection,
                        tooltip: '设置状态',
                        icon: const Icon(Icons.flag_outlined),
                        onSelected: (status) => _run(
                          () => widget.controller.batchSetTaskStatus(
                            widget.selectedTasks,
                            status,
                          ),
                          BatchTaskAction.setStatus,
                        ),
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: WorkStatus.inbox,
                            child: Text('收件箱'),
                          ),
                          PopupMenuItem(
                            value: WorkStatus.todo,
                            child: Text('待办'),
                          ),
                          PopupMenuItem(
                            value: WorkStatus.doing,
                            child: Text('进行中'),
                          ),
                          PopupMenuItem(
                            value: WorkStatus.done,
                            child: Text('已完成'),
                          ),
                          PopupMenuItem(
                            value: WorkStatus.cancelled,
                            child: Text('已取消'),
                          ),
                        ],
                      ),
                      PopupMenuButton<String>(
                        enabled: !busy && hasSelection,
                        tooltip: '安排日期',
                        icon: const Icon(Icons.event_outlined),
                        onSelected: (value) async {
                          if (value == 'custom') {
                            final date = await showDatePicker(
                              context: context,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                              initialDate: widget.controller.currentTime(),
                            );
                            if (date == null) return;
                            await _schedule(date);
                          } else if (value == 'clear') {
                            await _schedule(null);
                          } else {
                            final offset = value == 'tomorrow' ? 1 : 0;
                            final now = widget.controller.currentTime().add(
                              Duration(days: offset),
                            );
                            await _schedule(
                              DateTime(now.year, now.month, now.day),
                            );
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'today', child: Text('安排到今天')),
                          PopupMenuItem(
                            value: 'tomorrow',
                            child: Text('安排到明天'),
                          ),
                          PopupMenuItem(value: 'custom', child: Text('选择日期')),
                          PopupMenuDivider(),
                          PopupMenuItem(value: 'clear', child: Text('清除日期')),
                        ],
                      ),
                      PopupMenuButton<String>(
                        enabled: !busy && hasSelection,
                        tooltip: '设置主项目',
                        icon: const Icon(Icons.folder_outlined),
                        onSelected: (value) {
                          final projectId = value == _clearProjectValue
                              ? null
                              : value;
                          _run(
                            () => widget.controller.batchSetTaskProject(
                              widget.selectedTasks,
                              projectId,
                            ),
                            BatchTaskAction.setProject,
                          );
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem<String>(
                            value: _clearProjectValue,
                            child: Text('清除主项目'),
                          ),
                          ...widget.controller.projects.map(
                            (project) => PopupMenuItem<String>(
                              value: project.id,
                              child: Text(project.title),
                            ),
                          ),
                        ],
                      ),
                      PopupMenuButton<String>(
                        enabled: !busy && hasSelection,
                        tooltip: '设置任务群',
                        icon: const Icon(Icons.account_tree_outlined),
                        onSelected: (value) =>
                            _setGroup(value == _clearGroupValue ? null : value),
                        itemBuilder: (context) => [
                          const PopupMenuItem<String>(
                            value: _clearGroupValue,
                            child: Text('移出任务群'),
                          ),
                          ...widget.controller.taskGroups.map(
                            (group) => PopupMenuItem<String>(
                              value: group.id,
                              child: Text(group.title),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        tooltip: '移入回收站',
                        onPressed: busy || !hasSelection ? null : _trash,
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _schedule(DateTime? date) async {
    await _run(
      () => widget.controller.batchScheduleTasks(widget.selectedTasks, date),
      BatchTaskAction.setDate,
    );
  }

  Future<void> _setGroup(String? groupId) async {
    if (groupId != null) {
      final occupied = widget.selectedTasks.where((task) {
        return widget.controller.relations.any(
          (relation) =>
              relation.data['relationType'] == 'taskGroupMember' &&
              relation.data['taskId'] == task.id &&
              relation.data['groupId'] != groupId &&
              relation.data['active'] != false,
        );
      }).length;
      if (occupied > 0 && mounted) {
        final confirmed = await showWorkbenchDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('替换任务群归属？'),
            content: Text('$occupied 项任务已有任务群归属，将移出原任务群。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('替换归属'),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
      }
    }
    await _run(
      () => widget.controller.batchSetTaskGroup(
        widget.selectedTasks,
        groupId,
        replaceExisting: true,
      ),
      BatchTaskAction.setTaskGroup,
    );
  }

  Future<void> _trash() async {
    final confirmed = await showWorkbenchDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移入回收站？'),
        content: Text('将选中的 ${widget.selectedTasks.length} 项任务移入回收站。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('移入回收站'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (busy) return;
    final controller = widget.controller;
    final selected = [...widget.selectedTasks];
    final messenger = ScaffoldMessenger.of(context);
    setState(() => busy = true);
    try {
      final result = await controller.batchMoveTasksToTrash(selected);
      if (!mounted) return;
      final failedIds = result.failures
          .map((failure) => failure.recordId)
          .toSet();
      final moved = selected
          .where((task) => !failedIds.contains(task.id))
          .toList(growable: false);
      final suffix = result.failed == 0 ? '' : '，失败 ${result.failed} 项';
      showWorkbenchSnackBar(
        context,
        SnackBar(
          content: Text(
            '${_actionMessage(BatchTaskAction.moveToTrash)} ${result.succeeded} 项$suffix',
          ),
          action: moved.isEmpty
              ? null
              : SnackBarAction(
                  label: '撤销',
                  onPressed: () async {
                    final restored = await controller.restoreRecords(moved);
                    messenger.showSnackBar(
                      SnackBar(content: Text('已撤销 ${restored.succeeded} 项')),
                    );
                  },
                ),
        ),
      );
      if (result.isSuccessful) {
        widget.onExit();
      } else {
        _retainFailedSelection(result);
      }
    } catch (error) {
      if (mounted) {
        showWorkbenchSnackBar(
          context,
          SnackBar(content: Text('批量操作失败：$error')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _retainFailedSelection(BatchOperationResult result) {
    final failedIds = result.failures
        .map((failure) => failure.recordId)
        .toSet();
    widget.onSelectionChanged(
      widget.selectedTasks
          .where((task) => failedIds.contains(task.id))
          .map((task) => task.id)
          .toSet(),
    );
  }

  String _actionMessage(BatchTaskAction action) => switch (action) {
    BatchTaskAction.setStatus => '已更新状态',
    BatchTaskAction.setDate => '已更新日期',
    BatchTaskAction.setProject => '已更新主项目',
    BatchTaskAction.setTaskGroup => '已更新任务群',
    BatchTaskAction.moveToTrash => '已移入回收站',
  };
}
