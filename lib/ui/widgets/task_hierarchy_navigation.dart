import 'package:flutter/material.dart';

import '../../core/models/workspace_record.dart';
import '../../core/theme/app_theme.dart';

class TaskHierarchyNavigation extends StatefulWidget {
  const TaskHierarchyNavigation({
    super.key,
    required this.path,
    required this.onSelected,
  });

  final List<WorkspaceRecord> path;
  final ValueChanged<String?> onSelected;

  @override
  State<TaskHierarchyNavigation> createState() =>
      _TaskHierarchyNavigationState();
}

class _TaskHierarchyNavigationState extends State<TaskHierarchyNavigation> {
  final scrollController = ScrollController(keepScrollOffset: false);

  @override
  void initState() {
    super.initState();
    _revealCurrent();
  }

  @override
  void didUpdateWidget(TaskHierarchyNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path.lastOrNull?.id != widget.path.lastOrNull?.id) {
      _revealCurrent();
    }
  }

  void _revealCurrent() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && scrollController.hasClients) {
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.path;
    if (path.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth < 600 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.5 ||
              path.length > 6;
          if (compact) {
            return Row(
              children: [
                IconButton(
                  tooltip: '返回上一层',
                  onPressed: () => widget.onSelected(
                    path.length > 1 ? path[path.length - 2].id : null,
                  ),
                  icon: const Icon(Icons.arrow_back),
                ),
                PopupMenuButton<String>(
                  tooltip: '选择上级层级',
                  onSelected: (id) => widget.onSelected(id.isEmpty ? null : id),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: '', child: Text('全部层级')),
                    for (final task in path.take(path.length - 1))
                      PopupMenuItem(value: task.id, child: Text(task.title)),
                  ],
                  icon: const Icon(Icons.more_horiz),
                ),
                const Icon(Icons.chevron_right, size: 16),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Tooltip(
                    message: path.map((task) => task.title).join(' › '),
                    child: Semantics(
                      selected: true,
                      label:
                          '当前层级：${path.map((task) => task.title).join(' › ')}',
                      excludeSemantics: true,
                      child: Text(
                        path.last.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
          return Row(
            children: [
              IconButton(
                tooltip: '返回上一层',
                onPressed: () => widget.onSelected(
                  path.length > 1 ? path[path.length - 2].id : null,
                ),
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => widget.onSelected(null),
                        child: const Text('全部层级'),
                      ),
                      for (final task in path) ...[
                        const Icon(Icons.chevron_right, size: 16),
                        Tooltip(
                          message: task.title,
                          child: Semantics(
                            selected: task.id == path.last.id,
                            child: TextButton(
                              onPressed: () => widget.onSelected(task.id),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 180,
                                ),
                                child: Text(
                                  task.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
