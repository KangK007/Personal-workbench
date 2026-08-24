import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/models/workspace_record.dart';
import '../../core/utils/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../state/workbench_controller.dart';
import '../platform_feedback.dart';
import 'record_editor_dialog.dart';
import 'common.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final project = controller.projectById(task.projectId);
    return PressScale(
      pressedScale: 0.985,
      child: AnimatedSize(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : AppMotion.standard,
        curve: Curves.easeOutCubic,
        child: Material(
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
                      child: selectionMode
                          ? Checkbox(
                              value: selected,
                              onChanged: (value) =>
                                  onSelectionChanged?.call(value ?? false),
                              semanticLabel: selected ? '取消选择' : '选择任务',
                            )
                          : Checkbox(
                              value: task.isDone,
                              onChanged: (_) async {
                                await controller.toggleTaskDone(task);
                                if (!task.isDone && commitmentIndex != null) {
                                  await WorkbenchFeedback.completion();
                                }
                              },
                              semanticLabel: task.isDone ? '标记为未完成' : '标记为完成',
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
                                  defaultTargetPlatform ==
                                          TargetPlatform.android &&
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
                                  maxLines:
                                      task.isDone && commitmentIndex != null
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
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: context.tokens.mutedText,
                                        ),
                                  ),
                                  if (task.isDone && completionXp != null) ...[
                                    const SizedBox(width: 8),
                                    _AnimatedXpBadge(
                                      visible: true,
                                      child: NumericText(
                                        '+$completionXp XP',
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                              color: context.tokens.reward,
                                            ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                            if (!dense &&
                                (task.scheduledFor != null ||
                                    task.estimatedMinutes > 0 ||
                                    task.hasCtdpProtocol ||
                                    (showProject && project != null))) ...[
                              const SizedBox(height: 5),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  if (task.scheduledFor != null)
                                    _Meta(
                                      icon: Icons.schedule,
                                      label:
                                          task.scheduledFor!.hour == 0 &&
                                              task.scheduledFor!.minute == 0
                                          ? formatShortDate(task.scheduledFor!)
                                          : '${formatShortDate(task.scheduledFor!)} ${formatTime(task.scheduledFor!)}',
                                    ),
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
                    if (!selectionMode &&
                        !task.isDone &&
                        commitmentIndex == null)
                      IconButton(
                        onPressed: () async {
                          try {
                            await controller.setFocusTask(task, !task.isFocus);
                          } on FormatException catch (exception) {
                            if (!context.mounted) return;
                            showWorkbenchSnackBar(
                              context,
                              SnackBar(
                                content: Text(exception.message.toString()),
                              ),
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
                          if (task.hasCtdpProtocol &&
                              task.ctdpReservationPending)
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
        ),
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
            content: TextField(
              autofocus: true,
              onChanged: (value) => precedentDraft = value,
              decoration: const InputDecoration(
                labelText: '本次允许的例外行为',
                hintText: '例如：接听紧急电话',
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 150),
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// XP 徽章浮入动画：任务完成时 +XP 徽章上浮渐显，强化打卡成就感。
class _AnimatedXpBadge extends StatefulWidget {
  const _AnimatedXpBadge({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  State<_AnimatedXpBadge> createState() => _AnimatedXpBadgeState();
}

class _AnimatedXpBadgeState extends State<_AnimatedXpBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutBack,
  );

  @override
  void initState() {
    super.initState();
    if (widget.visible) _controller.forward(from: 0);
  }

  @override
  void didUpdateWidget(_AnimatedXpBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.5),
          end: Offset.zero,
        ).animate(_curve),
        child: widget.child,
      ),
    );
  }
}
