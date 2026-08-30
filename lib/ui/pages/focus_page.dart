import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/workspace_record.dart';
import '../../core/utils/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../services/focus_service.dart';
import '../../services/notification_service.dart';
import '../../state/workbench_controller.dart';
import '../platform_feedback.dart';
import '../widgets/celebration.dart';
import '../widgets/common.dart';
import '../widgets/solid_panel.dart';

class FocusHubPage extends StatelessWidget {
  const FocusHubPage({
    super.key,
    required this.controller,
    this.showHeader = true,
  });

  final WorkbenchController controller;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= AppBreakpoints.expanded;
    return Column(
      children: [
        if (showHeader)
          PageHeader(
            title: '专注',
            subtitle: '预设与任务关联的计时会话 · 自律规则与拦截日志',
            actions: [
              if (wide) ...[
                FilledButton.icon(
                  onPressed: () => _showPresetEditor(context, controller),
                  icon: const Icon(Icons.add),
                  label: const Text('新建专注预设'),
                ),
              ] else ...[
                IconButton(
                  onPressed: () => _showPresetEditor(context, controller),
                  tooltip: '新建专注预设',
                  icon: const Icon(Icons.add),
                ),
              ],
            ],
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => _showPresetEditor(context, controller),
                    tooltip: '新建专注预设',
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
          ),
        Expanded(child: _FocusTab(controller: controller)),
      ],
    );
  }
}

/// 专注 Tab：待确认启动 → 专注预设 → 下一项承诺 → 最近记录。
class _FocusTab extends StatelessWidget {
  const _FocusTab({required this.controller});

  final WorkbenchController controller;

  @override
  Widget build(BuildContext context) {
    final commitments = controller.commitmentTasks
        .where((task) => !task.isDone)
        .toList();
    final fallback = controller.focusTasks
        .where((task) => !task.isDone)
        .toList();
    final candidates = commitments.isNotEmpty ? commitments : fallback;
    final recent = controller
        .recordsOf(RecordKind.focusSession)
        .take(6)
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 132),
      children: [
        if (controller.pendingFocusPresets.isNotEmpty) ...[
          const SectionHeading(title: '待确认启动'),
          LogSurface(
            accent: Theme.of(context).colorScheme.tertiary,
            child: Column(
              children: [
                for (final preset in controller.pendingFocusPresets)
                  ListTile(
                    leading: const Icon(Icons.notification_important_outlined),
                    title: Text(preset.title),
                    subtitle: Text(
                      controller.pendingFocusPresets.length > 1
                          ? '与其他预设冲突，请选择一个开始'
                          : '已到计划时间，确认后才会开始计时',
                    ),
                    trailing: Wrap(
                      spacing: 6,
                      children: [
                        TextButton(
                          onPressed: () =>
                              controller.declineScheduledFocus(preset),
                          child: const Text('跳过'),
                        ),
                        FilledButton.icon(
                          onPressed: () async {
                            await controller.confirmScheduledFocus(preset);
                            if (context.mounted) {
                              await _startPreset(context, controller, preset);
                            }
                          },
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('确认开始'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SectionHeading(title: '专注预设'),
        if (controller.focusPresets.isEmpty)
          Text('尚未创建预设。', style: TextStyle(color: context.tokens.mutedText))
        else
          LogSurface(
            child: Column(
              children: [
                for (final preset in controller.focusPresets)
                  ListTile(
                    leading: Icon(
                      preset.data['mode'] == FocusMode.stopwatch.name
                          ? Icons.timer_outlined
                          : Icons.hourglass_bottom_outlined,
                    ),
                    title: Text(preset.title),
                    subtitle: Text(_presetSummary(preset)),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          onPressed: () => _showPresetEditor(
                            context,
                            controller,
                            preset: preset,
                          ),
                          tooltip: '编辑预设',
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        FilledButton.icon(
                          onPressed: () =>
                              _startPreset(context, controller, preset),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('开始'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        const SectionHeading(title: '下一项承诺'),
        if (candidates.isEmpty)
          const EmptyState(
            icon: Icons.timer_outlined,
            title: '尚无可执行承诺',
            message: '先在“今日”选择并锁定 1–3 项承诺。',
          )
        else
          LogSurface(
            accent: Theme.of(context).colorScheme.primary,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  candidates.first.title,
                  style: Theme.of(context).textTheme.titleLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  controller.todayStarted
                      ? controller.advancedFeaturesEnabled
                            ? '已关联今日承诺，完成的有效时长可计入专注 XP。'
                            : '已关联今日重点，完成后会保留专注记录。'
                      : '尚未开始今天，本次专注只记录时间。',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.tokens.mutedText,
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: () =>
                        showFocusSession(context, controller, candidates.first),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('开始专注'),
                  ),
                ),
              ],
            ),
          ),
        const SectionHeading(title: '最近记录'),
        if (recent.isEmpty)
          Text(
            '尚无专注记录。',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: context.tokens.mutedText),
          )
        else
          LogSurface(
            child: Column(
              children: [
                for (var index = 0; index < recent.length; index++) ...[
                  ListTile(
                    leading: NumericText(
                      '${((recent[index].data['seconds'] as num?)?.toInt() ?? 0) ~/ 60}'
                          .padLeft(2, '0'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    title: Text(
                      recent[index].title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: const Text('分钟'),
                    trailing: Text(
                      recent[index].data['mode']?.toString() ?? '',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: context.tokens.mutedText,
                      ),
                    ),
                  ),
                  if (index < recent.length - 1) const Divider(),
                ],
              ],
            ),
          ),
        if (candidates.length + recent.length < 5) const SizedBox(height: 12),
      ],
    );
  }
}

Future<void> showFocusSession(
  BuildContext context,
  WorkbenchController controller,
  WorkspaceRecord? task, {
  WorkspaceRecord? preset,
}) {
  return showWorkbenchDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => Dialog.fullscreen(
      child: FocusPage(controller: controller, task: task, preset: preset),
    ),
  );
}

String _presetSummary(WorkspaceRecord preset) {
  final mode = preset.data['mode'] == FocusMode.stopwatch.name
      ? '正计时'
      : '倒计时 ${(preset.data['minutes'] as num?)?.toInt() ?? 25} 分钟';
  final listMode = switch (preset.data['listMode']) {
    'allow' => '白名单',
    'block' => '黑名单',
    _ => '不检测应用',
  };
  final schedule = switch (preset.data['scheduleMode']) {
    'once' => '单次提醒',
    'weekly' => '每周提醒',
    _ => '手动启动',
  };
  return '$mode · $listMode · $schedule';
}

Future<void> _startPreset(
  BuildContext context,
  WorkbenchController controller,
  WorkspaceRecord preset,
) async {
  final taskId = preset.data['taskId']?.toString();
  var task = controller.tasks
      .where((record) => record.id == taskId)
      .firstOrNull;
  if (taskId != null && task == null) {
    task = await showWorkbenchDialog<WorkspaceRecord>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('选择主任务'),
        children: [
          for (final candidate in controller.tasks.where(
            (record) => !WorkStatus.terminal.contains(record.status),
          ))
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, candidate),
              child: Text(candidate.title),
            ),
        ],
      ),
    );
  }
  if (!context.mounted) return;
  await showFocusSession(context, controller, task, preset: preset);
}

Future<void> _showPresetEditor(
  BuildContext context,
  WorkbenchController controller, {
  WorkspaceRecord? preset,
}) async {
  final title = TextEditingController(text: preset?.title ?? '');
  final minutes = TextEditingController(
    text: '${(preset?.data['minutes'] as num?)?.toInt() ?? 25}',
  );
  final applications = TextEditingController(
    text: (preset?.data['applications'] as List<dynamic>? ?? const []).join(
      ', ',
    ),
  );
  var mode = FocusMode.values.firstWhere(
    (value) => value.name == preset?.data['mode'],
    orElse: () => FocusMode.custom,
  );
  var listMode = preset?.data['listMode']?.toString() ?? 'none';
  var detection = preset?.data['detectionEnabled'] == true;
  var taskId = preset?.data['taskId']?.toString();
  var scheduleMode = preset?.data['scheduleMode']?.toString() ?? 'none';
  var bringToFront = preset?.data['bringToFrontOnSchedule'] != false;
  var scheduledAt = DateTime.tryParse(
    preset?.data['scheduledAt']?.toString() ?? '',
  )?.toLocal();
  final weekdays = (preset?.data['weekdays'] as List<dynamic>? ?? const [])
      .map((value) => (value as num).toInt())
      .toSet();
  await showWorkbenchDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(preset == null ? '新建专注预设' : '编辑专注预设'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExternalField(
                  label: '预设名称',
                  child: TextField(
                    controller: title,
                    decoration: const InputDecoration(),
                  ),
                ),
                const SizedBox(height: 12),
                ExternalField(
                  label: '计时模式',
                  child: DropdownButtonFormField<FocusMode>(
                    initialValue: mode,
                    decoration: const InputDecoration(),
                    items: const [
                      DropdownMenuItem(
                        value: FocusMode.stopwatch,
                        child: Text('正计时'),
                      ),
                      DropdownMenuItem(
                        value: FocusMode.custom,
                        child: Text('自定义倒计时'),
                      ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => mode = value ?? mode),
                  ),
                ),
                if (mode != FocusMode.stopwatch) ...[
                  const SizedBox(height: 12),
                  ExternalField(
                    label: '时长（分钟）',
                    child: TextField(
                      controller: minutes,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                ExternalField(
                  label: '主任务（可空）',
                  child: DropdownButtonFormField<String?>(
                    initialValue: taskId,
                    decoration: const InputDecoration(),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('临时专注')),
                      for (final task in controller.tasks)
                        DropdownMenuItem(
                          value: task.id,
                          child: Text(task.title),
                        ),
                    ],
                    onChanged: (value) => setDialogState(() => taskId = value),
                  ),
                ),
                const SizedBox(height: 12),
                ExternalField(
                  label: '应用检测模式',
                  child: DropdownButtonFormField<String>(
                    initialValue: listMode,
                    decoration: const InputDecoration(),
                    items: const [
                      DropdownMenuItem(value: 'none', child: Text('不使用名单')),
                      DropdownMenuItem(value: 'allow', child: Text('白名单')),
                      DropdownMenuItem(value: 'block', child: Text('黑名单')),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => listMode = value ?? 'none'),
                  ),
                ),
                if (listMode != 'none') ...[
                  const SizedBox(height: 12),
                  ExternalField(
                    label: '应用进程名',
                    child: TextField(
                      controller: applications,
                      decoration: const InputDecoration(
                        hintText: 'chrome.exe, matlab.exe',
                      ),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: detection,
                    title: const Text('此预设启用前台检测'),
                    onChanged: (value) =>
                        setDialogState(() => detection = value),
                  ),
                ],
                const SizedBox(height: 12),
                ExternalField(
                  label: '定时启动提醒',
                  child: DropdownButtonFormField<String>(
                    initialValue: scheduleMode,
                    decoration: const InputDecoration(),
                    items: const [
                      DropdownMenuItem(value: 'none', child: Text('不定时')),
                      DropdownMenuItem(value: 'once', child: Text('单次')),
                      DropdownMenuItem(value: 'weekly', child: Text('每周指定日')),
                    ],
                    onChanged: (value) => setDialogState(() {
                      scheduleMode = value ?? 'none';
                      if (scheduleMode != 'none') {
                        scheduledAt ??= DateTime.now().add(
                          const Duration(hours: 1),
                        );
                      }
                    }),
                  ),
                ),
                if (scheduleMode != 'none') ...[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: bringToFront,
                    secondary: const Icon(Icons.open_in_new_outlined),
                    title: const Text('到点时显示工作台'),
                    subtitle: const Text('先发送系统提醒，再恢复窗口；仍需确认后才开始计时'),
                    onChanged: (value) =>
                        setDialogState(() => bringToFront = value),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (scheduleMode == 'once')
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final current = scheduledAt ?? DateTime.now();
                              final result = await showDatePicker(
                                context: context,
                                initialDate: current,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 3650),
                                ),
                              );
                              if (result != null) {
                                setDialogState(() {
                                  scheduledAt = DateTime(
                                    result.year,
                                    result.month,
                                    result.day,
                                    current.hour,
                                    current.minute,
                                  );
                                });
                              }
                            },
                            icon: const Icon(Icons.calendar_today_outlined),
                            label: Text(
                              scheduledAt == null
                                  ? '选择日期'
                                  : formatShortDate(scheduledAt!),
                            ),
                          ),
                        ),
                      if (scheduleMode == 'once') const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final current = scheduledAt ?? DateTime.now();
                            final result = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(current),
                            );
                            if (result != null) {
                              setDialogState(() {
                                scheduledAt = DateTime(
                                  current.year,
                                  current.month,
                                  current.day,
                                  result.hour,
                                  result.minute,
                                );
                              });
                            }
                          },
                          icon: const Icon(Icons.schedule_outlined),
                          label: Text(
                            scheduledAt == null
                                ? '选择时间'
                                : TimeOfDay.fromDateTime(
                                    scheduledAt!,
                                  ).format(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (scheduleMode == 'weekly') ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final value in const [
                        (DateTime.monday, '一'),
                        (DateTime.tuesday, '二'),
                        (DateTime.wednesday, '三'),
                        (DateTime.thursday, '四'),
                        (DateTime.friday, '五'),
                        (DateTime.saturday, '六'),
                        (DateTime.sunday, '日'),
                      ])
                        FilterChip(
                          label: Text(value.$2),
                          selected: weekdays.contains(value.$1),
                          onSelected: (selected) => setDialogState(() {
                            if (selected) {
                              weekdays.add(value.$1);
                            } else {
                              weekdays.remove(value.$1);
                            }
                          }),
                        ),
                    ],
                  ),
                ],
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
            onPressed: () async {
              try {
                await controller.saveFocusPreset(
                  preset: preset,
                  title: title.text,
                  mode: mode,
                  minutes: int.tryParse(minutes.text) ?? 25,
                  taskId: taskId,
                  listMode: listMode,
                  applications: applications.text.split(','),
                  detectionEnabled: detection,
                  scheduleMode: scheduleMode,
                  scheduledAt: scheduleMode == 'none' ? null : scheduledAt,
                  weekdays: scheduleMode == 'weekly'
                      ? (weekdays.toList()..sort())
                      : const [],
                  bringToFrontOnSchedule: bringToFront,
                );
                if (context.mounted) Navigator.pop(context);
              } on FormatException catch (error) {
                if (context.mounted) {
                  showWorkbenchSnackBar(
                    context,
                    SnackBar(content: Text(error.message)),
                  );
                }
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    ),
  );
  title.dispose();
  minutes.dispose();
  applications.dispose();
}

class FocusPage extends StatefulWidget {
  const FocusPage({
    super.key,
    required this.controller,
    required this.task,
    this.preset,
  });

  final WorkbenchController controller;
  final WorkspaceRecord? task;
  final WorkspaceRecord? preset;

  @override
  State<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends State<FocusPage> with WidgetsBindingObserver {
  FocusMode selectedMode = FocusMode.pomodoro25;
  bool finishing = false;
  bool targetNotified = false;
  bool celebrating = false;
  Duration celebratedDuration = Duration.zero;
  bool targetPulse = false;
  late final String focusSessionId;
  Timer? activityTimer;
  StreamSubscription<String>? powerSubscription;
  String? foregroundApplication;
  DateTime? foregroundStartedAt;
  String? lastWarnedApplication;

  FocusService get service => widget.controller.focusService;

  @override
  void initState() {
    super.initState();
    focusSessionId = newRecordId();
    if (widget.preset != null) {
      selectedMode = FocusMode.values.firstWhere(
        (mode) => mode.name == widget.preset!.data['mode'],
        orElse: () => FocusMode.custom,
      );
    } else if (widget.task?.hasCtdpProtocol == true) {
      selectedMode = widget.task!.ctdpIsDurationless
          ? FocusMode.stopwatch
          : FocusMode.custom;
    }
    WidgetsBinding.instance.addObserver(this);
    service.addListener(_handleTargetReached);
    powerSubscription = widget.controller.windowsActivityService.powerEvents
        .listen(_handlePowerEvent);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    service.removeListener(_handleTargetReached);
    activityTimer?.cancel();
    powerSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) service.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: scheme.surface,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            leading: IconButton(
              onPressed: _close,
              tooltip: '退出专注',
              icon: const Icon(Icons.close),
            ),
            title: const Text('专注'),
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1),
            ),
          ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              if (celebrating)
                Positioned.fill(
                  child: FocusCelebration(
                    title: '专注完成',
                    subtitle:
                        '$_focusTitle · ${celebratedDuration.inMinutes} 分钟',
                  ),
                ),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 680),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  widget.task?.title ??
                                      widget.preset?.title ??
                                      '临时专注',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineMedium,
                                  textAlign: TextAlign.center,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 32),
                                SolidPanel(
                                  padding: const EdgeInsets.all(4),
                                  radius: AppRadius.card,
                                  child: SegmentedButton<FocusMode>(
                                    segments: const [
                                      ButtonSegment(
                                        value: FocusMode.stopwatch,
                                        label: Text('正计时'),
                                        icon: Icon(Icons.timer_outlined),
                                      ),
                                      ButtonSegment(
                                        value: FocusMode.pomodoro25,
                                        label: Text('25 / 5'),
                                      ),
                                      ButtonSegment(
                                        value: FocusMode.pomodoro50,
                                        label: Text('50 / 10'),
                                      ),
                                      ButtonSegment(
                                        value: FocusMode.custom,
                                        label: Text('协议时长'),
                                        icon: Icon(Icons.link),
                                      ),
                                    ],
                                    selected: {
                                      service.running
                                          ? service.mode
                                          : selectedMode,
                                    },
                                    onSelectionChanged: service.running
                                        ? null
                                        : (value) => setState(
                                            () => selectedMode = value.first,
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 44),
                                Stack(
                                  clipBehavior: Clip.none,
                                  alignment: Alignment.center,
                                  children: [
                                    if (targetPulse)
                                      const PulseRing(
                                        duration: Duration(milliseconds: 900),
                                      ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                      child: Column(
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 5,
                                                height: 5,
                                                decoration: BoxDecoration(
                                                  color: context.tokens.marker,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                service.running
                                                    ? '灵息流转'
                                                    : '待入静',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelMedium
                                                    ?.copyWith(
                                                      color: context
                                                          .tokens
                                                          .mutedText,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          SizedBox(
                                            height: 128,
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                formatDuration(
                                                  service.displayDuration,
                                                ),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .displaySmall
                                                    ?.copyWith(
                                                      fontSize: 84,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontFeatures: const [
                                                        FontFeature.tabularFigures(),
                                                      ],
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 22),
                                if (service.mode != FocusMode.stopwatch)
                                  LinearProgressIndicator(
                                    value: service.progress,
                                    minHeight: 8,
                                    borderRadius: BorderRadius.circular(4),
                                  )
                                else
                                  Text(
                                    '按实际投入时间记录',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                  ),
                                const SizedBox(height: 38),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    PressScale(
                                      child: FilledButton.icon(
                                        onPressed: service.running
                                            ? _pause
                                            : _start,
                                        icon: Icon(
                                          service.running
                                              ? Icons.pause
                                              : Icons.play_arrow,
                                        ),
                                        label: Text(
                                          service.running ? '暂停' : '开始专注',
                                        ),
                                      ),
                                    ),
                                    PressScale(
                                      child: OutlinedButton.icon(
                                        onPressed:
                                            service.elapsed == Duration.zero ||
                                                finishing
                                            ? null
                                            : _finish,
                                        icon: const Icon(Icons.check),
                                        label: const Text('完成本次专注'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _finish() async {
    final duration = service.elapsed;
    final earlyCompletion =
        service.mode != FocusMode.stopwatch && duration < service.target;
    if (widget.task?.hasCtdpProtocol == true && earlyCompletion) {
      final rule = await _selectRule('early_completion', '提前完成需要引用判例');
      if (rule == null) return;
      await widget.controller.useExceptionRule(
        rule,
        widget.task!,
        action: 'early_completion_rule_used',
        elapsed: duration,
        remaining: service.target - duration,
      );
    }
    final evidence = await _askCompletionEvidence(
      requireDescription: widget.task?.hasCtdpProtocol == true,
    );
    if (evidence == null) return;
    setState(() => finishing = true);
    final mode = service.mode;
    service.finish();
    await _cancelEndNotification();
    try {
      await widget.controller.completeFocusSession(
        widget.task,
        duration,
        mode,
        sessionTitle: widget.preset?.title,
        description: evidence.$1,
        notes: evidence.$2,
        earlyCompletion: earlyCompletion,
      );
      await widget.controller.settleLocalBet(
        sessionId: focusSessionId,
        successful: true,
      );
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() => finishing = false);
      showWorkbenchSnackBar(context, SnackBar(content: Text(error.message)));
      return;
    }
    await WorkbenchFeedback.completion();
    await widget.controller.notificationService.showNow(
      id: stableNotificationId('focus-session:$_focusIdentity'),
      title: '专注完成',
      body: '$_focusTitle · ${duration.inMinutes} 分钟',
    );
    if (!mounted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      celebrating = true;
      celebratedDuration = duration;
    });
    await Future<void>.delayed(const Duration(milliseconds: 1850));
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _start() async {
    final shouldStart = await _maybePlaceBet();
    if (!shouldStart) return;
    targetNotified = false;
    service.start(
      selectedMode,
      customTarget: selectedMode == FocusMode.custom
          ? Duration(
              minutes:
                  (widget.preset?.data['minutes'] as num?)?.toInt().clamp(
                    1,
                    720,
                  ) ??
                  widget.task?.ctdpSessionMinutes.clamp(1, 720) ??
                  25,
            )
          : null,
    );
    _startActivityMonitoring();
    await _scheduleEndNotification();
  }

  Future<void> _pause() async {
    service.pause();
    await _stopActivityMonitoring();
    await _cancelEndNotification();
    if (widget.task?.hasCtdpProtocol != true ||
        service.elapsed == Duration.zero) {
      return;
    }
    final rule = await _selectRule('pause', '暂停需要引用判例');
    if (rule == null) {
      service.start(service.mode);
      await _scheduleEndNotification();
      return;
    }
    await widget.controller.useExceptionRule(
      rule,
      widget.task!,
      action: 'pause_rule_used',
      elapsed: service.elapsed,
      remaining: service.mode == FocusMode.stopwatch
          ? null
          : service.target - service.elapsed,
    );
  }

  void _handleTargetReached() {
    if (targetNotified ||
        service.mode == FocusMode.stopwatch ||
        service.running ||
        service.elapsed < service.target) {
      return;
    }
    targetNotified = true;
    final restMinutes = service.mode == FocusMode.pomodoro50 ? 10 : 5;
    if (!mounted) return;
    setState(() => targetPulse = true);
    Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => targetPulse = false);
    });
    showWorkbenchSnackBar(
      context,
      SnackBar(content: Text('本轮专注结束，建议休息 $restMinutes 分钟。')),
    );
  }

  Future<void> _close() async {
    await _stopActivityMonitoring();
    if (!mounted) return;
    if (service.elapsed == Duration.zero) {
      await _cancelEndNotification();
      await widget.controller.cancelLocalBet(focusSessionId);
      if (!mounted) return;
      Navigator.pop(context);
      return;
    }
    if (widget.task?.hasCtdpProtocol == true) {
      service.pause();
      await _cancelEndNotification();
      if (!mounted) return;
      final result = await showWorkbenchDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('中断 CTDP 本轮？'),
          content: const Text('中断必须结算：失败会重置主链；允许中断必须引用结构化判例。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'continue'),
              child: const Text('继续执行'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'rule'),
              child: const Text('引用判例退出'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'fail'),
              child: const Text('判定失败'),
            ),
          ],
        ),
      );
      if (result == 'continue' || result == null) {
        service.start(service.mode);
        await _scheduleEndNotification();
        return;
      }
      if (result == 'rule') {
        final rule = await _selectRule('interruption', '允许中断需要引用判例');
        if (rule == null) {
          service.start(service.mode);
          await _scheduleEndNotification();
          return;
        }
        await widget.controller.useExceptionRule(
          rule,
          widget.task!,
          action: 'interruption_rule_used',
          elapsed: service.elapsed,
        );
        await widget.controller.settleLocalBet(
          sessionId: focusSessionId,
          successful: false,
        );
      } else {
        await widget.controller.failCtdpTask(
          widget.task!,
          reason: '专注过程被中断，主链从 #1 重新开始',
        );
        await widget.controller.settleLocalBet(
          sessionId: focusSessionId,
          successful: false,
        );
      }
      if (!mounted) return;
      service.reset();
      await _cancelEndNotification();
      if (!mounted) return;
      Navigator.pop(context);
      return;
    }
    final discard = await showWorkbenchDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出本次专注？'),
        content: const Text('尚未保存的计时将被清除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('继续专注'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      service.reset();
      await widget.controller.cancelLocalBet(focusSessionId);
      await _cancelEndNotification();
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  Future<void> _handlePowerEvent(String event) async {
    if (event == 'suspend' && service.running) {
      service.pause();
      await _stopActivityMonitoring();
      await _cancelEndNotification();
      return;
    }
    if (event != 'resume' || !mounted || service.elapsed == Duration.zero) {
      return;
    }
    final action = await showWorkbenchDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('系统已从休眠恢复'),
        content: const Text('休眠时长未计入专注。请选择继续或结束本次会话。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'finish'),
            child: const Text('结束'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'continue'),
            child: const Text('继续'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'continue') {
      service.start(service.mode);
      _startActivityMonitoring();
      await _scheduleEndNotification();
    } else if (action == 'finish') {
      await _finish();
    }
  }

  void _startActivityMonitoring() {
    final preset = widget.preset;
    if (preset?.data['detectionEnabled'] != true ||
        !widget.controller.foregroundDetectionEnabled) {
      return;
    }
    activityTimer?.cancel();
    _pollForeground();
    activityTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _pollForeground(),
    );
  }

  Future<void> _pollForeground() async {
    final application = await widget.controller.windowsActivityService
        .foregroundProcess();
    if (application == null || application == foregroundApplication) return;
    await _flushForeground();
    foregroundApplication = application;
    foregroundStartedAt = widget.controller.currentTime();
    await _warnIfNeeded(application);
  }

  Future<void> _warnIfNeeded(String application) async {
    final preset = widget.preset;
    if (preset == null || lastWarnedApplication == application) return;
    final mode = preset.data['listMode']?.toString() ?? 'none';
    final apps = (preset.data['applications'] as List<dynamic>? ?? const [])
        .map((value) => value.toString().toLowerCase())
        .toSet();
    final normalized = application.toLowerCase();
    final violates = mode == 'block'
        ? apps.contains(normalized)
        : mode == 'allow'
        ? !apps.contains(normalized)
        : false;
    if (!violates) return;
    lastWarnedApplication = application;
    await widget.controller.notificationService.showNow(
      id: stableNotificationId('focus-app:${preset.id}:$normalized'),
      title: '专注应用提醒',
      body: '$application 不在当前专注预设的允许范围内。',
    );
  }

  Future<void> _flushForeground() async {
    final application = foregroundApplication;
    final startedAt = foregroundStartedAt;
    foregroundApplication = null;
    foregroundStartedAt = null;
    if (application == null || startedAt == null) return;
    await widget.controller.recordForegroundEvent(
      applicationId: application,
      startedAt: startedAt,
      duration: widget.controller.currentTime().difference(startedAt),
      presetId: widget.preset?.id,
    );
  }

  Future<void> _stopActivityMonitoring() async {
    activityTimer?.cancel();
    activityTimer = null;
    await _flushForeground();
  }

  Future<bool> _maybePlaceBet() async {
    if (widget.task == null) return true;
    final profile = widget.controller.gameProfile;
    if (!widget.controller.gameFeaturesEnabled ||
        !profile.gamblingEnabled ||
        widget.controller.pendingLocalBet(focusSessionId) != null) {
      return true;
    }
    final field = TextEditingController(
      text: profile.points >= 10 ? '10' : '${profile.points}',
    );
    final amount = await showWorkbenchDialog<int?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('要为这次专注押注吗？'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '余额 ${profile.points} 积分 · 今日已用 ${widget.controller.todayBetUsed} 积分',
            ),
            const SizedBox(height: 12),
            ExternalField(
              label: '押注金额',
              child: TextField(
                controller: field,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(suffixText: '积分'),
              ),
            ),
            const SizedBox(height: 8),
            const Text('完成后总返还为押注金额的 2 倍；失败不返还。'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 0),
            child: const Text('不押注，直接开始'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, int.tryParse(field.text)),
            child: const Text('确认押注'),
          ),
        ],
      ),
    );
    field.dispose();
    if (amount == null) return false;
    if (amount == 0) return true;
    try {
      await widget.controller.placeLocalBet(
        sessionId: focusSessionId,
        taskId: widget.task!.id,
        amount: amount,
      );
      return true;
    } on FormatException catch (error) {
      if (mounted) {
        showWorkbenchSnackBar(context, SnackBar(content: Text(error.message)));
      }
      return false;
    }
  }

  String get _focusTitle =>
      widget.task?.title ?? widget.preset?.title ?? '临时专注';

  String get _focusIdentity =>
      widget.task?.id ?? widget.preset?.id ?? focusSessionId;

  int get _focusNotificationId => stableNotificationId('focus:$_focusIdentity');

  Future<void> _scheduleEndNotification() async {
    if (service.mode == FocusMode.stopwatch || !service.running) return;
    final restMinutes = service.mode == FocusMode.pomodoro50 ? 10 : 5;
    try {
      await widget.controller.notificationService.scheduleFocusEnd(
        id: _focusNotificationId,
        taskTitle: _focusTitle,
        when: widget.controller.currentTime().add(service.displayDuration),
        restMinutes: restMinutes,
      );
    } catch (error) {
      debugPrint('Unable to schedule focus notification: $error');
    }
  }

  Future<void> _cancelEndNotification() async {
    try {
      await widget.controller.notificationService.cancel(_focusNotificationId);
    } catch (error) {
      debugPrint('Unable to cancel focus notification: $error');
    }
  }

  Future<WorkspaceRecord?> _selectRule(String type, String title) async {
    final task = widget.task;
    if (task == null) return null;
    final rules = widget.controller.exceptionRulesFor(task, ruleType: type);
    return showWorkbenchDialog<WorkspaceRecord>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 440,
          child: rules.isEmpty
              ? const Text('没有可用判例。请先在“协议 > 判例”中建立适用规则。')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: rules.length,
                  itemBuilder: (context, index) {
                    final rule = rules[index];
                    return ListTile(
                      leading: const Icon(Icons.gavel_outlined),
                      title: Text(rule.title),
                      subtitle: Text(rule.body),
                      onTap: () => Navigator.pop(context, rule),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  Future<(String, String)?> _askCompletionEvidence({
    required bool requireDescription,
  }) async {
    var description = '';
    var notes = '';
    String? error;
    return showWorkbenchDialog<(String, String)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('记录本轮证据'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExternalField(
                  label: requireDescription ? '完成内容（必填）' : '完成内容',
                  child: TextField(
                    autofocus: true,
                    onChanged: (value) => description = value,
                    decoration: InputDecoration(errorText: error),
                  ),
                ),
                const SizedBox(height: 12),
                ExternalField(
                  label: '备注',
                  child: TextField(
                    minLines: 2,
                    maxLines: 4,
                    onChanged: (value) => notes = value,
                    decoration: const InputDecoration(),
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
              onPressed: () {
                final trimmedDescription = description.trim();
                if (requireDescription && trimmedDescription.isEmpty) {
                  setDialogState(() => error = '请记录实际完成内容');
                  return;
                }
                Navigator.pop(context, (trimmedDescription, notes.trim()));
              },
              child: const Text('结算本轮'),
            ),
          ],
        ),
      ),
    );
  }
}
