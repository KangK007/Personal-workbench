import 'package:flutter_test/flutter_test.dart';

import 'package:personal_workbench/core/models/workspace_record.dart';

void main() {
  test('workspace records round-trip through JSON', () {
    final original = WorkspaceRecord.create(
      kind: RecordKind.task,
      title: '验证工作台数据',
      body: '保留关联和标签',
      tags: const ['测试', '科研'],
      status: WorkStatus.todo,
      data: const {'estimatedMinutes': 25, 'isFocus': true},
    );

    final restored = WorkspaceRecord.fromJson(original.toJson());

    expect(restored.id, original.id);
    expect(restored.kind, RecordKind.task);
    expect(restored.tags, contains('科研'));
    expect(restored.data['estimatedMinutes'], 25);
    expect(restored.isFocus, isTrue);
  });
}
