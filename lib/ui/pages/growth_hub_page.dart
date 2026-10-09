import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../core/theme/app_theme.dart';
import '../../state/workbench_controller.dart';
import '../widgets/common.dart';
import 'behavior_page.dart';
import 'goals_page.dart';
import 'growth_page.dart';
import 'habits_page.dart';
import 'policies_page.dart';

enum GrowthTab { goals, habits, behavior, growth }

class GrowthHubPage extends StatefulWidget {
  const GrowthHubPage({
    super.key,
    required this.controller,
    this.initialTab = GrowthTab.growth,
    this.showHeader = true,
    this.showTabs = true,
    this.initialBehaviorMode,
    this.initialPolicyTab = PolicyTab.tree,
    this.onBehaviorModeChanged,
  });

  final WorkbenchController controller;
  final GrowthTab initialTab;
  final bool showHeader;
  final bool showTabs;
  final BehaviorMode? initialBehaviorMode;
  final PolicyTab initialPolicyTab;
  final ValueChanged<BehaviorMode>? onBehaviorModeChanged;

  @override
  State<GrowthHubPage> createState() => _GrowthHubPageState();
}

class _GrowthHubPageState extends State<GrowthHubPage>
    with SingleTickerProviderStateMixin {
  late final TabController tabController = TabController(
    length: GrowthTab.values.length,
    initialIndex: widget.initialTab.index,
    vsync: this,
  );

  @override
  void didUpdateWidget(covariant GrowthHubPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab &&
        !tabController.indexIsChanging) {
      tabController.index = widget.initialTab.index;
    }
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact =
        WorkbenchViewport.sizeOf(context).width < AppBreakpoints.compact;
    final android = defaultTargetPlatform == TargetPlatform.android;
    final androidCompact = android && compact;
    final tabsVisible =
        widget.showTabs && defaultTargetPlatform != TargetPlatform.windows;
    return Column(
      children: [
        if (widget.showHeader)
          const PageHeader(title: '成长', subtitle: '目标、习惯、行为与成长账本'),
        if (tabsVisible)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 20),
            child: WorkbenchTabBar(
              controller: tabController,
              isScrollable: android ? false : compact,
              tabAlignment: android ? TabAlignment.fill : null,
              labelPadding: androidCompact
                  ? EdgeInsets.zero
                  : EdgeInsets.symmetric(horizontal: compact ? 14 : 20),
              tabs: [
                Tab(
                  icon: androidCompact ? null : const Icon(Icons.flag_outlined),
                  text: '目标',
                ),
                Tab(
                  icon: androidCompact
                      ? null
                      : const Icon(Icons.repeat_outlined),
                  text: '习惯',
                ),
                Tab(
                  icon: androidCompact
                      ? null
                      : const Icon(Icons.psychology_outlined),
                  text: '行为',
                ),
                Tab(
                  icon: androidCompact
                      ? null
                      : const Icon(Icons.stacked_line_chart_outlined),
                  text: '成长',
                ),
              ],
            ),
          ),
        Expanded(
          child: TabBarView(
            controller: tabController,
            children: [
              GoalsPage(controller: widget.controller, showHeader: false),
              HabitsPage(controller: widget.controller, showHeader: false),
              BehaviorPage(
                controller: widget.controller,
                showHeader: false,
                initialMode: widget.initialBehaviorMode,
                initialPolicyTab: widget.initialPolicyTab,
                onModeChanged: widget.onBehaviorModeChanged,
              ),
              GrowthPage(controller: widget.controller, showHeader: false),
            ],
          ),
        ),
      ],
    );
  }
}
