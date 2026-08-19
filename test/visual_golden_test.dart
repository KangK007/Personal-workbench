import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:personal_workbench/ui/pages/calendar_page.dart';
import 'package:personal_workbench/ui/pages/focus_page.dart';
import 'package:personal_workbench/ui/pages/growth_page.dart';
import 'package:personal_workbench/ui/pages/notes_page.dart';
import 'package:personal_workbench/ui/pages/policies_page.dart';
import 'package:personal_workbench/ui/pages/projects_page.dart';
import 'package:personal_workbench/ui/pages/protocols_page.dart';
import 'package:personal_workbench/ui/pages/review_page.dart';
import 'package:personal_workbench/ui/pages/today_page.dart';
import 'package:personal_workbench/ui/widgets/record_editor_dialog.dart';
import 'package:personal_workbench/ui/workbench_shell.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final _visualDate = DateTime(2026, 8, 7, 12);

Future<void> _loadGoldenFonts() async {
  final materialIcons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await materialIcons.load();

  final systemChinese = File(r'C:\Windows\Fonts\simhei.ttf');
  if (systemChinese.existsSync()) {
    final bytes = await systemChinese.readAsBytes();
    final chinese = FontLoader('GoldenCjk')
      ..addFont(Future.value(ByteData.sublistView(Uint8List.fromList(bytes))));
    await chinese.load();
  }
}

var _fixtureCounter = 0;

class _Fixture {
  const _Fixture(this.controller, this.databasePath);
  final WorkbenchController controller;
  final String databasePath;
}

Future<_Fixture> _createFixture({
  bool startToday = true,
  bool seed = true,
}) async {
  final databasePath =
      '${Directory.systemTemp.path}${Platform.pathSeparator}personal-workbench-golden-${_fixtureCounter++}.sqlite';
  final controller = WorkbenchController(
    database: AppDatabase(
      factory: databaseFactoryFfi,
      overridePath: databasePath,
    ),
    backupService: BackupService(),
    searchService: SearchService(),
    focusService: FocusService(),
    notificationService: NotificationService(),
    shareCaptureService: ShareCaptureService(),
    syncService: SupabaseSyncService(null),
    now: () => _visualDate,
  );
  if (!seed) {
    await controller.initialize();
    return _Fixture(controller, databasePath);
  }
  final today = DateTime(
    _visualDate.year,
    _visualDate.month,
    _visualDate.day,
    9,
  );
  final tasks = [
    WorkspaceRecord.create(
      kind: RecordKind.task,
      title: '整理衍射实验数据与误差记录',
      scheduledFor: today,
      data: const {'estimatedMinutes': 50, 'priority': 3},
    ),
    WorkspaceRecord.create(
      kind: RecordKind.task,
      title: '校对论文图 3 的坐标轴与单位',
      scheduledFor: today,
      data: const {'estimatedMinutes': 35, 'priority': 2},
    ),
    WorkspaceRecord.create(
      kind: RecordKind.task,
      title: '阅读角谱传播采样条件笔记',
      scheduledFor: today,
      data: const {'estimatedMinutes': 25, 'priority': 1},
    ),
    WorkspaceRecord.create(
      kind: RecordKind.task,
      title: '归档本周组会记录',
      scheduledFor: today,
    ),
  ];
  final habit = WorkspaceRecord.create(
    kind: RecordKind.habit,
    title: '实验记录复核',
    data: const {'frequency': 'daily'},
  );
  final protocolTask = WorkspaceRecord.create(
    kind: RecordKind.task,
    title: '复核一组衍射实验参数',
    data: const {
      'protocol': 'ctdp',
      'ctdpTrigger': '打开实验日志并戴上耳机',
      'ctdpAuxSignal': '预约闹钟响起',
      'ctdpAuxCompletionTrigger': '在截止前打开实验日志',
      'ctdpSessionMinutes': 25,
      'ctdpDelayMinutes': 15,
      'ctdpChainCount': 6,
      'ctdpAuxChainCount': 4,
      'ctdpTotalCompletions': 18,
      'ctdpTotalFailures': 2,
    },
  );
  final protocolHabit = WorkspaceRecord.create(
    kind: RecordKind.habit,
    title: '每日核对一个实验参数',
    data: const {
      'protocol': 'rsip',
      'rsipMinimumAction': '只核对一条参数',
      'rsipRule': '核对原始记录并写下单位',
      'rsipTrigger': '晚饭后坐到书桌前',
      'rsipGroup': '实验记录',
      'rsipActive': true,
      'rsipChainCount': 9,
      'rsipInternalization': 36,
    },
  );
  for (final record in [...tasks, habit, protocolTask, protocolHabit]) {
    await controller.addRecord(record);
  }
  await controller.createExceptionRule(
    name: '仪器安全报警',
    description: '仅在设备或人员安全相关报警出现时允许暂停。',
    ruleType: 'pause',
    chainId: protocolTask.id,
  );
  await controller.startCtdpReservation(protocolTask);
  if (startToday) {
    await controller.startToday(
      commitments: tasks.take(3).toList(),
      plannedHabits: [habit],
    );
    await controller.toggleTaskDone(controller.commitmentTasks.first);
  }

  final friday = _visualDate;
  for (final block in [
    WorkspaceRecord.create(
      kind: RecordKind.timeBlock,
      title: '实验数据清洗',
      parentId: tasks[0].id,
      scheduledFor: DateTime(friday.year, friday.month, friday.day, 9),
      data: const {'durationMinutes': 90},
    ),
    WorkspaceRecord.create(
      kind: RecordKind.timeBlock,
      title: '论文图复核',
      parentId: tasks[1].id,
      scheduledFor: DateTime(friday.year, friday.month, friday.day, 10),
      data: const {'durationMinutes': 75},
    ),
    WorkspaceRecord.create(
      kind: RecordKind.timeBlock,
      title: '文献阅读',
      parentId: tasks[2].id,
      scheduledFor: DateTime(friday.year, friday.month, friday.day, 14),
      data: const {'durationMinutes': 50},
    ),
  ]) {
    await controller.addRecord(block);
  }

  for (var index = 1; index <= 14; index++) {
    final day = _visualDate.subtract(Duration(days: index));
    final key = controller.growthService.dayKey(day);
    await controller.addRecord(
      WorkspaceRecord.create(
        kind: RecordKind.dailyPlan,
        title: '每日收尾',
        scheduledFor: day,
        status: WorkStatus.done,
        data: {'dayKey': key, 'closedAt': day.toUtc().toIso8601String()},
      ),
    );
  }
  for (final event in [
    ('完成承诺 1', 20, 'commitment'),
    ('承诺专注 45 分钟', 15, 'focus'),
    ('完成计分习惯', 5, 'habit'),
    ('完成每日收尾', 10, 'review'),
  ]) {
    await controller.addRecord(
      WorkspaceRecord.create(
        kind: RecordKind.growthEvent,
        title: event.$1,
        scheduledFor: _visualDate,
        status: WorkStatus.done,
        data: {
          'baseKey': 'visual:${event.$3}',
          'xp': event.$2,
          'category': event.$3,
          'dayKey': '2026-08-07',
        },
      ),
    );
  }
  await controller.setGameFeaturesEnabled(true);
  await controller.performDailyCheckin();
  return _Fixture(controller, databasePath);
}

Future<_Fixture> _createGuideFixture() async {
  final fixture = await _createFixture();
  final controller = fixture.controller;
  final project = WorkspaceRecord.create(
    kind: RecordKind.project,
    title: '衍射实验论文图复核',
    body: '整理数据、复核误差来源，并形成可追溯的论文图。',
    data: const {
      'progress': 55,
      'tags': ['论文图', '衍射'],
    },
  );
  await controller.addRecord(project);
  final projectTask = controller.tasks.first;
  await controller.updateRecord(projectTask.copyWith(projectId: project.id));
  final noteSeed = WorkspaceRecord.create(
    kind: RecordKind.note,
    title: '角谱传播采样检查清单',
    body:
        '## 本轮结论\n\n- 记录输入面像素尺寸和单位\n- 核对 fftshift 顺序\n- 保存传播距离与波长\n\n[关联分析脚本](https://example.com/analysis)',
    projectId: project.id,
    tags: const ['ASM', '采样'],
    favorite: true,
  );
  await controller.addRecord(
    WorkspaceRecord(
      id: noteSeed.id,
      kind: noteSeed.kind,
      title: noteSeed.title,
      body: noteSeed.body,
      status: noteSeed.status,
      createdAt: _visualDate,
      updatedAt: _visualDate,
      projectId: noteSeed.projectId,
      tags: noteSeed.tags,
      favorite: noteSeed.favorite,
      data: noteSeed.data,
    ),
  );
  await controller.saveFocusPreset(
    title: '论文图参数复核',
    mode: FocusMode.custom,
    minutes: 45,
    taskId: projectTask.id,
    scheduleMode: 'weekly',
    scheduledAt: DateTime(2026, 8, 7, 20),
    weekdays: const [1, 3, 5],
  );
  final dayStart = controller.growthService.logicalDay(_visualDate);
  await controller.savePeriodReview(
    type: ReviewPeriodType.daily,
    periodKey: controller.growthService.dayKey(_visualDate),
    periodStart: dayStart,
    periodEnd: dayStart.add(const Duration(days: 1)),
    body: '完成了数据清洗和图 3 单位复核。下一步检查误差条来源。',
    relatedTaskIds: [projectTask.id],
    relatedProjectIds: [project.id],
  );

  final group = await controller.saveRsipNodeGroup(
    title: '实验记录闭环',
    emoji: '🧪',
    initialTolerance: 2,
  );
  final root = WorkspaceRecord.create(
    kind: RecordKind.habit,
    title: '每日实验记录收尾',
    data: {
      'protocol': 'rsip',
      'recordType': 'rsipNode',
      'rsipNodeType': RsipNodeType.policy.name,
      'rsipRule': '当天实验结束后核对一条参数并写明单位',
      'rsipMinimumAction': '核对一条参数',
      'rsipGroupId': group.id,
      'rsipEmoji': '🧭',
      'rsipActive': true,
      'rsipChainCount': 9,
      'rsipCumulativeExecutions': 18,
    },
  );
  final child = WorkspaceRecord.create(
    kind: RecordKind.habit,
    title: '记录异常点处理依据',
    parentId: root.id,
    data: {
      'protocol': 'rsip',
      'recordType': 'rsipNode',
      'rsipNodeType': RsipNodeType.reminder.name,
      'rsipRule': '出现剔除点时同步保存阈值、原始索引和理由',
      'rsipMinimumAction': '写下一条异常点理由',
      'rsipGroupId': group.id,
      'rsipEmoji': '🔎',
      'rsipPassive': true,
      'rsipActive': true,
      'rsipChainCount': 3,
    },
  );
  final archived = WorkspaceRecord.create(
    kind: RecordKind.habit,
    title: '旧版晨间参数抄录',
    data: {
      'protocol': 'rsip',
      'recordType': 'rsipNode',
      'rsipNodeType': RsipNodeType.ritual.name,
      'rsipRule': '抄录当天仪器初始参数',
      'rsipMinimumAction': '抄录一项',
      'rsipEmoji': '📋',
      'rsipActive': true,
      'rsipChainCount': 7,
      'rsipCumulativeExecutions': 26,
    },
  );
  await controller.addRecord(root);
  await controller.addRecord(child);
  await controller.addRecord(archived);
  await controller.archiveRsipNode(archived, reason: '已合并到实验记录收尾流程');
  return fixture;
}

Widget _host(Widget child, {required bool dark}) {
  final light = AppTheme.light();
  final darkTheme = AppTheme.dark();
  ThemeData goldenTheme(ThemeData theme) {
    // Test-only system font fixture keeps pixel output deterministic.
    return theme.copyWith(
      textTheme: theme.textTheme.apply(fontFamily: 'GoldenCjk'),
      primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: 'GoldenCjk'),
    );
  }

  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: goldenTheme(light),
    darkTheme: goldenTheme(darkTheme),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
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

Future<void> _pumpGolden(
  WidgetTester tester,
  Widget child, {
  required Size size,
  required String fileName,
  bool dark = false,
  Finder? captureFinder,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(_host(child, dark: dark));
  await tester.pump(const Duration(milliseconds: 600));
  await expectLater(
    captureFinder ?? find.byType(Scaffold),
    matchesGoldenFile('goldens/$fileName.png'),
  );
}

Finder _textFieldWithLabel(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<void> _pumpDocumentationForm(
  WidgetTester tester,
  Widget child, {
  required String fileName,
  required Future<void> Function() fill,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(900, 1180);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(_host(Center(child: child), dark: false));
  await tester.pump(const Duration(milliseconds: 600));
  await fill();
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 600));
  await expectLater(
    find.byType(Scaffold),
    matchesGoldenFile('../docs/images/$fileName.png'),
  );
}

Future<void> _pumpDocumentationPage(
  WidgetTester tester,
  Widget child, {
  required String fileName,
  Future<void> Function()? beforeCapture,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1440, 900);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(_host(child, dark: false));
  await tester.pump(const Duration(milliseconds: 800));
  await beforeCapture?.call();
  await tester.pump(const Duration(milliseconds: 500));
  await expectLater(
    find.byType(Scaffold),
    matchesGoldenFile('../docs/images/$fileName.png'),
  );
}

void main() {
  late _Fixture fixture;
  late _Fixture guideFixture;
  late _Fixture unstartedFixture;
  late _Fixture emptyFixture;

  setUpAll(() async {
    sqfliteFfiInit();
    await _loadGoldenFonts();
    fixture = await _createFixture();
    guideFixture = await _createGuideFixture();
    unstartedFixture = await _createFixture(startToday: false);
    emptyFixture = await _createFixture(seed: false);
  });

  tearDownAll(() async {
    fixture.controller.focusService.dispose();
    await fixture.controller.database.close();
    File(fixture.databasePath).deleteSync();
    guideFixture.controller.focusService.dispose();
    await guideFixture.controller.database.close();
    File(guideFixture.databasePath).deleteSync();
    unstartedFixture.controller.focusService.dispose();
    await unstartedFixture.controller.database.close();
    File(unstartedFixture.databasePath).deleteSync();
    emptyFixture.controller.focusService.dispose();
    await emptyFixture.controller.database.close();
    File(emptyFixture.databasePath).deleteSync();
  });

  test('visual fixture stays isolated and deterministic', () {
    expect(fixture.controller.tasks, hasLength(5));
    expect(fixture.controller.timeBlocks, hasLength(3));
    expect(fixture.controller.growthSnapshot.totalXp, 70);
  });

  testWidgets('Wide today light', (tester) async {
    await _pumpGolden(
      tester,
      TodayPage(controller: fixture.controller, date: _visualDate),
      size: const Size(1536, 864),
      fileName: 'wide_today_light',
    );
  });

  testWidgets('Wide today dark', (tester) async {
    await _pumpGolden(
      tester,
      TodayPage(controller: fixture.controller, date: _visualDate),
      size: const Size(1536, 864),
      fileName: 'wide_today_dark',
      dark: true,
    );
  });

  testWidgets('Wide workweek conflict', (tester) async {
    await _pumpGolden(
      tester,
      CalendarPage(controller: fixture.controller, initialDate: _visualDate),
      size: const Size(1536, 864),
      fileName: 'wide_workweek_conflict',
    );
  });

  testWidgets('Android today', (tester) async {
    await _pumpGolden(
      tester,
      WorkbenchShell(controller: fixture.controller, enableSystemHotkey: false),
      size: const Size(412, 915),
      fileName: 'android_today',
      captureFinder: find.byType(Scaffold).last,
    );
  });

  testWidgets('Android growth', (tester) async {
    await _pumpGolden(
      tester,
      GrowthPage(controller: fixture.controller, now: _visualDate),
      size: const Size(412, 915),
      fileName: 'android_growth',
    );
  });

  testWidgets('Wide protocols light', (tester) async {
    await _pumpGolden(
      tester,
      ProtocolsPage(controller: fixture.controller),
      size: const Size(1536, 864),
      fileName: 'wide_protocols_light',
    );
  });

  testWidgets('Wide shell today light', (tester) async {
    await _pumpGolden(
      tester,
      WorkbenchShell(controller: fixture.controller, enableSystemHotkey: false),
      size: const Size(1536, 864),
      fileName: 'wide_shell_today_light',
      captureFinder: find.byType(Scaffold).last,
    );
  });

  testWidgets('Wide shell today dark', (tester) async {
    await _pumpGolden(
      tester,
      WorkbenchShell(controller: fixture.controller, enableSystemHotkey: false),
      size: const Size(1536, 864),
      fileName: 'wide_shell_today_dark',
      dark: true,
      captureFinder: find.byType(Scaffold).last,
    );
  });

  testWidgets('Wide shell unstarted today light', (tester) async {
    await _pumpGolden(
      tester,
      WorkbenchShell(
        controller: unstartedFixture.controller,
        enableSystemHotkey: false,
      ),
      size: const Size(1536, 864),
      fileName: 'wide_shell_unstarted_today_light',
      captureFinder: find.byType(Scaffold).last,
    );
  });

  testWidgets('Wide shell empty today light', (tester) async {
    await _pumpGolden(
      tester,
      WorkbenchShell(
        controller: emptyFixture.controller,
        enableSystemHotkey: false,
      ),
      size: const Size(1536, 864),
      fileName: 'wide_shell_empty_today_light',
      captureFinder: find.byType(Scaffold).last,
    );
  });

  testWidgets('documentation CTDP task editor', (tester) async {
    await _pumpDocumentationForm(
      tester,
      RecordEditorDialog(controller: fixture.controller, kind: RecordKind.task),
      fileName: 'create_ctdp_task',
      fill: () async {
        await tester.tap(find.text('补充更多信息'));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text('启用 CTDP 任务协议'));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.enterText(_textFieldWithLabel('标题'), '整理衍射实验数据并记录误差来源');
        await tester.enterText(
          _textFieldWithLabel('说明'),
          '完成数据清洗、异常点核查，并保存处理参数。',
        );
        await tester.enterText(_textFieldWithLabel('预计分钟'), '45');
        await tester.enterText(_textFieldWithLabel('触发标志'), '打开数据目录并戴上耳机');
        await tester.enterText(_textFieldWithLabel('主链时长'), '25');
        await tester.enterText(_textFieldWithLabel('预约缓冲'), '15');
      },
    );
  });

  testWidgets('documentation RSIP habit editor', (tester) async {
    await _pumpDocumentationForm(
      tester,
      RecordEditorDialog(
        controller: fixture.controller,
        kind: RecordKind.habit,
      ),
      fileName: 'create_rsip_habit',
      fill: () async {
        await tester.tap(find.text('补充更多信息'));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text('启用 RSIP 习惯协议'));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.enterText(_textFieldWithLabel('标题'), '每日复核实验记录');
        await tester.enterText(
          _textFieldWithLabel('执行说明'),
          '从最小动作开始，稳定后再增加记录深度。',
        );
        await tester.enterText(_textFieldWithLabel('最小动作'), '只核对一条实验参数');
        await tester.enterText(_textFieldWithLabel('触发条件'), '晚饭后坐到书桌前');
      },
    );
  });

  testWidgets('documentation projects page', (tester) async {
    await _pumpDocumentationPage(
      tester,
      ProjectsPage(controller: guideFixture.controller),
      fileName: 'guide_projects',
    );
  });

  testWidgets('documentation focus page', (tester) async {
    await _pumpDocumentationPage(
      tester,
      FocusHubPage(controller: guideFixture.controller),
      fileName: 'guide_focus',
    );
  });

  testWidgets('documentation notes page', (tester) async {
    await _pumpDocumentationPage(
      tester,
      NotesPage(controller: guideFixture.controller),
      fileName: 'guide_notes',
    );
  });

  testWidgets('documentation review page', (tester) async {
    await _pumpDocumentationPage(
      tester,
      ReviewPage(controller: guideFixture.controller),
      fileName: 'guide_review',
    );
  });

  testWidgets('documentation policies tree', (tester) async {
    await _pumpDocumentationPage(
      tester,
      PoliciesPage(controller: guideFixture.controller),
      fileName: 'guide_policies_tree',
    );
  });

  testWidgets('documentation policies analytics', (tester) async {
    await _pumpDocumentationPage(
      tester,
      PoliciesPage(controller: guideFixture.controller),
      fileName: 'guide_policies_analytics',
      beforeCapture: () async {
        await tester.tap(find.widgetWithText(Tab, '高级分析'));
        await tester.pumpAndSettle();
        expect(find.text('规则启发式'), findsOneWidget);
      },
    );
  });
}
