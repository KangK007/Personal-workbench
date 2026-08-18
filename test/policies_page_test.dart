import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_workbench/core/models/workspace_record.dart';
import 'package:personal_workbench/core/models/workspace_models_v3.dart';
import 'package:personal_workbench/core/theme/app_theme.dart';
import 'package:personal_workbench/data/app_database.dart';
import 'package:personal_workbench/data/backup_service.dart';
import 'package:personal_workbench/services/focus_service.dart';
import 'package:personal_workbench/services/notification_service.dart';
import 'package:personal_workbench/services/search_service.dart';
import 'package:personal_workbench/services/share_capture_service.dart';
import 'package:personal_workbench/services/supabase_sync_service.dart';
import 'package:personal_workbench/state/workbench_controller.dart';
import 'package:personal_workbench/ui/pages/policies_page.dart';

String _key(WorkspaceRecord record) => '${record.kind.name}:${record.id}';

class _MemoryDatabase extends AppDatabase {
  final Map<String, WorkspaceRecord> records = {};
  final Map<String, String> metadata = {};

  @override
  Future<void> saveRecord(
    WorkspaceRecord record, {
    bool markDirty = true,
  }) async {
    records[_key(record)] = record;
  }

  @override
  Future<String?> readMetadata(String key) async => metadata[key];

  @override
  Future<void> writeMetadata(String key, String value) async {
    metadata[key] = value;
  }

  @override
  Future<void> close() async {}
}

WorkbenchController _controller() => WorkbenchController(
  database: _MemoryDatabase(),
  backupService: BackupService(),
  searchService: SearchService(),
  focusService: FocusService(),
  notificationService: NotificationService(),
  shareCaptureService: ShareCaptureService(),
  syncService: SupabaseSyncService(null),
  now: () => DateTime(2026, 8, 14, 10),
);

Future<void> _pump(
  WidgetTester tester,
  WorkbenchController controller, {
  Size size = const Size(1280, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: PoliciesPage(
          controller: controller,
          showHeader: size.width >= AppBreakpoints.compact,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('zh_CN'));

  testWidgets('RSIP page creates a complete typed node', (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await _pump(tester, controller);

    expect(find.text('国策树'), findsOneWidget);
    expect(find.text('国策库'), findsOneWidget);
    expect(find.text('轮次历史'), findsOneWidget);
    expect(find.text('高级分析'), findsOneWidget);

    await tester.tap(find.text('添加国策'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '标题 *'), '实验后记录');
    await tester.enterText(
      find.widgetWithText(TextField, '精准规则 *'),
      '实验结束后十分钟内记录关键参数',
    );
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(controller.rsipNodes, hasLength(1));
    expect(controller.rsipNodes.single.record.title, '实验后记录');
    expect(controller.rsipNodes.single.rule, '实验结束后十分钟内记录关键参数');
    expect(controller.rsipNodes.single.stage, 'E0');
    expect(find.text('实验后记录'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('violation previews group collapse and archives to library', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await controller.setRsipAllowMultiplePerDay(true);
    final group = await controller.saveRsipNodeGroup(
      title: '零容错组',
      initialTolerance: 0,
    );
    await controller.saveRsipNode(
      title: '固定记录',
      rule: '离开实验室前保存记录',
      type: RsipNodeType.ritual,
      groupId: group.id,
    );
    await _pump(tester, controller);

    await tester.ensureVisible(find.byTooltip('标记已违反'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('标记已违反'));
    await tester.pumpAndSettle();
    expect(find.textContaining('容错耗尽'), findsOneWidget);
    expect(find.textContaining('将归档：固定记录'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, '违反原因 *'), '未在离开前保存');
    await tester.tap(find.widgetWithText(FilledButton, '确认违反'));
    await tester.pumpAndSettle();

    expect(controller.activeRsipHabits, isEmpty);
    expect(controller.rsipLibraryNodes.single.record.title, '固定记录');
    await tester.tap(find.text('国策库'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(OutlinedButton, '恢复'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow RSIP page keeps actions and tabs usable', (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await controller.saveRsipNode(
      title: '晨间检查',
      rule: '开始工作前检查今日任务',
      type: RsipNodeType.trigger,
    );
    await _pump(tester, controller, size: const Size(620, 780));

    expect(find.byTooltip('添加国策'), findsOneWidget);
    expect(find.text('晨间检查'), findsOneWidget);
    expect(find.text('触发器'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
