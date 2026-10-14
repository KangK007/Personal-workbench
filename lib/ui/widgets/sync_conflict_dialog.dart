import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/models/workspace_record.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../state/workbench_controller.dart';
import 'common.dart';

Future<bool> showSyncConflictDialog({
  required BuildContext context,
  required WorkbenchController controller,
  required WorkspaceRecord conflictCopy,
}) async =>
    await showWorkbenchDialog<bool>(
      context: context,
      builder: (context) => _SyncConflictDialog(
        controller: controller,
        conflictCopy: conflictCopy,
      ),
    ) ??
    false;

enum _ConflictChoice { cloud, local }

class _SyncDifference {
  const _SyncDifference(this.label, this.cloud, this.local);

  final String label;
  final String cloud;
  final String local;
}

class _SyncConflictDialog extends StatefulWidget {
  const _SyncConflictDialog({
    required this.controller,
    required this.conflictCopy,
  });

  final WorkbenchController controller;
  final WorkspaceRecord conflictCopy;

  @override
  State<_SyncConflictDialog> createState() => _SyncConflictDialogState();
}

class _SyncConflictDialogState extends State<_SyncConflictDialog> {
  _ConflictChoice? choice;
  bool saving = false;
  String? error;

  WorkspaceRecord? get original {
    final sourceId = widget.conflictCopy.data['conflictSourceId'];
    for (final record in widget.controller.activeRecords) {
      if (record.id == sourceId && record.kind == widget.conflictCopy.kind) {
        return record;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final compact = viewport.width < 600 || viewport.height < 560;
    final body = _body(context);
    final actions = Wrap(
      alignment: WrapAlignment.end,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context, false),
          child: const Text('继续保留'),
        ),
        FilledButton(
          onPressed: choice == null || original == null || saving
              ? null
              : _resolve,
          child: saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('确认采用所选版本'),
        ),
      ],
    );
    if (compact) {
      return Dialog.fullscreen(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: '关闭冲突对照',
                      onPressed: saving ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        '解决同步冲突',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(child: body),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    top: BorderSide(color: context.tokens.divider),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: actions,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final differenceCount = original == null
        ? 0
        : _differences(original!, widget.conflictCopy).length;
    return AlertDialog(
      title: const Text('解决同步冲突'),
      content: SizedBox(
        width: 700,
        height: (260.0 + differenceCount * 110).clamp(
          300.0,
          MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: body,
      ),
      actions: [actions],
    );
  }

  Widget _body(BuildContext context) {
    final source = original;
    final differences = source == null
        ? const <_SyncDifference>[]
        : _differences(source, widget.conflictCopy);
    final teal = context.accents.teal.color;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LogSurface(
            accent: teal,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.file_copy_outlined, color: teal),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    source == null
                        ? '原记录已不存在。冲突副本暂时保留，请先检查本地数据。'
                        : '同步时本地与云端同时修改了这条记录。请对照差异，再选择最终保留的版本。',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          if (source != null) ...[
            const SizedBox(height: AppSpacing.xl),
            Text('差异字段', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            if (differences.isEmpty)
              const Text('两版可见字段一致，仍可选择要保留的记录。')
            else
              for (final difference in differences) ...[
                Text(
                  difference.label,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cards = [
                      _valueCard(context, '云端当前版本', difference.cloud),
                      _valueCard(context, '本地冲突副本', difference.local),
                    ];
                    if (constraints.maxWidth < 560) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          cards.first,
                          const SizedBox(height: AppSpacing.sm),
                          cards.last,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: cards.first),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(child: cards.last),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            const SizedBox(height: AppSpacing.sm),
            Text('选择保留版本', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                ChoiceChip(
                  label: const Text('云端当前版本'),
                  selected: choice == _ConflictChoice.cloud,
                  onSelected: saving
                      ? null
                      : (_) => setState(() => choice = _ConflictChoice.cloud),
                ),
                ChoiceChip(
                  label: const Text('本地冲突副本'),
                  selected: choice == _ConflictChoice.local,
                  onSelected: saving
                      ? null
                      : (_) => setState(() => choice = _ConflictChoice.local),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '确认后，未采用的冲突副本会进入回收站；采用本地版时，原记录会更新为本地内容。',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontSize: 13),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _valueCard(BuildContext context, String source, String value) =>
      LogSurface(
        accent: context.accents.teal.color,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(source, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: AppSpacing.xs),
            SelectableText(
              value.isEmpty ? '空' : value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontSize: 15),
            ),
          ],
        ),
      );

  Future<void> _resolve() async {
    if (saving || choice == null) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.controller.resolveSyncConflict(
        widget.conflictCopy,
        useLocalCopy: choice == _ConflictChoice.local,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => error = '保存解决结果失败，当前选择已保留，请重试。');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}

List<_SyncDifference> _differences(
  WorkspaceRecord cloud,
  WorkspaceRecord local,
) {
  final cloudValues = _values(cloud);
  final localValues = _values(local, conflictCopy: true);
  return [
    for (final label in {...cloudValues.keys, ...localValues.keys})
      if (cloudValues[label] != localValues[label])
        _SyncDifference(
          label,
          cloudValues[label] ?? '无',
          localValues[label] ?? '无',
        ),
  ];
}

Map<String, String> _values(
  WorkspaceRecord record, {
  bool conflictCopy = false,
}) {
  final data = Map<String, dynamic>.from(record.data)
    ..remove('conflictSourceId');
  final values = <String, String>{
    '标题': conflictCopy
        ? record.title.replaceFirst(RegExp(r'（冲突副本）$'), '')
        : record.title,
    '正文': record.body,
    '状态': record.status,
    '计划时间': record.scheduledFor == null
        ? '无'
        : formatDateTime(record.scheduledFor!),
    '截止时间': record.dueAt == null ? '无' : formatDateTime(record.dueAt!),
    '所属项目': record.projectId ?? '无',
    '上级记录': record.parentId ?? '无',
    '标签':
        (conflictCopy ? record.tags.where((tag) => tag != '同步冲突') : record.tags)
            .join('、'),
    '收藏': record.favorite ? '是' : '否',
  };
  final keys = data.keys.toList()..sort();
  for (final key in keys) {
    final value = data[key];
    values['详细数据 · $key'] = value == null
        ? '无'
        : value is String
        ? value
        : jsonEncode(value);
  }
  return values;
}
