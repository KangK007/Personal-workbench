import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/models/workspace_record.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../state/workbench_controller.dart';
import '../widgets/common.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({
    super.key,
    required this.controller,
    this.initialDate,
    this.showHeader = true,
  });

  final WorkbenchController controller;
  final DateTime? initialDate;
  final bool showHeader;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime weekStart;
  late DateTime selectedDay;

  DateTime get _now => widget.initialDate ?? widget.controller.currentTime();

  @override
  void initState() {
    super.initState();
    weekStart = _startOfWeek(_now);
    selectedDay = startOfDay(_now);
  }

  @override
  Widget build(BuildContext context) {
    final days = List.generate(
      5,
      (index) => weekStart.add(Duration(days: index)),
    );
    return Column(
      children: [
        if (widget.showHeader)
          PageHeader(
            title: '工作周',
            subtitle:
                '${formatShortDate(days.first)}—${formatShortDate(days.last)} · 5 分钟吸附',
            actions: [
              IconButton(
                onPressed: () => setState(
                  () => weekStart = weekStart.subtract(const Duration(days: 7)),
                ),
                tooltip: '上一周',
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                onPressed: () => setState(() {
                  weekStart = _startOfWeek(_now);
                  selectedDay = startOfDay(_now);
                }),
                tooltip: '回到本周',
                icon: const Icon(Icons.today_outlined),
              ),
              IconButton(
                onPressed: () => setState(
                  () => weekStart = weekStart.add(const Duration(days: 7)),
                ),
                tooltip: '下一周',
                icon: const Icon(Icons.chevron_right),
              ),
              IconButton(
                onPressed: widget.controller.tasks.isEmpty
                    ? null
                    : () => _createBlock(context),
                tooltip: '安排时间块',
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        if (!widget.showHeader)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Text('工作周', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  onPressed: () => setState(
                    () =>
                        weekStart = weekStart.subtract(const Duration(days: 7)),
                  ),
                  tooltip: '上一周',
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  onPressed: () => setState(() {
                    weekStart = _startOfWeek(_now);
                    selectedDay = startOfDay(_now);
                  }),
                  tooltip: '回到本周',
                  icon: const Icon(Icons.today_outlined),
                ),
                IconButton(
                  onPressed: () => setState(
                    () => weekStart = weekStart.add(const Duration(days: 7)),
                  ),
                  tooltip: '下一周',
                  icon: const Icon(Icons.chevron_right),
                ),
                IconButton(
                  onPressed: widget.controller.tasks.isEmpty
                      ? null
                      : () => _createBlock(context),
                  tooltip: '安排时间块',
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
        if (widget.showHeader) const Divider(),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return constraints.maxWidth >= 820
                  ? _DesktopWeek(
                      controller: widget.controller,
                      days: days,
                      now: _now,
                      onEdit: (block) => _editBlock(context, block),
                    )
                  : _MobileWeek(
                      controller: widget.controller,
                      days: days,
                      selectedDay: selectedDay,
                      onSelected: (day) => setState(() => selectedDay = day),
                      onEdit: (block) => _editBlock(context, block),
                    );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _createBlock(BuildContext context) async {
    final task = widget.controller.tasks
        .where((task) => !task.isDone)
        .firstOrNull;
    if (task == null) return;
    var selectedTask = task;
    var start = DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
      9,
    );
    var minutes = 25;
    final accepted = await _showBlockDialog(
      context,
      title: '安排时间块',
      tasks: widget.controller.tasks.where((task) => !task.isDone).toList(),
      initialTask: selectedTask,
      initialStart: start,
      initialMinutes: minutes,
    );
    if (accepted == null) return;
    selectedTask = accepted.task;
    start = accepted.start;
    minutes = accepted.minutes;
    await widget.controller.createTimeBlock(
      task: selectedTask,
      start: start,
      minutes: minutes,
    );
  }

  Future<void> _editBlock(BuildContext context, WorkspaceRecord block) async {
    final task =
        widget.controller.tasks
            .where((task) => task.id == block.parentId)
            .firstOrNull ??
        widget.controller.tasks.firstOrNull;
    if (task == null) return;
    final result = await _showBlockDialog(
      context,
      title: '调整时间块',
      tasks: [task],
      initialTask: task,
      initialStart: block.scheduledFor!,
      initialMinutes: (block.data['durationMinutes'] as num?)?.toInt() ?? 25,
      allowDelete: true,
    );
    if (result == null) return;
    if (result.delete) {
      await widget.controller.moveToTrash(block);
      return;
    }
    await widget.controller.updateTimeBlock(
      block: block,
      start: result.start,
      minutes: result.minutes,
    );
  }
}

class _DesktopWeek extends StatelessWidget {
  const _DesktopWeek({
    required this.controller,
    required this.days,
    required this.now,
    required this.onEdit,
  });

  final WorkbenchController controller;
  final List<DateTime> days;
  final DateTime now;
  final ValueChanged<WorkspaceRecord> onEdit;

  @override
  Widget build(BuildContext context) {
    final blocks = days.expand(controller.timeBlocksForDay).toList();
    final mappedHours = blocks
        .map((block) => _logicalHour(block.scheduledFor!))
        .toList();
    final startHour = mappedHours.isEmpty
        ? 6
        : math.min(6, mappedHours.reduce(math.min).floor());
    final endHour = mappedHours.isEmpty
        ? 26
        : math.max(
            26,
            blocks
                .map(
                  (block) =>
                      _logicalHour(block.scheduledFor!) +
                      ((block.data['durationMinutes'] as num?)?.toInt() ?? 25) /
                          60,
                )
                .reduce(math.max)
                .ceil(),
          );
    const hourHeight = 46.0;
    final height = (endHour - startHour) * hourHeight;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: Row(
            children: [
              const SizedBox(width: 58),
              for (final day in days)
                Expanded(
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSameDay(day, now)
                          ? Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.08)
                          : Colors.transparent,
                      border: Border(
                        left: BorderSide(color: context.tokens.divider),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _weekday(day.weekday),
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: context.tokens.mutedText),
                        ),
                        NumericText(
                          '${day.month.toString().padLeft(2, '0')}.${day.day.toString().padLeft(2, '0')}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
            child: SizedBox(
              height: height,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 58,
                    child: Stack(
                      children: [
                        for (var hour = startHour; hour < endHour; hour++)
                          Positioned(
                            top: math.max(
                              2.0,
                              (hour - startHour) * hourHeight - 8,
                            ),
                            right: 10,
                            child: NumericText(
                              '${hour % 24}'.padLeft(2, '0'),
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(color: context.tokens.mutedText),
                            ),
                          ),
                      ],
                    ),
                  ),
                  for (final day in days)
                    Expanded(
                      child: _DayLane(
                        controller: controller,
                        day: day,
                        now: now,
                        startHour: startHour,
                        endHour: endHour,
                        hourHeight: hourHeight,
                        onEdit: onEdit,
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

class _DayLane extends StatelessWidget {
  const _DayLane({
    required this.controller,
    required this.day,
    required this.now,
    required this.startHour,
    required this.endHour,
    required this.hourHeight,
    required this.onEdit,
  });

  final WorkbenchController controller;
  final DateTime day;
  final DateTime now;
  final int startHour;
  final int endHour;
  final double hourHeight;
  final ValueChanged<WorkspaceRecord> onEdit;

  @override
  Widget build(BuildContext context) {
    final blocks = controller.timeBlocksForDay(day);
    final conflicts = _conflictingIds(blocks);
    return DragTarget<WorkspaceRecord>(
      onAcceptWithDetails: (details) {
        final source = details.data;
        final sourceStart = source.scheduledFor!;
        final target = DateTime(
          day.year,
          day.month,
          day.day,
          sourceStart.hour,
          sourceStart.minute,
        );
        controller.updateTimeBlock(
          block: source,
          start: target,
          minutes: (source.data['durationMinutes'] as num?)?.toInt() ?? 25,
        );
      },
      builder: (context, candidateData, _) => Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: candidateData.isNotEmpty
                    ? Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.06)
                    : Colors.transparent,
                border: Border(left: BorderSide(color: context.tokens.divider)),
              ),
              child: Column(
                children: [
                  for (var hour = startHour; hour < endHour; hour++)
                    Container(
                      height: hourHeight,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: context.tokens.divider),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          for (final block in blocks)
            Positioned(
              top: (_logicalHour(block.scheduledFor!) - startHour) * hourHeight,
              left: 3,
              right: 3,
              height: math.max(
                32,
                ((block.data['durationMinutes'] as num?)?.toInt() ?? 25) /
                    60 *
                    hourHeight,
              ),
              child: LongPressDraggable<WorkspaceRecord>(
                data: block,
                feedback: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 180,
                    child: _BlockTile(
                      block: block,
                      conflict: conflicts.contains(block.id),
                      onTap: null,
                    ),
                  ),
                ),
                childWhenDragging: Opacity(
                  opacity: 0.28,
                  child: _BlockTile(
                    block: block,
                    conflict: conflicts.contains(block.id),
                    onTap: null,
                  ),
                ),
                child: _BlockTile(
                  block: block,
                  conflict: conflicts.contains(block.id),
                  onTap: () => onEdit(block),
                ),
              ),
            ),
          if (isSameDay(day, now) &&
              _logicalHour(now) >= startHour &&
              _logicalHour(now) <= endHour)
            Positioned(
              top: (_logicalHour(now) - startHour) * hourHeight,
              left: 0,
              right: 0,
              child: Semantics(
                label: '当前时间',
                child: Container(
                  height: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BlockTile extends StatelessWidget {
  const _BlockTile({
    required this.block,
    required this.conflict,
    required this.onTap,
  });
  final WorkspaceRecord block;
  final bool conflict;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: conflict ? '${block.title}，时间冲突' : null,
      button: onTap != null,
      excludeSemantics: conflict,
      child: Material(
        color: conflict
            ? context.tokens.rewardContainer
            : Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(5),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(5),
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 5, 6, 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              border: Border(
                left: BorderSide(
                  color: conflict
                      ? context.tokens.reward
                      : Theme.of(context).colorScheme.primary,
                  width: 3,
                ),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final showConflictLabel =
                    conflict && constraints.maxHeight >= 32;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      block.title,
                      maxLines: showConflictLabel ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: conflict
                            ? Theme.of(context).colorScheme.onTertiaryContainer
                            : Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    if (showConflictLabel)
                      Text(
                        '冲突',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: context.tokens.reward,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileWeek extends StatelessWidget {
  const _MobileWeek({
    required this.controller,
    required this.days,
    required this.selectedDay,
    required this.onSelected,
    required this.onEdit,
  });
  final WorkbenchController controller;
  final List<DateTime> days;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onSelected;
  final ValueChanged<WorkspaceRecord> onEdit;

  @override
  Widget build(BuildContext context) {
    final blocks = controller.timeBlocksForDay(selectedDay);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 132),
      children: [
        SizedBox(
          height: 68,
          child: Row(
            children: [
              for (final day in days)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: InkWell(
                      onTap: () => onSelected(day),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSameDay(day, selectedDay)
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSameDay(day, selectedDay)
                                ? Theme.of(context).colorScheme.primary
                                : context.tokens.divider,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _weekday(day.weekday),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            NumericText(
                              '${day.day}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        SectionHeading(
          title: formatFullDate(selectedDay),
          scale: '${blocks.length.toString().padLeft(2, '0')} BLOCKS',
        ),
        if (blocks.isEmpty)
          const EmptyState(
            icon: Icons.calendar_today_outlined,
            title: '这一天没有时间块',
            message: '使用右上角新增并选择精确时间。',
          )
        else
          LogSurface(
            child: Column(
              children: [
                for (var index = 0; index < blocks.length; index++) ...[
                  ListTile(
                    leading: SizedBox(
                      width: 46,
                      child: NumericText(
                        formatTime(blocks[index].scheduledFor!),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: context.tokens.reward,
                        ),
                      ),
                    ),
                    title: Text(blocks[index].title),
                    subtitle: Text(
                      '${blocks[index].data['durationMinutes'] ?? 25} 分钟',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => onEdit(blocks[index]),
                  ),
                  if (index < blocks.length - 1) const Divider(),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _BlockDialogResult {
  const _BlockDialogResult({
    required this.task,
    required this.start,
    required this.minutes,
    this.delete = false,
  });
  final WorkspaceRecord task;
  final DateTime start;
  final int minutes;
  final bool delete;
}

Future<_BlockDialogResult?> _showBlockDialog(
  BuildContext context, {
  required String title,
  required List<WorkspaceRecord> tasks,
  required WorkspaceRecord initialTask,
  required DateTime initialStart,
  required int initialMinutes,
  bool allowDelete = false,
}) {
  var task = initialTask;
  var start = initialStart;
  var minutes = initialMinutes;
  return showWorkbenchDialog<_BlockDialogResult>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 430,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<WorkspaceRecord>(
                initialValue: task,
                decoration: const InputDecoration(labelText: '任务'),
                items: tasks
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
                onChanged: tasks.length == 1
                    ? null
                    : (value) => setState(() => task = value!),
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule),
                title: NumericText(
                  '${formatShortDate(start)} ${formatTime(start)}',
                ),
                subtitle: const Text('开始时间'),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: start,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (date == null || !context.mounted) return;
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(start),
                  );
                  if (time != null) {
                    setState(
                      () => start = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        time.hour,
                        (time.minute / 5).round() * 5,
                      ),
                    );
                  }
                },
              ),
              DropdownButtonFormField<int>(
                initialValue: minutes,
                decoration: const InputDecoration(labelText: '时长'),
                items: const [15, 25, 30, 45, 50, 60, 90, 120]
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text('$value 分钟'),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => minutes = value!),
              ),
            ],
          ),
        ),
        actions: [
          if (allowDelete)
            TextButton(
              onPressed: () => Navigator.pop(
                context,
                _BlockDialogResult(
                  task: task,
                  start: start,
                  minutes: minutes,
                  delete: true,
                ),
              ),
              child: const Text('删除'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              _BlockDialogResult(task: task, start: start, minutes: minutes),
            ),
            child: const Text('保存'),
          ),
        ],
      ),
    ),
  );
}

DateTime _startOfWeek(DateTime day) {
  final value = startOfDay(day);
  return value.subtract(Duration(days: value.weekday - 1));
}

double _logicalHour(DateTime value) =>
    (value.hour < 4 ? value.hour + 24 : value.hour) + value.minute / 60;

String _weekday(int value) =>
    const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][value - 1];

Set<String> _conflictingIds(List<WorkspaceRecord> blocks) {
  final conflicts = <String>{};
  for (var left = 0; left < blocks.length; left++) {
    final leftStart = blocks[left].scheduledFor!;
    final leftEnd = leftStart.add(
      Duration(
        minutes: (blocks[left].data['durationMinutes'] as num?)?.toInt() ?? 25,
      ),
    );
    for (var right = left + 1; right < blocks.length; right++) {
      final rightStart = blocks[right].scheduledFor!;
      final rightEnd = rightStart.add(
        Duration(
          minutes:
              (blocks[right].data['durationMinutes'] as num?)?.toInt() ?? 25,
        ),
      );
      if (leftStart.isBefore(rightEnd) && rightStart.isBefore(leftEnd)) {
        conflicts.add(blocks[left].id);
        conflicts.add(blocks[right].id);
      }
    }
  }
  return conflicts;
}
