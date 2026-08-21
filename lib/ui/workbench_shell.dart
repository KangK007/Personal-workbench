import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

import '../core/models/workspace_record.dart';
import '../core/theme/app_theme.dart';
import '../state/workbench_controller.dart';
import 'pages/focus_page.dart';
import 'pages/growth_page.dart';
import 'pages/goals_page.dart';
import 'pages/habits_page.dart';
import 'pages/diary_page.dart';
import 'pages/notes_page.dart';
import 'pages/plan_page.dart';
import 'pages/policies_page.dart';
import 'pages/projects_page.dart';
import 'pages/protocols_page.dart';
import 'pages/review_page.dart';
import 'pages/restriction_page.dart';
import 'pages/settings_page.dart';
import 'pages/today_page.dart';
import 'widgets/global_search_dialog.dart';
import 'widgets/common.dart';
import 'widgets/glass.dart';
import 'widgets/ink_decoration.dart';
import 'widgets/quick_capture_sheet.dart';

enum WorkbenchSection {
  today,
  tasksAll,
  tasksInbox,
  tasksWeek,
  tasksGroups,
  projectsOverview,
  projectsTasks,
  projectsGroups,
  projectsMilestones,
  projectsNotes,
  focus,
  restriction,
  notes,
  diary,
  reviewDaily,
  reviewWeekly,
  reviewMonthly,
  policiesTree,
  policiesLibrary,
  policiesHistory,
  policiesAnalytics,
  goals,
  habits,
  growth,
  settings,

  // Legacy targets remain as compatibility aliases and are normalized in _select.
  tasks,
  projects,
  review,
  policies,
  plan,
  protocols,
  inbox,
  calendar,
}

const _taskSections = {
  WorkbenchSection.tasksAll,
  WorkbenchSection.tasksInbox,
  WorkbenchSection.tasksWeek,
  WorkbenchSection.tasksGroups,
};
const _reviewSections = {
  WorkbenchSection.reviewDaily,
  WorkbenchSection.reviewWeekly,
  WorkbenchSection.reviewMonthly,
};
const _policySections = {
  WorkbenchSection.policiesTree,
  WorkbenchSection.policiesLibrary,
  WorkbenchSection.policiesHistory,
  WorkbenchSection.policiesAnalytics,
};
const _projectSections = {
  WorkbenchSection.projectsOverview,
  WorkbenchSection.projectsTasks,
  WorkbenchSection.projectsGroups,
  WorkbenchSection.projectsMilestones,
  WorkbenchSection.projectsNotes,
};

class WorkbenchShell extends StatefulWidget {
  const WorkbenchShell({
    super.key,
    required this.controller,
    this.enableSystemHotkey = true,
  });

  final WorkbenchController controller;
  final bool enableSystemHotkey;

  @override
  State<WorkbenchShell> createState() => _WorkbenchShellState();
}

class _WorkbenchShellState extends State<WorkbenchShell> {
  static const _mobilePrimarySections = [
    WorkbenchSection.today,
    WorkbenchSection.tasksAll,
    WorkbenchSection.reviewDaily,
    WorkbenchSection.policiesTree,
    WorkbenchSection.settings,
  ];

  WorkbenchSection section = WorkbenchSection.today;
  ProtocolTab protocolTab = ProtocolTab.goals;
  String? selectedProjectId;
  HotKey? captureHotKey;
  final Set<WorkbenchSection> _visitedSections = {WorkbenchSection.today};
  final List<WorkbenchSection> _mobileHistory = [];
  WorkbenchSection _lastMobilePrimary = WorkbenchSection.today;
  final Map<WorkbenchSection, WorkbenchSection> _lastMobileChild = {
    WorkbenchSection.tasksAll: WorkbenchSection.tasksAll,
    WorkbenchSection.reviewDaily: WorkbenchSection.reviewDaily,
    WorkbenchSection.policiesTree: WorkbenchSection.policiesTree,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.enableSystemHotkey &&
          Platform.isWindows &&
          defaultTargetPlatform == TargetPlatform.windows) {
        _registerHotKey();
      }
      _showGameFeaturesPrompt();
    });
  }

  Future<void> _showGameFeaturesPrompt() async {
    if (!mounted || !widget.controller.gameFeaturesPromptPending) return;
    final enable = await showWorkbenchDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('开启本地激励？'),
        content: const Text('签到、虚拟积分和专注押注只保存在本机。你可以稍后在设置中关闭展示，已有工作台数据不会改变。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('暂不开启'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('开启'),
          ),
        ],
      ),
    );
    if (enable != null) {
      await widget.controller.answerGameFeaturesPrompt(enable: enable);
    }
  }

  @override
  void dispose() {
    final hotKey = captureHotKey;
    if (hotKey != null) hotKeyManager.unregister(hotKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final width = MediaQuery.sizeOf(context).width;
        final compact = width < AppBreakpoints.compact;
        final compactNavigation = width < AppBreakpoints.expanded;
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
                showGlobalSearch(
                  context,
                  widget.controller,
                  initialKind: section == WorkbenchSection.notes
                      ? RecordKind.note
                      : null,
                ),
          },
          child: Focus(
            autofocus: true,
            child: compact
                ? _mobileLayout()
                : _desktopLayout(compactNavigation: compactNavigation),
          ),
        );
      },
    );
  }

  Widget _desktopLayout({required bool compactNavigation}) {
    final collapsed =
        compactNavigation || widget.controller.navigationCollapsed;
    return Scaffold(
      body: Stack(
        children: [
          Row(
            children: [
              AnimatedContainer(
                width: collapsed ? 80 : 220,
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                child: _DesktopNavigation(
                  selected: section,
                  collapsed: collapsed,
                  controller: widget.controller,
                  onSelected: _select,
                  onCapture: _shouldShowPersistentAdd ? _openCapture : null,
                  onSearch: () => showGlobalSearch(
                    context,
                    widget.controller,
                    initialKind: section == WorkbenchSection.notes
                        ? RecordKind.note
                        : null,
                  ),
                  allowCollapseToggle: !compactNavigation,
                  onToggleCollapsed: () =>
                      widget.controller.setNavigationCollapsed(!collapsed),
                ),
              ),
              const VerticalDivider(),
              Expanded(
                child: SafeArea(child: WorkbenchBackdrop(child: _pageStack())),
              ),
            ],
          ),
        ],
      ),
    );
  }

  WorkbenchSection? _mobilePrimaryFor(WorkbenchSection value) {
    if (_taskSections.contains(value)) {
      return WorkbenchSection.tasksAll;
    }
    if (_projectSections.contains(value)) {
      return WorkbenchSection.projectsOverview;
    }
    if (_reviewSections.contains(value)) {
      return WorkbenchSection.reviewDaily;
    }
    if (_policySections.contains(value)) {
      return WorkbenchSection.policiesTree;
    }
    if (_mobilePrimarySections.contains(value)) {
      return value;
    }
    return null;
  }

  Widget _mobileLayout() {
    final primary = _mobilePrimaryFor(section) ?? _lastMobilePrimary;
    final index = _mobilePrimarySections.indexOf(primary);
    // Project detail pages are reachable from 更多 but are not bottom
    // destinations; keep NavigationBar on a valid neutral index.
    final navigationIndex = index < 0 ? 0 : index;
    final title = switch (section) {
      WorkbenchSection.today => '今日',
      WorkbenchSection.tasksAll => '任务 · 全部',
      WorkbenchSection.tasksInbox => '任务 · 收件箱',
      WorkbenchSection.tasksWeek => '任务 · 周视图',
      WorkbenchSection.tasksGroups => '任务 · 任务群',
      WorkbenchSection.projectsOverview => '项目 · 概览',
      WorkbenchSection.projectsTasks => '项目 · 任务',
      WorkbenchSection.projectsGroups => '项目 · 任务群',
      WorkbenchSection.projectsMilestones => '项目 · 里程碑',
      WorkbenchSection.projectsNotes => '项目 · 笔记与回顾',
      WorkbenchSection.focus => '专注',
      WorkbenchSection.restriction => '自律',
      WorkbenchSection.notes => '笔记',
      WorkbenchSection.diary => '日记',
      WorkbenchSection.reviewDaily => '回顾 · 日回顾',
      WorkbenchSection.reviewWeekly => '回顾 · 周回顾',
      WorkbenchSection.reviewMonthly => '回顾 · 月回顾',
      WorkbenchSection.policiesTree => '国策 · 国策树',
      WorkbenchSection.policiesLibrary => '国策 · 国策库',
      WorkbenchSection.policiesHistory => '国策 · 轮次历史',
      WorkbenchSection.policiesAnalytics => '国策 · 高级分析',
      WorkbenchSection.goals => '目标与习惯 · 目标',
      WorkbenchSection.habits => '目标与习惯 · 习惯',
      WorkbenchSection.growth => '成长',
      WorkbenchSection.settings => '设置',
      _ => '个人工作台',
    };
    final theme = Theme.of(context);
    final tokens = context.tokens;
    return PopScope(
      canPop: _mobileHistory.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _mobileHistory.isEmpty) return;
        final previous = _mobileHistory.removeLast();
        setState(() {
          section = previous;
          _visitedSections.add(previous);
        });
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 56,
          titleSpacing: 8,
          leading: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Center(child: SealLogo(size: 30)),
          ),
          title: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            IconButton(
              onPressed: () => showGlobalSearch(
                context,
                widget.controller,
                initialKind: section == WorkbenchSection.notes
                    ? RecordKind.note
                    : null,
              ),
              tooltip: '全局搜索',
              icon: const Icon(Icons.search),
            ),
            IconButton(
              tooltip: '更多',
              icon: const Icon(Icons.apps_outlined),
              onPressed: () => _openMobileNavigation(context),
            ),
          ],
          flexibleSpace: GlassConfig.blurEnabled
              ? ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: tokens.glassBlur,
                      sigmaY: tokens.glassBlur,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: tokens.glassPanel,
                        border: Border(
                          top: BorderSide(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.08,
                            ),
                          ),
                          bottom: BorderSide(color: tokens.divider),
                        ),
                      ),
                    ),
                  ),
                )
              : DecoratedBox(
                  decoration: BoxDecoration(
                    color: tokens.panel.withValues(alpha: 0.96),
                    border: Border(
                      top: BorderSide(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.08,
                        ),
                      ),
                      bottom: BorderSide(color: tokens.divider),
                    ),
                  ),
                ),
        ),
        body: SafeArea(
          top: false,
          child: WorkbenchBackdrop(child: _pageStack(slidable: true)),
        ),
        floatingActionButton: _shouldShowPersistentAdd
            ? FloatingActionButton.small(
                onPressed: _openCapture,
                tooltip: '快速新增',
                child: const Icon(Icons.add),
              )
            : null,
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 同步状态指示器 — 与桌面侧栏底部同步状态对齐
            Container(
              height: 26,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: tokens.glassPanel,
                border: Border(top: BorderSide(color: tokens.divider)),
              ),
              child: Stack(
                children: [
                  // 底部 1px 主色微高光 — 分隔同步状态与底部导航
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary.withValues(alpha: 0.10),
                            theme.colorScheme.primary.withValues(alpha: 0.02),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        widget.controller.cloudConfigured
                            ? Icons.cloud_outlined
                            : Icons.cloud_off_outlined,
                        size: 13,
                        color: tokens.mutedText,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          widget.controller.syncMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: tokens.mutedText,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            NavigationBar(
              selectedIndex: navigationIndex,
              onDestinationSelected: (value) => _select(
                _lastMobileChild[_mobilePrimarySections[value]] ??
                    _mobilePrimarySections[value],
              ),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.today_outlined),
                  selectedIcon: Icon(Icons.today),
                  label: '今日',
                ),
                NavigationDestination(
                  icon: Icon(Icons.checklist_outlined),
                  selectedIcon: Icon(Icons.checklist),
                  label: '任务',
                ),
                NavigationDestination(
                  icon: Icon(Icons.insights_outlined),
                  selectedIcon: Icon(Icons.insights),
                  label: '回顾',
                ),
                NavigationDestination(
                  icon: Icon(Icons.account_tree_outlined),
                  selectedIcon: Icon(Icons.account_tree),
                  label: '国策',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: '设置',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pageStack({bool slidable = false}) => _SectionTransition(
    sectionIndex: WorkbenchSection.values.indexOf(section),
    slidable: slidable,
    child: IndexedStack(
      index: WorkbenchSection.values.indexOf(section),
      children: [
        for (final value in WorkbenchSection.values)
          _visitedSections.contains(value)
              ? _buildPage(value)
              : const SizedBox.shrink(),
      ],
    ),
  );

  bool get _showPageHeader =>
      MediaQuery.sizeOf(context).width >= AppBreakpoints.compact;

  Widget _planPage(WorkbenchSection value, PlanTab tab) => PlanPage(
    key: ValueKey(value),
    controller: widget.controller,
    initialTab: tab,
    showHeader: _showPageHeader,
    showTabs: false,
  );

  Widget _projectPage(WorkbenchSection value, ProjectDetailTab tab) =>
      ProjectsPage(
        key: ValueKey(value),
        controller: widget.controller,
        initialTab: tab,
        showHeader: _showPageHeader,
        showTabs: false,
        selectedProjectId: selectedProjectId,
        onProjectSelected: (id) {
          if (selectedProjectId != id) setState(() => selectedProjectId = id);
        },
      );

  Widget _reviewPage(WorkbenchSection value, ReviewTab tab) => ReviewPage(
    key: ValueKey(value),
    controller: widget.controller,
    initialTab: tab,
    showHeader: _showPageHeader,
    showPeriodSwitcher: false,
  );

  Widget _policyPage(WorkbenchSection value, PolicyTab tab) => PoliciesPage(
    key: ValueKey(value),
    controller: widget.controller,
    initialTab: tab,
    showHeader: _showPageHeader,
    showTabs: false,
  );

  Widget _buildPage(WorkbenchSection value) => switch (value) {
    WorkbenchSection.today => TodayPage(
      controller: widget.controller,
      showHeader: _showPageHeader,
      onOpenPlan: () => _select(WorkbenchSection.tasksAll),
      onOpenInbox: () => _select(WorkbenchSection.tasksInbox),
      onOpenReview: () => _select(WorkbenchSection.reviewDaily),
    ),
    WorkbenchSection.tasksAll => _planPage(value, PlanTab.all),
    WorkbenchSection.tasksInbox => _planPage(value, PlanTab.inbox),
    WorkbenchSection.tasksWeek => _planPage(value, PlanTab.week),
    WorkbenchSection.tasksGroups => _planPage(value, PlanTab.groups),
    WorkbenchSection.projectsOverview => _projectPage(
      value,
      ProjectDetailTab.overview,
    ),
    WorkbenchSection.projectsTasks => _projectPage(
      value,
      ProjectDetailTab.tasks,
    ),
    WorkbenchSection.projectsGroups => _projectPage(
      value,
      ProjectDetailTab.groups,
    ),
    WorkbenchSection.projectsMilestones => _projectPage(
      value,
      ProjectDetailTab.milestones,
    ),
    WorkbenchSection.projectsNotes => _projectPage(
      value,
      ProjectDetailTab.notes,
    ),
    WorkbenchSection.focus => FocusHubPage(
      controller: widget.controller,
      showHeader: _showPageHeader,
    ),
    WorkbenchSection.restriction => RestrictionPage(
      controller: widget.controller,
      showHeader: _showPageHeader,
      onOpenSettings: () => _select(WorkbenchSection.settings),
    ),
    WorkbenchSection.notes => NotesPage(
      controller: widget.controller,
      showHeader: _showPageHeader,
    ),
    WorkbenchSection.diary => DiaryPage(
      controller: widget.controller,
      showHeader: _showPageHeader,
    ),
    WorkbenchSection.reviewDaily => _reviewPage(value, ReviewTab.diary),
    WorkbenchSection.reviewWeekly => _reviewPage(value, ReviewTab.weekly),
    WorkbenchSection.reviewMonthly => _reviewPage(value, ReviewTab.monthly),
    WorkbenchSection.policiesTree => _policyPage(value, PolicyTab.tree),
    WorkbenchSection.policiesLibrary => _policyPage(value, PolicyTab.library),
    WorkbenchSection.policiesHistory => _policyPage(value, PolicyTab.history),
    WorkbenchSection.policiesAnalytics => _policyPage(
      value,
      PolicyTab.analytics,
    ),
    WorkbenchSection.goals => GoalsPage(
      controller: widget.controller,
      showHeader: _showPageHeader,
    ),
    WorkbenchSection.habits => HabitsPage(
      controller: widget.controller,
      showHeader: _showPageHeader,
    ),
    WorkbenchSection.growth => GrowthPage(
      controller: widget.controller,
      showHeader: _showPageHeader,
    ),
    WorkbenchSection.settings => SettingsPage(
      controller: widget.controller,
      showHeader: _showPageHeader,
    ),
    WorkbenchSection.protocols => ProtocolsPage(
      key: ValueKey(
        '${widget.controller.advancedFeaturesEnabled}:$protocolTab',
      ),
      controller: widget.controller,
      initialTab: protocolTab,
      showHeader: _showPageHeader,
    ),
    _ => const SizedBox.shrink(),
  };

  void _select(WorkbenchSection value) {
    value = switch (value) {
      WorkbenchSection.tasks || WorkbenchSection.plan =>
        _lastMobileChild[WorkbenchSection.tasksAll] ??
            WorkbenchSection.tasksAll,
      WorkbenchSection.inbox => WorkbenchSection.tasksInbox,
      WorkbenchSection.calendar => WorkbenchSection.tasksWeek,
      WorkbenchSection.projects => WorkbenchSection.projectsOverview,
      WorkbenchSection.review =>
        _lastMobileChild[WorkbenchSection.reviewDaily] ??
            WorkbenchSection.reviewDaily,
      WorkbenchSection.policies =>
        _lastMobileChild[WorkbenchSection.policiesTree] ??
            WorkbenchSection.policiesTree,
      WorkbenchSection.protocols => WorkbenchSection.goals,
      _ => value,
    };
    final parentId = _navigationParentId(value);
    if (parentId != null) {
      widget.controller.setNavigationGroupExpanded(parentId, true);
    }
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    setState(() {
      if (compact && value != section) {
        if (_mobileHistory.isEmpty || _mobileHistory.last != section) {
          _mobileHistory.add(section);
        }
      }
      final primary = _mobilePrimaryFor(value);
      if (primary != null) {
        _lastMobilePrimary = primary;
        if (_taskSections.contains(value) ||
            _reviewSections.contains(value) ||
            _policySections.contains(value)) {
          _lastMobileChild[primary] = value;
        }
      }
      section = value;
      _visitedSections.add(value);
    });
  }

  Future<void> _openMobileNavigation(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _MobileNavigationSheet(
        selected: section,
        controller: widget.controller,
        onSelected: (value) {
          Navigator.pop(context);
          _select(value);
        },
        onParentSelected: (value) {
          Navigator.pop(context);
          _select(value);
        },
      ),
    );
  }

  bool get _shouldShowPersistentAdd =>
      !(section == WorkbenchSection.today && widget.controller.tasks.isEmpty);

  Future<void> _openCapture() {
    final initialKind = section == WorkbenchSection.notes
        ? RecordKind.note
        : RecordKind.task;
    final today = section == WorkbenchSection.today;
    return showQuickCapture(
      context,
      widget.controller,
      initialKind: initialKind,
      initialScheduledFor: today ? widget.controller.currentTime() : null,
      initialStatus: today ? WorkStatus.todo : null,
    );
  }

  Future<void> _registerHotKey() async {
    final hotKey = HotKey(
      key: PhysicalKeyboardKey.space,
      modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
      scope: HotKeyScope.system,
    );
    try {
      await hotKeyManager.register(
        hotKey,
        keyDownHandler: (_) {
          if (mounted) showQuickCapture(context, widget.controller);
        },
      );
      captureHotKey = hotKey;
    } catch (error) {
      // The app remains usable if another program owns the shortcut.
      debugPrint('Unable to register quick capture shortcut: $error');
    }
  }
}

class _NavigationNode {
  const _NavigationNode.leaf(this.section, this.label, this.icon)
    : id = null,
      children = const [];

  const _NavigationNode.parent(this.id, this.label, this.icon, this.children)
    : section = null;

  final String? id;
  final WorkbenchSection? section;
  final String label;
  final IconData icon;
  final List<_NavigationNode> children;

  bool get isLeaf => children.isEmpty;
}

const _navigationTree = [
  _NavigationNode.leaf(WorkbenchSection.today, '今日', Icons.today_outlined),
  _NavigationNode.parent('tasks', '任务', Icons.checklist_outlined, [
    _NavigationNode.leaf(
      WorkbenchSection.tasksAll,
      '全部',
      Icons.checklist_outlined,
    ),
    _NavigationNode.leaf(
      WorkbenchSection.tasksInbox,
      '收件箱',
      Icons.inbox_outlined,
    ),
    _NavigationNode.leaf(
      WorkbenchSection.tasksWeek,
      '周视图',
      Icons.calendar_view_week_outlined,
    ),
    _NavigationNode.leaf(
      WorkbenchSection.tasksGroups,
      '任务群',
      Icons.account_tree_outlined,
    ),
  ]),
  _NavigationNode.parent('projects', '项目', Icons.folder_outlined, [
    _NavigationNode.leaf(
      WorkbenchSection.projectsOverview,
      '概览',
      Icons.dashboard_outlined,
    ),
    _NavigationNode.leaf(
      WorkbenchSection.projectsTasks,
      '任务',
      Icons.checklist_outlined,
    ),
    _NavigationNode.leaf(
      WorkbenchSection.projectsGroups,
      '任务群',
      Icons.account_tree_outlined,
    ),
    _NavigationNode.leaf(
      WorkbenchSection.projectsMilestones,
      '里程碑',
      Icons.flag_outlined,
    ),
    _NavigationNode.leaf(
      WorkbenchSection.projectsNotes,
      '笔记与回顾',
      Icons.library_books_outlined,
    ),
  ]),
  _NavigationNode.leaf(WorkbenchSection.focus, '专注', Icons.timer_outlined),
  _NavigationNode.leaf(
    WorkbenchSection.restriction,
    '自律',
    Icons.shield_outlined,
  ),
  _NavigationNode.leaf(WorkbenchSection.notes, '笔记', Icons.note_alt_outlined),
  _NavigationNode.leaf(WorkbenchSection.diary, '日记', Icons.book_outlined),
  _NavigationNode.parent('review', '回顾', Icons.insights_outlined, [
    _NavigationNode.leaf(
      WorkbenchSection.reviewDaily,
      '日回顾',
      Icons.today_outlined,
    ),
    _NavigationNode.leaf(
      WorkbenchSection.reviewWeekly,
      '周回顾',
      Icons.date_range_outlined,
    ),
    _NavigationNode.leaf(
      WorkbenchSection.reviewMonthly,
      '月回顾',
      Icons.calendar_month_outlined,
    ),
  ]),
  _NavigationNode.parent('policies', '国策', Icons.account_tree_outlined, [
    _NavigationNode.leaf(
      WorkbenchSection.policiesTree,
      '国策树',
      Icons.account_tree_outlined,
    ),
    _NavigationNode.leaf(
      WorkbenchSection.policiesLibrary,
      '国策库',
      Icons.inventory_2_outlined,
    ),
    _NavigationNode.leaf(
      WorkbenchSection.policiesHistory,
      '轮次历史',
      Icons.history_outlined,
    ),
    _NavigationNode.leaf(
      WorkbenchSection.policiesAnalytics,
      '高级分析',
      Icons.analytics_outlined,
    ),
  ]),
  _NavigationNode.parent('goals_habits', '目标与习惯', Icons.flag_outlined, [
    _NavigationNode.leaf(WorkbenchSection.goals, '目标', Icons.flag_outlined),
    _NavigationNode.leaf(WorkbenchSection.habits, '习惯', Icons.repeat),
  ]),
  _NavigationNode.leaf(
    WorkbenchSection.growth,
    '成长',
    Icons.trending_up_outlined,
  ),
  _NavigationNode.leaf(
    WorkbenchSection.settings,
    '设置',
    Icons.settings_outlined,
  ),
];

String? _navigationParentId(WorkbenchSection value) => switch (value) {
  WorkbenchSection.tasksAll ||
  WorkbenchSection.tasksInbox ||
  WorkbenchSection.tasksWeek ||
  WorkbenchSection.tasksGroups => 'tasks',
  WorkbenchSection.projectsOverview ||
  WorkbenchSection.projectsTasks ||
  WorkbenchSection.projectsGroups ||
  WorkbenchSection.projectsMilestones ||
  WorkbenchSection.projectsNotes => 'projects',
  WorkbenchSection.reviewDaily ||
  WorkbenchSection.reviewWeekly ||
  WorkbenchSection.reviewMonthly => 'review',
  WorkbenchSection.policiesTree ||
  WorkbenchSection.policiesLibrary ||
  WorkbenchSection.policiesHistory ||
  WorkbenchSection.policiesAnalytics => 'policies',
  WorkbenchSection.goals || WorkbenchSection.habits => 'goals_habits',
  _ => null,
};

class _DesktopNavigation extends StatelessWidget {
  const _DesktopNavigation({
    required this.selected,
    required this.collapsed,
    required this.controller,
    required this.onSelected,
    required this.onCapture,
    required this.onSearch,
    required this.allowCollapseToggle,
    required this.onToggleCollapsed,
  });

  final WorkbenchSection selected;
  final bool collapsed;
  final WorkbenchController controller;
  final ValueChanged<WorkbenchSection> onSelected;
  final VoidCallback? onCapture;
  final VoidCallback onSearch;
  final bool allowCollapseToggle;
  final VoidCallback onToggleCollapsed;
  @override
  Widget build(BuildContext context) {
    final expanded =
        MediaQuery.sizeOf(context).width >= AppBreakpoints.expanded;
    return WorkbenchBackdrop(
      child: GlassSurface(
        radius: 0,
        glow: false,
        child: SafeArea(
          child: Column(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: context.tokens.glassHighlight.withValues(alpha: 0.28),
                  border: Border(
                    bottom: BorderSide(color: context.tokens.divider),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    collapsed
                        ? 16
                        : expanded
                        ? 28
                        : 18,
                    expanded ? 22 : 14,
                    collapsed
                        ? 16
                        : expanded
                        ? 24
                        : 14,
                    expanded ? 16 : 10,
                  ),
                  child: Row(
                    children: [
                      SealLogo(size: expanded ? 48 : 32),
                      if (!collapsed) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '个人工作台',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontSize: expanded ? 20 : null),
                              ),
                              Text(
                                controller.profileAlias.isEmpty
                                    ? '个人工作空间'
                                    : controller.profileAlias,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: context.tokens.mutedText),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (!collapsed && allowCollapseToggle)
                        IconButton(
                          onPressed: onToggleCollapsed,
                          tooltip: '收起导航',
                          icon: const Icon(Icons.keyboard_double_arrow_left),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: collapsed
                      ? 10
                      : expanded
                      ? 28
                      : 14,
                ),
                child: collapsed
                    ? Column(
                        children: [
                          if (onCapture != null) ...[
                            IconButton(
                              onPressed: onCapture,
                              tooltip: '快速新增',
                              icon: const Icon(Icons.add),
                            ),
                            const SizedBox(height: 4),
                          ],
                          IconButton(
                            onPressed: onSearch,
                            tooltip: '全局搜索',
                            icon: const Icon(Icons.search),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          if (onCapture != null) ...[
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48),
                                ),
                                onPressed: onCapture,
                                icon: const Icon(Icons.add),
                                label: const Text('快速新增'),
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                              ),
                              onPressed: onSearch,
                              icon: const Icon(Icons.search),
                              label: const Text('全局搜索'),
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 10),
              const Divider(),
              Expanded(
                child: Scrollbar(
                  child: ListView(
                    cacheExtent: 10000,
                    padding: EdgeInsets.fromLTRB(
                      collapsed
                          ? 7
                          : expanded
                          ? 20
                          : 10,
                      10,
                      collapsed
                          ? 7
                          : expanded
                          ? 20
                          : 10,
                      12,
                    ),
                    children: [
                      Column(
                        children: [
                          for (final node in _navigationTree)
                            _node(context, node),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  collapsed
                      ? 16
                      : expanded
                      ? 28
                      : 14,
                  10,
                  collapsed
                      ? 16
                      : expanded
                      ? 28
                      : 14,
                  12,
                ),
                child: collapsed
                    ? Tooltip(
                        message: controller.syncMessage,
                        child: Icon(
                          controller.cloudConfigured
                              ? Icons.cloud_outlined
                              : Icons.cloud_off_outlined,
                          size: 19,
                          color: context.tokens.mutedText,
                        ),
                      )
                    : Row(
                        children: [
                          Icon(
                            controller.cloudConfigured
                                ? Icons.cloud_outlined
                                : Icons.cloud_off_outlined,
                            size: 18,
                            color: context.tokens.mutedText,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              controller.syncMessage,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: context.tokens.mutedText),
                            ),
                          ),
                        ],
                      ),
              ),
              if (collapsed && allowCollapseToggle)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: IconButton(
                    onPressed: onToggleCollapsed,
                    tooltip: '展开导航',
                    icon: const Icon(Icons.keyboard_double_arrow_right),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _node(BuildContext context, _NavigationNode node) {
    if (node.isLeaf) return _leaf(context, node);
    final containsSelected = node.children.any(
      (child) => child.section == selected,
    );
    final expanded = controller.navigationGroupExpanded(node.id!);
    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Tooltip(
          message: node.label,
          child: IconButton(
            onPressed: () => _showGroupMenu(context, node),
            icon: Icon(node.icon),
            color: containsSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    void toggle() => controller.setNavigationGroupExpanded(node.id!, !expanded);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Focus(
          canRequestFocus: true,
          onKeyEvent: (nodeFocus, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
                !expanded) {
              controller.setNavigationGroupExpanded(node.id!, true);
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft && expanded) {
              controller.setNavigationGroupExpanded(node.id!, false);
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space) {
              if (!containsSelected) {
                controller.setNavigationGroupExpanded(node.id!, true);
                onSelected(node.children.first.section!);
              } else {
                toggle();
              }
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Semantics(
            button: true,
            selected: containsSelected,
            expanded: expanded,
            child: ListTile(
              key: ValueKey('navigation-group:${node.id}'),
              dense: true,
              minVerticalPadding: 4,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              selected: containsSelected,
              selectedColor: Theme.of(context).colorScheme.primary,
              leading: Icon(node.icon, size: 19),
              title: Text(
                node.label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: containsSelected
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
              ),
              trailing: Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                size: 19,
              ),
              onTap: () {
                if (!containsSelected) {
                  controller.setNavigationGroupExpanded(node.id!, true);
                  onSelected(node.children.first.section!);
                } else {
                  toggle();
                }
              },
            ),
          ),
        ),
        if (expanded)
          for (final child in node.children)
            _leaf(context, child, nested: true),
        const SizedBox(height: 4),
      ],
    );
  }

  Future<void> _showGroupMenu(
    BuildContext context,
    _NavigationNode node,
  ) async {
    final selected = await showMenu<WorkbenchSection>(
      context: context,
      position: const RelativeRect.fromLTRB(72, 180, 0, 0),
      items: [
        for (final child in node.children)
          PopupMenuItem(value: child.section, child: Text(child.label)),
      ],
    );
    if (selected != null) onSelected(selected);
  }

  Widget _leaf(
    BuildContext context,
    _NavigationNode node, {
    bool nested = false,
  }) {
    final value = node.section!;
    final isSelected = selected == value;
    final theme = Theme.of(context);
    if (collapsed && !nested) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Tooltip(
          message: node.label,
          child: IconButton(
            onPressed: () => onSelected(value),
            icon: Icon(node.icon),
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    final tile = DecoratedBox(
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.6)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isSelected
            ? Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
              )
            : null,
      ),
      child: Stack(
        children: [
          ListTile(
            key: ValueKey('navigation-leaf:${value.name}'),
            dense: true,
            minVerticalPadding: 4,
            visualDensity: const VisualDensity(vertical: -1),
            contentPadding: EdgeInsets.symmetric(horizontal: nested ? 14 : 12),
            hoverColor: theme.colorScheme.primary.withValues(alpha: 0.06),
            focusColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            selected: isSelected,
            selectedColor: theme.colorScheme.primary,
            iconColor: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
            leading: Padding(
              padding: EdgeInsets.only(left: nested ? 16 : 0),
              child: Icon(node.icon, size: 20),
            ),
            title: Text(
              node.label,
              style: isSelected
                  ? TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    )
                  : null,
            ),
            onTap: () => onSelected(value),
          ),
          if (isSelected)
            PositionedDirectional(
              start: 0,
              top: 8,
              bottom: 8,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.secondary,
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: tile,
    );
  }
}

class _MobileNavigationSheet extends StatelessWidget {
  const _MobileNavigationSheet({
    required this.selected,
    required this.controller,
    required this.onSelected,
    required this.onParentSelected,
  });

  final WorkbenchSection selected;
  final WorkbenchController controller;
  final ValueChanged<WorkbenchSection> onSelected;
  final ValueChanged<WorkbenchSection> onParentSelected;

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      children: [
        for (final node in _navigationTree)
          if (node.isLeaf)
            ListTile(
              key: ValueKey('navigation-leaf:${node.section!.name}'),
              selected: node.section == selected,
              leading: Icon(node.icon, size: 20),
              title: Text(node.label),
              onTap: () => onSelected(node.section!),
            )
          else
            ExpansionTile(
              key: ValueKey('navigation-group:${node.id}'),
              initiallyExpanded: controller.navigationGroupExpanded(node.id!),
              leading: Icon(node.icon),
              title: Text(node.label),
              onExpansionChanged: (expanded) {
                controller.setNavigationGroupExpanded(node.id!, expanded);
                final containsSelected = node.children.any(
                  (child) => child.section == selected,
                );
                if (!containsSelected) {
                  onParentSelected(node.children.first.section!);
                }
              },
              children: [
                for (final child in node.children)
                  ListTile(
                    key: ValueKey('navigation-leaf:${child.section!.name}'),
                    contentPadding: const EdgeInsetsDirectional.only(
                      start: 32,
                      end: 8,
                    ),
                    selected: child.section == selected,
                    leading: Icon(child.icon, size: 20),
                    title: Text(child.label),
                    onTap: () => onSelected(child.section!),
                  ),
              ],
            ),
      ],
    );
  }
}

/// 页面切换过渡：淡入 + 轻微位移。
/// 桌面端使用向上浮入（fade-through 质感），移动端按导航方向横向滑入。
/// 内部保持 IndexedStack 不重建，页面状态不丢失。
class _SectionTransition extends StatefulWidget {
  const _SectionTransition({
    required this.sectionIndex,
    required this.slidable,
    required this.child,
  });

  final int sectionIndex;
  final bool slidable;
  final Widget child;

  @override
  State<_SectionTransition> createState() => _SectionTransitionState();
}

class _SectionTransitionState extends State<_SectionTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  int _previousIndex = 0;

  @override
  void initState() {
    super.initState();
    _previousIndex = widget.sectionIndex;
    _controller.value = 1; // 首次进入不播动画
  }

  @override
  void didUpdateWidget(_SectionTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sectionIndex != widget.sectionIndex) {
      _previousIndex = oldWidget.sectionIndex;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    final forward = widget.sectionIndex >= _previousIndex;
    final begin = widget.slidable
        ? Offset(forward ? 0.08 : -0.08, 0)
        : const Offset(0, 0.015);
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween<Offset>(begin: begin, end: Offset.zero).animate(_curve),
        child: widget.child,
      ),
    );
  }
}
