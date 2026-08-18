import 'package:flutter/material.dart';

import '../../core/models/workspace_record.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../state/workbench_controller.dart';
import '../widgets/common.dart';
import '../widgets/record_editor_dialog.dart';

class GoalsPage extends StatelessWidget {
  const GoalsPage({
    super.key,
    required this.controller,
    this.showHeader = true,
  });

  final WorkbenchController controller;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final goals = controller.goals
      ..sort((a, b) {
        if (a.favorite != b.favorite) return a.favorite ? -1 : 1;
        return (a.dueAt ?? DateTime(2100)).compareTo(b.dueAt ?? DateTime(2100));
      });
    return Column(
      children: [
        if (showHeader)
          PageHeader(
            title: '目标',
            subtitle: '结果协议 → 里程碑 → 关联项目',
            actions: [
              FilledButton.icon(
                onPressed: () => showRecordEditor(
                  context,
                  controller,
                  kind: RecordKind.goal,
                ),
                icon: const Icon(Icons.add),
                label: const Text('新建目标'),
              ),
            ],
          ),
        Expanded(
          child: goals.isEmpty
              ? EmptyState(
                  icon: Icons.flag_outlined,
                  title: '还没有目标',
                  message: '目标应描述一个有截止时间的结果，再用里程碑拆解。',
                  action: FilledButton(
                    onPressed: () => showRecordEditor(
                      context,
                      controller,
                      kind: RecordKind.goal,
                    ),
                    child: const Text('建立第一个目标'),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 132),
                  children: [
                    SectionHeading(
                      title: '目标树',
                      scale:
                          '${goals.length.toString().padLeft(2, '0')} OUTCOMES',
                    ),
                    LogSurface(
                      child: Column(
                        children: [
                          for (
                            var index = 0;
                            index < goals.length;
                            index++
                          ) ...[
                            _GoalBranch(
                              goal: goals[index],
                              controller: controller,
                            ),
                            if (index < goals.length - 1) const Divider(),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _GoalBranch extends StatelessWidget {
  const _GoalBranch({required this.goal, required this.controller});

  final WorkspaceRecord goal;
  final WorkbenchController controller;

  @override
  Widget build(BuildContext context) {
    final milestones = controller.milestonesForGoal(goal.id);
    final done = milestones.where((milestone) => milestone.isDone).length;
    final linkedProjects = controller
        .linkedRecords(goal)
        .where((record) => record.kind == RecordKind.project)
        .toList();
    return ExpansionTile(
      tilePadding: const EdgeInsets.fromLTRB(14, 5, 8, 5),
      childrenPadding: const EdgeInsets.fromLTRB(48, 0, 14, 14),
      leading: SizedBox(
        width: 30,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.flag_outlined,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
            Container(width: 1, height: 10, color: context.tokens.divider),
          ],
        ),
      ),
      title: Text(goal.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${goal.dueAt == null ? '无截止日' : formatShortDate(goal.dueAt!)} · 里程碑 $done/${milestones.length}',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: context.tokens.mutedText),
      ),
      trailing: IconButton(
        onPressed: () => showRecordEditor(
          context,
          controller,
          kind: RecordKind.goal,
          record: goal,
        ),
        tooltip: '编辑目标',
        icon: const Icon(Icons.edit_outlined),
      ),
      children: [
        if (goal.body.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                goal.body,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.tokens.mutedText,
                ),
              ),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: Text('里程碑', style: Theme.of(context).textTheme.titleSmall),
            ),
            TextButton.icon(
              onPressed: () => showRecordEditor(
                context,
                controller,
                kind: RecordKind.milestone,
                initialParentId: goal.id,
              ),
              icon: const Icon(Icons.add),
              label: const Text('添加'),
            ),
          ],
        ),
        if (milestones.isEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '尚未拆分里程碑。',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: context.tokens.mutedText),
            ),
          )
        else
          for (final milestone in milestones)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 1,
                  height: 46,
                  margin: const EdgeInsets.only(left: 8, right: 14),
                  color: milestone.isDone
                      ? Theme.of(context).colorScheme.primary
                      : context.tokens.divider,
                ),
                Expanded(
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: milestone.isDone,
                    title: Text(milestone.title),
                    subtitle: milestone.dueAt == null
                        ? null
                        : Text(formatShortDate(milestone.dueAt!)),
                    onChanged: (_) => controller.toggleTaskDone(milestone),
                    secondary: IconButton(
                      onPressed: () => showRecordEditor(
                        context,
                        controller,
                        kind: RecordKind.milestone,
                        record: milestone,
                      ),
                      tooltip: '编辑里程碑',
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ),
                ),
              ],
            ),
        if (linkedProjects.isNotEmpty) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('关联项目', style: Theme.of(context).textTheme.titleSmall),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: linkedProjects
                .map(
                  (project) => StatusPill(
                    label: project.title,
                    icon: Icons.folder_outlined,
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}
