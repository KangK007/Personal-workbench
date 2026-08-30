import '../../core/models/workspace_record.dart';

enum TaskRelationState { normal, parentFiltered, parentInTrash, missing, cycle }

class TaskRelationInfo {
  const TaskRelationInfo({
    required this.state,
    this.parentTitle,
    this.path = const [],
  });

  final TaskRelationState state;
  final String? parentTitle;
  final List<String> path;

  bool get isWarning => state != TaskRelationState.normal;

  String? get label {
    final title = parentTitle;
    return switch (state) {
      TaskRelationState.normal =>
        path.isEmpty ? null : '所属：${path.join(' › ')}',
      TaskRelationState.parentFiltered =>
        title == null ? '父任务不在当前视图' : '父任务不在当前视图：$title',
      TaskRelationState.parentInTrash =>
        title == null ? '原父任务在回收站' : '原父任务在回收站：$title',
      TaskRelationState.missing => '父任务记录缺失',
      TaskRelationState.cycle => '父子关系异常：检测到循环引用',
    };
  }
}

class TaskHierarchyEntry {
  const TaskHierarchyEntry({
    required this.task,
    required this.depth,
    required this.hasChildren,
    required this.expanded,
    required this.relation,
  });

  final WorkspaceRecord task;
  final int depth;
  final bool hasChildren;
  final bool expanded;
  final TaskRelationInfo relation;
}

List<TaskHierarchyEntry> buildTaskHierarchy({
  required List<WorkspaceRecord> visibleTasks,
  required Iterable<WorkspaceRecord> allRecords,
  Set<String> collapsedIds = const {},
}) {
  final allTasks = <String, WorkspaceRecord>{
    for (final record in allRecords)
      if (record.kind == RecordKind.task) record.id: record,
  };
  final visibleById = {for (final task in visibleTasks) task.id: task};
  final cyclicIds = <String>{};

  for (final task in visibleTasks) {
    final path = <String>{};
    WorkspaceRecord? current = task;
    while (current?.parentId != null) {
      if (!path.add(current!.id)) {
        cyclicIds.addAll(path);
        break;
      }
      final parent = allTasks[current.parentId];
      if (parent == null) break;
      current = parent;
    }
  }

  final children = <String, List<WorkspaceRecord>>{};
  final roots = <WorkspaceRecord>[];
  for (final task in visibleTasks) {
    final parentId = task.parentId;
    final parentVisible = parentId == null ? null : visibleById[parentId];
    final canNest =
        parentVisible != null &&
        !parentVisible.isDeleted &&
        !cyclicIds.contains(task.id) &&
        !cyclicIds.contains(parentVisible.id);
    if (canNest) {
      children.putIfAbsent(parentVisible.id, () => []).add(task);
    } else {
      roots.add(task);
    }
  }

  final result = <TaskHierarchyEntry>[];
  final emitted = <String>{};

  void append(WorkspaceRecord task, int depth, List<String> parentPath) {
    if (!emitted.add(task.id)) return;
    final directChildren = children[task.id] ?? const <WorkspaceRecord>[];
    final expanded = !collapsedIds.contains(task.id);
    final relation = _relationFor(
      task,
      visibleById: visibleById,
      allTasks: allTasks,
      cyclicIds: cyclicIds,
      parentPath: parentPath,
    );
    result.add(
      TaskHierarchyEntry(
        task: task,
        depth: depth,
        hasChildren: directChildren.isNotEmpty,
        expanded: expanded,
        relation: relation,
      ),
    );
    if (!expanded) return;
    for (final child in directChildren) {
      append(child, depth + 1, [...parentPath, task.title]);
    }
  }

  for (final root in roots) {
    append(root, 0, const []);
  }
  for (final task in visibleTasks) {
    if (!emitted.contains(task.id)) append(task, 0, const []);
  }
  return result;
}

TaskRelationInfo taskRelationInfo(
  WorkspaceRecord task,
  Iterable<WorkspaceRecord> allRecords,
) {
  final allTasks = <String, WorkspaceRecord>{
    for (final record in allRecords)
      if (record.kind == RecordKind.task) record.id: record,
  };
  final path = <String>[];
  final visited = <String>{task.id};
  var parentId = task.parentId;
  while (parentId != null) {
    if (!visited.add(parentId)) {
      return const TaskRelationInfo(state: TaskRelationState.cycle);
    }
    final parent = allTasks[parentId];
    if (parent == null) {
      return const TaskRelationInfo(state: TaskRelationState.missing);
    }
    if (parent.isDeleted) {
      return TaskRelationInfo(
        state: TaskRelationState.parentInTrash,
        parentTitle: parent.title,
      );
    }
    path.insert(0, parent.title);
    parentId = parent.parentId;
  }
  return TaskRelationInfo(
    state: TaskRelationState.normal,
    parentTitle: path.isEmpty ? null : path.first,
    path: path,
  );
}

TaskRelationInfo _relationFor(
  WorkspaceRecord task, {
  required Map<String, WorkspaceRecord> visibleById,
  required Map<String, WorkspaceRecord> allTasks,
  required Set<String> cyclicIds,
  required List<String> parentPath,
}) {
  if (cyclicIds.contains(task.id)) {
    return const TaskRelationInfo(state: TaskRelationState.cycle);
  }
  final parentId = task.parentId;
  if (parentId == null) {
    return const TaskRelationInfo(state: TaskRelationState.normal);
  }
  final parent = allTasks[parentId];
  if (parent == null) {
    return const TaskRelationInfo(state: TaskRelationState.missing);
  }
  if (parent.isDeleted) {
    return TaskRelationInfo(
      state: TaskRelationState.parentInTrash,
      parentTitle: parent.title,
    );
  }
  if (!visibleById.containsKey(parentId)) {
    return TaskRelationInfo(
      state: TaskRelationState.parentFiltered,
      parentTitle: parent.title,
    );
  }
  return TaskRelationInfo(
    state: TaskRelationState.normal,
    parentTitle: parent.title,
    path: parentPath,
  );
}
