import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/models/workspace_record.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../state/workbench_controller.dart';
import '../widgets/common.dart';
import '../widgets/batch_task_toolbar.dart';
import '../widgets/quick_capture_sheet.dart';
import '../widgets/record_editor_dialog.dart';
import '../widgets/task_row.dart';
import '../widgets/task_hierarchy.dart';
import '../widgets/solid_panel.dart';
import '../widgets/workbench_illustration.dart';

class InboxPage extends StatefulWidget {
  const InboxPage({
    super.key,
    required this.controller,
    this.showHeader = true,
  });

  final WorkbenchController controller;
  final bool showHeader;

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  final FocusNode _focusNode = FocusNode();
  final Set<String> _selectedIds = <String>{};
  bool _selectionMode = false;
  String? _selectionAnchorId;
  final Set<String> _collapsedTaskIds = <String>{};
  late List<WorkspaceRecord> _lastRecords;
  final Set<String> _incomingIds = {};
  final Map<String, ({WorkspaceRecord record, int position})> _exiting = {};
  final Map<String, Timer> _entryTimers = {};
  final Map<String, Timer> _exitTimers = {};
  bool _reducedMotion = false;

  @override
  void initState() {
    super.initState();
    _lastRecords = widget.controller.inboxRecords;
    widget.controller.addListener(_recordsChanged);
  }

  @override
  void didUpdateWidget(InboxPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_recordsChanged);
      _clearMotion();
      _lastRecords = widget.controller.inboxRecords;
      widget.controller.addListener(_recordsChanged);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (_reducedMotion) _clearMotion();
  }

  void _clearMotion() {
    for (final timer in [..._entryTimers.values, ..._exitTimers.values]) {
      timer.cancel();
    }
    _entryTimers.clear();
    _exitTimers.clear();
    _incomingIds.clear();
    _exiting.clear();
  }

  void _recordsChanged() {
    final next = widget.controller.inboxRecords;
    if (!mounted || listEquals(next, _lastRecords)) return;
    final previousIds = _lastRecords.map((record) => record.id).toSet();
    final nextIds = next.map((record) => record.id).toSet();
    if (!_reducedMotion) {
      for (final record in next) {
        _exitTimers.remove(record.id)?.cancel();
        _exiting.remove(record.id);
        if (!previousIds.contains(record.id)) {
          _incomingIds.add(record.id);
          _entryTimers.remove(record.id)?.cancel();
          _entryTimers[record.id] = Timer(AppMotion.standard, () {
            _entryTimers.remove(record.id);
            _incomingIds.remove(record.id);
          });
        }
      }
      for (var index = 0; index < _lastRecords.length; index++) {
        final record = _lastRecords[index];
        if (nextIds.contains(record.id)) continue;
        _exiting[record.id] = (record: record, position: index);
        _entryTimers.remove(record.id)?.cancel();
        _incomingIds.remove(record.id);
        _exitTimers.remove(record.id)?.cancel();
        _exitTimers[record.id] = Timer(const Duration(milliseconds: 160), () {
          _exitTimers.remove(record.id);
          if (mounted) setState(() => _exiting.remove(record.id));
        });
      }
    }
    setState(() => _lastRecords = next);
  }

  Future<void> _organizeRecord(WorkspaceRecord record) async {
    try {
      final current = widget.controller.latestRecordById(record);
      await widget.controller.updateRecord(current.withData('inbox', false));
      if (!mounted) return;
      showWorkbenchFeedback(
        context,
        '已整理',
        action: SnackBarAction(
          label: '撤销',
          onPressed: () => _undoOrganization(record),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      showWorkbenchFeedback(
        context,
        '整理失败，请重试。',
        action: SnackBarAction(
          label: '重试',
          onPressed: () => _organizeRecord(record),
        ),
      );
    }
  }

  Future<void> _undoOrganization(WorkspaceRecord record) async {
    try {
      final current = widget.controller.latestRecordById(record);
      if (current.isDeleted) throw const FormatException('记录已在回收站，无法撤销整理。');
      await widget.controller.updateRecord(current.withData('inbox', true));
      if (mounted) showWorkbenchFeedback(context, '已撤销整理');
    } on FormatException catch (error) {
      if (mounted) showWorkbenchFeedback(context, error.message);
    } catch (_) {
      if (!mounted) return;
      showWorkbenchFeedback(
        context,
        '撤销失败，请重试。',
        action: SnackBarAction(
          label: '重试',
          onPressed: () => _undoOrganization(record),
        ),
      );
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_recordsChanged);
    _clearMotion();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final records = widget.controller.inboxRecords;
    final presented = [...records];
    final exiting = _exiting.values.toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    for (final item in exiting) {
      presented.insert(item.position.clamp(0, presented.length), item.record);
    }
    final visibleTasks = records
        .where((record) => record.kind == RecordKind.task)
        .toList(growable: false);
    final selectedTasks = visibleTasks
        .where((task) => _selectedIds.contains(task.id))
        .toList(growable: false);
    final entries = buildTaskHierarchy(
      visibleTasks: presented
          .where((record) => record.kind == RecordKind.task)
          .toList(),
      allRecords: widget.controller.allRecords,
      collapsedIds: _collapsedTaskIds,
    );
    final displayRecords = <WorkspaceRecord>[];
    final emittedTaskIds = <String>{};
    final entryById = {for (final entry in entries) entry.task.id: entry};
    final entryIndexById = <String, int>{
      for (var index = 0; index < entries.length; index++)
        entries[index].task.id: index,
    };
    for (final record in presented) {
      if (record.kind != RecordKind.task) {
        displayRecords.add(record);
        continue;
      }
      if (emittedTaskIds.contains(record.id)) continue;
      final entryIndex = entryIndexById[record.id];
      if (entryIndex == null) continue;
      final entry = entries[entryIndex];
      if (entry.depth > 0 &&
          entry.task.parentId != null &&
          entryById.containsKey(entry.task.parentId) &&
          !emittedTaskIds.contains(entry.task.parentId)) {
        continue;
      }
      final rootDepth = entries[entryIndex].depth;
      for (var index = entryIndex; index < entries.length; index++) {
        final childEntry = entries[index];
        if (index > entryIndex && childEntry.depth <= rootDepth) break;
        if (emittedTaskIds.add(childEntry.task.id)) {
          displayRecords.add(childEntry.task);
        }
      }
    }
    for (final entry in entries) {
      if (emittedTaskIds.add(entry.task.id)) displayRecords.add(entry.task);
    }
    return PopScope(
      canPop: !_selectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectionMode) _exitSelection();
      },
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.escape && _selectionMode) {
            _exitSelection();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.keyA &&
              HardwareKeyboard.instance.isControlPressed) {
            setState(() {
              _selectionMode = true;
              _selectedIds.addAll(visibleTasks.map((task) => task.id));
              _selectionAnchorId = visibleTasks.lastOrNull?.id;
            });
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Column(
          children: [
            if (widget.showHeader)
              PageHeader(
                maxWidth: AppLayout.formMax,
                title: '收集箱',
                subtitle: '先记录，再决定它属于哪一天或哪个项目',
                actions: [
                  FilledButton.icon(
                    onPressed: () =>
                        showQuickCapture(context, widget.controller),
                    icon: const Icon(Icons.add),
                    label: const Text('快速收集'),
                  ),
                ],
              ),
            if (_selectionMode)
              BatchTaskToolbar(
                controller: widget.controller,
                visibleTasks: visibleTasks,
                selectedTasks: selectedTasks,
                onSelectionChanged: (ids) => setState(() {
                  _selectedIds
                    ..clear()
                    ..addAll(ids);
                }),
                onExit: _exitSelection,
              )
            else if (defaultTargetPlatform == TargetPlatform.windows &&
                visibleTasks.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: OutlinedButton.icon(
                    onPressed: _enterSelection,
                    icon: const Icon(Icons.library_add_check_outlined),
                    label: const Text('选择任务'),
                  ),
                ),
              ),
            WorkbenchContentFrame(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: _InboxIntakePanel(
                  controller: widget.controller,
                  records: records,
                  onCapture: () => showQuickCapture(context, widget.controller),
                  showCaptureAction: !widget.showHeader,
                  onSaved: () => setState(() {}),
                ),
              ),
            ),
            Expanded(
              child: displayRecords.isEmpty
                  ? EmptyState(
                      icon: Icons.inbox_outlined,
                      title: '收集箱已经清空',
                      message: '新的任务、笔记和链接会先到这里，安排完成后自动离开。',
                      action: TextButton.icon(
                        onPressed: () =>
                            showQuickCapture(context, widget.controller),
                        icon: const Icon(Icons.add),
                        label: const Text('记录一项'),
                      ),
                    )
                  : Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: AppLayout.formMax,
                        ),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                            20,
                            18,
                            20,
                            AppSpacing.bottomNavClearance,
                          ),
                          itemCount: displayRecords.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final record = displayRecords[index];
                            Widget child;
                            if (record.kind == RecordKind.task) {
                              final entry = entryById[record.id]!;
                              child = Card(
                                child: TaskRow(
                                  task: record,
                                  controller: widget.controller,
                                  hierarchyDepth: entry.depth,
                                  hasChildren: entry.hasChildren,
                                  expanded: entry.expanded,
                                  relationInfo: entry.relation,
                                  onToggleExpanded: () => setState(() {
                                    entry.expanded
                                        ? _collapsedTaskIds.add(record.id)
                                        : _collapsedTaskIds.remove(record.id);
                                  }),
                                  selectionMode: _selectionMode,
                                  selected: _selectedIds.contains(record.id),
                                  onSelectionChanged: (value) =>
                                      _toggleSelection(
                                        record.id,
                                        value,
                                        visibleTasks,
                                      ),
                                ),
                              );
                            } else {
                              child = _CaptureRow(
                                record: record,
                                controller: widget.controller,
                                onOrganize: () => _organizeRecord(record),
                              );
                            }
                            final removing = _exiting.containsKey(record.id);
                            final entering = _incomingIds.contains(record.id);
                            return TweenAnimationBuilder<double>(
                              key: ValueKey('inbox-motion-${record.id}'),
                              tween: Tween(
                                begin: entering ? 0 : 1,
                                end: removing ? 0 : 1,
                              ),
                              duration: _reducedMotion
                                  ? Duration.zero
                                  : removing
                                  ? const Duration(milliseconds: 160)
                                  : entering
                                  ? AppMotion.standard
                                  : Duration.zero,
                              builder: (context, value, child) => IgnorePointer(
                                ignoring: removing,
                                child: ExcludeSemantics(
                                  excluding: removing,
                                  child: Opacity(
                                    opacity: value,
                                    child: ClipRect(
                                      child: Align(
                                        heightFactor: value,
                                        child: child,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              child: child,
                            );
                          },
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleSelection(
    String id,
    bool value,
    List<WorkspaceRecord> visibleTasks,
  ) {
    setState(() {
      final anchorIndex = _selectionAnchorId == null
          ? -1
          : visibleTasks.indexWhere((task) => task.id == _selectionAnchorId);
      final currentIndex = visibleTasks.indexWhere((task) => task.id == id);
      if (value &&
          HardwareKeyboard.instance.isShiftPressed &&
          anchorIndex >= 0 &&
          currentIndex >= 0) {
        final start = anchorIndex < currentIndex ? anchorIndex : currentIndex;
        final end = anchorIndex < currentIndex ? currentIndex : anchorIndex;
        _selectedIds.addAll(
          visibleTasks.sublist(start, end + 1).map((task) => task.id),
        );
      } else if (value) {
        _selectedIds.add(id);
      } else {
        _selectedIds.remove(id);
      }
      _selectionMode = true;
      if (value) _selectionAnchorId = id;
    });
  }

  void _enterSelection() => setState(() => _selectionMode = true);

  void _exitSelection() => setState(() {
    _selectionMode = false;
    _selectionAnchorId = null;
    _selectedIds.clear();
  });
}

class _InboxIntakePanel extends StatefulWidget {
  const _InboxIntakePanel({
    required this.controller,
    required this.records,
    required this.onCapture,
    required this.showCaptureAction,
    required this.onSaved,
  });

  final WorkbenchController controller;
  final List<WorkspaceRecord> records;
  final VoidCallback onCapture;
  final bool showCaptureAction;
  final VoidCallback onSaved;

  @override
  State<_InboxIntakePanel> createState() => _InboxIntakePanelState();
}

class _InboxIntakePanelState extends State<_InboxIntakePanel> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode(debugLabel: 'Inbox.quickTask');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() => _error = '请先写下任务。');
      _focusNode.requestFocus();
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.controller.quickCapture(kind: RecordKind.task, text: text);
      if (!mounted) return;
      _textController.clear();
      widget.onSaved();
      showWorkbenchSnackBar(context, const SnackBar(content: Text('任务已放入收集箱')));
    } on FormatException catch (exception) {
      if (!mounted) return;
      setState(() => _error = exception.message.toString());
      _focusNode.requestFocus();
    } catch (error, stackTrace) {
      debugPrint('Inbox quick task failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() => _error = '保存失败，内容仍保留在输入框中，请稍后重试。');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final tasks = widget.records
        .where((record) => record.kind == RecordKind.task)
        .length;
    final notes = widget.records
        .where((record) => record.kind == RecordKind.note)
        .length;
    final links = widget.records
        .where((record) => record.kind == RecordKind.link)
        .length;
    final other = widget.records.length - tasks - notes - links;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth < 520 ||
            MediaQuery.textScalerOf(context).scale(14) > 21;
        return SolidPanel(
          accent: context.accents.clay.color,
          padding: EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (compact)
                    Icon(
                      Icons.move_to_inbox_outlined,
                      size: 24,
                      color: context.accents.clay.color,
                    )
                  else
                    WorkbenchIllustration(
                      kind: WorkbenchIllustrationKind.capture,
                      width: 64,
                      height: 64,
                    ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.xs,
                          children: [
                            Text(
                              widget.records.isEmpty ? '思路有了就记下来' : '待归位',
                              style: theme.textTheme.titleMedium,
                            ),
                            if (widget.records.isNotEmpty)
                              Container(
                                constraints: const BoxConstraints(minWidth: 24),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: context.accents.clay.container,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.pill,
                                  ),
                                ),
                                child: Text(
                                  '${widget.records.length}',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: context.accents.clay.color,
                                    fontFamily: AppFonts.numeric,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (!compact) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '先收集，再安排到任务、项目或资料。',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: tokens.mutedText,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (widget.showCaptureAction)
                    IconButton(
                      tooltip: '更多收集方式',
                      onPressed: widget.onCapture,
                      icon: const Icon(Icons.add),
                    ),
                ],
              ),
              if (!compact && widget.records.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _InboxKindCount(
                      icon: Icons.check_box_outlined,
                      label: '任务',
                      count: tasks,
                    ),
                    _InboxKindCount(
                      icon: Icons.note_alt_outlined,
                      label: '笔记',
                      count: notes,
                    ),
                    _InboxKindCount(
                      icon: Icons.link_outlined,
                      label: '链接',
                      count: links,
                    ),
                    if (other > 0)
                      _InboxKindCount(
                        icon: Icons.layers_outlined,
                        label: '其他',
                        count: other,
                      ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const ValueKey('inbox-quick-input'),
                controller: _textController,
                focusNode: _focusNode,
                readOnly: _saving,
                textInputAction: TextInputAction.done,
                style: theme.textTheme.bodyLarge,
                decoration: InputDecoration(
                  hintText: '写下待整理的任务…',
                  errorText: _error,
                  prefixIcon: const Icon(Icons.add_task_outlined),
                  suffixIcon: IconButton(
                    tooltip: '记录任务',
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_forward),
                  ),
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) => _save(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InboxKindCount extends StatelessWidget {
  const _InboxKindCount({
    required this.icon,
    required this.label,
    required this.count,
  });

  final IconData icon;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppIconSize.xs, color: context.tokens.mutedText),
        const SizedBox(width: AppSpacing.xs),
        Text(
          '$label $count',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: context.tokens.mutedText),
        ),
      ],
    );
  }
}

class _CaptureRow extends StatelessWidget {
  const _CaptureRow({
    required this.record,
    required this.controller,
    required this.onOrganize,
  });

  final WorkspaceRecord record;
  final WorkbenchController controller;
  final Future<void> Function() onOrganize;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(iconForKind(record.kind)),
        title: Text(record.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          record.kind == RecordKind.link
              ? record.data['url']?.toString() ?? ''
              : '更新于 ${formatDateTime(record.updatedAt)}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () => showRecordEditor(
          context,
          controller,
          kind: record.kind,
          record: record,
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'edit') {
              await showRecordEditor(
                context,
                controller,
                kind: record.kind,
                record: record,
              );
            } else if (value == 'organize') {
              await onOrganize();
            } else {
              await controller.moveToTrash(record);
              if (!context.mounted) return;
              showWorkbenchSnackBar(
                context,
                SnackBar(
                  content: Text('${record.kind.label}已移入回收站'),
                  action: SnackBarAction(
                    label: '撤销',
                    onPressed: () => controller.restoreFromTrash(record),
                  ),
                ),
              );
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'edit', child: Text('编辑')),
            PopupMenuItem(value: 'organize', child: Text('整理完成')),
            PopupMenuItem(value: 'trash', child: Text('移入回收站')),
          ],
        ),
      ),
    );
  }
}
