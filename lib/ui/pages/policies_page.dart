import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/models/workspace_record.dart';
import '../../core/models/workspace_models_v3.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../state/workbench_controller.dart';
import '../widgets/common.dart';

enum PolicyTab { tree, library, history, analytics }

class PoliciesPage extends StatefulWidget {
  const PoliciesPage({
    super.key,
    required this.controller,
    this.showHeader = true,
    this.initialTab = PolicyTab.tree,
    this.showTabs = true,
  });

  final WorkbenchController controller;
  final bool showHeader;
  final PolicyTab initialTab;
  final bool showTabs;

  @override
  State<PoliciesPage> createState() => _PoliciesPageState();
}

class _PoliciesPageState extends State<PoliciesPage> {
  final Set<String> _collapsed = {};
  final Set<RsipNodeType> _typeFilters = {};

  @override
  Widget build(BuildContext context) {
    final actions = _pageActions();
    return DefaultTabController(
      length: PolicyTab.values.length,
      initialIndex: widget.initialTab.index,
      child: Column(
        children: [
          if (widget.showHeader)
            PageHeader(
              title: '国策',
              subtitle: '递归稳态迭代协议 · 本地事实与轮次记录',
              actions: actions,
            )
          else if (!widget.showTabs)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Align(
                alignment: Alignment.centerRight,
                child: _compactActions(),
              ),
            ),
          if (widget.showTabs)
            SizedBox(
              height: 50,
              child: widget.showHeader
                  ? _policyTabs()
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: context.tokens.divider),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _policyTabs(
                              dividerColor: Colors.transparent,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _compactActions(),
                          ),
                        ],
                      ),
                    ),
            ),
          Expanded(
            child: TabBarView(
              children: [_tree(), _library(), _history(), _analytics()],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _pageActions() => [
    IconButton(
      tooltip: '新建国策组',
      onPressed: () => _showGroupEditor(),
      icon: const Icon(Icons.create_new_folder_outlined),
    ),
    IconButton(
      tooltip: '拆分目标',
      onPressed: _showSplitDialog,
      icon: const Icon(Icons.call_split_outlined),
    ),
    const SizedBox(width: 6),
    FilledButton.icon(
      onPressed: () => _showNodeEditor(),
      icon: const Icon(Icons.add),
      label: const Text('添加国策'),
    ),
  ];

  Widget _compactActions() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: '新建国策组',
        onPressed: () => _showGroupEditor(),
        icon: const Icon(Icons.create_new_folder_outlined),
      ),
      IconButton(
        tooltip: '拆分目标',
        onPressed: _showSplitDialog,
        icon: const Icon(Icons.call_split_outlined),
      ),
      IconButton(
        tooltip: '添加国策',
        onPressed: () => _showNodeEditor(),
        icon: const Icon(Icons.add),
      ),
    ],
  );

  Widget _policyTabs({Color? dividerColor}) => TabBar(
    isScrollable: true,
    dividerColor: dividerColor,
    labelPadding: const EdgeInsets.symmetric(horizontal: 12),
    tabs: const [
      Tab(
        height: 48,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_tree_outlined, size: 20),
            SizedBox(width: 6),
            Text('国策树'),
          ],
        ),
      ),
      Tab(
        height: 48,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, size: 20),
            SizedBox(width: 6),
            Text('国策库'),
          ],
        ),
      ),
      Tab(
        height: 48,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_outlined, size: 20),
            SizedBox(width: 6),
            Text('轮次历史'),
          ],
        ),
      ),
      Tab(
        height: 48,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.analytics_outlined, size: 20),
            SizedBox(width: 6),
            Text('高级分析'),
          ],
        ),
      ),
    ],
  );

  Widget _tree() {
    final nodes = widget.controller.activeRsipHabits;
    final nodeIds = nodes.map((node) => node.id).toSet();
    final roots =
        nodes
            .where(
              (node) =>
                  node.parentId == null || !nodeIds.contains(node.parentId),
            )
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final visibleIds = _visibleNodeIds(nodes);
    final maxDepth = nodes.isEmpty
        ? 1
        : nodes.map((node) => _nodeDepth(node, nodes)).reduce(math.max);
    final canvasWidth = math.max(960.0, visibleIds.length * 300.0);
    final canvasHeight = math.max(560.0, (maxDepth + 1) * 190.0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 132),
      children: [
        LogSurface(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: widget.controller.rsipStrictMode,
                secondary: const Icon(Icons.rule_outlined),
                title: const Text('严格模式'),
                subtitle: const Text('每个逻辑日只允许一次新增；切换前需结束计时并结算当日节点'),
                onChanged: _setMode,
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.balance_outlined),
                title: const Text('主动维护成本'),
                subtitle: const Text('被动国策仍需结算，但不计入主动维护数量'),
                trailing: Text(
                  '${widget.controller.activeRsipMaintenanceCount} 项',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _typeFilterBar(),
        if (widget.controller.rsipNodeGroups.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final group in widget.controller.rsipNodeGroups)
                ActionChip(
                  avatar: Text(group.emoji),
                  label: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '${group.record.title} · 容错 ${group.remainingTolerance}/${group.initialTolerance}',
                      style: const TextStyle(height: 1),
                    ),
                  ),
                  tooltip: '编辑国策组',
                  onPressed: () => _showGroupEditor(existing: group.record),
                ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        if (nodes.isEmpty)
          const EmptyState(
            icon: Icons.account_tree_outlined,
            title: '还没有国策节点',
            message: '创建第一个节点后，根节点会显示在树的底部。',
          )
        else if (visibleIds.isEmpty)
          const EmptyState(
            icon: Icons.filter_alt_off_outlined,
            title: '没有符合筛选的节点',
            message: '调整上方类型筛选后再查看。',
          )
        else
          LayoutBuilder(
            builder: (context, constraints) => SizedBox(
              height: math.min(720, math.max(320, constraints.maxHeight)),
              child: InteractiveViewer(
                minScale: 0.45,
                maxScale: 2.5,
                constrained: false,
                boundaryMargin: const EdgeInsets.all(160),
                child: SizedBox(
                  width: canvasWidth,
                  height: canvasHeight,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final root in roots)
                          if (visibleIds.contains(root.id))
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: _branch(root, nodes, visibleIds),
                            ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _typeFilterBar() {
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('类型筛选', style: Theme.of(context).textTheme.labelLarge),
        for (final type in RsipNodeType.values)
          FilterChip(
            selected: _typeFilters.contains(type),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: Center(child: Icon(_typeIcon(type), size: 16)),
                ),
                const SizedBox(width: 5),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    _typeLabel(type),
                    style: const TextStyle(height: 1),
                  ),
                ),
              ],
            ),
            onSelected: (selected) => setState(() {
              if (selected) {
                _typeFilters.add(type);
              } else {
                _typeFilters.remove(type);
              }
            }),
          ),
        if (_typeFilters.isNotEmpty)
          TextButton.icon(
            onPressed: () => setState(_typeFilters.clear),
            icon: const Icon(Icons.filter_alt_off_outlined),
            label: const Text('清除'),
          ),
      ],
    );
  }

  Set<String> _visibleNodeIds(List<WorkspaceRecord> nodes) {
    if (_typeFilters.isEmpty) return nodes.map((node) => node.id).toSet();
    final byId = {for (final node in nodes) node.id: node};
    final visible = <String>{};
    for (final node in nodes) {
      if (!_typeFilters.contains(RsipNode.fromRecord(node).type)) continue;
      WorkspaceRecord? current = node;
      while (current != null && visible.add(current.id)) {
        current = current.parentId == null ? null : byId[current.parentId];
      }
    }
    return visible;
  }

  int _nodeDepth(WorkspaceRecord node, List<WorkspaceRecord> nodes) {
    final byId = {for (final value in nodes) value.id: value};
    var depth = 0;
    var parentId = node.parentId;
    final visited = <String>{node.id};
    while (parentId != null && visited.add(parentId)) {
      final parent = byId[parentId];
      if (parent == null) break;
      depth++;
      parentId = parent.parentId;
    }
    return depth;
  }

  Widget _branch(
    WorkspaceRecord node,
    List<WorkspaceRecord> nodes,
    Set<String> visibleIds,
  ) {
    final children =
        nodes
            .where(
              (item) =>
                  item.parentId == node.id && visibleIds.contains(item.id),
            )
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final showChildren = !_collapsed.contains(node.id) && children.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showChildren)
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final child in children)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _branch(child, nodes, visibleIds),
                ),
            ],
          ),
        if (children.isNotEmpty)
          Container(
            width: 1,
            height: 18,
            color: Theme.of(context).dividerColor,
          ),
        SizedBox(width: 280, child: _nodeCard(node, children.length)),
      ],
    );
  }

  Widget _nodeCard(WorkspaceRecord record, int childCount) {
    final node = RsipNode.fromRecord(record);
    final execution = widget.controller.rsipExecutionForDay(
      record.id,
      widget.controller.currentTime(),
    );
    final group = widget.controller.rsipNodeGroups
        .where((item) => item.record.id == node.groupId)
        .firstOrNull;
    final pendingLinks = widget.controller.pendingRsipTaskActions(record.id);
    return LogSurface(
      accent: _typeColor(context, node.type),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(node.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  record.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: '国策节点操作',
                onSelected: (value) => _nodeMenuAction(value, record),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'collapse',
                    child: Text(
                      _collapsed.contains(record.id) ? '展开分支' : '折叠分支',
                    ),
                  ),
                  const PopupMenuItem(value: 'edit', child: Text('编辑节点')),
                  const PopupMenuItem(value: 'move', child: Text('移动到…')),
                  const PopupMenuItem(value: 'link', child: Text('任务联动…')),
                  if (node.stage == 'E2')
                    const PopupMenuItem(
                      value: 'reinforce',
                      child: Text('增加强化层'),
                    ),
                  if (execution != null)
                    const PopupMenuItem(
                      value: 'correct',
                      child: Text('留痕更正结算…'),
                    ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'archive',
                    child: Text('主动结束并归档…'),
                  ),
                ],
              ),
            ],
          ),
          Text(
            node.rule,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 5,
            children: [
              _tag(node.stage, Icons.layers_outlined),
              _tag(_typeLabel(node.type), _typeIcon(node.type)),
              if (node.passive) _tag('被动', Icons.low_priority_outlined),
              if (group != null)
                _tag(group.record.title, Icons.folder_outlined),
              if (node.reinforcement > 0)
                _tag('强化 +${node.reinforcement}', Icons.shield_outlined),
              if (childCount > 0)
                _tag('$childCount 个直接子节点', Icons.account_tree_outlined),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: execution == null
                    ? Text(
                        '今日待结算 · 连续 ${node.consecutiveExecutions} 天',
                        style: Theme.of(context).textTheme.labelMedium,
                      )
                    : Row(
                        children: [
                          Icon(_executionIcon(execution.status), size: 16),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              '今日${_executionLabel(execution.status)}',
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ),
                        ],
                      ),
              ),
              if (pendingLinks.isNotEmpty)
                IconButton(
                  tooltip: '处理待确认任务联动',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _promptPendingTaskActions(record.id),
                  icon: const Icon(Icons.link_outlined),
                ),
            ],
          ),
          if (execution == null)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: '标记已执行',
                  onPressed: () => _settleExecuted(record),
                  icon: const Icon(Icons.check_circle_outline),
                ),
                IconButton(
                  tooltip: '标记已违反',
                  onPressed: () => _settleViolated(record),
                  icon: const Icon(Icons.gpp_bad_outlined),
                ),
                IconButton(
                  tooltip: '跳过今日',
                  onPressed: () => _settleSkipped(record),
                  icon: const Icon(Icons.skip_next_outlined),
                ),
                if (record.rsipUseTimer)
                  IconButton(
                    tooltip: record.rsipTimerRunning ? '完成计时' : '开始计时',
                    onPressed: () => _toggleTimer(record),
                    icon: Icon(
                      record.rsipTimerRunning
                          ? Icons.timer_off_outlined
                          : Icons.timer_outlined,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _tag(String label, IconData icon) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    ),
  );

  Widget _library() {
    final values = widget.controller.rsipLibraryNodes;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 132),
      children: [
        const SectionHeading(title: '已归档国策'),
        if (values.isEmpty)
          const EmptyState(
            icon: Icons.inventory_2_outlined,
            title: '国策库为空',
            message: '崩塌或主动结束的节点会保留执行历史，并出现在这里。',
          ),
        for (final node in values)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: LogSurface(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                leading: CircleAvatar(child: Text(node.emoji)),
                title: Text(node.record.title),
                subtitle: Text(
                  '累计执行 ${node.cumulativeExecutionDays} 天 · '
                  '最高 ${node.record.data['rsipHighestStage'] ?? node.stage} · '
                  '最高强化 ${node.maxReinforcement} · '
                  '使用 ${(node.record.data['rsipLibraryUses'] as num?)?.toInt() ?? 1} 次\n'
                  '${node.record.data['rsipArchiveReason'] ?? '已归档'}',
                ),
                isThreeLine: true,
                trailing: OutlinedButton.icon(
                  onPressed: () => _restoreNode(node.record),
                  icon: const Icon(Icons.restore_outlined),
                  label: const Text('恢复'),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _history() {
    final runs = widget.controller.rsipRunRecords.toList()
      ..sort((a, b) => b.runNumber.compareTo(a.runNumber));
    final executions = widget.controller.rsipExecutionRecords.toList()
      ..sort((a, b) => b.record.createdAt.compareTo(a.record.createdAt));
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 132),
      children: [
        const SectionHeading(title: '轮次'),
        if (runs.isEmpty)
          const EmptyState(
            icon: Icons.history_outlined,
            title: '还没有轮次记录',
            message: '创建或恢复第一个活动节点后自动开始一轮。',
          ),
        for (final run in runs)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: LogSurface(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ListTile(
                leading: Icon(
                  run.endedAt == null
                      ? Icons.play_circle_outline
                      : Icons.stop_circle_outlined,
                ),
                title: Text(
                  '第 ${run.runNumber} 轮 · ${run.endedAt == null ? '进行中' : '已结束'}',
                ),
                subtitle: Text(
                  '${formatDateTime(run.startedAt)} 开始 · '
                  '峰值 ${run.peakNodeCount} 节点'
                  '${run.endedAt == null ? '' : ' · 持续 ${run.durationDays} 天'}'
                  '${run.collapseReason.isEmpty ? '' : '\n原因：${run.collapseReason}'}',
                ),
                isThreeLine: run.collapseReason.isNotEmpty,
              ),
            ),
          ),
        const SectionHeading(title: '执行与更正'),
        if (executions.isEmpty) const Text('尚无节点结算记录。'),
        for (final execution in executions)
          ListTile(
            leading: Icon(_executionIcon(execution.status)),
            title: Text(execution.record.title),
            subtitle: Text(
              '${execution.logicalDayKey} · ${_executionLabel(execution.status)}'
              '${execution.reason.isEmpty ? '' : ' · ${execution.reason}'}'
              '${execution.corrected ? ' · 已留痕更正' : ''}',
            ),
            trailing: Text(formatDateTime(execution.record.createdAt)),
          ),
      ],
    );
  }

  Widget _analytics() {
    final insights = widget.controller.rsipInsights;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 132),
      children: [
        const SectionHeading(title: '规则启发式'),
        const Text('以下结果只根据本地记录和公开规则计算，不是预测、诊断或科学证明。'),
        const SizedBox(height: 10),
        for (final insight in insights)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: LogSurface(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    insight.message,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '时间窗口：${formatDateTime(insight.windowStart)} 至 ${formatDateTime(insight.windowEnd)}',
                  ),
                  const SizedBox(height: 6),
                  Text('规则依据：${insight.rule}'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in insight.metrics.entries)
                        _tag(
                          '${_metricLabel(entry.key)} ${_metricValue(entry.key, entry.value)}',
                          Icons.data_usage_outlined,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _nodeMenuAction(String value, WorkspaceRecord record) async {
    switch (value) {
      case 'collapse':
        setState(
          () => _collapsed.contains(record.id)
              ? _collapsed.remove(record.id)
              : _collapsed.add(record.id),
        );
        break;
      case 'edit':
        await _showNodeEditor(existing: record);
        break;
      case 'move':
        await _move(record);
        break;
      case 'link':
        await _showTaskLinkDialog(record);
        break;
      case 'reinforce':
        await _run(
          () => widget.controller.reinforceRsipNode(record),
          '已增加一层强化',
        );
        break;
      case 'correct':
        await _correctSettlement(record);
        break;
      case 'archive':
        await _archive(record);
        break;
    }
  }

  Future<void> _showNodeEditor({WorkspaceRecord? existing}) async {
    final current = existing == null ? null : RsipNode.fromRecord(existing);
    final title = TextEditingController(text: existing?.title ?? '');
    final rule = TextEditingController(text: current?.rule ?? '');
    final emoji = TextEditingController(text: current?.emoji ?? '策');
    final timer = TextEditingController(
      text: '${existing?.rsipTimerMinutes ?? 15}',
    );
    var type = current?.type ?? RsipNodeType.policy;
    var parentId = existing?.parentId;
    var groupId = current?.groupId;
    var passive = current?.passive ?? false;
    var useTimer = existing?.rsipUseTimer ?? false;
    String? error;
    final saved = await showWorkbenchDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? '添加国策节点' : '编辑国策节点'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExternalField(
                    label: '标题 *',
                    child: TextField(
                      controller: title,
                      autofocus: true,
                      decoration: const InputDecoration(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ExternalField(
                    label: '精准规则 *',
                    child: TextField(
                      controller: rule,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: '写成可观察、可结算的动作',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ExternalField(
                          label: '节点类型',
                          child: DropdownButtonFormField<RsipNodeType>(
                            initialValue: type,
                            decoration: const InputDecoration(),
                            items: [
                              for (final value in RsipNodeType.values)
                                DropdownMenuItem(
                                  value: value,
                                  child: Text(_typeLabel(value)),
                                ),
                            ],
                            onChanged: (value) => setDialogState(() {
                              type = value ?? type;
                              emoji.text = _typeEmoji(type);
                            }),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 110,
                        child: ExternalField(
                          label: 'Emoji/标记',
                          child: TextField(
                            controller: emoji,
                            decoration: const InputDecoration(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ExternalField(
                    label: '父节点',
                    child: DropdownButtonFormField<String>(
                      initialValue: parentId ?? '',
                      decoration: const InputDecoration(),
                      items: [
                        const DropdownMenuItem(value: '', child: Text('作为根节点')),
                        for (final candidate
                            in widget.controller.activeRsipHabits.where(
                              (candidate) =>
                                  existing == null ||
                                  widget.controller.canUseRsipParent(
                                    recordId: existing.id,
                                    parentId: candidate.id,
                                  ),
                            ))
                          DropdownMenuItem(
                            value: candidate.id,
                            child: Text(candidate.title),
                          ),
                      ],
                      onChanged: (value) => setDialogState(
                        () => parentId = value == null || value.isEmpty
                            ? null
                            : value,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ExternalField(
                    label: '国策组',
                    child: DropdownButtonFormField<String>(
                      initialValue: groupId ?? '',
                      decoration: const InputDecoration(),
                      items: [
                        const DropdownMenuItem(value: '', child: Text('不分组')),
                        for (final group in widget.controller.rsipNodeGroups)
                          DropdownMenuItem(
                            value: group.record.id,
                            child: Text(
                              '${group.emoji} ${group.record.title} · 容错 ${group.remainingTolerance}/${group.initialTolerance}',
                            ),
                          ),
                      ],
                      onChanged: (value) => setDialogState(
                        () => groupId = value == null || value.isEmpty
                            ? null
                            : value,
                      ),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: passive,
                    title: const Text('被动国策'),
                    subtitle: const Text('仍需每日结算，但不计入主动维护成本'),
                    onChanged: (value) => setDialogState(() => passive = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: useTimer,
                    title: const Text('启用节点计时'),
                    onChanged: (value) =>
                        setDialogState(() => useTimer = value),
                  ),
                  if (useTimer)
                    ExternalField(
                      label: '计时分钟（1–180）',
                      child: TextField(
                        controller: timer,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(),
                      ),
                    ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await widget.controller.saveRsipNode(
                    existing: existing,
                    title: title.text,
                    rule: rule.text,
                    type: type,
                    emoji: emoji.text,
                    parentId: parentId,
                    groupId: groupId,
                    passive: passive,
                    useTimer: useTimer,
                    timerMinutes: int.tryParse(timer.text) ?? 0,
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                } on FormatException catch (value) {
                  setDialogState(() => error = value.message);
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    await _disposeAfterDialog([title, rule, emoji, timer]);
    if (saved == true && mounted) setState(() {});
  }

  Future<void> _showGroupEditor({WorkspaceRecord? existing}) async {
    final current = existing == null
        ? null
        : RsipNodeGroup.fromRecord(existing);
    final title = TextEditingController(text: existing?.title ?? '');
    final emoji = TextEditingController(text: current?.emoji ?? '组');
    final tolerance = TextEditingController(
      text: '${current?.initialTolerance ?? 1}',
    );
    String? error;
    final saved = await showWorkbenchDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? '新建国策组' : '编辑国策组'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExternalField(
                  label: '组名称 *',
                  child: TextField(
                    controller: title,
                    autofocus: true,
                    decoration: const InputDecoration(),
                  ),
                ),
                const SizedBox(height: 12),
                ExternalField(
                  label: 'Emoji/标记',
                  child: TextField(
                    controller: emoji,
                    decoration: const InputDecoration(),
                  ),
                ),
                const SizedBox(height: 12),
                ExternalField(
                  label: '每轮初始容错次数',
                  child: TextField(
                    controller: tolerance,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      helperText: '消耗至 0 时，整组活动节点及其子树归档',
                    ),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await widget.controller.saveRsipNodeGroup(
                    existing: existing,
                    title: title.text,
                    emoji: emoji.text,
                    initialTolerance: int.tryParse(tolerance.text) ?? -1,
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                } on FormatException catch (value) {
                  setDialogState(() => error = value.message);
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    await _disposeAfterDialog([title, emoji, tolerance]);
    if (saved == true && mounted) setState(() {});
  }

  Future<void> _showSplitDialog() async {
    final goal = TextEditingController();
    var rows = <_SplitDraft>[_SplitDraft()];
    String? parentId;
    String? groupId;
    String? error;
    final saved = await showWorkbenchDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('拆分目标为国策'),
          content: SizedBox(
            width: 760,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExternalField(
                    label: '目标说明 *',
                    child: TextField(
                      controller: goal,
                      autofocus: true,
                      decoration: const InputDecoration(hintText: '例如：建立稳定作息'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ExternalField(
                          label: '共同父节点',
                          child: DropdownButtonFormField<String>(
                            initialValue: '',
                            decoration: const InputDecoration(),
                            items: [
                              const DropdownMenuItem(
                                value: '',
                                child: Text('作为同级根节点'),
                              ),
                              for (final node
                                  in widget.controller.activeRsipHabits)
                                DropdownMenuItem(
                                  value: node.id,
                                  child: Text(node.title),
                                ),
                            ],
                            onChanged: (value) => parentId =
                                value == null || value.isEmpty ? null : value,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ExternalField(
                          label: '共同国策组',
                          child: DropdownButtonFormField<String>(
                            initialValue: '',
                            decoration: const InputDecoration(),
                            items: [
                              const DropdownMenuItem(
                                value: '',
                                child: Text('不分组'),
                              ),
                              for (final group
                                  in widget.controller.rsipNodeGroups)
                                DropdownMenuItem(
                                  value: group.record.id,
                                  child: Text(
                                    '${group.emoji} ${group.record.title}',
                                  ),
                                ),
                            ],
                            onChanged: (value) => groupId =
                                value == null || value.isEmpty ? null : value,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          final replaced = rows;
                          setDialogState(() => rows = _sleepTemplate());
                          _disposeDraftsAfterFrame(replaced);
                        },
                        child: const Text('作息模板'),
                      ),
                      OutlinedButton(
                        onPressed: () {
                          final replaced = rows;
                          setDialogState(() => rows = _exerciseTemplate());
                          _disposeDraftsAfterFrame(replaced);
                        },
                        child: const Text('运动模板'),
                      ),
                      OutlinedButton(
                        onPressed: () {
                          final replaced = rows;
                          setDialogState(() => rows = _dietTemplate());
                          _disposeDraftsAfterFrame(replaced);
                        },
                        child: const Text('饮食模板'),
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            setDialogState(() => rows.add(_SplitDraft())),
                        icon: const Icon(Icons.add),
                        label: const Text('添加子国策'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (var index = 0; index < rows.length; index++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _splitRow(
                        rows[index],
                        index,
                        () => setDialogState(() {
                          final removed = rows.removeAt(index);
                          _disposeDraftsAfterFrame([removed]);
                        }),
                        setDialogState,
                      ),
                    ),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton.icon(
              onPressed: () async {
                try {
                  await widget.controller.splitRsipGoal(
                    goal: goal.text,
                    parentId: parentId,
                    groupId: groupId,
                    items: [for (final row in rows) row.toData()],
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                } on FormatException catch (value) {
                  setDialogState(() => error = value.message);
                }
              },
              icon: const Icon(Icons.call_split_outlined),
              label: const Text('批量创建'),
            ),
          ],
        ),
      ),
    );
    await _disposeAfterDialog([goal]);
    for (final row in rows) {
      row.dispose();
    }
    if (saved == true && mounted) setState(() {});
  }

  Widget _splitRow(
    _SplitDraft row,
    int index,
    VoidCallback onRemove,
    void Function(VoidCallback) refresh,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ExternalField(
                    label: '子国策 ${index + 1} 标题 *',
                    child: TextField(
                      controller: row.title,
                      decoration: InputDecoration(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<RsipNodeType>(
                  value: row.type,
                  items: [
                    for (final type in RsipNodeType.values)
                      DropdownMenuItem(
                        value: type,
                        child: Text(_typeLabel(type)),
                      ),
                  ],
                  onChanged: (value) =>
                      refresh(() => row.type = value ?? row.type),
                ),
                IconButton(
                  tooltip: '删除此行',
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: ExternalField(
                    label: '精准规则 *',
                    child: TextField(
                      controller: row.rule,
                      decoration: const InputDecoration(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Checkbox(
                  value: row.passive,
                  onChanged: (value) =>
                      refresh(() => row.passive = value ?? false),
                ),
                const Text('被动'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _settleExecuted(WorkspaceRecord record) async {
    await _run(
      () => widget.controller.settleRsipNode(
        record,
        status: RsipExecutionStatus.executed,
      ),
      '已记录执行',
    );
    if (mounted) await _promptPendingTaskActions(record.id);
  }

  Future<void> _settleViolated(WorkspaceRecord record) async {
    RsipViolationPreview preview;
    try {
      preview = widget.controller.previewRsipViolation(record);
    } on FormatException catch (error) {
      _notice(error.message);
      return;
    }
    final reason = TextEditingController();
    final repair = TextEditingController();
    String? error;
    final confirmed = await showWorkbenchDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: const Icon(Icons.warning_amber_outlined),
          title: Text('确认违反「${record.title}」'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_violationSummary(preview)),
                if (preview.archiveNodeIds.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '将归档：${_titlesForIds(preview.archiveNodeIds).join('、')}',
                  ),
                ],
                const SizedBox(height: 14),
                ExternalField(
                  label: '违反原因 *',
                  child: TextField(
                    controller: reason,
                    autofocus: true,
                    maxLines: 2,
                    decoration: const InputDecoration(),
                  ),
                ),
                const SizedBox(height: 10),
                ExternalField(
                  label: '修复建议（可选）',
                  child: TextField(
                    controller: repair,
                    maxLines: 2,
                    decoration: const InputDecoration(),
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await widget.controller.settleRsipNode(
                    record,
                    status: RsipExecutionStatus.violated,
                    reason: reason.text,
                    repairHint: repair.text,
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                } on FormatException catch (value) {
                  setDialogState(() => error = value.message);
                }
              },
              child: const Text('确认违反'),
            ),
          ],
        ),
      ),
    );
    await _disposeAfterDialog([reason, repair]);
    if (confirmed == true && mounted) {
      setState(() {});
      _notice('违反已留痕，崩塌范围已按规则处理');
    }
  }

  Future<void> _settleSkipped(WorkspaceRecord record) async {
    final confirmed = await showWorkbenchDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('跳过今日结算'),
        content: const Text('跳过会打断连续执行天数，但不会触发节点或国策组崩塌。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认跳过'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _run(
        () => widget.controller.settleRsipNode(
          record,
          status: RsipExecutionStatus.skipped,
        ),
        '已跳过今日结算',
      );
    }
  }

  Future<void> _correctSettlement(WorkspaceRecord record) async {
    final current = widget.controller.rsipExecutionForDay(
      record.id,
      widget.controller.currentTime(),
    );
    if (current == null) return;
    var status = current.status;
    final reason = TextEditingController();
    final correction = TextEditingController();
    String? error;
    final saved = await showWorkbenchDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('留痕更正结算'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExternalField(
                  label: '更正为',
                  child: DropdownButtonFormField<RsipExecutionStatus>(
                    initialValue: status,
                    decoration: const InputDecoration(),
                    items: [
                      for (final value in RsipExecutionStatus.values)
                        DropdownMenuItem(
                          value: value,
                          child: Text(_executionLabel(value)),
                        ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => status = value ?? status),
                  ),
                ),
                const SizedBox(height: 12),
                ExternalField(
                  label: '结算说明/违反原因',
                  child: TextField(
                    controller: reason,
                    decoration: const InputDecoration(),
                  ),
                ),
                const SizedBox(height: 12),
                ExternalField(
                  label: '更正原因 *',
                  child: TextField(
                    controller: correction,
                    maxLines: 2,
                    decoration: const InputDecoration(),
                  ),
                ),
                const SizedBox(height: 8),
                const Text('更正会保留原状态和时间。若原结算已导致结构崩塌，系统不会静默恢复节点，请在国策库中明确恢复。'),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await widget.controller.settleRsipNode(
                    record,
                    status: status,
                    reason: reason.text,
                    correctionReason: correction.text,
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                } on FormatException catch (value) {
                  setDialogState(() => error = value.message);
                }
              },
              child: const Text('保存更正'),
            ),
          ],
        ),
      ),
    );
    await _disposeAfterDialog([reason, correction]);
    if (saved == true && mounted) {
      setState(() {});
      _notice('结算更正已留痕');
    }
  }

  Future<void> _toggleTimer(WorkspaceRecord record) async {
    await _run(
      () => record.rsipTimerRunning
          ? widget.controller.completeRsipTimer(record)
          : widget.controller.startRsipTimer(record),
      record.rsipTimerRunning ? '计时已完成并结算' : '国策计时已开始',
    );
  }

  Future<void> _archive(WorkspaceRecord record) async {
    final reason = TextEditingController();
    final subtree = widget.controller
        .rsipSubtree(record)
        .where((node) => node.rsipActive)
        .toList();
    final confirmed = await showWorkbenchDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('主动结束国策'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('将把当前节点及 ${subtree.length - 1} 个活动子节点放入国策库，历史不会删除。'),
              const SizedBox(height: 12),
              ExternalField(
                label: '结束原因 *',
                child: TextField(
                  controller: reason,
                  autofocus: true,
                  decoration: const InputDecoration(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('结束并归档'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _run(
        () => widget.controller.archiveRsipNode(record, reason: reason.text),
        '节点已移入国策库',
      );
    }
    await _disposeAfterDialog([reason]);
  }

  Future<void> _restoreNode(WorkspaceRecord record) async {
    String? parentId;
    final confirmed = await showWorkbenchDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('恢复「${record.title}」'),
          content: SizedBox(
            width: 480,
            child: ExternalField(
              label: '恢复位置',
              child: DropdownButtonFormField<String>(
                initialValue: '',
                decoration: const InputDecoration(),
                items: [
                  const DropdownMenuItem(value: '', child: Text('作为新根节点')),
                  for (final candidate
                      in widget.controller.activeRsipHabits.where(
                        (candidate) => widget.controller.canUseRsipParent(
                          recordId: record.id,
                          parentId: candidate.id,
                        ),
                      ))
                    DropdownMenuItem(
                      value: candidate.id,
                      child: Text(candidate.title),
                    ),
                ],
                onChanged: (value) => setDialogState(
                  () =>
                      parentId = value == null || value.isEmpty ? null : value,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('恢复'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      await _run(
        () => widget.controller.restoreRsipNode(record, parentId: parentId),
        '节点已恢复到活动树',
      );
    }
  }

  Future<void> _move(WorkspaceRecord node) async {
    String? parentId = node.parentId;
    final reason = TextEditingController();
    final subtree = widget.controller.rsipSubtree(node);
    final confirmed = await showWorkbenchDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('移动国策节点'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('此操作将同时移动 ${subtree.length} 个节点。不会改变历史结算。'),
                const SizedBox(height: 12),
                ExternalField(
                  label: '新父节点',
                  child: DropdownButtonFormField<String>(
                    initialValue: parentId ?? '',
                    decoration: const InputDecoration(),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('作为根节点')),
                      for (final candidate
                          in widget.controller.activeRsipHabits.where(
                            (candidate) => widget.controller.canUseRsipParent(
                              recordId: node.id,
                              parentId: candidate.id,
                            ),
                          ))
                        DropdownMenuItem(
                          value: candidate.id,
                          child: Text(candidate.title),
                        ),
                    ],
                    onChanged: (value) => setDialogState(
                      () => parentId = value == null || value.isEmpty
                          ? null
                          : value,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ExternalField(
                  label: '调整原因 *',
                  child: TextField(
                    controller: reason,
                    decoration: const InputDecoration(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('确认移动'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      await _run(
        () => widget.controller.moveRsipNode(
          node,
          parentId: parentId,
          reason: reason.text,
        ),
        '节点结构已更新',
      );
    }
    await _disposeAfterDialog([reason]);
  }

  Future<void> _showTaskLinkDialog(WorkspaceRecord node) async {
    final taskOptions = <WorkspaceRecord>[
      ...widget.controller.taskDefinitions,
      ...widget.controller.tasks.where(
        (task) => task.data['definitionId'] == null,
      ),
    ];
    String? selectedId = taskOptions.firstOrNull?.id;
    var selectedGroup = false;
    var onCompleted = true;
    var onInterrupted = true;
    var reverse = true;
    var reverseEffect = RsipTaskLinkEffect.promptStartChain;
    String? error;
    final saved = await showWorkbenchDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final options = selectedGroup
              ? widget.controller.taskGroups
              : taskOptions;
          if (!options.any((option) => option.id == selectedId)) {
            selectedId = options.firstOrNull?.id;
          }
          return AlertDialog(
            title: Text('任务联动 · ${node.title}'),
            content: SizedBox(
              width: 600,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('任务')),
                        ButtonSegment(value: true, label: Text('任务群')),
                      ],
                      selected: {selectedGroup},
                      onSelectionChanged: (value) => setDialogState(() {
                        selectedGroup = value.first;
                        selectedId = null;
                      }),
                    ),
                    const SizedBox(height: 12),
                    ExternalField(
                      label: '关联对象',
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedId,
                        decoration: const InputDecoration(),
                        items: [
                          for (final option in options)
                            DropdownMenuItem(
                              value: option.id,
                              child: Text(option.title),
                            ),
                        ],
                        onChanged: (value) =>
                            setDialogState(() => selectedId = value),
                      ),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: onCompleted,
                      title: Text(
                        selectedGroup ? '任务群完成一轮 → 自动执行国策' : '任务完成 → 自动执行国策',
                      ),
                      onChanged: (value) =>
                          setDialogState(() => onCompleted = value ?? false),
                    ),
                    if (!selectedGroup)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: onInterrupted,
                        title: const Text('任务失败 → 自动标记国策违反'),
                        onChanged: (value) => setDialogState(
                          () => onInterrupted = value ?? false,
                        ),
                      ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: reverse,
                      title: const Text('国策执行 → 询问是否操作任务'),
                      onChanged: (value) =>
                          setDialogState(() => reverse = value ?? false),
                    ),
                    if (reverse)
                      ExternalField(
                        label: '确认后的任务动作',
                        child: DropdownButtonFormField<RsipTaskLinkEffect>(
                          initialValue: reverseEffect,
                          decoration: const InputDecoration(),
                          items: const [
                            DropdownMenuItem(
                              value: RsipTaskLinkEffect.promptStartChain,
                              child: Text('开始任务/任务群'),
                            ),
                            DropdownMenuItem(
                              value: RsipTaskLinkEffect.promptScheduleChain,
                              child: Text('安排到今天'),
                            ),
                          ],
                          onChanged: (value) => setDialogState(
                            () => reverseEffect = value ?? reverseEffect,
                          ),
                        ),
                      ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    if (widget.controller.rsipTaskLinks.any(
                      (link) => link.nodeId == node.id,
                    )) ...[
                      const Divider(height: 28),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '现有联动',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      for (final link in widget.controller.rsipTaskLinks.where(
                        (link) => link.nodeId == node.id,
                      ))
                        SwitchListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: link.active,
                          title: Text(
                            '${_linkTriggerLabel(link.triggerEvent)} → ${_linkEffectLabel(link.effect)}',
                          ),
                          subtitle: Text(link.chainId),
                          onChanged: (value) async {
                            await widget.controller.saveRsipTaskLink(
                              existing: link.record,
                              nodeId: link.nodeId,
                              chainId: link.chainId,
                              chainKind: link.chainKind,
                              triggerEvent: link.triggerEvent,
                              effect: link.effect,
                              automation: link.automation,
                              active: value,
                            );
                            setDialogState(() {});
                          },
                        ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('关闭'),
              ),
              FilledButton(
                onPressed: options.isEmpty
                    ? null
                    : () async {
                        try {
                          final chainId = selectedId;
                          if (chainId == null) {
                            throw const FormatException('请选择关联对象。');
                          }
                          final kind = selectedGroup
                              ? RsipTaskChainKind.group
                              : RsipTaskChainKind.unit;
                          if (onCompleted) {
                            await widget.controller.saveRsipTaskLink(
                              nodeId: node.id,
                              chainId: chainId,
                              chainKind: kind,
                              triggerEvent: selectedGroup
                                  ? RsipTaskLinkTriggerEvent.groupCycleCompleted
                                  : RsipTaskLinkTriggerEvent.taskCompleted,
                              effect: RsipTaskLinkEffect.markRsipExecuted,
                            );
                          }
                          if (onInterrupted && !selectedGroup) {
                            await widget.controller.saveRsipTaskLink(
                              nodeId: node.id,
                              chainId: chainId,
                              chainKind: kind,
                              triggerEvent:
                                  RsipTaskLinkTriggerEvent.taskInterrupted,
                              effect: RsipTaskLinkEffect.markRsipViolated,
                            );
                          }
                          if (reverse) {
                            await widget.controller.saveRsipTaskLink(
                              nodeId: node.id,
                              chainId: chainId,
                              chainKind: kind,
                              triggerEvent:
                                  RsipTaskLinkTriggerEvent.rsipMarkedExecuted,
                              effect: reverseEffect,
                              automation: RsipTaskLinkAutomation.confirm,
                            );
                          }
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext, true);
                          }
                        } on FormatException catch (value) {
                          setDialogState(() => error = value.message);
                        }
                      },
                child: const Text('保存联动'),
              ),
            ],
          );
        },
      ),
    );
    if (saved == true) _notice('任务联动已保存');
  }

  Future<void> _promptPendingTaskActions(String nodeId) async {
    final links = widget.controller.pendingRsipTaskActions(nodeId);
    for (final link in links.where(
      (value) => value.automation == RsipTaskLinkAutomation.confirm,
    )) {
      if (!mounted) return;
      final title = _linkedTargetTitle(link);
      final confirmed = await showWorkbenchDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('确认任务联动'),
          content: Text('国策已执行。是否${_linkEffectLabel(link.effect)}「$title」？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('暂不处理'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确认执行'),
            ),
          ],
        ),
      );
      if (confirmed == true) await widget.controller.applyRsipTaskAction(link);
    }
    if (mounted) setState(() {});
  }

  Future<void> _setMode(bool value) async {
    await _run(
      () => widget.controller.setRsipStrictMode(value),
      value ? '已切换严格模式' : '已切换自由模式',
    );
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    try {
      await action();
      if (!mounted) return;
      setState(() {});
      _notice(success);
    } on FormatException catch (error) {
      if (mounted) _notice(error.message);
    }
  }

  void _notice(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _disposeAfterDialog(
    Iterable<TextEditingController> controllers,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    for (final controller in controllers) {
      controller.dispose();
    }
  }

  void _disposeDraftsAfterFrame(Iterable<_SplitDraft> drafts) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final draft in drafts) {
        draft.dispose();
      }
    });
  }

  String _violationSummary(RsipViolationPreview preview) {
    if (preview.onlyConsumesReinforcement) {
      return '本次先扣除 1 层强化：+${preview.reinforcementBefore} → +${preview.reinforcementAfter}。节点保持活动。';
    }
    if (preview.collapsesWholeGroup) {
      return '本轮组容错 ${preview.remainingToleranceBefore} → ${preview.remainingToleranceAfter}，容错耗尽，将归档整组活动节点及其子树。';
    }
    if (preview.remainingToleranceBefore != null) {
      return '本轮组容错 ${preview.remainingToleranceBefore} → ${preview.remainingToleranceAfter}，本次只归档当前节点及其子树。';
    }
    return '该节点不属于国策组，将归档当前节点及其子树。';
  }

  List<String> _titlesForIds(Iterable<String> ids) {
    final byId = {
      for (final node in widget.controller.rsipNodes)
        node.record.id: node.record.title,
    };
    return ids.map((id) => byId[id] ?? id).toList(growable: false);
  }

  String _linkedTargetTitle(RsipTaskLink link) {
    final values = link.chainKind == RsipTaskChainKind.group
        ? widget.controller.taskGroups
        : [...widget.controller.taskDefinitions, ...widget.controller.tasks];
    return values
            .where((value) => value.id == link.chainId)
            .firstOrNull
            ?.title ??
        link.chainId;
  }
}

class _SplitDraft {
  _SplitDraft({
    String title = '',
    String rule = '',
    this.passive = false,
    this.type = RsipNodeType.policy,
  }) : title = TextEditingController(text: title),
       rule = TextEditingController(text: rule);

  final TextEditingController title;
  final TextEditingController rule;
  bool passive;
  RsipNodeType type;

  Map<String, dynamic> toData() => {
    'title': title.text,
    'rule': rule.text,
    'passive': passive,
    'type': type.name,
    'emoji': _typeEmoji(type),
  };

  void dispose() {
    title.dispose();
    rule.dispose();
  }
}

List<_SplitDraft> _sleepTemplate() => [
  _SplitDraft(title: '固定关灯', rule: '在设定就寝时间前关闭主要照明', type: RsipNodeType.ritual),
  _SplitDraft(
    title: '离床后见光',
    rule: '起床后 15 分钟内拉开窗帘或到室外',
    type: RsipNodeType.trigger,
  ),
  _SplitDraft(
    title: '午后停止咖啡因',
    rule: '14:00 后不摄入含咖啡因饮品',
    passive: true,
    type: RsipNodeType.reminder,
  ),
];

List<_SplitDraft> _exerciseTemplate() => [
  _SplitDraft(
    title: '开始最小运动',
    rule: '计划时段开始后先完成 5 分钟热身',
    type: RsipNodeType.habit,
  ),
  _SplitDraft(title: '记录运动结果', rule: '结束后记录时长和主观强度', type: RsipNodeType.ritual),
];

List<_SplitDraft> _dietTemplate() => [
  _SplitDraft(
    title: '餐前确定份量',
    rule: '进餐前先确定本餐主食和蛋白质份量',
    type: RsipNodeType.ritual,
  ),
  _SplitDraft(
    title: '饮料默认无糖',
    rule: '未提前决定时只选择水或无糖饮料',
    passive: true,
    type: RsipNodeType.policy,
  ),
];

String _typeLabel(RsipNodeType type) => switch (type) {
  RsipNodeType.policy => '国策',
  RsipNodeType.habit => '习惯',
  RsipNodeType.reward => '奖励',
  RsipNodeType.penalty => '惩罚',
  RsipNodeType.ritual => '仪式',
  RsipNodeType.goal => '目标',
  RsipNodeType.trigger => '触发器',
  RsipNodeType.reminder => '提醒',
};

String _typeEmoji(RsipNodeType type) => switch (type) {
  RsipNodeType.policy => '策',
  RsipNodeType.habit => '习',
  RsipNodeType.reward => '赏',
  RsipNodeType.penalty => '罚',
  RsipNodeType.ritual => '仪',
  RsipNodeType.goal => '标',
  RsipNodeType.trigger => '触',
  RsipNodeType.reminder => '醒',
};

IconData _typeIcon(RsipNodeType type) => switch (type) {
  RsipNodeType.policy => Icons.policy_outlined,
  RsipNodeType.habit => Icons.repeat_outlined,
  RsipNodeType.reward => Icons.redeem_outlined,
  RsipNodeType.penalty => Icons.gavel_outlined,
  RsipNodeType.ritual => Icons.auto_awesome_outlined,
  RsipNodeType.goal => Icons.flag_outlined,
  RsipNodeType.trigger => Icons.bolt_outlined,
  RsipNodeType.reminder => Icons.notifications_outlined,
};

Color _typeColor(BuildContext context, RsipNodeType type) {
  final scheme = Theme.of(context).colorScheme;
  return switch (type) {
    RsipNodeType.policy => scheme.primary,
    RsipNodeType.habit => scheme.tertiary,
    RsipNodeType.reward => context.tokens.marker,
    RsipNodeType.penalty => scheme.error,
    RsipNodeType.ritual => context.tokens.marker,
    RsipNodeType.goal => context.tokens.info,
    RsipNodeType.trigger => scheme.error,
    RsipNodeType.reminder => scheme.secondary,
  };
}

String _executionLabel(RsipExecutionStatus status) => switch (status) {
  RsipExecutionStatus.executed => '已执行',
  RsipExecutionStatus.violated => '已违反',
  RsipExecutionStatus.skipped => '已跳过',
};

IconData _executionIcon(RsipExecutionStatus status) => switch (status) {
  RsipExecutionStatus.executed => Icons.check_circle_outline,
  RsipExecutionStatus.violated => Icons.gpp_bad_outlined,
  RsipExecutionStatus.skipped => Icons.skip_next_outlined,
};

String _metricLabel(String value) => switch (value) {
  'activeNodes' => '活动节点',
  'passiveNodes' => '被动节点',
  'reinforcedNodes' => '有强化节点',
  'executed14d' => '14 日执行',
  'violated14d' => '14 日违反',
  'successRate14d' => '14 日执行率',
  'runs' => '轮次数',
  'descendants' => '子孙节点',
  'failureCost' => '失败成本',
  _ => value,
};

String _metricValue(String key, num value) => key.contains('Rate')
    ? '${(value * 100).toStringAsFixed(0)}%'
    : value is int || value == value.roundToDouble()
    ? '${value.toInt()}'
    : value.toStringAsFixed(2);

String _linkTriggerLabel(RsipTaskLinkTriggerEvent value) => switch (value) {
  RsipTaskLinkTriggerEvent.taskCompleted => '任务完成',
  RsipTaskLinkTriggerEvent.taskInterrupted => '任务中断',
  RsipTaskLinkTriggerEvent.groupCycleCompleted => '任务群一轮完成',
  RsipTaskLinkTriggerEvent.rsipMarkedExecuted => '国策执行',
};

String _linkEffectLabel(RsipTaskLinkEffect value) => switch (value) {
  RsipTaskLinkEffect.markRsipExecuted => '标记国策执行',
  RsipTaskLinkEffect.markRsipViolated => '标记国策违反',
  RsipTaskLinkEffect.promptStartChain => '开始',
  RsipTaskLinkEffect.promptScheduleChain => '安排到今天',
};
