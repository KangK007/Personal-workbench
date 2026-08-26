import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/workspace_record.dart';
import '../../core/theme/app_theme.dart';
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
  final textController = TextEditingController();
  late RecordKind kind;
  bool saving = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    kind = widget.initialKind;
  }

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
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
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                tooltip: '关闭',
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            kind == RecordKind.task ? '先写标题，其他信息稍后补充。' : '先记下来，之后可以继续完善。',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.tokens.mutedText),
          ),
          const SizedBox(height: 12),
          ExternalField(
            label: '类型',
            child: DropdownButtonFormField<RecordKind>(
              initialValue: kind,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: const [
                DropdownMenuItem(value: RecordKind.task, child: Text('任务')),
                DropdownMenuItem(value: RecordKind.note, child: Text('笔记')),
                DropdownMenuItem(value: RecordKind.diary, child: Text('今日记录')),
                DropdownMenuItem(value: RecordKind.link, child: Text('链接')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => kind = value);
              },
            ),
          ),
          const SizedBox(height: 16),
          ExternalField(
            label: kind == RecordKind.link ? '网页或云盘链接' : '写下内容',
            child: TextField(
              controller: textController,
              autofocus: true,
              inputFormatters: [LengthLimitingTextInputFormatter(2000)],
              minLines: kind == RecordKind.note || kind == RecordKind.diary
                  ? 3
                  : 1,
              maxLines: 6,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: kind == RecordKind.task ? '例如：整理本周实验记录' : null,
                prefixIcon: Icon(iconForKind(kind)),
              ),
              onSubmitted: (_) {
                if (kind == RecordKind.task || kind == RecordKind.link) _save();
              },
              onChanged: (_) {
                if (errorMessage != null) setState(() => errorMessage = null);
              },
            ),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 18,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (kind != RecordKind.diary)
                TextButton(
                  onPressed: saving ? null : _openDetails,
                  child: const Text('完善信息'),
                ),
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: saving ? null : _save,
                icon: saving
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: const Text('收下'),
              ),
            ],
          ),
        ],
      ),
    );
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
        scheduledFor: widget.initialScheduledFor,
        projectId: widget.initialProjectId,
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
      initialScheduledFor: widget.initialScheduledFor,
      initialProjectId: widget.initialProjectId,
      initialStatus: widget.initialStatus,
    );
    if (result != null && mounted) Navigator.pop(context);
  }
}
