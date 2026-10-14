import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/models/workspace_record.dart';
import '../../core/theme/app_theme.dart';
import '../../state/workbench_controller.dart';
import 'common.dart';

class RelationSelection {
  const RelationSelection({
    required this.taskIds,
    required this.projectIds,
    this.goalIds = const {},
    this.noteIds = const {},
  });

  final Set<String> taskIds;
  final Set<String> projectIds;
  final Set<String> goalIds;
  final Set<String> noteIds;
}

Future<RelationSelection?> showRelationPickerDialog({
  required BuildContext context,
  required WorkbenchController controller,
  required Iterable<String> initialTaskIds,
  required Iterable<String> initialProjectIds,
  Iterable<String> initialGoalIds = const [],
  Iterable<String> initialNoteIds = const [],
  Set<String> excludedNoteIds = const {},
  bool tasksOnly = false,
  Set<String>? allowedTaskIds,
  FocusNode? returnFocusNode,
}) {
  return showWorkbenchDialog<RelationSelection>(
    context: context,
    builder: (context) => _RelationPickerDialog(
      controller: controller,
      initialTaskIds: initialTaskIds,
      initialProjectIds: initialProjectIds,
      initialGoalIds: initialGoalIds,
      initialNoteIds: initialNoteIds,
      excludedNoteIds: excludedNoteIds,
      tasksOnly: tasksOnly,
      allowedTaskIds: allowedTaskIds,
    ),
  ).then((result) {
    returnFocusNode?.requestFocus();
    return result;
  });
}

enum _RelationKind {
  task(RecordKind.task),
  project(RecordKind.project),
  goal(RecordKind.goal),
  note(RecordKind.note);

  const _RelationKind(this.recordKind);
  final RecordKind recordKind;
  String get label => recordKind.label;
  IconData get icon => iconForKind(recordKind);
}

class _RelationPickerDialog extends StatefulWidget {
  const _RelationPickerDialog({
    required this.controller,
    required this.initialTaskIds,
    required this.initialProjectIds,
    required this.initialGoalIds,
    required this.initialNoteIds,
    required this.excludedNoteIds,
    required this.tasksOnly,
    required this.allowedTaskIds,
  });

  final WorkbenchController controller;
  final Iterable<String> initialTaskIds;
  final Iterable<String> initialProjectIds;
  final Iterable<String> initialGoalIds;
  final Iterable<String> initialNoteIds;
  final Set<String> excludedNoteIds;
  final bool tasksOnly;
  final Set<String>? allowedTaskIds;

  @override
  State<_RelationPickerDialog> createState() => _RelationPickerDialogState();
}

class _RelationPickerDialogState extends State<_RelationPickerDialog> {
  late final Set<String> taskIds = widget.initialTaskIds.toSet();
  late final Set<String> projectIds = widget.initialProjectIds.toSet();
  late final Set<String> goalIds = widget.initialGoalIds.toSet();
  late final Set<String> noteIds = widget.initialNoteIds.toSet();
  late final List<WorkspaceRecord> availableTasks;
  late final List<WorkspaceRecord> availableProjects;
  late final List<WorkspaceRecord> availableGoals;
  late final List<WorkspaceRecord> availableNotes;
  late final Map<String, String> taskNames;
  late final Map<String, String> projectNames;
  late final Map<String, String> goalNames;
  late final Map<String, String> noteNames;
  late List<WorkspaceRecord> filteredTasks;
  late List<WorkspaceRecord> filteredProjects;
  late List<WorkspaceRecord> filteredGoals;
  late List<WorkspaceRecord> filteredNotes;
  final searchController = TextEditingController();
  Timer? searchDebounce;
  String query = '';
  _RelationKind compactKind = _RelationKind.task;
  bool selectionsExpanded = false;
  final limits = {for (final kind in _RelationKind.values) kind: 40};

  @override
  void initState() {
    super.initState();
    final tasks = widget.controller.tasks;
    availableTasks = tasks
        .where(
          (task) =>
              widget.allowedTaskIds == null ||
              widget.allowedTaskIds!.contains(task.id),
        )
        .toList();
    availableProjects = widget.tasksOnly
        ? const <WorkspaceRecord>[]
        : widget.controller.projects.toList();
    availableGoals = widget.tasksOnly
        ? const []
        : widget.controller.goals.toList();
    availableNotes = widget.tasksOnly
        ? const []
        : widget.controller.notes
              .where(
                (note) =>
                    !widget.excludedNoteIds.contains(note.id) &&
                    note.data['recordType'] != 'periodReview' &&
                    note.data['recordType'] != 'restrictionLogArchive',
              )
              .toList();
    taskNames = {for (final record in tasks) record.id: record.title};
    projectNames = {
      for (final record in widget.controller.projects) record.id: record.title,
    };
    goalNames = {
      for (final record in widget.controller.goals) record.id: record.title,
    };
    noteNames = {
      for (final record in widget.controller.notes) record.id: record.title,
    };
    filteredTasks = availableTasks;
    filteredProjects = availableProjects;
    filteredGoals = availableGoals;
    filteredNotes = availableNotes;
  }

  @override
  void dispose() {
    searchDebounce?.cancel();
    searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    searchDebounce?.cancel();
    searchDebounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      setState(() {
        query = value.trim().toLowerCase();
        filteredTasks = _matching(availableTasks);
        filteredProjects = _matching(availableProjects);
        filteredGoals = _matching(availableGoals);
        filteredNotes = _matching(availableNotes);
        limits.updateAll((_, _) => 40);
      });
    });
  }

  void _toggle(String id, _RelationKind kind, bool selected) {
    setState(() {
      final ids = _idsFor(kind);
      selected ? ids.add(id) : ids.remove(id);
      if (_RelationKind.values.every((kind) => _idsFor(kind).isEmpty)) {
        selectionsExpanded = false;
      }
    });
  }

  List<WorkspaceRecord> _matching(List<WorkspaceRecord> source) {
    if (query.isEmpty) return source;
    return source
        .where(
          (record) =>
              record.title.toLowerCase().contains(query) ||
              record.body.toLowerCase().contains(query),
        )
        .toList();
  }

  List<({String id, String label, _RelationKind kind})> _selected() {
    return [
      for (final id in taskIds)
        (id: id, label: taskNames[id] ?? '已移除任务', kind: _RelationKind.task),
      for (final id in projectIds)
        (
          id: id,
          label: projectNames[id] ?? '已移除项目',
          kind: _RelationKind.project,
        ),
      for (final id in goalIds)
        (id: id, label: goalNames[id] ?? '已移除目标', kind: _RelationKind.goal),
      for (final id in noteIds)
        (id: id, label: noteNames[id] ?? '已移除笔记', kind: _RelationKind.note),
    ];
  }

  Set<String> _idsFor(_RelationKind kind) => switch (kind) {
    _RelationKind.task => taskIds,
    _RelationKind.project => projectIds,
    _RelationKind.goal => goalIds,
    _RelationKind.note => noteIds,
  };

  List<WorkspaceRecord> _recordsFor(_RelationKind kind) => switch (kind) {
    _RelationKind.task => filteredTasks,
    _RelationKind.project => filteredProjects,
    _RelationKind.goal => filteredGoals,
    _RelationKind.note => filteredNotes,
  };

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 700;
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 22;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final selected = _selected();
    final visibleSelections = selectionsExpanded
        ? selected
        : selected.take(compact ? 4 : 8).toList();
    final selectedHeight = selectionsExpanded
        ? 116.0
        : selected.isEmpty || largeText
        ? 0.0
        : compact
        ? 88.0
        : selected.length > 3
        ? 88.0
        : 48.0;
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final preferredHeight =
        56 * textScale.clamp(1.0, 1.5) +
        12 +
        48 * textScale.clamp(1.0, 1.3) +
        selectedHeight +
        (widget.tasksOnly ? 0 : 48 * textScale.clamp(1.0, 1.3) + 8) +
        _recordsFor(compactKind).length.clamp(1, 6) *
            64 *
            textScale.clamp(1.0, 1.5);
    return AlertDialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 24,
        vertical: compact ? 8 : 24,
      ),
      title: Text(
        compact && largeText
            ? '选择关联'
            : widget.tasksOnly
            ? '关联任务'
            : '选择关联',
      ),
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      content: SizedBox(
        width: 680,
        height: math.min(
          preferredHeight,
          (size.height * (compact && !largeText ? 0.68 : 0.58)).clamp(
            180.0,
            520.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: widget.tasksOnly ? '搜索任务' : '搜索关联记录',
                suffixIcon: searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清除搜索',
                        onPressed: () {
                          searchController.clear();
                          _onSearchChanged('');
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '已选 ${selected.length}',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                if (selected.isNotEmpty) ...[
                  TextButton(
                    onPressed: () => setState(
                      () => selectionsExpanded = !selectionsExpanded,
                    ),
                    child: Text(selectionsExpanded ? '收起' : '展开'),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      taskIds.clear();
                      projectIds.clear();
                      goalIds.clear();
                      noteIds.clear();
                      selectionsExpanded = false;
                    }),
                    child: const Text('清空'),
                  ),
                ],
              ],
            ),
            if (selectedHeight > 0)
              SizedBox(
                height: selectedHeight,
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final item in visibleSelections)
                        InputChip(
                          avatar: Icon(
                            item.kind.icon,
                            size: 16,
                            color: context.tokens.teal,
                          ),
                          label: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: math.min(260, size.width - 130),
                            ),
                            child: Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          onDeleted: () => _toggle(item.id, item.kind, false),
                          deleteButtonTooltipMessage: '移除${item.label}',
                        ),
                      if (visibleSelections.length < selected.length)
                        ActionChip(
                          label: Text(
                            '还有 ${selected.length - visibleSelections.length} 项',
                          ),
                          onPressed: () =>
                              setState(() => selectionsExpanded = true),
                        ),
                    ],
                  ),
                ),
              ),
            if (!widget.tasksOnly) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final kind in _RelationKind.values) ...[
                      if (kind != _RelationKind.task) const SizedBox(width: 8),
                      _kindChip(kind, kind.label, _recordsFor(kind).length),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: _resultList(
                compactKind,
                _recordsFor(compactKind),
                reducedMotion,
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
          onPressed: () => Navigator.pop(
            context,
            RelationSelection(
              taskIds: Set<String>.of(taskIds),
              projectIds: Set<String>.of(projectIds),
              goalIds: Set<String>.of(goalIds),
              noteIds: Set<String>.of(noteIds),
            ),
          ),
          child: const Text('完成'),
        ),
      ],
    );
  }

  Widget _kindChip(_RelationKind kind, String label, int count) => ChoiceChip(
    showCheckmark: false,
    label: Text('$label $count'),
    avatar: Icon(kind.icon, size: 16),
    selected: compactKind == kind,
    onSelected: (_) => setState(() => compactKind = kind),
  );

  Widget _resultList(
    _RelationKind kind,
    List<WorkspaceRecord> records,
    bool reducedMotion,
  ) {
    final title = kind.label;
    final ids = _idsFor(kind);
    final limit = limits[kind]!;
    final visibleCount = math.min(records.length, limit);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: AnimatedSwitcher(
            duration: reducedMotion
                ? Duration.zero
                : const Duration(milliseconds: 180),
            child: records.isEmpty
                ? Center(
                    key: ValueKey('empty-$kind-$query'),
                    child: Text(
                      query.isEmpty ? '暂无可关联$title' : '没有匹配的$title',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                : ListView.builder(
                    key: ValueKey('results-$kind-$query'),
                    itemCount:
                        visibleCount + (visibleCount < records.length ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == visibleCount) {
                        return TextButton(
                          onPressed: () => setState(() {
                            limits[kind] = limits[kind]! + 40;
                          }),
                          child: Text(
                            '显示更多（剩余 ${records.length - visibleCount}）',
                          ),
                        );
                      }
                      final record = records[index];
                      return AnimatedContainer(
                        duration: reducedMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 120),
                        decoration: BoxDecoration(
                          color: ids.contains(record.id)
                              ? context.accents.teal.container
                              : null,
                          borderRadius: BorderRadius.circular(
                            AppRadius.control,
                          ),
                        ),
                        child: Material(
                          type: MaterialType.transparency,
                          child: CheckboxListTile(
                            key: ValueKey('relation-${kind.name}-${record.id}'),
                            value: ids.contains(record.id),
                            title: Text(
                              record.title,
                              style: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.copyWith(fontSize: 15),
                            ),
                            subtitle: record.body.trim().isEmpty
                                ? null
                                : Text(
                                    record.body.trim(),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(fontSize: 13),
                                  ),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
                            onChanged: (selected) =>
                                _toggle(record.id, kind, selected == true),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
