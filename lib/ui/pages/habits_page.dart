import 'package:flutter/material.dart';

import '../../core/models/workspace_record.dart';
import '../../core/theme/app_theme.dart';
import '../../state/workbench_controller.dart';
import '../widgets/common.dart';
import '../widgets/record_editor_dialog.dart';

class HabitsPage extends StatelessWidget {
  const HabitsPage({
    super.key,
    required this.controller,
    this.showHeader = true,
    this.protocolSection,
    this.includeRsip = true,
  });

  final WorkbenchController controller;
  final bool showHeader;
  final Widget? protocolSection;
  final bool includeRsip;

  @override
  Widget build(BuildContext context) {
    final habits = controller.habits
        .where((habit) => includeRsip || !habit.hasRsipProtocol)
        .toList(growable: false);
    return Column(
      children: [
        if (showHeader)
          PageHeader(
            title: '习惯',
            subtitle: '行为协议 · 28 日事实矩阵',
            actions: [
              FilledButton.icon(
                onPressed: () => showRecordEditor(
                  context,
                  controller,
                  kind: RecordKind.habit,
                ),
                icon: const _HabitAddIcon(),
                label: const Text('新建习惯'),
              ),
            ],
          ),
        Expanded(
          child: habits.isEmpty
              ? ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 132),
                  children: [
                    EmptyState(
                      icon: Icons.repeat,
                      title: '还没有习惯协议',
                      message: '从真正需要长期保持的一件小事开始。',
                      action: FilledButton.icon(
                        onPressed: () => showRecordEditor(
                          context,
                          controller,
                          kind: RecordKind.habit,
                        ),
                        icon: const _HabitAddIcon(),
                        label: const Text('创建习惯'),
                      ),
                    ),
                    ?protocolSection,
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 132),
                  children: [
                    SectionHeading(
                      title: '近期记录',
                      scale:
                          '${habits.length.toString().padLeft(2, '0')} HABITS',
                    ),
                    _HabitMatrix(habits: habits, controller: controller),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 14,
                      runSpacing: 8,
                      children: const [
                        _Legend(state: WorkStatus.done, label: '完成'),
                        _Legend(state: WorkStatus.skipped, label: '跳过'),
                        _Legend(state: WorkStatus.todo, label: '未记录'),
                      ],
                    ),
                    if (protocolSection != null) ...[
                      const SizedBox(height: 18),
                      protocolSection!,
                    ],
                    if (habits.length < 5) const SizedBox(height: 12),
                  ],
                ),
        ),
      ],
    );
  }
}

class _HabitMatrix extends StatelessWidget {
  const _HabitMatrix({required this.habits, required this.controller});

  final List<WorkspaceRecord> habits;
  final WorkbenchController controller;

  @override
  Widget build(BuildContext context) {
    final today = controller.growthService.logicalDay(controller.currentTime());
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    final cellSlot = compact ? 20.0 : 18.0;
    final days = List.generate(
      28,
      (index) => today.subtract(Duration(days: 27 - index)),
    );
    return Column(
      children: [
        for (final habit in habits)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _HabitLabel(
                            habit: habit,
                            controller: controller,
                          ),
                        ),
                        _TodayHabitButton(
                          habit: habit,
                          controller: controller,
                          today: today,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final day in days)
                            SizedBox(
                              width: cellSlot,
                              child: Center(
                                child: NumericText(
                                  day.day % 7 == 1 ? '${day.day}' : '·',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: context.tokens.mutedText,
                                      ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 5),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final day in days)
                            _HabitCell(
                              label: '${habit.title}，${day.month}月${day.day}日',
                              status: controller
                                  .habitLogForDay(habit.id, day)
                                  ?.status,
                              isToday: isSameDay(day, today),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TodayHabitButton extends StatelessWidget {
  const _TodayHabitButton({
    required this.habit,
    required this.controller,
    required this.today,
  });

  final WorkspaceRecord habit;
  final WorkbenchController controller;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final log = controller.habitLogForDay(habit.id, today);
    final checked = log?.status == WorkStatus.done;
    final failed = log?.status == WorkStatus.failed;
    final locked = habit.hasRsipProtocol && (!habit.rsipActive || failed);
    return OutlinedButton.icon(
      onPressed: locked
          ? null
          : () async {
              try {
                await controller.setHabitTodayStatus(
                  habit,
                  checked ? WorkStatus.todo : WorkStatus.done,
                );
              } on FormatException catch (error) {
                if (!context.mounted) return;
                showWorkbenchSnackBar(
                  context,
                  SnackBar(content: Text(error.message)),
                );
              }
            },
      icon: Icon(checked ? Icons.undo_outlined : Icons.check),
      label: Text(
        locked
            ? failed
                  ? '已失败'
                  : '已熄灭'
            : checked
            ? '取消打卡'
            : '今日打卡',
      ),
    );
  }
}

class _HabitLabel extends StatelessWidget {
  const _HabitLabel({required this.habit, required this.controller});

  final WorkspaceRecord habit;
  final WorkbenchController controller;

  @override
  Widget build(BuildContext context) {
    String? parentTitle;
    for (final candidate in controller.habits) {
      if (candidate.id == habit.parentId) {
        parentTitle = candidate.title;
        break;
      }
    }
    final hierarchy = parentTitle == null ? '根节点' : '子节点 · $parentTitle';
    final protocolColor = habit.rsipActive
        ? Theme.of(context).colorScheme.primary
        : context.tokens.mutedText;
    return SizedBox(
      width: 220,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: InkWell(
              onTap: () => showRecordEditor(
                context,
                controller,
                kind: RecordKind.habit,
                record: habit,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: habit.hasRsipProtocol && !habit.rsipActive
                            ? context.tokens.mutedText
                            : null,
                      ),
                    ),
                    if (habit.hasRsipProtocol) ...[
                      Text(
                        '最小动作：${habit.rsipMinimumAction}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      Text(
                        '${habit.rsipActive ? '' : '已熄灭 · '}$hierarchy · #${habit.rsipChainCount} · 内化 ${habit.rsipInternalization}%',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.labelSmall?.copyWith(color: protocolColor),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (habit.hasRsipProtocol)
            PopupMenuButton<String>(
              tooltip: 'RSIP 节点操作',
              onSelected: (value) async {
                if (value == 'fail') {
                  await controller.logHabit(
                    habit,
                    controller.growthService.logicalDay(
                      controller.currentTime(),
                    ),
                    WorkStatus.failed,
                  );
                } else if (value == 'reactivate') {
                  await controller.reactivateRsipHabit(habit);
                }
                if (!context.mounted) return;
                showWorkbenchSnackBar(
                  context,
                  SnackBar(
                    content: Text(
                      value == 'fail' ? '当前节点及其子节点已熄灭' : 'RSIP 节点已重新启用',
                    ),
                  ),
                );
              },
              itemBuilder: (context) => [
                if (habit.rsipActive)
                  const PopupMenuItem(
                    value: 'fail',
                    child: ListTile(
                      leading: Icon(Icons.power_settings_new),
                      title: Text('今日失败并熄灭分支'),
                    ),
                  )
                else
                  const PopupMenuItem(
                    value: 'reactivate',
                    child: ListTile(
                      leading: Icon(Icons.restart_alt),
                      title: Text('重新启用节点'),
                    ),
                  ),
              ],
              icon: const Icon(Icons.more_horiz),
            ),
        ],
      ),
    );
  }
}

class _HabitCell extends StatelessWidget {
  const _HabitCell({
    required this.label,
    required this.status,
    required this.isToday,
  });
  final String label;
  final String? status;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    final cellSize = compact ? 16.0 : 14.0;
    // 未记录格用 mutedText@35% 描边，保证与面板底 ≥1.15:1 的可辨识对比度。
    final unrecordedBorder = context.tokens.mutedText.withValues(alpha: 0.35);
    final color = switch (status) {
      WorkStatus.done => Theme.of(context).colorScheme.primary,
      WorkStatus.skipped => context.tokens.reward,
      _ => unrecordedBorder,
    };
    return Semantics(
      button: false,
      label: switch (status) {
        WorkStatus.done => '$label，已完成',
        WorkStatus.skipped => '$label，已跳过',
        WorkStatus.todo => '$label，待记录',
        _ => '$label，未记录',
      },
      child: InkWell(
        onTap: null,
        borderRadius: BorderRadius.circular(3),
        child: Container(
          width: cellSize,
          height: cellSize,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: status == null || status == WorkStatus.todo
                ? Colors.transparent
                : color,
            border: Border.all(
              color: isToday ? context.tokens.marker : color,
              width: isToday ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
          child: status == WorkStatus.done
              ? Icon(
                  Icons.check,
                  size: compact ? 10 : 9,
                  color: Theme.of(context).colorScheme.onPrimary,
                )
              : status == WorkStatus.skipped
              ? Icon(
                  Icons.remove,
                  size: compact ? 10 : 9,
                  color: Theme.of(context).colorScheme.onSurface,
                )
              : null,
        ),
      ),
    );
  }
}

class _HabitAddIcon extends StatelessWidget {
  const _HabitAddIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.add,
        size: 17,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.state, required this.label});
  final String state;
  final String label;
  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      WorkStatus.done => Theme.of(context).colorScheme.primary,
      WorkStatus.skipped => context.tokens.reward,
      _ => context.tokens.divider,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: state == WorkStatus.todo ? Colors.transparent : color,
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: context.tokens.mutedText),
        ),
      ],
    );
  }
}
