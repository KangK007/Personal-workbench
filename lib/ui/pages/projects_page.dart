import 'dart:async';

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
import '../widgets/jade_botanical_edge.dart';
import '../widgets/jade_icon.dart';
import '../widgets/task_hierarchy.dart';
import '../widgets/task_hierarchy_navigation.dart';
import '../widgets/solid_panel.dart';
import '../widgets/project_knowledge_section.dart';
import '../widgets/project_icons.dart';

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

class _ProjectsPageState extends State<ProjectsPage>
    with SingleTickerProviderStateMixin {
  String? selectedProjectId;
  ProjectViewMode mode = ProjectViewMode.list;
  String? expandedPanel;
  String? _highlightedGroupId;
  String? _groupMoveTargetId;
  String? _groupRevealTaskId;
  int _groupRevealVersion = 0;
  final Map<String, GlobalKey> _groupCardKeys = {};
  final Map<String, GlobalKey> _groupRowKeys = {};
  Timer? _groupHighlightTimer;
  late final AnimationController _projectSwitchOpacity = AnimationController(
    vsync: this,
    duration: AppMotion.standard,
    value: 1,
  );

  WorkbenchController get controller => widget.controller;

  @override
  void dispose() {
    _groupHighlightTimer?.cancel();
    _projectSwitchOpacity.dispose();
    super.dispose();
  }

  void _revealGroup(String groupId, String taskId) {
    _groupHighlightTimer?.cancel();
    setState(() {
      _highlightedGroupId = groupId;
      _groupRevealTaskId = taskId;
      _groupRevealVersion++;
    });
    _groupHighlightTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _highlightedGroupId = null);
    });
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!reducedMotion) await Future<void>.delayed(AppMotion.standard);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final cardContext =
          _groupRowKeys[groupId]?.currentContext ??
          _groupCardKeys[groupId]?.currentContext;
      if (cardContext == null || !cardContext.mounted) return;
      await Scrollable.ensureVisible(
        cardContext,
        alignment: 0,
        duration: reducedMotion ? Duration.zero : AppMotion.standard,
      );
    });
  }

  void _showGroupFeedback(String message, {SnackBarAction? action}) {
    showWorkbenchFeedback(context, message, action: action);
  }

  Future<void> _moveGroupTask(
    WorkspaceRecord task,
    WorkspaceRecord source,
    WorkspaceRecord target,
  ) async {
    if (_groupMoveTargetId != null) return;
    setState(() => _groupMoveTargetId = target.id);
    try {
      final transfer = await controller.moveTaskBetweenGroups(
        task: task,
        sourceGroup: source,
        targetGroup: target,
      );
      if (!mounted) return;
      _revealGroup(target.id, transfer.taskId);
      _showGroupFeedback(
        '已移入“${target.title}”',
        action: SnackBarAction(
          label: '撤销',
          onPressed: () => _undoGroupMove(transfer, source.title),
        ),
      );
    } on FormatException catch (error) {
      if (mounted) {
        _showGroupFeedback(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showGroupFeedback(
          '移动失败，请重试。',
          action: SnackBarAction(
            label: '重试',
            onPressed: () => _moveGroupTask(task, source, target),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _groupMoveTargetId = null);
    }
  }

  Future<void> _undoGroupMove(
    TaskGroupTransfer transfer,
    String sourceTitle,
  ) async {
    if (_groupMoveTargetId != null) return;
    setState(() => _groupMoveTargetId = transfer.sourceGroupId);
    try {
      await controller.undoTaskGroupTransfer(transfer);
      if (!mounted) return;
      _revealGroup(transfer.sourceGroupId, transfer.taskId);
      _showGroupFeedback('已移回“$sourceTitle”');
    } on FormatException catch (error) {
      if (mounted) {
        _showGroupFeedback(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showGroupFeedback(
          '撤销失败，请重试。',
          action: SnackBarAction(
            label: '重试',
            onPressed: () => _undoGroupMove(transfer, sourceTitle),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _groupMoveTargetId = null);
    }
  }

  Future<void> _chooseGroupTarget(
    WorkspaceRecord task,
    WorkspaceRecord source,
    List<WorkspaceRecord> groups,
  ) async {
    String? selectedId;
    final targets = groups.where((group) => group.id != source.id).toList();
    final target = await showWorkbenchDialog<WorkspaceRecord>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final size = MediaQuery.sizeOf(context);
          return AlertDialog(
            insetPadding: EdgeInsets.symmetric(
              horizontal: size.width < 600 ? 8 : 24,
              vertical: size.height < 600 ? 8 : 24,
            ),
            title: const Text('移动任务'),
            content: SizedBox(
              width: 520,
              height: (targets.length * 72.0 + 64).clamp(
                160.0,
                (size.height * 0.55).clamp(180.0, 400.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: RadioGroup<String>(
                      groupValue: selectedId,
                      onChanged: (id) => setDialogState(() => selectedId = id),
                      child: ListView.builder(
                        itemCount: targets.length,
                        itemBuilder: (context, index) {
                          final group = targets[index];
                          return RadioListTile<String>(
                            value: group.id,
                            selected: selectedId == group.id,
                            selectedTileColor: context.accents.moss.container,
                            title: Text(group.title),
                            subtitle: Text(
                              '${group.data['mode'] == 'sequential' ? '顺序任务链' : '并行任务群'} · ${controller.groupMembers(group.id).length} 项',
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: selectedId == null
                    ? null
                    : () => Navigator.pop(
                        context,
                        targets.firstWhere((group) => group.id == selectedId),
                      ),
                child: const Text('移动'),
              ),
            ],
          );
        },
      ),
    );
    if (target != null && mounted) await _moveGroupTask(task, source, target);
  }

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
      if (selectedProjectId != widget.selectedProjectId &&
          widget.selectedProjectId != null) {
        _fadeSelectedProject();
      }
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
    if (value == null || value == selectedProjectId) return;
    setState(() => selectedProjectId = value);
    _fadeSelectedProject();
    widget.onProjectSelected?.call(value);
  }

  void _fadeSelectedProject() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _projectSwitchOpacity.value = 1;
    } else {
      _projectSwitchOpacity.forward(from: 0);
    }
  }

  Widget _selectedProjectDetail(
    BuildContext context,
    WorkspaceRecord project,
  ) => FadeTransition(
    key: const ValueKey('project-detail-fade'),
    opacity: _projectSwitchOpacity,
    child: _projectDetail(context, project),
  );

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
                    Expanded(child: _selectedProjectDetail(context, selected)),
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
        Expanded(child: _selectedProjectDetail(context, selected)),
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
      if (record.data['recordType'] == 'periodReview') return false;
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

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.bottomNavClearance),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 600;
              final title = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        ProjectIcons.forKey(project.data['projectIcon']).icon,
                        color: Theme.of(context).colorScheme.primary,
                        size: AppIconSize.md,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          project.title,
                          style: Theme.of(
                            context,
                          ).textTheme.titleLarge?.copyWith(fontSize: 22),
                        ),
                      ),
                    ],
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
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.initialTab != ProjectDetailTab.overview) ...[
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
                  reviews: reviews,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              if (widget.initialTab == ProjectDetailTab.overview) ...[
                _ProjectOverview(
                  key: ValueKey('project-overview-${project.id}'),
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
                    AnimatedSwitcher(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      child: mode == ProjectViewMode.list
                          ? _TaskList(
                              key: const ValueKey('project-task-list'),
                              tasks: tasks,
                              controller: controller,
                            )
                          : _KanbanBoard(
                              key: const ValueKey('project-task-board'),
                              tasks: tasks,
                              controller: controller,
                            ),
                    ),
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
                        KeyedSubtree(
                          key: _groupCardKeys.putIfAbsent(
                            group.id,
                            GlobalKey.new,
                          ),
                          child: _ProjectGroupCard(
                            key: ValueKey('project-group-card-${group.id}'),
                            controller: controller,
                            group: group,
                            highlighted: _highlightedGroupId == group.id,
                            moving: _groupMoveTargetId == group.id,
                            canMove:
                                groups.length > 1 && _groupMoveTargetId == null,
                            revealTaskId: _highlightedGroupId == group.id
                                ? _groupRevealTaskId
                                : null,
                            revealVersion: _groupRevealVersion,
                            revealRowKey: _groupRowKeys.putIfAbsent(
                              group.id,
                              GlobalKey.new,
                            ),
                            onMove: _moveGroupTask,
                            onChooseTarget: (task) =>
                                _chooseGroupTarget(task, group, groups),
                          ),
                        ),
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
                    if (milestones.isNotEmpty)
                      _ProjectMilestoneTimeline(
                        milestones: milestones,
                        tasks: tasks,
                        controller: controller,
                      ),
                  ],
                ),
              ),
              panel(
                id: 'notes',
                title: '笔记与回顾',
                icon: Icons.auto_stories_outlined,
                count: documents.length + reviews.length,
                child: ProjectKnowledgeSection(
                  key: ValueKey('project-knowledge-${project.id}'),
                  controller: controller,
                  project: project,
                  notes: documents,
                  reviews: reviews,
                  onOpenReview: widget.onOpenReview,
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

class _ProjectGroupDrag {
  const _ProjectGroupDrag(this.task, this.sourceGroup);
  final WorkspaceRecord task;
  final WorkspaceRecord sourceGroup;
}

class _ProjectGroupCard extends StatefulWidget {
  const _ProjectGroupCard({
    super.key,
    required this.controller,
    required this.group,
    required this.highlighted,
    required this.moving,
    required this.canMove,
    required this.revealTaskId,
    required this.revealVersion,
    required this.revealRowKey,
    required this.onMove,
    required this.onChooseTarget,
  });

  final WorkbenchController controller;
  final WorkspaceRecord group;
  final bool highlighted;
  final bool moving;
  final bool canMove;
  final String? revealTaskId;
  final int revealVersion;
  final GlobalKey revealRowKey;
  final void Function(WorkspaceRecord, WorkspaceRecord, WorkspaceRecord) onMove;
  final ValueChanged<WorkspaceRecord> onChooseTarget;

  @override
  State<_ProjectGroupCard> createState() => _ProjectGroupCardState();
}

class _ProjectGroupCardState extends State<_ProjectGroupCard> {
  final Set<String> _collapsedTaskIds = <String>{};
  bool _expanded = false;
  String? _rootTaskId;
  final expansionController = ExpansibleController();

  @override
  void initState() {
    super.initState();
    _expanded = widget.highlighted;
    _prepareReveal();
  }

  void _prepareReveal() {
    final id = widget.revealTaskId;
    if (id == null) return;
    final path = taskHierarchyPath(
      id,
      widget.controller.groupMembers(widget.group.id),
    );
    _rootTaskId = path.length > 3 ? path[path.length - 2].id : null;
    for (final task in path) {
      _collapsedTaskIds.remove(task.id);
    }
  }

  @override
  void didUpdateWidget(_ProjectGroupCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlighted && widget.revealVersion != oldWidget.revealVersion) {
      _prepareReveal();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) expansionController.expand();
      });
    }
  }

  @override
  void dispose() {
    expansionController.dispose();
    super.dispose();
  }

  void _selectHierarchyRoot(String? id) {
    setState(() {
      _rootTaskId = id;
      if (id != null) _collapsedTaskIds.remove(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final controller = widget.controller;
    final members = controller.groupMembers(group.id);
    final sequential = group.data['mode'] == 'sequential';
    final completed = members.where((task) => task.isDone).length;
    final accent = context.accents.moss;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth < 600 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.5;
        return DragTarget<_ProjectGroupDrag>(
          onWillAcceptWithDetails: (details) =>
              widget.canMove && details.data.sourceGroup.id != group.id,
          onAcceptWithDetails: (details) =>
              widget.onMove(details.data.task, details.data.sourceGroup, group),
          builder: (context, candidates, _) => Card(
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.card),
              side: BorderSide(
                color: widget.highlighted || candidates.isNotEmpty
                    ? accent.color
                    : context.tokens.panelBorder,
                width: widget.highlighted || candidates.isNotEmpty ? 2 : 1,
              ),
            ),
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            child: ExpansionTile(
              key: PageStorageKey('project-group-${group.id}'),
              controller: expansionController,
              initiallyExpanded: widget.highlighted,
              tilePadding: EdgeInsets.symmetric(
                horizontal: compact ? AppSpacing.md : AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
              childrenPadding: EdgeInsets.fromLTRB(
                compact ? AppSpacing.sm : AppSpacing.md,
                0,
                compact ? AppSpacing.sm : AppSpacing.md,
                AppSpacing.md,
              ),
              expansionAnimationStyle: AnimationStyle(
                duration: reducedMotion ? Duration.zero : AppMotion.standard,
                reverseDuration: reducedMotion
                    ? Duration.zero
                    : AppMotion.standard,
              ),
              onExpansionChanged: (value) => setState(() => _expanded = value),
              leading: widget.moving
                  ? const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : candidates.isNotEmpty
                  ? Icon(Icons.move_to_inbox_outlined, color: accent.color)
                  : JadeIcon(glyph: JadeGlyph.groups, color: accent.color),
              title: Text(
                group.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${sequential ? '顺序任务链' : '并行任务群'} · 已完成 $completed/${members.length}'
                    '${group.projectId == null ? ' · 根据成员推断' : ''}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontSize: 13,
                      color: context.tokens.mutedText,
                    ),
                  ),
                  if (members.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Semantics(
                      label: '完成进度 $completed / ${members.length}',
                      child: LinearProgressIndicator(
                        value: completed / members.length,
                        minHeight: 3,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        color: accent.color,
                        backgroundColor: accent.container,
                      ),
                    ),
                  ],
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PopupMenuButton<String>(
                    tooltip: '任务群操作',
                    onSelected: (value) {
                      if (value == 'edit') {
                        showTaskGroupEditor(
                          context: context,
                          controller: controller,
                          group: group,
                        );
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('编辑任务群')),
                    ],
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: context.tokens.mutedText,
                  ),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.xs,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      sequential ? '顺序依赖 · 完成前一项后解锁下一项' : '并行执行 · 每项任务可独立推进',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.tokens.mutedText,
                      ),
                    ),
                  ),
                ),
                Builder(
                  builder: (context) {
                    final entries = sequential
                        ? [
                            for (final task in members)
                              TaskHierarchyEntry(
                                task: task,
                                depth: 0,
                                hasChildren: false,
                                expanded: true,
                                relation: taskRelationInfo(
                                  task,
                                  controller.tasks,
                                ),
                              ),
                          ]
                        : buildTaskHierarchy(
                            visibleTasks: members,
                            allRecords: controller.tasks,
                            collapsedIds: _collapsedTaskIds,
                            rootTaskId: _rootTaskId,
                            maxDepth: compact ? 2 : 4,
                          );
                    if (entries.isEmpty) {
                      return const ListTile(title: Text('群内暂无任务'));
                    }
                    return Column(
                      children: [
                        if (!sequential && _rootTaskId != null)
                          TaskHierarchyNavigation(
                            path: taskHierarchyPath(_rootTaskId!, members),
                            onSelected: _selectHierarchyRoot,
                          ),
                        for (final entry in entries)
                          _ProjectGroupMember(
                            key: entry.task.id == widget.revealTaskId
                                ? widget.revealRowKey
                                : null,
                            entry: entry,
                            group: group,
                            controller: controller,
                            compact: compact,
                            accent: accent,
                            canMove: widget.canMove,
                            onChooseTarget: () =>
                                widget.onChooseTarget(entry.task),
                            onToggle: () => setState(() {
                              if (entry.canDrill) {
                                _rootTaskId = entry.task.id;
                                _collapsedTaskIds.remove(entry.task.id);
                                return;
                              }
                              if (entry.expanded) {
                                _collapsedTaskIds.add(entry.task.id);
                              } else {
                                _collapsedTaskIds.remove(entry.task.id);
                              }
                            }),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProjectGroupMember extends StatelessWidget {
  const _ProjectGroupMember({
    super.key,
    required this.entry,
    required this.group,
    required this.controller,
    required this.compact,
    required this.accent,
    required this.onToggle,
    required this.canMove,
    required this.onChooseTarget,
  });

  final TaskHierarchyEntry entry;
  final WorkspaceRecord group;
  final WorkbenchController controller;
  final bool compact;
  final JadeAccentPair accent;
  final VoidCallback onToggle;
  final bool canMove;
  final VoidCallback onChooseTarget;

  @override
  Widget build(BuildContext context) {
    final task = entry.task;
    final locked = controller.isTaskGroupMemberLocked(task, group);
    final visibleDepth = entry.depth.clamp(0, compact ? 2 : 4);
    return Container(
      margin: EdgeInsetsDirectional.only(
        start: (visibleDepth * (compact ? 16 : 20)).toDouble(),
      ),
      decoration: entry.depth == 0
          ? null
          : BoxDecoration(
              border: BorderDirectional(
                start: BorderSide(color: accent.color.withValues(alpha: 0.35)),
              ),
            ),
      child: ListTile(
        leading: entry.hasChildren
            ? IconButton(
                tooltip: entry.canDrill
                    ? '进入子层'
                    : entry.expanded
                    ? '收起子任务'
                    : '展开子任务',
                onPressed: onToggle,
                icon: Icon(
                  entry.canDrill
                      ? Icons.subdirectory_arrow_right
                      : entry.expanded
                      ? Icons.expand_less
                      : Icons.expand_more,
                  color: accent.color,
                ),
              )
            : Icon(
                locked ? Icons.lock_outline : Icons.eco_outlined,
                color: accent.color,
              ),
        title: Text(
          task.title,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 15),
        ),
        subtitle: Text(
          [
            locked ? '前置任务尚未通过' : statusLabel(task.status),
            if (entry.depth >= 3 && entry.relation.path.isNotEmpty)
              entry.relation.path.join(' › '),
            if (entry.relation.isWarning) entry.relation.label ?? '',
          ].join(' · '),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!compact && canMove)
              LongPressDraggable<_ProjectGroupDrag>(
                data: _ProjectGroupDrag(task, group),
                feedback: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  child: SizedBox(
                    width: 220,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                childWhenDragging: const Icon(
                  Icons.drag_indicator,
                  color: Colors.transparent,
                ),
                child: Tooltip(
                  message: '拖动到其他任务群',
                  triggerMode: TooltipTriggerMode.manual,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.drag_indicator, color: accent.color),
                  ),
                ),
              ),
            PopupMenuButton<String>(
              tooltip: '任务操作',
              onSelected: (value) {
                if (value == 'move') onChooseTarget();
                if (value == 'edit') {
                  showRecordEditor(
                    context,
                    controller,
                    kind: RecordKind.task,
                    record: task,
                  );
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('编辑任务')),
                if (canMove)
                  const PopupMenuItem(value: 'move', child: Text('移到其他任务群')),
              ],
            ),
          ],
        ),
        onTap: () => showRecordEditor(
          context,
          controller,
          kind: RecordKind.task,
          record: task,
        ),
      ),
    );
  }
}

class _ProjectMilestoneTimeline extends StatefulWidget {
  const _ProjectMilestoneTimeline({
    required this.milestones,
    required this.tasks,
    required this.controller,
  });

  final List<WorkspaceRecord> milestones;
  final List<WorkspaceRecord> tasks;
  final WorkbenchController controller;

  @override
  State<_ProjectMilestoneTimeline> createState() =>
      _ProjectMilestoneTimelineState();
}

class _ProjectMilestoneTimelineState extends State<_ProjectMilestoneTimeline> {
  String? _selectedId;
  final Set<String> _expandedDescriptionIds = <String>{};
  late Set<String> _knownMilestoneIds;
  final Set<String> _enteringMilestoneIds = <String>{};

  @override
  void initState() {
    super.initState();
    _knownMilestoneIds = widget.milestones.map((item) => item.id).toSet();
  }

  @override
  void didUpdateWidget(covariant _ProjectMilestoneTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentIds = widget.milestones.map((item) => item.id).toSet();
    final added = currentIds.difference(_knownMilestoneIds);
    _knownMilestoneIds = currentIds;
    if (added.isEmpty) return;
    _enteringMilestoneIds.addAll(added);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _enteringMilestoneIds.removeAll(added));
    });
  }

  List<WorkspaceRecord> _linkedTasks(WorkspaceRecord milestone) {
    final rawIds = milestone.data['relatedTaskIds'];
    final ids = rawIds is List
        ? rawIds.map((value) => value.toString()).toSet()
        : const <String>{};
    return widget.tasks
        .where((task) => ids.contains(task.id) || task.parentId == milestone.id)
        .toList(growable: false);
  }

  Future<void> _toggleDone(WorkspaceRecord milestone) async {
    final completing = !milestone.isDone;
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await widget.controller.toggleTaskDone(
        widget.controller.latestRecordById(milestone),
      );
      if (!mounted) return;
      setState(() => _selectedId = milestone.id);
      messenger?.hideCurrentSnackBar();
      messenger?.showSnackBar(
        SnackBar(
          content: Text(completing ? '里程碑已达成' : '里程碑已重新打开'),
          action: SnackBarAction(
            label: '撤销',
            onPressed: () async {
              await widget.controller.toggleTaskDone(
                widget.controller.latestRecordById(milestone),
              );
              if (mounted) setState(() => _selectedId = milestone.id);
            },
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger?.showSnackBar(const SnackBar(content: Text('里程碑状态更新失败，请重试')));
    }
  }

  Widget _relatedSummary(WorkspaceRecord milestone) {
    final linked = _linkedTasks(milestone);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('关联任务 ${linked.length}', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        if (linked.isEmpty)
          Text(
            '尚未关联任务',
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.tokens.mutedText,
            ),
          )
        else
          for (final task in linked.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: [
                  Icon(
                    task.isDone ? Icons.check_circle : Icons.circle_outlined,
                    size: AppIconSize.xs,
                    color: context.accents.moss.color,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        if (linked.length > 5)
          Text(
            '另有 ${linked.length - 5} 项',
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.tokens.mutedText,
            ),
          ),
      ],
    );
  }

  Widget _node(
    WorkspaceRecord milestone, {
    required bool last,
    required bool compact,
    required bool selected,
  }) {
    final theme = Theme.of(context);
    final moss = context.accents.moss;
    final overdue =
        !milestone.isDone &&
        milestone.dueAt != null &&
        milestone.dueAt!.isBefore(widget.controller.currentTime());
    final nodeColor = overdue ? context.tokens.signal : moss.color;
    final completion = milestone.isDone ? 1.0 : 0.0;
    final expanded = _expandedDescriptionIds.contains(milestone.id);
    final dateLabel = milestone.dueAt == null
        ? '未设置日期'
        : formatShortDate(milestone.dueAt!);
    return Stack(
      children: [
        if (!last)
          PositionedDirectional(
            start: 19,
            top: 35,
            bottom: 0,
            width: 2,
            child: ColoredBox(color: moss.color.withValues(alpha: 0.35)),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 40,
              child: Padding(
                padding: const EdgeInsets.only(top: 17),
                child: Center(
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey('milestone-state-${milestone.id}'),
                    tween: Tween(begin: completion, end: completion),
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) => Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color.lerp(theme.cardColor, nodeColor, value),
                        border: Border.all(color: nodeColor, width: 2),
                      ),
                      child: Opacity(opacity: value, child: child),
                    ),
                    child: Icon(
                      Icons.check,
                      size: 14,
                      color:
                          ThemeData.estimateBrightnessForColor(nodeColor) ==
                              Brightness.dark
                          ? Colors.white
                          : Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: Card(
                  margin: EdgeInsets.zero,
                  color: selected ? moss.container : null,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    onTap: () => setState(() => _selectedId = milestone.id),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.xs,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                dateLabel,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontFamily: AppFonts.numeric,
                                  fontSize: 13,
                                  color: context.tokens.mutedText,
                                ),
                              ),
                              Text(
                                milestone.isDone
                                    ? '已达成'
                                    : overdue
                                    ? '已逾期'
                                    : '待到达',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: nodeColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            milestone.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 16,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                          if (milestone.body.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              milestone.body,
                              maxLines: expanded ? null : 3,
                              overflow: expanded
                                  ? TextOverflow.visible
                                  : TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 14,
                              ),
                            ),
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: TextButton(
                                onPressed: () => setState(() {
                                  if (expanded) {
                                    _expandedDescriptionIds.remove(
                                      milestone.id,
                                    );
                                  } else {
                                    _expandedDescriptionIds.add(milestone.id);
                                  }
                                }),
                                child: Text(expanded ? '收起说明' : '展开说明'),
                              ),
                            ),
                          ],
                          if (compact && selected) ...[
                            const Divider(),
                            _relatedSummary(milestone),
                          ],
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.xs,
                            children: [
                              TextButton.icon(
                                onPressed: () => _toggleDone(milestone),
                                icon: Icon(
                                  milestone.isDone
                                      ? Icons.undo_outlined
                                      : Icons.check_circle_outline,
                                  size: AppIconSize.xs,
                                ),
                                label: Text(milestone.isDone ? '重新打开' : '标记达成'),
                              ),
                              IconButton(
                                tooltip: '编辑里程碑',
                                onPressed: () => showRecordEditor(
                                  context,
                                  widget.controller,
                                  kind: RecordKind.milestone,
                                  record: milestone,
                                ),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ordered =
        [
          for (final milestone in widget.milestones)
            widget.controller.latestRecordById(milestone),
        ]..sort((a, b) {
          final left = a.dueAt;
          final right = b.dueAt;
          if (left == null && right == null) return a.title.compareTo(b.title);
          if (left == null) return 1;
          if (right == null) return -1;
          return left.compareTo(right);
        });
    final selected =
        ordered.where((milestone) => milestone.id == _selectedId).firstOrNull ??
        ordered.where((milestone) => !milestone.isDone).firstOrNull ??
        ordered.first;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final timeline = ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: (WorkbenchViewport.sizeOf(context).height * 0.7).clamp(
              260.0,
              720.0,
            ),
          ),
          child: ListView.builder(
            key: const PageStorageKey('project-milestone-scroll'),
            primary: false,
            shrinkWrap: true,
            itemCount: ordered.length,
            itemBuilder: (context, index) => AnimatedOpacity(
              key: ValueKey('milestone-node-${ordered[index].id}'),
              opacity: _enteringMilestoneIds.contains(ordered[index].id)
                  ? 0
                  : 1,
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: _node(
                ordered[index],
                last: index == ordered.length - 1,
                compact: compact,
                selected: ordered[index].id == selected.id,
              ),
            ),
          ),
        );
        if (compact) return timeline;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: timeline),
            const SizedBox(width: AppSpacing.lg),
            SizedBox(
              width: 280,
              child: AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                child: SolidPanel(
                  key: ValueKey('milestone-detail-${selected.id}'),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '当前节点',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        selected.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _relatedSummary(selected),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
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
    required this.reviews,
  });

  final String section;
  final List<WorkspaceRecord> tasks;
  final List<WorkspaceRecord> groups;
  final List<WorkspaceRecord> milestones;
  final List<WorkspaceRecord> notes;
  final List<WorkspaceRecord> reviews;

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
    final recentRecords = [...notes, ...reviews]
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
        description = recentRecords.isEmpty
            ? '把决策、材料和发现放在项目的同一处。'
            : '最近更新：${recentRecords.first.title}';
        facts = [
          _ProjectSignalFact(
            label: '关联笔记',
            value: notes.length,
            icon: Icons.note_alt_outlined,
          ),
          _ProjectSignalFact(
            label: '关联回顾',
            value: reviews.length,
            icon: Icons.insights_outlined,
          ),
          if (recentRecords.isNotEmpty)
            Text(
              '更新于 ${formatShortDate(recentRecords.first.updatedAt)}',
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
    super.key,
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
    final nextTask = tasks
        .where((task) => !WorkStatus.terminal.contains(task.status))
        .firstOrNull;
    WorkspaceRecord? nextMilestone;
    WorkspaceRecord? latestCompletedMilestone;
    for (final milestone in milestones) {
      if (milestone.isDone) {
        if (latestCompletedMilestone == null ||
            milestone.updatedAt.isAfter(latestCompletedMilestone.updatedAt)) {
          latestCompletedMilestone = milestone;
        }
      } else if (!WorkStatus.terminal.contains(milestone.status)) {
        final currentDate = nextMilestone?.dueAt;
        final candidateDate = milestone.dueAt;
        if (nextMilestone == null ||
            (candidateDate != null &&
                (currentDate == null || candidateDate.isBefore(currentDate)))) {
          nextMilestone = milestone;
        }
      }
    }
    final summaryMilestone = nextMilestone ?? latestCompletedMilestone;
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
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
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
                          Text(
                            nextTask == null ? '项目进展' : '当前下一步',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: tokens.mutedText,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            nextTask?.title ??
                                (tasks.isEmpty ? '从第一步开始搭起项目路径' : '当前任务已完成'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                    if (showArt) ...[
                      const SizedBox(width: AppSpacing.sm),
                      JadeBotanicalEdge(
                        width: compact ? 32 : 56,
                        height: compact ? 28 : 42,
                        compact: compact,
                      ),
                    ],
                    if (compact)
                      IconButton(
                        onPressed: onOpenTasks,
                        tooltip: '查看任务',
                        icon: const Icon(Icons.arrow_forward),
                      )
                    else
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
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          Semantics(
            label: '任务进度：已完成 $completed 项，共 ${tasks.length} 项',
            child: TweenAnimationBuilder<double>(
              key: const ValueKey('project-overview-progress'),
              tween: Tween<double>(begin: progress, end: progress),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => LinearProgressIndicator(
                value: value,
                minHeight: 7,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                backgroundColor: tokens.subtle,
              ),
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
          if (summaryMilestone != null) ...[
            const SizedBox(height: AppSpacing.md),
            Divider(height: 1, color: tokens.divider),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  nextMilestone == null
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: AppIconSize.sm,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nextMilestone == null ? '最近达成' : '下一里程碑',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: tokens.mutedText,
                        ),
                      ),
                      Text(
                        summaryMilestone.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                if (summaryMilestone.dueAt case final date?) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    formatShortDate(date),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tokens.mutedText,
                      fontFamily: AppFonts.numeric,
                    ),
                  ),
                ],
              ],
            ),
          ],
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
    return ListView.builder(
      key: const PageStorageKey('project-index-scroll'),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      itemCount: projects.length,
      itemBuilder: (context, index) {
        final project = projects[index];
        final tasks = controller.projectTasks(project.id);
        final done = tasks.where((task) => task.isDone).length;
        return ListTile(
          key: ValueKey('project-index-${project.id}'),
          selected: project.id == selectedId,
          selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          leading: Icon(
            ProjectIcons.forKey(project.data['projectIcon']).icon,
            color: project.favorite
                ? Theme.of(context).colorScheme.primary
                : null,
          ),
          title: Text(
            project.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tasks.isEmpty ? '尚未添加任务' : '已完成 $done/${tasks.length} 项'),
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
    );
  }
}

class _TaskList extends StatefulWidget {
  const _TaskList({super.key, required this.tasks, required this.controller});

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
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: (WorkbenchViewport.sizeOf(context).height * 0.65).clamp(
          240.0,
          680.0,
        ),
      ),
      child: ListView.builder(
        key: const PageStorageKey('project-task-list-scroll'),
        primary: false,
        shrinkWrap: true,
        itemCount: entries.length,
        itemBuilder: (context, index) => Padding(
          padding: EdgeInsets.only(bottom: index == entries.length - 1 ? 0 : 8),
          child: Card(
            key: ValueKey('project-task-${entries[index].task.id}'),
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
        ),
      ),
    );
  }
}

class _KanbanBoard extends StatefulWidget {
  const _KanbanBoard({
    super.key,
    required this.tasks,
    required this.controller,
  });

  final List<WorkspaceRecord> tasks;
  final WorkbenchController controller;

  @override
  State<_KanbanBoard> createState() => _KanbanBoardState();
}

class _KanbanBoardState extends State<_KanbanBoard> {
  static const _columns = [
    (WorkStatus.todo, '待办'),
    (WorkStatus.doing, '进行中'),
    (WorkStatus.done, '已完成'),
  ];
  String _selectedCompactStatus = WorkStatus.todo;

  Future<void> _moveTask(WorkspaceRecord task, String status) async {
    final original = widget.controller.latestRecordById(task);
    final result = await widget.controller.batchSetTaskStatus([
      original,
    ], status);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    if (!result.isSuccessful) {
      messenger.showSnackBar(const SnackBar(content: Text('任务状态更新失败，请重试')));
      return;
    }
    final definition = widget.controller.taskDefinitionFor(original);
    final recurring = definition != null
        ? TaskDefinition.fromRecord(definition).isRecurring
        : original.data['recurrence'] != null &&
              original.data['recurrence'] != 'none';
    final canUndo = !original.hasCtdpProtocol && !recurring;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '已移至${_columns.firstWhere((item) => item.$1 == status).$2}',
        ),
        action: canUndo
            ? SnackBarAction(
                label: '撤销',
                onPressed: () async {
                  final current = widget.controller.latestRecordById(original);
                  final undo = await widget.controller.batchSetTaskStatus([
                    current,
                  ], original.status);
                  if (!mounted || undo.isSuccessful) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('撤销失败，请重试')));
                },
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasksByStatus = <String, List<WorkspaceRecord>>{
      for (final column in _columns) column.$1: <WorkspaceRecord>[],
    };
    for (final task in widget.tasks) {
      final normalized = task.status == WorkStatus.inbox
          ? WorkStatus.todo
          : task.status;
      tasksByStatus[normalized]?.add(task);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        // The project index takes part of the window on desktop. Decide from
        // this board's real width, rather than the outer window width.
        final compact = constraints.maxWidth < 960;
        if (compact) {
          final selected = _columns.firstWhere(
            (entry) => entry.$1 == _selectedCompactStatus,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final entry in _columns)
                    ChoiceChip(
                      label: Text(
                        '${entry.$2} ${tasksByStatus[entry.$1]!.length}',
                      ),
                      selected: _selectedCompactStatus == entry.$1,
                      onSelected: (_) =>
                          setState(() => _selectedCompactStatus = entry.$1),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                child: _KanbanColumn(
                  key: ValueKey('project-kanban-${selected.$1}'),
                  status: selected.$1,
                  label: selected.$2,
                  tasks: tasksByStatus[selected.$1]!,
                  controller: widget.controller,
                  enableDragAndDrop: false,
                  onMove: _moveTask,
                ),
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final entry in _columns) ...[
              if (entry != _columns.first) const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _KanbanColumn(
                  status: entry.$1,
                  label: entry.$2,
                  tasks: tasksByStatus[entry.$1]!,
                  controller: widget.controller,
                  enableDragAndDrop: true,
                  onMove: _moveTask,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _KanbanColumn extends StatelessWidget {
  const _KanbanColumn({
    super.key,
    required this.status,
    required this.label,
    required this.tasks,
    required this.controller,
    required this.enableDragAndDrop,
    required this.onMove,
  });

  final String status;
  final String label;
  final List<WorkspaceRecord> tasks;
  final WorkbenchController controller;
  final bool enableDragAndDrop;
  final Future<void> Function(WorkspaceRecord, String) onMove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = switch (status) {
      WorkStatus.doing => context.accents.jade,
      WorkStatus.done => context.accents.moss,
      _ => context.accents.teal,
    };
    Widget taskCard(WorkspaceRecord task) => Card(
      margin: EdgeInsets.zero,
      child: TaskRow(task: task, controller: controller, dense: true),
    );
    Widget draggableCard(WorkspaceRecord task) => Card(
      margin: EdgeInsets.zero,
      child: Row(
        children: [
          LongPressDraggable<WorkspaceRecord>(
            data: task,
            feedback: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: SizedBox(width: 260, child: taskCard(task)),
            ),
            childWhenDragging: const SizedBox(width: 28, height: 60),
            child: Semantics(
              label: '拖动任务至其他状态列',
              child: const SizedBox(
                width: 28,
                height: 60,
                child: Icon(Icons.drag_indicator, size: AppIconSize.sm),
              ),
            ),
          ),
          Expanded(
            child: TaskRow(task: task, controller: controller, dense: true),
          ),
        ],
      ),
    );
    Widget column(bool highlighted) => ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: ColoredBox(
        color: highlighted ? scheme.primaryContainer : context.tokens.subtle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 4, child: ColoredBox(color: accent.color)),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
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
                  const SizedBox(height: AppSpacing.md),
                  if (tasks.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.lg,
                      ),
                      child: Text(
                        enableDragAndDrop ? '拖动任务到这里' : '此状态暂无任务',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight:
                            (WorkbenchViewport.sizeOf(context).height * 0.6)
                                .clamp(220.0, 640.0),
                      ),
                      child: ListView.builder(
                        key: PageStorageKey('project-kanban-scroll-$status'),
                        primary: false,
                        shrinkWrap: true,
                        itemCount: tasks.length,
                        itemBuilder: (context, index) => Padding(
                          padding: EdgeInsets.only(
                            top: index == 0 ? 0 : AppSpacing.sm,
                          ),
                          child: enableDragAndDrop
                              ? draggableCard(tasks[index])
                              : taskCard(tasks[index]),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (!enableDragAndDrop) return column(false);
    return DragTarget<WorkspaceRecord>(
      onWillAcceptWithDetails: (details) {
        final currentStatus = details.data.status == WorkStatus.inbox
            ? WorkStatus.todo
            : details.data.status;
        return currentStatus != status;
      },
      onAcceptWithDetails: (details) => onMove(details.data, status),
      builder: (context, candidates, _) => column(candidates.isNotEmpty),
    );
  }
}
