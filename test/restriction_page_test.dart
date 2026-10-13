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

class _FailingDatabase extends _MemoryDatabase {
  bool failRestrictionWrites = false;

  @override
  Future<void> saveRecord(
    WorkspaceRecord record, {
    bool markDirty = true,
  }) async {
    if (failRestrictionWrites &&
        record.data['recordType'] == 'restrictionProfile') {
      throw StateError('disk full');
    }
  }
}

WorkbenchController _controller({AppDatabase? database}) => WorkbenchController(
  database: database ?? _MemoryDatabase(),
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

  testWidgets('weekly restriction summary refreshes across midnight at 320dp', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _controller();
    addTearDown(controller.dispose);
    final profile = RestrictionProfile(
      id: 'restriction-week-cache',
      title: '实验时段',
      enabled: true,
      schedules: const [
        RestrictionScheduleRule(
          id: 'sunday-night',
          label: '周日夜间',
          days: [DateTime.sunday],
          startMinutes: 22 * 60,
          endMinutes: 2 * 60,
        ),
        RestrictionScheduleRule(
          id: 'monday-day',
          label: '周一白天',
          days: [DateTime.monday],
          startMinutes: 9 * 60,
          endMinutes: 18 * 60,
        ),
      ],
    );
    await controller.addRecord(profile.toRecord());
    Widget page() => _host(
      RestrictionSection(controller: controller),
      textScaler: const TextScaler.linear(2),
    );

    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('每周限制时段'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    const original = '00:00—02:00、09:00—18:00';
    expect(find.text(original), findsOneWidget);
    await tester.ensureVisible(find.text(original));
    expect(tester.takeException(), isNull);

    final changed = profile.copyWith(
      schedules: const [
        RestrictionScheduleRule(
          id: 'sunday-night',
          label: '周日夜间',
          days: [DateTime.sunday],
          startMinutes: 21 * 60,
          endMinutes: 3 * 60,
        ),
        RestrictionScheduleRule(
          id: 'monday-day',
          label: '周一白天',
          days: [DateTime.monday],
          startMinutes: 10 * 60,
          endMinutes: 11 * 60,
        ),
      ],
    );
    await controller.updateRecord(
      changed.toRecord(existing: controller.restrictionProfileRecords.first),
    );
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    expect(find.text(original), findsNothing);
    expect(find.text('00:00—03:00、10:00—11:00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('restriction metrics fill wide space and reflow with text size', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _populatedController();
    addTearDown(controller.dispose);

    Future<List<Offset>> positions(Size size, double textScale) async {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        _host(
          RestrictionPage(controller: controller, showHeader: false),
          textScaler: TextScaler.linear(textScale),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      return [
        tester.getTopLeft(find.text('当前状态')),
        tester.getTopLeft(find.text('当前规则')),
        tester.getTopLeft(find.text('下一次切换')),
      ];
    }

    final wide = await positions(const Size(1200, 900), 1);
    expect(wide[0].dy, wide[1].dy);
    expect(wide[1].dy, wide[2].dy);
    expect(wide[1].dx - wide[0].dx, greaterThan(200));

    final medium = await positions(const Size(800, 450), 1);
    expect(medium[0].dy, medium[1].dy);
    expect(medium[1].dy, medium[2].dy);

    final compact = await positions(const Size(390, 844), 1);
    expect(compact[0].dy, compact[1].dy);
    expect(compact[2].dy, greaterThan(compact[0].dy));

    final largeText = await positions(const Size(320, 568), 2);
    expect(largeText[1].dy, greaterThan(largeText[0].dy));
    expect(largeText[2].dy, greaterThan(largeText[1].dy));
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

    await tester.ensureVisible(find.text('检测间隔'));
    await tester.pumpAndSettle();
    expect(find.text('检测间隔'), findsOneWidget);
    expect(tester.getRect(find.text('检测间隔')).top, lessThan(812));
    expect(tester.takeException(), isNull);
  });

  testWidgets('restriction editor keeps input after a save failure', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = _FailingDatabase();
    final controller = _controller(database: database);
    addTearDown(controller.dispose);
    await controller.addRecord(
      const RestrictionProfile(
        id: 'restriction-save-failure',
        title: '原规则',
      ).toRecord(),
    );
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () => showRestrictionProfileEditor(context, controller),
            child: const Text('打开编辑器'),
          ),
        ),
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.tap(find.text('打开编辑器'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '修改后的规则');
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('保存修改？'), findsOneWidget);
    await tester.tap(find.text('继续编辑'));
    await tester.pumpAndSettle();

    database.failRestrictionWrites = true;
    await tester.tap(find.widgetWithText(FilledButton, '保存').last);
    await tester.pumpAndSettle();
    expect(find.text('保存失败，当前输入已保留，请稍后重试。'), findsOneWidget);
    expect(find.text('修改后的规则'), findsOneWidget);
    expect(controller.restrictionProfile?.title, '原规则');
    expect(tester.takeException(), isNull);

    database.failRestrictionWrites = false;
    await tester.tap(find.widgetWithText(FilledButton, '保存').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.restrictionProfile?.title, '修改后的规则');
    expect(tester.takeException(), isNull);
  });

  testWidgets('schedule preview follows draft times in a narrow dialog', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () => showRestrictionProfileEditor(context, controller),
            child: const Text('打开编辑器'),
          ),
        ),
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.tap(find.text('打开编辑器'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('添加时段'));
    await tester.pump();
    await tester.tap(find.byTooltip('添加时段'));
    await tester.pump(const Duration(milliseconds: 220));
    expect(find.text('时段规则'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final fields = find.descendant(
      of: find.byType(AlertDialog).last,
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(1), '10:00');
    await tester.enterText(fields.at(2), '12:00');
    await tester.ensureVisible(find.widgetWithText(FilterChip, '一').last);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilterChip, '一').last);
    await tester.pump();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            (widget.properties.label ?? '').contains('周一：10:00 至 12:00'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
