import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/models/workspace_record.dart';
import '../../core/models/workspace_models_v3.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../state/workbench_controller.dart';
import '../platform_feedback.dart';
import '../widgets/celebration.dart';
import '../widgets/common.dart';
import '../widgets/quick_capture_sheet.dart';
import '../widgets/record_editor_dialog.dart';
import '../widgets/solid_panel.dart';
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
    this.onOpenHabits,
  });

  final WorkbenchController controller;
  final DateTime? date;
  final bool showHeader;
  final VoidCallback? onOpenPlan;
  final VoidCallback? onOpenInbox;
  final VoidCallback? onOpenReview;
  final VoidCallback? onOpenHabits;

  @override
  Widget build(BuildContext context) {
    final date = this.date ?? controller.currentTime();
    return Column(
      children: [
        if (showHeader)
          PageHeader(
            title: '今日',
            // 方案 C 的页头把日期放在标题**之上**，移动端 AppBar 即此排布
            // （规格 §20.4）。桌面原先把同一段日期放在标题**下方**，
            // 同一天在两个端上是两种读法，故改为 kicker。
            kicker: formatFullDate(date),
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
          _TimeRuler(controller: controller),
        Expanded(
          child: _TodayContent(
            controller: controller,
            date: date,
            onOpenPlan: onOpenPlan,
            onOpenInbox: onOpenInbox,
            onOpenReview: onOpenReview,
            onOpenHabits: onOpenHabits,
          ),
        ),
      ],
    );
  }
}

class _TimeRuler extends StatefulWidget {
  const _TimeRuler({required this.controller});

  final WorkbenchController controller;

  @override
  State<_TimeRuler> createState() => _TimeRulerState();
}

class _TimeRulerState extends State<_TimeRuler> with WidgetsBindingObserver {
  late DateTime now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    now = widget.controller.currentTime().toLocal();
    WidgetsBinding.instance.addObserver(this);
    _scheduleTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() => now = widget.controller.currentTime().toLocal());
      _scheduleTimer();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _timer?.cancel();
    }
  }

  void _scheduleTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => now = widget.controller.currentTime().toLocal());
    });
  }

  double get _progress {
    final start = DateTime(now.year, now.month, now.day);
    return (now.difference(start).inMicroseconds /
            const Duration(days: 1).inMicroseconds)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labels = List<String>.generate(
      24,
      (index) => '${index.toString().padLeft(2, '0')}:00',
    );
    return SizedBox(
      height: 38,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.tokens.divider)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final progress = _progress.clamp(0.0, 1.0).toDouble();
            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _TimeRulerPainter(
                      color: context.tokens.divider,
                      pastColor: context.tokens.mutedText,
                      currentColor: scheme.primary,
                      progress: progress,
                    ),
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
                          children: [
                            for (var index = 0; index < labels.length; index++)
                              Expanded(
                                child: Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      labels[index],
                                      key: ValueKey('time-ruler-hour-$index'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                    ),
                                  ),
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
                Positioned(
                  left: 54 + (constraints.maxWidth - 108) * progress,
                  top: 5,
                  bottom: 2,
                  child: Semantics(
                    key: const ValueKey('time-ruler-marker'),
                    label:
                        '当前时间 ${formatTime(now)}，自然日进度 ${(100 * progress).round()}%',
                    child: Container(width: 2, color: scheme.primary),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TimeRulerPainter extends CustomPainter {
  const _TimeRulerPainter({
    required this.color,
    required this.pastColor,
    required this.currentColor,
    required this.progress,
  });

  final Color color;
  final Color pastColor;
  final Color currentColor;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final tickPaint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..strokeWidth = 1;
    const left = 54.0;
    final right = size.width - 54;
    final segmentWidth = (right - left) / 24;
    for (var index = 0; index < 24; index++) {
      final segmentStart = left + segmentWidth * index;
      final segmentEnd = segmentStart + segmentWidth;
      final segmentProgress = progress * 24 - index;
      final fillColor = segmentProgress >= 1
          ? pastColor.withValues(alpha: 0.22)
          : segmentProgress > 0
          ? currentColor.withValues(alpha: 0.14)
          : null;
      if (fillColor != null) {
        canvas.drawRect(
          Rect.fromLTRB(segmentStart + 0.5, 0, segmentEnd - 0.5, size.height),
          Paint()..color = fillColor,
        );
      }
      final x = segmentStart;
      canvas.drawLine(
        Offset(x, size.height - 10),
        Offset(x, size.height - (index % 2 == 0 ? 2 : 5)),
        tickPaint,
      );
    }
    canvas.drawLine(
      Offset(right, size.height - 10),
      Offset(right, size.height - 2),
      tickPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TimeRulerPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.pastColor != pastColor ||
      oldDelegate.currentColor != currentColor ||
      oldDelegate.progress != progress;
}

class _TodayContent extends StatelessWidget {
  const _TodayContent({
    required this.controller,
    required this.date,
    this.onOpenPlan,
    this.onOpenInbox,
    this.onOpenReview,
    this.onOpenHabits,
  });

  final WorkbenchController controller;
  final DateTime date;
  final VoidCallback? onOpenPlan;
  final VoidCallback? onOpenInbox;
  final VoidCallback? onOpenReview;
  final VoidCallback? onOpenHabits;

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
      overdue: true,
    );
    final todaySection = _TodayTaskSection(
      title: '今日',
      tasks: today,
      controller: controller,
      emptyMessage: '今天还没有待处理任务。',
      action: '全部',
      onAction: onOpenPlan,
      countLabel: '剩 ${today.length} 项',
    );
    final settledSection = _TodayTaskSection(
      title: '已结算',
      tasks: settled,
      controller: controller,
      emptyMessage: '今天还没有已结算任务。',
      settled: true,
    );
    // 方案 C 的手机页只画了「今日重点 → 习惯打卡」两段。
    // 承诺本身就是今日任务的子集，若再把全量任务列一遍，
    // 同一个标题会在同屏出现两次。故移动端「今日」只列
    // 未被聚光的那部分；全为承诺时整段省略，页面顺序即与源稿一致。
    final spotlightIds = controller.commitmentIds.toSet();
    final todayRest = today
        .where((task) => !spotlightIds.contains(task.id))
        .toList();
    final todayRestSection = _TodayTaskSection(
      title: '今日',
      tasks: todayRest,
      controller: controller,
      emptyMessage: '今天还没有待处理任务。',
      action: '全部',
      onAction: onOpenPlan,
      countLabel: '剩 ${todayRest.length} 项',
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
    // 移动端把「计划习惯」提为顶层分区（方案 C 的「习惯打卡」），
    // 故「今日详情」里不再重复；桌面仍留在折叠区，信息架构未变。
    final compactDetails = <Widget>[
      const SectionHeading(title: '每日收尾'),
      _ClosePanel(controller: controller, onClosed: onOpenReview),
      if (controller.advancedFeaturesEnabled) ...[
        const SectionHeading(title: '成长记录'),
        _CompactGrowth(controller: controller),
      ],
    ];
    final habitCount = controller.habits.length;
    final habitDone = controller.habits
        .where(
          (habit) =>
              controller.habitLogForDay(habit.id, date)?.status ==
              WorkStatus.done,
        )
        .length;
    final habitSection = <Widget>[
      SectionHeading(
        title: '习惯打卡',
        scale: '已 $habitDone/$habitCount',
        action: '全部',
        onAction: onOpenHabits,
      ),
      _HabitLog(controller: controller, date: date),
    ];
    final commitmentSection = <Widget>[
      SectionHeading(
        title: '今日重点',
        scale: controller.todayStarted ? '剩 ${commitments.length} 项' : '最多 3 项',
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
            // 内容列限宽并居中。
            //
            // 实测 1536 视口下主工作区约 847px，而任务卡的可见内容只需
            // 约 300px —— 不限宽时 65% 的卡面是空白，扫读要横穿整行。
            // 规范 §8 要求主工作区「单列内容」有宽度上限：长文阅读列取
            // 620（按中文 25–40 字/行推导），卡片列表取 720
            // （见 AppSpacing.contentMax）。
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppSpacing.contentMax,
                  ),
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 72),
                    children: [
                      // 概览卡是方案 C 的视觉锚点：移动端在顶层，桌面同样
                      // 置顶。少了它，同一天在两个端上是两种观感。
                      _TodayOverviewCard(
                        remaining: today.length,
                        completed: settled.where((task) => task.isDone).length,
                        focus: controller.todayFocusDuration,
                      ),
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

    // ── 移动端（方案 C 手机 2 的编排）──
    // 概览 → 接下来 → 今日 → 今日重点 → 习惯打卡 → 其余。
    // 与桌面的差别不只是宽度：桌面是两栏分区，移动端是单列连续滚动，
    // 概览与习惯必须落在顶层，否则整页没有视觉锚点。
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pageCompact,
        AppSpacing.xs,
        AppSpacing.pageCompact,
        AppSpacing.bottomNavClearance + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        _TodayOverviewCard(
          remaining: today.length,
          completed: settled.where((task) => task.isDone).length,
          focus: controller.todayFocusDuration,
        ),
        nextStep,
        // 空白天仍保留「今日」分区（给出「今天还没有待处理任务」的明示），
        // 只有当内容**整体搬进「今日重点」**时才省略整段。
        if (todayRest.isNotEmpty || today.isEmpty) todayRestSection,
        ...commitmentSection,
        ...habitSection,
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
              children: compactDetails,
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
    this.settled = false,
    this.overdue = false,
    this.action,
    this.onAction,
    this.countLabel,
  });

  final String title;
  final List<WorkspaceRecord> tasks;
  final WorkbenchController controller;
  final String emptyMessage;
  final bool settled;

  /// 逾期分区：卡片上补一枚「已逾期」标签。
  ///
  /// 这项语义原先由面板左侧 3px 红条承担；改成「一卡一项」后色条消失，
  /// 语义必须改由标签承载，否则逾期与普通待办在视觉上无从区分。
  final bool overdue;

  /// 分区标题右侧的文字链接（方案 C 的「全部 →」）。
  final String? action;
  final VoidCallback? onAction;

  /// 计数文案。方案 C 的修辞是「剩 N 项」，不是中性的「N 项」。
  final String? countLabel;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(
          title: title,
          scale: countLabel ?? '${tasks.length} 项',
          action: action,
          onAction: onAction,
        ),
        if (tasks.isEmpty)
          Text(
            emptyMessage,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: context.tokens.mutedText),
          )
        else
          // 方案 C：一项一张独立卡。原先「一张面板 + 行内分隔线 + 左侧
          // 3px 状态竖条」的形态在方案 C 里没有任何对应物。
          Column(
            children: [
              for (var index = 0; index < tasks.length; index++) ...[
                _TodayStatusTask(
                  task: tasks[index],
                  controller: controller,
                  settled: settled,
                  overdue: overdue,
                ),
                if (index < tasks.length - 1)
                  SizedBox(height: compact ? 7 : AppSpacing.sm),
              ],
            ],
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
    this.overdue = false,
    this.extraActions,
  });

  final WorkspaceRecord task;
  final WorkbenchController controller;
  final bool settled;
  final bool overdue;

  /// 承诺卡在展开区追加的专属动作。
  ///
  /// 承诺与今日任务共用同一种卡（方案 C 只有一种任务卡），
  /// 差异仅在展开区动作上，故用注入而不复制卡片。
  final Widget? extraActions;

  @override
  Widget build(BuildContext context) {
    return _ExpandableTodayTask(
      task: task,
      controller: controller,
      settled: settled,
      overdue: overdue,
      extraActions: extraActions,
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
                  ExternalField(
                    label: '常用原因模板',
                    child: DropdownButtonFormField<String?>(
                      initialValue: template,
                      decoration: const InputDecoration(),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('自定义')),
                        DropdownMenuItem(
                          value: '外部依赖未完成',
                          child: Text('外部依赖未完成'),
                        ),
                        DropdownMenuItem(
                          value: '时间估计不足',
                          child: Text('时间估计不足'),
                        ),
                        DropdownMenuItem(
                          value: '设备或环境不可用',
                          child: Text('设备或环境不可用'),
                        ),
                        DropdownMenuItem(
                          value: '任务定义不清',
                          child: Text('任务定义不清'),
                        ),
                      ],
                      onChanged: (value) {
                        setDialogState(() => template = value);
                        if (value != null) field.text = value;
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  ExternalField(
                    label: '原因（必填，可补充说明）',
                    child: TextField(
                      controller: field,
                      autofocus: true,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: '例如：仪器占用、外部依赖未完成',
                      ),
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
                  ExternalField(
                    label: '结果说明（可选）',
                    child: TextField(
                      controller: note,
                      autofocus: true,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: '记录产出、结论或保存位置',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ExternalField(
                    label: '结果链接（可选）',
                    child: TextField(
                      controller: link,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(hintText: 'https://'),
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
                ExternalField(
                  label: '更正后的状态',
                  child: DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(),
                    items: const [
                      DropdownMenuItem(
                        value: WorkStatus.done,
                        child: Text('完成'),
                      ),
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
                ),
                const SizedBox(height: 12),
                ExternalField(
                  label: '更正原因（必填）',
                  child: TextField(
                    controller: reason,
                    autofocus: true,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: '说明为什么需要修正原结算事实',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ExternalField(
                  label: status == WorkStatus.failed
                      ? '失败原因（不填则使用更正原因）'
                      : '结果说明（可选）',
                  child: TextField(
                    controller: detail,
                    maxLines: 3,
                    decoration: InputDecoration(),
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
    this.overdue = false,
    this.extraActions,
  });

  final WorkspaceRecord task;
  final WorkbenchController controller;
  final bool settled;
  final bool overdue;
  final ValueChanged<String> onSettle;
  final VoidCallback onCorrect;

  /// 展开区追加的专属动作（仅承诺卡使用）。
  final Widget? extraActions;

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
    final tokens = context.tokens;
    final scheme = theme.colorScheme;
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    final (statusLabel, statusIcon) = switch (task.status) {
      WorkStatus.done => ('已完成', Icons.check_circle_outline),
      WorkStatus.failed => ('失败', Icons.cancel_outlined),
      WorkStatus.skipped => ('已跳过', Icons.skip_next_outlined),
      WorkStatus.rescheduled => ('已改期', Icons.event_repeat_outlined),
      WorkStatus.doing => ('进行中', Icons.play_circle_outline),
      _ => ('待处理', Icons.radio_button_unchecked),
    };
    // 状态标签取「容器 / 容器上文字」成对令牌——把饱和实色直接铺成底，
    // 一张卡上多枚标签会互相抢注意力。
    final (statusContainer, statusOnContainer) = switch (task.status) {
      WorkStatus.done => (tokens.rewardContainer, tokens.rewardOnContainer),
      WorkStatus.failed => (tokens.signalContainer, tokens.signalOnContainer),
      WorkStatus.rescheduled => (tokens.infoContainer, tokens.infoOnContainer),
      WorkStatus.doing => (scheme.primaryContainer, scheme.onPrimaryContainer),
      _ => (tokens.subtle, tokens.mutedText),
    };
    // 方案 C：元信息改由 pill 标签承载。
    //
    // 原先是一行拼接文本（`待处理 · 一次性任务 · 计划 2026-08-07 09:00 · 截止 …`），
    // 窄卡上会折成两行且没有层级；标签天然分块、可着色、可扫读。
    // 不含信息量的项（「待处理」「一次性任务」）不占位——满屏标签等于没有标签。
    final pills = <Widget>[
      if (widget.overdue)
        StatusPill(
          label: '已逾期',
          color: tokens.signalContainer,
          foreground: tokens.signalOnContainer,
          dense: compact,
        ),
      if (!widget.settled && statusLabel != '待处理')
        StatusPill(
          label: statusLabel,
          icon: statusIcon,
          color: statusContainer,
          foreground: statusOnContainer,
          dense: compact,
        ),
      if (widget.controller.commitmentIds.contains(task.id))
        StatusPill(
          label: '今日必达',
          color: tokens.oliveContainer,
          foreground: tokens.oliveOnContainer,
          dense: compact,
        ),
      if (summary.primaryProjectTitle != null)
        StatusPill(
          label: summary.primaryProjectInTrash
              ? '${summary.primaryProjectTitle}（回收站）'
              : summary.primaryProjectTitle!,
          dense: compact,
        ),
      if (summary.recurring)
        StatusPill(
          label: '周期',
          color: tokens.subtle,
          foreground: tokens.mutedText,
          dense: compact,
        ),
      if (summary.dueAt != null)
        StatusPill(
          label: '截止 ${formatDateTime(summary.dueAt!)}',
          color: tokens.rewardContainer,
          foreground: tokens.rewardOnContainer,
          dense: compact,
        )
      else if (summary.scheduledFor != null)
        StatusPill(
          label: '计划 ${formatDateTime(summary.scheduledFor!)}',
          color: tokens.subtle,
          foreground: tokens.mutedText,
          dense: compact,
        ),
      if (widget.settled &&
          (summary.failureReason?.isNotEmpty == true ||
              summary.skipReason?.isNotEmpty == true ||
              summary.rescheduledTo != null))
        StatusPill(
          label: summary.rescheduledTo != null
              ? '改期至 ${formatDateTime(summary.rescheduledTo!)}'
              : '原因：${summary.failureReason ?? summary.skipReason}',
          color: tokens.subtle,
          foreground: tokens.mutedText,
          dense: compact,
        ),
    ];
    final done = task.isDone;
    // 方案 C：一项一张独立白卡（圆角 16、1px 中性描边）。
    // 旧的「一张面板内多行 + 每行左侧 3px 状态色竖条 + 行间 Divider」
    // 在方案 C 里没有任何对应物。
    return Material(
      color: tokens.panel,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: tokens.panelBorder),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => expanded = !expanded),
            // 桌面是鼠标 / 键盘优先的场景，悬停与聚焦必须有可见反馈。
            // 取值与侧栏导航项一致（6% / 10% 主色），全应用同一种悬停语言。
            hoverColor: scheme.primary.withValues(alpha: 0.06),
            focusColor: scheme.primary.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TaskCheckbox(done: done),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            height: 1.45,
                            color: done ? tokens.inkFaint : null,
                            decoration: done
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        if (pills.isNotEmpty) ...[
                          const SizedBox(height: 7),
                          Wrap(spacing: 6, runSpacing: 6, children: pills),
                        ],
                      ],
                    ),
                  ),
                  // 展开指示只在桌面出现。方案 C 的手机卡没有行内指示（整卡可点），
                  // 但桌面卡宽约为手机的 1.8 倍，去掉后右侧留下大片空白，
                  // 也失去「这一行可以展开」的可见线索。
                  if (!compact) ...[
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Icon(
                        expanded ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                        color: tokens.inkFaint,
                        semanticLabel: expanded ? '收起详情' : '展开详情',
                      ),
                    ),
                  ],
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
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TaskFactDetails(task: task, summary: summary),
                if (widget.extraActions != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 2),
                    child: widget.extraActions!,
                  ),
                // 折叠时卡片上不再悬挂图标按钮（方案 C 的任务卡是「一眼扫完」）；
                // 编辑与结算移进展开区，功能一项不减。
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                  child: Row(
                    children: [
                      if (!widget.settled)
                        TextButton.icon(
                          onPressed: () => showRecordEditor(
                            context,
                            widget.controller,
                            kind: RecordKind.task,
                            record: task,
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('编辑'),
                        ),
                      _taskMenu(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 结算 / 更正菜单。
  ///
  /// 在展开区里渲染成文字按钮而非默认的 ⋮ 图标：图标脱离列表上下文后，
  /// 点开前不知道是什么，文字省掉一次试错成本。
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
        child: _taskMenuLabel(context, '留痕更正'),
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
      child: _taskMenuLabel(context, '结算'),
    );
  }

  Widget _taskMenuLabel(BuildContext context, String text) => Padding(
    // 视觉高约 36，上下留白把触控区撑到 ≥48dp。
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        // 显式 TextStyle 若不给 fontFamily，就退回引擎默认字体：真机靠系统
        // 回退兜住 CJK，golden 环境没有系统字体则渲染成豆腐块（见 §20.6）。
        fontFamily: AppFonts.body,
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
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
      // 缩进与卡片内边距对齐（14），不再按旧行的「12 + 图标 21 + 10」推算。
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
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
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: SolidPanel(
        // 方案 C 的卡片档是 16，不是工作面档 20。
        radius: AppRadius.card,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.tokens.mutedText,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    // 方案 C 的主操作是 52 高、圆角 16 的通栏按钮。
                    // 移动端对齐这一档；桌面保持默认高度，避免纵向臃肿。
                    width: compact ? double.infinity : null,
                    height: compact ? 52 : null,
                    child: FilledButton.icon(
                      onPressed: () => _act(context, nextTask),
                      style: compact
                          ? FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.card,
                                ),
                              ),
                            )
                          : null,
                      icon: Icon(icon),
                      label: Text(label),
                    ),
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
      return Padding(
        padding: const EdgeInsets.fromLTRB(2, 10, 2, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SurfaceIcon(Icons.route_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '今日航迹尚未开始',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '安排任务后，今日重点会显示在这里。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.tokens.mutedText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    // 方案 C 只有一种列表语言：一项一张独立白卡。
    // 旧形态是「一张面板装多行 + 行间 Divider」——方案 C 通篇不使用，
    // 而它正是「今日重点」在开始今天之前的默认外观，桌面与移动端都会看到。
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    final tokens = context.tokens;
    return Column(
      children: [
        for (var index = 0; index < tasks.length; index++) ...[
          Material(
            color: tokens.panel,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.card),
              side: BorderSide(color: tokens.panelBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  NumericText(
                    '${index + 1}'.padLeft(2, '0'),
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: tokens.mutedText),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tasks[index].title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (index < tasks.length - 1)
            SizedBox(height: compact ? 7 : AppSpacing.sm),
        ],
      ],
    );
  }
}

class _CommitmentLog extends StatelessWidget {
  const _CommitmentLog({required this.controller, required this.commitments});
  final WorkbenchController controller;
  final List<WorkspaceRecord> commitments;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    // 方案 C 只有一种任务卡：白底、圆角 16、1px 描边、
    // 圆角方复选框 + pill 标签。承诺卡不再走 TaskRow——
    // 左侧索引竖条、内联五行事实、⋯ 菜单是桌面
    // 「一张面板装多行」的语言，正是方案 C 通篇不使用的形态。
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < commitments.length; index++) ...[
          _TodayStatusTask(
            task: commitments[index],
            controller: controller,
            settled: false,
            extraActions: _commitmentActions(context, index),
          ),
          if (index < commitments.length - 1)
            SizedBox(height: compact ? 7 : AppSpacing.sm),
        ],
      ],
    );
  }

  /// 承诺卡的展开区动作：完成奖励、开始专注、更换承诺。
  Widget _commitmentActions(BuildContext context, int index) {
    final task = commitments[index];
    final tokens = context.tokens;
    final xp = controller.advancedFeaturesEnabled && !task.isDone
        ? (index < controller.commitmentIds.length &&
                  task.id == controller.commitmentIds[index]
              ? 20
              : 10)
        : null;
    final canReplace =
        !task.isDone &&
        !controller.todayClosed &&
        !controller.canUpdateTodayCommitments;
    if (xp == null && !canReplace && task.isDone) {
      return const SizedBox.shrink();
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: [
        if (xp != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '完成 +$xp XP',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                fontFamily: AppFonts.body,
                color: tokens.reward,
              ),
            ),
          ),
        if (!task.isDone)
          TextButton.icon(
            onPressed: () => showFocusSession(context, controller, task),
            icon: const Icon(Icons.play_arrow, size: 16),
            // 刻意不叫「开始专注」：今日页的「下一步行动」必须唯一，
            // 「开始专注」是 `_NextStepPanel` 的主按钮文案，
            // 承诺卡再挂一个同文案会让「唯一行动」的守卫失效。
            label: const Text('专注此项'),
          ),
        if (canReplace)
          TextButton(
            onPressed: () => _showReplacementDialog(context, controller, index),
            child: const Text('更换承诺'),
          ),
      ],
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
    VineRailState stateFor(WorkspaceRecord block) {
      if (conflicts.contains(block.id)) return VineRailState.warning;
      if (block.isDone) return VineRailState.completed;
      final start = block.scheduledFor!;
      final end = start.add(
        Duration(
          minutes: (block.data['durationMinutes'] as num?)?.toInt() ?? 25,
        ),
      );
      if (!now.isBefore(start) && now.isBefore(end)) {
        return VineRailState.current;
      }
      return VineRailState.pending;
    }

    return LogSurface(
      padding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
      child: VineRail(
        entries: [
          for (final block in blocks)
            VineRailEntry(
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
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    return Column(
      children: [
        for (var index = 0; index < controller.habits.length; index++) ...[
          _HabitRowCard(
            controller: controller,
            habit: controller.habits[index],
            date: date,
          ),
          if (index < controller.habits.length - 1)
            SizedBox(height: compact ? 7 : AppSpacing.sm),
        ],
      ],
    );
  }
}

/// 习惯行卡（方案 C 规格）。
///
/// 与旧实现的差别：独立白卡（不再是面板里的 ListTile）、左侧 **17×17 方点**
/// （不是圆形 Checkbox）、右侧「连续 N 天」为主色强调文字。
///
/// 打卡点用方形是刻意的：方案 C 里「任务复选框（20×20/圆角 7）」与
/// 「习惯方点（17×17/圆角 6）」是两种形状，**形状本身就承担区分**，
/// 不必再靠颜色——与项目既有的「颜色不是唯一线索」纪律一致。
class _HabitRowCard extends StatelessWidget {
  const _HabitRowCard({
    required this.controller,
    required this.habit,
    required this.date,
  });

  final WorkbenchController controller;
  final WorkspaceRecord habit;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final scheme = theme.colorScheme;
    final log = controller.habitLogForDay(habit.id, date);
    final done = log?.status == WorkStatus.done;
    final planned = controller.plannedHabitIds.contains(habit.id);
    final streak = controller.habitStreak(habit.id);
    return Material(
      color: tokens.panel,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: tokens.panelBorder),
      ),
      child: InkWell(
        onTap: () => controller.logHabit(
          habit,
          date,
          done ? WorkStatus.todo : WorkStatus.done,
        ),
        hoverColor: scheme.primary.withValues(alpha: 0.06),
        focusColor: scheme.primary.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              _HabitDot(done: done),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: done ? tokens.mutedText : scheme.onSurface,
                      ),
                    ),
                    // 「计分 / 仅记录」只在开启进阶功能时占位：
                    // 默认配置下习惯行与方案 C 一样是单行。
                    if (controller.advancedFeaturesEnabled)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          planned ? '今日计分习惯' : '仅记录完成情况',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 11,
                            color: tokens.inkFaint,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (planned && controller.advancedFeaturesEnabled)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: NumericText(
                    '+5 XP',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: tokens.reward,
                    ),
                  ),
                ),
              if (streak > 1)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    '连续 $streak 天',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: scheme.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
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
    // 去掉左侧 3px 状态竖条（方案 C 不使用该形状）。收尾状态已由
    // 图标（check_circle）+ 文案（今日已收尾）双重表达，色条是第三种冗余；
    // 而且它会把内容左内边距挤歪 3px，与相邻面板不对齐。
    return LogSurface(
      padding: const EdgeInsets.all(14),
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
    // 同收尾面板：装饰性色条与「实色面板 + 中性边框」冲突，
    // 而 reward 色已由 LV 数字与进度条承担，不需要第三种表达。
    return LogSurface(
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
              ExternalField(
                label: '替换为',
                child: DropdownButtonFormField<WorkspaceRecord>(
                  initialValue: replacement,
                  decoration: const InputDecoration(),
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
              ),
              const SizedBox(height: 12),
              ExternalField(
                label: '调整原因',
                child: DropdownButtonFormField<String>(
                  initialValue: reason,
                  decoration: const InputDecoration(),
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
                  ExternalField(
                    label: '结算方式',
                    child: DropdownButtonFormField<String>(
                      initialValue: dispositions[task.id],
                      decoration: const InputDecoration(),
                      items: const [
                        DropdownMenuItem(value: 'failed', child: Text('失败')),
                        DropdownMenuItem(value: 'skipped', child: Text('跳过')),
                        DropdownMenuItem(
                          value: 'rescheduled',
                          child: Text('改期'),
                        ),
                        DropdownMenuItem(value: 'inbox', child: Text('退回收集箱')),
                      ],
                      onChanged: (value) {
                        setState(() => dispositions[task.id] = value ?? '');
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  ExternalField(
                    label: dispositions[task.id] == 'failed'
                        ? '原因（必填）'
                        : '原因或说明（可选）',
                    child: TextFormField(
                      initialValue: reasons[task.id],
                      decoration: InputDecoration(hintText: '例如：外部阻塞、估时偏差'),
                      onChanged: (value) => reasons[task.id] = value,
                    ),
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
                ExternalField(
                  label: '日回顾草稿（可选）',
                  child: TextField(
                    controller: reflection,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      hintText: '收尾后会自动转到日回顾继续编辑',
                    ),
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
                    if (context.mounted) {
                      await showGeneralDialog<void>(
                        context: context,
                        barrierDismissible: true,
                        barrierLabel: '日结完成',
                        transitionDuration: Duration.zero,
                        pageBuilder: (dialogContext, _, _) => _DismissAfter(
                          duration: const Duration(milliseconds: 2000),
                          child: FocusCelebration(
                            title: '今日已收尾',
                            subtitle: '今日航迹已写入执行日志',
                          ),
                        ),
                      );
                    }
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
              ExternalField(
                label: '任务',
                child: DropdownButtonFormField<WorkspaceRecord>(
                  initialValue: selectedTask,
                  decoration: const InputDecoration(),
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
              ExternalField(
                label: '时长',
                child: DropdownButtonFormField<int>(
                  initialValue: minutes,
                  decoration: const InputDecoration(),
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
              ExternalField(
                label: '时长',
                child: DropdownButtonFormField<int>(
                  initialValue: minutes,
                  decoration: const InputDecoration(),
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

/// 展示 [duration] 后自动关闭自身所在路由的仪式覆盖层。
class _DismissAfter extends StatefulWidget {
  const _DismissAfter({required this.duration, required this.child});

  final Duration duration;
  final Widget child;

  @override
  State<_DismissAfter> createState() => _DismissAfterState();
}

class _DismissAfterState extends State<_DismissAfter> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, () {
      if (mounted) Navigator.maybePop(context);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ═══════════════════════════════════════════════════════════════════════
// 方案 C「新芽晨光」· 移动端专属组件
//
// 这三件在旧实现里完全不存在，也是「看起来不像方案 C」的主因：
// 今日概览卡（视觉锚点）、分段进度条、环形进度。
// ═══════════════════════════════════════════════════════════════════════

/// 今日概览卡（方案 C 手机 2 的 Hero）。
///
/// 左侧三行文字 + 分段进度条，右侧 64px 环形进度。
///
/// 与源稿的一处**有意偏离**：源稿用 `linear-gradient(sprout-050 → sprout-100)`
/// 打底，项目规范明文禁止装饰渐变（面板一律实色），故改用实色 `tokens.subtle`
/// + 1px 主色淡边。视觉意图（浅绿托底、与白色任务卡拉开层次）保留。
class _TodayOverviewCard extends StatelessWidget {
  const _TodayOverviewCard({
    required this.remaining,
    required this.completed,
    required this.focus,
  });

  final int remaining;
  final int completed;
  final Duration focus;

  static String formatFocus(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60);
    if (hours == 0) return '${minutes}m';
    return '${hours}h${minutes.toString().padLeft(2, '0')}m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final scheme = theme.colorScheme;
    final total = remaining + completed;
    final ratio = total == 0 ? 0.0 : completed / total;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md + 2,
        AppSpacing.lg - 2,
        AppSpacing.md + 2,
      ),
      decoration: BoxDecoration(
        color: tokens.subtle,
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(color: scheme.primaryContainer),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        remaining == 0 ? '今日已清空' : '还剩 $remaining 件事',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    // 源稿此处是 U+2726（四角星）。四款内置字体的 cmap
                    // 都没有这个码位（`tool/verify_glyph_coverage.py` 实测），
                    // 文字渲染出来是豆腐块——移动端 golden 也一直是坏的，
                    // 只是没放大看过。改用 Material 图标字体里的同形四角星，
                    // 已实测 U+E0B7 存在。
                    Icon(
                      Icons.auto_awesome,
                      size: 13,
                      color: scheme.onPrimaryContainer,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  '已完成 $completed 项 · 专注 ${formatFocus(focus)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 11.5,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: 11),
                _SegmentedProgress(ratio: ratio),
              ],
            ),
          ),
          const SizedBox(width: 14),
          _RingProgress(ratio: ratio),
        ],
      ),
    );
  }
}

/// 分段进度条：12 段方块，已完成的段用主色。
///
/// 用分段而非连续条，是为了让「还剩几件」可以被数出来——进度不是大概，
/// 是 N 件事。这也是方案 C 在概览卡里最显眼的一处细节。
class _SegmentedProgress extends StatelessWidget {
  const _SegmentedProgress({required this.ratio});

  /// 段数固定 12：源稿即 12 段，且它同时是「还剩几件事」的可数刻度。
  static const segments = 12;

  final double ratio;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filled = (ratio * segments).round().clamp(0, segments);
    return Row(
      children: [
        for (var index = 0; index < segments; index++) ...[
          if (index > 0) const SizedBox(width: 5),
          Expanded(
            child: Container(
              height: 5,
              decoration: BoxDecoration(
                color: index < filled
                    ? scheme.primary
                    : scheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// 64px 环形进度 + 中心等宽百分比。
class _RingProgress extends StatelessWidget {
  const _RingProgress({required this.ratio});

  /// 直径固定 64（源稿规格），环宽 7。
  static const size = 64.0;

  final double ratio;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final percent = (ratio * 100).round();
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          ratio: ratio.clamp(0.0, 1.0),
          track: scheme.primaryContainer,
          progress: scheme.primary,
        ),
        child: Center(
          child: Text(
            '$percent%',
            style: TextStyle(
              fontFamily: AppFonts.numeric,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: scheme.onPrimaryContainer,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.ratio,
    required this.track,
    required this.progress,
  });

  final double ratio;
  final Color track;
  final Color progress;

  static const _stroke = 7.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - _stroke) / 2;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..color = track,
    );
    if (ratio <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * ratio,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round
        ..color = progress,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.ratio != ratio || old.track != track || old.progress != progress;
}

/// 任务复选框：20×20、圆角 6 的方框（方案 C 规格）。
///
/// 旧实现是圆形的状态图标。改成圆角方框后，「完成」这一最常用动作
/// 与「习惯方点」形成同一套形状语言。
/// 未完成态的描边用 `borderStrong`，与主题里 Checkbox 的既有边界色一致。
class _TaskCheckbox extends StatelessWidget {
  const _TaskCheckbox({required this.done});

  final bool done;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    return Container(
      width: 20,
      height: 20,
      margin: const EdgeInsets.only(top: 1),
      decoration: BoxDecoration(
        color: done ? scheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.dot),
        border: done
            ? null
            : Border.all(color: tokens.borderStrong, width: 1.5),
      ),
      child: done ? Icon(Icons.check, size: 14, color: scheme.onPrimary) : null,
    );
  }
}

/// 习惯打卡点：17×17、圆角 6。与任务复选框刻意不同尺寸，避免两处混淆。
class _HabitDot extends StatelessWidget {
  const _HabitDot({required this.done});

  final bool done;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    return Container(
      width: 17,
      height: 17,
      decoration: BoxDecoration(
        color: done ? scheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.dot),
        border: done
            ? null
            : Border.all(color: tokens.borderStrong, width: 1.5),
      ),
    );
  }
}
