import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/models/workspace_record.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../state/workbench_controller.dart';
import '../widgets/common.dart';
import '../widgets/jade_icon.dart';
import '../widgets/record_editor_dialog.dart';
import 'focus_page.dart';
import 'goals_page.dart';
import 'habits_page.dart';

enum ProtocolTab { goals, habits, execution, rules, analytics }

class ProtocolsPage extends StatefulWidget {
  const ProtocolsPage({
    super.key,
    required this.controller,
    this.initialTab = ProtocolTab.execution,
    this.showHeader = true,
  });

  final WorkbenchController controller;
  final ProtocolTab initialTab;
  final bool showHeader;

  @override
  State<ProtocolsPage> createState() => _ProtocolsPageState();
}

class _ProtocolsPageState extends State<ProtocolsPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late TabController tabController;
  late List<ProtocolTab> _activeTabs;
  Timer? ticker;
  String ruleQuery = '';
  String ruleTypeFilter = 'all';
  int _analyticsDays = 7;
  final Set<String> expandedRuleIds = <String>{};
  bool _tickerActive = false;

  void _startTicker() {
    if (_tickerActive) return;
    _tickerActive = true;
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      widget.controller.settleProtocols();
      if (mounted) setState(() {});
    });
  }

  void _stopTicker() {
    _tickerActive = false;
    ticker?.cancel();
    ticker = null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _activeTabs = _tabs;
    tabController = _newTabController(_activeTabs, widget.initialTab);
    _startTicker();
  }

  TabController _newTabController(
    List<ProtocolTab> tabs,
    ProtocolTab selected,
  ) {
    return TabController(
      length: tabs.length,
      initialIndex: tabs.indexOf(selected).clamp(0, tabs.length - 1),
      vsync: this,
    )..addListener(_handleTabChanged);
  }

  @override
  void didUpdateWidget(covariant ProtocolsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextTabs = _tabs;
    final initialChanged = widget.initialTab != oldWidget.initialTab;
    final selected = initialChanged
        ? widget.initialTab
        : _activeTabs[tabController.index];
    if (!listEquals(_activeTabs, nextTabs)) {
      tabController.removeListener(_handleTabChanged);
      tabController.dispose();
      _activeTabs = nextTabs;
      tabController = _newTabController(_activeTabs, selected);
    } else if (initialChanged) {
      final index = _activeTabs.indexOf(selected);
      tabController.animateTo(
        index < 0 ? _activeTabs.indexOf(ProtocolTab.execution) : index,
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTicker();
    tabController.removeListener(_handleTabChanged);
    tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 应用退到后台时暂停秒级重建，回到前台立即恢复。
    if (state == AppLifecycleState.resumed) {
      if (TickerMode.of(context)) _startTicker();
    } else if (state != AppLifecycleState.inactive) {
      _stopTicker();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 页面不在前台 Section（IndexedStack 非激活页）时暂停秒级重建，
    // 修复「页面不可见时 Timer 仍每秒重建」的性能问题。
    final visible = TickerMode.of(context);
    if (visible && !_tickerActive) {
      _startTicker();
    } else if (!visible && _tickerActive) {
      _stopTicker();
    }
    final tabs = _activeTabs;
    final compact =
        WorkbenchViewport.sizeOf(context).width < AppBreakpoints.compact;
    return WorkbenchContentFrame(
      maxWidth: AppLayout.workspaceMax,
      child: Column(
        children: [
          if (widget.showHeader)
            PageHeader(
              title: '协议',
              subtitle: '执行协议 · 行为规则 · 判例 · 分析；目标与日常习惯请在成长中管理',
              actions: [
                if (_activeTabs[tabController.index] == ProtocolTab.execution)
                  FilledButton.icon(
                    onPressed: _createForCurrentTab,
                    icon: const Icon(Icons.add),
                    label: const Text('新增链条'),
                  ),
              ],
            ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 20),
            child: WorkbenchTabBar(
              controller: tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelPadding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
              tabs: [for (final tab in tabs) _tabWidget(tab)],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: tabController,
              children: [for (final tab in tabs) _tabView(tab)],
            ),
          ),
        ],
      ),
    );
  }

  List<ProtocolTab> get _tabs => [
    if (widget.initialTab == ProtocolTab.goals) ProtocolTab.goals,
    ProtocolTab.execution,
    if (widget.controller.advancedFeaturesEnabled ||
        widget.initialTab == ProtocolTab.habits)
      ProtocolTab.habits,
    if (widget.controller.advancedFeaturesEnabled) ...const [
      ProtocolTab.rules,
      ProtocolTab.analytics,
    ],
  ];

  Widget _tabWidget(ProtocolTab tab) => switch (tab) {
    ProtocolTab.goals => const Tab(icon: Icon(Icons.flag_outlined), text: '目标'),
    ProtocolTab.habits => Tab(
      icon: const Icon(Icons.repeat),
      text: widget.initialTab == ProtocolTab.habits ? '习惯' : '行为协议',
    ),
    ProtocolTab.execution => const Tab(
      icon: JadeIcon(glyph: JadeGlyph.protocols),
      text: '执行协议',
    ),
    ProtocolTab.rules => const Tab(
      icon: Icon(Icons.gavel_outlined),
      text: '判例',
    ),
    ProtocolTab.analytics => const Tab(
      icon: Icon(Icons.analytics_outlined),
      text: '分析',
    ),
  };

  Widget _tabView(ProtocolTab tab) => switch (tab) {
    // 旧入口仅在显式请求时复用正式页面和同一份记录。
    ProtocolTab.goals => _legacyContent(
      '目标',
      GoalsPage(controller: widget.controller, showHeader: false),
    ),
    ProtocolTab.habits =>
      widget.initialTab == ProtocolTab.habits
          ? _legacyContent(
              '习惯',
              HabitsPage(controller: widget.controller, showHeader: false),
            )
          : _rsipView(),
    ProtocolTab.execution => _ctdpView(),
    ProtocolTab.rules => _rulesView(),
    ProtocolTab.analytics => _analyticsView(),
  };

  Widget _legacyContent(String title, Widget page) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            '兼容视图 · $title内容与成长页同步',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.tokens.mutedText),
          ),
        ),
      ),
      Expanded(child: page),
    ],
  );

  Widget _rsipView() => ListView(
    padding: const EdgeInsets.fromLTRB(
      20,
      18,
      20,
      AppSpacing.bottomNavClearance,
    ),
    children: [
      const SectionHeading(title: '行为协议', scale: 'RSIP'),
      Text(
        '这里配置最小行动、规则树与结算；日常打卡和本月事实矩阵请在成长 → 习惯中完成。',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: context.tokens.mutedText),
      ),
      const SizedBox(height: 12),
      ..._rsipContent(),
    ],
  );

  void _handleTabChanged() {
    if (!tabController.indexIsChanging && mounted) setState(() {});
  }

  Future<void> _createForCurrentTab() {
    final current = _activeTabs[tabController.index];
    if (current == ProtocolTab.execution) return _showCtdpEditor();
    return showRecordEditor(
      context,
      widget.controller,
      kind: switch (current) {
        ProtocolTab.goals => RecordKind.goal,
        ProtocolTab.habits => RecordKind.habit,
        _ => RecordKind.task,
      },
    );
  }

  Future<void> _showCtdpEditor({WorkspaceRecord? existing}) async {
    await showRecordEditor(
      context,
      widget.controller,
      kind: RecordKind.task,
      record: existing,
      protocolMode: 'ctdp',
      editorTitle: existing == null ? '新建 CTDP 执行链' : '编辑 CTDP 执行链',
    );
    if (mounted) setState(() {});
  }

  Widget _ctdpView() {
    final chains = widget.controller.ctdpTasks;
    final chainIds = {for (final task in chains) task.id};
    final childrenByParent = <String, List<WorkspaceRecord>>{};
    for (final task in chains) {
      if (task.parentId != null) {
        childrenByParent.putIfAbsent(task.parentId!, () => []).add(task);
      }
    }
    final roots = chains
        .where(
          (task) => task.parentId == null || !chainIds.contains(task.parentId),
        )
        .toList();
    final groupRoots = roots.where((task) => task.ctdpIsGroup).toList();
    final chainRoots = roots.where((task) => !task.ctdpIsGroup).toList();
    final chainById = {for (final task in chains) task.id: task};
    final linkedSessions =
        widget.controller
            .recordsOf(RecordKind.focusSession)
            .where((session) => chainById.containsKey(session.parentId))
            .toList()
          ..sort(
            (a, b) => (b.scheduledFor ?? b.createdAt).compareTo(
              a.scheduledFor ?? a.createdAt,
            ),
          );
    final now = widget.controller.currentTime();
    final rows = <WidgetBuilder>[];
    rows.add(
      (_) => _MetricStrip(
        values: [
          ('链条', chains.length),
          ('待触发', chains.where((task) => task.ctdpReservationPending).length),
          (
            '主链轮次',
            chains.fold(0, (sum, task) => sum + task.ctdpTotalCompletions),
          ),
          ('失败', chains.fold(0, (sum, task) => sum + task.ctdpTotalFailures)),
        ],
      ),
    );
    rows.add((_) => const SizedBox(height: 18));
    rows.add(
      (_) => Align(
        alignment: AlignmentDirectional.centerEnd,
        child: FilledButton.icon(
          key: const ValueKey('ctdp-create-chain'),
          onPressed: _showCtdpEditor,
          icon: const Icon(Icons.add),
          label: const Text('新增链条'),
        ),
      ),
    );
    rows.add((_) => const SizedBox(height: 12));
    void appendTree(WorkspaceRecord task, int depth) {
      final children = childrenByParent[task.id] ?? const <WorkspaceRecord>[];
      rows.add(
        (context) => Padding(
          padding: EdgeInsets.only(
            left:
                (depth *
                        (WorkbenchViewport.sizeOf(context).width <
                                AppBreakpoints.compact
                            ? 12
                            : 20))
                    .clamp(0, 60)
                    .toDouble(),
            bottom: 10,
          ),
          child: _CtdpCard(
            task: task,
            children: children,
            now: now,
            onAction: (action) => _handleCtdpAction(task, action),
          ),
        ),
      );
      for (final child in children) {
        appendTree(child, depth + 1);
      }
    }

    if (chains.isEmpty) {
      rows.add(
        (context) => EmptyState(
          icon: Icons.link_off_outlined,
          title: '还没有 CTDP 链',
          message: '创建任务并定义触发标志、预约缓冲和完成时长。',
        ),
      );
    } else {
      if (groupRoots.isNotEmpty) {
        rows.add(
          (_) => SectionHeading(
            title: '任务组',
            scale: '${groupRoots.length} GROUPS',
          ),
        );
        for (final task in groupRoots) {
          appendTree(task, 0);
        }
      }
      if (chainRoots.isNotEmpty) {
        rows.add(
          (_) => SectionHeading(
            title: '执行链',
            scale: '${chainRoots.length} CHAINS',
          ),
        );
        for (final task in chainRoots) {
          appendTree(task, 0);
        }
      }
      rows.add(
        (_) => SectionHeading(
          title: '关联专注',
          scale: '${linkedSessions.length} SESSIONS',
        ),
      );
      if (linkedSessions.isEmpty) {
        rows.add(
          (context) => LogSurface(
            child: Row(
              children: [
                Icon(Icons.timer_outlined, color: context.tokens.mutedText),
                const SizedBox(width: AppSpacing.md),
                const Expanded(child: Text('尚无关联专注。可从上方执行协议启动一轮。')),
              ],
            ),
          ),
        );
      } else {
        for (
          var index = 0;
          index < linkedSessions.length && index < 6;
          index++
        ) {
          final session = linkedSessions[index];
          final isLast = index == linkedSessions.length - 1 || index == 5;
          rows.add(
            (_) => _linkedSessionTile(
              session,
              chainById[session.parentId]!,
              showConnector: !isLast,
            ),
          );
        }
        if (linkedSessions.length > 6) {
          rows.add(
            (context) => Text(
              '仅显示最近 6 轮；完整记录可在专注中心查看。',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: context.tokens.mutedText),
            ),
          );
        }
      }
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        20,
        18,
        20,
        AppSpacing.bottomNavClearance,
      ),
      itemCount: rows.length,
      itemBuilder: (context, index) => rows[index](context),
    );
  }

  Widget _linkedSessionTile(
    WorkspaceRecord session,
    WorkspaceRecord task, {
    required bool showConnector,
  }) {
    final seconds = (session.data['seconds'] as num?)?.toInt() ?? 0;
    final duration = Duration(seconds: seconds < 0 ? 0 : seconds);
    final time = (session.scheduledFor ?? session.createdAt).toLocal();
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Icon(
                Icons.timer_outlined,
                size: AppIconSize.md,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: LogSurface(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.title.isEmpty ? task.title : session.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(fontSize: 15),
                    ),
                    if (session.title != task.title) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '关联任务：${task.title}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.tokens.mutedText,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.xs,
                      children: [
                        NumericText(
                          _sessionDateTime(time),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        NumericText(
                          formatDuration(duration),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (showConnector)
          Padding(
            padding: const EdgeInsets.only(left: 11),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Container(
                width: 1,
                height: AppSpacing.md,
                color: context.tokens.divider,
              ),
            ),
          ),
      ],
    );
  }

  String _sessionDateTime(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${time.year}-${two(time.month)}-${two(time.day)} '
        '${two(time.hour)}:${two(time.minute)}';
  }

  Future<void> _handleCtdpAction(WorkspaceRecord task, String action) async {
    try {
      switch (action) {
        case 'start':
          await showFocusSession(context, widget.controller, task);
        case 'reserve':
          await widget.controller.startCtdpReservation(task);
        case 'confirm':
          await widget.controller.confirmCtdpTrigger(task);
          if (mounted) await showFocusSession(context, widget.controller, task);
        case 'aux_fail':
          await widget.controller.failCtdpAuxiliary(task);
        case 'group_start':
          await widget.controller.startCtdpGroup(task);
        case 'copy':
          await widget.controller.duplicateCtdpTask(task);
        case 'edit':
          if (!mounted) return;
          await _showCtdpEditor(existing: task);
        case 'trash':
          await widget.controller.moveToTrash(task);
      }
    } on FormatException catch (error) {
      if (!mounted) return;
      showWorkbenchSnackBar(
        context,
        SnackBar(content: Text(error.message.toString())),
      );
    }
  }

  List<Widget> _rsipContent() {
    final nodes = widget.controller.habits
        .where((habit) => habit.hasRsipProtocol)
        .toList();
    final nodeIds = {for (final node in nodes) node.id};
    final childrenByParent = <String, List<WorkspaceRecord>>{};
    for (final node in nodes) {
      if (node.parentId != null) {
        childrenByParent.putIfAbsent(node.parentId!, () => []).add(node);
      }
    }
    final day = widget.controller.growthService.logicalDay(
      widget.controller.currentTime(),
    );
    final dayLogs = <String, WorkspaceRecord>{};
    for (final log in widget.controller.recordsOf(RecordKind.habitLog)) {
      if (log.parentId != null && isSameDay(log.scheduledFor, day)) {
        dayLogs.putIfAbsent(log.parentId!, () => log);
      }
    }
    final roots = nodes
        .where(
          (node) => node.parentId == null || !nodeIds.contains(node.parentId),
        )
        .toList();
    final groups = <String, List<WorkspaceRecord>>{};
    for (final root in roots) {
      groups.putIfAbsent(root.rsipGroup, () => []).add(root);
    }
    return [
      LogSurface(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('允许一天新增多个节点'),
          subtitle: const Text('默认遵守每日只增加一条国策；仅在已明确设计好树结构时开启。'),
          value: widget.controller.rsipAllowMultiplePerDay,
          onChanged: widget.controller.setRsipAllowMultiplePerDay,
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 10,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            onPressed: () => showRecordEditor(
              context,
              widget.controller,
              kind: RecordKind.habit,
              protocolMode: 'rsip',
              editorTitle: '新建 RSIP 国策',
            ),
            icon: const Icon(Icons.add),
            label: const Text('新增国策'),
          ),
          OutlinedButton.icon(
            onPressed: _recordVictory,
            icon: const Icon(Icons.emoji_events_outlined),
            label: const Text('记录今日胜利'),
          ),
        ],
      ),
      const SizedBox(height: 18),
      if (nodes.isEmpty)
        const EmptyState(
          icon: Icons.account_tree_outlined,
          title: '还没有 RSIP 国策',
          message: '从一个足够小、可以稳定执行的动作开始。',
        )
      else
        for (final group in groups.entries) ...[
          SectionHeading(
            title: group.key,
            scale: '${group.value.length} ROOTS',
          ),
          for (final root in group.value)
            ..._rsipTree(root, childrenByParent, dayLogs, 0),
        ],
    ];
  }

  List<Widget> _rsipTree(
    WorkspaceRecord node,
    Map<String, List<WorkspaceRecord>> childrenByParent,
    Map<String, WorkspaceRecord> dayLogs,
    int depth,
  ) {
    final children = childrenByParent[node.id] ?? const <WorkspaceRecord>[];
    return [
      Padding(
        padding: EdgeInsets.only(
          left:
              (depth *
                      (WorkbenchViewport.sizeOf(context).width <
                              AppBreakpoints.compact
                          ? 12
                          : 20))
                  .clamp(0, 60)
                  .toDouble(),
          bottom: 10,
        ),
        child: _RsipCard(
          node: node,
          now: widget.controller.currentTime(),
          settledToday: dayLogs[node.id]?.status == WorkStatus.done,
          onAction: (action) => _handleRsipAction(node, action),
        ),
      ),
      for (final child in children)
        ..._rsipTree(child, childrenByParent, dayLogs, depth + 1),
    ];
  }

  Future<void> _handleRsipAction(WorkspaceRecord node, String action) async {
    try {
      switch (action) {
        case 'timer_start':
          await widget.controller.startRsipTimer(node);
        case 'timer_complete':
          await widget.controller.completeRsipTimer(node);
        case 'done':
          await widget.controller.logHabit(
            node,
            widget.controller.currentTime(),
            WorkStatus.done,
          );
        case 'fail':
          await widget.controller.logHabit(
            node,
            widget.controller.currentTime(),
            WorkStatus.skipped,
          );
        case 'freeze':
          await widget.controller.freezeRsipBranch(
            node,
            until: widget.controller.currentTime().add(const Duration(days: 1)),
            reason: '水密隔舱：暂停 24 小时后自动解冻',
          );
        case 'reactivate':
          await widget.controller.reactivateRsipHabit(node);
        case 'child':
          if (!mounted) return;
          await showRecordEditor(
            context,
            widget.controller,
            kind: RecordKind.habit,
            initialParentId: node.id,
            protocolMode: 'rsip',
            editorTitle: '新建 RSIP 国策',
          );
        case 'edit':
          if (!mounted) return;
          await showRecordEditor(
            context,
            widget.controller,
            kind: RecordKind.habit,
            record: node,
            protocolMode: 'rsip',
            editorTitle: '编辑 RSIP 国策',
          );
        case 'trash':
          await widget.controller.moveToTrash(node);
          if (mounted) {
            setState(() {});
            showWorkbenchSnackBar(
              context,
              SnackBar(
                content: const Text('国策已移入回收站'),
                action: SnackBarAction(
                  label: '撤销',
                  onPressed: () => widget.controller.restoreFromTrash(node),
                ),
              ),
            );
          }
      }
    } on FormatException catch (error) {
      if (!mounted) return;
      showWorkbenchSnackBar(
        context,
        SnackBar(content: Text(error.message.toString())),
      );
    }
  }

  Widget _rulesView() {
    final query = ruleQuery.trim().toLowerCase();
    final allRules = widget.controller.exceptionRules;
    final chainNames = {
      for (final task in widget.controller.ctdpTasks) task.id: task.title,
    };
    final rules = allRules.where((rule) {
      if (ruleTypeFilter != 'all' && rule.data['ruleType'] != ruleTypeFilter) {
        return false;
      }
      final scopeName = chainNames[rule.parentId] ?? '';
      return query.isEmpty ||
          rule.title.toLowerCase().contains(query) ||
          rule.body.toLowerCase().contains(query) ||
          scopeName.toLowerCase().contains(query) ||
          _ruleTypeLabel(rule.data['ruleType']?.toString()).contains(query);
    }).toList();
    final slate = context.accents.slate;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        20,
        18,
        20,
        AppSpacing.bottomNavClearance,
      ),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusPill(
              label:
                  '${widget.controller.exceptionRules.where((rule) => rule.data['archived'] != true).length} 条生效判例',
              icon: Icons.gavel_outlined,
            ),
            StatusPill(
              label:
                  '${widget.controller.exceptionRules.where((rule) => rule.data['archived'] == true).length} 条已归档',
              icon: Icons.archive_outlined,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          '判例为 CTDP 专注提供暂停、提前完成和中断依据。归档后不可再引用，已有记录仍保留。',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.tokens.mutedText),
        ),
        const SizedBox(height: AppSpacing.lg),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 560;
            final search = SearchBar(
              hintText: '搜索判例名称或说明',
              leading: const Icon(Icons.search),
              onChanged: (value) => setState(() => ruleQuery = value),
            );
            final create = FilledButton.icon(
              onPressed: () => _showRuleEditor(),
              icon: const Icon(Icons.add),
              label: const Text('新建判例'),
            );
            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [search, const SizedBox(height: 8), create],
              );
            }
            return Row(
              children: [
                Expanded(child: search),
                const SizedBox(width: 12),
                create,
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final (value, label) in const [
              ('all', '全部'),
              ('pause', '暂停'),
              ('early_completion', '提前完成'),
              ('interruption', '允许中断'),
            ])
              ChoiceChip(
                label: Text(
                  '$label ${value == 'all' ? allRules.length : allRules.where((rule) => rule.data['ruleType'] == value).length}',
                ),
                selected: ruleTypeFilter == value,
                selectedColor: slate.container,
                onSelected: (_) => setState(() => ruleTypeFilter = value),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (rules.isEmpty)
          EmptyState(
            icon: Icons.menu_book_outlined,
            title: allRules.isEmpty ? '还没有判例' : '没有符合条件的判例',
            message: allRules.isEmpty
                ? '暂停、提前完成和允许中断都必须先有可引用的规则。'
                : '调整分类或搜索词，查看其他判例。',
            action: allRules.isEmpty
                ? FilledButton.icon(
                    onPressed: () => _showRuleEditor(),
                    icon: const Icon(Icons.add),
                    label: const Text('创建第一条判例'),
                  )
                : null,
          )
        else
          for (final rule in rules) _ruleCard(rule, chainNames[rule.parentId]),
      ],
    );
  }

  Widget _ruleCard(WorkspaceRecord rule, String? chainName) {
    final archived = rule.data['archived'] == true;
    final expanded = expandedRuleIds.contains(rule.id);
    final scope = rule.data['scope'] == 'global'
        ? '所有 CTDP 链'
        : chainName ?? '原任务已移除';
    final longDetails = scope.length > 22 || rule.body.length > 46;
    final slate = context.accents.slate;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: LogSurface(
        accent: slate.color,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.gavel_outlined, color: slate.color),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    rule.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: '判例操作：${rule.title}',
                  onSelected: (action) async {
                    if (action == 'edit') {
                      await _showRuleEditor(rule: rule);
                      return;
                    }
                    if (action == 'trash') {
                      await widget.controller.moveToTrash(rule);
                      if (!mounted) return;
                      setState(() {});
                      showWorkbenchSnackBar(
                        context,
                        SnackBar(
                          content: const Text('判例已移入回收站'),
                          action: SnackBarAction(
                            label: '撤销',
                            onPressed: () =>
                                widget.controller.restoreFromTrash(rule),
                          ),
                        ),
                      );
                      return;
                    }
                    try {
                      await widget.controller.archiveExceptionRule(
                        rule,
                        !archived,
                      );
                      if (mounted) setState(() {});
                    } catch (_) {
                      if (!mounted) return;
                      showWorkbenchSnackBar(
                        context,
                        SnackBar(
                          content: Text(
                            archived ? '恢复判例失败，请重试。' : '归档判例失败，请重试。',
                          ),
                        ),
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('编辑判例')),
                    PopupMenuItem(
                      value: 'archive',
                      child: Text(archived ? '恢复判例' : '归档判例'),
                    ),
                    const PopupMenuItem(value: 'trash', child: Text('移入回收站')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                StatusPill(
                  label: _ruleTypeLabel(rule.data['ruleType']?.toString()),
                  icon: Icons.rule_outlined,
                  color: slate.container,
                  foreground: slate.color,
                  dense: true,
                ),
                AnimatedSwitcher(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : AppMotion.standard,
                  child: StatusPill(
                    key: ValueKey(archived),
                    label: archived ? '已归档 · 不可引用' : '生效中 · 可引用',
                    icon: archived
                        ? Icons.archive_outlined
                        : Icons.verified_outlined,
                    dense: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '作用范围：$scope',
              maxLines: expanded ? null : 2,
              overflow: expanded ? null : TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (rule.body.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                rule.body,
                maxLines: expanded ? null : 2,
                overflow: expanded ? null : TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.tokens.mutedText,
                ),
              ),
            ],
            if (longDetails)
              TextButton(
                onPressed: () => setState(() {
                  expanded
                      ? expandedRuleIds.remove(rule.id)
                      : expandedRuleIds.add(rule.id);
                }),
                child: Text(expanded ? '收起详情' : '展开详情'),
              ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '使用 ${(rule.data['usageCount'] as num?)?.toInt() ?? 0} 次',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: context.tokens.mutedText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _analyticsView() {
    final snapshot = _ProtocolAnalyticsSnapshot.fromEvents(
      widget.controller.protocolEvents,
      widget.controller.currentTime(),
      _analyticsDays,
    );
    final events = snapshot.events;
    final resolved = snapshot.successes + snapshot.failures;
    final successRate = resolved == 0 ? null : snapshot.successes / resolved;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        20,
        18,
        20,
        AppSpacing.bottomNavClearance,
      ),
      children: [
        _MetricStrip(
          values: [
            ('协议事件', events.length),
            ('成功结算', snapshot.successes),
            ('失败结算', snapshot.failures),
            (
              '判例使用',
              widget.controller.exceptionRules.fold(
                0,
                (sum, rule) =>
                    sum + ((rule.data['usageCount'] as num?)?.toInt() ?? 0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        LogSurface(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    color: context.accents.slate.color,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '可判定事件成功率',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (successRate == null)
                Text(
                  '暂无可判定结算。完成或失败的协议记录出现后，才会计算成功率。',
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              else ...[
                TweenAnimationBuilder<double>(
                  tween: Tween(end: successRate),
                  duration: const Duration(milliseconds: 240),
                  builder: (context, value, _) =>
                      LinearProgressIndicator(value: value, minHeight: 10),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(successRate * 100).toStringAsFixed(1)}% · $resolved 次有效结算',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        _ProtocolOutcomeTimeline(
          snapshot: snapshot,
          onDaysChanged: (days) => setState(() => _analyticsDays = days),
        ),
        const SizedBox(height: 24),
        const SectionHeading(title: '最近协议记录', scale: 'AUDIT LOG'),
        if (events.isEmpty)
          const Text('尚无协议事件。')
        else
          LogSurface(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                for (
                  var index = 0;
                  index < events.length && index < 30;
                  index++
                ) ...[
                  _EventTile(
                    event: events[index],
                    onDelete: () => _deleteProtocolEvent(events[index]),
                  ),
                  if (index < events.length - 1 && index < 29) const Divider(),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _showRuleEditor({WorkspaceRecord? rule}) async {
    final saved = await showWorkbenchDialog<bool>(
      context: context,
      builder: (context) =>
          _RuleEditorDialog(controller: widget.controller, rule: rule),
    );
    if (saved == true && mounted) setState(() {});
  }

  Future<void> _deleteProtocolEvent(WorkspaceRecord event) async {
    await widget.controller.moveToTrash(event);
    if (!mounted) return;
    setState(() {});
    showWorkbenchSnackBar(
      context,
      SnackBar(
        content: const Text('协议记录已移入回收站'),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () => widget.controller.restoreFromTrash(event),
        ),
      ),
    );
  }

  Future<void> _recordVictory() async {
    final title = TextEditingController();
    final notes = TextEditingController();
    var grade = 'small';
    final saved = await showWorkbenchDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('记录今日胜利'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExternalField(
                  label: '今天赢在哪里',
                  child: TextField(
                    controller: title,
                    autofocus: true,
                    decoration: const InputDecoration(),
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'small', label: Text('小胜')),
                    ButtonSegment(value: 'medium', label: Text('中胜')),
                    ButtonSegment(value: 'big', label: Text('大胜')),
                  ],
                  selected: {grade},
                  onSelectionChanged: (value) =>
                      setDialogState(() => grade = value.first),
                ),
                const SizedBox(height: 12),
                ExternalField(
                  label: '证据或复盘',
                  child: TextField(
                    controller: notes,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      await widget.controller.recordRsipVictory(
        title: title.text,
        grade: grade,
        notes: notes.text,
      );
    }
    title.dispose();
    notes.dispose();
  }
}

class _RuleEditorDialog extends StatefulWidget {
  const _RuleEditorDialog({required this.controller, this.rule});

  final WorkbenchController controller;
  final WorkspaceRecord? rule;

  @override
  State<_RuleEditorDialog> createState() => _RuleEditorDialogState();
}

class _RuleEditorDialogState extends State<_RuleEditorDialog> {
  late final TextEditingController name;
  late final TextEditingController description;
  final FocusNode nameFocus = FocusNode();
  final FocusNode chainFocus = FocusNode();
  late String type;
  late String scope;
  String? chainId;
  late final String initialName;
  late final String initialDescription;
  late final String initialType;
  late final String initialScope;
  String? initialChainId;
  String? errorMessage;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.rule?.title ?? '');
    description = TextEditingController(text: widget.rule?.body ?? '');
    type = widget.rule?.data['ruleType']?.toString() ?? 'pause';
    scope = widget.rule?.data['scope']?.toString() ?? 'global';
    chainId = widget.rule?.parentId;
    if (chainId != null &&
        !widget.controller.ctdpTasks.any((task) => task.id == chainId)) {
      chainId = null;
    }
    initialName = name.text;
    initialDescription = description.text;
    initialType = type;
    initialScope = scope;
    initialChainId = chainId;
  }

  bool get isDirty =>
      name.text != initialName ||
      description.text != initialDescription ||
      type != initialType ||
      scope != initialScope ||
      chainId != initialChainId;

  Future<void> _requestClose() async {
    if (saving) return;
    if (!isDirty) {
      Navigator.of(context).pop(false);
      return;
    }
    final discard = await showWorkbenchDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('放弃未保存的判例？'),
        content: const Text('当前修改尚未保存。可以继续编辑，或放弃这次修改。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('继续编辑'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('放弃更改'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop(false);
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    nameFocus.dispose();
    chainFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (name.text.trim().isEmpty) {
      setState(() => errorMessage = '判例名称不能为空');
      nameFocus.requestFocus();
      return;
    }
    if (scope == 'chain' && chainId == null) {
      setState(() => errorMessage = '请选择适用的 CTDP 任务');
      chainFocus.requestFocus();
      return;
    }
    setState(() {
      saving = true;
      errorMessage = null;
    });
    try {
      if (widget.rule == null) {
        await widget.controller.createExceptionRule(
          name: name.text,
          description: description.text,
          ruleType: type,
          scope: scope,
          chainId: chainId,
        );
      } else {
        await widget.controller.updateExceptionRule(
          widget.rule!,
          name: name.text,
          description: description.text,
          ruleType: type,
          scope: scope,
          chainId: chainId,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } on FormatException catch (error) {
      if (mounted) {
        setState(() {
          saving = false;
          errorMessage = error.message.toString();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          errorMessage = '保存失败，请重试；输入已保留。';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !saving && !isDirty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !saving) _requestClose();
      },
      child: AlertDialog(
        title: Text(widget.rule == null ? '新建结构化判例' : '编辑结构化判例'),
        content: SizedBox(
          width: 500,
          child: AbsorbPointer(
            absorbing: saving,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExternalField(
                    label: '判例名称',
                    child: TextField(
                      controller: name,
                      focusNode: nameFocus,
                      autofocus: true,
                      decoration: const InputDecoration(),
                      onChanged: (_) => setState(() => errorMessage = null),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ExternalField(
                    label: '适用条件',
                    child: TextField(
                      controller: description,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ExternalField(
                    label: '允许行为',
                    child: DropdownButtonFormField<String>(
                      initialValue: type,
                      isExpanded: true,
                      decoration: const InputDecoration(),
                      items: const [
                        DropdownMenuItem(value: 'pause', child: Text('暂停')),
                        DropdownMenuItem(
                          value: 'early_completion',
                          child: Text('提前完成'),
                        ),
                        DropdownMenuItem(
                          value: 'interruption',
                          child: Text('允许中断'),
                        ),
                      ],
                      onChanged: (value) => setState(() => type = value!),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ExternalField(
                    label: '作用范围',
                    child: DropdownButtonFormField<String>(
                      initialValue: scope,
                      isExpanded: true,
                      decoration: const InputDecoration(),
                      items: const [
                        DropdownMenuItem(
                          value: 'global',
                          child: Text('所有 CTDP 链'),
                        ),
                        DropdownMenuItem(
                          value: 'chain',
                          child: Text('指定 CTDP 链'),
                        ),
                      ],
                      onChanged: (value) => setState(() {
                        scope = value!;
                        if (scope == 'global') chainId = null;
                        errorMessage = null;
                      }),
                    ),
                  ),
                  if (scope == 'chain') ...[
                    const SizedBox(height: AppSpacing.md),
                    ExternalField(
                      label: '适用任务',
                      child: DropdownButtonFormField<String>(
                        initialValue: chainId,
                        isExpanded: true,
                        focusNode: chainFocus,
                        decoration: const InputDecoration(),
                        items: widget.controller.ctdpTasks
                            .where((task) => !task.ctdpIsGroup)
                            .map(
                              (task) => DropdownMenuItem(
                                value: task.id,
                                child: Text(
                                  task.title,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() {
                          chainId = value;
                          errorMessage = null;
                        }),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '判例只在符合范围的专注任务中供选择；归档后不可再引用。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.tokens.mutedText,
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : _requestClose,
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: saving ? null : _save,
            child: Text(
              saving
                  ? '保存中…'
                  : widget.rule == null
                  ? '创建'
                  : '保存',
            ),
          ),
        ],
      ),
    );
  }
}

class _CtdpCard extends StatelessWidget {
  const _CtdpCard({
    required this.task,
    required this.children,
    required this.now,
    required this.onAction,
  });

  final WorkspaceRecord task;
  final List<WorkspaceRecord> children;
  final DateTime now;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final dueAt = DateTime.tryParse(
      task.data['ctdpReservationDueAt']?.toString() ?? '',
    )?.toLocal();
    final groupStarted = DateTime.tryParse(
      task.data['ctdpGroupStartedAt']?.toString() ?? '',
    )?.toLocal();
    final completedChildren = groupStarted == null
        ? 0
        : children.where((child) {
            final completedAt = DateTime.tryParse(
              child.data['ctdpLastCompletedAt']?.toString() ?? '',
            )?.toLocal();
            return completedAt != null && !completedAt.isBefore(groupStarted);
          }).length;
    final descriptionStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(fontSize: 14);
    final chainMenu = PopupMenuButton<String>(
      tooltip: 'CTDP 链操作',
      onSelected: onAction,
      itemBuilder: (context) => [
        if (task.ctdpIsGroup)
          const PopupMenuItem(value: 'group_start', child: Text('启动任务组时限'))
        else ...[
          const PopupMenuItem(value: 'start', child: Text('直接开始本轮')),
          if (!task.ctdpReservationPending)
            PopupMenuItem(
              value: 'reserve',
              child: Text('预约 ${task.ctdpDelayMinutes} 分钟后开始'),
            )
          else ...[
            const PopupMenuItem(value: 'confirm', child: Text('确认触发并开始')),
            const PopupMenuItem(value: 'aux_fail', child: Text('辅助链失败')),
          ],
        ],
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'copy', child: Text('复制链条')),
        const PopupMenuItem(value: 'edit', child: Text('编辑 / 移动')),
        const PopupMenuItem(value: 'trash', child: Text('移入回收站')),
      ],
    );
    List<Widget> badges() => [
      _ChainBadge(label: '主', count: task.ctdpChainCount),
      const SizedBox(width: 6),
      _ChainBadge(label: '辅', count: task.ctdpAuxChainCount),
    ];
    return LogSurface(
      accent: task.ctdpReservationPending
          ? context.tokens.info
          : Theme.of(context).colorScheme.primary,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact =
                  constraints.maxWidth < 460 ||
                  MediaQuery.textScalerOf(context).scale(14) > 20;
              final titleRow = Row(
                children: [
                  JadeIcon(
                    glyph: task.ctdpIsGroup
                        ? JadeGlyph.groups
                        : JadeGlyph.protocols,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      task.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (!compact) ...badges(),
                  chainMenu,
                ],
              );
              if (!compact) return titleRow;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titleRow,
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      _ChainBadge(label: '主', count: task.ctdpChainCount),
                      _ChainBadge(label: '辅', count: task.ctdpAuxChainCount),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          if (task.ctdpIsGroup) ...[
            Text(
              '任务组 · ${children.length} 个单元 · 时限 ${task.ctdpGroupTimeLimitHours == 0 ? '不限' : '${task.ctdpGroupTimeLimitHours} 小时'}',
              style: descriptionStyle,
            ),
            if (groupStarted != null) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: children.isEmpty
                    ? 0
                    : completedChildren / children.length,
                minHeight: 8,
              ),
              const SizedBox(height: 5),
              Text(
                '本轮进度 $completedChildren / ${children.length}',
                style: descriptionStyle,
              ),
            ],
          ] else ...[
            Text('触发：${task.ctdpTrigger}', style: descriptionStyle),
            if (task.ctdpAuxSignal.isNotEmpty)
              Text('辅助：${task.ctdpAuxSignal}', style: descriptionStyle),
            Text(
              task.ctdpIsDurationless
                  ? '正计时 · 最低 ${task.ctdpMinimumMinutes} 分钟'
                  : '本轮 ${task.ctdpSessionMinutes} 分钟',
              style: descriptionStyle,
            ),
          ],
          const SizedBox(height: 10),
          _ProtocolStageBand(
            key: ValueKey('protocol-stage-${task.id}'),
            labels: task.ctdpIsGroup
                ? const ['待启动', '单元执行', '本轮完成']
                : const ['预约缓冲中', '等待触发', '任务结算'],
            selected: task.ctdpIsGroup
                ? groupStarted == null
                      ? 0
                      : children.isNotEmpty &&
                            completedChildren == children.length
                      ? 2
                      : 1
                : task.isDone
                ? 2
                : task.ctdpReservationPending
                ? 0
                : 1,
            color: task.ctdpReservationPending ? context.tokens.info : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              StatusPill(
                label: task.ctdpIsGroup
                    ? '${children.length} 个执行单元'
                    : '执行 ${task.ctdpIsDurationless ? '正计时' : '${task.ctdpSessionMinutes} 分'}',
                fontSize: 13,
                icon: Icons.timer_outlined,
              ),
              StatusPill(
                label: '完成证据 ${task.ctdpTotalCompletions} 轮',
                fontSize: 13,
                icon: Icons.verified_outlined,
                color: context.tokens.rewardContainer,
                foreground: context.tokens.rewardOnContainer,
              ),
            ],
          ),
          if (task.ctdpReservationPending && dueAt != null) ...[
            const SizedBox(height: 8),
            Text(
              '预约倒计时 ${_countdown(dueAt.difference(now))}',
              style: TextStyle(
                color: context.tokens.info,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 5),
          Text(
            '累计完成 ${task.ctdpTotalCompletions} · 主链失败 ${task.ctdpTotalFailures} · 辅链失败 ${task.ctdpAuxFailures}',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: context.tokens.mutedText),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => onAction(
                task.ctdpIsGroup
                    ? 'group_start'
                    : task.ctdpReservationPending
                    ? 'confirm'
                    : 'start',
              ),
              icon: Icon(
                task.ctdpReservationPending
                    ? Icons.check_circle_outline
                    : Icons.play_arrow,
              ),
              label: Text(
                task.ctdpIsGroup
                    ? '启动任务组时限'
                    : task.ctdpReservationPending
                    ? '确认触发并开始'
                    : '开始本轮专注',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RsipCard extends StatelessWidget {
  const _RsipCard({
    required this.node,
    required this.now,
    required this.settledToday,
    required this.onAction,
  });

  final WorkspaceRecord node;
  final DateTime now;
  final bool settledToday;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final dueAt = DateTime.tryParse(
      node.data['rsipTimerDueAt']?.toString() ?? '',
    )?.toLocal();
    final frozenUntil = DateTime.tryParse(
      node.data['rsipFrozenUntil']?.toString() ?? '',
    )?.toLocal();
    final descriptionStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(fontSize: 14);
    return LogSurface(
      accent: node.rsipFrozen
          ? context.tokens.info
          : node.rsipActive
          ? Theme.of(context).colorScheme.primary
          : context.tokens.mutedText,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                node.rsipActive
                    ? Icons.account_tree_outlined
                    : Icons.power_off_outlined,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      node.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '最小动作：${node.rsipMinimumAction}',
                      style: descriptionStyle,
                    ),
                    if (node.rsipRule.isNotEmpty)
                      Text('规则：${node.rsipRule}', style: descriptionStyle),
                    if (node.rsipTimerRunning && dueAt != null)
                      Text(
                        '计时 ${_countdown(dueAt.difference(now))}',
                        style: descriptionStyle,
                      ),
                    if (node.rsipFrozen && frozenUntil != null)
                      Text(
                        '水密隔舱至 ${_dateTime(frozenUntil)}',
                        style: descriptionStyle,
                      ),
                    const SizedBox(height: 5),
                    Text(
                      '${node.rsipActive ? '生效' : '熄灭'} · 连续 #${node.rsipChainCount} · 内化 ${node.rsipInternalization}% · 失败 ${node.rsipFailureCount}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: context.tokens.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'RSIP 国策操作',
                onSelected: onAction,
                itemBuilder: (context) => [
                  if (node.rsipActive && !node.rsipFrozen) ...[
                    if (node.rsipUseTimer && !node.rsipTimerRunning)
                      const PopupMenuItem(
                        value: 'timer_start',
                        child: Text('开始最小动作计时'),
                      ),
                    if (node.rsipTimerRunning)
                      const PopupMenuItem(
                        value: 'timer_complete',
                        child: Text('结算计时'),
                      ),
                    if (!node.rsipUseTimer)
                      const PopupMenuItem(value: 'done', child: Text('完成最小动作')),
                    const PopupMenuItem(
                      value: 'freeze',
                      child: Text('水密隔舱 24 小时'),
                    ),
                    const PopupMenuItem(value: 'fail', child: Text('失败并熄灭分支')),
                  ],
                  if (!node.rsipActive)
                    const PopupMenuItem(
                      value: 'reactivate',
                      child: Text('重建当前节点'),
                    ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: 'child', child: Text('新增子国策')),
                  const PopupMenuItem(value: 'edit', child: Text('编辑国策')),
                  const PopupMenuItem(value: 'trash', child: Text('移入回收站')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ProtocolStageBand(
            key: ValueKey('protocol-stage-${node.id}'),
            labels: [
              node.rsipFrozen
                  ? '水密隔舱'
                  : node.rsipActive
                  ? '规则生效'
                  : '待重建',
              node.rsipTimerRunning ? '最小行动计时' : '最小行动',
              '今日已结算',
            ],
            selected: node.rsipFrozen || !node.rsipActive
                ? 0
                : settledToday
                ? 2
                : 1,
            color: node.rsipFrozen ? context.tokens.info : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              StatusPill(
                label: '内化 ${node.rsipInternalization}%',
                fontSize: 13,
                icon: Icons.auto_graph_outlined,
              ),
            ],
          ),
          if (!node.rsipFrozen) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => onAction(
                !node.rsipActive
                    ? 'reactivate'
                    : node.rsipUseTimer
                    ? node.rsipTimerRunning
                          ? 'timer_complete'
                          : 'timer_start'
                    : 'done',
              ),
              icon: Icon(
                !node.rsipActive
                    ? Icons.restart_alt
                    : node.rsipTimerRunning
                    ? Icons.check
                    : Icons.play_arrow,
              ),
              label: Text(
                !node.rsipActive
                    ? '重建当前节点'
                    : node.rsipUseTimer
                    ? node.rsipTimerRunning
                          ? '结算最小行动'
                          : '开始最小行动'
                    : '完成最小行动',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A view of persisted protocol state; only the current stage is highlighted.
/// Earlier stages are not marked complete because CTDP reservations are optional.
class _ProtocolStageBand extends StatelessWidget {
  const _ProtocolStageBand({
    super.key,
    required this.labels,
    required this.selected,
    this.color,
  });

  final List<String> labels;
  final int selected;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? Theme.of(context).colorScheme.primary;
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13);
    return Semantics(
      label: '协议阶段',
      value: '${labels.join(' → ')}；当前：${labels[selected]}',
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact =
                constraints.maxWidth < 420 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.5;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    for (var index = 0; index < labels.length; index++) ...[
                      if (index > 0) const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 3,
                              decoration: BoxDecoration(
                                color: index == selected
                                    ? activeColor
                                    : context.tokens.divider,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.xs,
                                ),
                              ),
                            ),
                            if (!compact) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                labels[index],
                                style: style?.copyWith(
                                  color: index == selected
                                      ? activeColor
                                      : context.tokens.mutedText,
                                  fontWeight: index == selected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                if (compact) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    labels[selected],
                    style: style?.copyWith(
                      color: activeColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

enum _ProtocolOutcome { success, failure, informational }

_ProtocolOutcome _protocolOutcome(WorkspaceRecord event) {
  final action = event.data['action'];
  if (event.data['protocol'] == 'ctdp') {
    if (const {
      'round_completed',
      'round_completed_early',
      'group_completed',
      'task_closed',
    }.contains(action)) {
      return _ProtocolOutcome.success;
    }
    if (const {
      'main_failed',
      'auxiliary_failed',
      'reservation_expired',
      'group_expired',
      'task_reopened',
    }.contains(action)) {
      return _ProtocolOutcome.failure;
    }
  }
  if (event.data['protocol'] == 'rsip' && action == 'node_settled') {
    return switch (event.data['executionStatus']) {
      'executed' => _ProtocolOutcome.success,
      'violated' => _ProtocolOutcome.failure,
      _ => _ProtocolOutcome.informational,
    };
  }
  return _ProtocolOutcome.informational;
}

class _ProtocolAnalyticsSnapshot {
  const _ProtocolAnalyticsSnapshot({
    required this.events,
    required this.days,
    required this.bucketDates,
    required this.successCounts,
    required this.failureCounts,
    required this.successes,
    required this.failures,
  });

  factory _ProtocolAnalyticsSnapshot.fromEvents(
    List<WorkspaceRecord> source,
    DateTime now,
    int days,
  ) {
    final today = DateTime(now.year, now.month, now.day);
    final first = today.subtract(Duration(days: days - 1));
    final bucketCount = days == 7 ? 7 : 6;
    final bucketDates = List.generate(
      bucketCount,
      (index) => first.add(Duration(days: index * (days == 7 ? 1 : 5))),
    );
    final successCounts = List<int>.filled(bucketCount, 0);
    final failureCounts = List<int>.filled(bucketCount, 0);
    final events = <WorkspaceRecord>[];
    var successes = 0;
    var failures = 0;
    final firstUtc = DateTime.utc(first.year, first.month, first.day);
    for (final event in source) {
      if (event.data['protocol'] != 'ctdp' &&
          event.data['protocol'] != 'rsip') {
        continue;
      }
      events.add(event);
      final outcome = _protocolOutcome(event);
      if (outcome == _ProtocolOutcome.informational) continue;
      if (outcome == _ProtocolOutcome.success) {
        successes++;
      } else {
        failures++;
      }
      final at = (event.scheduledFor ?? event.createdAt).toLocal();
      final dayOffset = DateTime.utc(
        at.year,
        at.month,
        at.day,
      ).difference(firstUtc).inDays;
      if (dayOffset < 0 || dayOffset >= days) continue;
      final bucket = days == 7 ? dayOffset : dayOffset ~/ 5;
      if (outcome == _ProtocolOutcome.success) {
        successCounts[bucket]++;
      } else {
        failureCounts[bucket]++;
      }
    }
    return _ProtocolAnalyticsSnapshot(
      events: events,
      days: days,
      bucketDates: bucketDates,
      successCounts: successCounts,
      failureCounts: failureCounts,
      successes: successes,
      failures: failures,
    );
  }

  final List<WorkspaceRecord> events;
  final int days;
  final List<DateTime> bucketDates;
  final List<int> successCounts;
  final List<int> failureCounts;
  final int successes;
  final int failures;

  bool get hasPeriodOutcomes =>
      successCounts.any((count) => count > 0) ||
      failureCounts.any((count) => count > 0);
}

class _ProtocolOutcomeTimeline extends StatelessWidget {
  const _ProtocolOutcomeTimeline({
    required this.snapshot,
    required this.onDaysChanged,
  });

  final _ProtocolAnalyticsSnapshot snapshot;
  final ValueChanged<int> onDaysChanged;

  @override
  Widget build(BuildContext context) {
    final maximum = List.generate(snapshot.bucketDates.length, (index) {
      return snapshot.successCounts[index] + snapshot.failureCounts[index];
    }).fold<int>(1, (maximum, count) => count > maximum ? count : maximum);
    const weekday = ['一', '二', '三', '四', '五', '六', '日'];
    return LogSurface(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('近期结算', style: Theme.of(context).textTheme.titleMedium),
              ChoiceChip(
                label: const Text('7 日'),
                selected: snapshot.days == 7,
                onSelected: (_) => onDaysChanged(7),
              ),
              ChoiceChip(
                label: const Text('30 日'),
                selected: snapshot.days == 30,
                onSelected: (_) => onDaysChanged(30),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            snapshot.days == 7
                ? '仅统计有成功或失败结论的协议事件。'
                : '每格汇总 5 日，只统计有成功或失败结论的协议事件。',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: context.tokens.mutedText),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: !snapshot.hasPeriodOutcomes
                ? Text(
                    '近 ${snapshot.days} 日暂无可判定结算。',
                    key: ValueKey('empty-${snapshot.days}'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                : Column(
                    key: ValueKey('chart-${snapshot.days}'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 94,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (
                              var index = 0;
                              index < snapshot.bucketDates.length;
                              index++
                            )
                              Expanded(
                                child: Semantics(
                                  label:
                                      '${snapshot.bucketDates[index].month}月'
                                      '${snapshot.bucketDates[index].day}日起，'
                                      '成功 ${snapshot.successCounts[index]} 次，'
                                      '失败 ${snapshot.failureCounts[index]} 次',
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: Column(
                                      children: [
                                        Expanded(
                                          child: Align(
                                            alignment: Alignment.bottomCenter,
                                            child: SizedBox(
                                              width: 18,
                                              child: FractionallySizedBox(
                                                key: ValueKey(
                                                  'protocol-outcome-bar-$index',
                                                ),
                                                heightFactor:
                                                    (snapshot.successCounts[index] +
                                                            snapshot
                                                                .failureCounts[index]) ==
                                                        0
                                                    ? 0.06
                                                    : (snapshot.successCounts[index] +
                                                              snapshot
                                                                  .failureCounts[index]) /
                                                          maximum,
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .stretch,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.end,
                                                  children: [
                                                    if (snapshot
                                                            .failureCounts[index] >
                                                        0)
                                                      Expanded(
                                                        flex: snapshot
                                                            .failureCounts[index],
                                                        child: ColoredBox(
                                                          color: Theme.of(
                                                            context,
                                                          ).colorScheme.error,
                                                        ),
                                                      ),
                                                    if (snapshot
                                                            .successCounts[index] >
                                                        0)
                                                      Expanded(
                                                        flex: snapshot
                                                            .successCounts[index],
                                                        child: ColoredBox(
                                                          color: Theme.of(
                                                            context,
                                                          ).colorScheme.primary,
                                                        ),
                                                      ),
                                                    if (snapshot.successCounts[index] +
                                                            snapshot
                                                                .failureCounts[index] ==
                                                        0)
                                                      Expanded(
                                                        child: ColoredBox(
                                                          color: context
                                                              .tokens
                                                              .orbitTrack,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        ExcludeSemantics(
                                          child: Text(
                                            snapshot.days == 7
                                                ? weekday[snapshot
                                                          .bucketDates[index]
                                                          .weekday -
                                                      1]
                                                : '${snapshot.bucketDates[index].day}',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.labelSmall,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 14,
                        runSpacing: 4,
                        children: [
                          _OutcomeLegend(
                            color: Theme.of(context).colorScheme.primary,
                            label: '成功',
                          ),
                          _OutcomeLegend(
                            color: Theme.of(context).colorScheme.error,
                            label: '失败',
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
}

class _OutcomeLegend extends StatelessWidget {
  const _OutcomeLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 5),
      Text(label, style: Theme.of(context).textTheme.labelMedium),
    ],
  );
}

class _MetricStrip extends StatelessWidget {
  const _MetricStrip({required this.values});

  final List<(String, int)> values;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        final columns = constraints.maxWidth >= 640
            ? 4
            : constraints.maxWidth >= 340
            ? 2
            : 1;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final value in values)
              SizedBox(
                width: width,
                child: LogSurface(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      NumericText(
                        '${value.$2}',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        value.$1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ChainBadge extends StatelessWidget {
  const _ChainBadge({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: context.tokens.divider),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label #$count',
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event, required this.onDelete});

  final WorkspaceRecord event;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final outcome = _protocolOutcome(event);
    final compact =
        WorkbenchViewport.sizeOf(context).width < 600 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.5;
    final at = _dateTime(event.scheduledFor ?? event.createdAt);
    final detail =
        '${event.data['protocol']?.toString().toUpperCase()} · '
        '${_actionLabel(event.data['action']?.toString())}';
    final color = switch (outcome) {
      _ProtocolOutcome.success => Theme.of(context).colorScheme.primary,
      _ProtocolOutcome.failure => Theme.of(context).colorScheme.error,
      _ProtocolOutcome.informational => context.accents.slate.color,
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(switch (outcome) {
        _ProtocolOutcome.success => Icons.check_circle_outline,
        _ProtocolOutcome.failure => Icons.error_outline,
        _ProtocolOutcome.informational => Icons.info_outline,
      }, color: color),
      title: Text(event.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        compact ? '$detail · $at' : detail,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!compact) Text(at),
          IconButton(
            tooltip: '删除记录',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

String _ruleTypeLabel(String? value) => switch (value) {
  'pause' => '暂停',
  'early_completion' => '提前完成',
  'interruption' => '允许中断',
  _ => value ?? '未知',
};

String _actionLabel(String? value) => switch (value) {
  'reservation_started' => '创建预约',
  'task_closed' => '任务完成',
  'task_reopened' => '重新打开任务',
  'reservation_confirmed' => '预约触发',
  'reservation_expired' => '预约超时',
  'round_completed' => '完成本轮',
  'round_completed_early' => '提前完成',
  'main_failed' => '主链失败',
  'auxiliary_failed' => '辅助链失败',
  'group_started' => '任务组启动',
  'group_completed' => '任务组完成',
  'group_expired' => '任务组超时',
  'timer_started' => '最小动作计时',
  'timer_completed' => '计时完成',
  'branch_frozen' => '水密隔舱',
  'node_thawed' => '自动解冻',
  'branch_failed' => '分支熄灭',
  'daily_victory' => '今日胜利',
  'daily_settlement' => 'RSIP 自动日结',
  'node_settled' => '节点结算',
  'node_created' => '创建节点',
  'run_started' => '启动规则树',
  'run_collapsed' => '规则树收束',
  'execution_corrected' => '结算更正',
  'pause_rule_used' => '使用暂停判例',
  'early_completion_rule_used' => '使用提前完成判例',
  'interruption_rule_used' => '使用中断判例',
  _ => value ?? '协议事件',
};

String _countdown(Duration value) {
  if (value.isNegative) return '00:00';
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}

String _dateTime(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$month-$day $hour:$minute';
}
