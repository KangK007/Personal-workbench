import 'package:flutter/material.dart';

import '../../core/models/workspace_record.dart';
import '../../core/utils/formatters.dart';
import '../../state/workbench_controller.dart';
import '../widgets/common.dart';
import '../widgets/quick_capture_sheet.dart';
import '../widgets/record_editor_dialog.dart';
import '../widgets/task_row.dart';

class InboxPage extends StatelessWidget {
  const InboxPage({
    super.key,
    required this.controller,
    this.showHeader = true,
  });

  final WorkbenchController controller;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final records = controller.inboxRecords;
    return Column(
      children: [
        if (showHeader)
          PageHeader(
            title: '收集箱',
            subtitle: '先记录，再决定它属于哪一天或哪个项目',
            actions: [
              FilledButton.icon(
                onPressed: () => showQuickCapture(context, controller),
                icon: const Icon(Icons.add),
                label: const Text('快速收集'),
              ),
            ],
          ),
        if (showHeader) const Divider(),
        Expanded(
          child: records.isEmpty
              ? EmptyState(
                  icon: Icons.inbox_outlined,
                  title: '收集箱已经清空',
                  message: '新的任务、笔记和链接会先到这里，安排完成后自动离开。',
                  action: showHeader
                      ? FilledButton.icon(
                          onPressed: () =>
                              showQuickCapture(context, controller),
                          icon: const Icon(Icons.add),
                          label: const Text('记录一项'),
                        )
                      : null,
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 132),
                  itemCount: records.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final record = records[index];
                    if (record.kind == RecordKind.task) {
                      return Card(
                        child: TaskRow(task: record, controller: controller),
                      );
                    }
                    return _CaptureRow(record: record, controller: controller);
                  },
                ),
        ),
      ],
    );
  }
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
