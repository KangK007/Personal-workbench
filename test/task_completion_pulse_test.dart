import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_workbench/core/models/attachment.dart';
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
import 'package:personal_workbench/ui/widgets/task_row.dart';

/// 任务完成瞬间的"航迹节点落定"脉冲动效：
/// 只在未完成 → 完成转变时播放一次，结束后从树中移除，
/// 且尊重系统减少动效设置。
///
/// testWidgets 运行在 FakeAsync 时区，sqflite 的真实 IO 不会完成，
/// 因此使用同步内存数据库替身（与 ui_coverage_regression_test 一致）。
void main() {
  testWidgets('completion plays a one-shot log node pulse', (tester) async {
    final fixture = _fixture();
    addTearDown(fixture.dispose);
    final task = (await tester.runAsync<WorkspaceRecord>(() async {
      final record = WorkspaceRecord.create(
        kind: RecordKind.task,
        title: '航迹节点测试任务',
      );
      await fixture.controller.addRecord(record);
      return record;
    }))!;
    await _pumpRow(tester, fixture.controller, task);
    final pulse = find.byKey(const ValueKey('completion-node-pulse'));

    // 初始未完成：无脉冲。
    expect(pulse, findsNothing);

    await tester.tap(find.byType(Checkbox));
    // toggle 异步链的完成帧不固定：以 30ms 步进轮询，脉冲应在 180ms
    // 动画窗口内的某帧出现，且动画结束后消失。
    var observed = false;
    for (var frame = 0; frame < 12; frame++) {
      await tester.pump(const Duration(milliseconds: 30));
      if (tester.any(pulse)) {
        observed = true;
        break;
      }
    }
    expect(observed, isTrue);

    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    await tester.pumpAndSettle();
    expect(pulse, findsNothing);
    expect(
      fixture.controller.tasks.firstWhere((t) => t.id == task.id).isDone,
      isTrue,
    );
  });

  testWidgets('reduced motion skips the pulse entirely', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final fixture = _fixture();
    addTearDown(fixture.dispose);
    final task = (await tester.runAsync<WorkspaceRecord>(() async {
      final record = WorkspaceRecord.create(
        kind: RecordKind.task,
        title: '减少动效测试任务',
      );
      await fixture.controller.addRecord(record);
      return record;
    }))!;
    await _pumpRow(tester, fixture.controller, task);

    // 直接驱动控制器完成切换（绕过 Checkbox 内部动画与布局重入的
    // 测试时序坑），验证 didUpdateWidget 的减少动效分支不启动脉冲。
    final current = fixture.controller.tasks.firstWhere(
      (record) => record.id == task.id,
    );
    await tester.runAsync(() => fixture.controller.toggleTaskDone(current));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    await tester.pump(const Duration(milliseconds: 90));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('completion-node-pulse')), findsNothing);
    expect(
      fixture.controller.tasks.firstWhere((t) => t.id == task.id).isDone,
      isTrue,
    );
  });
}

Future<void> _pumpRow(
  WidgetTester tester,
  WorkbenchController controller,
  WorkspaceRecord task,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final current = controller.tasks.firstWhere(
              (record) => record.id == task.id,
            );
            return TaskRow(task: current, controller: controller);
          },
        ),
      ),
    ),
  );
  await tester.pump();
}

({WorkbenchController controller, void Function() dispose}) _fixture() {
  final database = _MemoryDatabase();
  final controller = WorkbenchController(
    database: database,
    backupService: BackupService(),
    searchService: SearchService(),
    focusService: FocusService(),
    notificationService: _TestNotifications(),
    shareCaptureService: ShareCaptureService(),
    syncService: SupabaseSyncService(null),
  );
  return (controller: controller, dispose: controller.dispose);
}

String _key(WorkspaceRecord record) => '${record.kind.name}:${record.id}';

class _MemoryDatabase extends AppDatabase {
  final Map<String, WorkspaceRecord> records = {};
  final Map<String, String> metadata = {};

  @override
  Future<void> saveRecord(
    WorkspaceRecord record, {
    bool markDirty = true,
  }) async {
    records[_key(record)] = record.copyWith(
      syncState: markDirty ? SyncState.dirty : SyncState.clean,
      touch: false,
    );
  }

  @override
  Future<void> saveRecords(
    Iterable<WorkspaceRecord> values, {
    bool markDirty = true,
  }) async {
    for (final record in values) {
      await saveRecord(record, markDirty: markDirty);
    }
  }

  @override
  Future<void> permanentlyDelete(String id, RecordKind kind) async {
    records.remove('${kind.name}:$id');
  }

  @override
  Future<void> permanentlyDeleteRecords(
    Iterable<({String id, RecordKind kind})> values,
  ) async {
    for (final value in values) {
      records.remove('${value.kind.name}:${value.id}');
    }
  }

  @override
  Future<String?> readMetadata(String key) async => metadata[key];

  @override
  Future<void> writeMetadata(String key, String value) async {
    metadata[key] = value;
  }

  @override
  Future<List<Attachment>> loadAttachments({String? ownerRecordId}) async =>
      const [];

  @override
  Future<void> replaceAttachments(Iterable<Attachment> attachments) async {}

  @override
  Future<void> close() async {}
}

class _TestNotifications extends NotificationService {
  @override
  bool get supportsSystemNotifications => false;

  @override
  Future<void> initialize() async {}
}
