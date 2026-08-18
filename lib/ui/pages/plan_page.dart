import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../core/models/workspace_record.dart';
import '../../core/theme/app_theme.dart';
import '../../state/workbench_controller.dart';
import '../widgets/common.dart';
import '../widgets/quick_capture_sheet.dart';
import '../widgets/record_editor_dialog.dart';
import '../widgets/task_row.dart';
import 'calendar_page.dart';
import 'inbox_page.dart';

/// Task page views. Projects have their own first-class navigation entry.
enum PlanTab { all, inbox, week, groups }

class PlanPage extends StatelessWidget {
  const PlanPage({
    super.key,
    required this.controller,
    this.initialTab = PlanTab.all,
    this.showHeader = true,
    this.onOpenInbox,
    this.onOpenCalendar,
    this.onOpenProjects,
  });

  final WorkbenchController controller;
  final PlanTab initialTab;
  final bool showHeader;
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

class _AllTasksPage extends StatelessWidget {
  const _AllTasksPage({required this.controller});

  final WorkbenchController controller;

  @override
  Widget build(BuildContext context) {
    final tasks = [...controller.tasks]
      ..sort(
        (a, b) => (a.scheduledFor ?? a.dueAt ?? a.createdAt).compareTo(
          b.scheduledFor ?? b.dueAt ?? b.createdAt,
        ),
      );
    if (tasks.isEmpty) {
      return EmptyState(
        icon: Icons.checklist_outlined,
        title: '还没有任务',
        message: '把要完成的下一步写成一个可以验收的动作。',
        action: FilledButton.icon(
          onPressed: () => showQuickCapture(
            context,
            controller,
            initialKind: RecordKind.task,
          ),
          icon: const Icon(Icons.add_task),
          label: const Text('新建任务'),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 132),
      itemCount: tasks.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) =>
          TaskRow(task: tasks[index], controller: controller),
    );
  }
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 132),
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
      trailing: IconButton(
        onPressed: () => _addMember(group),
        tooltip: '添加任务',
        icon: const Icon(Icons.playlist_add),
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
              return ListTile(
                leading: CircleAvatar(
                  child: locked
                      ? const Icon(Icons.lock_outline, size: 18)
                      : Text('${index + 1}'),
                ),
                title: Text(task.title),
                subtitle: Text(locked ? '前置任务尚未通过' : task.status),
                trailing: Row(
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
                        onPressed: () =>
                            widget.controller.skipTaskAndContinueChain(task),
                        child: const Text('跳过并继续'),
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
    final title = TextEditingController();
    final timeLimit = TextEditingController();
    var sequential = false;
    final confirmed = await showWorkbenchDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('新建任务群'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: '名称'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: sequential,
                title: const Text('顺序任务链'),
                subtitle: const Text('关闭时为并行任务群'),
                onChanged: (value) => setDialogState(() => sequential = value),
              ),
              TextField(
                controller: timeLimit,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '总时限（分钟，可选）',
                  hintText: '每个子任务的 CTDP 配置保持独立',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      try {
        await widget.controller.createTaskGroup(
          title: title.text,
          sequential: sequential,
          timeLimitMinutes: int.tryParse(timeLimit.text.trim()),
        );
      } on FormatException catch (error) {
        if (mounted) {
          showWorkbenchSnackBar(
            context,
            SnackBar(content: Text(error.message)),
          );
        }
      }
    }
    title.dispose();
    timeLimit.dispose();
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
        content: TextField(
          controller: reason,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: '调整原因（必填）',
            hintText: '顺序变更会记录到任务群历史',
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
