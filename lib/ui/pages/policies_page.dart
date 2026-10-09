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
  final TextEditingController _librarySearchController =
      TextEditingController();
  String _libraryQuery = '';
  String _libraryScope = 'all';

  @override
  void dispose() {
    _librarySearchController.dispose();
    super.dispose();
  }

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
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final compact =
        WorkbenchViewport.sizeOf(context).width <
        AppLayout.masterDetailMin * textScale.clamp(1, 1.5);
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
    final canvasHeight = math.max(560.0, (maxDepth + 1) * 240.0 * textScale);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        20,
        6,
        20,
        AppSpacing.bottomNavClearance,
      ),
      children: [
        if (nodes.isNotEmpty) ...[
          LogSurface(
            accent: Theme.of(context).colorScheme.primary,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.account_tree_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '当前在用 · ${nodes.length} 个节点',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      Text(
                        nodes.first.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
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
        else if (compact) ...[
          for (final root in roots)
            if (visibleIds.contains(root.id))
              _mobileBranch(root, nodes, visibleIds, 0),
        ] else
          LayoutBuilder(
            builder: (context, constraints) => SizedBox(
              height: (WorkbenchViewport.sizeOf(context).height * 0.65).clamp(
                280.0,
                640.0,
              ),
              child: WorkbenchDiagramViewport(
                canvasSize: Size(canvasWidth, canvasHeight),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final root in roots)
                        if (visibleIds.contains(root.id))
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: _branch(root, nodes, visibleIds),
                          ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _mobileBranch(
    WorkspaceRecord record,
    List<WorkspaceRecord> nodes,
    Set<String> visibleIds,
    int depth,
  ) {
    final children =
        nodes
            .where(
              (node) =>
                  node.parentId == record.id && visibleIds.contains(node.id),
            )
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final expanded = !_collapsed.contains(record.id);
    final indent = (depth * 12.0).clamp(0.0, 24.0);
    return Padding(
      padding: EdgeInsets.only(left: indent, bottom: AppSpacing.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: depth == 0
              ? null
              : Border(
                  left: BorderSide(color: context.tokens.orbitTrack, width: 2),
                ),
        ),
        child: Padding(
          padding: EdgeInsets.only(left: depth == 0 ? 0 : AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _nodeCard(record, children.length),
              if (children.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() {
                      if (expanded) {
                        _collapsed.add(record.id);
                      } else {
                        _collapsed.remove(record.id);
                      }
                    }),
                    icon: Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                    ),
                    label: Text(
                      expanded
                          ? '收起 ${children.length} 个子节点'
                          : '展开 ${children.length} 个子节点',
                    ),
                  ),
                ),
              if (expanded)
                for (final child in children)
                  _mobileBranch(child, nodes, visibleIds, depth + 1),
            ],
          ),
        ),
      ),
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
          Flexible(
            child: Text(
              label,
              softWrap: true,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _library() {
    final nodes = widget.controller.rsipNodes;
    final active = nodes.where((node) => node.record.rsipActive).toList();
    final archived = nodes.where((node) => !node.record.rsipActive).toList();
    final query = _libraryQuery.trim().toLowerCase();
    bool matches(RsipNode node) =>
        query.isEmpty ||
        node.record.title.toLowerCase().contains(query) ||
        node.rule.toLowerCase().contains(query) ||
        _typeLabel(node.type).contains(query) ||
        (node.record.data['rsipArchiveReason']?.toString() ?? '')
            .toLowerCase()
            .contains(query);
    final visibleActive = active.where(matches).toList();
    final visibleArchived = archived.where(matches).toList();
    final showActive = _libraryScope != 'archived';
    final showArchived = _libraryScope != 'active';
    final narrow = WorkbenchViewport.sizeOf(context).width < 390;

    Widget nodeRow(RsipNode node, {required bool isArchived}) {
      final group = widget.controller.rsipNodeGroups
          .where((value) => value.record.id == node.groupId)
          .firstOrNull;
      final linkCount = widget.controller.rsipTaskLinks
          .where((link) => link.nodeId == node.record.id && link.active)
          .length;
      final archiveReason = node.record.data['rsipArchiveReason']?.toString();
      final date = DateTime.tryParse(
        node.record.data[isArchived ? 'rsipArchivedAt' : 'rsipAddedAt']
                ?.toString() ??
            '',
      )?.toLocal();
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: LogSurface(
          accent: _typeColor(context, node.type),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            leading: SurfaceIcon(_typeIcon(node.type)),
            title: Text(node.record.title),
            subtitle: Text(
              '${_typeLabel(node.type)} · ${node.stage} · '
              '${node.passive ? '被动' : '每日维护'}'
              '${group == null ? '' : ' · ${group.record.title}'}\n'
              '${node.rule}'
              '${linkCount == 0 ? '' : '\n关联任务 $linkCount 项'}'
              '${date == null ? '' : '\n${isArchived ? '归档' : '创建'}于 ${formatShortDate(date)}'}'
              '${!isArchived || archiveReason == null || archiveReason.isEmpty ? '' : ' · $archiveReason'}',
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            isThreeLine: true,
            trailing: isArchived
                ? narrow
                      ? IconButton(
                          tooltip: '恢复 ${node.record.title}',
                          onPressed: () => _restoreNode(node.record),
                          icon: const Icon(Icons.restore_outlined),
                        )
                      : OutlinedButton.icon(
                          onPressed: () => _restoreNode(node.record),
                          icon: const Icon(Icons.restore_outlined),
                          label: const Text('恢复'),
                        )
                : Builder(
                    builder: (tabContext) => narrow
                        ? IconButton(
                            tooltip: '在树中查看 ${node.record.title}',
                            onPressed: () => DefaultTabController.of(
                              tabContext,
                            ).animateTo(0),
                            icon: const Icon(Icons.account_tree_outlined),
                          )
                        : TextButton(
                            onPressed: () => DefaultTabController.of(
                              tabContext,
                            ).animateTo(0),
                            child: const Text('查看树'),
                          ),
                  ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        20,
        6,
        20,
        AppSpacing.bottomNavClearance,
      ),
      children: [
        const SectionHeading(title: '国策文库', scale: '索引'),
        Text(
          '在用 ${active.length} · 已归档 ${archived.length}',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.tokens.mutedText),
        ),
        const SizedBox(height: AppSpacing.md),
        ExternalField(
          label: '搜索标题、规则或归档原因',
          child: TextField(
            key: const ValueKey('policy-library-search'),
            controller: _librarySearchController,
            onChanged: (value) => setState(() => _libraryQuery = value),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search)),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            for (final (scope, label, count) in [
              ('all', '全部', nodes.length),
              ('active', '在用', active.length),
              ('archived', '归档', archived.length),
            ])
              FilterChip(
                label: Text('$label $count'),
                selected: _libraryScope == scope,
                onSelected: (_) => setState(() => _libraryScope = scope),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (nodes.isEmpty)
          EmptyState(
            icon: Icons.inventory_2_outlined,
            title: '国策库为空',
            message: '创建国策后，在用与归档的规则会集中出现在这里。',
            action: FilledButton.icon(
              onPressed: () => _showNodeEditor(),
              icon: const Icon(Icons.add),
              label: const Text('添加国策'),
            ),
          ),
        if (nodes.isNotEmpty &&
            (!showActive || visibleActive.isEmpty) &&
            (!showArchived || visibleArchived.isEmpty))
          EmptyState(
            icon: Icons.manage_search_outlined,
            title: '没有匹配的国策',
            message: '试试其他关键词，或切换“全部”查看完整文库。',
            action: TextButton(
              onPressed: () => setState(() {
                _librarySearchController.clear();
                _libraryQuery = '';
                _libraryScope = 'all';
              }),
              child: const Text('查看全部'),
            ),
          ),
        if (showActive && visibleActive.isNotEmpty) ...[
          SectionHeading(title: '在用国策', scale: '${visibleActive.length} 条'),
          for (final node in visibleActive) nodeRow(node, isArchived: false),
        ],
        if (showArchived && visibleArchived.isNotEmpty) ...[
          SectionHeading(title: '已归档国策', scale: '${visibleArchived.length} 条'),
          for (final node in visibleArchived) nodeRow(node, isArchived: true),
        ],
      ],
    );
  }

  Widget _history() {
    final runs = widget.controller.rsipRunRecords.toList()
      ..sort((a, b) => b.runNumber.compareTo(a.runNumber));
    final executions = widget.controller.rsipExecutionRecords.toList()
      ..sort((a, b) => b.record.createdAt.compareTo(a.record.createdAt));
    final grouped = {
      for (final run in runs) run.record.id: <RsipExecutionRecord>[],
    };
    final unassigned = <RsipExecutionRecord>[];
    for (final execution in executions) {
      final at = execution.record.createdAt.toLocal();
      final day =
          DateTime.tryParse(execution.logicalDayKey)?.toLocal() ??
          execution.record.scheduledFor?.toLocal();
      RsipRunRecord? owner;
      for (final run in runs) {
        if (!at.isBefore(run.startedAt) &&
            (run.endedAt == null || !at.isAfter(run.endedAt!))) {
          owner = run;
          break;
        }
      }
      if (owner == null && day != null) {
        final logicalDay = DateTime(day.year, day.month, day.day);
        for (final run in runs) {
          final start = DateTime(
            run.startedAt.year,
            run.startedAt.month,
            run.startedAt.day,
          );
          final end = run.endedAt == null
              ? null
              : DateTime(
                  run.endedAt!.year,
                  run.endedAt!.month,
                  run.endedAt!.day,
                );
          if (!logicalDay.isBefore(start) &&
              (end == null || !logicalDay.isAfter(end))) {
            owner = run;
            break;
          }
        }
      }
      if (owner == null) {
        unassigned.add(execution);
      } else {
        grouped[owner.record.id]!.add(execution);
      }
    }

    Widget executionTile(RsipExecutionRecord execution) {
      final data = execution.record.data;
      final repair = data['repairHint']?.toString() ?? '';
      final correction = data['correctionReason']?.toString() ?? '';
      final source = execution.sourceEvent;
      final sourceRecord = [
        ...widget.controller.tasks,
        ...widget.controller.taskGroups,
      ].where((record) => record.id == execution.sourceId).firstOrNull;
      return DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: context.tokens.orbitTrack, width: 2),
          ),
        ),
        child: ExpansionTile(
          key: PageStorageKey('policy-execution-${execution.record.id}'),
          leading: Icon(
            _executionIcon(execution.status),
            color: execution.status == RsipExecutionStatus.violated
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.primary,
          ),
          title: Text(execution.record.title),
          subtitle: Text(
            '${execution.logicalDayKey} · ${_executionLabel(execution.status)}'
            '${execution.corrected ? ' · 已留痕更正' : ''}',
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('记录时间：${formatDateTime(execution.record.createdAt)}'),
                  Text(
                    '来源：${source.isEmpty ? '手动结算' : _sourceEventLabel(source)}'
                    '${sourceRecord == null ? '' : ' · ${sourceRecord.title}'}',
                  ),
                  if (execution.reason.isNotEmpty)
                    Text('结算原因：${execution.reason}'),
                  if (repair.isNotEmpty) Text('修复提示：$repair'),
                  if (correction.isNotEmpty) Text('更正原因：$correction'),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        20,
        6,
        20,
        AppSpacing.bottomNavClearance,
      ),
      children: [
        const SectionHeading(title: '轮次时间线', scale: '审计'),
        Text(
          '展开轮次查看结算，再展开条目核对原因与来源。',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.tokens.mutedText),
        ),
        const SizedBox(height: AppSpacing.md),
        if (runs.isEmpty)
          const EmptyState(
            icon: Icons.history_outlined,
            title: '还没有轮次记录',
            message: '创建或恢复第一个活动节点后自动开始一轮。',
          ),
        for (final run in runs)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: LogSurface(
              child: ExpansionTile(
                key: PageStorageKey('policy-run-${run.record.id}'),
                initiallyExpanded: run.endedAt == null,
                leading: Icon(
                  run.endedAt == null
                      ? Icons.play_circle_outline
                      : Icons.stop_circle_outlined,
                ),
                title: Text(
                  '第 ${run.runNumber} 轮 · ${run.endedAt == null ? '进行中' : '已结束'}',
                ),
                subtitle: Text(
                  '${formatDateTime(run.startedAt)} 开始 · 峰值 ${run.peakNodeCount} 节点'
                  '${run.endedAt == null ? '' : ' · 持续 ${run.durationDays} 天'}',
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          _tag(
                            '已执行 ${grouped[run.record.id]!.where((value) => value.status == RsipExecutionStatus.executed).length}',
                            Icons.check_circle_outline,
                          ),
                          _tag(
                            '已违反 ${grouped[run.record.id]!.where((value) => value.status == RsipExecutionStatus.violated).length}',
                            Icons.gpp_bad_outlined,
                          ),
                          if (run.collapseReason.isNotEmpty)
                            _tag(
                              '结束原因：${run.collapseReason}',
                              Icons.info_outline,
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (grouped[run.record.id]!.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('本轮暂无节点结算记录。'),
                      ),
                    ),
                  for (final execution in grouped[run.record.id]!)
                    executionTile(execution),
                ],
              ),
            ),
          ),
        if (unassigned.isNotEmpty) ...[
          const SectionHeading(title: '未归属轮次的记录'),
          for (final execution in unassigned) executionTile(execution),
        ],
      ],
    );
  }

  Widget _analytics() {
    final insights = widget.controller.rsipInsights;
    final today = widget.controller.currentTime().toLocal();
    final firstDay = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(const Duration(days: 13));
    final days = [
      for (var index = 0; index < 14; index++)
        firstDay.add(Duration(days: index)),
    ];
    String dayKey(DateTime value) =>
        '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    final records = widget.controller.rsipExecutionRecords;
    final executedByDay = <String, int>{};
    final violatedByDay = <String, int>{};
    for (final record in records) {
      final key = record.logicalDayKey.isNotEmpty
          ? record.logicalDayKey
          : dayKey(record.record.createdAt.toLocal());
      if (record.status == RsipExecutionStatus.executed) {
        executedByDay[key] = (executedByDay[key] ?? 0) + 1;
      } else if (record.status == RsipExecutionStatus.violated) {
        violatedByDay[key] = (violatedByDay[key] ?? 0) + 1;
      }
    }
    final executed = days.fold<int>(
      0,
      (total, day) => total + (executedByDay[dayKey(day)] ?? 0),
    );
    final violated = days.fold<int>(
      0,
      (total, day) => total + (violatedByDay[dayKey(day)] ?? 0),
    );
    final tracked = executed + violated;
    final maxCount = math.max(
      1,
      days.fold<int>(
        0,
        (value, day) => math.max(
          value,
          math.max(
            executedByDay[dayKey(day)] ?? 0,
            violatedByDay[dayKey(day)] ?? 0,
          ),
        ),
      ),
    );
    final scheme = Theme.of(context).colorScheme;
    final barWidth = MediaQuery.textScalerOf(
      context,
    ).scale(48).clamp(68.0, 112.0).toDouble();

    Widget dayBar(DateTime day) {
      final key = dayKey(day);
      final done = executedByDay[key] ?? 0;
      final missed = violatedByDay[key] ?? 0;
      Widget bar(int count, Color color) => Container(
        width: 16,
        height: count == 0 ? 2 : math.max(8, count / maxCount * 76),
        decoration: BoxDecoration(
          color: count == 0 ? context.tokens.orbitTrack : color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        ),
      );
      return Semantics(
        label: '${day.month}月${day.day}日，已执行 $done，已违反 $missed',
        child: SizedBox(
          key: ValueKey('policy-day-bar-$key'),
          width: barWidth,
          child: Column(
            children: [
              SizedBox(
                height: 82,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    bar(done, scheme.primary),
                    const SizedBox(width: 4),
                    bar(missed, scheme.error),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${day.month}/${day.day}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              Text(
                '$done / $missed',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.tokens.mutedText,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        20,
        6,
        20,
        AppSpacing.bottomNavClearance,
      ),
      children: [
        const SectionHeading(title: '规则启发式'),
        const Text('以下结果只根据本地记录和公开规则计算，不是预测、诊断或科学证明。'),
        const SizedBox(height: 10),
        if (tracked == 0)
          EmptyState(
            icon: Icons.insights_outlined,
            title: '暂无可分析的协议记录',
            message: '近 14 日没有执行或违反结算。完成一次国策结算后会显示每日分布。',
            action: Builder(
              builder: (tabContext) => OutlinedButton.icon(
                onPressed: () =>
                    DefaultTabController.of(tabContext).animateTo(0),
                icon: const Icon(Icons.account_tree_outlined),
                label: const Text('查看国策树'),
              ),
            ),
          )
        else
          LogSurface(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '14 日结算分布',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _tag('已执行 $executed', Icons.check_circle_outline),
                    _tag('已违反 $violated', Icons.gpp_bad_outlined),
                    _tag(
                      '执行率 ${(executed / tracked * 100).toStringAsFixed(0)}%',
                      Icons.percent_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [for (final day in days) dayBar(day)]),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '每日数值依次为执行 / 违反；左右滑动查看完整 14 天。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.tokens.mutedText,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        for (final insight in tracked == 0 ? insights.skip(1) : insights)
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

/// 节点类型强调色。
///
/// **8 种类型各自独立一色**，不再有共享色。原「同色必须同语义」的分组约束
/// 已解除，改为**邻近色同语义**——同一语义组的类别在色相环上相邻，既保留
/// 关系暗示，又能逐类单独指认：
///   规则：policy 绿 · habit 青碧（相邻）
///   流程：ritual 蓝
///   成果：goal 橄榄 · reward 黄铜（相邻）
///   后果：penalty 红
///   触发：trigger 紫 · reminder 中性（色相两端）
///
/// 色值经实测（accent 渲染为面板左缘 3px 竖条，属非文字图形元素）：
///   两两 CIEDE2000 ΔE 最小 14.7（浅）/ 16.4（深）
///   面板底色上对比度最低 3.25:1（浅）/ 5.04:1（深）——满足 WCAG 1.4.11 的 3:1
///   （在 subtle 上更低：2.76 / 4.29。但 accent 条只贴在面板上，以面板为准。）
///
/// **「柔壤」换色带来的回退，以及为什么只调两个色相。** 旧配色下 8 色的最小
/// ΔE00 是 17.0 / 15.6；新配色刻意**降饱和**（这是「温柔有机」的核心手法），
/// 而分类可辨性需要**彩度差**，两者在暖色区直接冲突，最小 ΔE00 一度塌到
/// 12.4 / 11.7。最弱两对是「陶土成果 ↔ 砖红惩罚」与「苔绿国策 ↔ 橄榄目标」。
///
/// 处置：语义色板（苔绿/陶土/砖红/靛蓝）严格照规范不动；只把处于瓶颈的
/// `goal` 调向黄绿、并为「奖励」节点改用分类色层的 `amber`（不复用语义
/// `reward`）。其余 6 类继续锚定语义令牌——分类色与语义色分家会让系统更难
/// 解释，实测再放开 `ritual` 也只能换来 16.4 / 17.8，不值这一处解耦。
///
/// 最终最弱一对是「习惯青碧 ↔ 仪式蓝」14.7 / 16.4：青碧夹在绿与蓝之间，
/// 已是最优，无法再拉开。颜色始终只作辅助线索：每类另有独立图标与简称，
/// 形状冗余，不依赖颜色单独成立。
///
/// 历史：原实现把 reward 与 ritual 同置黄铜、habit/penalty/trigger 三置红色，
/// 后者还把「习惯」标成了危险色；中间态曾收敛为「五组共享色」。
/// 上表的实现见下方 `rsipNodeTypeColor`——刻意抽成不依赖 `BuildContext` 的
/// 纯函数，好让回归测试**直接断言色板**，而不必经过界面渲染：节点色只体现在
/// 3px 的 accent 条上，一旦落在视口外，截图里就是 0 像素，靠 golden 守不住
/// （实测 reward / penalty / trigger 三色在 1440×900 树视图下命中 0 像素）。
Color _typeColor(BuildContext context, RsipNodeType type) =>
    rsipNodeTypeColor(context.tokens, Theme.of(context).colorScheme, type);

/// 节点类型 → 强调色的纯映射。设计说明与实测数据见上方 `_typeColor` 注释。
@visibleForTesting
Color rsipNodeTypeColor(
  WorkbenchTokens tokens,
  ColorScheme scheme,
  RsipNodeType type,
) => switch (type) {
  RsipNodeType.policy => scheme.primary,
  RsipNodeType.habit => tokens.teal,
  RsipNodeType.ritual => tokens.info,
  RsipNodeType.goal => tokens.olive,
  // 奖励节点用分类色层的琥珀，而非语义成果色（陶土）。理由见上方注释：
  // 二者在新暖色基座上互相挤到 ΔE00 12.4，低于分类色可用区间上沿。
  RsipNodeType.reward => tokens.amber,
  RsipNodeType.penalty => tokens.signal,
  RsipNodeType.trigger => tokens.violet,
  RsipNodeType.reminder => scheme.outline,
};

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

String _sourceEventLabel(String value) => switch (value) {
  'taskCompleted' => '关联任务完成',
  'taskInterrupted' => '关联任务中断',
  'groupCycleCompleted' => '任务群一轮完成',
  'rsipMarkedExecuted' => '国策结算',
  _ => value,
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
