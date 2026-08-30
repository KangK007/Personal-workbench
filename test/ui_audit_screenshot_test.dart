import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_workbench/core/models/attachment.dart';
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
import 'package:personal_workbench/ui/pages/behavior_page.dart';
import 'package:personal_workbench/ui/pages/calendar_page.dart';
import 'package:personal_workbench/ui/pages/diary_page.dart';
import 'package:personal_workbench/ui/pages/focus_page.dart';
import 'package:personal_workbench/ui/pages/goals_page.dart';
import 'package:personal_workbench/ui/pages/growth_page.dart';
import 'package:personal_workbench/ui/pages/habits_page.dart';
import 'package:personal_workbench/ui/pages/inbox_page.dart';
import 'package:personal_workbench/ui/pages/more_page.dart';
import 'package:personal_workbench/ui/pages/notes_page.dart';
import 'package:personal_workbench/ui/pages/plan_page.dart';
import 'package:personal_workbench/ui/pages/policies_page.dart';
import 'package:personal_workbench/ui/pages/projects_page.dart';
import 'package:personal_workbench/ui/pages/protocols_page.dart';
import 'package:personal_workbench/ui/pages/review_page.dart';
import 'package:personal_workbench/ui/pages/restriction_page.dart';
import 'package:personal_workbench/ui/pages/settings_page.dart';
import 'package:personal_workbench/ui/pages/today_page.dart';

class _MemoryDatabase extends AppDatabase {
  final Map<String, WorkspaceRecord> records = {};

  @override
  Future<void> saveRecord(
    WorkspaceRecord record, {
    bool markDirty = true,
  }) async {
    records['${record.kind.name}:${record.id}'] = record;
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
  Future<void> permanentlyDeleteRecords(
    Iterable<({String id, RecordKind kind})> values,
  ) async {
    for (final value in values) {
      records.remove('${value.kind.name}:${value.id}');
    }
  }

  @override
  Future<void> close() async {}

  @override
  Future<List<Attachment>> loadAttachments({String? ownerRecordId}) async =>
      const [];

  @override
  Future<int> attachmentBytes() async => 0;
}

final _auditNow = DateTime(2026, 8, 9, 10);

Future<void> _loadAuditFonts() async {
  final materialIcons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  final display = FontLoader(AppFonts.display)
    ..addFont(rootBundle.load('assets/fonts/LXGWWenKaiGB-Medium.ttf'));
  final goldenCjk = FontLoader('GoldenCjk')
    ..addFont(rootBundle.load('assets/fonts/LXGWWenKaiGB-Medium.ttf'));
  final body = FontLoader(AppFonts.body)
    ..addFont(rootBundle.load('assets/fonts/IBMPlexSansSC-Regular.otf'))
    ..addFont(rootBundle.load('assets/fonts/IBMPlexSansSC-Medium.otf'))
    ..addFont(rootBundle.load('assets/fonts/IBMPlexSansSC-SemiBold.otf'));
  final numeric = FontLoader(AppFonts.numeric)
    ..addFont(rootBundle.load('assets/fonts/IBMPlexMono-Medium.ttf'));
  await Future.wait([
    materialIcons.load(),
    display.load(),
    goldenCjk.load(),
    body.load(),
    numeric.load(),
  ]);
}

Future<WorkbenchController> _createEmptyController() async =>
    WorkbenchController(
      database: _MemoryDatabase(),
      backupService: BackupService(),
      searchService: SearchService(),
      focusService: FocusService(),
      notificationService: NotificationService(),
      shareCaptureService: ShareCaptureService(),
      syncService: SupabaseSyncService(null),
      now: () => _auditNow,
    );

Future<WorkbenchController> _createController() async {
  final controller = await _createEmptyController();
  final project = WorkspaceRecord.create(
    kind: RecordKind.project,
    title: '行射实验论文复核',
    body: '整理数据、复核误差来源，并形成可追溯的论文图。',
    favorite: true,
  );
  final task = WorkspaceRecord.create(
    kind: RecordKind.task,
    title: '核对采样间隔与单位',
    body: '确认 Nyquist 条件和传播距离。',
    scheduledFor: _auditNow,
    projectId: project.id,
    data: const {'isFocus': true, 'priority': 3, 'estimatedMinutes': 25},
  );
  final records = <WorkspaceRecord>[
    project,
    task,
    WorkspaceRecord.create(
      kind: RecordKind.task,
      title: '整理实验数据与误差记录',
      status: WorkStatus.done,
      projectId: project.id,
      data: const {'estimatedMinutes': 50},
    ),
    WorkspaceRecord.create(
      kind: RecordKind.task,
      title: '阅读角谱传播采样条件笔记',
      status: WorkStatus.todo,
      projectId: project.id,
    ),
    WorkspaceRecord(
      id: newRecordId(),
      kind: RecordKind.note,
      title: '角谱传播采样检查清单',
      body: '记录输入场、波长、采样间隔和单位。',
      projectId: project.id,
      tags: const ['ASM', '采样'],
      createdAt: _auditNow,
      updatedAt: _auditNow,
    ),
    WorkspaceRecord.create(
      kind: RecordKind.link,
      title: '待整理的参考链接',
      body: 'https://example.com',
      status: WorkStatus.inbox,
      data: const {'inbox': true},
    ),
    WorkspaceRecord.create(
      kind: RecordKind.goal,
      title: '完成论文图表复核',
      dueAt: _auditNow.add(const Duration(days: 30)),
    ),
    WorkspaceRecord.create(
      kind: RecordKind.milestone,
      title: '确认图轴单位',
      dueAt: _auditNow.add(const Duration(days: 7)),
    ),
    WorkspaceRecord.create(
      kind: RecordKind.habit,
      title: '每日记录实验进展',
      data: const {'frequency': 'daily'},
    ),
    WorkspaceRecord.create(
      kind: RecordKind.diary,
      title: '今日实验回顾',
      body: '完成数据清洗，下一步检查误差来源。',
      scheduledFor: _auditNow,
      data: const {'mood': 4, 'completedToday': '采样复核'},
    ),
    WorkspaceRecord.create(
      kind: RecordKind.focusSession,
      title: '角谱传播复核',
      scheduledFor: _auditNow.subtract(const Duration(hours: 1)),
      data: const {'seconds': 1500},
    ),
    WorkspaceRecord.create(
      kind: RecordKind.timeBlock,
      title: '论文图表复核时段',
      parentId: task.id,
      scheduledFor: DateTime(2026, 8, 9, 9),
      data: const {'durationMinutes': 60},
    ),
  ];
  for (final record in records) {
    await controller.addRecord(record);
  }
  await controller.addRecord(
    const RestrictionProfile(
      id: 'restriction-profile-audit',
      title: '论文冲刺自律',
      enabled: true,
      schedules: [
        RestrictionScheduleRule(
          id: 'weekday-daytime',
          label: '工作日实验与写作',
          days: [1, 2, 3, 4, 5],
          startMinutes: 9 * 60,
          endMinutes: 18 * 60,
        ),
        RestrictionScheduleRule(
          id: 'evening-review',
          label: '晚间论文复核',
          days: [1, 3, 5],
          startMinutes: 19 * 60 + 30,
          endMinutes: 22 * 60,
        ),
      ],
      blockedApps: ['game.exe', 'video.exe'],
      blockedTitleKeywords: ['短视频', '游戏直播'],
      websiteBlocking: true,
      blockedWebsites: ['example-video.test', 'example-game.test'],
      allowBreak: true,
      strongProtection: true,
    ).toRecord(),
  );
  await controller.addRecord(
    WorkspaceRecord(
      id: 'restriction-event-audit',
      kind: RecordKind.protocolEvent,
      title: 'video.exe',
      body: '',
      status: WorkStatus.done,
      scheduledFor: _auditNow.subtract(const Duration(minutes: 18)),
      createdAt: _auditNow.subtract(const Duration(minutes: 18)),
      updatedAt: _auditNow.subtract(const Duration(minutes: 18)),
      data: const {
        'recordType': 'restrictionEvent',
        'reason': '窗口标题命中：短视频',
        'action': 'forceClose',
      },
    ),
  );
  return controller;
}

Widget _host(
  Widget page, {
  Brightness brightness = Brightness.light,
  TextScaler textScaler = TextScaler.noScaling,
  bool disableAnimations = false,
}) {
  final theme = brightness == Brightness.dark
      ? AppTheme.dark()
      : AppTheme.light();
  final goldenTheme = theme.copyWith(
    textTheme: theme.textTheme.apply(fontFamily: 'GoldenCjk'),
    primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: 'GoldenCjk'),
  );
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: goldenTheme,
    locale: const Locale('zh', 'CN'),
    supportedLocales: const [Locale('zh', 'CN')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) {
      final media = MediaQuery.of(context);
      return MediaQuery(
        data: media.copyWith(
          textScaler: textScaler,
          disableAnimations: disableAnimations,
        ),
        child: child!,
      );
    },
    home: Scaffold(body: page),
  );
}

Future<void> _capture(
  WidgetTester tester,
  String name,
  Widget child, {
  Size size = const Size(1200, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  // 每张页面截图使用全新的 Navigator，避免前一张图的弹窗路由残留。
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pumpWidget(_host(child));
  await tester.pump(const Duration(milliseconds: 600));
  expect(tester.takeException(), isNull);
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/ui_audit/$name.png'),
  );
}

Future<void> _captureRestrictionEditor(
  WidgetTester tester,
  WorkbenchController controller,
  String name, {
  required Size size,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  final compact = size.width < AppBreakpoints.compact;
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pumpWidget(
    _host(RestrictionPage(controller: controller, showHeader: !compact)),
  );
  await tester.pump(const Duration(milliseconds: 600));
  await tester.tap(
    compact ? find.byTooltip('编辑自律规则') : find.byTooltip('编辑规则').first,
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/ui_audit/$name.png'),
  );
}

class _AuditSurface {
  const _AuditSurface(this.name, this.builder);

  final String name;
  final Widget Function(Size size) builder;
}

List<_AuditSurface> _auditSurfaces(WorkbenchController controller) => [
  _AuditSurface(
    'today',
    (size) => TodayPage(
      controller: controller,
      showHeader: size.width >= AppBreakpoints.compact,
    ),
  ),
  for (final tab in PlanTab.values)
    _AuditSurface(
      'tasks_${tab.name}',
      (size) => PlanPage(
        controller: controller,
        initialTab: tab,
        showHeader: size.width >= AppBreakpoints.compact,
        showTabs: false,
      ),
    ),
  for (final tab in ProjectDetailTab.values)
    _AuditSurface(
      'projects_${tab.name}',
      (size) => ProjectsPage(
        controller: controller,
        initialTab: tab,
        showHeader: size.width >= AppBreakpoints.compact,
        showTabs: false,
      ),
    ),
  _AuditSurface(
    'focus_hub',
    (size) => FocusHubPage(
      controller: controller,
      showHeader: size.width >= AppBreakpoints.compact,
    ),
  ),
  _AuditSurface(
    'focus_session',
    (_) => FocusPage(
      controller: controller,
      task: controller.focusTasks.firstOrNull,
    ),
  ),
  _AuditSurface(
    'restriction',
    (size) => RestrictionPage(
      controller: controller,
      showHeader: size.width >= AppBreakpoints.compact,
    ),
  ),
  _AuditSurface(
    'notes',
    (size) => NotesPage(
      controller: controller,
      showHeader: size.width >= AppBreakpoints.compact,
    ),
  ),
  for (final tab in ReviewTab.values)
    _AuditSurface(
      'review_${tab.name}',
      (size) => ReviewPage(
        controller: controller,
        initialTab: tab,
        showHeader: size.width >= AppBreakpoints.compact,
        showPeriodSwitcher: false,
      ),
    ),
  _AuditSurface(
    'legacy_diary',
    (size) => DiaryPage(
      controller: controller,
      showHeader: size.width >= AppBreakpoints.compact,
    ),
  ),
  _AuditSurface(
    'goals',
    (size) => GoalsPage(
      controller: controller,
      showHeader: size.width >= AppBreakpoints.compact,
    ),
  ),
  _AuditSurface(
    'habits',
    (size) => HabitsPage(
      controller: controller,
      showHeader: size.width >= AppBreakpoints.compact,
    ),
  ),
  _AuditSurface(
    'behavior_habits',
    (size) => BehaviorPage(
      controller: controller,
      initialMode: BehaviorMode.habits,
      showHeader: size.width >= AppBreakpoints.compact,
    ),
  ),
  for (final tab in PolicyTab.values)
    _AuditSurface(
      'behavior_policies_${tab.name}',
      (size) => BehaviorPage(
        controller: controller,
        initialMode: BehaviorMode.policies,
        initialPolicyTab: tab,
        showHeader: size.width >= AppBreakpoints.compact,
      ),
    ),
  for (final tab in PolicyTab.values)
    _AuditSurface(
      'policies_${tab.name}',
      (size) => PoliciesPage(
        controller: controller,
        initialTab: tab,
        showHeader: size.width >= AppBreakpoints.compact,
        showTabs: false,
      ),
    ),
  for (final tab in ProtocolTab.values)
    _AuditSurface(
      'legacy_protocols_${tab.name}',
      (size) => ProtocolsPage(
        controller: controller,
        initialTab: tab,
        showHeader: size.width >= AppBreakpoints.compact,
      ),
    ),
  _AuditSurface(
    'growth',
    (size) => GrowthPage(
      controller: controller,
      showHeader: size.width >= AppBreakpoints.compact,
    ),
  ),
  _AuditSurface(
    'settings',
    (size) => SettingsPage(
      controller: controller,
      showHeader: size.width >= AppBreakpoints.compact,
    ),
  ),
  _AuditSurface('more', (_) => MorePage(onSelected: (_) {})),
];

Future<void> _verifySurface(
  WidgetTester tester,
  _AuditSurface surface,
  Size size, {
  Brightness brightness = Brightness.light,
  TextScaler textScaler = TextScaler.noScaling,
  bool disableAnimations = false,
  required String scenario,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  expect(
    tester.takeException(),
    isNull,
    reason:
        'previous surface failed while switching to ${surface.name} '
        'at $size ($scenario)',
  );
  await tester.pumpWidget(
    _host(
      surface.builder(size),
      brightness: brightness,
      textScaler: textScaler,
      disableAnimations: disableAnimations,
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  expect(
    tester.takeException(),
    isNull,
    reason: '${surface.name} failed at $size ($scenario)',
  );
  expect(
    find.byType(Semantics),
    findsWidgets,
    reason: '${surface.name} has no semantics at $size ($scenario)',
  );
}

void main() {
  setUpAll(_loadAuditFonts);

  testWidgets('captures the remaining UI audit surfaces', (tester) async {
    final controller = await _createController();
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _capture(
      tester,
      'plan_desktop',
      PlanPage(
        controller: controller,
        onOpenInbox: () {},
        onOpenCalendar: () {},
        onOpenProjects: () {},
      ),
    );
    await _capture(
      tester,
      'calendar_desktop',
      CalendarPage(controller: controller),
    );
    await _capture(tester, 'inbox_desktop', InboxPage(controller: controller));
    await _capture(
      tester,
      'projects_desktop',
      ProjectsPage(controller: controller),
    );
    await _capture(
      tester,
      'focus_hub_desktop',
      FocusHubPage(controller: controller),
    );
    await _capture(tester, 'notes_desktop', NotesPage(controller: controller));
    await _capture(
      tester,
      'review_desktop',
      ReviewPage(controller: controller),
    );
    await _capture(tester, 'diary_desktop', DiaryPage(controller: controller));
    await _capture(tester, 'goals_desktop', GoalsPage(controller: controller));
    await _capture(
      tester,
      'habits_desktop',
      HabitsPage(controller: controller),
    );
    await _capture(
      tester,
      'policies_desktop',
      PoliciesPage(controller: controller),
    );
    await _capture(
      tester,
      'protocols_desktop',
      ProtocolsPage(controller: controller),
    );
    await _capture(
      tester,
      'restriction_desktop',
      RestrictionPage(controller: controller),
    );
    await _capture(
      tester,
      'restriction_mobile',
      RestrictionPage(controller: controller, showHeader: false),
      size: const Size(412, 915),
    );
    await _captureRestrictionEditor(
      tester,
      controller,
      'restriction_editor_desktop',
      size: const Size(1200, 900),
    );
    await _captureRestrictionEditor(
      tester,
      controller,
      'restriction_editor_mobile',
      size: const Size(412, 915),
    );
    await _capture(
      tester,
      'growth_desktop',
      GrowthPage(controller: controller),
    );
    await _capture(
      tester,
      'settings_desktop',
      SettingsPage(controller: controller),
    );
    await _capture(
      tester,
      'more_mobile',
      MorePage(onSelected: (_) {}),
      size: const Size(412, 915),
    );
    await _capture(
      tester,
      'focus_session_desktop',
      FocusPage(controller: controller, task: controller.tasks.first),
    );
    await _capture(
      tester,
      'today_mobile',
      TodayPage(controller: controller),
      size: const Size(412, 915),
    );
  });

  testWidgets('reduced-motion skeletons can unmount repeatedly', (
    tester,
  ) async {
    final controller = await _createController();
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(1200, 864);
    tester.view.devicePixelRatio = 1;
    for (var index = 0; index < 3; index++) {
      await tester.pumpWidget(
        _host(NotesPage(controller: controller), disableAnimations: true),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('all mapped surfaces survive the complete layout matrix', (
    tester,
  ) async {
    final populated = await _createController();
    final empty = await _createEmptyController();
    addTearDown(populated.dispose);
    addTearDown(empty.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const viewports = [
      Size(375, 812),
      Size(412, 915),
      Size(768, 864),
      Size(1024, 864),
      Size(1200, 864),
      Size(1440, 900),
      Size(1536, 864),
    ];
    for (final surface in _auditSurfaces(populated)) {
      for (final size in viewports) {
        await _verifySurface(tester, surface, size, scenario: 'light');
      }
      for (final size in const [Size(412, 915), Size(1200, 864)]) {
        await _verifySurface(
          tester,
          surface,
          size,
          brightness: Brightness.dark,
          scenario: 'dark',
        );
        await _verifySurface(
          tester,
          surface,
          size,
          disableAnimations: true,
          scenario: 'reduced-motion',
        );
      }
      await _verifySurface(
        tester,
        surface,
        const Size(375, 812),
        textScaler: const TextScaler.linear(2),
        scenario: 'text-200-percent',
      );
    }

    for (final surface in _auditSurfaces(empty)) {
      for (final size in const [Size(412, 915), Size(1200, 864)]) {
        await _verifySurface(tester, surface, size, scenario: 'empty');
      }
    }
  });
}
