import 'package:flutter_test/flutter_test.dart';
import 'package:personal_workbench/core/models/workspace_record.dart';
import 'package:personal_workbench/services/search_service.dart';

void main() {
  test('global search covers title, body and tags', () {
    final records = [
      WorkspaceRecord.create(
        kind: RecordKind.note,
        title: '傅里叶光学',
        body: '记录角谱法采样条件',
        tags: const ['衍射'],
      ),
      WorkspaceRecord.create(kind: RecordKind.task, title: '整理实验台'),
    ];

    expect(SearchService().search(records, '角谱').single.kind, RecordKind.note);
    expect(SearchService().search(records, '衍射').single.title, '傅里叶光学');
  });

  test('search index refreshes when a record changes', () {
    final service = SearchService();
    final original = WorkspaceRecord.create(
      kind: RecordKind.note,
      title: '旧标题',
    );
    expect(service.search([original], '旧标题'), hasLength(1));

    final updated = original.copyWith(title: '新标题');
    expect(service.search([updated], '新标题').single.id, original.id);
    expect(service.search([updated], '旧标题'), isEmpty);
  });

  test('multi-term ranking considers every term in the title', () {
    final fullTitle = WorkspaceRecord.create(
      kind: RecordKind.note,
      title: 'alpha beta',
    );
    final bodyMatch = WorkspaceRecord.create(
      kind: RecordKind.note,
      title: 'alpha',
      body: 'beta',
    );

    final results = SearchService().search([
      bodyMatch,
      fullTitle,
    ], 'alpha beta');
    expect(results.first.id, fullTitle.id);
  });
}
