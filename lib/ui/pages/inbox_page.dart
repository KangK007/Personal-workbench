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

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final records = widget.controller.inboxRecords;
    final visibleTasks = records
        .where((record) => record.kind == RecordKind.task)
        .toList(growable: false);
    final selectedTasks = visibleTasks
        .where((task) => _selectedIds.contains(task.id))
        .toList(growable: false);
    final entries = buildTaskHierarchy(
      visibleTasks: visibleTasks,
      allRecords: widget.controller.allRecords,
      collapsedIds: _collapsedTaskIds,
    );
    final displayRecords = <WorkspaceRecord>[];
    final emittedTaskIds = <String>{};
    final entryById = {for (final entry in entries) entry.task.id: entry};
    for (final record in records) {
      if (record.kind != RecordKind.task) {
        displayRecords.add(record);
        continue;
      }
      if (emittedTaskIds.contains(record.id)) continue;
      final entryIndex = entries.indexWhere(
        (entry) => entry.task.id == record.id,
      );
      if (entryIndex < 0) continue;
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
            Expanded(
              child: displayRecords.isEmpty
                  ? EmptyState(
                      icon: Icons.inbox_outlined,
                      title: '收集箱已经清空',
                      message: '新的任务、笔记和链接会先到这里，安排完成后自动离开。',
                      action: widget.showHeader
                          ? FilledButton.icon(
                              onPressed: () =>
                                  showQuickCapture(context, widget.controller),
                              icon: const Icon(Icons.add),
                              label: const Text('记录一项'),
                            )
                          : null,
                    )
                  : ListView.separated(
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
                        if (record.kind == RecordKind.task) {
                          final entry = entries.firstWhere(
                            (candidate) => candidate.task.id == record.id,
                          );
                          return Card(
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
                              onSelectionChanged: (value) => _toggleSelection(
                                record.id,
                                value,
                                visibleTasks,
                              ),
                            ),
                          );
                        }
                        return _CaptureRow(
                          record: record,
                          controller: widget.controller,
                        );
                      },
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

class _CaptureRow extends StatelessWidget {
  const _CaptureRow({required this.record, required this.controller});

  final WorkspaceRecord record;
  final WorkbenchController controller;

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
            PopupMenuItem(value: 'trash', child: Text('移入回收站')),
          ],
        ),
      ),
    );
  }
}
