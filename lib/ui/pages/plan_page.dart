import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/utils/formatters.dart';
import '../../core/models/workspace_record.dart';
import '../../core/theme/app_theme.dart';
import '../../state/workbench_controller.dart';
import '../widgets/common.dart';
import '../widgets/batch_task_toolbar.dart';
import '../widgets/quick_capture_sheet.dart';
import '../widgets/record_editor_dialog.dart';
import '../widgets/task_row.dart';
import '../widgets/task_group_editor_dialog.dart';
import '../widgets/task_hierarchy.dart';
import 'calendar_page.dart';
import 'inbox_page.dart';

/// Task page views. Projects have their own first-class navigation entry.
enum PlanTab { all, inbox, week, groups }

enum _MemberAction { moveUp, moveDown, skipAndContinue, remove }

class PlanPage extends StatelessWidget {
  const PlanPage({
    super.key,
    required this.controller,
    this.initialTab = PlanTab.all,
    this.showHeader = true,
    this.showTabs = true,
    this.onOpenInbox,
    this.onOpenCalendar,
    this.onOpenProjects,
  });

  final WorkbenchController controller;
  final PlanTab initialTab;
  final bool showHeader;
  final bool showTabs;
  // Kept for callers from the first shell API; tabs now handle these routes.
  final VoidCallback? onOpenInbox;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenProjects;

  @override
  Widget build(BuildContext context) {
    final now = controller.currentTime();
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    return Column(
      children: [
        if (showHeader)
          PageHeader(
            title: '任务',
            subtitle:
                '全部任务 · ${formatShortDate(weekStart)}—${formatShortDate(weekStart.add(const Duration(days: 6)))}',
          ),
        Expanded(
          child: DefaultTabController(
            length: PlanTab.values.length,
            initialIndex: initialTab.index,
            child: Column(
              children: [
                if (showTabs)
                  TabBar(
                    isScrollable: compact,
                    labelPadding: EdgeInsets.symmetric(
                      horizontal: compact ? 14 : 16,
                    ),
                    indicatorSize: TabBarIndicatorSize.label,
                    tabs: [
                      Tab(
                        text: '全部',
                        icon: compact
                            ? null
                            : const Icon(Icons.checklist_outlined),
                      ),
                      Tab(
                        text: '收件箱',
                        icon: compact ? null : const Icon(Icons.inbox_outlined),
                      ),
                      Tab(
                        text: '周视图',
                        icon: compact
                            ? null
                            : const Icon(Icons.calendar_view_week_outlined),
                      ),
                      Tab(
                        text: '任务群',
                        icon: compact
                            ? null
                            : const Icon(Icons.account_tree_outlined),
                      ),
                    ],
                  ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _AllTasksPage(controller: controller),
                      InboxPage(controller: controller, showHeader: false),
                      CalendarPage(controller: controller, showHeader: false),
                      _TaskGroupsPage(controller: controller),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AllTasksPage extends StatefulWidget {
  const _AllTasksPage({required this.controller});

  final WorkbenchController controller;

  @override
  State<_AllTasksPage> createState() => _AllTasksPageState();
}

class _AllTasksPageState extends State<_AllTasksPage> {
  final FocusNode _focusNode = FocusNode();
  final Set<String> _selectedIds = <String>{};
  bool _selectionMode = false;
  String? _selectionAnchorId;
  final Set<String> _collapsedTaskIds = <String>{};

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = [...widget.controller.tasks]
      ..sort(
        (a, b) => (a.scheduledFor ?? a.dueAt ?? a.createdAt).compareTo(
          b.scheduledFor ?? b.dueAt ?? b.createdAt,
        ),
      );
    final entries = buildTaskHierarchy(
      visibleTasks: tasks,
      allRecords: widget.controller.allRecords,
      collapsedIds: _collapsedTaskIds,
    );
    final selectedTasks = tasks
        .where((task) => _selectedIds.contains(task.id))
        .toList(growable: false);
    if (tasks.isEmpty) {
      return EmptyState(
        icon: Icons.checklist_outlined,
        title: '还没有任务',
        message: '把要完成的下一步写成一个可以验收的动作。',
        action: FilledButton.icon(
          onPressed: () => showQuickCapture(
            context,
            widget.controller,
            initialKind: RecordKind.task,
          ),
          icon: const Icon(Icons.add_task),
          label: const Text('新建任务'),
        ),
      );
    }
    return PopScope(
      canPop: !_selectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectionMode) _exitSelection();
      },
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.escape && _selectionMode) {
            _exitSelection();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.keyA &&
              HardwareKeyboard.instance.isControlPressed) {
            setState(() {
              _selectionMode = true;
              _selectedIds.addAll(tasks.map((task) => task.id));
              _selectionAnchorId = tasks.lastOrNull?.id;
            });
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Column(
          children: [
            if (_selectionMode)
              BatchTaskToolbar(
                controller: widget.controller,
                visibleTasks: tasks,
                selectedTasks: selectedTasks,
                onSelectionChanged: (ids) => setState(() {
                  _selectedIds
                    ..clear()
                    ..addAll(ids);
                }),
                onExit: _exitSelection,
              )
            else if (defaultTargetPlatform == TargetPlatform.windows)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: OutlinedButton.icon(
                    onPressed: _enterSelection,
                    icon: const Icon(Icons.library_add_check_outlined),
                    label: const Text('选择任务'),
                  ),
                ),
              ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  AppSpacing.bottomNavClearance,
                ),
                itemCount: entries.length,
                // 一项一张独立卡，卡间 8px 留白分组。
                //
                // 原先是裸行 + `Divider(height: 1)`。§8.2 对这个列表的要求是
                // 「分组之间留白，**无分隔线**」，§1 也写明「留白承担分组职责，
                // 线条只做次要提示」。收件箱页与项目看板早已是「一行一卡」，
                // 此处补齐后全应用只剩一种列表语言。
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return Card(
                    child: TaskRow(
                      task: entry.task,
                      controller: widget.controller,
                      hierarchyDepth: entry.depth,
                      hasChildren: entry.hasChildren,
                      expanded: entry.expanded,
                      relationInfo: entry.relation,
                      onToggleExpanded: () => setState(() {
                        entry.expanded
                            ? _collapsedTaskIds.add(entry.task.id)
                            : _collapsedTaskIds.remove(entry.task.id);
                      }),
                      selectionMode: _selectionMode,
                      selected: _selectedIds.contains(entry.task.id),
                      onSelectionChanged: (value) =>
                          _toggleSelection(entry.task.id, value, tasks),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleSelection(
    String id,
    bool value,
    List<WorkspaceRecord> visibleTasks,
  ) {
    setState(() {
      final anchorIndex = _selectionAnchorId == null
          ? -1
          : visibleTasks.indexWhere((task) => task.id == _selectionAnchorId);
      final currentIndex = visibleTasks.indexWhere((task) => task.id == id);
      if (value &&
          HardwareKeyboard.instance.isShiftPressed &&
          anchorIndex >= 0 &&
          currentIndex >= 0) {
        final start = anchorIndex < currentIndex ? anchorIndex : currentIndex;
        final end = anchorIndex < currentIndex ? currentIndex : anchorIndex;
        _selectedIds.addAll(
          visibleTasks.sublist(start, end + 1).map((task) => task.id),
        );
      } else if (value) {
        _selectedIds.add(id);
      } else {
        _selectedIds.remove(id);
      }
      _selectionMode = true;
      if (value) _selectionAnchorId = id;
    });
  }

  void _enterSelection() => setState(() => _selectionMode = true);

  void _exitSelection() => setState(() {
    _selectionMode = false;
    _selectionAnchorId = null;
    _selectedIds.clear();
  });
}

class _TaskGroupsPage extends StatefulWidget {
  const _TaskGroupsPage({required this.controller});

  final WorkbenchController controller;

  @override
  State<_TaskGroupsPage> createState() => _TaskGroupsPageState();
}

class _TaskGroupsPageState extends State<_TaskGroupsPage> {
  @override
  Widget build(BuildContext context) {
    final groups = widget.controller.taskGroups;
    final legacy = widget.controller.tasks
        .where((task) => task.ctdpIsGroup)
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        20,
        16,
        20,
        AppSpacing.bottomNavClearance,
      ),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _createGroup,
            icon: const Icon(Icons.add),
            label: const Text('新建任务群'),
          ),
        ),
        const SizedBox(height: 12),
        if (groups.isEmpty && legacy.isEmpty)
          const EmptyState(
            icon: Icons.account_tree_outlined,
            title: '还没有任务群',
            message: '任务群可并行执行；顺序链会锁定尚未到达的节点。',
          ),
        for (final group in groups) _groupTile(group),
        if (legacy.isNotEmpty) ...[
          const SectionHeading(title: '旧版 CTDP 嵌套组', scale: '兼容'),
          for (final group in legacy)
            ListTile(
              leading: const Icon(Icons.link_outlined),
              title: Text(group.title),
              subtitle: Text(
                '兼容模式 · ${widget.controller.ctdpChildren(group.id).length} 个单元',
              ),
              trailing: IconButton(
                tooltip: '编辑 CTDP 组',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => showRecordEditor(
                  context,
                  widget.controller,
                  kind: RecordKind.task,
                  record: group,
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _groupTile(WorkspaceRecord group) {
    final members = widget.controller.groupMembers(group.id);
    final sequential = group.data['mode'] == 'sequential';
    return ExpansionTile(
      leading: Icon(sequential ? Icons.linear_scale : Icons.hub_outlined),
      title: Text(group.title),
      subtitle: Text('${sequential ? '顺序任务链' : '并行任务群'} · ${members.length} 项'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => _addMember(group),
            tooltip: '添加任务',
            icon: const Icon(Icons.playlist_add),
          ),
          PopupMenuButton<String>(
            tooltip: '任务群操作',
            onSelected: (value) {
              if (value == 'edit') _editGroup(group);
              if (value == 'trash') _deleteGroup(group);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.edit_outlined),
                  title: Text('编辑任务群'),
                ),
              ),
              PopupMenuItem(
                value: 'trash',
                child: ListTile(
                  leading: Icon(Icons.delete_outline),
                  title: Text('移入回收站'),
                ),
              ),
            ],
          ),
        ],
      ),
      children: [
        if (members.isEmpty) const ListTile(title: Text('群内暂无任务')),
        for (var index = 0; index < members.length; index++)
          Builder(
            builder: (context) {
              final task = members[index];
              final locked = widget.controller.isTaskGroupMemberLocked(
                task,
                group,
              );
              final compact =
                  MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
              Future<void> edit() => showRecordEditor(
                context,
                widget.controller,
                kind: RecordKind.task,
                record: task,
              );
              return ListTile(
                leading: CircleAvatar(
                  child: locked
                      ? const Icon(Icons.lock_outline, size: 18)
                      : Text('${index + 1}'),
                ),
                title: Text(task.title),
                subtitle: Text(locked ? '前置任务尚未通过' : task.status),
                onTap: edit,
                trailing: compact
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: '编辑任务',
                            onPressed: edit,
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          PopupMenuButton<_MemberAction>(
                            tooltip: '更多操作',
                            itemBuilder: (context) => [
                              if (sequential)
                                PopupMenuItem(
                                  value: _MemberAction.moveUp,
                                  enabled: widget.controller
                                      .taskGroupMemberCanMove(
                                        task,
                                        group,
                                        index - 1,
                                      ),
                                  child: const Text('上移'),
                                ),
                              if (sequential)
                                PopupMenuItem(
                                  value: _MemberAction.moveDown,
                                  enabled: widget.controller
                                      .taskGroupMemberCanMove(
                                        task,
                                        group,
                                        index + 1,
                                      ),
                                  child: const Text('下移'),
                                ),
                              if (task.status == WorkStatus.failed)
                                const PopupMenuItem(
                                  value: _MemberAction.skipAndContinue,
                                  child: Text('跳过并继续'),
                                ),
                              const PopupMenuItem(
                                value: _MemberAction.remove,
                                child: Text('移出任务群'),
                              ),
                            ],
                            onSelected: (action) {
                              switch (action) {
                                case _MemberAction.moveUp:
                                  _moveMember(group, task, index - 1);
                                case _MemberAction.moveDown:
                                  _moveMember(group, task, index + 1);
                                case _MemberAction.skipAndContinue:
                                  widget.controller.skipTaskAndContinueChain(
                                    task,
                                  );
                                case _MemberAction.remove:
                                  _removeMember(group, task);
                              }
                            },
                          ),
                        ],
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (sequential) ...[
                            IconButton(
                              tooltip: '上移',
                              onPressed:
                                  widget.controller.taskGroupMemberCanMove(
                                    task,
                                    group,
                                    index - 1,
                                  )
                                  ? () => _moveMember(group, task, index - 1)
                                  : null,
                              icon: const Icon(Icons.arrow_upward),
                            ),
                            IconButton(
                              tooltip: '下移',
                              onPressed:
                                  widget.controller.taskGroupMemberCanMove(
                                    task,
                                    group,
                                    index + 1,
                                  )
                                  ? () => _moveMember(group, task, index + 1)
                                  : null,
                              icon: const Icon(Icons.arrow_downward),
                            ),
                          ],
                          if (task.status == WorkStatus.failed)
                            TextButton(
                              onPressed: () => widget.controller
                                  .skipTaskAndContinueChain(task),
                              child: const Text('跳过并继续'),
                            ),
                          IconButton(
                            tooltip: '编辑任务',
                            onPressed: edit,
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: '移出任务群',
                            onPressed: () => _removeMember(group, task),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                        ],
                      ),
              );
            },
          ),
      ],
    );
  }

  Future<void> _createGroup() async {
    await showTaskGroupEditor(context: context, controller: widget.controller);
  }

  Future<void> _editGroup(WorkspaceRecord group) async {
    await showTaskGroupEditor(
      context: context,
      controller: widget.controller,
      group: group,
    );
  }

  Future<void> _deleteGroup(WorkspaceRecord group) async {
    final confirmed = await showWorkbenchDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移入回收站？'),
        content: Text('任务群“${group.title}”及其成员关系会移入回收站，成员任务本身保留。'),
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
    if (confirmed != true) return;
    try {
      final result = await widget.controller.moveTaskGroupToTrash(group);
      if (mounted && result.isSuccessful) {
        showWorkbenchSnackBar(
          context,
          SnackBar(
            content: Text('任务群已移入回收站（${result.succeeded} 项）'),
            action: SnackBarAction(
              label: '撤销',
              onPressed: () async {
                final restored = await widget.controller.restoreRecords([
                  group,
                ]);
                if (!mounted || restored.failed == 0) return;
                showWorkbenchSnackBar(
                  context,
                  SnackBar(content: Text(restored.failures.first.message)),
                );
              },
            ),
          ),
        );
      } else if (mounted) {
        showWorkbenchSnackBar(
          context,
          SnackBar(content: Text('操作失败：${result.failures.first.message}')),
        );
      }
    } catch (error) {
      if (mounted) {
        showWorkbenchSnackBar(context, SnackBar(content: Text('操作失败：$error')));
      }
    }
  }

  Future<void> _removeMember(
    WorkspaceRecord group,
    WorkspaceRecord task,
  ) async {
    final confirmed = await showWorkbenchDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移出任务群？'),
        content: Text('“${task.title}”会保留，只解除与任务群的关系。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('移出'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.controller.removeTaskFromGroup(task: task, group: group);
    } on FormatException catch (error) {
      if (mounted) {
        showWorkbenchSnackBar(context, SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _moveMember(
    WorkspaceRecord group,
    WorkspaceRecord task,
    int targetIndex,
  ) async {
    final reason = TextEditingController();
    final confirmed = await showWorkbenchDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('调整任务链顺序'),
        content: ExternalField(
          label: '调整原因（必填）',
          child: TextField(
            controller: reason,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(hintText: '顺序变更会记录到任务群历史'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认调整'),
          ),
        ],
      ),
    );
    final value = reason.text.trim();
    reason.dispose();
    if (confirmed != true || value.isEmpty) return;
    try {
      await widget.controller.reorderTaskGroupMember(
        task: task,
        group: group,
        targetIndex: targetIndex,
        reason: value,
      );
    } on FormatException catch (error) {
      if (mounted) {
        showWorkbenchSnackBar(context, SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _addMember(WorkspaceRecord group) async {
    final candidates = widget.controller.tasks.where((task) {
      return !widget.controller.relations.any(
        (relation) =>
            relation.data['relationType'] == 'taskGroupMember' &&
            relation.data['taskId'] == task.id &&
            relation.data['active'] != false,
      );
    }).toList();
    final selected = await showWorkbenchDialog<WorkspaceRecord>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('添加现有任务'),
        children: [
          for (final task in candidates)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, task),
              child: Text(task.title),
            ),
        ],
      ),
    );
    if (selected == null) return;
    try {
      await widget.controller.addTaskToGroup(task: selected, group: group);
    } on FormatException catch (error) {
      if (mounted) {
        showWorkbenchSnackBar(context, SnackBar(content: Text(error.message)));
      }
    }
  }
}
