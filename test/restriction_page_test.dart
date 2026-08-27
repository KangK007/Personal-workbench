import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_workbench/core/models/restriction_models.dart';
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
import 'package:personal_workbench/ui/pages/restriction_page.dart';
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
  now: () => DateTime(2026, 8, 19, 10),
);

Widget _host(Widget child, {TextScaler? textScaler}) => MaterialApp(
  theme: AppTheme.light(),
  locale: const Locale('zh', 'CN'),
  supportedLocales: const [Locale('zh', 'CN')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  builder: textScaler == null
      ? null
      : (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
  home: Scaffold(body: child),
);

Future<WorkbenchController> _populatedController() async {
  final controller = _controller();
  final profile = RestrictionProfile(
    id: 'restriction-profile-test',
    title: '论文冲刺与实验数据整理自律规则',
    enabled: true,
    schedules: const [
      RestrictionScheduleRule(
        id: 'weekday-morning',
        label: '工作日实验与论文写作时段',
        days: [1, 2, 3, 4, 5],
        startMinutes: 9 * 60,
        endMinutes: 18 * 60,
      ),
    ],
    blockedApps: const ['game.exe', 'video.exe'],
    titleKeywordProcesses: const ['browser.exe'],
    blockedTitleKeywords: const ['短视频', '游戏直播'],
    websiteBlocking: true,
    blockedWebsites: const ['example-video.test', 'example-game.test'],
    allowBreak: true,
    strongProtection: true,
  );
  await controller.addRecord(profile.toRecord());
  await controller.addRecord(
    WorkspaceRecord(
      id: 'restriction-event-test',
      kind: RecordKind.protocolEvent,
      title: 'video.exe',
      body: '',
      status: WorkStatus.done,
      scheduledFor: DateTime(2026, 8, 19, 9, 42),
      createdAt: DateTime(2026, 8, 19, 9, 42),
      updatedAt: DateTime(2026, 8, 19, 9, 42),
      data: const {
        'recordType': 'restrictionEvent',
        'reason': '窗口标题命中：实验间隙短视频',
        'action': 'forceClose',
      },
    ),
  );
  return controller;
}

void main() {
  testWidgets('restriction section renders compact guidance', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(RestrictionSection(controller: controller)));
    await tester.pump();
    expect(find.text('尚未创建自律规则'), findsOneWidget);
    expect(find.text('当前状态'), findsOneWidget);
  });

  testWidgets('focus hub is a dedicated focus page', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(FocusHubPage(controller: controller)));
    await tester.pump();
    expect(find.text('专注'), findsOneWidget);
    expect(find.text('导入 SelfControl'), findsNothing);
    expect(find.text('自律'), findsNothing);
    expect(find.text('保护设置'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact focus hub only exposes focus actions', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _controller();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(FocusHubPage(controller: controller, showHeader: false)),
    );
    await tester.pump();

    expect(find.byTooltip('新建专注预设'), findsOneWidget);
    expect(find.byTooltip('编辑自律规则'), findsNothing);
    expect(find.byTooltip('导入 SelfControl'), findsNothing);
  });

  testWidgets('restriction page is reachable as a standalone page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(RestrictionPage(controller: controller)));
    await tester.pump();
    expect(find.text('自律'), findsOneWidget);
    expect(find.text('当前状态'), findsOneWidget);
  });

  testWidgets('populated restriction page remains readable on compact width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _populatedController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        RestrictionPage(controller: controller, showHeader: false),
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('论文冲刺与实验数据整理自律规则'), findsWidgets);
    expect(find.byType(SurfaceIcon), findsWidgets);
    expect(
      tester.getTopLeft(find.byType(SurfaceIcon).first).dx,
      greaterThanOrEqualTo(AppSpacing.pageCompact + AppSpacing.lg),
    );
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('强制结束'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('强制结束'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('restriction editor reflows dense controls on compact width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _populatedController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        RestrictionPage(controller: controller, showHeader: false),
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.tap(find.byTooltip('编辑自律规则'));
    await tester.pumpAndSettle();

    expect(find.text('编辑自律规则'), findsOneWidget);
    expect(find.byTooltip('关闭'), findsOneWidget);
    expect(find.text('工作日实验与论文写作时段'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, -1600),
    );
    await tester.pumpAndSettle();
    expect(find.text('检测间隔'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
