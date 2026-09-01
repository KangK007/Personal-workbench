import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/models/workspace_record.dart';
import '../../core/theme/app_theme.dart';
import '../../state/workbench_controller.dart';
import '../platform_feedback.dart';
import 'record_editor_dialog.dart';
import 'common.dart';
import 'task_hierarchy.dart';

class TaskRow extends StatelessWidget {
  const TaskRow({
    super.key,
    required this.task,
    required this.controller,
    this.showProject = true,
    this.dense = false,
    this.onStartFocus,
    this.commitmentIndex,
    this.completionXp,
    this.selectionMode = false,
    this.selected = false,
    this.onSelectionChanged,
    this.hierarchyDepth = 0,
    this.hasChildren = false,
    this.expanded = true,
    this.onToggleExpanded,
    this.relationInfo,
  });

  final WorkspaceRecord task;
  final WorkbenchController controller;
  final bool showProject;
  final bool dense;
  final VoidCallback? onStartFocus;
  final int? commitmentIndex;
  final int? completionXp;
  final bool selectionMode;
  final bool selected;
  final ValueChanged<bool>? onSelectionChanged;
  final int hierarchyDepth;
  final bool hasChildren;
  final bool expanded;
  final VoidCallback? onToggleExpanded;
  final TaskRelationInfo? relationInfo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final project = controller.projectById(task.projectId);
    final relation =
        relationInfo ?? taskRelationInfo(task, controller.allRecords);
    final content = Material(
      color: task.isDone && commitmentIndex != null
          ? theme.colorScheme.primary.withValues(alpha: 0.045)
          : Colors.transparent,
      child: InkWell(
        onTap: selectionMode
            ? () => onSelectionChanged?.call(!selected)
            : () => showRecordEditor(
                context,
                controller,
                kind: RecordKind.task,
                record: task,
              ),
        onLongPress: selectionMode
            ? null
            : () => onSelectionChanged?.call(true),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: task.isDone && commitmentIndex != null
                ? 42
                : (dense ? 48 : 58),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 10,
              vertical: dense ? 4 : 7,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hierarchyDepth > 0)
                  SizedBox(
                    width: (hierarchyDepth * 20).clamp(0, 80).toDouble(),
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Container(
                        width: 1,
                        margin: const EdgeInsetsDirectional.only(end: 8),
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                if (hasChildren || hierarchyDepth > 0)
                  SizedBox.square(
                    dimension: 40,
                    child: hasChildren
                        ? IconButton(
                            onPressed: onToggleExpanded,
                            tooltip: expanded ? '收起子任务' : '展开子任务',
                            icon: Icon(
                              expanded
                                  ? Icons.expand_more
                                  : Icons.chevron_right,
                            ),
                          )
                        : const Icon(Icons.subdirectory_arrow_right, size: 18),
                  ),
                if (commitmentIndex != null) ...[
                  // 状态强调条（v2 规范）：done=primary@30%，进行中=primary。
                  Container(
                    width: 3,
                    height: task.isDone ? 26 : 38,
                    margin: const EdgeInsets.only(top: 5, right: 8),
                    decoration: BoxDecoration(
                      color: task.isDone
                          ? theme.colorScheme.primary.withValues(alpha: 0.3)
                          : theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(
                    width: 28,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: NumericText(
                        '${commitmentIndex! + 1}'.padLeft(2, '0'),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: context.tokens.mutedText,
                        ),
                      ),
                    ),
                  ),
                ],
                SizedBox.square(
                  dimension: 48,
                  child: _CompletionNode(
                    done: task.isDone,
                    selectionMode: selectionMode,
                    selected: selected,
                    onSelectionChanged: onSelectionChanged,
                    onToggleDone: () async {
                      await controller.toggleTaskDone(task);
                      if (!task.isDone && commitmentIndex != null) {
                        await WorkbenchFeedback.completion();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Tooltip(
                          message: task.title,
                          triggerMode:
                              defaultTargetPlatform == TargetPlatform.android &&
                                  onSelectionChanged != null
                              ? TooltipTriggerMode.manual
                              : null,
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                            style: theme.textTheme.bodyLarge!.copyWith(
                              decoration: task.isDone
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                              color: task.isDone
                                  ? theme.colorScheme.onSurfaceVariant
                                  : theme.textTheme.bodyLarge!.color,
                            ),
                            child: Text(
                              task.title,
                              maxLines: task.isDone && commitmentIndex != null
                                  ? 1
                                  : 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        if (commitmentIndex != null) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Text(
                                task.isDone ? '已归入执行日志' : '今日承诺',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: context.tokens.mutedText,
                                ),
                              ),
                              AnimatedSwitcher(
                                duration:
                                    MediaQuery.disableAnimationsOf(context)
                                    ? Duration.zero
                                    : AppMotion.standard,
                                reverseDuration:
                                    MediaQuery.disableAnimationsOf(context)
                                    ? Duration.zero
                                    : AppMotion.exit,
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                transitionBuilder: (child, animation) =>
                                    FadeTransition(
                                      opacity: animation,
                                      child: ScaleTransition(
                                        scale: Tween<double>(
                                          begin: 0.96,
                                          end: 1,
                                        ).animate(animation),
                                        child: child,
                                      ),
                                    ),
                                child: task.isDone && completionXp != null
                                    ? Padding(
                                        key: ValueKey(completionXp),
                                        padding: const EdgeInsets.only(left: 8),
                                        child: NumericText(
                                          '+$completionXp XP',
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(
                                                color: context.tokens.reward,
                                              ),
                                        ),
                                      )
                                    : const SizedBox.shrink(
                                        key: ValueKey('xp-hidden'),
                                      ),
                              ),
                            ],
                          ),
                        ],
                        if (relation.label != null) ...[
                          const SizedBox(height: 4),
                          _RelationLabel(relation: relation),
                        ],
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: dense ? 6 : 8,
                          runSpacing: 4,
                          children: [
                            _Meta(
                              icon: Icons.date_range_outlined,
                              label:
                                  '安排 ${_dateLabel(task.scheduledFor, empty: '未安排')} → 截止 ${_dateLabel(task.dueAt, empty: '无截止')}',
                            ),
                            _Meta(
                              icon: _statusIcon(task.status),
                              label: '状态 ${statusLabel(task.status)}',
                            ),
                            _Meta(
                              icon: Icons.flag_outlined,
                              label: '优先级 ${_priorityLabel(task.priority)}',
                            ),
                            _Meta(
                              icon: Icons.repeat_outlined,
                              label: '循环 ${_recurrenceLabel(task)}',
                            ),
                          ],
                        ),
                        if (task.estimatedMinutes > 0 ||
                            task.hasCtdpProtocol ||
                            (showProject && project != null)) ...[
                          const SizedBox(height: 5),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if ((task.hasCtdpProtocol
                                      ? task.ctdpSessionMinutes
                                      : task.estimatedMinutes) >
                                  0)
                                _Meta(
                                  icon: Icons.timelapse,
                                  label:
                                      '${task.hasCtdpProtocol ? task.ctdpSessionMinutes : task.estimatedMinutes} min',
                                ),
                              if (task.hasCtdpProtocol)
                                _Meta(
                                  icon: task.ctdpReservationPending
                                      ? Icons.pending_actions_outlined
                                      : Icons.link_outlined,
                                  label: task.ctdpReservationPending
                                      ? '预约中 · 主 #${task.ctdpChainCount} · 辅 #${task.ctdpAuxChainCount}'
                                      : 'CTDP 主 #${task.ctdpChainCount} · 辅 #${task.ctdpAuxChainCount}',
                                ),
                              if (showProject && project != null)
                                _Meta(
                                  icon: Icons.folder_outlined,
                                  label: project.title,
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (!selectionMode && !task.isDone && commitmentIndex == null)
                  IconButton(
                    onPressed: () async {
                      try {
                        await controller.setFocusTask(task, !task.isFocus);
                      } on FormatException catch (exception) {
                        if (!context.mounted) return;
                        showWorkbenchSnackBar(
                          context,
                          SnackBar(content: Text(exception.message.toString())),
                        );
                      }
                    },
                    tooltip: task.isFocus ? '移出今日重点' : '设为今日重点',
                    icon: Icon(
                      task.isFocus ? Icons.star : Icons.star_border,
                      color: task.isFocus
                          ? theme.colorScheme.tertiary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (!selectionMode)
                  PopupMenuButton<String>(
                    tooltip: '更多操作',
                    onSelected: (value) => _handleAction(context, value),
                    itemBuilder: (context) => [
                      if (onStartFocus != null)
                        const PopupMenuItem(
                          value: 'focus',
                          child: ListTile(
                            leading: Icon(Icons.timer_outlined),
                            title: Text('开始专注'),
                          ),
                        ),
                      if (task.hasCtdpProtocol)
                        PopupMenuItem(
                          value: task.ctdpReservationPending
                              ? 'ctdp_confirm'
                              : 'ctdp_reserve',
                          child: ListTile(
                            leading: Icon(
                              task.ctdpReservationPending
                                  ? Icons.play_arrow_outlined
                                  : Icons.notifications_active_outlined,
                            ),
                            title: Text(
                              task.ctdpReservationPending
                                  ? '触发主链'
                                  : '预约 ${task.ctdpDelayMinutes} 分钟后开始',
                            ),
                          ),
                        ),
                      if (task.hasCtdpProtocol && task.ctdpReservationPending)
                        const PopupMenuItem(
                          value: 'ctdp_aux_fail',
                          child: ListTile(
                            leading: Icon(Icons.notifications_off_outlined),
                            title: Text('辅助链失败并重置'),
                          ),
                        ),
                      if (task.hasCtdpProtocol)
                        const PopupMenuItem(
                          value: 'ctdp_precedent',
                          child: ListTile(
                            leading: Icon(Icons.gavel_outlined),
                            title: Text('记录判例'),
                          ),
                        ),
                      if (task.hasCtdpProtocol && !task.isDone)
                        const PopupMenuItem(
                          value: 'ctdp_fail',
                          child: ListTile(
                            leading: Icon(Icons.link_off_outlined),
                            title: Text('主链失败并重置'),
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('编辑'),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'subtask',
                        child: ListTile(
                          leading: Icon(Icons.subdirectory_arrow_right),
                          title: Text('添加子任务'),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'trash',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline),
                          title: Text('移入回收站'),
                        ),
                      ),
                    ],
                    icon: const Icon(Icons.more_horiz),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    // 减少动效时跳过 AnimatedSize：零时长动画在布局中重入会触发
    // RenderAnimatedSize 断言，直接渲染静态终态。
    return PressScale(
      pressedScale: 0.985,
      child: MediaQuery.disableAnimationsOf(context)
          ? content
          : AnimatedSize(
              duration: AppMotion.standard,
              curve: Curves.easeOutCubic,
              child: content,
            ),
    );
  }

  Future<void> _handleAction(BuildContext context, String value) async {
    switch (value) {
      case 'focus':
        onStartFocus?.call();
      case 'ctdp_reserve':
        await controller.startCtdpReservation(task);
        if (!context.mounted) return;
        showWorkbenchSnackBar(
          context,
          SnackBar(content: Text('已预约：${task.ctdpDelayMinutes} 分钟后触发主链')),
        );
      case 'ctdp_confirm':
        try {
          await controller.confirmCtdpTrigger(task);
          onStartFocus?.call();
        } on FormatException catch (exception) {
          if (!context.mounted) return;
          showWorkbenchSnackBar(
            context,
            SnackBar(content: Text(exception.message.toString())),
          );
        }
      case 'ctdp_aux_fail':
        await controller.failCtdpAuxiliary(task);
        if (!context.mounted) return;
        showWorkbenchSnackBar(
          context,
          const SnackBar(content: Text('CTDP 辅助链已重置')),
        );
      case 'ctdp_precedent':
        var precedentDraft = '';
        final precedent = await showWorkbenchDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('记录 CTDP 判例'),
            content: ExternalField(
              label: '本次允许的例外行为',
              child: TextField(
                autofocus: true,
                onChanged: (value) => precedentDraft = value,
                decoration: const InputDecoration(hintText: '例如：接听紧急电话'),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, precedentDraft.trim()),
                child: const Text('写入判例'),
              ),
            ],
          ),
        );
        if (precedent != null && precedent.isNotEmpty) {
          await controller.recordCtdpPrecedent(task, precedent);
        }
      case 'ctdp_fail':
        await controller.failCtdpTask(task);
        if (!context.mounted) return;
        showWorkbenchSnackBar(
          context,
          const SnackBar(content: Text('CTDP 主链已重置')),
        );
      case 'edit':
        await showRecordEditor(
          context,
          controller,
          kind: RecordKind.task,
          record: task,
        );
      case 'subtask':
        await showRecordEditor(
          context,
          controller,
          kind: RecordKind.task,
          initialProjectId: task.projectId,
          initialParentId: task.id,
        );
      case 'trash':
        await controller.moveToTrash(task);
        if (!context.mounted) return;
        showWorkbenchSnackBar(
          context,
          SnackBar(
            content: const Text('任务已移入回收站'),
            action: SnackBarAction(
              label: '撤销',
              onPressed: () => controller.restoreFromTrash(task),
            ),
          ),
        );
    }
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return SizedBox(
      width: 180,
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _RelationLabel extends StatelessWidget {
  const _RelationLabel({required this.relation});

  final TaskRelationInfo relation;

  @override
  Widget build(BuildContext context) {
    final color = relation.isWarning
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          relation.isWarning
              ? Icons.warning_amber_outlined
              : Icons.subdirectory_arrow_right,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            relation.label!,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

String _dateLabel(DateTime? value, {required String empty}) {
  if (value == null) return empty;
  final date = '${value.month}月${value.day}日';
  return value.hour == 0 && value.minute == 0
      ? date
      : '$date ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

String _priorityLabel(int priority) => switch (priority) {
  1 => '低',
  2 => '中',
  3 => '高',
  _ => '普通',
};

IconData _statusIcon(String status) => switch (status) {
  WorkStatus.done => Icons.check_circle_outline,
  WorkStatus.doing => Icons.play_circle_outline,
  WorkStatus.failed => Icons.error_outline,
  WorkStatus.skipped => Icons.skip_next_outlined,
  WorkStatus.rescheduled => Icons.event_repeat_outlined,
  WorkStatus.cancelled => Icons.cancel_outlined,
  WorkStatus.inbox => Icons.inbox_outlined,
  _ => Icons.radio_button_unchecked,
};

String _recurrenceLabel(WorkspaceRecord task) {
  final definition = TaskDefinition.fromRecord(task);
  final base = switch (definition.recurrence) {
    RecurrenceType.none => '不循环',
    RecurrenceType.daily => '每天',
    RecurrenceType.weekdays => '工作日',
    RecurrenceType.weekly =>
      definition.weekdays.isEmpty
          ? '每周'
          : '每周（${definition.weekdays.map(_weekdayLabel).join('、')}）',
    RecurrenceType.monthly => '每月',
    RecurrenceType.yearly => '每年',
  };
  final end = definition.endAt;
  return end == null ? base : '$base，至 ${end.month}月${end.day}日';
}

String _weekdayLabel(int value) => switch (value) {
  DateTime.monday => '一',
  DateTime.tuesday => '二',
  DateTime.wednesday => '三',
  DateTime.thursday => '四',
  DateTime.friday => '五',
  DateTime.saturday => '六',
  DateTime.sunday => '日',
  _ => '?',
};

/// 任务完成瞬间的"航迹节点落定"：从勾选框圆心弹出一个黄铜标记色
/// 节点，并向右留下一条短航迹线后淡出（180ms，仅完成瞬间播放一次）。
/// 语义：这件真实完成的工作被记入执行日志。
class _CompletionNode extends StatefulWidget {
  const _CompletionNode({
    required this.done,
    required this.selectionMode,
    required this.selected,
    required this.onSelectionChanged,
    required this.onToggleDone,
  });

  final bool done;
  final bool selectionMode;
  final bool selected;
  final ValueChanged<bool>? onSelectionChanged;
  final VoidCallback onToggleDone;

  @override
  State<_CompletionNode> createState() => _CompletionNodeState();
}

class _CompletionNodeState extends State<_CompletionNode>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: AppMotion.standard,
  );

  @override
  void didUpdateWidget(_CompletionNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.done && widget.done) {
      // binding 级减少动效检查不依赖 inherited widget，
      // 可在 didUpdateWidget 中安全使用。
      final binding = WidgetsBinding.instance;
      if (!binding.platformDispatcher.accessibilityFeatures.disableAnimations) {
        _pulse.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final checkbox = widget.selectionMode
        ? Checkbox(
            value: widget.selected,
            onChanged: (value) =>
                widget.onSelectionChanged?.call(value ?? false),
            semanticLabel: widget.selected ? '取消选择' : '选择任务',
          )
        : Checkbox(
            value: widget.done,
            onChanged: (_) => widget.onToggleDone(),
            semanticLabel: widget.done ? '标记为未完成' : '标记为完成',
          );
    return SizedBox.square(
      dimension: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          checkbox,
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                if (_pulse.value <= 0 ||
                    _pulse.value >= 1 ||
                    MediaQuery.disableAnimationsOf(context)) {
                  return const SizedBox.shrink();
                }
                return CustomPaint(
                  key: const ValueKey('completion-node-pulse'),
                  size: const Size.square(48),
                  painter: _NodePulsePainter(
                    progress: _pulse.value,
                    color: context.tokens.marker,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NodePulsePainter extends CustomPainter {
  const _NodePulsePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final t = progress;

    // 节点从勾选框圆心放大并淡出
    final nodeRadius = 3.0 + 9.0 * t;
    canvas.drawCircle(
      center,
      nodeRadius,
      Paint()
        ..color = color.withValues(alpha: (1 - t) * 0.85)
        ..style = PaintingStyle.fill,
    );

    // 一小段航迹线向右延伸后淡出
    final trailEnd = center.translate(16.0 * t, 0);
    if (t > 0.08) {
      canvas.drawLine(
        center.translate(4, 0),
        trailEnd,
        Paint()
          ..color = color.withValues(alpha: (1 - t) * 0.6)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NodePulsePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
