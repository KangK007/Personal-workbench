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
import 'package:personal_workbench/ui/pages/focus_page.dart';
import 'package:personal_workbench/ui/pages/goals_page.dart';
import 'package:personal_workbench/ui/pages/growth_hub_page.dart';
import 'package:personal_workbench/ui/pages/habits_page.dart';
import 'package:personal_workbench/ui/widgets/common.dart';

class _MemoryDatabase extends AppDatabase {
  @override
  Future<void> saveRecord(
    WorkspaceRecord record, {
    bool markDirty = true,
  }) async {}

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
  now: () => DateTime(2026, 10, 15, 12),
);

Widget _host(Widget child, {double scale = 1}) => MaterialApp(
  theme: AppTheme.light(),
  locale: const Locale('zh', 'CN'),
  supportedLocales: const [Locale('zh', 'CN')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true),
    child: child!,
  ),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('focus dial reflects a selected duration before start', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _host(FocusPage(controller: controller, task: null), scale: 2),
    );
    await tester.pumpAndSettle();
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('尚未开始'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hidden growth tabs keep create actions reachable', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _controller();
    addTearDown(controller.dispose);
    await controller.addRecord(
      WorkspaceRecord.create(kind: RecordKind.goal, title: '成长目标'),
    );
    await controller.addRecord(
      WorkspaceRecord.create(kind: RecordKind.habit, title: '成长习惯'),
    );
    for (final page in [
      GoalsPage(
        key: const ValueKey('goals-create'),
        controller: controller,
        showHeader: false,
        showCreateAction: true,
      ),
      HabitsPage(
        key: const ValueKey('habits-create'),
        controller: controller,
        showHeader: false,
        showCreateAction: true,
      ),
    ]) {
      await tester.pumpWidget(_host(page));
      await tester.pumpAndSettle();
      expect(find.text(page is GoalsPage ? '新建目标' : '新建习惯'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'growth hub enables those actions without exposing duplicate headers',
    (tester) async {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = _controller();
      addTearDown(controller.dispose);
      await controller.addRecord(
        WorkspaceRecord.create(kind: RecordKind.goal, title: '成长目标'),
      );
      await tester.pumpWidget(
        _host(
          GrowthHubPage(
            controller: controller,
            initialTab: GrowthTab.goals,
            showHeader: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('新建目标'), findsOneWidget);
      expect(find.byType(PageHeader), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
