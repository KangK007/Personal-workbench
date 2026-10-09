import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../core/theme/app_theme.dart';
import '../../state/workbench_controller.dart';
import '../widgets/common.dart';
import 'focus_page.dart';
import 'protocols_page.dart';

enum ExecutionTab { focus, protocols }

class ExecutionPage extends StatefulWidget {
  const ExecutionPage({
    super.key,
    required this.controller,
    this.initialTab = ExecutionTab.focus,
    this.showHeader = true,
    this.showTabs = true,
  });

  final WorkbenchController controller;
  final ExecutionTab initialTab;
  final bool showHeader;
  final bool showTabs;

  @override
  State<ExecutionPage> createState() => _ExecutionPageState();
}

class _ExecutionPageState extends State<ExecutionPage>
    with SingleTickerProviderStateMixin {
  late final TabController tabController = TabController(
    length: ExecutionTab.values.length,
    initialIndex: widget.initialTab.index,
    vsync: this,
  );

  @override
  void didUpdateWidget(covariant ExecutionPage oldWidget) {
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
          const PageHeader(title: '执行', subtitle: '专注计时与执行协议'),
        if (tabsVisible)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 20),
            child: WorkbenchTabBar(
              controller: tabController,
              isScrollable: android ? false : compact,
              tabAlignment: android ? TabAlignment.fill : null,
              labelPadding: androidCompact
                  ? EdgeInsets.zero
                  : EdgeInsets.symmetric(horizontal: compact ? 16 : 24),
              tabs: [
                Tab(
                  icon: androidCompact
                      ? null
                      : const Icon(Icons.timer_outlined),
                  text: '专注',
                ),
                Tab(
                  icon: androidCompact
                      ? null
                      : const Icon(Icons.timeline_outlined),
                  text: '协议',
                ),
              ],
            ),
          ),
        Expanded(
          child: TabBarView(
            controller: tabController,
            children: [
              FocusHubPage(controller: widget.controller, showHeader: false),
              ProtocolsPage(
                controller: widget.controller,
                initialTab: ProtocolTab.execution,
                showHeader: false,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
