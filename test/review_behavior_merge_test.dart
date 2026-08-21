import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_workbench/core/models/workspace_record.dart';
import 'package:personal_workbench/core/theme/app_theme.dart';
import 'package:personal_workbench/data/app_database.dart';
import 'package:personal_workbench/data/backup_service.dart';
import 'package:personal_workbench/services/focus_service.dart';
import 'package:personal_workbench/services/notification_service.dart';
import 'package:personal_workbench/services/search_service.dart';
import 'package:personal_workbench/services/share_capture_service.dart';
import 'package:personal_workbench/services/supabase_sync_service.dart';
import 'package:personal_workbench/state/workbench_controller.dart';
import 'package:personal_workbench/ui/pages/behavior_page.dart';

class _MemoryDatabase extends AppDatabase {
  final records = <String, WorkspaceRecord>{};
  final metadata = <String, String>{};

  @override
  Future<List<WorkspaceRecord>> loadRecords({
    bool includeDeleted = true,
  }) async => records.values.toList();

  @override
  Future<String?> readMetadata(String key) async => metadata[key];

  @override
  Future<void> writeMetadata(String key, String value) async {
    metadata[key] = value;
  }

  @override
  Future<void> saveRecord(
    WorkspaceRecord record, {
    bool markDirty = true,
  }) async {
    records['${record.kind.name}:${record.id}'] = record;
  }

  @override
  Future<void> permanentlyDelete(String id, RecordKind kind) async {
    records.remove('${kind.name}:$id');
  }
}

WorkbenchController _controller(_MemoryDatabase database) =>
    WorkbenchController(
      database: database,
      backupService: BackupService(),
      searchService: SearchService(),
      focusService: FocusService(tickInterval: const Duration(hours: 1)),
      notificationService: NotificationService(),
      shareCaptureService: ShareCaptureService(),
      syncService: SupabaseSyncService(null),
      now: () => DateTime(2026, 8, 10, 10),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeDateFormatting('zh_CN');
  });

  testWidgets('behavior center separates ordinary habits from RSIP habits', (
    tester,
  ) async {
    final database = _MemoryDatabase();
    final controller = _controller(database);
    addTearDown(controller.dispose);
    await controller.addRecord(
      WorkspaceRecord.create(kind: RecordKind.habit, title: '普通习惯'),
    );
    await controller.addRecord(
      WorkspaceRecord.create(
        kind: RecordKind.habit,
        title: '国策节点',
        data: {'protocol': 'rsip', 'rsipActive': true},
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: BehaviorPage(controller: controller)),
      ),
    );
    await tester.pump();
    expect(find.text('普通习惯'), findsOneWidget);
    expect(find.text('国策节点'), findsNothing);
    await tester.tap(find.text('国策协议'));
    await tester.pump();
    expect(find.text('国策节点'), findsWidgets);
    expect(find.text('普通习惯'), findsNothing);
    expect(database.metadata['behavior_mode'], 'policies');
  });
}
