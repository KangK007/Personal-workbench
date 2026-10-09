import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
import 'package:personal_workbench/ui/pages/growth_page.dart';
import 'package:personal_workbench/ui/pages/protocols_page.dart';
import 'package:personal_workbench/ui/pages/today_page.dart';
import 'package:personal_workbench/ui/widgets/record_editor_dialog.dart';

final _now = DateTime(2026, 8, 12, 10);

class _MemoryDatabase extends AppDatabase {
  final Map<String, String> metadata = {};

  @override
  Future<List<WorkspaceRecord>> loadRecords({
    bool includeDeleted = true,
    String? accountId,
  }) async => const [];

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
  }) async {}

  @override
  Future<String?> readLocalGameState() async => metadata['local_game_state_v1'];

  @override
  Future<void> writeLocalGameState(String value) async {
    metadata['local_game_state_v1'] = value;
  }

  @override
  Future<void> close() async {}
}

WorkbenchController _controller() {
  return WorkbenchController(
    database: _MemoryDatabase(),
    backupService: BackupService(),
    searchService: SearchService(),
    focusService: FocusService(),
    notificationService: NotificationService(),
    shareCaptureService: ShareCaptureService(),
    syncService: SupabaseSyncService(null),
    now: () => _now,
  );
}

Widget _host(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? AppTheme.light(),
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: const [Locale('zh', 'CN')],
  home: Scaffold(body: child),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('empty today has no fabricated completion percentage', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(TodayPage(controller: controller)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('今日尚未安排'), findsOneWidget);
    expect(find.text('今日已清空'), findsNothing);
    expect(find.text('0%'), findsNothing);
    expect(find.bySemanticsLabel('尚未安排任务，暂无完成进度'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('protocol page exposes simple and advanced tab sets', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await controller.setAdvancedFeaturesEnabled(false);

    await tester.pumpWidget(
      _host(
        ProtocolsPage(controller: controller, initialTab: ProtocolTab.goals),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('协议'), findsOneWidget);
    expect(find.text('执行协议'), findsOneWidget);
    expect(find.text('目标与习惯'), findsNothing);

    await controller.setAdvancedFeaturesEnabled(true);
    await tester.pumpWidget(
      _host(
        ProtocolsPage(controller: controller, initialTab: ProtocolTab.goals),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('执行协议'), findsOneWidget);
    expect(find.text('判例'), findsOneWidget);
    expect(find.text('分析'), findsOneWidget);

    await controller.setAdvancedFeaturesEnabled(false);
    await tester.pumpWidget(
      _host(
        ProtocolsPage(controller: controller, initialTab: ProtocolTab.goals),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('判例'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('growth page checkin pays once without pet controls', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await controller.setGameFeaturesEnabled(true);

    await tester.pumpWidget(_host(GrowthPage(controller: controller)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('签到 +10'), findsOneWidget);
    expect(find.textContaining('宠物'), findsNothing);
    await tester.tap(find.text('签到 +10'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.gameProfile.points, 10);
    await tester.pumpWidget(_host(GrowthPage(controller: controller)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('今日已签到'), findsOneWidget);
    expect(find.textContaining('无现金价值'), findsOneWidget);
  });

  for (final case_ in [
    (name: 'desktop day', size: const Size(1280, 800), dark: false),
    (name: 'mobile night', size: const Size(390, 844), dark: true),
  ]) {
    testWidgets('growth without local incentives keeps facts: ${case_.name}', (
      tester,
    ) async {
      tester.view.physicalSize = case_.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = _controller();
      addTearDown(controller.dispose);
      await controller.setGameFeaturesEnabled(false);
      await controller.addRecord(
        WorkspaceRecord.create(
          kind: RecordKind.growthEvent,
          title: '完成专注记录',
          data: const {'xp': 25, 'dayKey': '2026-08-12', 'category': 'focus'},
        ),
      );

      await tester.pumpWidget(
        _host(
          GrowthPage(controller: controller),
          theme: case_.dark ? AppTheme.dark() : AppTheme.light(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.textContaining('XP'), findsNothing);
      expect(find.text('当前等级'), findsNothing);
      expect(find.text('里程碑印章'), findsNothing);
      expect(find.text('本月执行账本'), findsOneWidget);
      expect(find.textContaining('累计 0 次日结'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('最近证据'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('完成专注记录'), findsOneWidget);
      expect(find.byIcon(Icons.fact_check_outlined), findsOneWidget);
      expect(find.textContaining('XP'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('empty growth ledger opens a dated task from its main action', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await controller.setGameFeaturesEnabled(false);
    await tester.pumpWidget(_host(GrowthPage(controller: controller)));
    await tester.scrollUntilVisible(
      find.text('记录今天的下一步'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(find.text('记录今天的下一步')),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('记录今天的下一步'));
    await tester.pumpAndSettle();
    final editor = tester.widget<RecordEditorDialog>(
      find.byType(RecordEditorDialog),
    );
    expect(editor.kind, RecordKind.task);
    expect(editor.initialScheduledFor, _now);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile today has no pet panel or duplicate page header', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _controller();
    addTearDown(controller.dispose);
    await controller.setGameFeaturesEnabled(true);

    await tester.pumpWidget(
      _host(TodayPage(controller: controller, showHeader: false)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('宠物'), findsNothing);
    expect(find.text('今日'), findsOneWidget);
    expect(find.text('从一件事开始'), findsOneWidget);
  });
}
