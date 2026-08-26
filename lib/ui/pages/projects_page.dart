import 'package:flutter/material.dart';

import '../../core/models/workspace_record.dart';
import '../../core/theme/app_theme.dart';
import '../../state/workbench_controller.dart';
import '../widgets/common.dart';
import '../widgets/quick_capture_sheet.dart';
import '../widgets/record_editor_dialog.dart';
import '../widgets/task_row.dart';

enum ProjectViewMode { list, board }

enum ProjectDetailTab { overview, tasks, groups, milestones, notes }

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({
    super.key,
    required this.controller,
    this.showHeader = true,
    this.initialTab = ProjectDetailTab.overview,
    this.showTabs = true,
    this.selectedProjectId,
    this.onProjectSelected,
    this.onOpenGoals,
  });

  final WorkbenchController controller;
  final bool showHeader;
  final ProjectDetailTab initialTab;
  final bool showTabs;
  final String? selectedProjectId;
  final ValueChanged<String>? onProjectSelected;
  final VoidCallback? onOpenGoals;

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  String? selectedProjectId;
  ProjectViewMode mode = ProjectViewMode.list;

  WorkbenchController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    selectedProjectId = widget.selectedProjectId;
  }

  @override
  void didUpdateWidget(covariant ProjectsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedProjectId != oldWidget.selectedProjectId) {
      selectedProjectId = widget.selectedProjectId;
    }
  }

  void _selectProject(String? value) {
    if (value == null) return;
    setState(() => selectedProjectId = value);
    widget.onProjectSelected?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final projects = controller.projects;
    final selected =
        projects
            .where((project) => project.id == selectedProjectId)
            .firstOrNull ??
        projects.firstOrNull;
    final desktop = MediaQuery.sizeOf(context).width >= AppBreakpoints.expanded;
    return Column(
      children: [
        if (widget.showHeader)
          PageHeader(
            title: '项目',
            subtitle: '用清单推进，用看板看清当前状态',
            actions: [
              FilledButton.icon(
                onPressed: () => showRecordEditor(
                  context,
                  controller,
                  kind: RecordKind.project,
                ),
                icon: const Icon(Icons.create_new_folder_outlined),
                label: const Text('新建项目'),
              ),
            ],
          ),
        if (!widget.showHeader)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: () => showRecordEditor(
                  context,
                  controller,
                  kind: RecordKind.project,
                ),
                tooltip: '新建项目',
                icon: const Icon(Icons.create_new_folder_outlined),
              ),
            ),
          ),
        if (widget.showHeader) const Divider(),
        Expanded(
          child: projects.isEmpty
              ? EmptyState(
                  icon: Icons.folder_open_outlined,
                  title: '还没有项目',
                  message: '项目用于组织相关任务、里程碑、笔记和资料链接。',
                  action: widget.showHeader
                      ? FilledButton(
                          onPressed: () => showRecordEditor(
                            context,
                            controller,
                            kind: RecordKind.project,
                          ),
                          child: const Text('创建第一个项目'),
                        )
                      : null,
                )
              : desktop
              ? Row(
                  children: [
                    SizedBox(
                      width: 260,
                      child: _ProjectList(
                        projects: projects,
                        controller: controller,
                        selectedId: selected!.id,
                        onSelected: _selectProject,
                        onEdit: _editProject,
                        onDelete: _moveProjectToTrash,
                      ),
                    ),
                    const VerticalDivider(),
                    Expanded(child: _projectDetail(context, selected)),
                  ],
                )
              : _mobileBody(context, projects, selected!),
        ),
      ],
    );
  }

  Widget _mobileBody(
    BuildContext context,
    List<WorkspaceRecord> projects,
    WorkspaceRecord selected,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: ExternalField(
            label: '当前项目',
            child: DropdownButtonFormField<String>(
              initialValue: selected.id,
              decoration: const InputDecoration(),
              items: projects
                  .map(
                    (project) => DropdownMenuItem(
                      value: project.id,
                      child: Text(project.title),
                    ),
                  )
                  .toList(),
              onChanged: _selectProject,
            ),
          ),
        ),
        Expanded(child: _projectDetail(context, selected)),
      ],
    );
  }

  Widget _projectDetail(BuildContext context, WorkspaceRecord project) {
    final tasks = controller.projectTasks(project.id);
    final milestones = controller
        .recordsOf(RecordKind.milestone)
        .where((record) => record.projectId == project.id)
        .toList();
    final groups = controller.taskGroups.where((group) {
      return controller
          .groupMembers(group.id)
          .any(
            (task) => controller
                .projectsForTask(task)
                .any((value) => value.id == project.id),
          );
    }).toList();
    final documents = [...controller.notes, ...controller.diaries].where((
      record,
    ) {
      final ids =
          (record.data['relatedProjectIds'] as List<dynamic>? ?? const []).map(
            (value) => value.toString(),
          );
      return record.projectId == project.id || ids.contains(project.id);
    }).toList();
    return DefaultTabController(
      length: ProjectDetailTab.values.length,
      initialIndex: widget.initialTab.index,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (project.body.isNotEmpty)
                        Text(
                          project.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                    ],
                  ),
                ),
                SegmentedButton<ProjectViewMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: ProjectViewMode.list,
                      icon: Icon(Icons.view_list),
                      label: Text('清单'),
                    ),
                    ButtonSegment(
                      value: ProjectViewMode.board,
                      icon: Icon(Icons.view_kanban_outlined),
                      label: Text('看板'),
                    ),
                  ],
                  selected: {mode},
                  onSelectionChanged: (value) =>
                      setState(() => mode = value.first),
                ),
                PopupMenuButton<String>(
                  tooltip: '项目操作',
                  onSelected: (value) {
                    if (value == 'edit') _editProject(project);
                    if (value == 'trash') _moveProjectToTrash(project);
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('编辑项目'),
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
          ),
          if (widget.showTabs)
            const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: '概览'),
                Tab(text: '任务'),
                Tab(text: '任务群'),
                Tab(text: '里程碑'),
                Tab(text: '笔记与回顾'),
              ],
            ),
          Expanded(
            child: TabBarView(
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 132),
                  children: [
                    ListTile(
                      leading: const Icon(Icons.checklist_outlined),
                      title: const Text('任务'),
                      trailing: Text('${tasks.length}'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.account_tree_outlined),
                      title: const Text('任务群'),
                      trailing: Text('${groups.length}'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.flag_outlined),
                      title: const Text('里程碑'),
                      trailing: Text('${milestones.length}'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.note_alt_outlined),
                      title: const Text('笔记与回顾'),
                      trailing: Text('${documents.length}'),
                    ),
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 132),
                  children: [
                    SectionHeading(
                      title: '任务',
                      trailing: TextButton.icon(
                        onPressed: () => showQuickCapture(
                          context,
                          controller,
                          initialKind: RecordKind.task,
                          initialProjectId: project.id,
                          initialStatus: WorkStatus.todo,
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('新增任务'),
                      ),
                    ),
                    if (mode == ProjectViewMode.list)
                      _TaskList(tasks: tasks, controller: controller)
                    else
                      _KanbanBoard(tasks: tasks, controller: controller),
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 132),
                  children: [
                    if (groups.isEmpty)
                      const EmptyState(
                        icon: Icons.account_tree_outlined,
                        title: '没有关联任务群',
                        message: '任务群中任意成员关联此项目后会显示在这里。',
                      ),
                    for (final group in groups)
                      ListTile(
                        leading: const Icon(Icons.account_tree_outlined),
                        title: Text(group.title),
                        subtitle: Text(
                          '${controller.groupMembers(group.id).length} 项任务',
                        ),
                      ),
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 132),
                  children: [
                    SectionHeading(
                      title: '关联里程碑',
                      trailing: TextButton.icon(
                        onPressed: widget.onOpenGoals,
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('前往目标'),
                      ),
                    ),
                    if (milestones.isEmpty)
                      Text(
                        '尚未设置里程碑。',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      )
                    else
                      for (final milestone in milestones)
                        ListTile(
                          leading: Icon(
                            milestone.isDone
                                ? Icons.check_circle
                                : Icons.flag_outlined,
                          ),
                          title: Text(milestone.title),
                          subtitle: Text(
                            [
                              controller.goals
                                      .where(
                                        (goal) => goal.id == milestone.parentId,
                                      )
                                      .firstOrNull
                                      ?.title ??
                                  '未关联目标',
                              if (milestone.dueAt != null)
                                '截止 ${milestone.dueAt!.year}-${milestone.dueAt!.month.toString().padLeft(2, '0')}-${milestone.dueAt!.day.toString().padLeft(2, '0')}',
                            ].join(' · '),
                          ),
                          trailing: Text(milestone.isDone ? '已完成' : '进行中'),
                          onTap: widget.onOpenGoals,
                        ),
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 132),
                  children: [
                    if (documents.isEmpty)
                      const EmptyState(
                        icon: Icons.note_alt_outlined,
                        title: '没有关联笔记或回顾',
                        message: '在笔记或回顾的关联选项中选择此项目。',
                      ),
                    for (final document in documents)
                      ListTile(
                        leading: Icon(
                          document.data['recordType'] == 'periodReview'
                              ? Icons.insights_outlined
                              : Icons.note_alt_outlined,
                        ),
                        title: Text(document.title),
                        subtitle: Text(
                          document.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editProject(WorkspaceRecord project) async {
    final updated = await showRecordEditor(
      context,
      controller,
      kind: RecordKind.project,
      record: project,
    );
    if (updated != null && mounted) {
      setState(() => selectedProjectId = updated.id);
    }
  }

  Future<void> _moveProjectToTrash(WorkspaceRecord project) async {
    final counts = controller.projectAssociationCounts(project);
    final confirmed =
        await showWorkbenchDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('将项目移入回收站？'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('“${project.title}”将被移入回收站。'),
                const SizedBox(height: 12),
                Text(
                  '关联内容：${counts['tasks']} 个任务、${counts['groups']} 个任务群、'
                  '${counts['notes']} 篇笔记、${counts['reviews']} 篇回顾、'
                  '${counts['milestones']} 个里程碑。',
                ),
                const SizedBox(height: 8),
                const Text('关联内容不会被删除或解除关系；恢复项目后会自动恢复正常显示。'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.delete_outline),
                label: const Text('移入回收站'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    final remaining = controller.projects
        .where((value) => value.id != project.id)
        .toList();
    await controller.moveToTrash(project);
    if (!mounted) return;
    setState(() => selectedProjectId = remaining.firstOrNull?.id);
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('项目已移入回收站，关联内容仍被保留。'),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () async {
            await controller.restoreFromTrash(project);
            if (mounted) setState(() => selectedProjectId = project.id);
          },
        ),
      ),
    );
  }
}

class _ProjectList extends StatelessWidget {
  const _ProjectList({
    required this.projects,
    required this.controller,
    required this.selectedId,
    required this.onSelected,
    required this.onEdit,
    required this.onDelete,
  });

  final List<WorkspaceRecord> projects;
  final WorkbenchController controller;
  final String selectedId;
  final ValueChanged<String> onSelected;
  final ValueChanged<WorkspaceRecord> onEdit;
  final ValueChanged<WorkspaceRecord> onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      children: [
        for (final project in projects)
          ListTile(
            selected: project.id == selectedId,
            selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            leading: Icon(
              project.favorite
                  ? Icons.folder_special_outlined
                  : Icons.folder_outlined,
            ),
            title: Text(
              project.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text('${controller.projectTasks(project.id).length} 项任务'),
            trailing: PopupMenuButton<String>(
              tooltip: '项目操作',
              onSelected: (value) {
                if (value == 'edit') onEdit(project);
                if (value == 'trash') onDelete(project);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('编辑')),
                PopupMenuItem(value: 'trash', child: Text('移入回收站')),
              ],
            ),
            onTap: () => onSelected(project.id),
          ),
      ],
    );
  }
}

class _TaskList extends StatelessWidget {
  const _TaskList({required this.tasks, required this.controller});

  final List<WorkspaceRecord> tasks;
  final WorkbenchController controller;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const EmptyState(
        icon: Icons.check_box_outlined,
        title: '项目还没有任务',
        message: '新增一个可执行任务，项目才会开始向前移动。',
      );
    }
    return Card(
      child: Column(
        children: [
          for (var index = 0; index < tasks.length; index++) ...[
            Padding(
              padding: EdgeInsets.only(
                left: tasks[index].parentId == null ? 0 : 24,
              ),
              child: TaskRow(
                task: tasks[index],
                controller: controller,
                showProject: false,
              ),
            ),
            if (index != tasks.length - 1) const Divider(),
          ],
        ],
      ),
    );
  }
}

class _KanbanBoard extends StatelessWidget {
  const _KanbanBoard({required this.tasks, required this.controller});

  final List<WorkspaceRecord> tasks;
  final WorkbenchController controller;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    final columns = [
      (WorkStatus.todo, '待办'),
      (WorkStatus.doing, '进行中'),
      (WorkStatus.done, '已完成'),
    ];
    final children = columns
        .map(
          (entry) => SizedBox(
            width: narrow ? double.infinity : 300,
            child: _KanbanColumn(
              status: entry.$1,
              label: entry.$2,
              tasks: tasks.where((task) {
                final normalized = task.status == WorkStatus.inbox
                    ? WorkStatus.todo
                    : task.status;
                return normalized == entry.$1;
              }).toList(),
              controller: controller,
            ),
          ),
        )
        .toList();
    return narrow
        ? Column(
            children: children
                .map(
                  (child) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: child,
                  ),
                )
                .toList(),
          )
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children
                  .map(
                    (child) => Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: child,
                    ),
                  )
                  .toList(),
            ),
          );
  }
}

class _KanbanColumn extends StatelessWidget {
  const _KanbanColumn({
    required this.status,
    required this.label,
    required this.tasks,
    required this.controller,
  });

  final String status;
  final String label;
  final List<WorkspaceRecord> tasks;
  final WorkbenchController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DragTarget<WorkspaceRecord>(
      onWillAcceptWithDetails: (details) => details.data.status != status,
      onAcceptWithDetails: (details) =>
          controller.setTaskStatus(details.data, status),
      builder: (context, candidates, _) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: candidates.isEmpty
                ? scheme.surfaceContainerHighest
                : scheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    StatusPill(label: '${tasks.length}'),
                  ],
                ),
                const SizedBox(height: 10),
                if (tasks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      '拖动任务到这里',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  )
                else
                  ...tasks.map(
                    (task) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: LongPressDraggable<WorkspaceRecord>(
                        data: task,
                        feedback: Material(
                          elevation: 8,
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          child: SizedBox(
                            width: 260,
                            child: Card(
                              child: TaskRow(
                                task: task,
                                controller: controller,
                                dense: true,
                              ),
                            ),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.35,
                          child: Card(
                            child: TaskRow(
                              task: task,
                              controller: controller,
                              dense: true,
                            ),
                          ),
                        ),
                        child: Card(
                          child: TaskRow(
                            task: task,
                            controller: controller,
                            dense: true,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
