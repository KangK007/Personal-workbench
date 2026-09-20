import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/workspace_record.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../state/workbench_controller.dart';
import 'common.dart';
import 'record_editor_dialog.dart';

Future<void> showQuickCapture(
  BuildContext context,
  WorkbenchController controller, {
  RecordKind initialKind = RecordKind.task,
  DateTime? initialScheduledFor,
  String? initialProjectId,
  String? initialStatus,
}) async {
  final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
  if (compact) {
    await showWorkbenchSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => QuickCaptureSheet(
        controller: controller,
        initialKind: initialKind,
        initialScheduledFor: initialScheduledFor,
        initialProjectId: initialProjectId,
        initialStatus: initialStatus,
      ),
    );
  } else {
    await showWorkbenchDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: QuickCaptureSheet(
            controller: controller,
            initialKind: initialKind,
            initialScheduledFor: initialScheduledFor,
            initialProjectId: initialProjectId,
            initialStatus: initialStatus,
          ),
        ),
      ),
    );
  }
}

/// 快速捕获表单（方案 C 手机 1 规格）。
///
/// 形态与旧实现的差别是**整块换掉**，不是微调：
///
/// | | 旧实现 | 现在 |
/// |---|---|---|
/// | 输入 | `TextField` + `prefixIcon` | 独立输入卡（20 圆角 / 1.6px 主色淡边 / 底部工具行 + 实时字数） |
/// | 类型 | `DropdownButtonFormField` | 「这是」+ chip 行（选中 = 主色实心） |
/// | 目标 | 无（藏在二级弹窗） | 「放到」+ 选择行卡（32×32 图标块 + 主副标题 + 右侧动作） |
/// | 主操作 | 右下角 `TextButton` + `FilledButton` | 通栏 52px 主按钮 + 52×52 方形图标按钮 |
///
/// 两处**有意偏离**源稿，均为「不为了像而丢信息」：
/// 1. 标题保留「新增」而非「随手记」——本入口同时收任务/笔记/日记/链接，
///    叫「随手记」会把范围说窄。
/// 2. 主按钮保留「收下」而非「保存到收件箱」——从今日页唤起时它是直接落到
///    今天，并非进收件箱，写死「收件箱」会误导。
class QuickCaptureSheet extends StatefulWidget {
  const QuickCaptureSheet({
    super.key,
    required this.controller,
    this.initialKind = RecordKind.task,
    this.initialScheduledFor,
    this.initialProjectId,
    this.initialStatus,
  });

  final WorkbenchController controller;
  final RecordKind initialKind;
  final DateTime? initialScheduledFor;
  final String? initialProjectId;
  final String? initialStatus;

  @override
  State<QuickCaptureSheet> createState() => _QuickCaptureSheetState();
}

class _QuickCaptureSheetState extends State<QuickCaptureSheet> {
  /// chip 行呈现的可捕获类型。顺序即主次。
  static const _kindOptions = <RecordKind>[
    RecordKind.task,
    RecordKind.note,
    RecordKind.diary,
    RecordKind.link,
  ];

  static const _kindLabels = <RecordKind, String>{
    RecordKind.task: '任务',
    RecordKind.note: '笔记',
    RecordKind.diary: '今日记录',
    RecordKind.link: '链接',
  };

  final textController = TextEditingController();
  late RecordKind kind;
  bool saving = false;
  String? errorMessage;
  DateTime? scheduledFor;
  String? projectId;

  @override
  void initState() {
    super.initState();
    kind = widget.initialKind;
    scheduledFor = widget.initialScheduledFor;
    projectId = widget.initialProjectId;
  }

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }

  String? get _projectTitle {
    final id = projectId;
    if (id == null) return null;
    for (final project in widget.controller.projects) {
      if (project.id == id) return project.title;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final scheme = theme.colorScheme;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pageCompact,
        AppSpacing.lg,
        AppSpacing.pageCompact,
        AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '新增',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                tooltip: '关闭',
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Text(
            '想到什么先丢进来，稍后再整理',
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 12,
              color: tokens.inkFaint,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ─── 输入卡：这一屏的主角 ───
          _CaptureInputCard(
            controller: textController,
            hint: kind == RecordKind.task ? '例如：整理本周实验记录' : '记下这一条…',
            charCount: textController.text.characters.length,
            onChanged: (_) => setState(() => errorMessage = null),
            onClear: textController.text.isEmpty
                ? null
                : () => setState(() {
                    textController.clear();
                    errorMessage = null;
                  }),
            onComplete: _openDetails,
          ),

          if (errorMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Semantics(
              liveRegion: true,
              child: Row(
                children: [
                  Icon(Icons.error_outline, size: 18, color: scheme.error),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      errorMessage!,
                      style: TextStyle(color: scheme.error),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ─── 这是 ───
          const _FieldLabel('这是'),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final option in _kindOptions)
                _CaptureChip(
                  label: _kindLabels[option]!,
                  icon: iconForKind(option),
                  selected: option == kind,
                  onTap: () => setState(() => kind = option),
                ),
            ],
          ),

          // ─── 放到 ───
          const _FieldLabel('放到'),
          _CaptureRowCard(
            icon: Icons.event_outlined,
            title: scheduledFor == null
                ? '未安排时间'
                : formatShortDate(scheduledFor!),
            subtitle: scheduledFor == null
                ? '点右侧「安排」选一个日期'
                : '计划时间 · ${formatTime(scheduledFor!)}',
            actionLabel: scheduledFor == null ? '安排' : '修改',
            onAction: _pickDate,
          ),
          const SizedBox(height: 9),
          _CaptureRowCard(
            icon: Icons.folder_outlined,
            title: _projectTitle ?? '未关联项目',
            subtitle: _projectTitle == null ? '也可以稍后在编辑里关联' : '项目',
            actionLabel: _projectTitle == null ? '选择' : '更换',
            onAction: _pickProject,
          ),

          const SizedBox(height: AppSpacing.xl),

          // ─── 主操作：通栏 52px + 方形图标按钮 ───
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: saving ? null : _save,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.card),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        fontFamily: AppFonts.body,
                      ),
                    ),
                    child: saving
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('收下'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _CaptureSquareIconButton(
                icon: Icons.tune,
                tooltip: '完善信息',
                onPressed: saving ? null : _openDetails,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final base = scheduledFor ?? widget.controller.currentTime();
    final picked = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: startOfDay(
        widget.controller.currentTime(),
      ).subtract(const Duration(days: 365)),
      lastDate: DateTime(base.year + 5),
    );
    if (picked == null || !mounted) return;
    setState(
      () => scheduledFor = DateTime(
        picked.year,
        picked.month,
        picked.day,
        base.hour,
        base.minute,
      ),
    );
  }

  Future<void> _pickProject() async {
    final projects = widget.controller.projects;
    final chosen = await showWorkbenchDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('关联项目'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('不关联项目'),
          ),
          for (final project in projects)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, project.id),
              child: Text(project.title),
            ),
        ],
      ),
    );
    if (chosen == null || !mounted) return;
    setState(() => projectId = chosen.isEmpty ? null : chosen);
  }

  Future<void> _save() async {
    setState(() {
      saving = true;
      errorMessage = null;
    });
    try {
      await widget.controller.quickCapture(
        kind: kind,
        text: textController.text,
        scheduledFor: scheduledFor,
        projectId: projectId,
        status: widget.initialStatus,
      );
      if (!mounted) return;
      Navigator.pop(context);
      showWorkbenchSnackBar(
        context,
        SnackBar(content: Text('${kind.label}已放入工作台')),
      );
    } on FormatException catch (exception) {
      if (!mounted) return;
      setState(() => errorMessage = exception.message.toString());
    } catch (error, stackTrace) {
      debugPrint('Quick capture failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() => errorMessage = '保存失败，内容仍保留在输入框中，请稍后重试。');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _openDetails() async {
    final title = textController.text.trim();
    if (title.isEmpty) {
      setState(() => errorMessage = '请先输入标题。');
      return;
    }
    final result = await showRecordEditor(
      context,
      widget.controller,
      kind: kind,
      initialTitle: title,
      initialScheduledFor: scheduledFor,
      initialProjectId: projectId,
      initialStatus: widget.initialStatus,
    );
    if (result != null && mounted) Navigator.pop(context);
  }
}

/// 「这是 / 放到」这类分区小标签（方案 C 的 `fld-lab`）。
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: 9),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w600,
        color: context.tokens.inkFaint,
      ),
    ),
  );
}

/// 输入卡：方案 C 里这一屏的主角。
///
/// 20 圆角 + 1.6px 主色淡边 + 底部工具行（左侧动作 + 右侧实时字数）。
/// 边框用主色淡色而非中性线，是为了让「正在输入的地方」在一屏里第一眼被找到。
class _CaptureInputCard extends StatelessWidget {
  const _CaptureInputCard({
    required this.controller,
    required this.hint,
    required this.charCount,
    required this.onChanged,
    required this.onComplete,
    this.onClear,
  });

  final TextEditingController controller;
  final String hint;
  final int charCount;
  final ValueChanged<String> onChanged;
  final VoidCallback onComplete;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final scheme = theme.colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 122),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md + 3,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: tokens.panel,
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(color: scheme.primaryContainer, width: 1.6),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.09),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            minLines: 2,
            maxLines: 6,
            inputFormatters: [LengthLimitingTextInputFormatter(2000)],
            textInputAction: TextInputAction.newline,
            onChanged: onChanged,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 14.5,
              height: 1.75,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 14.5,
                height: 1.75,
                color: tokens.inkFaint,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(height: 1, color: tokens.subtle),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _CaptureInlineAction(
                icon: Icons.tune,
                tooltip: '完善信息',
                onPressed: onComplete,
              ),
              if (onClear != null) ...[
                const SizedBox(width: AppSpacing.sm),
                _CaptureInlineAction(
                  icon: Icons.backspace_outlined,
                  tooltip: '清空输入',
                  onPressed: onClear,
                ),
              ],
              const Spacer(),
              Text(
                '$charCount 字',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 11,
                  color: tokens.inkFaint,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 输入卡底部的小图标按钮（30×30、圆角 12、主色淡底）。
class _CaptureInlineAction extends StatelessWidget {
  const _CaptureInlineAction({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: tokens.subtle,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.control),
          child: SizedBox(
            width: 30,
            height: 30,
            child: Icon(icon, size: 15, color: scheme.primary),
          ),
        ),
      ),
    );
  }
}

/// 类型 chip（方案 C 的「这是」行）。
///
/// 固定 48 高是刻意的：视觉上略高于源稿的 33，但换来 Android 端达标的触控目标，
/// 而 chip 行本来就是一屏里最容易误触的位置。
class _CaptureChip extends StatelessWidget {
  const _CaptureChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final scheme = Theme.of(context).colorScheme;
    final foreground = selected ? scheme.onPrimary : tokens.mutedText;
    return Material(
      color: selected ? scheme.primary : tokens.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        side: BorderSide(color: selected ? scheme.primary : tokens.panelBorder),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md + 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: foreground),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 「放到」选择行卡（方案 C 规格）：32×32 图标块 + 主副标题 + 右侧动作。
class _CaptureRowCard extends StatelessWidget {
  const _CaptureRowCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final scheme = theme.colorScheme;
    return Material(
      color: tokens.panel,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: tokens.panelBorder),
      ),
      child: InkWell(
        onTap: onAction,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg - 1,
            vertical: AppSpacing.md + 1,
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: tokens.subtle,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                child: Icon(icon, size: 16, color: scheme.primary),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 11,
                          color: tokens.inkFaint,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                actionLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 与主按钮同高的方形图标按钮（方案 C 的 `btn-ic`）。
class _CaptureSquareIconButton extends StatelessWidget {
  const _CaptureSquareIconButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: tokens.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: scheme.primaryContainer, width: 1.4),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(icon, size: 20, color: scheme.primary),
          ),
        ),
      ),
    );
  }
}
