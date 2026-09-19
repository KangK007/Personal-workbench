import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
import 'package:personal_workbench/ui/pages/focus_page.dart';
import 'package:personal_workbench/ui/pages/inbox_page.dart';
import 'package:personal_workbench/ui/pages/plan_page.dart';
import 'package:personal_workbench/ui/pages/settings_page.dart';
import 'package:personal_workbench/ui/pages/today_page.dart';
import 'package:personal_workbench/ui/widgets/celebration.dart';
import 'package:personal_workbench/ui/widgets/attachment_panel.dart';
import 'package:personal_workbench/ui/widgets/common.dart';
import 'package:personal_workbench/ui/widgets/record_editor_dialog.dart';
import 'package:personal_workbench/ui/workbench_shell.dart';

String _key(WorkspaceRecord record) => '${record.kind.name}:${record.id}';

class _MemoryDatabase extends AppDatabase {
  final Map<String, WorkspaceRecord> records = {};
  final Map<String, String> metadata = {};

  @override
  Future<void> saveRecord(
    WorkspaceRecord record, {
    bool markDirty = true,
  }) async {
    records[_key(record)] = record.copyWith(
      syncState: markDirty ? SyncState.dirty : SyncState.clean,
      touch: false,
    );
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
  Future<void> permanentlyDelete(String id, RecordKind kind) async {
    records.remove('${kind.name}:$id');
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
  Future<String?> readMetadata(String key) async => metadata[key];

  @override
  Future<void> writeMetadata(String key, String value) async {
    metadata[key] = value;
  }

  @override
  Future<List<Attachment>> loadAttachments({String? ownerRecordId}) async =>
      const [];

  @override
  Future<void> replaceAttachments(Iterable<Attachment> attachments) async {}

  @override
  Future<void> close() async {}
}

class _TestNotifications extends NotificationService {
  _TestNotifications({this.permission = true, this.systemSupport = true});

  final bool permission;
  final bool systemSupport;
  int showCount = 0;
  int scheduledCount = 0;

  @override
  bool get supportsSystemNotifications => systemSupport;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => permission;

  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
  }) async {
    showCount++;
  }

  @override
  Future<void> scheduleFocusEnd({
    required int id,
    required String taskTitle,
    required DateTime when,
    required int restMinutes,
  }) async {
    scheduledCount++;
  }

  @override
  Future<void> scheduleTaskReminder({
    required int id,
    required String title,
    required DateTime when,
    String? body,
  }) async {
    scheduledCount++;
  }

  @override
  Future<void> cancel(int id) async {}
}

class _TestBackupService extends BackupService {
  _TestBackupService(this.directory, {this.failExport = false});

  final Directory directory;
  final bool failExport;
  int backupCalls = 0;

  @override
  Future<Uint8List> createEncryptedBackup(
    String password,
    Iterable<WorkspaceRecord> records, {
    Map<String, dynamic>? localGameState,
    Iterable<BackupAttachment> attachments = const [],
  }) async {
    backupCalls++;
    if (password.length < 8) {
      throw const FormatException('备份密码至少需要 8 个字符。');
    }
    return Uint8List.fromList(const [1, 2, 3]);
  }

  @override
  Future<File> writeDefaultBackup(Uint8List bytes) async {
    final file = File(
      '${directory.path}${Platform.pathSeparator}test-backup.pwb',
    );
    file.writeAsBytesSync(bytes, flush: true);
    return file;
  }

  @override
  Future<File> writeJsonExport(Iterable<WorkspaceRecord> records) async {
    if (failExport) {
      throw const FileSystemException('测试导出失败');
    }
    final file = File(
      '${directory.path}${Platform.pathSeparator}test-export.json',
    );
    file.writeAsStringSync('[]', flush: true);
    return file;
  }
}

class _Fixture {
  _Fixture({
    required this.directory,
    required this.clock,
    required this.database,
    required this.notifications,
    required this.controller,
  });

  final Directory directory;
  final ValueNotifier<DateTime> clock;
  final _MemoryDatabase database;
  final _TestNotifications notifications;
  final WorkbenchController controller;

  void dispose() {
    controller.dispose();
    clock.dispose();
  }
}

_Fixture _fixture({
  bool systemNotifications = true,
  bool systemNotificationSupport = true,
  bool withBackup = false,
  bool exportFails = false,
}) {
  final directory = Directory.systemTemp.createTempSync('workbench-ui-');
  final clock = ValueNotifier(DateTime(2026, 8, 10, 10));
  final database = _MemoryDatabase();
  final notifications = _TestNotifications(
    permission: systemNotifications,
    systemSupport: systemNotificationSupport,
  );
  final focusService = FocusService(
    now: () => clock.value,
    tickInterval: const Duration(hours: 1),
  );
  final backupService = withBackup
      ? _TestBackupService(directory, failExport: exportFails)
      : BackupService();
  final syncService = SupabaseSyncService(null);
  final controller = WorkbenchController(
    database: database,
    backupService: backupService,
    searchService: SearchService(),
    focusService: focusService,
    notificationService: notifications,
    shareCaptureService: ShareCaptureService(),
    syncService: syncService,
    now: () => clock.value,
  );
  return _Fixture(
    directory: directory,
    clock: clock,
    database: database,
    notifications: notifications,
    controller: controller,
  );
}

Widget _host(WorkbenchController controller, Widget Function() builder) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: const Locale('zh', 'CN'),
    supportedLocales: const [Locale('zh', 'CN')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Scaffold(body: builder()),
    ),
  );
}

Future<void> _pump(
  WidgetTester tester,
  WorkbenchController controller,
  Widget Function() builder, {
  Size size = const Size(1200, 1000),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  await tester.pumpWidget(_host(controller, builder));
  await tester.pump(const Duration(milliseconds: 100));
}

WorkspaceRecord _task(
  String title,
  DateTime now, {
  Map<String, dynamic> data = const {},
}) => WorkspaceRecord.create(
  kind: RecordKind.task,
  title: title,
  scheduledFor: now,
  data: data,
);

void main() {
  testWidgets('attachment picker cancellation restores keyboard focus', (
    tester,
  ) async {
    final fixture = _fixture();
    addTearDown(() {
      fixture.dispose();
      if (fixture.directory.existsSync()) {
        fixture.directory.deleteSync(recursive: true);
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    const channel = MethodChannel('miguelruivo.flutter.plugins.filepicker');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      _,
    ) async {
      FocusManager.instance.primaryFocus?.unfocus();
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    final note = WorkspaceRecord.create(
      kind: RecordKind.note,
      title: '附件选择器回归',
    );
    await fixture.controller.addRecord(note);
    await _pump(
      tester,
      fixture.controller,
      () => AttachmentPanel(owner: note, controller: fixture.controller),
    );

    await tester.tap(find.text('添加图片'));
    await tester.pumpAndSettle();

    final button = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '添加图片'),
    );
    expect(button.focusNode?.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'desktop task list supports explicit, range and all selection',
    (tester) async {
      final fixture = _fixture();
      addTearDown(() {
        fixture.dispose();
        if (fixture.directory.existsSync()) {
          fixture.directory.deleteSync(recursive: true);
        }
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final project = WorkspaceRecord.create(
        kind: RecordKind.project,
        title: '批量测试项目',
      );
      await fixture.controller.addRecord(project);
      for (var index = 0; index < 3; index++) {
        await fixture.controller.addRecord(
          WorkspaceRecord.create(
            kind: RecordKind.task,
            title: '批量任务 $index',
            projectId: index == 0 ? project.id : null,
          ),
        );
      }
      await _pump(
        tester,
        fixture.controller,
        () => PlanPage(controller: fixture.controller),
      );

      await tester.tap(find.widgetWithText(OutlinedButton, '选择任务').first);
      await tester.pump();
      expect(find.text('0 项'), findsOneWidget);
      await tester.tap(find.text('批量任务 0'));
      await tester.pump();
      await tester.tap(find.byTooltip('设置主项目'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('清除主项目'));
      await tester.pumpAndSettle();
      expect(
        fixture.controller.tasks
            .firstWhere((task) => task.title == '批量任务 0')
            .projectId,
        isNull,
      );

      await tester.tap(find.widgetWithText(OutlinedButton, '选择任务').first);
      await tester.pump();
      await tester.tap(find.text('批量任务 0'));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.tap(find.text('批量任务 2'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(find.text('3 项'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.byTooltip('退出多选'), findsNothing);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(find.text('3 项'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('task list scrolls 1000 records without layout failures', (
    tester,
  ) async {
    final fixture = _fixture();
    addTearDown(() {
      fixture.dispose();
      if (fixture.directory.existsSync()) {
        fixture.directory.deleteSync(recursive: true);
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    for (var index = 0; index < 1000; index++) {
      await fixture.controller.addRecord(
        WorkspaceRecord.create(
          kind: RecordKind.task,
          title: '性能回归任务 ${index.toString().padLeft(4, '0')}',
          body: '用于验证大量记录的懒加载、滚动和布局稳定性。',
        ),
      );
    }
    final stopwatch = Stopwatch()..start();
    await _pump(
      tester,
      fixture.controller,
      () => PlanPage(controller: fixture.controller),
    );
    await tester.fling(
      find.byType(Scrollable).last,
      const Offset(0, -6000),
      5000,
    );
    await tester.pumpAndSettle();
    stopwatch.stop();

    expect(find.text('性能回归任务 0000'), findsNothing);
    expect(tester.takeException(), isNull);
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
    debugPrint('1000-record task list render+scroll: ${stopwatch.elapsed}');
  });

  testWidgets(
    'Android inbox exits selection on back and can undo batch trash',
    (tester) async {
      final fixture = _fixture();
      addTearDown(() {
        fixture.dispose();
        if (fixture.directory.existsSync()) {
          fixture.directory.deleteSync(recursive: true);
        }
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final task = WorkspaceRecord.create(
        kind: RecordKind.task,
        title: '安卓批量任务',
        status: WorkStatus.inbox,
      );
      final note = WorkspaceRecord.create(
        kind: RecordKind.note,
        title: '保持单项操作的笔记',
        data: const {'inbox': true},
      );
      await fixture.controller.addRecord(task);
      await fixture.controller.addRecord(note);
      await _pump(
        tester,
        fixture.controller,
        () => InboxPage(controller: fixture.controller),
        size: const Size(412, 915),
      );

      await tester.longPress(find.text('安卓批量任务'));
      await tester.pump();
      expect(find.text('1 项'), findsOneWidget);
      expect(find.text('保持单项操作的笔记'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byTooltip('退出多选'), findsNothing);

      await tester.longPress(find.text('安卓批量任务'));
      await tester.pump();
      await tester.tap(find.byTooltip('移入回收站'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '移入回收站'));
      await tester.pumpAndSettle();
      expect(fixture.controller.trashRecords, hasLength(1));
      expect(find.text('撤销'), findsOneWidget);
      await tester.tap(find.text('撤销'));
      await tester.pumpAndSettle();
      expect(fixture.controller.trashRecords, isEmpty);
      expect(find.text('保持单项操作的笔记'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('trash supports mixed selection and two-step clear', (
    tester,
  ) async {
    final fixture = _fixture();
    addTearDown(() {
      fixture.dispose();
      if (fixture.directory.existsSync()) {
        fixture.directory.deleteSync(recursive: true);
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final deletedAt = fixture.clock.value.subtract(const Duration(hours: 1));
    await fixture.controller.addRecord(
      WorkspaceRecord.create(
        kind: RecordKind.task,
        title: '回收任务',
      ).copyWith(deletedAt: deletedAt),
    );
    await fixture.controller.addRecord(
      WorkspaceRecord.create(
        kind: RecordKind.note,
        title: '回收笔记',
      ).copyWith(deletedAt: deletedAt),
    );
    await _pump(
      tester,
      fixture.controller,
      () => SettingsPage(controller: fixture.controller),
    );

    await tester.scrollUntilVisible(
      find.text('回收站（2）'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    for (final title in ['回收任务', '回收笔记']) {
      final tile = find.ancestor(
        of: find.text(title),
        matching: find.byType(ListTile),
      );
      await tester.tap(
        find.descendant(of: tile, matching: find.byType(Checkbox)),
      );
      await tester.pump();
    }
    expect(find.text('已选 2 项'), findsOneWidget);

    await tester.tap(find.byTooltip('清空回收站'));
    await tester.pumpAndSettle();
    expect(find.text('清空回收站？'), findsOneWidget);
    expect(find.textContaining('2 项记录和 0 个附件'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '继续'));
    await tester.pumpAndSettle();
    expect(find.text('最后确认'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
    expect(fixture.controller.trashRecords, hasLength(2));

    await tester.tap(find.byTooltip('清空回收站'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '继续'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '永久清空'));
    await tester.pumpAndSettle();
    expect(fixture.controller.trashRecords, isEmpty);
    expect(find.text('回收站为空'), findsOneWidget);
  });

  testWidgets('today exposes one next action for all seven states', (
    tester,
  ) async {
    final fixtures = <_Fixture>[];
    _Fixture createFixture() {
      final fixture = _fixture();
      fixtures.add(fixture);
      return fixture;
    }

    addTearDown(() {
      for (final fixture in fixtures) {
        fixture.dispose();
        if (fixture.directory.existsSync()) {
          fixture.directory.deleteSync(recursive: true);
        }
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    Future<void> expectState(
      _Fixture fixture,
      String title,
      String action,
    ) async {
      await fixture.controller.setAdvancedFeaturesEnabled(false);
      await _pump(
        tester,
        fixture.controller,
        () => TodayPage(controller: fixture.controller, showHeader: false),
        size: const Size(412, 915),
      );
      expect(find.text(title), findsOneWidget);
      expect(find.text(action), findsOneWidget);
      expect(
        find.byWidgetPredicate((widget) => widget is FilledButton),
        findsOneWidget,
      );
    }

    await expectState(createFixture(), '从一件事开始', '添加今天的第一项任务');

    final inbox = createFixture();
    await inbox.controller.addRecord(
      WorkspaceRecord.create(
        kind: RecordKind.task,
        title: '收集箱任务',
        status: WorkStatus.inbox,
      ),
    );
    await expectState(inbox, '先整理收集箱', '去安排');

    final unscheduled = createFixture();
    await unscheduled.controller.addRecord(
      WorkspaceRecord.create(
        kind: RecordKind.task,
        title: '明日任务',
        status: WorkStatus.todo,
        scheduledFor: unscheduled.clock.value.add(const Duration(days: 1)),
      ),
    );
    await expectState(unscheduled, '安排今天要做的事', '打开计划');

    final priorities = createFixture();
    await priorities.controller.addRecord(
      _task('今日任务', priorities.clock.value),
    );
    await expectState(priorities, '准备开始今天', '开始今天');

    final focus = createFixture();
    final focusTask = _task('继续实验分析', focus.clock.value);
    await focus.controller.addRecord(focusTask);
    await focus.controller.startToday(
      commitments: [focusTask],
      plannedHabits: const [],
    );
    await expectState(focus, '接下来：继续实验分析', '开始专注');

    final close = createFixture();
    final completedTask = _task('已完成重点', close.clock.value);
    await close.controller.addRecord(completedTask);
    await close.controller.startToday(
      commitments: [completedTask],
      plannedHabits: const [],
    );
    await close.controller.toggleTaskDone(close.controller.tasks.single);
    await expectState(close, '今日重点已完成', '完成收尾');

    final closed = createFixture();
    final closedTask = _task('已收尾重点', closed.clock.value);
    final tomorrowTask = WorkspaceRecord.create(
      kind: RecordKind.task,
      title: '明日重点',
      status: WorkStatus.todo,
      scheduledFor: closed.clock.value.add(const Duration(days: 1)),
    );
    await closed.controller.addRecord(closedTask);
    await closed.controller.addRecord(tomorrowTask);
    await closed.controller.startToday(
      commitments: [closedTask],
      plannedHabits: const [],
    );
    await closed.controller.toggleTaskDone(
      closed.controller.tasks.firstWhere((task) => task.id == closedTask.id),
    );
    await closed.controller.closeToday(
      reasons: const {},
      dispositions: const {},
      tomorrowCommitments: [tomorrowTask],
    );
    await expectState(closed, '今天已收尾', '查看明日计划');
  });

  testWidgets('shell keeps desktop navigation and five mobile destinations', (
    tester,
  ) async {
    final fixture = _fixture();
    addTearDown(() {
      fixture.dispose();
      if (fixture.directory.existsSync()) {
        fixture.directory.deleteSync(recursive: true);
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await fixture.controller.setAdvancedFeaturesEnabled(false);

    await _pump(
      tester,
      fixture.controller,
      () => WorkbenchShell(
        controller: fixture.controller,
        enableSystemHotkey: false,
      ),
      size: const Size(1536, 864),
    );
    expect(find.widgetWithText(ListTile, '今日'), findsOneWidget);
    expect(find.byKey(const ValueKey('desktop-quick-capture')), findsOneWidget);
    final brand = find.byKey(const ValueKey('desktop-navigation-brand'));
    final primaryActions = find.byKey(
      const ValueKey('desktop-navigation-primary-actions'),
    );
    expect(
      tester.getTopLeft(primaryActions).dy - tester.getBottomLeft(brand).dy,
      greaterThanOrEqualTo(12),
    );
    expect(find.byKey(const ValueKey('navigation-group:plan')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('navigation-leaf:projectsOverview')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('navigation-leaf:settings')),
      findsOneWidget,
    );
    // 6 域导航：域标题本身常显（旧版是折叠组标题，默认不可见）。
    expect(find.widgetWithText(ListTile, '计划'), findsOneWidget);
    expect(find.widgetWithText(ListTile, '执行'), findsOneWidget);
    await fixture.controller.setNavigationGroupExpanded('plan', false);
    await tester.pumpAndSettle();
    // 手风琴：非当前域恒收起，其子页不可见。
    for (final key in ['tasksAll', 'tasksWeek', 'tasksGroups']) {
      expect(find.byKey(ValueKey('navigation-leaf:$key')), findsNothing);
    }
    // 点击非当前域标题 = 展开该域并进入其首个子页（规范 2.2 第 1 条）。
    await tester.tap(find.byKey(const ValueKey('navigation-group:plan')));
    await tester.pumpAndSettle();
    for (final key in ['tasksAll', 'tasksWeek', 'tasksGroups']) {
      expect(find.byKey(ValueKey('navigation-leaf:$key')), findsOneWidget);
    }
    expect(
      find.byKey(const ValueKey('navigation-leaf:tasksInbox')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('navigation-leaf:projectsOverview')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TabBar), findsNothing);
    expect(find.widgetWithText(ListTile, '系统'), findsNothing);
    expect(find.byKey(const ValueKey('navigation-leaf:diary')), findsNothing);
    // 旧折叠组 policies / goals_habits 已分别并入「执行」「成长」两域。
    expect(
      find.byKey(const ValueKey('navigation-group:execute')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('navigation-group:growth')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('navigation-group:record')),
      findsOneWidget,
    );
    // 当前域是「项目」，故「成长」子页保持收起。
    expect(find.byKey(const ValueKey('navigation-leaf:goals')), findsNothing);
    expect(
      find.byKey(const ValueKey('navigation-leaf:behavior')),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await fixture.controller.setAdvancedFeaturesEnabled(false);
    await _pump(
      tester,
      fixture.controller,
      () => WorkbenchShell(
        controller: fixture.controller,
        enableSystemHotkey: false,
      ),
      size: const Size(412, 915),
    );
    final navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
    final labels = navigation.destinations
        .cast<NavigationDestination>()
        .map((destination) => destination.label)
        .toList();
    expect(labels, ['今日', '计划', '记录', '成长', '更多']);
    expect(find.byType(PageHeader), findsNothing);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-quick-capture')), findsOneWidget);
    expect(find.byTooltip('快速新增'), findsOneWidget);
    expect(find.byTooltip('全局搜索'), findsOneWidget);
    // 「更多」入口唯一：底部导航末位。AppBar 曾另放一个同功能按钮，
    // 与底栏同屏重复且同名 tooltip 会干扰无障碍与自动化定位，已移除。
    final moreDestination = find.descendant(
      of: find.byType(NavigationBar),
      matching: find.byTooltip('更多'),
    );
    expect(moreDestination, findsOneWidget);
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.byTooltip('更多')),
      findsNothing,
    );

    await tester.tap(moreDestination);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('navigation-leaf:projectsOverview')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('navigation-leaf:projectsOverview')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('项目 · 概览'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('今日')),
      findsOneWidget,
    );
  });

  testWidgets('compact shell fits a short Android viewport', (tester) async {
    final fixture = _fixture();
    addTearDown(() {
      fixture.dispose();
      if (fixture.directory.existsSync()) {
        fixture.directory.deleteSync(recursive: true);
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await fixture.controller.setAdvancedFeaturesEnabled(false);

    await _pump(
      tester,
      fixture.controller,
      () => WorkbenchShell(
        controller: fixture.controller,
        enableSystemHotkey: false,
      ),
      size: const Size(390, 700),
    );

    expect(tester.takeException(), isNull);
    final navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navigation.destinations, hasLength(5));
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byTooltip('更多'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('navigation-leaf:focus')),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const ValueKey('navigation-leaf:focus')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone landscape keeps the mobile navigation', (tester) async {
    final fixture = _fixture();
    addTearDown(() {
      fixture.dispose();
      if (fixture.directory.existsSync()) {
        fixture.directory.deleteSync(recursive: true);
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await fixture.controller.setAdvancedFeaturesEnabled(false);

    await _pump(
      tester,
      fixture.controller,
      () => WorkbenchShell(
        controller: fixture.controller,
        enableSystemHotkey: false,
      ),
      size: const Size(915, 412),
    );

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('task editor progressively reveals optional fields', (
    tester,
  ) async {
    final basic = _fixture();
    final advanced = _fixture();
    addTearDown(() {
      for (final fixture in [basic, advanced]) {
        fixture.dispose();
        if (fixture.directory.existsSync()) {
          fixture.directory.deleteSync(recursive: true);
        }
      }
    });
    await basic.controller.setAdvancedFeaturesEnabled(false);

    await _pump(
      tester,
      basic.controller,
      () => RecordEditorDialog(
        key: const ValueKey('basic-editor'),
        controller: basic.controller,
        kind: RecordKind.task,
        initialScheduledFor: basic.clock.value,
      ),
    );
    expect(find.text('标题'), findsOneWidget);
    expect(find.text('说明'), findsOneWidget);
    expect(find.text('安排日期'), findsOneWidget);
    expect(find.text('8月10日'), findsOneWidget);
    expect(find.text('补充更多信息'), findsOneWidget);
    expect(find.text('状态'), findsNothing);
    expect(find.text('启用 CTDP 任务协议'), findsNothing);

    await tester.tap(find.text('补充更多信息'));
    await tester.pump();
    expect(find.text('状态'), findsOneWidget);
    expect(find.text('优先级'), findsOneWidget);
    expect(find.text('启用 CTDP 任务协议'), findsNothing);

    await advanced.controller.setAdvancedFeaturesEnabled(true);
    await _pump(
      tester,
      advanced.controller,
      () => RecordEditorDialog(
        key: const ValueKey('advanced-editor'),
        controller: advanced.controller,
        kind: RecordKind.task,
      ),
    );
    expect(find.text('启用 CTDP 任务协议'), findsNothing);
    await tester.tap(find.text('补充更多信息'));
    await tester.pump();
    expect(find.text('启用 CTDP 任务协议'), findsOneWidget);
  });

  testWidgets(
    'settings covers theme, alias, permission, backup and trash flows',
    (tester) async {
      const filePickerChannel = MethodChannel(
        'miguelruivo.flutter.plugins.filepicker',
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        filePickerChannel,
        (_) async => null,
      );
      final fixture = _fixture(withBackup: true);
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          filePickerChannel,
          null,
        );
        fixture.dispose();
        if (fixture.directory.existsSync()) {
          fixture.directory.deleteSync(recursive: true);
        }
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final sample = WorkspaceRecord.create(
        kind: RecordKind.note,
        title: '示例笔记',
        data: const {'sample': true},
      );
      final deleted = WorkspaceRecord.create(
        kind: RecordKind.note,
        title: '待恢复笔记',
      ).copyWith(deletedAt: fixture.clock.value);
      await fixture.controller.addRecord(sample);
      await fixture.controller.addRecord(deleted);

      await _pump(tester, fixture.controller, () {
        return SettingsPage(controller: fixture.controller);
      });
      final semantics = tester.ensureSemantics();

      await tester.scrollUntilVisible(
        find.text('跟随系统'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('跟随系统'));
      await tester.pump();
      await tester.tap(find.text('深色').last);
      await tester.pump();
      expect(fixture.controller.themeMode, ThemeMode.dark);

      await tester.tap(find.widgetWithText(OutlinedButton, '编辑'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '  实验别名  ');
      await tester.tap(find.text('保存'));
      await tester.pump();
      expect(fixture.controller.profileAlias, '实验别名');

      await tester.tap(find.widgetWithText(OutlinedButton, '编辑'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '不应保存');
      await tester.tap(find.text('取消'));
      await tester.pump();
      expect(fixture.controller.profileAlias, '实验别名');

      await tester.tap(find.widgetWithText(OutlinedButton, '编辑'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '回车提交');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(fixture.controller.profileAlias, '回车提交');

      final permission = find.widgetWithText(OutlinedButton, '申请权限');
      await tester.scrollUntilVisible(
        permission,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(permission),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      await tester.tap(permission);
      await tester.pump();
      expect(find.text('通知权限已启用'), findsOneWidget);
      expect(fixture.notifications.showCount, 1);
      tester
          .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
          .clearSnackBars();
      await tester.pumpAndSettle();

      final list = find.byType(Scrollable).first;
      final backupButton = find.widgetWithText(FilledButton, '备份');
      await tester.scrollUntilVisible(backupButton, 300, scrollable: list);
      await tester.ensureVisible(backupButton);
      await tester.pumpAndSettle();
      await tester.tap(backupButton);
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'short');
      await tester.tap(find.text('继续'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        (fixture.controller.backupService as _TestBackupService).backupCalls,
        1,
      );
      expect(find.textContaining('至少需要 8 个字符'), findsOneWidget);
      tester
          .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
          .clearSnackBars();
      await tester.pumpAndSettle();

      await tester.tap(backupButton);
      await tester.pump();
      await tester.tap(find.text('取消'));
      await tester.pump();
      expect(
        (fixture.controller.backupService as _TestBackupService).backupCalls,
        1,
      );

      await tester.tap(backupButton);
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'valid-pass');
      await tester.tap(find.text('继续'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('备份已保存'), findsOneWidget);
      expect(
        File(
          '${fixture.directory.path}${Platform.pathSeparator}test-backup.pwb',
        ).existsSync(),
        isTrue,
      );
      tester
          .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
          .clearSnackBars();
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, '导出'));
      await tester.pump();
      expect(find.textContaining('数据已导出'), findsOneWidget);
      expect(
        File(
          '${fixture.directory.path}${Platform.pathSeparator}test-export.json',
        ).existsSync(),
        isTrue,
      );
      tester
          .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
          .clearSnackBars();
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, '选择文件'));
      await tester.pump();
      await tester.tap(find.widgetWithText(OutlinedButton, '导入'));
      await tester.pump();
      expect(tester.takeException(), isNull);

      final selectedBackup = File(
        '${fixture.directory.path}${Platform.pathSeparator}selected-backup.pwb',
      );
      selectedBackup.writeAsBytesSync(const [1, 2, 3]);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        filePickerChannel,
        (_) async => [
          {
            'name': 'selected-backup.pwb',
            'path': selectedBackup.path,
            'bytes': null,
            'size': selectedBackup.lengthSync(),
            'identifier': null,
          },
        ],
      );
      await tester.tap(find.widgetWithText(OutlinedButton, '选择文件'));
      await tester.pump();
      expect(find.text('输入备份密码'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pump();

      await tester.tap(find.byTooltip('恢复'));
      await tester.pump();
      expect(fixture.controller.trashRecords, isEmpty);

      final restored = fixture.controller.notes.firstWhere(
        (note) => note.title == '待恢复笔记',
      );
      await fixture.controller.moveToTrash(restored);
      await tester.pump();
      await tester.tap(find.byTooltip('永久删除'));
      await tester.pump();
      expect(find.text('永久删除？'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pump();
      expect(fixture.controller.trashRecords, hasLength(1));
      await tester.tap(find.byTooltip('永久删除'));
      await tester.pump();
      await tester.tap(find.text('永久删除'));
      await tester.pump();
      expect(fixture.controller.trashRecords, isEmpty);

      await tester.drag(list, const Offset(0, -700));
      await tester.pump();
      await tester.tap(find.text('清除'));
      await tester.pump();
      await tester.tap(find.text('取消'));
      await tester.pump();
      expect(fixture.controller.notes, hasLength(1));
      await tester.tap(find.text('清除'));
      await tester.pump();
      await tester.tap(find.text('清除示例'));
      await tester.pump();
      expect(
        fixture.controller.notes.any((note) => note.title == '示例笔记'),
        isFalse,
      );
      semantics.dispose();
    },
  );

  testWidgets('settings reports denied notification permission', (
    tester,
  ) async {
    final fixture = _fixture(systemNotifications: false);
    addTearDown(() {
      fixture.dispose();
      if (fixture.directory.existsSync()) {
        fixture.directory.deleteSync(recursive: true);
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await _pump(tester, fixture.controller, () {
      return SettingsPage(controller: fixture.controller);
    });
    final permission = find.widgetWithText(OutlinedButton, '申请权限');
    await tester.scrollUntilVisible(
      permission,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(permission);
    await tester.pumpAndSettle();
    await tester.tap(permission);
    await tester.pump();

    expect(find.textContaining('通知权限未启用'), findsOneWidget);
    expect(fixture.notifications.showCount, 0);
  });

  testWidgets('settings covers desktop notifications and export failure', (
    tester,
  ) async {
    final fixture = _fixture(
      systemNotificationSupport: false,
      withBackup: true,
      exportFails: true,
    );
    addTearDown(() {
      fixture.dispose();
      if (fixture.directory.existsSync()) {
        fixture.directory.deleteSync(recursive: true);
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await _pump(tester, fixture.controller, () {
      return SettingsPage(controller: fixture.controller);
    });
    await tester.scrollUntilVisible(
      find.text('当前平台仅显示应用内提示'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('当前平台仅显示应用内提示'), findsOneWidget);
    final permissionButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '申请权限'),
    );
    expect(permissionButton.onPressed, isNull);

    final export = find.text('导出', skipOffstage: false);
    await tester.scrollUntilVisible(
      export,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(export);
    await tester.pumpAndSettle();
    await tester.tap(export);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('导出失败'), findsOneWidget);
  });

  testWidgets(
    'today covers start, replacement, habit, scheduling and close flows',
    (tester) async {
      final fixture = _fixture();
      addTearDown(() {
        fixture.dispose();
        if (fixture.directory.existsSync()) {
          fixture.directory.deleteSync(recursive: true);
        }
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final tasks = [
        _task('今日任务 A', fixture.clock.value),
        _task('今日任务 B', fixture.clock.value),
        _task('今日任务 C', fixture.clock.value),
        _task('替换任务 D', fixture.clock.value),
      ];
      final habit = WorkspaceRecord.create(
        kind: RecordKind.habit,
        title: '记录实验日志',
      );
      for (final task in tasks) {
        await fixture.controller.addRecord(task);
      }
      await fixture.controller.addRecord(habit);

      await _pump(tester, fixture.controller, () {
        return TodayPage(controller: fixture.controller);
      });
      await tester.tap(find.text('开始今天'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(fixture.controller.todayStarted, isTrue);
      final replacementId = fixture.controller.todayTasks
          .firstWhere(
            (task) => !fixture.controller.activeCommitmentIds.contains(task.id),
          )
          .id;

      await tester.ensureVisible(find.text('调整重点'));
      await tester.tap(find.text('调整重点'));
      await tester.pump();
      expect(find.text('保存重点'), findsOneWidget);
      final checkboxes = find.byType(CheckboxListTile);
      await tester.tap(checkboxes.at(0));
      await tester.tap(checkboxes.at(3));
      await tester.tap(find.text('保存重点'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(fixture.controller.activeCommitmentIds, contains(replacementId));

      // 前序「开始今天」会弹出一个 8 秒的浮动 SnackBar（带「撤销」操作），
      // 它悬停在底部；密度调整后「安排」按钮位于其遮挡带内。这里显式等它退场，
      // 而不是依赖「按钮恰好不在遮挡带里」这一偶然的垂直位置。
      await tester.pump(const Duration(seconds: 9));
      await tester.pump(const Duration(milliseconds: 500));

      final arrange = find.text('安排', skipOffstage: false);
      await tester.ensureVisible(arrange);
      await tester.pump();
      await tester.tap(arrange);
      await tester.pump();
      await tester.tap(find.text('安排').last);
      await tester.pump(const Duration(milliseconds: 100));
      expect(fixture.controller.timeBlocks, hasLength(1));

      await tester.tap(find.text('今日详情'));
      await tester.pump(const Duration(milliseconds: 400));
      await fixture.controller.logHabit(
        habit,
        fixture.clock.value,
        WorkStatus.done,
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        fixture.controller.habitLogForDay(habit.id, fixture.clock.value),
        isNotNull,
      );

      final incomplete = {
        for (final task in [
          ...fixture.controller.todayTasks,
          ...fixture.controller.overdueTasks,
        ])
          if (!WorkStatus.terminal.contains(task.status)) task.id: task,
      }.values.toList();
      await fixture.controller.closeToday(
        reasons: {for (final task in incomplete) task.id: '估时偏差'},
        dispositions: {for (final task in incomplete) task.id: 'tomorrow'},
        tomorrowCommitments: incomplete,
        reflection: '记录了今日实验事实',
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(fixture.controller.todayClosed, isTrue);
      expect(
        fixture.controller.notes.where(
          (note) => note.data['periodType'] == ReviewPeriodType.daily.name,
        ),
        hasLength(1),
      );
    },
  );

  testWidgets(
    'calendar covers week navigation, desktop create/edit/delete and mobile state',
    (tester) async {
      final fixture = _fixture();
      addTearDown(() {
        fixture.dispose();
        if (fixture.directory.existsSync()) {
          fixture.directory.deleteSync(recursive: true);
        }
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final task = _task('日历任务', fixture.clock.value);
      await fixture.controller.addRecord(task);
      await fixture.controller.createTimeBlock(
        task: task,
        start: DateTime(2026, 8, 10, 9),
        minutes: 25,
      );

      await _pump(tester, fixture.controller, () {
        return CalendarPage(controller: fixture.controller);
      }, size: const Size(1200, 900));
      final originalSubtitle = find.textContaining('8月10日');
      expect(originalSubtitle, findsWidgets);
      await tester.tap(find.byTooltip('下一周'));
      await tester.tap(find.byTooltip('上一周'));
      await tester.tap(find.byTooltip('回到本周'));
      await tester.pump();

      await tester.tap(find.byTooltip('安排时间块'));
      await tester.pump();
      expect(find.text('安排时间块'), findsOneWidget);
      await tester.tap(find.text('保存'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(fixture.controller.timeBlocks, hasLength(2));

      await tester.tap(find.text('日历任务').last);
      await tester.pump();
      expect(find.text('调整时间块'), findsOneWidget);
      await tester.tap(find.text('删除'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(fixture.controller.trashRecords, hasLength(1));

      await _pump(
        tester,
        fixture.controller,
        () => CalendarPage(controller: fixture.controller),
        size: const Size(390, 700),
      );
      expect(find.text('工作周'), findsOneWidget);
      await tester.tap(find.text('周二'));
      await tester.pump();
      expect(find.text('这一天没有时间块'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'focus completion accepts empty optional evidence without lifecycle errors',
    (tester) async {
      final fixture = _fixture();
      addTearDown(() {
        fixture.dispose();
        if (fixture.directory.existsSync()) {
          fixture.directory.deleteSync(recursive: true);
        }
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final task = _task(
        '可选证据专注任务',
        fixture.clock.value,
        data: const {'isFocus': true},
      );
      await fixture.controller.addRecord(task);
      await _pump(tester, fixture.controller, () {
        return FocusPage(controller: fixture.controller, task: task);
      });
      await tester.tap(find.text('正计时'));
      await tester.tap(find.text('开始专注'));
      fixture.clock.value = fixture.clock.value.add(
        const Duration(seconds: 65),
      );
      fixture.controller.focusService.refresh();
      await tester.pump();
      await tester.tap(find.text('完成本次专注'));
      await tester.pump();
      expect(find.text('记录本轮证据'), findsOneWidget);

      await tester.tap(find.text('结算本轮'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 2000));
      await tester.pump(const Duration(milliseconds: 400));

      final sessions = fixture.controller.recordsOf(RecordKind.focusSession);
      expect(sessions, hasLength(1));
      expect(sessions.single.body, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('CTDP focus completion requires evidence before settlement', (
    tester,
  ) async {
    final fixture = _fixture();
    addTearDown(() {
      fixture.dispose();
      if (fixture.directory.existsSync()) {
        fixture.directory.deleteSync(recursive: true);
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final task = _task(
      'CTDP 证据任务',
      fixture.clock.value,
      data: const {
        'isFocus': true,
        'protocol': 'ctdp',
        'ctdpTrigger': '开始',
        'ctdpIsDurationless': true,
      },
    );
    await fixture.controller.addRecord(task);
    await _pump(tester, fixture.controller, () {
      return FocusPage(controller: fixture.controller, task: task);
    });
    await tester.tap(find.text('正计时'));
    await tester.tap(find.text('开始专注'));
    fixture.clock.value = fixture.clock.value.add(const Duration(seconds: 10));
    fixture.controller.focusService.refresh();
    await tester.pump();
    await tester.tap(find.text('完成本次专注'));
    await tester.pump();

    await tester.tap(find.text('结算本轮'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('请记录实际完成内容'), findsOneWidget);
    expect(fixture.controller.recordsOf(RecordKind.focusSession), isEmpty);
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byType(TextField).first, '完成 CTDP 证据记录');
    await tester.tap(find.text('结算本轮'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pump(const Duration(milliseconds: 400));

    final sessions = fixture.controller.recordsOf(RecordKind.focusSession);
    expect(sessions, hasLength(1));
    expect(sessions.single.data['description'], '完成 CTDP 证据记录');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'focus covers completion evidence and CTDP interruption choices',
    (tester) async {
      final fixture = _fixture();
      addTearDown(() {
        fixture.dispose();
        if (fixture.directory.existsSync()) {
          fixture.directory.deleteSync(recursive: true);
        }
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final task = _task(
        '普通专注任务',
        fixture.clock.value,
        data: const {'isFocus': true},
      );
      await fixture.controller.addRecord(task);
      await _pump(tester, fixture.controller, () {
        return FocusHubPage(controller: fixture.controller);
      });
      await tester.tap(find.text('开始专注'));
      await tester.pump();
      await tester.tap(find.byTooltip('退出专注'));
      await tester.pump();
      expect(find.text('下一项承诺'), findsOneWidget);
      await tester.tap(find.text('开始专注'));
      await tester.pump();
      await tester.tap(find.text('正计时'));
      await tester.pump();
      await tester.tap(find.text('开始专注').last);
      fixture.clock.value = fixture.clock.value.add(
        const Duration(seconds: 65),
      );
      fixture.controller.focusService.refresh();
      await tester.pump();
      await tester.tap(find.text('完成本次专注'));
      await tester.pump();
      expect(find.text('记录本轮证据'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '完成采样检查');
      await tester.enterText(find.byType(TextField).last, '记录结果');
      await tester.tap(find.text('结算本轮'));
      await tester.pump(const Duration(milliseconds: 100));
      // 等待完成庆祝动画（约 1.85s）与弹层退场后再继续
      await tester.pump(const Duration(milliseconds: 2000));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(FocusCelebration), findsNothing);
      expect(
        fixture.controller.recordsOf(RecordKind.focusSession),
        hasLength(1),
      );
      expect(fixture.notifications.showCount, 1);

      final ctdp = _task(
        'CTDP 中断任务',
        fixture.clock.value,
        data: const {
          'protocol': 'ctdp',
          'ctdpTrigger': '开始',
          'ctdpIsDurationless': true,
        },
      );
      await fixture.controller.addRecord(ctdp);
      await _pump(tester, fixture.controller, () {
        return FocusPage(controller: fixture.controller, task: ctdp);
      });
      await tester.tap(find.text('开始专注'));
      fixture.clock.value = fixture.clock.value.add(
        const Duration(seconds: 10),
      );
      fixture.controller.focusService.refresh();
      await tester.pump();
      await tester.tap(find.byTooltip('退出专注'));
      await tester.pump();
      await tester.tap(find.text('继续执行'));
      await tester.pump();
      await tester.tap(find.byTooltip('退出专注'));
      await tester.pump();
      await tester.tap(find.text('判定失败'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(fixture.controller.protocolEvents, isNotEmpty);
      expect(fixture.controller.focusService.running, isFalse);
    },
  );
}
