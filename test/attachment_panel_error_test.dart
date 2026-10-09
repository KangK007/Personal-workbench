import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_workbench/core/models/attachment.dart';
import 'package:personal_workbench/core/models/workspace_record.dart';
import 'package:personal_workbench/core/theme/app_theme.dart';
import 'package:personal_workbench/data/app_database.dart';
import 'package:personal_workbench/data/backup_service.dart';
import 'package:personal_workbench/services/attachment_service.dart';
import 'package:personal_workbench/services/focus_service.dart';
import 'package:personal_workbench/services/notification_service.dart';
import 'package:personal_workbench/services/search_service.dart';
import 'package:personal_workbench/services/share_capture_service.dart';
import 'package:personal_workbench/services/supabase_sync_service.dart';
import 'package:personal_workbench/state/workbench_controller.dart';
import 'package:personal_workbench/ui/widgets/attachment_panel.dart';

class _MemoryDatabase extends AppDatabase {
  @override
  Future<void> close() async {}
}

class _TestAttachmentService extends AttachmentService {
  _TestAttachmentService(AppDatabase database) : super(database: database);

  bool failList = false;
  bool failBytes = false;
  bool failResolve = false;
  int listCalls = 0;
  int bytesCalls = 0;
  int resolveCalls = 0;
  int deleteCalls = 0;
  List<Attachment> values = [];

  @override
  Future<List<Attachment>> forRecord(String recordId) {
    listCalls++;
    if (failList) throw StateError('list failed');
    return Future.value(values);
  }

  @override
  Future<int> totalBytes() {
    bytesCalls++;
    if (failBytes) throw StateError('bytes failed');
    return Future.value(0);
  }

  @override
  Future<File?> resolve(Attachment attachment) async {
    resolveCalls++;
    if (failResolve) throw StateError('resolve failed');
    return null;
  }

  @override
  Future<void> delete(Attachment attachment) async {
    deleteCalls++;
    values.removeWhere((item) => item.id == attachment.id);
  }
}

WorkbenchController _controller(
  AppDatabase database,
  AttachmentService service,
) => WorkbenchController(
  database: database,
  attachmentService: service,
  backupService: BackupService(),
  searchService: SearchService(),
  focusService: FocusService(),
  notificationService: NotificationService(),
  shareCaptureService: ShareCaptureService(),
  syncService: SupabaseSyncService(null),
);

Future<void> _pumpPanel(
  WidgetTester tester,
  WorkbenchController controller,
  WorkspaceRecord owner,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: ListView(
          children: [AttachmentPanel(owner: owner, controller: controller)],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('attachment list and capacity errors have independent retries', (
    tester,
  ) async {
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final database = _MemoryDatabase();
    final service = _TestAttachmentService(database)
      ..failList = true
      ..failBytes = true;
    final controller = _controller(database, service);
    addTearDown(controller.dispose);
    final owner = WorkspaceRecord.create(kind: RecordKind.note, title: '资料');
    await _pumpPanel(tester, controller, owner);

    expect(find.text('附件加载失败'), findsOneWidget);
    expect(find.text('附件 · 容量读取失败'), findsOneWidget);
    expect(find.text('暂无附件'), findsNothing);

    service.failList = false;
    await tester.tap(find.widgetWithText(TextButton, '重试'));
    await tester.pumpAndSettle();
    expect(find.text('暂无附件'), findsOneWidget);

    service.failBytes = false;
    await tester.tap(find.byTooltip('重试容量统计'));
    await tester.pumpAndSettle();
    expect(find.text('附件 · 0 B'), findsOneWidget);
    expect(service.listCalls, greaterThanOrEqualTo(2));
    expect(service.bytesCalls, greaterThanOrEqualTo(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed image lookup can be retried without hiding the row', (
    tester,
  ) async {
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final database = _MemoryDatabase();
    final owner = WorkspaceRecord.create(kind: RecordKind.note, title: '资料');
    final service = _TestAttachmentService(database)
      ..failResolve = true
      ..values = [
        Attachment(
          id: 'image-1',
          ownerRecordId: owner.id,
          ownerKind: owner.kind,
          fileName: 'figure.png',
          relativePath: 'figure.png',
          mimeType: 'image/png',
          sizeBytes: 1024,
          sha256: 'abcdef0123456789',
          createdAt: DateTime(2026, 8, 19),
        ),
      ];
    final controller = _controller(database, service);
    addTearDown(controller.dispose);
    await _pumpPanel(tester, controller, owner);

    expect(find.text('figure.png'), findsOneWidget);
    expect(find.text('图片读取失败，请重试'), findsOneWidget);
    service.failResolve = false;
    await tester.tap(find.byTooltip('重试附件读取'));
    await tester.pumpAndSettle();
    expect(find.textContaining('附件未下载'), findsOneWidget);
    expect(service.resolveCalls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('physical attachment deletion requires explicit confirmation', (
    tester,
  ) async {
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final database = _MemoryDatabase();
    final owner = WorkspaceRecord.create(kind: RecordKind.note, title: '资料');
    final service = _TestAttachmentService(database)
      ..values = [
        Attachment(
          id: 'image-2',
          ownerRecordId: owner.id,
          ownerKind: owner.kind,
          fileName: 'draft.png',
          relativePath: 'draft.png',
          mimeType: 'image/png',
          sizeBytes: 2048,
          sha256: 'abcdef0123456789',
          createdAt: DateTime(2026, 8, 19),
        ),
      ];
    final controller = _controller(database, service);
    addTearDown(controller.dispose);
    await _pumpPanel(tester, controller, owner);

    await tester.tap(find.byTooltip('删除附件'));
    await tester.pumpAndSettle();
    expect(find.text('删除附件？'), findsOneWidget);
    expect(service.deleteCalls, 0);
    await tester.tap(find.widgetWithText(TextButton, '保留附件'));
    await tester.pumpAndSettle();
    expect(find.text('draft.png'), findsOneWidget);
    expect(service.deleteCalls, 0);

    await tester.tap(find.byTooltip('删除附件'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '确认删除'));
    await tester.pumpAndSettle();
    expect(service.deleteCalls, 1);
    expect(find.text('draft.png'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
