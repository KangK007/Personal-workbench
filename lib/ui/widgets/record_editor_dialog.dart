import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/workspace_record.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../state/workbench_controller.dart';
import 'common.dart';

Future<WorkspaceRecord?> showRecordEditor(
  BuildContext context,
  WorkbenchController controller, {
  required RecordKind kind,
  WorkspaceRecord? record,
  String? initialTitle,
  String? initialBody,
  String? initialProjectId,
  String? initialParentId,
  DateTime? initialScheduledFor,
  String? initialStatus,
}) {
  return showWorkbenchDialog<WorkspaceRecord>(
    context: context,
    builder: (context) => RecordEditorDialog(
      controller: controller,
      kind: kind,
      record: record,
      initialTitle: initialTitle,
      initialBody: initialBody,
      initialProjectId: initialProjectId,
      initialParentId: initialParentId,
      initialScheduledFor: initialScheduledFor,
      initialStatus: initialStatus,
    ),
  );
}

class RecordEditorDialog extends StatefulWidget {
  const RecordEditorDialog({
    super.key,
    required this.controller,
    required this.kind,
    this.record,
    this.initialTitle,
    this.initialBody,
    this.initialProjectId,
    this.initialParentId,
    this.initialScheduledFor,
    this.initialStatus,
  });

  final WorkbenchController controller;
  final RecordKind kind;
  final WorkspaceRecord? record;
  final String? initialTitle;
  final String? initialBody;
  final String? initialProjectId;
  final String? initialParentId;
  final DateTime? initialScheduledFor;
  final String? initialStatus;

  @override
  State<RecordEditorDialog> createState() => _RecordEditorDialogState();
}

class _RecordEditorDialogState extends State<RecordEditorDialog> {
  late final TextEditingController titleController;
  late final TextEditingController bodyController;
  late final TextEditingController tagsController;
  late final TextEditingController estimateController;
  late final TextEditingController completionWindowController;
  late final TextEditingController urlController;
  late final TextEditingController ctdpTriggerController;
  late final TextEditingController ctdpSessionController;
  late final TextEditingController ctdpDelayController;
  late final TextEditingController ctdpAuxSignalController;
  late final TextEditingController ctdpAuxCompletionController;
  late final TextEditingController ctdpMinimumController;
  late final TextEditingController ctdpGroupHoursController;
  late final TextEditingController rsipTriggerController;
  late final TextEditingController rsipMinimumController;
  late final TextEditingController rsipRuleController;
  late final TextEditingController rsipGroupController;
  late final TextEditingController rsipTimerController;
  late String status;
  late String recurrence;
  late String frequency;
  late int priority;
  late bool favorite;
  late bool protocolEnabled;
  late bool ctdpDurationless;
  late bool rsipUseTimer;
  late String ctdpUnitType;
  DateTime? date;
  DateTime? taskDueAt;
  DateTime? recurrenceEndAt;
  late Set<int> recurrenceWeekdays;
  String? projectId;
  String? rsipParentId;
  String? ctdpParentId;
  bool saving = false;
  late bool showMoreOptions;
  bool showTitleError = false;
  bool showCtdpTriggerError = false;
  bool showRsipMinimumError = false;
  String? formError;

  bool get isTask => widget.kind == RecordKind.task;
  bool get isGoal => widget.kind == RecordKind.goal;
  bool get isMilestone => widget.kind == RecordKind.milestone;
  bool get isHabit => widget.kind == RecordKind.habit;
  bool get isLink => widget.kind == RecordKind.link;

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    titleController = TextEditingController(
      text: record?.title ?? widget.initialTitle ?? '',
    );
    bodyController = TextEditingController(
      text: record?.body ?? widget.initialBody ?? '',
    );
    tagsController = TextEditingController(text: record?.tags.join(', ') ?? '');
    estimateController = TextEditingController(
      text: record == null || record.estimatedMinutes == 0
          ? ''
          : '${record.estimatedMinutes}',
    );
    completionWindowController = TextEditingController(
      text:
          '${(record?.data['completionWindowMinutes'] as num?)?.toInt() ?? 1440}',
    );
    urlController = TextEditingController(
      text: record?.data['url']?.toString() ?? '',
    );
    ctdpTriggerController = TextEditingController(
      text: record?.ctdpTrigger ?? '',
    );
    ctdpSessionController = TextEditingController(
      text:
          '${record?.ctdpSessionMinutes == 0 ? 25 : record?.ctdpSessionMinutes ?? 25}',
    );
    ctdpDelayController = TextEditingController(
      text: '${record?.ctdpDelayMinutes ?? 15}',
    );
    ctdpAuxSignalController = TextEditingController(
      text: record?.ctdpAuxSignal ?? '',
    );
    ctdpAuxCompletionController = TextEditingController(
      text: record?.ctdpAuxCompletionTrigger ?? '',
    );
    ctdpMinimumController = TextEditingController(
      text: '${record?.ctdpMinimumMinutes ?? 0}',
    );
    ctdpGroupHoursController = TextEditingController(
      text: '${record?.ctdpGroupTimeLimitHours ?? 0}',
    );
    rsipTriggerController = TextEditingController(
      text: record?.rsipTrigger ?? '',
    );
    rsipMinimumController = TextEditingController(
      text: record?.rsipMinimumAction ?? '',
    );
    rsipRuleController = TextEditingController(text: record?.rsipRule ?? '');
    rsipGroupController = TextEditingController(
      text: record?.rsipGroup ?? '默认国策组',
    );
    rsipTimerController = TextEditingController(
      text: '${record?.rsipTimerMinutes ?? 1}',
    );
    status =
        record?.status ??
        widget.initialStatus ??
        (isTask ? WorkStatus.inbox : WorkStatus.todo);
    recurrence = record?.data['recurrence']?.toString() ?? 'none';
    frequency = record?.data['frequency']?.toString() ?? 'daily';
    priority = record?.priority ?? 0;
    favorite = record?.favorite ?? false;
    protocolEnabled = record != null
        ? (isTask
              ? record.hasCtdpProtocol
              : isHabit
              ? record.hasRsipProtocol
              : false)
        : false;
    ctdpDurationless = record?.ctdpIsDurationless ?? false;
    ctdpUnitType = record?.ctdpUnitType ?? 'unit';
    rsipUseTimer = record?.rsipUseTimer ?? false;
    date = isGoal || isMilestone
        ? record?.dueAt
        : record?.scheduledFor ?? widget.initialScheduledFor;
    taskDueAt = isTask ? record?.dueAt : null;
    recurrenceEndAt = DateTime.tryParse(
      record?.data['recurrenceEndAt']?.toString() ?? '',
    )?.toLocal();
    recurrenceWeekdays =
        (record?.data['recurrenceWeekdays'] as List<dynamic>? ?? const [])
            .map((value) => (value as num).toInt())
            .where(
              (value) => value >= DateTime.monday && value <= DateTime.sunday,
            )
            .toSet();
    projectId = record?.projectId ?? widget.initialProjectId;
    rsipParentId = record?.parentId ?? widget.initialParentId;
    final candidateCtdpParent = record?.parentId ?? widget.initialParentId;
    ctdpParentId =
        candidateCtdpParent != null &&
            widget.controller.ctdpTasks.any(
              (task) => task.id == candidateCtdpParent && task.ctdpIsGroup,
            )
        ? candidateCtdpParent
        : null;
    final existingProtocol = protocolEnabled;
    showMoreOptions =
        record != null &&
        !(existingProtocol && !widget.controller.advancedFeaturesEnabled);
  }

  @override
  void dispose() {
    titleController.dispose();
    bodyController.dispose();
    tagsController.dispose();
    estimateController.dispose();
    completionWindowController.dispose();
    urlController.dispose();
    ctdpTriggerController.dispose();
    ctdpSessionController.dispose();
    ctdpDelayController.dispose();
    ctdpAuxSignalController.dispose();
    ctdpAuxCompletionController.dispose();
    ctdpMinimumController.dispose();
    ctdpGroupHoursController.dispose();
    rsipTriggerController.dispose();
    rsipMinimumController.dispose();
    rsipRuleController.dispose();
    rsipGroupController.dispose();
    rsipTimerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projects = widget.controller.projects;
    final ctdpPrecedents =
        (widget.record?.data['ctdpPrecedents'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .where((item) => item.isNotEmpty)
            .toList(growable: false);
    final ctdpGroups = widget.controller.ctdpTasks
        .where(
          (task) =>
              task.ctdpIsGroup &&
              task.id != widget.record?.id &&
              widget.controller.canUseCtdpParent(
                recordId: widget.record?.id ?? '',
                parentId: task.id,
              ),
        )
        .toList(growable: false);
    final rsipParents = widget.controller.activeRsipHabits
        .where(
          (habit) =>
              habit.id != widget.record?.id &&
              widget.controller.canUseRsipParent(
                recordId: widget.record?.id ?? '',
                parentId: habit.id,
              ),
        )
        .toList();
    if (rsipParentId != null &&
        !rsipParents.any((habit) => habit.id == rsipParentId)) {
      for (final habit in widget.controller.habits) {
        if (habit.id == rsipParentId) {
          rsipParents.add(habit);
          break;
        }
      }
    }
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    final editorTitle = widget.record == null
        ? '新建${widget.kind.label}'
        : '编辑${widget.kind.label}';
    final editorContent = SingleChildScrollView(
      padding: compact
          ? const EdgeInsets.fromLTRB(16, 12, 16, 24)
          : EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExternalField(
            label: '标题',
            child: TextField(
              controller: titleController,
              autofocus: true,
              inputFormatters: [LengthLimitingTextInputFormatter(200)],
              textInputAction: TextInputAction.next,
              onChanged: (_) {
                if (showTitleError || formError != null) {
                  setState(() {
                    showTitleError = false;
                    formError = null;
                  });
                }
              },
              decoration: InputDecoration(
                errorText: showTitleError ? '请输入标题' : null,
              ),
            ),
          ),
          if (formError != null) ...[
            const SizedBox(height: 10),
            Semantics(
              liveRegion: true,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 18,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(formError!)),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          ExternalField(
            label: isHabit ? '执行说明' : '说明',
            child: TextField(
              controller: bodyController,
              minLines: widget.kind == RecordKind.note ? 6 : 3,
              maxLines: 12,
              inputFormatters: [LengthLimitingTextInputFormatter(5000)],
              decoration: InputDecoration(alignLabelWithHint: true),
            ),
          ),
          if (isTask || isHabit) ...[
            const SizedBox(height: 8),
            if (showMoreOptions &&
                (widget.controller.advancedFeaturesEnabled ||
                    (widget.record != null &&
                        (widget.record!.hasCtdpProtocol ||
                            widget.record!.hasRsipProtocol))))
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(isTask ? '启用 CTDP 任务协议' : '启用 RSIP 习惯协议'),
                subtitle: Text(isTask ? '触发标志、预约缓冲与主链记录' : '最小动作、父节点与递归熄灭'),
                value: protocolEnabled,
                onChanged: (value) => setState(() {
                  protocolEnabled = value;
                  showCtdpTriggerError = false;
                  showRsipMinimumError = false;
                  formError = null;
                }),
              ),
            if (!showMoreOptions)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => showMoreOptions = true),
                  icon: const Icon(Icons.tune_outlined),
                  label: Text(
                    widget.record != null && protocolEnabled
                        ? '此记录已启用高级规则'
                        : '补充更多信息',
                  ),
                ),
              ),
          ],
          if (isLink) ...[
            const SizedBox(height: 12),
            ExternalField(
              label: '网页或云盘链接',
              child: TextField(
                controller: urlController,
                keyboardType: TextInputType.url,
                inputFormatters: [LengthLimitingTextInputFormatter(2048)],
                onChanged: (_) {
                  if (formError != null) setState(() => formError = null);
                },
                decoration: const InputDecoration(prefixIcon: Icon(Icons.link)),
              ),
            ),
          ],
          if (showMoreOptions &&
              (isTask || widget.kind == RecordKind.note || isLink)) ...[
            const SizedBox(height: 12),
            ExternalField(
              label: '关联项目',
              child: DropdownButtonFormField<String?>(
                initialValue: projectId,
                decoration: const InputDecoration(),
                items: [
                  const DropdownMenuItem(value: null, child: Text('不关联项目')),
                  ...projects.map(
                    (project) => DropdownMenuItem(
                      value: project.id,
                      child: Text(
                        project.title,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => projectId = value),
              ),
            ),
          ],
          if (isTask && showMoreOptions) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ExternalField(
                    label: '状态',
                    child: DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(),
                      items: const [
                        DropdownMenuItem(
                          value: WorkStatus.inbox,
                          child: Text('收集箱'),
                        ),
                        DropdownMenuItem(
                          value: WorkStatus.todo,
                          child: Text('待办'),
                        ),
                        DropdownMenuItem(
                          value: WorkStatus.doing,
                          child: Text('进行中'),
                        ),
                        DropdownMenuItem(
                          value: WorkStatus.done,
                          child: Text('已完成'),
                        ),
                        DropdownMenuItem(
                          value: WorkStatus.cancelled,
                          child: Text('已取消'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => status = value);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ExternalField(
                    label: '优先级',
                    child: DropdownButtonFormField<int>(
                      initialValue: priority,
                      decoration: const InputDecoration(),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('普通')),
                        DropdownMenuItem(value: 1, child: Text('低')),
                        DropdownMenuItem(value: 2, child: Text('中')),
                        DropdownMenuItem(value: 3, child: Text('高')),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => priority = value);
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ExternalField(
                    label: '预计分钟',
                    child: TextField(
                      controller: estimateController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(suffixText: 'min'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ExternalField(
                    label: '循环',
                    child: DropdownButtonFormField<String>(
                      initialValue: recurrence,
                      decoration: const InputDecoration(),
                      items: const [
                        DropdownMenuItem(value: 'none', child: Text('不循环')),
                        DropdownMenuItem(value: 'daily', child: Text('每天')),
                        DropdownMenuItem(value: 'weekdays', child: Text('工作日')),
                        DropdownMenuItem(value: 'weekly', child: Text('每周')),
                        DropdownMenuItem(value: 'monthly', child: Text('每月')),
                        DropdownMenuItem(value: 'yearly', child: Text('每年')),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => recurrence = value);
                      },
                    ),
                  ),
                ),
              ],
            ),
            if (recurrence == 'weekly') ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '每周执行日',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const SizedBox(height: 6),
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
                      selected: recurrenceWeekdays.contains(value.$1),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          recurrenceWeekdays.add(value.$1);
                        } else {
                          recurrenceWeekdays.remove(value.$1);
                        }
                      }),
                    ),
                ],
              ),
            ],
            if (recurrence != 'none') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ExternalField(
                      label: '完成窗口',
                      child: TextField(
                        controller: completionWindowController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(suffixText: 'min'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ExternalField(
                      label: '周期结束',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppRadius.control),
                        onTap: _pickRecurrenceEnd,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            suffixIcon: recurrenceEndAt == null
                                ? null
                                : IconButton(
                                    onPressed: () =>
                                        setState(() => recurrenceEndAt = null),
                                    tooltip: '清除周期结束日期',
                                    icon: const Icon(Icons.close),
                                  ),
                          ),
                          child: Text(
                            recurrenceEndAt == null
                                ? '持续执行'
                                : formatShortDate(recurrenceEndAt!),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (protocolEnabled && showMoreOptions) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ExternalField(
                      label: 'CTDP 类型',
                      child: DropdownButtonFormField<String>(
                        initialValue: ctdpUnitType,
                        decoration: const InputDecoration(),
                        items: const [
                          DropdownMenuItem(value: 'unit', child: Text('执行单元')),
                          DropdownMenuItem(value: 'group', child: Text('任务组')),
                          DropdownMenuItem(
                            value: 'assault',
                            child: Text('突击单元'),
                          ),
                          DropdownMenuItem(value: 'recon', child: Text('侦察单元')),
                          DropdownMenuItem(
                            value: 'command',
                            child: Text('指挥单元'),
                          ),
                          DropdownMenuItem(
                            value: 'special_ops',
                            child: Text('特勤单元'),
                          ),
                          DropdownMenuItem(
                            value: 'engineering',
                            child: Text('工程单元'),
                          ),
                          DropdownMenuItem(
                            value: 'quartermaster',
                            child: Text('保障单元'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => ctdpUnitType = value);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ExternalField(
                      label: '所属任务组',
                      child: DropdownButtonFormField<String?>(
                        initialValue: ctdpParentId,
                        decoration: const InputDecoration(),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('不属于任务组'),
                          ),
                          ...ctdpGroups.map(
                            (group) => DropdownMenuItem<String?>(
                              value: group.id,
                              child: Text(
                                group.title,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => ctdpParentId = value),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ExternalField(
                label: '触发标志',
                child: TextField(
                  controller: ctdpTriggerController,
                  onChanged: (_) {
                    if (showCtdpTriggerError) {
                      setState(() => showCtdpTriggerError = false);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: '例如：戴上蓝色帽子后开始',
                    prefixIcon: const Icon(Icons.touch_app_outlined),
                    errorText: showCtdpTriggerError ? '请先定义触发标志' : null,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ExternalField(
                      label: '辅助信号',
                      child: TextField(
                        controller: ctdpAuxSignalController,
                        decoration: const InputDecoration(hintText: '例如：闹钟响起'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ExternalField(
                      label: '辅助链完成条件',
                      child: TextField(
                        controller: ctdpAuxCompletionController,
                        decoration: const InputDecoration(
                          hintText: '例如：截止前执行触发标志',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ExternalField(
                      label: '主链时长',
                      child: TextField(
                        controller: ctdpSessionController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(suffixText: 'min'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ExternalField(
                      label: '预约缓冲',
                      child: TextField(
                        controller: ctdpDelayController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(suffixText: 'min'),
                      ),
                    ),
                  ),
                ],
              ),
              if (ctdpUnitType == 'group') ...[
                const SizedBox(height: 12),
                ExternalField(
                  label: '任务组完成时限',
                  child: TextField(
                    controller: ctdpGroupHoursController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      suffixText: 'h（0 表示不限时）',
                      prefixIcon: Icon(Icons.account_tree_outlined),
                    ),
                  ),
                ),
              ] else ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('使用正计时'),
                  subtitle: const Text('不设固定结束时间，可设置最低有效时长'),
                  value: ctdpDurationless,
                  onChanged: (value) =>
                      setState(() => ctdpDurationless = value),
                ),
                if (ctdpDurationless)
                  ExternalField(
                    label: '最低有效时长',
                    child: TextField(
                      controller: ctdpMinimumController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(suffixText: 'min'),
                    ),
                  ),
              ],
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '例外采用“下必为例”：失败重置主链，允许则写入永久判例。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (ctdpPrecedents.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final precedent in ctdpPrecedents)
                        Chip(
                          avatar: const Icon(Icons.gavel_outlined, size: 16),
                          label: Text(precedent),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ],
          if (isHabit && showMoreOptions) ...[
            const SizedBox(height: 12),
            ExternalField(
              label: '频率',
              child: DropdownButtonFormField<String>(
                initialValue: frequency,
                decoration: const InputDecoration(),
                items: const [
                  DropdownMenuItem(value: 'daily', child: Text('每天')),
                  DropdownMenuItem(value: 'weekdays', child: Text('工作日')),
                  DropdownMenuItem(value: 'weekly', child: Text('每周一次')),
                  DropdownMenuItem(value: 'monthly', child: Text('每月一次')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => frequency = value);
                },
              ),
            ),
            if (protocolEnabled) ...[
              const SizedBox(height: 12),
              ExternalField(
                label: '最小动作',
                child: TextField(
                  controller: rsipMinimumController,
                  onChanged: (_) {
                    if (showRsipMinimumError) {
                      setState(() => showRsipMinimumError = false);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: '例如：只读一页论文',
                    prefixIcon: const Icon(Icons.flag_outlined),
                    helperText: '写到状态很差时也能开始的程度',
                    errorText: showRsipMinimumError ? '请先定义最小动作' : null,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ExternalField(
                label: '触发条件',
                child: TextField(
                  controller: rsipTriggerController,
                  decoration: const InputDecoration(
                    hintText: '例如：晚饭后坐到书桌前',
                    prefixIcon: Icon(Icons.alt_route_outlined),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ExternalField(
                label: '精确规则',
                child: TextField(
                  controller: rsipRuleController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: '写清何时算完成、何时算失败，不留临场解释空间',
                    prefixIcon: Icon(Icons.rule_outlined),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ExternalField(
                label: '国策组',
                child: TextField(
                  controller: rsipGroupController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.folder_outlined),
                  ),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('最小动作计时'),
                subtitle: const Text('倒计时完成后才能结算本节点'),
                value: rsipUseTimer,
                onChanged: (value) => setState(() => rsipUseTimer = value),
              ),
              if (rsipUseTimer) ...[
                ExternalField(
                  label: '计时分钟',
                  child: TextField(
                    controller: rsipTimerController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(suffixText: 'min'),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              ExternalField(
                label: '父节点（国策树）',
                child: DropdownButtonFormField<String?>(
                  initialValue: rsipParentId,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.account_tree_outlined),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('根节点'),
                    ),
                    ...rsipParents.map(
                      (habit) => DropdownMenuItem<String?>(
                        value: habit.id,
                        child: Text(
                          habit.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => rsipParentId = value),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '每天最多新增一个节点；失败时熄灭当前节点及其子节点，内化进度保留。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ],
          if (isTask || isGoal || isMilestone) ...[
            const SizedBox(height: 12),
            ExternalField(
              label: isGoal || isMilestone ? '截止日期' : '安排日期',
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.control),
                onTap: _pickDate,
                child: InputDecorator(
                  decoration:
                      const InputDecoration(
                        prefixIcon: Icon(Icons.calendar_today_outlined),
                      ).copyWith(
                        suffixIcon: date == null
                            ? null
                            : IconButton(
                                onPressed: () => setState(() => date = null),
                                tooltip: '清除日期',
                                icon: const Icon(Icons.close),
                              ),
                      ),
                  child: Text(date == null ? '未设置' : formatShortDate(date!)),
                ),
              ),
            ),
          ],
          if (isTask && showMoreOptions) ...[
            const SizedBox(height: 12),
            ExternalField(
              label: '明确截止日期',
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.control),
                onTap: _pickTaskDueDate,
                child: InputDecorator(
                  decoration:
                      const InputDecoration(
                        prefixIcon: Icon(Icons.event_busy_outlined),
                      ).copyWith(
                        suffixIcon: taskDueAt == null
                            ? null
                            : IconButton(
                                onPressed: () =>
                                    setState(() => taskDueAt = null),
                                tooltip: '清除截止日期',
                                icon: const Icon(Icons.close),
                              ),
                      ),
                  child: Text(
                    taskDueAt == null ? '使用完成窗口' : formatShortDate(taskDueAt!),
                  ),
                ),
              ),
            ),
          ],
          if (showMoreOptions) ...[
            const SizedBox(height: 12),
            ExternalField(
              label: '标签',
              child: TextField(
                controller: tagsController,
                inputFormatters: [LengthLimitingTextInputFormatter(500)],
                decoration: const InputDecoration(hintText: '使用逗号分隔'),
              ),
            ),
          ],
          if (widget.kind == RecordKind.project ||
              widget.kind == RecordKind.note ||
              isGoal) ...[
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('收藏'),
              value: favorite,
              onChanged: (value) => setState(() => favorite = value),
            ),
          ],
        ],
      ),
    );
    final cancelAction = TextButton(
      onPressed: saving ? null : () => Navigator.pop(context),
      child: const Text('取消'),
    );
    final saveAction = FilledButton(
      onPressed: saving ? null : _save,
      child: saving
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(widget.record == null ? '创建${widget.kind.label}' : '保存修改'),
    );
    final heading = Text(editorTitle);
    if (compact) {
      return Dialog.fullscreen(
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            leading: IconButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              tooltip: '关闭',
              icon: const Icon(Icons.close),
            ),
            title: heading,
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1),
            ),
          ),
          body: SafeArea(top: false, child: editorContent),
          bottomNavigationBar: SafeArea(
            top: false,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(top: BorderSide(color: context.tokens.divider)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Row(
                  children: [
                    Expanded(child: cancelAction),
                    const SizedBox(width: 12),
                    Expanded(child: saveAction),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [heading, const SizedBox(height: 8), const Divider()],
      ),
      content: SizedBox(width: 560, child: editorContent),
      actions: [cancelAction, saveAction],
    );
  }

  Future<void> _pickDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: date ?? widget.controller.currentTime(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (result != null) setState(() => date = result);
  }

  Future<void> _pickTaskDueDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: taskDueAt ?? date ?? widget.controller.currentTime(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (result != null) {
      setState(() {
        taskDueAt = DateTime(result.year, result.month, result.day, 23, 59, 59);
      });
    }
  }

  Future<void> _pickRecurrenceEnd() async {
    final result = await showDatePicker(
      context: context,
      initialDate: recurrenceEndAt ?? date ?? widget.controller.currentTime(),
      firstDate: date ?? DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (result != null) setState(() => recurrenceEndAt = result);
  }

  Future<void> _save() async {
    final title = titleController.text.trim();
    final url = urlController.text.trim();
    final missingCtdpTrigger =
        isTask &&
        protocolEnabled &&
        ctdpUnitType != 'group' &&
        ctdpTriggerController.text.trim().isEmpty;
    final missingRsipMinimum =
        isHabit && protocolEnabled && rsipMinimumController.text.trim().isEmpty;
    if (title.isEmpty || missingCtdpTrigger || missingRsipMinimum) {
      setState(() {
        showTitleError = title.isEmpty;
        showCtdpTriggerError = missingCtdpTrigger;
        showRsipMinimumError = missingRsipMinimum;
        formError = null;
      });
      return;
    }
    if (isLink && !_isWebUrl(url)) {
      setState(() => formError = '请输入以 http:// 或 https:// 开头的有效链接');
      return;
    }
    final createsRsipNode =
        isHabit &&
        protocolEnabled &&
        (widget.record == null || !widget.record!.hasRsipProtocol);
    if (createsRsipNode &&
        !widget.controller.canAddRsipNode(excludingId: widget.record?.id)) {
      setState(() => formError = 'RSIP 每天最多新增一个习惯节点');
      return;
    }
    setState(() {
      saving = true;
      formError = null;
    });
    final tags = tagsController.text
        .split(RegExp(r'[,，;；]'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    final data = {
      ...?widget.record?.data,
      if (isTask) 'priority': priority,
      if (isTask)
        'estimatedMinutes': int.tryParse(estimateController.text.trim()) ?? 0,
      if (isTask) 'recurrence': recurrence,
      if (isTask) 'recurrenceWeekdays': recurrenceWeekdays.toList()..sort(),
      if (isTask) 'recurrenceEndAt': recurrenceEndAt?.toUtc().toIso8601String(),
      if (isTask)
        'completionWindowMinutes':
            int.tryParse(
              completionWindowController.text.trim(),
            )?.clamp(1, 525600) ??
            1440,
      if (isTask) 'recordType': widget.record?.data['recordType'],
      if (isHabit) 'frequency': frequency,
      if (isLink) 'url': url,
      if (isTask && protocolEnabled) ...{
        'protocol': 'ctdp',
        'ctdpUnitType': ctdpUnitType,
        'ctdpTrigger': ctdpTriggerController.text.trim(),
        'ctdpAuxSignal': ctdpAuxSignalController.text.trim(),
        'ctdpAuxCompletionTrigger': ctdpAuxCompletionController.text.trim(),
        'ctdpSessionMinutes':
            int.tryParse(ctdpSessionController.text.trim())?.clamp(1, 720) ??
            25,
        'ctdpDelayMinutes':
            int.tryParse(ctdpDelayController.text.trim())?.clamp(1, 120) ?? 15,
        'ctdpIsDurationless': ctdpDurationless,
        'ctdpMinimumMinutes':
            int.tryParse(ctdpMinimumController.text.trim())?.clamp(0, 720) ?? 0,
        'ctdpGroupTimeLimitHours':
            int.tryParse(ctdpGroupHoursController.text.trim())?.clamp(0, 720) ??
            0,
        'ctdpChainCount': widget.record?.ctdpChainCount ?? 0,
        'ctdpAuxChainCount': widget.record?.ctdpAuxChainCount ?? 0,
        'ctdpReservationCount': widget.record?.ctdpReservationCount ?? 0,
        'ctdpTotalCompletions': widget.record?.ctdpTotalCompletions ?? 0,
        'ctdpTotalFailures': widget.record?.ctdpTotalFailures ?? 0,
        'ctdpAuxFailures': widget.record?.ctdpAuxFailures ?? 0,
        'ctdpPrecedents':
            widget.record?.data['ctdpPrecedents'] ?? const <String>[],
      },
      if (isTask && !protocolEnabled) 'protocol': 'standard',
      if (isHabit && protocolEnabled) ...{
        'protocol': 'rsip',
        'rsipTrigger': rsipTriggerController.text.trim(),
        'rsipMinimumAction': rsipMinimumController.text.trim(),
        'rsipRule': rsipRuleController.text.trim(),
        'rsipGroup': rsipGroupController.text.trim().isEmpty
            ? '默认国策组'
            : rsipGroupController.text.trim(),
        'rsipUseTimer': rsipUseTimer,
        'rsipTimerMinutes':
            int.tryParse(rsipTimerController.text.trim())?.clamp(1, 180) ?? 1,
        'rsipActive': widget.record?.rsipActive ?? true,
        'rsipChainCount': widget.record?.rsipChainCount ?? 0,
        'rsipInternalization': widget.record?.rsipInternalization ?? 0,
        'rsipFailureCount': widget.record?.rsipFailureCount ?? 0,
        'rsipAddedAt':
            widget.record?.data['rsipAddedAt'] ??
            widget.controller.currentTime().toUtc().toIso8601String(),
      },
      if (isHabit && !protocolEnabled) 'protocol': 'standard',
    };
    final record = widget.record == null
        ? WorkspaceRecord.create(
            kind: widget.kind,
            title: title,
            body: bodyController.text.trim(),
            status: status,
            scheduledFor: isGoal || isMilestone ? null : date,
            dueAt: isGoal || isMilestone ? date : taskDueAt,
            projectId: projectId,
            parentId: isHabit
                ? rsipParentId
                : isTask && protocolEnabled
                ? ctdpParentId
                : widget.initialParentId,
            tags: tags,
            favorite: favorite,
            data: data,
          )
        : widget.record!.copyWith(
            title: title,
            body: bodyController.text.trim(),
            status: status,
            scheduledFor: isGoal || isMilestone
                ? widget.record!.scheduledFor
                : date,
            dueAt: isGoal || isMilestone ? date : taskDueAt,
            projectId: projectId,
            parentId: isHabit
                ? rsipParentId
                : isTask && protocolEnabled
                ? ctdpParentId
                : widget.record!.parentId,
            tags: tags,
            favorite: favorite,
            data: data,
          );
    try {
      if (widget.record == null) {
        await widget.controller.addRecord(record);
      } else if (isTask && _isRecurringTaskInstance(widget.record!)) {
        final scope = await _selectTaskEditScope();
        if (scope == null) {
          if (mounted) setState(() => saving = false);
          return;
        }
        await widget.controller.updateTaskWithScope(
          original: widget.record!,
          updated: record,
          scope: scope,
        );
      } else {
        await widget.controller.updateRecord(record);
      }
      if (!mounted) return;
      Navigator.pop(context, record);
    } catch (error, stackTrace) {
      debugPrint('Failed to save ${widget.kind.name}: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        saving = false;
        formError = '保存失败，内容仍保留在当前窗口，请稍后重试。';
      });
    }
  }

  bool _isRecurringTaskInstance(WorkspaceRecord record) {
    final definition = widget.controller.taskDefinitionFor(record);
    return definition != null &&
        TaskDefinition.fromRecord(definition).isRecurring;
  }

  Future<TaskEditScope?> _selectTaskEditScope() {
    return showWorkbenchDialog<TaskEditScope>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('修改周期任务'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, TaskEditScope.occurrence),
            child: const ListTile(
              leading: Icon(Icons.today_outlined),
              title: Text('仅修改本次'),
              subtitle: Text('只修改当前实例'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, TaskEditScope.future),
            child: const ListTile(
              leading: Icon(Icons.update_outlined),
              title: Text('修改本次及未来'),
              subtitle: Text('不改写此前实例和任何已结算历史'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, TaskEditScope.series),
            child: const ListTile(
              leading: Icon(Icons.repeat),
              title: Text('修改整个周期'),
              subtitle: Text('更新全部未结算实例，已结算历史保持不变'),
            ),
          ),
        ],
      ),
    );
  }

  bool _isWebUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }
}
