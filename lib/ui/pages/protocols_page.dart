import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/workspace_record.dart';
import '../../core/theme/app_theme.dart';
import '../../state/workbench_controller.dart';
import '../widgets/common.dart';
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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final TabController tabController;
  Timer? ticker;
  String ruleQuery = '';
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
    final tabs = _tabs;
    tabController = TabController(
      length: tabs.length,
      initialIndex: tabs.indexOf(widget.initialTab).clamp(0, tabs.length - 1),
      vsync: this,
    )..addListener(_handleTabChanged);
    _startTicker();
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
    final tabs = _tabs;
    return Column(
      children: [
        if (widget.showHeader)
          PageHeader(
            title: widget.controller.advancedFeaturesEnabled ? '协议' : '目标与习惯',
            subtitle: widget.controller.advancedFeaturesEnabled
                ? '结果协议 · 行为协议 · CTDP 执行链 · RSIP 规则树'
                : '用结果协议明确方向，用习惯协议稳定行动',
            actions: [
              if (tabController.index <= 2)
                FilledButton.icon(
                  onPressed: _createForCurrentTab,
                  icon: const Icon(Icons.add),
                  label: Text(switch (tabs[tabController.index]) {
                    ProtocolTab.goals => '新建目标',
                    ProtocolTab.habits => '新建习惯',
                    _ => '新建执行协议',
                  }),
                ),
            ],
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TabBar(
            controller: tabController,
            isScrollable: true,
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
    );
  }

  List<ProtocolTab> get _tabs => widget.controller.advancedFeaturesEnabled
      ? ProtocolTab.values
      : const [ProtocolTab.goals, ProtocolTab.habits];

  Widget _tabWidget(ProtocolTab tab) => switch (tab) {
    ProtocolTab.goals => const Tab(icon: Icon(Icons.flag_outlined), text: '目标'),
    ProtocolTab.habits => const Tab(icon: Icon(Icons.repeat), text: '习惯'),
    ProtocolTab.execution => const Tab(icon: Icon(Icons.link), text: '执行协议'),
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
    ProtocolTab.goals => GoalsPage(
      controller: widget.controller,
      showHeader: false,
    ),
    ProtocolTab.habits => HabitsPage(
      controller: widget.controller,
      showHeader: false,
      protocolSection: widget.controller.advancedFeaturesEnabled
          ? ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: const Text('RSIP 规则树'),
              subtitle: const Text('高级行为规则与最小行动结算'),
              children: _rsipContent(),
            )
          : null,
    ),
    ProtocolTab.execution => _ctdpView(),
    ProtocolTab.rules => _rulesView(),
    ProtocolTab.analytics => _analyticsView(),
  };

  void _handleTabChanged() {
    if (!tabController.indexIsChanging && mounted) setState(() {});
  }

  Future<void> _createForCurrentTab() {
    final current = _tabs[tabController.index];
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

  Widget _ctdpView() {
    final chains = widget.controller.ctdpTasks;
    final roots = chains.where((task) => task.parentId == null).toList();
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
            ('链条', chains.length),
            ('待触发', chains.where((task) => task.ctdpReservationPending).length),
            (
              '主链轮次',
              chains.fold(0, (sum, task) => sum + task.ctdpTotalCompletions),
            ),
            ('失败', chains.fold(0, (sum, task) => sum + task.ctdpTotalFailures)),
          ],
        ),
        const SizedBox(height: 18),
        if (chains.isEmpty)
          EmptyState(
            icon: Icons.link_off_outlined,
            title: '还没有 CTDP 链',
            message: '创建任务并定义触发标志、预约缓冲和完成时长。',
            action: FilledButton(
              onPressed: () => showRecordEditor(
                context,
                widget.controller,
                kind: RecordKind.task,
              ),
              child: const Text('创建第一条链'),
            ),
          )
        else
          for (final task in roots) ..._ctdpTree(task, 0),
      ],
    );
  }

  List<Widget> _ctdpTree(WorkspaceRecord task, int depth) {
    final children = widget.controller.ctdpChildren(task.id);
    return [
      Padding(
        padding: EdgeInsets.only(left: depth * 20, bottom: 10),
        child: _CtdpCard(
          task: task,
          controller: widget.controller,
          now: widget.controller.currentTime(),
          onAction: (action) => _handleCtdpAction(task, action),
        ),
      ),
      for (final child in children) ..._ctdpTree(child, depth + 1),
    ];
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
          await showRecordEditor(
            context,
            widget.controller,
            kind: RecordKind.task,
            record: task,
          );
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
    final roots = nodes.where((habit) => habit.parentId == null).toList();
    return [
      LogSurface(
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('允许一天新增多个节点'),
          subtitle: const Text('默认遵守每日只增加一条国策；仅在已明确设计好树结构时开启。'),
          value: widget.controller.rsipAllowMultiplePerDay,
          onChanged: widget.controller.setRsipAllowMultiplePerDay,
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          FilledButton.icon(
            onPressed: () => showRecordEditor(
              context,
              widget.controller,
              kind: RecordKind.habit,
            ),
            icon: const Icon(Icons.add),
            label: const Text('新增国策'),
          ),
          const SizedBox(width: 10),
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
        for (final root in roots) ..._rsipTree(root, nodes, 0),
    ];
  }

  List<Widget> _rsipTree(
    WorkspaceRecord node,
    List<WorkspaceRecord> all,
    int depth,
  ) {
    final children = all.where((item) => item.parentId == node.id).toList();
    return [
      Padding(
        padding: EdgeInsets.only(left: depth * 20, bottom: 10),
        child: _RsipCard(
          node: node,
          now: widget.controller.currentTime(),
          onAction: (action) => _handleRsipAction(node, action),
        ),
      ),
      for (final child in children) ..._rsipTree(child, all, depth + 1),
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
          );
        case 'edit':
          if (!mounted) return;
          await showRecordEditor(
            context,
            widget.controller,
            kind: RecordKind.habit,
            record: node,
          );
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
    final rules = widget.controller.exceptionRules.where((rule) {
      return query.isEmpty ||
          rule.title.toLowerCase().contains(query) ||
          rule.body.toLowerCase().contains(query);
    }).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        20,
        18,
        20,
        AppSpacing.bottomNavClearance,
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: SearchBar(
                hintText: '搜索判例名称或说明',
                leading: const Icon(Icons.search),
                onChanged: (value) => setState(() => ruleQuery = value),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: _createRule,
              icon: const Icon(Icons.add),
              label: const Text('新建判例'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (rules.isEmpty)
          const EmptyState(
            icon: Icons.gavel_outlined,
            title: '还没有判例',
            message: '暂停、提前完成和允许中断都必须先有可引用的规则。',
          )
        else
          for (final rule in rules)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: LogSurface(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    rule.data['archived'] == true
                        ? Icons.archive_outlined
                        : Icons.gavel_outlined,
                  ),
                  title: Text(rule.title),
                  subtitle: Text(
                    '${_ruleTypeLabel(rule.data['ruleType']?.toString())} · '
                    '${rule.data['scope'] == 'global' ? '全局' : '任务'} · '
                    '使用 ${(rule.data['usageCount'] as num?)?.toInt() ?? 0} 次\n${rule.body}',
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    tooltip: rule.data['archived'] == true ? '恢复判例' : '归档判例',
                    onPressed: () => widget.controller.archiveExceptionRule(
                      rule,
                      rule.data['archived'] != true,
                    ),
                    icon: Icon(
                      rule.data['archived'] == true
                          ? Icons.unarchive_outlined
                          : Icons.archive_outlined,
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
  }

  Widget _analyticsView() {
    final events = widget.controller.protocolEvents;
    final successes = events
        .where((event) => event.data['successful'] == true)
        .length;
    final failures = events
        .where((event) => event.data['successful'] == false)
        .length;
    final resolved = successes + failures;
    final successRate = resolved == 0 ? 0.0 : successes / resolved;
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
            ('成功结算', successes),
            ('失败结算', failures),
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
        const SizedBox(height: 18),
        LogSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('可判定事件成功率', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              LinearProgressIndicator(value: successRate, minHeight: 10),
              const SizedBox(height: 6),
              Text(
                '${(successRate * 100).toStringAsFixed(1)}% · $resolved 次有效结算',
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const SectionHeading(title: '最近协议记录', scale: 'AUDIT LOG'),
        if (events.isEmpty)
          const Text('尚无协议事件。')
        else
          LogSurface(
            child: Column(
              children: [
                for (
                  var index = 0;
                  index < events.take(30).length;
                  index++
                ) ...[
                  _EventTile(event: events[index]),
                  if (index < events.take(30).length - 1) const Divider(),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _createRule() async {
    final name = TextEditingController();
    final description = TextEditingController();
    var type = 'pause';
    var scope = 'global';
    String? chainId;
    final created = await showWorkbenchDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('新建结构化判例'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExternalField(
                    label: '判例名称',
                    child: TextField(
                      controller: name,
                      autofocus: true,
                      decoration: const InputDecoration(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ExternalField(
                    label: '适用条件',
                    child: TextField(
                      controller: description,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ExternalField(
                    label: '允许行为',
                    child: DropdownButtonFormField<String>(
                      initialValue: type,
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
                      onChanged: (value) => setDialogState(() => type = value!),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ExternalField(
                    label: '作用范围',
                    child: DropdownButtonFormField<String>(
                      initialValue: scope,
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
                      onChanged: (value) => setDialogState(() {
                        scope = value!;
                        if (scope == 'global') chainId = null;
                      }),
                    ),
                  ),
                  if (scope == 'chain') ...[
                    const SizedBox(height: 12),
                    ExternalField(
                      label: '适用任务',
                      child: DropdownButtonFormField<String>(
                        initialValue: chainId,
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
                        onChanged: (value) =>
                            setDialogState(() => chainId = value),
                      ),
                    ),
                  ],
                ],
              ),
            ),
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
    if (created == true) {
      try {
        await widget.controller.createExceptionRule(
          name: name.text,
          description: description.text,
          ruleType: type,
          scope: scope,
          chainId: chainId,
        );
      } on FormatException catch (error) {
        if (mounted) {
          showWorkbenchSnackBar(
            context,
            SnackBar(content: Text(error.message.toString())),
          );
        }
      }
    }
    name.dispose();
    description.dispose();
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

class _CtdpCard extends StatelessWidget {
  const _CtdpCard({
    required this.task,
    required this.controller,
    required this.now,
    required this.onAction,
  });

  final WorkspaceRecord task;
  final WorkbenchController controller;
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
    final children = task.ctdpIsGroup
        ? controller.ctdpChildren(task.id)
        : const <WorkspaceRecord>[];
    final completedChildren = groupStarted == null
        ? 0
        : children.where((child) {
            final completedAt = DateTime.tryParse(
              child.data['ctdpLastCompletedAt']?.toString() ?? '',
            )?.toLocal();
            return completedAt != null && !completedAt.isBefore(groupStarted);
          }).length;
    return LogSurface(
      accent: task.ctdpReservationPending
          ? context.tokens.reward
          : Theme.of(context).colorScheme.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(task.ctdpIsGroup ? Icons.account_tree_outlined : Icons.link),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  task.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              _ChainBadge(label: '主', count: task.ctdpChainCount),
              const SizedBox(width: 6),
              _ChainBadge(label: '辅', count: task.ctdpAuxChainCount),
              PopupMenuButton<String>(
                tooltip: 'CTDP 链操作',
                onSelected: onAction,
                itemBuilder: (context) => [
                  if (task.ctdpIsGroup)
                    const PopupMenuItem(
                      value: 'group_start',
                      child: Text('启动任务组时限'),
                    )
                  else ...[
                    const PopupMenuItem(value: 'start', child: Text('直接开始本轮')),
                    if (!task.ctdpReservationPending)
                      PopupMenuItem(
                        value: 'reserve',
                        child: Text('预约 ${task.ctdpDelayMinutes} 分钟后开始'),
                      )
                    else ...[
                      const PopupMenuItem(
                        value: 'confirm',
                        child: Text('确认触发并开始'),
                      ),
                      const PopupMenuItem(
                        value: 'aux_fail',
                        child: Text('辅助链失败'),
                      ),
                    ],
                  ],
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: 'copy', child: Text('复制链条')),
                  const PopupMenuItem(value: 'edit', child: Text('编辑 / 移动')),
                  const PopupMenuItem(value: 'trash', child: Text('移入回收站')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (task.ctdpIsGroup) ...[
            Text(
              '任务组 · ${children.length} 个单元 · 时限 ${task.ctdpGroupTimeLimitHours == 0 ? '不限' : '${task.ctdpGroupTimeLimitHours} 小时'}',
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
              Text('本轮进度 $completedChildren / ${children.length}'),
            ],
          ] else ...[
            Text('触发：${task.ctdpTrigger}'),
            if (task.ctdpAuxSignal.isNotEmpty) Text('辅助：${task.ctdpAuxSignal}'),
            Text(
              task.ctdpIsDurationless
                  ? '正计时 · 最低 ${task.ctdpMinimumMinutes} 分钟'
                  : '本轮 ${task.ctdpSessionMinutes} 分钟',
            ),
          ],
          if (task.ctdpReservationPending && dueAt != null) ...[
            const SizedBox(height: 8),
            Text(
              '预约倒计时 ${_countdown(dueAt.difference(now))}',
              style: TextStyle(
                color: context.tokens.reward,
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
        ],
      ),
    );
  }
}

class _RsipCard extends StatelessWidget {
  const _RsipCard({
    required this.node,
    required this.now,
    required this.onAction,
  });

  final WorkspaceRecord node;
  final DateTime now;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final dueAt = DateTime.tryParse(
      node.data['rsipTimerDueAt']?.toString() ?? '',
    )?.toLocal();
    final frozenUntil = DateTime.tryParse(
      node.data['rsipFrozenUntil']?.toString() ?? '',
    )?.toLocal();
    return LogSurface(
      accent: node.rsipFrozen
          ? context.tokens.reward
          : node.rsipActive
          ? Theme.of(context).colorScheme.primary
          : context.tokens.mutedText,
      child: Row(
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
                Text('${node.rsipGroup} · 最小动作：${node.rsipMinimumAction}'),
                if (node.rsipRule.isNotEmpty) Text('规则：${node.rsipRule}'),
                if (node.rsipTimerRunning && dueAt != null)
                  Text('计时 ${_countdown(dueAt.difference(now))}'),
                if (node.rsipFrozen && frozenUntil != null)
                  Text('水密隔舱至 ${_dateTime(frozenUntil)}'),
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
                const PopupMenuItem(value: 'freeze', child: Text('水密隔舱 24 小时')),
                const PopupMenuItem(value: 'fail', child: Text('失败并熄灭分支')),
              ],
              if (!node.rsipActive)
                const PopupMenuItem(value: 'reactivate', child: Text('重建当前节点')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'child', child: Text('新增子国策')),
              const PopupMenuItem(value: 'edit', child: Text('编辑国策')),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricStrip extends StatelessWidget {
  const _MetricStrip({required this.values});

  final List<(String, int)> values;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final value in values)
          SizedBox(
            width: 150,
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
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            ),
          ),
      ],
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
      child: Text('$label #$count'),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});

  final WorkspaceRecord event;

  @override
  Widget build(BuildContext context) {
    final success = event.data['successful'] != false;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        success ? Icons.check_circle_outline : Icons.error_outline,
        color: success
            ? Theme.of(context).colorScheme.primary
            : context.tokens.reward,
      ),
      title: Text(event.title),
      subtitle: Text(
        '${event.data['protocol']?.toString().toUpperCase()} · '
        '${_actionLabel(event.data['action']?.toString())}',
      ),
      trailing: Text(_dateTime(event.scheduledFor ?? event.createdAt)),
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
