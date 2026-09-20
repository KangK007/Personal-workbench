import 'package:flutter/material.dart';

import '../../core/models/workspace_record.dart';
import '../../core/theme/app_theme.dart';
import '../../state/workbench_controller.dart';
import '../widgets/common.dart';
import '../widgets/record_editor_dialog.dart';
import 'habits_page.dart';
import 'policies_page.dart';

enum BehaviorMode { habits, policies }

class BehaviorPage extends StatefulWidget {
  const BehaviorPage({
    super.key,
    required this.controller,
    this.showHeader = true,
    this.initialMode,
    this.initialPolicyTab = PolicyTab.tree,
    this.onModeChanged,
  });

  final WorkbenchController controller;
  final bool showHeader;
  final BehaviorMode? initialMode;
  final PolicyTab initialPolicyTab;
  final ValueChanged<BehaviorMode>? onModeChanged;

  @override
  State<BehaviorPage> createState() => _BehaviorPageState();
}

class _BehaviorPageState extends State<BehaviorPage> {
  late BehaviorMode mode;

  @override
  void initState() {
    super.initState();
    mode = widget.initialMode ?? _modeFromController();
  }

  @override
  void didUpdateWidget(covariant BehaviorPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialMode != null &&
        widget.initialMode != oldWidget.initialMode) {
      mode = widget.initialMode!;
    }
  }

  BehaviorMode _modeFromController() =>
      widget.controller.behaviorMode == 'policies'
      ? BehaviorMode.policies
      : BehaviorMode.habits;

  void _selectMode(BehaviorMode value) {
    if (mode == value) return;
    setState(() => mode = value);
    widget.controller.setBehaviorMode(value.name);
    widget.onModeChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.showHeader)
          const PageHeader(title: '行为', subtitle: '把日常习惯与国策协议放在同一个行为中心。'),
        Padding(
          padding: EdgeInsets.fromLTRB(
            widget.showHeader ? 20 : 8,
            widget.showHeader ? 0 : 4,
            widget.showHeader ? 20 : 8,
            10,
          ),
          child: Row(
            children: [
              Flexible(
                child: SegmentedButton<BehaviorMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: BehaviorMode.habits,
                      icon: Icon(Icons.repeat_outlined),
                      label: Text('习惯追踪'),
                    ),
                    ButtonSegment(
                      value: BehaviorMode.policies,
                      icon: Icon(Icons.account_tree_outlined),
                      label: Text('国策协议'),
                    ),
                  ],
                  selected: {mode},
                  onSelectionChanged: (value) => _selectMode(value.first),
                ),
              ),
              if (mode == BehaviorMode.habits) ...[
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: context.tokens.raised,
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    side: BorderSide(color: context.tokens.panelBorder),
                  ),
                  onPressed: () => showRecordEditor(
                    context,
                    widget.controller,
                    kind: RecordKind.habit,
                  ),
                  tooltip: '新建习惯',
                  icon: const Icon(Icons.add),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: mode.index,
            children: [
              HabitsPage(
                key: const PageStorageKey('behavior-habits'),
                controller: widget.controller,
                showHeader: false,
                includeRsip: false,
              ),
              PoliciesPage(
                key: ValueKey(
                  'behavior-policies-${widget.initialPolicyTab.name}',
                ),
                controller: widget.controller,
                showHeader: false,
                initialTab: widget.initialPolicyTab,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
