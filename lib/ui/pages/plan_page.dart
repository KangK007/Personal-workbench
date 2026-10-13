import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/utils/formatters.dart';
import '../../core/models/workspace_record.dart';
import '../../core/theme/app_theme.dart';
import '../../state/workbench_controller.dart';
import '../widgets/common.dart';
import '../widgets/jade_icon.dart';
import '../widgets/batch_task_toolbar.dart';
import '../widgets/quick_capture_sheet.dart';
import '../widgets/record_editor_dialog.dart';
import '../widgets/task_row.dart';
import '../widgets/task_group_editor_dialog.dart';
import '../widgets/task_hierarchy.dart';
import '../widgets/task_hierarchy_navigation.dart';
import '../widgets/solid_panel.dart';
import 'calendar_page.dart';
import 'inbox_page.dart';

/// Task page views. Projects have their own first-class navigation entry.
enum PlanTab { all, inbox, week, groups }

enum _MemberAction { edit, moveUp, moveDown, skipAndContinue, remove }

enum _TaskStatusFilter { all, open, doing, done, otherClosed }

enum _TaskDateFilter { all, today, nextSevenDays, overdue, unscheduled }

enum _TaskOrder { scheduled, deadline, recentlyUpdated, priority }

String _statusFilterLabel(_TaskStatusFilter value) => switch (value) {
  _TaskStatusFilter.all => '全部状态',
  _TaskStatusFilter.open => '未完成',
  _TaskStatusFilter.doing => '进行中',
  _TaskStatusFilter.done => '已完成',
  _TaskStatusFilter.otherClosed => '其他结案',
};

String _dateFilterLabel(_TaskDateFilter value) => switch (value) {
  _TaskDateFilter.all => '全部日期',
  _TaskDateFilter.today => '今天',
  _TaskDateFilter.nextSevenDays => '未来七天',
  _TaskDateFilter.overdue => '已逾期',
  _TaskDateFilter.unscheduled => '未安排',
};

String _taskOrderLabel(_TaskOrder value) => switch (value) {
  _TaskOrder.scheduled => '安排时间',
  _TaskOrder.deadline => '截止时间',
  _TaskOrder.recentlyUpdated => '最近更新',
  _TaskOrder.priority => '优先级',
};

/// A compact map of the real task queue; the text remains readable without
/// relying on the colored distribution bar.
class _TaskDomainOverview extends StatelessWidget {
  const _TaskDomainOverview({required this.tasks, required this.now});

  final List<WorkspaceRecord> tasks;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final accent = context.accents.teal;
    final done = tasks.where((task) => task.isDone).length;
    final doing = tasks.where((task) => task.status == WorkStatus.doing).length;
    final overdue = tasks.where((task) {
      final due = task.dueAt;
      return due != null &&
          due.isBefore(now) &&
          !WorkStatus.terminal.contains(task.status);
    }).length;
    final remaining = tasks
        .where((task) => !WorkStatus.terminal.contains(task.status))
        .length;
    return SolidPanel(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.route_outlined, color: accent.color),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text('任务版图', style: theme.textTheme.titleMedium)),
              Text(
                '$done/${tasks.length}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFamily: AppFonts.numeric,
                  color: accent.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '按真实状态汇总，点开任务可继续拆分和安排。',
            style: theme.textTheme.bodySmall?.copyWith(color: tokens.mutedText),
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: tasks.isEmpty ? 0 : done / tasks.length,
              minHeight: 8,
              backgroundColor: accent.container,
              valueColor: AlwaysStoppedAnimation<Color>(accent.color),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: [
              _TaskOverviewMetric(
                icon: Icons.pending_actions_outlined,
                label: '待推进',
                value: remaining,
              ),
              _TaskOverviewMetric(
                icon: Icons.play_circle_outline,
                label: '进行中',
                value: doing,
              ),
              _TaskOverviewMetric(
                icon: Icons.schedule_outlined,
                label: '已逾期',
                value: overdue,
                color: overdue > 0 ? tokens.signal : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TaskOverviewMetric extends StatelessWidget {
  const _TaskOverviewMetric({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = color ?? context.tokens.mutedText;
    return Semantics(
      label: '$label $value 项',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppIconSize.xs, color: foreground),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '$label $value',
            style: theme.textTheme.labelMedium?.copyWith(
              color: foreground,
              fontFamily: AppFonts.numeric,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupOverview extends StatelessWidget {
  const _GroupOverview({required this.groups, required this.controller});

  final List<WorkspaceRecord> groups;
  final WorkbenchController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = context.accents.moss;
    final sequential = groups
        .where((group) => group.data['mode'] == 'sequential')
        .length;
    final memberCount = groups.fold<int>(
      0,
      (sum, group) => sum + controller.groupMembers(group.id).length,
    );
    return SolidPanel(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          JadeIcon(
            glyph: JadeGlyph.groups,
            color: accent.color,
            size: AppIconSize.lg,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('协作结构', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '顺序链 $sequential · 并行群 ${groups.length - sequential} · 成员 $memberCount',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.tokens.mutedText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupMemberTrack extends StatelessWidget {
  const _GroupMemberTrack({required this.members, required this.sequential});

  final List<WorkspaceRecord> members;
  final bool sequential;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    final visible = members
        .take(
          WorkbenchViewport.sizeOf(context).width < AppBreakpoints.compact
              ? 2
              : 5,
        )
        .toList(growable: false);
    return Semantics(
      label:
          '${sequential ? '顺序任务链' : '并行任务群'}，${members.length} 项，'
          '已完成 ${members.where((task) => task.isDone).length} 项',
      child: ExcludeSemantics(
        child: Row(
          children: [
            for (var index = 0; index < visible.length; index++) ...[
              if (index > 0) ...[
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  sequential ? Icons.arrow_forward : Icons.more_horiz,
                  size: AppIconSize.xs,
                  color: tokens.mutedText,
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: visible[index].isDone ? scheme.primary : tokens.subtle,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: visible[index].isDone
                        ? scheme.primary
                        : tokens.borderStrong,
                  ),
                ),
                child: visible[index].isDone
                    ? Icon(Icons.check, size: 13, color: scheme.onPrimary)
                    : null,
              ),
            ],
            if (members.length > visible.length) ...[
              const SizedBox(width: AppSpacing.sm),
              Text(
                '+${members.length - visible.length}',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: tokens.mutedText),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class PlanPage extends StatefulWidget {
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
  State<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: PlanTab.values.length,
    initialIndex: widget.initialTab.index,
    vsync: this,
  );

  @override
  void didUpdateWidget(covariant PlanPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab &&
        !_tabController.indexIsChanging) {
      _tabController.index = widget.initialTab.index;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.controller.currentTime();
    final compact =
        WorkbenchViewport.sizeOf(context).width < AppBreakpoints.compact;
    final android = defaultTargetPlatform == TargetPlatform.android;
    final androidCompact = android && compact;
    final tabsVisible =
        widget.showTabs && defaultTargetPlatform != TargetPlatform.windows;
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    return Column(
      children: [
        if (widget.showHeader)
          PageHeader(
            title: '任务',
            subtitle:
                '全部任务 · ${formatShortDate(weekStart)}—${formatShortDate(weekStart.add(const Duration(days: 6)))}',
          ),
        Expanded(
          child: Column(
            children: [
              if (tabsVisible)
                WorkbenchTabBar(
                  controller: _tabController,
                  // Android uses four equal-width targets so the selected tab
                  // stays visible without requiring a horizontal gesture.
                  isScrollable: android ? false : compact,
                  autofocus: android,
                  tabAlignment: android ? TabAlignment.fill : null,
                  labelPadding: androidCompact
                      ? EdgeInsets.zero
                      : EdgeInsets.symmetric(horizontal: compact ? 14 : 16),
                  indicatorSize: TabBarIndicatorSize.label,
                  tabs: [
                    Tab(
                      text: '全部任务',
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
                  controller: _tabController,
                  children: [
                    _AllTasksPage(controller: widget.controller),
                    InboxPage(controller: widget.controller, showHeader: false),
                    CalendarPage(
                      controller: widget.controller,
                      showHeader: false,
                    ),
                    _TaskGroupsPage(controller: widget.controller),
                  ],
                ),
              ),
            ],
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
  _TaskStatusFilter _statusFilter = _TaskStatusFilter.all;
  _TaskDateFilter _dateFilter = _TaskDateFilter.all;
  _TaskOrder _order = _TaskOrder.scheduled;
  bool _filtersExpanded = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allTasks = widget.controller.tasks;
    final now = widget.controller.currentTime();
    final tasks =
        allTasks
            .where((task) => _matchesStatus(task) && _matchesDate(task, now))
            .toList(growable: false)
          ..sort(_compareTasks);
    final entries = buildTaskHierarchy(
      visibleTasks: tasks,
      allRecords: widget.controller.allRecords,
      collapsedIds: _collapsedTaskIds,
    );
    final selectedTasks = tasks
        .where((task) => _selectedIds.contains(task.id))
        .toList(growable: false);
    if (allTasks.isEmpty) {
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
    final overviewAndFilters = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: _TaskDomainOverview(tasks: allTasks, now: now),
        ),
        _filterBar(
          context,
          visibleCount: tasks.length,
          totalCount: allTasks.length,
        ),
      ],
    );
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
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            children: [
              if (!_selectionMode)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight * 0.62,
                  ),
                  child: SingleChildScrollView(child: overviewAndFilters),
                ),
              if (_selectionMode)
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  builder: (context, opacity, child) => Opacity(
                    key: const ValueKey('task-batch-enter'),
                    opacity: opacity,
                    child: child,
                  ),
                  child: BatchTaskToolbar(
                    controller: widget.controller,
                    visibleTasks: tasks,
                    selectedTasks: selectedTasks,
                    onSelectionChanged: (ids) => setState(() {
                      _selectedIds
                        ..clear()
                        ..addAll(ids);
                    }),
                    onExit: _exitSelection,
                  ),
                ),
              Expanded(
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(
                    'task-results-${_statusFilter.name}-${_dateFilter.name}-${_order.name}',
                  ),
                  tween: Tween(begin: 0.5, end: 1),
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 120),
                  builder: (context, opacity, child) => Opacity(
                    key: const ValueKey('task-results-fade'),
                    opacity: opacity,
                    child: child,
                  ),
                  child: entries.isEmpty
                      ? Center(
                          child: EmptyState(
                            icon: Icons.filter_alt_off_outlined,
                            title: '没有符合条件的任务',
                            message: '调整状态或日期，看看其他任务。',
                            action: OutlinedButton.icon(
                              onPressed: _clearFilters,
                              icon: const Icon(Icons.restart_alt),
                              label: const Text('清除筛选'),
                            ),
                          ),
                        )
                      : ListView.separated(
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
                                onSelectionChanged: (value) => _toggleSelection(
                                  entry.task.id,
                                  value,
                                  tasks,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterBar(
    BuildContext context, {
    required int visibleCount,
    required int totalCount,
  }) {
    final viewport = WorkbenchViewport.sizeOf(context);
    final compact =
        viewport.width < AppBreakpoints.compact ||
        viewport.height < AppBreakpoints.compactHeight ||
        MediaQuery.textScalerOf(context).scale(1) > 1.5;
    final activeCount =
        (_statusFilter == _TaskStatusFilter.all ? 0 : 1) +
        (_dateFilter == _TaskDateFilter.all ? 0 : 1) +
        (_order == _TaskOrder.scheduled ? 0 : 1);
    final count = Text(
      '匹配 $visibleCount / $totalCount 项',
      key: const ValueKey('task-filter-result-count'),
      style: Theme.of(context).textTheme.labelLarge,
    );
    final controls = compact
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _statusChoice(),
              const SizedBox(height: AppSpacing.sm),
              _dateChoice(),
              const SizedBox(height: AppSpacing.sm),
              _orderChoice(),
            ],
          )
        : Row(
            children: [
              Expanded(child: _statusChoice()),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _dateChoice()),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _orderChoice()),
            ],
          );
    final filtersBody = !compact || _filtersExpanded
        ? Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                controls,
                if (activeCount > 0)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('重置筛选与排序'),
                    ),
                  ),
              ],
            ),
          )
        : const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, AppSpacing.md, 20, 0),
      child: SolidPanel(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (compact)
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  count,
                  TextButton.icon(
                    key: const ValueKey('task-filter-toggle'),
                    onPressed: () =>
                        setState(() => _filtersExpanded = !_filtersExpanded),
                    icon: Icon(
                      _filtersExpanded ? Icons.expand_less : Icons.tune,
                    ),
                    label: Text(
                      _filtersExpanded
                          ? '收起筛选'
                          : activeCount == 0
                          ? '筛选'
                          : '筛选 $activeCount',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _enterSelection,
                    icon: const Icon(Icons.library_add_check_outlined),
                    label: const Text('选择'),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Icon(
                    Icons.filter_list_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  count,
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: _enterSelection,
                    icon: const Icon(Icons.library_add_check_outlined),
                    label: const Text('选择任务'),
                  ),
                ],
              ),
            if (MediaQuery.disableAnimationsOf(context))
              filtersBody
            else
              AnimatedSize(
                alignment: Alignment.topCenter,
                duration: const Duration(milliseconds: 160),
                child: filtersBody,
              ),
          ],
        ),
      ),
    );
  }

  Widget _statusChoice() => _filterChoice<_TaskStatusFilter>(
    key: const ValueKey('task-filter-status'),
    label: '状态',
    value: _statusFilter,
    options: _TaskStatusFilter.values,
    optionLabel: _statusFilterLabel,
    onChanged: (value) => setState(() => _statusFilter = value),
  );

  Widget _dateChoice() => _filterChoice<_TaskDateFilter>(
    key: const ValueKey('task-filter-date'),
    label: '日期',
    value: _dateFilter,
    options: _TaskDateFilter.values,
    optionLabel: _dateFilterLabel,
    onChanged: (value) => setState(() => _dateFilter = value),
  );

  Widget _orderChoice() => _filterChoice<_TaskOrder>(
    key: const ValueKey('task-filter-order'),
    label: '排序',
    value: _order,
    options: _TaskOrder.values,
    optionLabel: _taskOrderLabel,
    onChanged: (value) => setState(() => _order = value),
  );

  Widget _filterChoice<T>({
    required Key key,
    required String label,
    required T value,
    required List<T> options,
    required String Function(T) optionLabel,
    required ValueChanged<T> onChanged,
  }) => Semantics(
    label: label == '排序' ? '任务排序' : '任务$label筛选',
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          key: key,
          value: value,
          isExpanded: true,
          isDense: true,
          items: [
            for (final option in options)
              DropdownMenuItem(
                value: option,
                child: Text(
                  optionLabel(option),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      ),
    ),
  );

  bool _matchesStatus(WorkspaceRecord task) => switch (_statusFilter) {
    _TaskStatusFilter.all => true,
    _TaskStatusFilter.open => !WorkStatus.terminal.contains(task.status),
    _TaskStatusFilter.doing => task.status == WorkStatus.doing,
    _TaskStatusFilter.done => task.status == WorkStatus.done,
    _TaskStatusFilter.otherClosed =>
      WorkStatus.terminal.contains(task.status) &&
          task.status != WorkStatus.done,
  };

  bool _matchesDate(WorkspaceRecord task, DateTime now) {
    final start = DateTime(now.year, now.month, now.day);
    bool inRange(DateTime? value, DateTime end) {
      final local = value?.toLocal();
      return local != null && !local.isBefore(start) && local.isBefore(end);
    }

    return switch (_dateFilter) {
      _TaskDateFilter.all => true,
      _TaskDateFilter.today =>
        inRange(task.scheduledFor, start.add(const Duration(days: 1))) ||
            inRange(task.dueAt, start.add(const Duration(days: 1))),
      _TaskDateFilter.nextSevenDays =>
        inRange(task.scheduledFor, start.add(const Duration(days: 7))) ||
            inRange(task.dueAt, start.add(const Duration(days: 7))),
      _TaskDateFilter.overdue =>
        task.dueAt != null &&
            task.dueAt!.isBefore(now) &&
            !WorkStatus.terminal.contains(task.status),
      _TaskDateFilter.unscheduled => task.scheduledFor == null,
    };
  }

  int _compareTasks(WorkspaceRecord a, WorkspaceRecord b) {
    final scheduled = (a.scheduledFor ?? a.dueAt ?? a.createdAt).compareTo(
      b.scheduledFor ?? b.dueAt ?? b.createdAt,
    );
    final result = switch (_order) {
      _TaskOrder.scheduled => scheduled,
      _TaskOrder.deadline => _compareOptionalDates(a.dueAt, b.dueAt),
      _TaskOrder.recentlyUpdated => b.updatedAt.compareTo(a.updatedAt),
      _TaskOrder.priority =>
        ((b.data['priority'] as num?)?.toInt() ?? 0).compareTo(
          (a.data['priority'] as num?)?.toInt() ?? 0,
        ),
    };
    if (result != 0) return result;
    if (scheduled != 0) return scheduled;
    final title = a.title.compareTo(b.title);
    if (title != 0) return title;
    return a.id.compareTo(b.id);
  }

  int _compareOptionalDates(DateTime? a, DateTime? b) {
    if (a == null) return b == null ? 0 : 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }

  void _clearFilters() => setState(() {
    _statusFilter = _TaskStatusFilter.all;
    _dateFilter = _TaskDateFilter.all;
    _order = _TaskOrder.scheduled;
    _filtersExpanded = false;
  });

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
  final Set<String> _expandedGroupIds = {};
  final Set<String> _renderedGroupIds = {};
  final Map<String, Timer> _collapseTimers = {};
  final Set<String> _collapsedTaskIds = {};
  final Map<String, String> _rootTaskIds = {};
  final Map<String, ExpansibleController> _groupControllers = {};
  final Map<String, GlobalKey> _memberKeys = {};
  final Map<String, FocusNode> _memberFocusNodes = {};
  final Set<String> _newMemberIds = {};
  final Map<String, Timer> _entryTimers = {};

  void _selectHierarchyRoot(String groupId, String? taskId) {
    setState(() {
      if (taskId == null) {
        _rootTaskIds.remove(groupId);
      } else {
        _rootTaskIds[groupId] = taskId;
        _collapsedTaskIds.remove(taskId);
      }
    });
  }

  @override
  void dispose() {
    for (final timer in _collapseTimers.values) {
      timer.cancel();
    }
    for (final timer in _entryTimers.values) {
      timer.cancel();
    }
    for (final controller in _groupControllers.values) {
      controller.dispose();
    }
    for (final focusNode in _memberFocusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _setGroupExpanded(String id, bool expanded) {
    _collapseTimers.remove(id)?.cancel();
    if (expanded) {
      setState(() {
        _expandedGroupIds.add(id);
        _renderedGroupIds.add(id);
      });
      return;
    }
    setState(() => _expandedGroupIds.remove(id));
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() => _renderedGroupIds.remove(id));
      return;
    }
    _collapseTimers[id] = Timer(AppMotion.standard, () {
      _collapseTimers.remove(id);
      if (!mounted || _expandedGroupIds.contains(id)) return;
      setState(() => _renderedGroupIds.remove(id));
    });
  }

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
        _GroupOverview(groups: groups, controller: widget.controller),
        const SizedBox(height: AppSpacing.md),
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
    final completed = members.where((task) => task.isDone).length;
    final compact =
        WorkbenchViewport.sizeOf(context).width < AppBreakpoints.compact;
    final accent = context.accents.moss;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final expanded = _expandedGroupIds.contains(group.id);
    final visibleMembers = !_renderedGroupIds.contains(group.id)
        ? const <TaskHierarchyEntry>[]
        : sequential
        ? [
            for (final task in members)
              TaskHierarchyEntry(
                task: task,
                depth: 0,
                hasChildren: false,
                expanded: true,
                relation: taskRelationInfo(task, widget.controller.tasks),
              ),
          ]
        : buildTaskHierarchy(
            visibleTasks: members,
            allRecords: widget.controller.tasks,
            collapsedIds: _collapsedTaskIds,
            rootTaskId: _rootTaskIds[group.id],
            maxDepth: compact ? 2 : 4,
          );
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: ExpansionTile(
        key: ValueKey('task-group-${group.id}'),
        controller: _groupControllers.putIfAbsent(
          group.id,
          ExpansibleController.new,
        ),
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
          reverseDuration: reducedMotion ? Duration.zero : AppMotion.standard,
        ),
        onExpansionChanged: (value) => _setGroupExpanded(group.id, value),
        leading: JadeIcon(glyph: JadeGlyph.groups, color: accent.color),
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
              '${sequential ? '顺序任务链' : '并行任务群'} · 已完成 $completed/${members.length}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontSize: 13,
                color: context.tokens.mutedText,
              ),
            ),
            if (members.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              _GroupMemberTrack(members: members, sequential: sequential),
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
            if (!compact)
              IconButton(
                onPressed: () => _addMember(group),
                tooltip: '添加任务',
                icon: const Icon(Icons.playlist_add),
              ),
            PopupMenuButton<String>(
              tooltip: '任务群操作',
              onSelected: (value) {
                if (value == 'add') _addMember(group);
                if (value == 'edit') _editGroup(group);
                if (value == 'trash') _deleteGroup(group);
              },
              itemBuilder: (context) => [
                if (compact)
                  const PopupMenuItem(
                    value: 'add',
                    child: ListTile(
                      leading: Icon(Icons.playlist_add),
                      title: Text('添加任务'),
                    ),
                  ),
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('编辑任务群'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'trash',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline),
                    title: Text('移入回收站'),
                  ),
                ),
              ],
            ),
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              color: context.tokens.mutedText,
            ),
          ],
        ),
        children: _renderedGroupIds.contains(group.id)
            ? [
                if (members.isEmpty) const ListTile(title: Text('群内暂无任务')),
                if (!sequential && _rootTaskIds[group.id] != null)
                  TaskHierarchyNavigation(
                    path: taskHierarchyPath(_rootTaskIds[group.id]!, members),
                    onSelected: (id) => _selectHierarchyRoot(group.id, id),
                  ),
                for (var index = 0; index < visibleMembers.length; index++)
                  Builder(
                    builder: (context) {
                      final entry = visibleMembers[index];
                      final task = entry.task;
                      final memberId = '${group.id}:${task.id}';
                      final rowKey = _memberKeys.putIfAbsent(
                        memberId,
                        GlobalKey.new,
                      );
                      final focusNode = _memberFocusNodes.putIfAbsent(
                        memberId,
                        () =>
                            FocusNode(debugLabel: 'TaskGroupMember.${task.id}'),
                      );
                      final memberIndex = sequential
                          ? index
                          : members.indexWhere(
                              (member) => member.id == task.id,
                            );
                      final locked = widget.controller.isTaskGroupMemberLocked(
                        task,
                        group,
                      );
                      final compact =
                          WorkbenchViewport.sizeOf(context).width <
                          AppBreakpoints.compact;
                      Future<void> edit() => showRecordEditor(
                        context,
                        widget.controller,
                        kind: RecordKind.task,
                        record: task,
                      );
                      return TweenAnimationBuilder<double>(
                        key: ValueKey('group-member-$memberId'),
                        tween: Tween(
                          begin: _newMemberIds.contains(memberId) ? 0 : 1,
                          end: 1,
                        ),
                        duration:
                            _newMemberIds.contains(memberId) && !reducedMotion
                            ? AppMotion.standard
                            : Duration.zero,
                        builder: (context, opacity, child) =>
                            Opacity(opacity: opacity, child: child),
                        child: Container(
                          key: rowKey,
                          margin: EdgeInsets.only(
                            left: entry.depth * (compact ? 16 : 20).toDouble(),
                          ),
                          decoration: entry.depth == 0
                              ? null
                              : BoxDecoration(
                                  border: Border(
                                    left: BorderSide(
                                      color: accent.color.withValues(
                                        alpha: 0.35,
                                      ),
                                    ),
                                  ),
                                ),
                          child: ListTile(
                            focusNode: focusNode,
                            leading: entry.hasChildren
                                ? IconButton(
                                    tooltip: entry.canDrill
                                        ? '进入子层'
                                        : entry.expanded
                                        ? '收起子任务'
                                        : '展开子任务',
                                    onPressed: () {
                                      if (entry.canDrill) {
                                        _selectHierarchyRoot(group.id, task.id);
                                        return;
                                      }
                                      setState(() {
                                        if (entry.expanded) {
                                          _collapsedTaskIds.add(task.id);
                                        } else {
                                          _collapsedTaskIds.remove(task.id);
                                        }
                                      });
                                    },
                                    icon: Icon(
                                      entry.canDrill
                                          ? Icons.subdirectory_arrow_right
                                          : entry.expanded
                                          ? Icons.expand_less
                                          : Icons.expand_more,
                                      color: accent.color,
                                    ),
                                  )
                                : CircleAvatar(
                                    backgroundColor: accent.container,
                                    foregroundColor: accent.color,
                                    child: locked
                                        ? const Icon(
                                            Icons.lock_outline,
                                            size: 18,
                                          )
                                        : Text('${memberIndex + 1}'),
                                  ),
                            title: Row(
                              children: [
                                Icon(
                                  entry.hasChildren
                                      ? Icons.park_outlined
                                      : Icons.eco_outlined,
                                  size: AppIconSize.xs,
                                  color: accent.color,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Expanded(
                                  child: Text(
                                    task.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontSize: 15),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              [
                                locked ? '前置任务尚未通过' : statusLabel(task.status),
                                if (entry.depth >= 3 &&
                                    entry.relation.path.isNotEmpty)
                                  entry.relation.path.join(' › '),
                                if (entry.relation.isWarning)
                                  entry.relation.label ?? '',
                              ].join(' · '),
                            ),
                            onTap: edit,
                            trailing: compact
                                ? PopupMenuButton<_MemberAction>(
                                    tooltip: '更多操作',
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: _MemberAction.edit,
                                        child: Text('编辑任务'),
                                      ),
                                      if (sequential)
                                        PopupMenuItem(
                                          value: _MemberAction.moveUp,
                                          enabled: widget.controller
                                              .taskGroupMemberCanMove(
                                                task,
                                                group,
                                                memberIndex - 1,
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
                                                memberIndex + 1,
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
                                        case _MemberAction.edit:
                                          edit();
                                        case _MemberAction.moveUp:
                                          _moveMember(
                                            group,
                                            task,
                                            memberIndex - 1,
                                          );
                                        case _MemberAction.moveDown:
                                          _moveMember(
                                            group,
                                            task,
                                            memberIndex + 1,
                                          );
                                        case _MemberAction.skipAndContinue:
                                          widget.controller
                                              .skipTaskAndContinueChain(task);
                                        case _MemberAction.remove:
                                          _removeMember(group, task);
                                      }
                                    },
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (sequential) ...[
                                        IconButton(
                                          tooltip: '上移',
                                          onPressed:
                                              widget.controller
                                                  .taskGroupMemberCanMove(
                                                    task,
                                                    group,
                                                    memberIndex - 1,
                                                  )
                                              ? () => _moveMember(
                                                  group,
                                                  task,
                                                  memberIndex - 1,
                                                )
                                              : null,
                                          icon: const Icon(Icons.arrow_upward),
                                        ),
                                        IconButton(
                                          tooltip: '下移',
                                          onPressed:
                                              widget.controller
                                                  .taskGroupMemberCanMove(
                                                    task,
                                                    group,
                                                    memberIndex + 1,
                                                  )
                                              ? () => _moveMember(
                                                  group,
                                                  task,
                                                  memberIndex + 1,
                                                )
                                              : null,
                                          icon: const Icon(
                                            Icons.arrow_downward,
                                          ),
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
                                        onPressed: () =>
                                            _removeMember(group, task),
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
              ]
            : const [],
      ),
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
      builder: (context) => AlertDialog(
        title: const Text('添加现有任务'),
        content: SizedBox(
          width: 480,
          height: (candidates.length * 64.0).clamp(
            80.0,
            (MediaQuery.sizeOf(context).height * 0.55).clamp(180.0, 360.0),
          ),
          child: candidates.isEmpty
              ? const Center(child: Text('没有可添加的任务'))
              : ListView.builder(
                  itemCount: candidates.length,
                  itemBuilder: (context, index) => ListTile(
                    title: Text(candidates[index].title),
                    onTap: () => Navigator.pop(context, candidates[index]),
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
    if (selected == null) return;
    try {
      await widget.controller.addTaskToGroup(task: selected, group: group);
      if (!mounted) return;
      final path = taskHierarchyPath(
        selected.id,
        widget.controller.groupMembers(group.id),
      );
      final memberId = '${group.id}:${selected.id}';
      setState(() {
        _newMemberIds.add(memberId);
        _expandedGroupIds.add(group.id);
        _renderedGroupIds.add(group.id);
        for (final task in path) {
          _collapsedTaskIds.remove(task.id);
        }
        if (path.length > 3) {
          _rootTaskIds[group.id] = path[path.length - 2].id;
        } else {
          _rootTaskIds.remove(group.id);
        }
      });
      _groupControllers[group.id]?.expand();
      _entryTimers.remove(memberId)?.cancel();
      _entryTimers[memberId] = Timer(AppMotion.standard, () {
        _entryTimers.remove(memberId);
        _newMemberIds.remove(memberId);
      });
      final reducedMotion = MediaQuery.disableAnimationsOf(context);
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!reducedMotion) await Future<void>.delayed(AppMotion.standard);
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
        final rowContext = _memberKeys[memberId]?.currentContext;
        if (rowContext == null || !rowContext.mounted) return;
        await Scrollable.ensureVisible(
          rowContext,
          duration: reducedMotion
              ? Duration.zero
              : const Duration(milliseconds: 160),
          alignment: 0.4,
        );
        if (mounted) _memberFocusNodes[memberId]?.requestFocus();
      });
      showWorkbenchSnackBar(
        context,
        SnackBar(content: Text('已添加“${selected.title}”')),
      );
    } on FormatException catch (error) {
      if (mounted) {
        showWorkbenchSnackBar(context, SnackBar(content: Text(error.message)));
      }
    }
  }
}
