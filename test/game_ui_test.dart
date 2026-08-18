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

final _now = DateTime(2026, 8, 12, 10);

class _MemoryDatabase extends AppDatabase {
  final Map<String, String> metadata = {};

  @override
  Future<List<WorkspaceRecord>> loadRecords({
    bool includeDeleted = true,
  }) async => const [];

  @override
  Future<String?> readMetadata(String key) async => metadata[key];

  @override
  Future<void> writeMetadata(String key, String value) async {
    metadata[key] = value;
  }

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

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.light(),
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
    expect(find.text('目标与习惯'), findsOneWidget);
    expect(find.text('目标'), findsWidgets);
    expect(find.text('习惯'), findsOneWidget);
    expect(find.text('执行协议'), findsNothing);

    await controller.setAdvancedFeaturesEnabled(true);
    await tester.pumpWidget(
      _host(
        ProtocolsPage(
          key: const ValueKey('advanced'),
          controller: controller,
          initialTab: ProtocolTab.goals,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('执行协议'), findsOneWidget);
    expect(find.text('判例'), findsOneWidget);
    expect(find.text('分析'), findsOneWidget);
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
