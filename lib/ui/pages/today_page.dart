import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/models/workspace_record.dart';
import '../../core/models/workspace_models_v3.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../state/workbench_controller.dart';
import '../platform_feedback.dart';
import '../widgets/common.dart';
import '../widgets/quick_capture_sheet.dart';
import '../widgets/record_editor_dialog.dart';
import '../widgets/task_row.dart';
import 'focus_page.dart';

class TodayPage extends StatelessWidget {
  const TodayPage({
    super.key,
    required this.controller,
    this.date,
    this.showHeader = true,
    this.onOpenPlan,
    this.onOpenInbox,
    this.onOpenReview,
  });

  final WorkbenchController controller;
  final DateTime? date;
  final bool showHeader;
  final VoidCallback? onOpenPlan;
  final VoidCallback? onOpenInbox;
  final VoidCallback? onOpenReview;

  @override
  Widget build(BuildContext context) {
    final date = this.date ?? controller.currentTime();
    return Column(
      children: [
        if (showHeader)
          PageHeader(
            title: '今日',
            subtitle: formatFullDate(date),
            actions: [
              IconButton(
                onPressed: () => showWorkbenchDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('每日记录分界'),
                    content: Text(
                      '应用以每天 ${controller.logicalDayBoundaryHour.toString().padLeft(2, '0')}:00 '
                      '作为任务、日记和回顾的日期分界。修改设置只影响未来实例。',
                    ),
                  ),
                ),
                tooltip: '了解每日记录分界',
                icon: const Icon(Icons.info_outline),
              ),
            ],
          ),
        if (showHeader &&
            MediaQuery.sizeOf(context).width >= AppBreakpoints.compact)
          _TimeRuler(startHour: controller.logicalDayBoundaryHour),
        Expanded(
          child: _TodayContent(
            controller: controller,
            date: date,
            onOpenPlan: onOpenPlan,
            onOpenInbox: onOpenInbox,
            onOpenReview: onOpenReview,
          ),
        ),
      ],
    );
  }
}

class _TimeRuler extends StatelessWidget {
  const _TimeRuler({required this.startHour});

  final int startHour;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labels = List<String>.generate(
      10,
      (index) => '${'${(startHour + index * 2) % 24}'.padLeft(2, '0')}:00',
    );
    return SizedBox(
      height: 38,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.tokens.divider)),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _TimeRulerPainter(color: context.tokens.divider),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                children: [
                  Icon(
                    Icons.wb_sunny_outlined,
                    size: 16,
                    color: context.tokens.reward,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (final label in labels)
                          Text(
                            label,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.nightlight_outlined,
                    size: 16,
                    color: context.tokens.mutedText,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeRulerPainter extends CustomPainter {
  const _TimeRulerPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..strokeWidth = 1;
    const left = 54.0;
    final right = size.width - 54;
    for (var index = 0; index <= 9; index++) {
      final x = left + (right - left) * index / 9;
      canvas.drawLine(
        Offset(x, size.height - 10),
        Offset(x, size.height - (index % 2 == 0 ? 2 : 5)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TimeRulerPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _TodayContent extends StatelessWidget {
  const _TodayContent({
    required this.controller,
    required this.date,
    this.onOpenPlan,
    this.onOpenInbox,
    this.onOpenReview,
  });

  final WorkbenchController controller;
  final DateTime date;
  final VoidCallback? onOpenPlan;
  final VoidCallback? onOpenInbox;
  final VoidCallback? onOpenReview;

  @override
  Widget build(BuildContext context) {
    final commitments = controller.commitmentTasks;
    final wide = MediaQuery.sizeOf(context).width >= AppBreakpoints.expanded;
    final overdue = controller.overdueTasks;
    final today = controller.todayTasks
        .where((task) => !WorkStatus.terminal.contains(task.status))
        .toList();
    final settled = controller.settledTodayTasks;
    final nextStep = _NextStepPanel(
      controller: controller,
      date: date,
      onOpenPlan: onOpenPlan,
      onOpenInbox: onOpenInbox,
      onOpenReview: onOpenReview,
    );
    final timeline = <Widget>[
      SectionHeading(
        title: '时间安排',
        scale: '06:00—02:00',
        trailing: TextButton.icon(
          onPressed: controller.todayTasks.isEmpty
              ? null
              : () => _showTimeBlockDialog(
                  context,
                  controller,
                  controller.todayTasks.first,
                ),
          icon: const Icon(Icons.add),
          label: const Text('安排'),
        ),
      ),
      _Timeline(controller: controller, date: date),
    ];
    final overdueSection = _TodayTaskSection(
      title: '逾期待结算',
      tasks: overdue,
      controller: controller,
      emptyMessage: '没有逾期待处理的任务。',
      accent: Theme.of(context).colorScheme.error,
    );
    final todaySection = _TodayTaskSection(
      title: '今日',
      tasks: today,
      controller: controller,
      emptyMessage: '今天还没有待处理任务。',
      accent: Theme.of(context).colorScheme.primary,
    );
    final settledSection = _TodayTaskSection(
      title: '已结算',
      tasks: settled,
      controller: controller,
      emptyMessage: '今天还没有已结算任务。',
      accent: context.tokens.reward,
      settled: true,
    );
    final taskSections = <Widget>[overdueSection, todaySection, settledSection];
    final details = <Widget>[
      const SectionHeading(title: '计划习惯'),
      _HabitLog(controller: controller, date: date),
      const SectionHeading(title: '每日收尾'),
      _ClosePanel(controller: controller, onClosed: onOpenReview),
      if (controller.advancedFeaturesEnabled) ...[
        const SectionHeading(title: '成长记录'),
        _CompactGrowth(controller: controller),
      ],
    ];
    final commitmentSection = <Widget>[
      SectionHeading(
        title: '今日重点',
        scale: controller.todayStarted ? '${commitments.length} 项' : '最多 3 项',
        trailing: controller.todayStarted
            ? Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                children: [
                  StatusPill(
                    label: controller.todayClosed ? '已收尾' : '执行中',
                    color: controller.todayClosed
                        ? Theme.of(context).colorScheme.primaryContainer
                        : context.tokens.rewardContainer,
                  ),
                  if (controller.canUpdateTodayCommitments)
                    TextButton(
                      onPressed: () =>
                          _showAdjustTodayDialog(context, controller),
                      child: const Text('调整重点'),
                    ),
                ],
              )
            : null,
      ),
      if (controller.todayStarted)
        _CommitmentLog(controller: controller, commitments: commitments)
      else
        _TodayTaskPreview(controller: controller),
    ];

    if (wide) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 72),
                children: [
                  nextStep,
                  ...taskSections,
                  ...timeline,
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    title: const Text('今日详情'),
                    children: details,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            SizedBox(
              width: 380,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 80),
                children: [
                  ...commitmentSection,
                  if (controller.advancedFeaturesEnabled) ...[
                    const SectionHeading(title: '成长进度'),
                    _CompactGrowth(controller: controller),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        132 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        nextStep,
        todaySection,
        ...commitmentSection,
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: const Text('更多今日记录'),
          children: [
            overdueSection,
            settledSection,
            ...timeline,
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: const Text('今日详情'),
              children: details,
            ),
          ],
        ),
      ],
    );
  }
}

enum _TodayNextState {
  createTask,
  organizeInbox,
  scheduleTasks,
  selectPriorities,
  focus,
  closeDay,
  closed,
}

class _TodayTaskSection extends StatelessWidget {
  const _TodayTaskSection({
    required this.title,
    required this.tasks,
    required this.controller,
    required this.emptyMessage,
    required this.accent,
    this.settled = false,
  });

  final String title;
  final List<WorkspaceRecord> tasks;
  final WorkbenchController controller;
  final String emptyMessage;
  final Color accent;
  final bool settled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(title: title, scale: '${tasks.length} 项'),
        if (tasks.isEmpty)
          Text(
            emptyMessage,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: context.tokens.mutedText),
          )
        else
          LogSurface(
            accent: accent,
            child: Column(
              children: [
                for (var index = 0; index < tasks.length; index++) ...[
                  _TodayStatusTask(
                    task: tasks[index],
                    controller: controller,
                    settled: settled,
                  ),
                  if (index < tasks.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _TodayStatusTask extends StatelessWidget {
  const _TodayStatusTask({
    required this.task,
    required this.controller,
    required this.settled,
  });

  final WorkspaceRecord task;
  final WorkbenchController controller;
  final bool settled;

  @override
  Widget build(BuildContext context) {
    return _ExpandableTodayTask(
      task: task,
      controller: controller,
      settled: settled,
      onSettle: (value) => _settle(context, value),
      onCorrect: () => _correct(context),
    );
  }

  Future<void> _settle(BuildContext context, String value) async {
    if (value == 'rescheduled') {
      final target = await showDatePicker(
        context: context,
        initialDate: (task.scheduledFor ?? controller.currentTime()).add(
          const Duration(days: 1),
        ),
        firstDate: startOfDay(controller.currentTime()),
        lastDate: DateTime(controller.currentTime().year + 5),
      );
      if (target != null) await controller.rescheduleTaskInstance(task, target);
      return;
    }
    var reason = '';
    var resultNote = '';
    var resultLink = '';
    String? resultImagePath;
    if (value == 'failed') {
      final field = TextEditingController();
      String? template;
      final accepted = await showWorkbenchDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('记录失败原因'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String?>(
                    initialValue: template,
                    decoration: const InputDecoration(labelText: '常用原因模板'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('自定义')),
                      DropdownMenuItem(
                        value: '外部依赖未完成',
                        child: Text('外部依赖未完成'),
                      ),
                      DropdownMenuItem(value: '时间估计不足', child: Text('时间估计不足')),
                      DropdownMenuItem(
                        value: '设备或环境不可用',
                        child: Text('设备或环境不可用'),
                      ),
                      DropdownMenuItem(value: '任务定义不清', child: Text('任务定义不清')),
                    ],
                    onChanged: (value) {
                      setDialogState(() => template = value);
                      if (value != null) field.text = value;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: field,
                    autofocus: true,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: '原因（必填，可补充说明）',
                      hintText: '例如：仪器占用、外部依赖未完成',
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
                child: const Text('确认失败'),
              ),
            ],
          ),
        ),
      );
      reason = field.text.trim();
      field.dispose();
      if (accepted != true || reason.isEmpty) return;
    } else if (value == 'done') {
      final note = TextEditingController();
      final link = TextEditingController();
      final accepted = await showWorkbenchDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('记录完成结果'),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: note,
                    autofocus: true,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: '结果说明（可选）',
                      hintText: '记录产出、结论或保存位置',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: link,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: '结果链接（可选）',
                      hintText: 'https://',
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.image_outlined),
                    title: Text(
                      resultImagePath == null
                          ? '添加结果图片（可选）'
                          : File(resultImagePath!).uri.pathSegments.last,
                    ),
                    trailing: OutlinedButton(
                      onPressed: () async {
                        final picked = await FilePicker.pickFiles(
                          type: FileType.image,
                          allowMultiple: false,
                          withData: false,
                        );
                        final path = picked?.files.single.path;
                        if (path != null) {
                          setDialogState(() => resultImagePath = path);
                        }
                      },
                      child: Text(resultImagePath == null ? '选择' : '更换'),
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
                child: const Text('确认完成'),
              ),
            ],
          ),
        ),
      );
      resultNote = note.text.trim();
      resultLink = link.text.trim();
      note.dispose();
      link.dispose();
      if (accepted != true) return;
    }
    try {
      await controller.settleTask(
        task,
        status: value == 'done'
            ? WorkStatus.done
            : value == 'failed'
            ? WorkStatus.failed
            : WorkStatus.skipped,
        reason: reason,
        resultNote: resultNote,
        resultLink: resultLink,
      );
      if (resultImagePath != null) {
        try {
          await controller.attachmentService.importImage(
            owner: task,
            source: File(resultImagePath!),
          );
        } on FormatException catch (error) {
          if (context.mounted) {
            showWorkbenchSnackBar(
              context,
              SnackBar(content: Text('任务已完成，但图片未添加：${error.message}')),
            );
          }
        }
      }
    } on FormatException catch (error) {
      if (context.mounted) {
        showWorkbenchSnackBar(context, SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _correct(BuildContext context) async {
    final reason = TextEditingController();
    final detail = TextEditingController();
    var status = task.status == WorkStatus.rescheduled
        ? WorkStatus.done
        : task.status;
    final accepted = await showWorkbenchDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('留痕更正'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: '更正后的状态'),
                  items: const [
                    DropdownMenuItem(value: WorkStatus.done, child: Text('完成')),
                    DropdownMenuItem(
                      value: WorkStatus.failed,
                      child: Text('失败'),
                    ),
                    DropdownMenuItem(
                      value: WorkStatus.skipped,
                      child: Text('跳过'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => status = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reason,
                  autofocus: true,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '更正原因（必填）',
                    hintText: '说明为什么需要修正原结算事实',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: detail,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: status == WorkStatus.failed
                        ? '失败原因（不填则使用更正原因）'
                        : '结果说明（可选）',
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
              child: const Text('保存更正'),
            ),
          ],
        ),
      ),
    );
    final correctionReason = reason.text.trim();
    final correctionDetail = detail.text.trim();
    reason.dispose();
    detail.dispose();
    if (accepted != true || correctionReason.isEmpty) return;
    try {
      await controller.correctSettledTask(
        task: task,
        status: status,
        reason: correctionReason,
        failureReason: status == WorkStatus.failed ? correctionDetail : '',
        resultNote: status == WorkStatus.failed ? '' : correctionDetail,
      );
    } on FormatException catch (error) {
      if (context.mounted) {
        showWorkbenchSnackBar(context, SnackBar(content: Text(error.message)));
      }
    }
  }
}

class _ExpandableTodayTask extends StatefulWidget {
  const _ExpandableTodayTask({
    required this.task,
    required this.controller,
    required this.settled,
    required this.onSettle,
    required this.onCorrect,
  });

  final WorkspaceRecord task;
  final WorkbenchController controller;
  final bool settled;
  final ValueChanged<String> onSettle;
  final VoidCallback onCorrect;

  @override
  State<_ExpandableTodayTask> createState() => _ExpandableTodayTaskState();
}

class _ExpandableTodayTaskState extends State<_ExpandableTodayTask> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final summary = widget.controller.taskContextSummary(task);
    final theme = Theme.of(context);
    final (statusLabel, statusIcon, statusColor) = switch (task.status) {
      WorkStatus.done => (
        '已完成',
        Icons.check_circle_outline,
        context.tokens.reward,
      ),
      WorkStatus.failed => (
        '失败',
        Icons.cancel_outlined,
        theme.colorScheme.error,
      ),
      WorkStatus.skipped => (
        '已跳过',
        Icons.skip_next_outlined,
        theme.colorScheme.outline,
      ),
      WorkStatus.rescheduled => (
        '已改期',
        Icons.event_repeat_outlined,
        theme.colorScheme.tertiary,
      ),
      WorkStatus.doing => (
        '进行中',
        Icons.play_circle_outline,
        theme.colorScheme.primary,
      ),
      _ => ('待处理', Icons.radio_button_unchecked, theme.colorScheme.primary),
    };
    final metadata = [
      statusLabel,
      summary.recurring ? '周期任务' : '一次性任务',
      if (summary.primaryProjectTitle != null)
        summary.primaryProjectInTrash
            ? '${summary.primaryProjectTitle}（回收站）'
            : summary.primaryProjectTitle!,
      if (summary.additionalProjectCount > 0)
        '+${summary.additionalProjectCount} 个项目',
      if (summary.groupTitle != null)
        summary.groupMode == 'sequential'
            ? '${summary.groupTitle} · 链 '
                  '${summary.chainPosition}/${summary.chainLength}'
            : '${summary.groupTitle} · 任务群',
      if (summary.ctdpEnabled) 'CTDP',
      if (summary.scheduledFor != null)
        '计划 ${formatDateTime(summary.scheduledFor!)}',
      if (summary.dueAt != null) '截止 ${formatDateTime(summary.dueAt!)}',
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: widget.settled ? .08 : .025),
        border: Border(left: BorderSide(color: statusColor, width: 3)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => expanded = !expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(statusIcon, color: statusColor, size: 21),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          metadata.join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (widget.settled &&
                            (summary.failureReason?.isNotEmpty == true ||
                                summary.skipReason?.isNotEmpty == true ||
                                summary.rescheduledTo != null)) ...[
                          const SizedBox(height: 5),
                          Text(
                            summary.rescheduledTo != null
                                ? '改期至 ${formatDateTime(summary.rescheduledTo!)}'
                                : '原因：${summary.failureReason ?? summary.skipReason}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: statusColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!widget.settled)
                    IconButton(
                      onPressed: () => showRecordEditor(
                        context,
                        widget.controller,
                        kind: RecordKind.task,
                        record: task,
                      ),
                      tooltip: '编辑任务',
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  _taskMenu(),
                  Padding(
                    padding: const EdgeInsets.only(top: 8, right: 4),
                    child: Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      semanticLabel: expanded ? '收起详情' : '展开详情',
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 160),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: _TaskFactDetails(task: task, summary: summary),
          ),
        ],
      ),
    );
  }

  Widget _taskMenu() {
    if (widget.settled) {
      if (!widget.controller.todayClosed) return const SizedBox.shrink();
      return PopupMenuButton<String>(
        tooltip: '已结算任务操作',
        onSelected: (value) {
          if (value == 'correct') widget.onCorrect();
        },
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: 'correct',
            child: ListTile(
              leading: Icon(Icons.history_edu_outlined),
              title: Text('留痕更正'),
            ),
          ),
        ],
      );
    }
    return PopupMenuButton<String>(
      tooltip: '结算任务',
      onSelected: widget.onSettle,
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'done', child: Text('完成')),
        PopupMenuItem(value: 'failed', child: Text('失败')),
        PopupMenuItem(value: 'skipped', child: Text('跳过')),
        PopupMenuItem(value: 'rescheduled', child: Text('改期')),
      ],
    );
  }
}

class _TaskFactDetails extends StatelessWidget {
  const _TaskFactDetails({required this.task, required this.summary});

  final WorkspaceRecord task;
  final TaskContextSummary summary;

  @override
  Widget build(BuildContext context) {
    final definitionId = task.data['definitionId']?.toString();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(43, 2, 16, 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.tokens.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (definitionId != null) _detail('任务定义', definitionId),
          _detail(
            '关联项目',
            summary.projectTitles.isEmpty
                ? '未关联项目'
                : summary.projectTitles.join('、'),
          ),
          if (summary.groupTitle != null)
            _detail(
              '任务群',
              '${summary.groupTitle} · '
                  '${summary.groupMode == 'sequential' ? '顺序链' : '并行群'}',
            ),
          if (summary.previousTaskTitle != null)
            _detail('前置节点', summary.previousTaskTitle!),
          if (summary.nextTaskTitle != null)
            _detail('后续节点', summary.nextTaskTitle!),
          if (summary.lockReason != null) _detail('锁定原因', summary.lockReason!),
          if (summary.settledAt != null)
            _detail('结算时间', formatDateTime(summary.settledAt!)),
          if (summary.result?.isNotEmpty == true)
            _detail('结果说明', summary.result!),
          if (summary.failureReason?.isNotEmpty == true)
            _detail('失败原因', summary.failureReason!),
          if (summary.skipReason?.isNotEmpty == true)
            _detail('跳过原因', summary.skipReason!),
          if (summary.rescheduledTo != null)
            _detail('改期目标', formatDateTime(summary.rescheduledTo!)),
          if (summary.rescheduledFromId != null)
            _detail('来源实例', summary.rescheduledFromId!),
        ],
      ),
    );
  }

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text('$label：$value'),
  );
}

class _NextStepPanel extends StatelessWidget {
  const _NextStepPanel({
    required this.controller,
    required this.date,
    this.onOpenPlan,
    this.onOpenInbox,
    this.onOpenReview,
  });

  final WorkbenchController controller;
  final DateTime date;
  final VoidCallback? onOpenPlan;
  final VoidCallback? onOpenInbox;
  final VoidCallback? onOpenReview;

  _TodayNextState get state {
    if (controller.todayClosed) return _TodayNextState.closed;
    if (controller.todayStarted) {
      return controller.commitmentTasks.any((task) => !task.isDone)
          ? _TodayNextState.focus
          : _TodayNextState.closeDay;
    }
    if (controller.todayTasks.any((task) => !task.isDone)) {
      return _TodayNextState.selectPriorities;
    }
    if (controller.tasks.isEmpty) return _TodayNextState.createTask;
    if (controller.inboxRecords.isNotEmpty) {
      return _TodayNextState.organizeInbox;
    }
    return _TodayNextState.scheduleTasks;
  }

  @override
  Widget build(BuildContext context) {
    final nextTask = controller.commitmentTasks
        .where((task) => !task.isDone)
        .firstOrNull;
    final (title, message, label, icon) = switch (state) {
      _TodayNextState.createTask => (
        '从一件事开始',
        '写下今天真正需要推进的一项任务。',
        '添加今天的第一项任务',
        Icons.add_task_outlined,
      ),
      _TodayNextState.organizeInbox => (
        '先整理收集箱',
        '把已经记录的内容安排到今天或项目。',
        '去安排',
        Icons.inbox_outlined,
      ),
      _TodayNextState.scheduleTasks => (
        '安排今天要做的事',
        '从已有任务中选择今天要推进的内容。',
        '打开计划',
        Icons.calendar_view_week_outlined,
      ),
      _TodayNextState.selectPriorities => (
        '准备开始今天',
        '将按优先级和时间自动选出最多三项重点。',
        '开始今天',
        Icons.play_arrow,
      ),
      _TodayNextState.focus => (
        '接下来：${nextTask?.title ?? '继续今日重点'}',
        '只处理这一项，完成后再决定下一步。',
        '开始专注',
        Icons.timer_outlined,
      ),
      _TodayNextState.closeDay => (
        '今日重点已完成',
        '处理剩余事项，并为明天留下清晰起点。',
        '完成收尾',
        Icons.fact_check_outlined,
      ),
      _TodayNextState.closed => (
        '今天已收尾',
        '今天的记录已经保存。',
        '查看明日计划',
        Icons.event_available_outlined,
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: LogSurface(
        accent: Theme.of(context).colorScheme.primary,
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 5),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.tokens.mutedText,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () => _act(context, nextTask),
                    icon: Icon(icon),
                    label: Text(label),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _act(BuildContext context, WorkspaceRecord? nextTask) async {
    switch (state) {
      case _TodayNextState.createTask:
        await showQuickCapture(
          context,
          controller,
          initialKind: RecordKind.task,
          initialScheduledFor: date,
          initialStatus: WorkStatus.todo,
        );
        return;
      case _TodayNextState.organizeInbox:
        (onOpenInbox ?? onOpenPlan)?.call();
        return;
      case _TodayNextState.scheduleTasks:
        onOpenPlan?.call();
        return;
      case _TodayNextState.closed:
        onOpenPlan?.call();
        return;
      case _TodayNextState.selectPriorities:
        await _showStartTodayDialog(context, controller);
        return;
      case _TodayNextState.focus:
        if (nextTask != null) {
          await showFocusSession(context, controller, nextTask);
        }
        return;
      case _TodayNextState.closeDay:
        await _showCloseDialog(context, controller, onClosed: onOpenReview);
        return;
    }
  }
}

class _TodayTaskPreview extends StatelessWidget {
  const _TodayTaskPreview({required this.controller});

  final WorkbenchController controller;

  @override
  Widget build(BuildContext context) {
    final tasks = controller.suggestedTodayTasks;
    if (tasks.isEmpty) {
      return Text(
        '安排任务后，今日重点会显示在这里。',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: context.tokens.mutedText),
      );
    }
    return LogSurface(
      child: Column(
        children: [
          for (var index = 0; index < tasks.length; index++) ...[
            ListTile(
              leading: NumericText('${index + 1}'.padLeft(2, '0')),
              title: Text(
                tasks[index].title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (index < tasks.length - 1) const Divider(),
          ],
        ],
      ),
    );
  }
}

class _CommitmentLog extends StatelessWidget {
  const _CommitmentLog({required this.controller, required this.commitments});
  final WorkbenchController controller;
  final List<WorkspaceRecord> commitments;

  @override
  Widget build(BuildContext context) {
    return LogSurface(
      child: Column(
        children: [
          for (var index = 0; index < commitments.length; index++) ...[
            TaskRow(
              task: commitments[index],
              controller: controller,
              commitmentIndex: index,
              completionXp: controller.advancedFeaturesEnabled
                  ? commitments[index].id == controller.commitmentIds[index]
                        ? 20
                        : 10
                  : null,
              onStartFocus: () =>
                  showFocusSession(context, controller, commitments[index]),
            ),
            if (!commitments[index].isDone &&
                !controller.todayClosed &&
                !controller.canUpdateTodayCommitments)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 6),
                  child: TextButton(
                    onPressed: () =>
                        _showReplacementDialog(context, controller, index),
                    child: const Text('更换承诺'),
                  ),
                ),
              ),
            if (index < commitments.length - 1) const Divider(),
          ],
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.controller, required this.date});
  final WorkbenchController controller;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final blocks = controller.timeBlocksForDay(date);
    if (blocks.isEmpty) {
      return LogSurface(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.schedule, size: 20, color: context.tokens.mutedText),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '尚无时间块。',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.tokens.mutedText,
                ),
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(child: TickDivider(height: 12, dashed: true)),
          ],
        ),
      );
    }
    final conflicts = <String>{};
    for (var index = 1; index < blocks.length; index++) {
      final previous = blocks[index - 1];
      final previousEnd = previous.scheduledFor!.add(
        Duration(
          minutes: (previous.data['durationMinutes'] as num?)?.toInt() ?? 25,
        ),
      );
      if (blocks[index].scheduledFor!.isBefore(previousEnd)) {
        conflicts.add(previous.id);
        conflicts.add(blocks[index].id);
      }
    }
    final now = controller.currentTime();
    LogRailState stateFor(WorkspaceRecord block) {
      if (conflicts.contains(block.id)) return LogRailState.warning;
      if (block.isDone) return LogRailState.completed;
      final start = block.scheduledFor!;
      final end = start.add(
        Duration(
          minutes: (block.data['durationMinutes'] as num?)?.toInt() ?? 25,
        ),
      );
      if (!now.isBefore(start) && now.isBefore(end)) {
        return LogRailState.current;
      }
      return LogRailState.pending;
    }

    return LogSurface(
      padding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
      child: LogRail(
        entries: [
          for (final block in blocks)
            LogRailEntry(
              label: block.title,
              detail:
                  '${formatTime(block.scheduledFor!)} · ${block.data['durationMinutes'] ?? 25} 分钟${conflicts.contains(block.id) ? ' · 时间冲突' : ''}',
              state: stateFor(block),
              trailing: conflicts.contains(block.id)
                  ? Semantics(
                      button: true,
                      label: '调整时间安排：${block.title}',
                      child: TextButton(
                        onPressed: () => _showEditTimeBlockDialog(
                          context,
                          controller,
                          block,
                        ),
                        child: const Text('调整'),
                      ),
                    )
                  : IconButton(
                      onPressed: () => controller.moveToTrash(block),
                      tooltip: '删除时间块',
                      icon: const Icon(Icons.close),
                    ),
            ),
        ],
      ),
    );
  }
}

class _HabitLog extends StatelessWidget {
  const _HabitLog({required this.controller, required this.date});
  final WorkbenchController controller;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    if (controller.habits.isEmpty) {
      return Text(
        '尚未建立习惯。',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: context.tokens.mutedText),
      );
    }
    return LogSurface(
      child: Column(
        children: [
          for (var index = 0; index < controller.habits.length; index++) ...[
            Builder(
              builder: (context) {
                final habit = controller.habits[index];
                final log = controller.habitLogForDay(habit.id, date);
                final planned = controller.plannedHabitIds.contains(habit.id);
                return ListTile(
                  leading: Checkbox(
                    value: log?.status == WorkStatus.done,
                    onChanged: (_) => controller.logHabit(
                      habit,
                      date,
                      log?.status == WorkStatus.done
                          ? WorkStatus.todo
                          : WorkStatus.done,
                    ),
                  ),
                  title: Text(habit.title),
                  subtitle: Text(
                    controller.advancedFeaturesEnabled
                        ? planned
                              ? '今日计分习惯'
                              : '仅记录完成情况'
                        : '今天完成情况',
                  ),
                  trailing: planned && controller.advancedFeaturesEnabled
                      ? NumericText(
                          '+5 XP',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: context.tokens.reward),
                        )
                      : null,
                );
              },
            ),
            if (index < controller.habits.length - 1) const Divider(),
          ],
        ],
      ),
    );
  }
}

class _ClosePanel extends StatelessWidget {
  const _ClosePanel({required this.controller, this.onClosed});
  final WorkbenchController controller;
  final VoidCallback? onClosed;

  @override
  Widget build(BuildContext context) {
    final closed = controller.todayClosed;
    return LogSurface(
      padding: const EdgeInsets.all(14),
      accent: closed ? Theme.of(context).colorScheme.primary : null,
      child: Row(
        children: [
          Icon(
            closed ? Icons.check_circle_outline : Icons.fact_check_outlined,
            color: closed
                ? Theme.of(context).colorScheme.primary
                : context.tokens.mutedText,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  closed ? '今日已收尾' : '处理未完成承诺并预选明天',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  closed
                      ? '今天的记录已经保存。'
                      : controller.advancedFeaturesEnabled
                      ? '完成后获得 10 XP。'
                      : '处理未完成事项，并为明天留下起点。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.tokens.mutedText,
                  ),
                ),
              ],
            ),
          ),
          if (!closed)
            FilledButton(
              onPressed: controller.todayStarted
                  ? () => _showCloseDialog(
                      context,
                      controller,
                      onClosed: onClosed,
                    )
                  : null,
              child: const Text('完成收尾'),
            ),
        ],
      ),
    );
  }
}

class _CompactGrowth extends StatelessWidget {
  const _CompactGrowth({required this.controller});
  final WorkbenchController controller;
  @override
  Widget build(BuildContext context) {
    final snapshot = controller.growthSnapshot;
    return LogSurface(
      accent: context.tokens.reward,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          AnimatedNumber(
            value: snapshot.level,
            formatter: (v) => 'LV ${v.round().toString().padLeft(2, '0')}',
            duration: const Duration(milliseconds: 400),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: context.tokens.reward),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: snapshot.levelProgress),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              builder: (context, progress, child) => LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                borderRadius: BorderRadius.circular(3),
                color: context.tokens.reward,
                backgroundColor: context.tokens.rewardContainer.withValues(
                  alpha: 0.45,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          AnimatedNumber(
            value: snapshot.streak,
            formatter: (v) => '${v.round()} 日',
            duration: const Duration(milliseconds: 400),
          ),
        ],
      ),
    );
  }
}

Future<void> _showStartTodayDialog(
  BuildContext context,
  WorkbenchController controller,
) async {
  final selected = controller.suggestedTodayTasks;
  if (selected.isEmpty) return;
  await controller.startToday(commitments: selected, plannedHabits: const []);
  await WorkbenchFeedback.selection();
  if (!context.mounted) return;
  showWorkbenchSnackBar(
    context,
    SnackBar(
      duration: const Duration(seconds: 8),
      content: Text('已自动选择 ${selected.length} 项今日重点'),
      action: SnackBarAction(
        label: '撤销',
        onPressed: () async {
          final undone = await controller.undoStartToday();
          if (!undone || !context.mounted) return;
          showWorkbenchSnackBar(
            context,
            const SnackBar(content: Text('已撤销开始今天')),
          );
        },
      ),
    ),
  );
}

Future<void> _showAdjustTodayDialog(
  BuildContext context,
  WorkbenchController controller,
) async {
  final tasks = controller.todayTasks.where((task) => !task.isDone).toList();
  final selected = controller.commitmentIds.toSet();
  await showWorkbenchDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('调整今日重点'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              children: [
                const Text('选择 1–3 项未完成任务。开始专注后将保持当前重点。'),
                for (final task in tasks)
                  CheckboxListTile(
                    value: selected.contains(task.id),
                    title: Text(task.title),
                    onChanged: (value) => setState(() {
                      if (value == true && selected.length < 3) {
                        selected.add(task.id);
                      } else if (value == false) {
                        selected.remove(task.id);
                      }
                    }),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: selected.isEmpty || selected.length > 3
                ? null
                : () async {
                    await controller.updateTodayCommitments(
                      tasks
                          .where((task) => selected.contains(task.id))
                          .toList(),
                    );
                    if (context.mounted) Navigator.pop(context);
                  },
            child: const Text('保存重点'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showReplacementDialog(
  BuildContext context,
  WorkbenchController controller,
  int slot,
) async {
  final candidates = controller.todayTasks
      .where(
        (task) =>
            !task.isDone && !controller.activeCommitmentIds.contains(task.id),
      )
      .toList();
  if (candidates.isEmpty) {
    showWorkbenchSnackBar(
      context,
      const SnackBar(content: Text('没有可用于替换的未完成任务。')),
    );
    return;
  }
  var replacement = candidates.first;
  var reason = '优先级变化';
  await showWorkbenchDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text('调整承诺 ${slot + 1}'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<WorkspaceRecord>(
                initialValue: replacement,
                decoration: const InputDecoration(labelText: '替换为'),
                items: candidates
                    .map(
                      (task) => DropdownMenuItem(
                        value: task,
                        child: Text(
                          task.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => replacement = value);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: reason,
                decoration: const InputDecoration(labelText: '调整原因'),
                items: const ['优先级变化', '估时偏差', '外部阻塞', '临时中断', '任务已失效']
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => reason = value);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              await controller.replaceTodayCommitment(
                slot: slot,
                replacement: replacement,
                reason: reason,
              );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('记录调整'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showCloseDialog(
  BuildContext context,
  WorkbenchController controller, {
  VoidCallback? onClosed,
}) async {
  final overdueIds = controller.overdueTasks.map((task) => task.id).toSet();
  final logicalDay = controller.growthService.logicalDay(
    controller.currentTime(),
  );
  final incomplete = controller.tasks.where((task) {
    return !WorkStatus.terminal.contains(task.status) &&
        (isSameDay(task.scheduledFor, logicalDay) ||
            overdueIds.contains(task.id));
  }).toList();
  final reasons = <String, String>{};
  final dispositions = <String, String>{};
  final rescheduleDates = <String, DateTime>{};
  final reflection = TextEditingController();
  await showWorkbenchDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('完成每日收尾'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (incomplete.isNotEmpty)
                  const SectionHeading(title: '未结算任务', scale: '必选'),
                for (final task in incomplete) ...[
                  Text(
                    task.title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: dispositions[task.id],
                    decoration: const InputDecoration(labelText: '结算方式'),
                    items: const [
                      DropdownMenuItem(value: 'failed', child: Text('失败')),
                      DropdownMenuItem(value: 'skipped', child: Text('跳过')),
                      DropdownMenuItem(value: 'rescheduled', child: Text('改期')),
                      DropdownMenuItem(value: 'inbox', child: Text('退回收集箱')),
                    ],
                    onChanged: (value) {
                      setState(() => dispositions[task.id] = value ?? '');
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: reasons[task.id],
                    decoration: InputDecoration(
                      labelText: dispositions[task.id] == 'failed'
                          ? '原因（必填）'
                          : '原因或说明（可选）',
                      hintText: '例如：外部阻塞、估时偏差',
                    ),
                    onChanged: (value) => reasons[task.id] = value,
                  ),
                  if (dispositions[task.id] == 'rescheduled') ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final selected = await showDatePicker(
                          context: context,
                          initialDate: logicalDay.add(const Duration(days: 1)),
                          firstDate: logicalDay.add(const Duration(days: 1)),
                          lastDate: DateTime(2100),
                        );
                        if (selected != null) {
                          setState(() => rescheduleDates[task.id] = selected);
                        }
                      },
                      icon: const Icon(Icons.event_repeat_outlined),
                      label: Text(
                        rescheduleDates[task.id] == null
                            ? '选择新日期'
                            : formatShortDate(rescheduleDates[task.id]!),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 10),
                TextField(
                  controller: reflection,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: '日回顾草稿（可选）',
                    hintText: '收尾后会自动转到日回顾继续编辑',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed:
                incomplete.any((task) {
                  final disposition = dispositions[task.id];
                  return disposition == null ||
                      (disposition == 'rescheduled' &&
                          rescheduleDates[task.id] == null);
                })
                ? null
                : () async {
                    await controller.closeToday(
                      reasons: reasons,
                      dispositions: dispositions,
                      rescheduleDates: rescheduleDates,
                      reflection: reflection.text,
                    );
                    await WorkbenchFeedback.selection();
                    if (context.mounted) Navigator.pop(context);
                    onClosed?.call();
                  },
            child: Text(
              controller.advancedFeaturesEnabled ? '确认收尾 +10 XP' : '确认收尾',
            ),
          ),
        ],
      ),
    ),
  );
  reflection.dispose();
}

Future<void> _showTimeBlockDialog(
  BuildContext context,
  WorkbenchController controller,
  WorkspaceRecord task,
) async {
  var selectedTask = task;
  final now = controller.currentTime();
  var start = DateTime(
    now.year,
    now.month,
    now.day,
    now.hour,
    ((now.minute + 9) ~/ 5) * 5,
  );
  var minutes = 25;
  await showWorkbenchDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('安排时间块'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<WorkspaceRecord>(
                initialValue: selectedTask,
                decoration: const InputDecoration(labelText: '任务'),
                items: controller.todayTasks
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(
                          value.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => selectedTask = value);
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule),
                title: NumericText(formatTime(start)),
                subtitle: const Text('开始时间 · 5 分钟吸附'),
                onTap: () async {
                  final value = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(start),
                  );
                  if (value != null) {
                    setState(
                      () => start = DateTime(
                        start.year,
                        start.month,
                        start.day,
                        value.hour,
                        (value.minute / 5).round() * 5,
                      ),
                    );
                  }
                },
              ),
              DropdownButtonFormField<int>(
                initialValue: minutes,
                decoration: const InputDecoration(labelText: '时长'),
                items: const [15, 25, 45, 50, 60, 90]
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text('$value 分钟'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => minutes = value);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              await controller.createTimeBlock(
                task: selectedTask,
                start: start,
                minutes: minutes,
              );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('安排'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showEditTimeBlockDialog(
  BuildContext context,
  WorkbenchController controller,
  WorkspaceRecord block,
) async {
  var start = block.scheduledFor ?? controller.currentTime();
  const durations = [15, 25, 45, 50, 60, 90];
  final storedMinutes = (block.data['durationMinutes'] as num?)?.toInt() ?? 25;
  var minutes = durations.contains(storedMinutes) ? storedMinutes : 25;
  await showWorkbenchDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('调整时间安排'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(block.title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_outlined),
                title: NumericText(formatTime(start)),
                subtitle: const Text('开始时间 · 5 分钟吸附'),
                onTap: () async {
                  final value = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(start),
                  );
                  if (value != null) {
                    setState(
                      () => start = DateTime(
                        start.year,
                        start.month,
                        start.day,
                        value.hour,
                        (value.minute / 5).round() * 5,
                      ),
                    );
                  }
                },
              ),
              DropdownButtonFormField<int>(
                initialValue: minutes,
                decoration: const InputDecoration(labelText: '时长'),
                items: durations
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text('$value 分钟'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => minutes = value);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              await controller.updateTimeBlock(
                block: block,
                start: start,
                minutes: minutes,
              );
              if (!context.mounted) return;
              Navigator.pop(context);
              showWorkbenchSnackBar(
                context,
                const SnackBar(content: Text('时间安排已更新')),
              );
            },
            child: const Text('更新安排'),
          ),
        ],
      ),
    ),
  );
}
