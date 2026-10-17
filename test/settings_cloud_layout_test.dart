import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:personal_workbench/ui/pages/settings_page.dart';

class _MemoryDatabase extends AppDatabase {
  bool failBatch = false;

  @override
  Future<void> saveRecord(
    WorkspaceRecord record, {
    bool markDirty = true,
  }) async {}

  @override
  Future<void> saveRecords(
    Iterable<WorkspaceRecord> records, {
    bool markDirty = true,
  }) async {
    if (failBatch) throw StateError('simulated write failure');
  }

  @override
  Future<void> close() async {}
}

class _ConfiguredRemote implements WorkspaceSyncRemote {
  @override
  String get userId => 'layout-test-account';

  @override
  Future<void> upsert(List<Map<String, dynamic>> rows) async {}

  @override
  Future<void> delete(List<Map<String, dynamic>> keys) async {}

  @override
  Future<List<Map<String, dynamic>>> fetchPage({
    required int offset,
    required int limit,
  }) async => const [];
}

WorkbenchController _controller() => WorkbenchController(
  database: _MemoryDatabase(),
  backupService: BackupService(),
  searchService: SearchService(),
  focusService: FocusService(),
  notificationService: NotificationService(),
  shareCaptureService: ShareCaptureService(),
  syncService: SupabaseSyncService.withRemote(_ConfiguredRemote()),
  now: () => DateTime(2026, 10, 11, 10),
);

class _SignedInPreviewController extends WorkbenchController {
  _SignedInPreviewController()
    : super(
        database: _MemoryDatabase(),
        backupService: BackupService(),
        searchService: SearchService(),
        focusService: FocusService(),
        notificationService: NotificationService(),
        shareCaptureService: ShareCaptureService(),
        syncService: SupabaseSyncService.withRemote(_ConfiguredRemote()),
      );

  @override
  String? get signedInEmail => 'a.long.account.name@example.com';

  @override
  SyncPhase get syncPhase => SyncPhase.error;

  @override
  String get syncMessage => '网络暂时不可用，本地修改仍已保存。';
}

void main() {
  testWidgets(
    'desktop settings index jumps to data and preserves account draft',
    (tester) async {
      final controller = _controller();
      addTearDown(controller.dispose);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: SettingsPage(controller: controller)),
        ),
      );

      expect(find.text('设置目录'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('settings-index:1')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'kept@example.com');
      await tester.enterText(find.byType(TextField).at(1), 'kept-password');

      await tester.tap(find.byKey(const ValueKey('settings-index:3')));
      await tester.pumpAndSettle();
      final backup = find.text('创建加密备份');
      expect(tester.getTopLeft(backup).dy, greaterThan(0));
      expect(tester.getBottomLeft(backup).dy, lessThan(900));
      expect(find.text('导入文件'), findsOneWidget);

      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(find.text('设置目录'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'kept@example.com',
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
        'kept-password',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('data actions leave readable copy at 200 percent text', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: SettingsPage(controller: controller, showHeader: false),
          ),
        ),
      ),
    );
    final backup = find.text('备份');
    await tester.ensureVisible(backup);
    await tester.pumpAndSettle();
    final title = tester.getRect(find.text('创建加密备份'));
    final explanation = tester.getRect(find.text('保存全部本地内容，密码至少 8 个字符'));
    final action = tester.getRect(backup);
    expect(title.width, greaterThan(160));
    expect(action.top, greaterThan(explanation.bottom));
    expect(action.bottom, lessThan(568));
    expect(find.text('设置目录'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('auth form keeps fields and actions reachable with a keyboard', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: SettingsPage(controller: controller, showHeader: false),
          ),
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('登录'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('登录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('登录'));
    await tester.pump();
    expect(find.text('请输入有效邮箱。'), findsOneWidget);
    expect(find.text('请输入密码。'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'person@example.com');
    await tester.enterText(fields.at(1), 'kept-password');
    await tester.ensureVisible(find.byTooltip('显示密码'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('显示密码'));
    await tester.pump();
    expect(find.byTooltip('隐藏密码'), findsOneWidget);
    tester.view.viewInsets = const FakeViewPadding(bottom: 200);
    await tester.pump();
    await tester.ensureVisible(find.text('登录'));
    await tester.tap(find.text('登录'));
    await tester.pump();
    expect(find.text('登录失败，请检查账号、密码或网络后重试。'), findsOneWidget);
    expect(fields.at(0).evaluate().single.widget, isA<TextField>());
    expect(
      (tester.widget<TextField>(fields.at(0))).controller!.text,
      'person@example.com',
    );
    expect(
      (tester.widget<TextField>(fields.at(1))).controller!.text,
      'kept-password',
    );
    await tester.ensureVisible(find.text('登录'));
    await tester.pump();
    expect(tester.getBottomLeft(find.text('登录')).dy, lessThan(368));
    expect(tester.takeException(), isNull);
  });

  testWidgets('signed-in sync status and actions reflow at 200 percent text', (
    tester,
  ) async {
    final controller = _SignedInPreviewController();
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: SettingsPage(controller: controller, showHeader: false),
          ),
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('重试同步'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('重试同步'));
    await tester.pumpAndSettle();
    expect(find.text('网络暂时不可用，本地修改仍已保存。'), findsOneWidget);
    expect(find.text('本次启动尚未成功同步'), findsOneWidget);
    expect(find.text('退出账号'), findsOneWidget);
    expect(tester.getBottomLeft(find.text('重试同步')).dy, lessThan(568));
    expect(tester.takeException(), isNull);
  });

  testWidgets('conflict comparison preserves the choice after a failed save', (
    tester,
  ) async {
    final controller = _SignedInPreviewController();
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    final cloud = WorkspaceRecord.create(
      kind: RecordKind.note,
      title: '云端标题',
      body: '云端正文',
    );
    final local = cloud.copyWith(title: '本地标题', body: '本地正文').asConflictCopy();
    await controller.addRecord(cloud);
    await controller.addRecord(local);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: SettingsPage(controller: controller, showHeader: false),
          ),
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('对照并解决'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('对照并解决'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('对照并解决'));
    await tester.pumpAndSettle();
    expect(find.text('差异字段'), findsOneWidget);
    expect(find.text('云端标题'), findsOneWidget);
    expect(find.text('本地标题'), findsOneWidget);
    await tester.ensureVisible(find.byType(ChoiceChip).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ChoiceChip).last);
    await tester.pump();
    final database = controller.database as _MemoryDatabase;
    database.failBatch = true;
    await tester.tap(find.text('确认采用所选版本'));
    await tester.pump();
    expect(find.text('保存解决结果失败，当前选择已保留，请重试。'), findsOneWidget);
    expect(controller.syncConflictCopies, hasLength(1));
    expect(controller.allRecords.first.title, '云端标题');
    database.failBatch = false;
    await tester.tap(find.text('确认采用所选版本'));
    await tester.pumpAndSettle();
    expect(controller.syncConflictCopies, isEmpty);
    expect(controller.allRecords.first.title, '本地标题');
    expect(controller.allRecords.first.body, '本地正文');
    expect(controller.allRecords.last.isDeleted, isTrue);
    expect(tester.takeException(), isNull);
  });

  test(
    'choosing the cloud version leaves the source and archives the copy',
    () async {
      final controller = _SignedInPreviewController();
      addTearDown(controller.dispose);
      final cloud = WorkspaceRecord.create(
        kind: RecordKind.note,
        title: '云端标题',
        body: '云端正文',
      );
      final local = cloud.copyWith(title: '本地标题').asConflictCopy();
      await controller.addRecord(cloud);
      await controller.addRecord(local);

      await controller.resolveSyncConflict(local, useLocalCopy: false);

      expect(controller.syncConflictCopies, isEmpty);
      expect(controller.allRecords.first.title, '云端标题');
      expect(controller.allRecords.first.body, '云端正文');
      expect(controller.allRecords.last.isDeleted, isTrue);
    },
  );
}
