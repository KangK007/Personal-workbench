import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
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
  final loaders = <Future<void>>[materialIcons.load()];
  final systemChinese = File(r'C:\Windows\Fonts\simhei.ttf');
  if (systemChinese.existsSync()) {
    final bytes = await systemChinese.readAsBytes();
    loaders.add(
      (FontLoader('GoldenCjk')..addFont(
            Future.value(ByteData.sublistView(Uint8List.fromList(bytes))),
          ))
          .load(),
    );
  }
  await Future.wait(loaders);
}

Future<WorkbenchController> _createController() async {
  final controller = WorkbenchController(
    database: _MemoryDatabase(),
    backupService: BackupService(),
    searchService: SearchService(),
    focusService: FocusService(),
    notificationService: NotificationService(),
    shareCaptureService: ShareCaptureService(),
    syncService: SupabaseSyncService(null),
    now: () => _auditNow,
  );
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
  return controller;
}

Widget _host(Widget child) {
  final theme = AppTheme.light();
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
    home: Scaffold(body: child),
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
  await tester.pumpWidget(_host(child));
  await tester.pump(const Duration(milliseconds: 600));
  expect(tester.takeException(), isNull);
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('../docs/images/ui_audit/$name.png'),
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
}
