import 'package:flutter/material.dart';

import '../../core/models/workspace_record.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../state/workbench_controller.dart';
import '../widgets/common.dart';
import '../widgets/quick_capture_sheet.dart';
import '../widgets/record_editor_dialog.dart';
import '../widgets/task_row.dart';
import '../widgets/task_group_editor_dialog.dart';
import '../widgets/markdown_editor_dialog.dart';
import '../widgets/task_hierarchy.dart';
import '../widgets/solid_panel.dart';
import '../widgets/workbench_illustration.dart';

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
    this.onOpenReview,
  });

  final WorkbenchController controller;
  final bool showHeader;
  final ProjectDetailTab initialTab;
  final bool showTabs;
  final String? selectedProjectId;
  final ValueChanged<String>? onProjectSelected;
  final VoidCallback? onOpenGoals;
  final ValueChanged<WorkspaceRecord?>? onOpenReview;

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  String? selectedProjectId;
  ProjectViewMode mode = ProjectViewMode.list;
  String? expandedPanel;

  WorkbenchController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    selectedProjectId = widget.selectedProjectId;
    // Shell routes use the existing detail panels as stable anchors. This
    // keeps the public ProjectDetailTab routes distinct without changing the
    // project data model or duplicating the page implementation.
    expandedPanel = switch (widget.initialTab) {
      ProjectDetailTab.overview => 'tasks',
      ProjectDetailTab.tasks => 'tasks',
      ProjectDetailTab.groups => 'groups',
      ProjectDetailTab.milestones => 'milestones',
      ProjectDetailTab.notes => 'notes',
    };
  }

  @override
  void didUpdateWidget(covariant ProjectsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedProjectId != oldWidget.selectedProjectId) {
      selectedProjectId = widget.selectedProjectId;
    }
    if (widget.initialTab != oldWidget.initialTab) {
      expandedPanel = switch (widget.initialTab) {
        ProjectDetailTab.overview || ProjectDetailTab.tasks => 'tasks',
        ProjectDetailTab.groups => 'groups',
        ProjectDetailTab.milestones => 'milestones',
        ProjectDetailTab.notes => 'notes',
      };
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
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final desktop =
        WorkbenchViewport.sizeOf(context).width >=
        AppLayout.masterDetailMin * textScale.clamp(1, 1.5);
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
        Expanded(
          child: projects.isEmpty
              ? SingleChildScrollView(
                  padding: const EdgeInsets.only(
                    bottom: AppSpacing.bottomNavClearance,
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: AppSpacing.xl),
                      const WorkbenchIllustration(
                        kind: WorkbenchIllustrationKind.project,
                        width: 210,
                        height: 142,
                      ),
                      EmptyState(
                        icon: Icons.folder_open_outlined,
                        title: '还没有项目',
                        message: '项目用于组织相关任务、里程碑、笔记和资料链接。',
                        action: FilledButton(
                          onPressed: () => showRecordEditor(
                            context,
                            controller,
                            kind: RecordKind.project,
                          ),
                          child: const Text('创建第一个项目'),
                        ),
                      ),
                    ],
                  ),
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
              key: ValueKey(selected.id),
              initialValue: selected.id,
              isExpanded: true,
              decoration: const InputDecoration(),
              items: projects
                  .map(
                    (project) => DropdownMenuItem(
                      value: project.id,
                      child: Text(
                        project.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
      if (group.projectId == project.id) return true;
      if (group.projectId != null) return false;
      return controller
          .groupMembers(group.id)
          .any(
            (task) => controller
                .projectsForTask(task)
                .any((value) => value.id == project.id),
          );
    }).toList();
    final documents = controller.notes.where((record) {
      final ids =
          (record.data['relatedProjectIds'] as List<dynamic>? ?? const []).map(
            (value) => value.toString(),
          );
      return record.projectId == project.id || ids.contains(project.id);
    }).toList();
    final reviews = controller.periodReviews.where((record) {
      final ids =
          (record.data['relatedProjectIds'] as List<dynamic>? ?? const []).map(
            (value) => value.toString(),
          );
      return record.projectId == project.id || ids.contains(project.id);
    }).toList();
    Widget panel({
      required String id,
      required String title,
      required IconData icon,
      required int count,
      required Widget child,
    }) {
      return ExpansionTile(
        key: ValueKey('${project.id}-$id-${expandedPanel == id}'),
        initiallyExpanded: expandedPanel == id,
        onExpansionChanged: (value) => setState(() {
          expandedPanel = value ? id : null;
        }),
        leading: Icon(icon),
        title: Text(title),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$count'),
            const SizedBox(width: 8),
            Icon(expandedPanel == id ? Icons.expand_less : Icons.expand_more),
          ],
        ),
        children: [child],
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 600;
              final title = Column(
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
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              );
              final viewSwitch = SegmentedButton<ProjectViewMode>(
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
              );
              final compactViewSwitch = PopupMenuButton<ProjectViewMode>(
                tooltip: '切换项目视图',
                onSelected: (value) => setState(() => mode = value),
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: ProjectViewMode.list,
                    child: Text('清单视图'),
                  ),
                  PopupMenuItem(
                    value: ProjectViewMode.board,
                    child: Text('看板视图'),
                  ),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        mode == ProjectViewMode.list
                            ? Icons.view_list
                            : Icons.view_kanban_outlined,
                        size: AppIconSize.sm,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(mode == ProjectViewMode.list ? '清单视图' : '看板视图'),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              );
              final menu = PopupMenuButton<String>(
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
              );
              return compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        title,
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [compactViewSwitch, const Spacer(), menu],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: title),
                        viewSwitch,
                        menu,
                      ],
                    );
            },
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              20,
              12,
              20,
              AppSpacing.bottomNavClearance,
            ),
            children: [
              if (widget.initialTab != ProjectDetailTab.overview ||
                  expandedPanel != null) ...[
                _ProjectSectionSignal(
                  section:
                      expandedPanel ??
                      switch (widget.initialTab) {
                        ProjectDetailTab.overview => 'tasks',
                        ProjectDetailTab.tasks => 'tasks',
                        ProjectDetailTab.groups => 'groups',
                        ProjectDetailTab.milestones => 'milestones',
                        ProjectDetailTab.notes => 'notes',
                      },
                  tasks: tasks,
                  groups: groups,
                  milestones: milestones,
                  notes: documents,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              if (widget.initialTab == ProjectDetailTab.overview) ...[
                _ProjectOverview(
                  tasks: tasks,
                  milestones: milestones,
                  notes: documents,
                  onOpenTasks: () => setState(() => expandedPanel = 'tasks'),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              panel(
                id: 'tasks',
                title: '任务',
                icon: Icons.checklist_outlined,
                count: tasks.length,
                child: Column(
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Wrap(
                        spacing: 8,
                        children: [
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
                          FilledButton.icon(
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (mode == ProjectViewMode.list)
                      _TaskList(tasks: tasks, controller: controller)
                    else
                      _KanbanBoard(tasks: tasks, controller: controller),
                  ],
                ),
              ),
              panel(
                id: 'groups',
                title: '任务群',
                icon: Icons.account_tree_outlined,
                count: groups.length,
                child: Column(
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: FilledButton.icon(
                        onPressed: () => showTaskGroupEditor(
                          context: context,
                          controller: controller,
                          initialProjectId: project.id,
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('新建任务群'),
                      ),
                    ),
                    if (groups.isEmpty)
                      const EmptyState(
                        icon: Icons.account_tree_outlined,
                        title: '没有关联任务群',
                        message: '从此处新建或编辑当前项目的任务群。',
                      )
                    else
                      for (final group in groups)
                        _ProjectGroupCard(controller: controller, group: group),
                  ],
                ),
              ),
              panel(
                id: 'milestones',
                title: '里程碑',
                icon: Icons.flag_outlined,
                count: milestones.length,
                child: Column(
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: FilledButton.icon(
                        onPressed: () => showRecordEditor(
                          context,
                          controller,
                          kind: RecordKind.milestone,
                          initialProjectId: project.id,
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('新增里程碑'),
                      ),
                    ),
                    if (milestones.isEmpty)
                      const EmptyState(
                        icon: Icons.flag_outlined,
                        title: '还没有里程碑',
                        message: '为项目标记下一次需要核对的成果或日期。',
                      ),
                    for (final milestone in milestones)
                      Card(
                        child: ListTile(
                          leading: Icon(
                            milestone.isDone
                                ? Icons.check_circle
                                : Icons.flag_outlined,
                            color: milestone.isDone
                                ? context.tokens.reward
                                : milestone.dueAt != null &&
                                      milestone.dueAt!.isBefore(
                                        controller.currentTime(),
                                      )
                                ? context.tokens.signal
                                : Theme.of(context).colorScheme.primary,
                          ),
                          title: Text(milestone.title),
                          subtitle: Text(
                            milestone.isDone
                                ? '已达成${milestone.dueAt == null ? '' : ' · ${formatShortDate(milestone.dueAt!)}'}'
                                : milestone.dueAt == null
                                ? '待到达 · 未设置日期'
                                : '${milestone.dueAt!.isBefore(controller.currentTime()) ? '已逾期' : '待到达'} · ${formatShortDate(milestone.dueAt!)}',
                          ),
                          trailing: IconButton(
                            tooltip: '编辑里程碑',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => showRecordEditor(
                              context,
                              controller,
                              kind: RecordKind.milestone,
                              record: milestone,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              panel(
                id: 'notes',
                title: '笔记',
                icon: Icons.note_alt_outlined,
                count: documents.length,
                child: Column(
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: FilledButton.icon(
                        onPressed: () => showMarkdownNoteEditor(
                          context,
                          controller,
                          initialProjectId: project.id,
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('新增笔记'),
                      ),
                    ),
                    if (documents.isEmpty)
                      const EmptyState(
                        icon: Icons.note_alt_outlined,
                        title: '没有关联笔记',
                        message: '从此处新建一篇属于当前项目的笔记。',
                      ),
                    for (final document in documents)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.note_alt_outlined),
                          title: Text(document.title),
                          subtitle: Text(
                            document.body.isEmpty
                                ? '更新于 ${formatShortDate(document.updatedAt)}'
                                : '${document.body}\n更新于 ${formatShortDate(document.updatedAt)}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => showMarkdownNoteEditor(
                            context,
                            controller,
                            note: document,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              panel(
                id: 'reviews',
                title: '回顾',
                icon: Icons.insights_outlined,
                count: reviews.length,
                child: Column(
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: FilledButton.icon(
                        onPressed: widget.onOpenReview == null
                            ? null
                            : () => widget.onOpenReview!(null),
                        icon: const Icon(Icons.add),
                        label: const Text('打开当前回顾'),
                      ),
                    ),
                    if (reviews.isEmpty)
                      const EmptyState(
                        icon: Icons.insights_outlined,
                        title: '没有关联回顾',
                        message: '打开当前回顾后，在关联设置中选择此项目。',
                      ),
                    for (final review in reviews)
                      ListTile(
                        leading: const Icon(Icons.insights_outlined),
                        title: Text(review.title),
                        subtitle: Text(
                          '${switch (review.data['periodType']) {
                            'weekly' => '周回顾',
                            'monthly' => '月回顾',
                            _ => '日回顾',
                          }} · ${review.data['periodKey']?.toString() ?? formatShortDate(review.updatedAt)}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: widget.onOpenReview == null
                            ? null
                            : () => widget.onOpenReview!(review),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
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

class _ProjectGroupCard extends StatelessWidget {
  const _ProjectGroupCard({required this.controller, required this.group});

  final WorkbenchController controller;
  final WorkspaceRecord group;

  @override
  Widget build(BuildContext context) {
    final members = controller.groupMembers(group.id);
    final sequential = group.data['mode'] == 'sequential';
    final completed = members.where((task) => task.isDone).length;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: PageStorageKey('project-group-${group.id}'),
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(group.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${sequential ? '顺序链' : '并行群'} · 已完成 $completed/${members.length}'
              '${group.projectId == null ? ' · 根据成员推断' : ''}',
            ),
            const SizedBox(height: AppSpacing.xs),
            LinearProgressIndicator(
              value: members.isEmpty ? 0 : completed / members.length,
              minHeight: 5,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              backgroundColor: context.tokens.subtle,
            ),
          ],
        ),
        trailing: IconButton(
          tooltip: '编辑任务群',
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => showTaskGroupEditor(
            context: context,
            controller: controller,
            group: group,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                sequential ? '顺序依赖 · 完成前一项后解锁下一项' : '并行执行 · 每项任务可独立推进',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          if (members.isEmpty)
            const ListTile(title: Text('群内暂无任务'))
          else
            for (var index = 0; index < members.length; index++)
              Builder(
                builder: (context) {
                  final task = members[index];
                  final locked = controller.isTaskGroupMemberLocked(
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
                    subtitle: Text(
                      locked
                          ? '第 ${index + 1} 项 · 前置任务尚未通过'
                          : '第 ${index + 1} 项 · ${task.status}',
                    ),
                    trailing: const Icon(Icons.open_in_new_outlined),
                    onTap: () => showRecordEditor(
                      context,
                      controller,
                      kind: RecordKind.task,
                      record: task,
                    ),
                  );
                },
              ),
        ],
      ),
    );
  }
}

/// Each project subpage keeps a distinct live-data cue above its work area.
class _ProjectSectionSignal extends StatelessWidget {
  const _ProjectSectionSignal({
    required this.section,
    required this.tasks,
    required this.groups,
    required this.milestones,
    required this.notes,
  });

  final String section;
  final List<WorkspaceRecord> tasks;
  final List<WorkspaceRecord> groups;
  final List<WorkspaceRecord> milestones;
  final List<WorkspaceRecord> notes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final doneTasks = tasks.where((task) => task.isDone).length;
    final doingTasks = tasks
        .where((task) => task.status == WorkStatus.doing)
        .length;
    final pendingTasks = tasks
        .where(
          (task) =>
              !WorkStatus.terminal.contains(task.status) &&
              task.status != WorkStatus.doing,
        )
        .length;
    final doneMilestones = milestones.where((item) => item.isDone).length;
    final pendingMilestones = milestones.where((item) => !item.isDone).toList()
      ..sort((a, b) {
        final aDate = a.dueAt;
        final bDate = b.dueAt;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return aDate.compareTo(bDate);
      });
    final recentNotes = [...notes]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    late final IconData icon;
    late final String title;
    late final String description;
    late final List<Widget> facts;
    switch (section) {
      case 'groups':
        final sequential = groups
            .where((group) => group.data['mode'] == 'sequential')
            .length;
        icon = Icons.account_tree_outlined;
        title = '任务群关系';
        description = groups.isEmpty
            ? '把有依赖的动作串成顺序链，独立动作组成并行群。'
            : '关系决定下一步是否可以开始，展开任务群可查看成员。';
        facts = [
          _ProjectSignalFact(
            label: '顺序链',
            value: sequential,
            icon: Icons.linear_scale,
          ),
          _ProjectSignalFact(
            label: '并行群',
            value: groups.length - sequential,
            icon: Icons.hub_outlined,
          ),
        ];
      case 'milestones':
        icon = Icons.flag_outlined;
        title = '成果里程碑';
        description = pendingMilestones.isEmpty
            ? '尚无待到达的里程碑。'
            : '下一节点：${pendingMilestones.first.title}'
                  '${pendingMilestones.first.dueAt == null ? '' : ' · ${formatShortDate(pendingMilestones.first.dueAt!)}'}';
        facts = [
          _ProjectSignalFact(
            label: '待到达',
            value: pendingMilestones.length,
            icon: Icons.outlined_flag,
          ),
          _ProjectSignalFact(
            label: '已达成',
            value: doneMilestones,
            icon: Icons.verified_outlined,
            color: tokens.reward,
          ),
        ];
      case 'notes':
        icon = Icons.auto_stories_outlined;
        title = '项目知识';
        description = recentNotes.isEmpty
            ? '把决策、材料和发现放在项目的同一处。'
            : '最近更新：${recentNotes.first.title}';
        facts = [
          _ProjectSignalFact(
            label: '关联笔记',
            value: notes.length,
            icon: Icons.note_alt_outlined,
          ),
          if (recentNotes.isNotEmpty)
            Text(
              '更新于 ${formatShortDate(recentNotes.first.updatedAt)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: tokens.mutedText,
              ),
            ),
        ];
      default:
        icon = Icons.route_outlined;
        title = '任务推进管线';
        description = tasks.isEmpty
            ? '先写下可以行动的一步，项目便有了推进路径。'
            : '从待办到完成，清单和看板显示同一组任务。';
        facts = [
          _ProjectSignalFact(
            label: '待推进',
            value: pendingTasks,
            icon: Icons.pending_actions_outlined,
          ),
          _ProjectSignalFact(
            label: '进行中',
            value: doingTasks,
            icon: Icons.play_circle_outline,
          ),
          _ProjectSignalFact(
            label: '已完成',
            value: doneTasks,
            icon: Icons.check_circle_outline,
            color: theme.colorScheme.primary,
          ),
        ];
    }
    return SolidPanel(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: tokens.mutedText),
          ),
          const SizedBox(height: AppSpacing.md),
          if (section == 'tasks' && tasks.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: doneTasks / tasks.length,
                minHeight: 7,
                backgroundColor: tokens.subtle,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: facts,
          ),
        ],
      ),
    );
  }
}

class _ProjectSignalFact extends StatelessWidget {
  const _ProjectSignalFact({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? context.tokens.mutedText;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppIconSize.xs, color: foreground),
        const SizedBox(width: AppSpacing.xs),
        Text(
          '$label $value',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: foreground,
            fontFamily: AppFonts.numeric,
          ),
        ),
      ],
    );
  }
}

class _ProjectOverview extends StatelessWidget {
  const _ProjectOverview({
    required this.tasks,
    required this.milestones,
    required this.notes,
    required this.onOpenTasks,
  });

  final List<WorkspaceRecord> tasks;
  final List<WorkspaceRecord> milestones;
  final List<WorkspaceRecord> notes;
  final VoidCallback onOpenTasks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final completed = tasks.where((task) => task.isDone).length;
    final progress = tasks.isEmpty ? 0.0 : completed / tasks.length;
    return SolidPanel(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 500;
              final showArt = MediaQuery.textScalerOf(context).scale(1) < 1.6;
              return Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [tokens.heroStart, tokens.heroEnd],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(tokens.cardRadius),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('项目进展', style: theme.textTheme.titleMedium),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            tasks.isEmpty
                                ? '从第一步开始搭起项目路径'
                                : '已完成 $completed / ${tasks.length} 项任务',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: tokens.mutedText,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          TextButton.icon(
                            onPressed: onOpenTasks,
                            icon: const Icon(
                              Icons.arrow_forward,
                              size: AppIconSize.xs,
                            ),
                            label: const Text('查看任务'),
                          ),
                        ],
                      ),
                    ),
                    if (showArt) ...[
                      const SizedBox(width: AppSpacing.sm),
                      WorkbenchIllustration(
                        kind: WorkbenchIllustrationKind.project,
                        width: compact ? 92 : 180,
                        height: compact ? 94 : 130,
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          Semantics(
            label: '任务进度：已完成 $completed 项，共 ${tasks.length} 项',
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              backgroundColor: tokens.subtle,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xl,
            runSpacing: AppSpacing.sm,
            children: [
              _ProjectOverviewCount(label: '任务', value: tasks.length),
              _ProjectOverviewCount(label: '已完成', value: completed),
              _ProjectOverviewCount(label: '里程碑', value: milestones.length),
              _ProjectOverviewCount(label: '笔记', value: notes.length),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProjectOverviewCount extends StatelessWidget {
  const _ProjectOverviewCount({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$label $value',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: theme.textTheme.titleMedium?.copyWith(
              fontFamily: AppFonts.numeric,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.tokens.mutedText,
            ),
          ),
        ],
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
          Builder(
            builder: (context) {
              final tasks = controller.projectTasks(project.id);
              final done = tasks.where((task) => task.isDone).length;
              return ListTile(
                selected: project.id == selectedId,
                selectedTileColor: Theme.of(
                  context,
                ).colorScheme.primaryContainer,
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
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tasks.isEmpty ? '尚未添加任务' : '已完成 $done/${tasks.length} 项',
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    LinearProgressIndicator(
                      value: tasks.isEmpty ? 0 : done / tasks.length,
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      backgroundColor: context.tokens.subtle,
                    ),
                  ],
                ),
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
              );
            },
          ),
      ],
    );
  }
}

class _TaskList extends StatefulWidget {
  const _TaskList({required this.tasks, required this.controller});

  final List<WorkspaceRecord> tasks;
  final WorkbenchController controller;

  @override
  State<_TaskList> createState() => _TaskListState();
}

class _TaskListState extends State<_TaskList> {
  final Set<String> _collapsedTaskIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final tasks = widget.tasks;
    final controller = widget.controller;
    if (tasks.isEmpty) {
      return const EmptyState(
        icon: Icons.check_box_outlined,
        title: '项目还没有任务',
        message: '新增一个可执行任务，项目才会开始向前移动。',
      );
    }
    final entries = buildTaskHierarchy(
      visibleTasks: tasks,
      allRecords: controller.allRecords,
      collapsedIds: _collapsedTaskIds,
    );
    // 一行一卡：与收件箱页、项目看板、今日页同一种列表语言。
    // 旧形态是「一张 Card 装多行 + 行间 Divider」，§8.2 与 §1 都要求
    // 用留白分组、不用分隔线。
    return Column(
      children: [
        for (var index = 0; index < entries.length; index++) ...[
          Card(
            child: TaskRow(
              task: entries[index].task,
              controller: controller,
              showProject: false,
              hierarchyDepth: entries[index].depth,
              hasChildren: entries[index].hasChildren,
              expanded: entries[index].expanded,
              relationInfo: entries[index].relation,
              onToggleExpanded: () => setState(() {
                entries[index].expanded
                    ? _collapsedTaskIds.add(entries[index].task.id)
                    : _collapsedTaskIds.remove(entries[index].task.id);
              }),
            ),
          ),
          if (index != entries.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _KanbanBoard extends StatelessWidget {
  const _KanbanBoard({required this.tasks, required this.controller});

  final List<WorkspaceRecord> tasks;
  final WorkbenchController controller;

  @override
  Widget build(BuildContext context) {
    final narrow =
        WorkbenchViewport.sizeOf(context).width < AppBreakpoints.compact;
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
