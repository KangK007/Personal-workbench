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
  tasks,
  projects,
  focus,
  restriction,
  notes,
  review,
  policies,
  settings,
  plan,
  protocols,
  growth,
  inbox,
  calendar,
  diary,
  goals,
  habits,
}

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
    WorkbenchSection.tasks,
    WorkbenchSection.review,
    WorkbenchSection.policies,
    WorkbenchSection.settings,
  ];

  WorkbenchSection section = WorkbenchSection.today;
  PlanTab planTab = PlanTab.all;
  ReviewTab reviewTab = ReviewTab.diary;
  ProtocolTab protocolTab = ProtocolTab.goals;
  HotKey? captureHotKey;
  final Set<WorkbenchSection> _visitedSections = {WorkbenchSection.today};
  final List<WorkbenchSection> _mobileHistory = [];
  WorkbenchSection _lastMobilePrimary = WorkbenchSection.today;

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

  Widget _mobileLayout() {
    final index = _mobilePrimarySections.indexOf(
      _mobilePrimarySections.contains(section) ? section : _lastMobilePrimary,
    );
    final title = switch (section) {
      WorkbenchSection.tasks => '任务',
      WorkbenchSection.projects => '项目',
      WorkbenchSection.policies => '国策',
      WorkbenchSection.today => '今日',
      WorkbenchSection.plan => '计划',
      WorkbenchSection.focus => '专注',
      WorkbenchSection.restriction => '自律',
      WorkbenchSection.notes => '笔记',
      WorkbenchSection.protocols =>
        widget.controller.advancedFeaturesEnabled ? '协议' : '目标与习惯',
      WorkbenchSection.growth => '成长',
      WorkbenchSection.inbox => '收集箱',
      WorkbenchSection.calendar => '工作周',
      WorkbenchSection.diary => '日记',
      WorkbenchSection.goals => '目标与习惯',
      WorkbenchSection.habits => '目标与习惯',
      WorkbenchSection.review => '回顾',
      WorkbenchSection.settings => '设置',
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
              selectedIndex: index,
              onDestinationSelected: (value) =>
                  _select(_mobilePrimarySections[value]),
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

  Widget _buildPage(WorkbenchSection value) => switch (value) {
    WorkbenchSection.today => TodayPage(
      controller: widget.controller,
      showHeader: MediaQuery.sizeOf(context).width >= AppBreakpoints.compact,
      onOpenPlan: () => _select(WorkbenchSection.tasks),
      onOpenInbox: () => _select(WorkbenchSection.tasks),
      onOpenReview: () {
        reviewTab = ReviewTab.diary;
        _select(WorkbenchSection.review);
      },
    ),
    WorkbenchSection.tasks => PlanPage(
      key: ValueKey(planTab),
      controller: widget.controller,
      initialTab: planTab,
      showHeader: MediaQuery.sizeOf(context).width >= AppBreakpoints.compact,
    ),
    WorkbenchSection.plan => PlanPage(
      key: ValueKey(planTab),
      controller: widget.controller,
      initialTab: planTab,
      showHeader: MediaQuery.sizeOf(context).width >= AppBreakpoints.compact,
    ),
    WorkbenchSection.focus => FocusHubPage(
      controller: widget.controller,
      showHeader: MediaQuery.sizeOf(context).width >= AppBreakpoints.compact,
      onOpenSettings: () => _select(WorkbenchSection.settings),
    ),
    WorkbenchSection.restriction => RestrictionPage(
      controller: widget.controller,
      showHeader: MediaQuery.sizeOf(context).width >= AppBreakpoints.compact,
      onOpenSettings: () => _select(WorkbenchSection.settings),
    ),
    WorkbenchSection.policies => PoliciesPage(
      controller: widget.controller,
      showHeader: MediaQuery.sizeOf(context).width >= AppBreakpoints.compact,
    ),
    WorkbenchSection.protocols => ProtocolsPage(
      key: ValueKey(
        '${widget.controller.advancedFeaturesEnabled}:$protocolTab',
      ),
      controller: widget.controller,
      initialTab: protocolTab,
      showHeader: MediaQuery.sizeOf(context).width >= AppBreakpoints.compact,
    ),
    WorkbenchSection.projects => ProjectsPage(
      controller: widget.controller,
      showHeader: MediaQuery.sizeOf(context).width >= AppBreakpoints.compact,
    ),
    WorkbenchSection.notes => NotesPage(
      controller: widget.controller,
      showHeader: MediaQuery.sizeOf(context).width >= AppBreakpoints.compact,
    ),
    WorkbenchSection.review => ReviewPage(
      key: ValueKey(reviewTab),
      controller: widget.controller,
      initialTab: reviewTab,
      showHeader: MediaQuery.sizeOf(context).width >= AppBreakpoints.compact,
    ),
    WorkbenchSection.growth => GrowthPage(
      controller: widget.controller,
      showHeader: MediaQuery.sizeOf(context).width >= AppBreakpoints.compact,
    ),
    WorkbenchSection.diary => DiaryPage(
      controller: widget.controller,
      showHeader: MediaQuery.sizeOf(context).width >= AppBreakpoints.compact,
    ),
    WorkbenchSection.goals => GoalsPage(
      controller: widget.controller,
      showHeader: MediaQuery.sizeOf(context).width >= AppBreakpoints.compact,
    ),
    WorkbenchSection.habits => HabitsPage(
      controller: widget.controller,
      showHeader: MediaQuery.sizeOf(context).width >= AppBreakpoints.compact,
    ),
    WorkbenchSection.settings => SettingsPage(
      controller: widget.controller,
      showHeader: MediaQuery.sizeOf(context).width >= AppBreakpoints.compact,
    ),
    _ => PlanPage(
      controller: widget.controller,
      initialTab: PlanTab.all,
      showHeader: MediaQuery.sizeOf(context).width >= AppBreakpoints.compact,
    ),
  };

  void _select(WorkbenchSection value) {
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    setState(() {
      if (value == WorkbenchSection.inbox) {
        planTab = PlanTab.inbox;
        value = WorkbenchSection.tasks;
      } else if (value == WorkbenchSection.calendar) {
        planTab = PlanTab.week;
        value = WorkbenchSection.tasks;
      } else if (value == WorkbenchSection.plan) {
        value = WorkbenchSection.tasks;
      }
      if (compact && value != section) {
        if (_mobileHistory.isEmpty || _mobileHistory.last != section) {
          _mobileHistory.add(section);
        }
      }
      if (_mobilePrimarySections.contains(value)) {
        _lastMobilePrimary = value;
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

class _NavigationGroup {
  const _NavigationGroup(this.id, this.label, this.icon, this.items);

  final String id;
  final String label;
  final IconData icon;
  final List<_NavigationItem> items;
}

class _NavigationItem {
  const _NavigationItem(this.section, this.label, this.icon);

  final WorkbenchSection section;
  final String label;
  final IconData icon;
}

List<_NavigationGroup> _navigationGroups(WorkbenchController controller) => [
  const _NavigationGroup('plan', '计划', Icons.event_note_outlined, [
    _NavigationItem(WorkbenchSection.today, '今日', Icons.today_outlined),
    _NavigationItem(WorkbenchSection.tasks, '任务', Icons.checklist_outlined),
    _NavigationItem(WorkbenchSection.projects, '项目', Icons.folder_outlined),
  ]),
  const _NavigationGroup('execute', '执行', Icons.play_circle_outline, [
    _NavigationItem(WorkbenchSection.focus, '专注', Icons.timer_outlined),
    _NavigationItem(WorkbenchSection.restriction, '自律', Icons.shield_outlined),
  ]),
  const _NavigationGroup('capture', '沉淀', Icons.collections_bookmark_outlined, [
    _NavigationItem(WorkbenchSection.notes, '笔记', Icons.note_alt_outlined),
    _NavigationItem(WorkbenchSection.diary, '日记', Icons.book_outlined),
  ]),
  const _NavigationGroup('review', '回顾', Icons.insights_outlined, [
    _NavigationItem(WorkbenchSection.review, '期间回顾', Icons.insights_outlined),
    _NavigationItem(
      WorkbenchSection.policies,
      '国策',
      Icons.account_tree_outlined,
    ),
    _NavigationItem(WorkbenchSection.goals, '目标与习惯', Icons.flag_outlined),
    _NavigationItem(WorkbenchSection.growth, '成长', Icons.trending_up_outlined),
  ]),
  const _NavigationGroup('system', '系统', Icons.settings_outlined, [
    _NavigationItem(WorkbenchSection.settings, '设置', Icons.settings_outlined),
  ]),
];

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
                          for (final group in _navigationGroups(controller))
                            _group(context, group),
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

  Widget _group(BuildContext context, _NavigationGroup group) {
    final containsSelected = group.items.any(
      (item) => item.section == selected,
    );
    final expanded =
        controller.navigationGroupExpanded(group.id) || containsSelected;
    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Tooltip(
          message: group.label,
          child: IconButton(
            onPressed: () => _showGroupMenu(context, group),
            icon: Icon(group.icon),
            color: containsSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Focus(
          canRequestFocus: true,
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
                !expanded) {
              controller.setNavigationGroupExpanded(group.id, true);
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft && expanded) {
              controller.setNavigationGroupExpanded(group.id, false);
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space) {
              controller.setNavigationGroupExpanded(group.id, !expanded);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Semantics(
            button: true,
            expanded: expanded,
            child: ListTile(
              dense: true,
              minVerticalPadding: 4,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              leading: Icon(group.icon, size: 19),
              title: Text(
                group.label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              trailing: Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                size: 19,
              ),
              onTap: () =>
                  controller.setNavigationGroupExpanded(group.id, !expanded),
            ),
          ),
        ),
        if (expanded)
          for (final item in group.items) _item(context, item),
        const SizedBox(height: 4),
      ],
    );
  }

  Future<void> _showGroupMenu(
    BuildContext context,
    _NavigationGroup group,
  ) async {
    final selected = await showMenu<WorkbenchSection>(
      context: context,
      position: const RelativeRect.fromLTRB(72, 180, 0, 0),
      items: [
        for (final item in group.items)
          PopupMenuItem(value: item.section, child: Text(item.label)),
      ],
    );
    if (selected != null) onSelected(selected);
  }

  Widget _item(BuildContext context, _NavigationItem item) {
    final value = item.section;
    final isSelected = selected == value;
    final theme = Theme.of(context);
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
            dense: true,
            minVerticalPadding: 4,
            visualDensity: const VisualDensity(vertical: -1),
            contentPadding: EdgeInsets.symmetric(horizontal: 14),
            hoverColor: theme.colorScheme.primary.withValues(alpha: 0.06),
            focusColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            selected: isSelected,
            selectedColor: theme.colorScheme.primary,
            iconColor: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
            leading: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Icon(item.icon, size: 20),
            ),
            title: Text(
              item.label,
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
  });

  final WorkbenchSection selected;
  final WorkbenchController controller;
  final ValueChanged<WorkbenchSection> onSelected;

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      children: [
        for (final group in _navigationGroups(controller))
          ExpansionTile(
            initiallyExpanded:
                controller.navigationGroupExpanded(group.id) ||
                group.items.any((item) => item.section == selected),
            leading: Icon(group.icon),
            title: Text(group.label),
            onExpansionChanged: (expanded) =>
                controller.setNavigationGroupExpanded(group.id, expanded),
            children: [
              for (final item in group.items)
                ListTile(
                  contentPadding: const EdgeInsets.only(left: 32, right: 8),
                  selected: item.section == selected,
                  leading: Icon(item.icon, size: 20),
                  title: Text(item.label),
                  onTap: () => onSelected(item.section),
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
