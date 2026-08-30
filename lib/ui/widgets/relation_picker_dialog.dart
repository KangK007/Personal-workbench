import 'package:flutter/material.dart';

import '../../state/workbench_controller.dart';
import 'common.dart';

class RelationSelection {
  const RelationSelection({required this.taskIds, required this.projectIds});

  final Set<String> taskIds;
  final Set<String> projectIds;
}

Future<RelationSelection?> showRelationPickerDialog({
  required BuildContext context,
  required WorkbenchController controller,
  required Iterable<String> initialTaskIds,
  required Iterable<String> initialProjectIds,
  FocusNode? returnFocusNode,
}) {
  return showWorkbenchDialog<RelationSelection>(
    context: context,
    builder: (context) => _RelationPickerDialog(
      controller: controller,
      initialTaskIds: initialTaskIds,
      initialProjectIds: initialProjectIds,
    ),
  ).then((result) {
    returnFocusNode?.requestFocus();
    return result;
  });
}

class _RelationPickerDialog extends StatefulWidget {
  const _RelationPickerDialog({
    required this.controller,
    required this.initialTaskIds,
    required this.initialProjectIds,
  });

  final WorkbenchController controller;
  final Iterable<String> initialTaskIds;
  final Iterable<String> initialProjectIds;

  @override
  State<_RelationPickerDialog> createState() => _RelationPickerDialogState();
}

class _RelationPickerDialogState extends State<_RelationPickerDialog> {
  late final Set<String> taskIds = widget.initialTaskIds.toSet();
  late final Set<String> projectIds = widget.initialProjectIds.toSet();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return AlertDialog(
      title: const Text('关联任务和项目'),
      content: SizedBox(
        width: 640,
        height: (size.height * 0.62).clamp(300, 520),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tasks = _relationList(
              title: '关联任务',
              icon: Icons.checklist_outlined,
              children: widget.controller.tasks
                  .map(
                    (task) => CheckboxListTile(
                      value: taskIds.contains(task.id),
                      title: Text(task.title),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (selected) => setState(() {
                        selected == true
                            ? taskIds.add(task.id)
                            : taskIds.remove(task.id);
                      }),
                    ),
                  )
                  .toList(),
              emptyText: '暂无可关联任务',
            );
            final projects = _relationList(
              title: '关联项目',
              icon: Icons.folder_outlined,
              children: widget.controller.projects
                  .map(
                    (project) => CheckboxListTile(
                      value: projectIds.contains(project.id),
                      title: Text(project.title),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (selected) => setState(() {
                        selected == true
                            ? projectIds.add(project.id)
                            : projectIds.remove(project.id);
                      }),
                    ),
                  )
                  .toList(),
              emptyText: '暂无可关联项目',
            );
            if (constraints.maxWidth < 560) {
              return Column(
                children: [
                  Expanded(child: tasks),
                  const Divider(height: 16),
                  Expanded(child: projects),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: tasks),
                const VerticalDivider(width: 16),
                Expanded(child: projects),
              ],
            );
          },
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
            RelationSelection(taskIds: taskIds, projectIds: projectIds),
          ),
          child: const Text('完成'),
        ),
      ],
    );
  }

  Widget _relationList({
    required String title,
    required IconData icon,
    required List<Widget> children,
    required String emptyText,
  }) {
    return ListView(
      children: [
        ListTile(leading: Icon(icon), title: Text(title)),
        if (children.isEmpty) ListTile(title: Text(emptyText)),
        ...children,
      ],
    );
  }
}
