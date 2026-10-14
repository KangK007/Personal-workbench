import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:personal_workbench/ui/pages/inbox_page.dart';
import 'package:personal_workbench/ui/pages/notes_page.dart';
import 'package:personal_workbench/ui/pages/plan_page.dart';
import 'package:personal_workbench/ui/pages/projects_page.dart';
import 'package:personal_workbench/ui/pages/review_page.dart';
import 'package:personal_workbench/ui/pages/settings_page.dart';
import 'package:personal_workbench/ui/widgets/global_search_dialog.dart';
import 'package:personal_workbench/ui/widgets/quick_capture_sheet.dart';
import 'package:personal_workbench/ui/workbench_shell.dart';

String _key(WorkspaceRecord record) => '${record.kind.name}:${record.id}';

class _MemoryDatabase extends AppDatabase {
  final Map<String, WorkspaceRecord> records = {};
  bool failNextRecordSave = false;

  @override
  Future<void> saveRecord(
    WorkspaceRecord record, {
    bool markDirty = true,
  }) async {
    if (failNextRecordSave) {
      failNextRecordSave = false;
      throw StateError('record write failed');
    }
    records[_key(record)] = record;
  }

  @override
  Future<void> close() async {}
}

final _now = DateTime(2026, 8, 9, 10);

Future<WorkbenchController> _createController({AppDatabase? database}) async {
  final controller = WorkbenchController(
    database: database ?? _MemoryDatabase(),
    backupService: BackupService(),
    searchService: SearchService(),
    focusService: FocusService(),
    notificationService: NotificationService(),
    shareCaptureService: ShareCaptureService(),
    syncService: SupabaseSyncService(null),
    now: () => _now,
  );
  final project = WorkspaceRecord.create(
    kind: RecordKind.project,
    title: 'Optics project',
    body: 'Fourier optics simulation',
    favorite: true,
  );
  final task = WorkspaceRecord.create(
    kind: RecordKind.task,
    title: 'Check sampling interval',
    body: 'Verify Nyquist condition',
    scheduledFor: _now,
    projectId: project.id,
    data: const {'isFocus': true, 'priority': 3, 'estimatedMinutes': 25},
  );
  final overdue = WorkspaceRecord.create(
    kind: RecordKind.task,
    title: 'Overdue calibration',
    dueAt: _now.subtract(const Duration(days: 1)),
    status: WorkStatus.todo,
  );
  final note = WorkspaceRecord.create(
    kind: RecordKind.note,
    title: 'Angular spectrum notes',
    body: 'Sampling and propagation notes',
    projectId: project.id,
    tags: const ['optics'],
  );
  final inboxLink = WorkspaceRecord.create(
    kind: RecordKind.link,
    title: 'Reference link',
    body: 'https://example.com',
    status: WorkStatus.inbox,
    data: const {'inbox': true},
  );
  final goal = WorkspaceRecord.create(
    kind: RecordKind.goal,
    title: 'Complete thesis figures',
    dueAt: _now.add(const Duration(days: 30)),
  );
  final records = <WorkspaceRecord>[
    project,
    task,
    overdue,
    note,
    inboxLink,
    goal,
    WorkspaceRecord.create(
      kind: RecordKind.milestone,
      title: 'Validate figure axes',
      parentId: goal.id,
      dueAt: _now.add(const Duration(days: 7)),
    ),
    WorkspaceRecord.create(
      kind: RecordKind.habit,
      title: 'Daily lab note',
      data: const {'frequency': 'daily'},
    ),
    WorkspaceRecord.create(
      kind: RecordKind.diary,
      title: 'Daily review',
      body: 'Experiment completed',
      scheduledFor: _now,
      data: const {'mood': 4, 'completedToday': 'Calibration'},
    ),
    WorkspaceRecord.create(
      kind: RecordKind.focusSession,
      title: 'Focus session',
      scheduledFor: _now.subtract(const Duration(hours: 1)),
      data: const {'seconds': 1500},
    ),
    WorkspaceRecord.create(
      kind: RecordKind.timeBlock,
      title: 'Simulation block',
      parentId: task.id,
      scheduledFor: DateTime(2026, 8, 9, 9),
      data: const {'durationMinutes': 60},
    ),
    WorkspaceRecord.create(
      kind: RecordKind.note,
      title: 'Deleted note',
    ).copyWith(deletedAt: _now.subtract(const Duration(hours: 1))),
  ];
  for (final record in records) {
    await controller.addRecord(record);
  }
  return controller;
}

Widget _host(Widget child, {ThemeData? theme, TextScaler? textScaler}) =>
    MaterialApp(
      key: UniqueKey(),
      theme: theme ?? AppTheme.light(),
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

Future<void> _pumpPage(WidgetTester tester, Widget page) async {
  await tester.pumpWidget(_host(page));
  await tester.pump(const Duration(milliseconds: 100));
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('inbox quick input keeps a draft after a failed save', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    tester.view.viewInsets = const FakeViewPadding(bottom: 200);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);
    final database = _MemoryDatabase();
    final controller = await _createController(database: database);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _host(
        InboxPage(controller: controller, showHeader: false),
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.pumpAndSettle();
    final input = find.byKey(const ValueKey('inbox-quick-input'));
    expect(input, findsOneWidget);
    await tester.enterText(input, '复核实验数据');
    database.failNextRecordSave = true;
    await tester.tap(find.byTooltip('记录任务'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(input).controller!.text, '复核实验数据');
    expect(find.textContaining('保存失败'), findsOneWidget);
    expect(
      controller.inboxRecords.any((record) => record.title == '复核实验数据'),
      isFalse,
    );

    await tester.tap(find.byTooltip('记录任务'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(input).controller!.text, isEmpty);
    expect(
      controller.inboxRecords.any((record) => record.title == '复核实验数据'),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  final inboxMotionVariant = ValueVariant<bool>({false, true});
  testWidgets(
    'inbox organization can retry shrink and undo without losing data',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final database = _MemoryDatabase();
      final controller = await _createController(database: database);
      addTearDown(controller.dispose);
      final link = controller.inboxRecords.firstWhere(
        (record) => record.kind == RecordKind.link,
      );
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: inboxMotionVariant.currentValue!),
              child: InboxPage(controller: controller, showHeader: false),
            ),
          ),
          textScaler: const TextScaler.linear(2),
        ),
      );
      await tester.pumpAndSettle();
      final motion = find.byKey(ValueKey('inbox-motion-${link.id}'));
      final opacity = find
          .descendant(of: motion, matching: find.byType(Opacity))
          .first;
      expect(tester.widget<Opacity>(opacity).opacity, 1);
      final menu = find.descendant(
        of: find.widgetWithText(ListTile, link.title),
        matching: find.byType(PopupMenuButton<String>),
      );
      await tester.ensureVisible(menu);
      await tester.pumpAndSettle();
      await tester.tap(menu);
      await tester.pumpAndSettle();
      database.failNextRecordSave = true;
      await tester.tap(find.text('整理完成'));
      await tester.pumpAndSettle();
      expect(find.text('整理失败，请重试。'), findsOneWidget);
      expect(
        controller.inboxRecords.any((record) => record.id == link.id),
        isTrue,
      );
      expect(tester.widget<Opacity>(opacity).opacity, 1);
      await tester.tap(find.text('重试'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      if (inboxMotionVariant.currentValue!) {
        expect(motion, findsNothing);
      } else {
        expect(tester.widget<Opacity>(opacity).opacity, inExclusiveRange(0, 1));
        expect(
          tester
              .widget<IgnorePointer>(
                find
                    .descendant(
                      of: motion,
                      matching: find.byType(IgnorePointer),
                    )
                    .first,
              )
              .ignoring,
          isTrue,
        );
        expect(
          tester
              .widget<ExcludeSemantics>(
                find
                    .descendant(
                      of: motion,
                      matching: find.byType(ExcludeSemantics),
                    )
                    .first,
              )
              .excluding,
          isTrue,
        );
      }
      await tester.pumpAndSettle();
      expect(controller.latestRecordById(link).data['inbox'], isFalse);
      expect(motion, findsNothing);
      await tester.tap(find.text('撤销'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      if (!inboxMotionVariant.currentValue!) {
        expect(tester.widget<Opacity>(opacity).opacity, inExclusiveRange(0, 1));
      }
      await tester.pumpAndSettle();
      expect(tester.widget<Opacity>(opacity).opacity, 1);
      expect(controller.latestRecordById(link).data['inbox'], isTrue);
      expect(controller.latestRecordById(link).body, link.body);
      expect(tester.takeException(), isNull);
    },
    variant: inboxMotionVariant,
  );

  testWidgets(
    'record pages keep reading and period controls usable at 320dp and 200% text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 700);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final controller = await _createController();
      addTearDown(controller.dispose);

      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        await tester.pumpWidget(
          _host(
            NotesPage(controller: controller),
            theme: theme,
            textScaler: const TextScaler.linear(2),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
        await tester.enterText(find.byType(SearchBar), 'Angular');
        await tester.pump();
        await tester.ensureVisible(find.text('Angular spectrum notes'));
        await tester.tap(find.text('Angular spectrum notes'));
        await tester.pump();
        expect(find.text('返回笔记索引'), findsOneWidget);
        await tester.tap(find.text('返回笔记索引'));
        await tester.pump();
        expect(find.text('Angular spectrum notes'), findsOneWidget);
        expect(tester.takeException(), isNull);

        for (final period in [
          (ReviewTab.diary, '日事实卡'),
          (ReviewTab.weekly, '七日完成分布'),
          (ReviewTab.monthly, '月度完成日历'),
        ]) {
          await tester.pumpWidget(
            _host(
              ReviewPage(controller: controller, initialTab: period.$1),
              theme: theme,
              textScaler: const TextScaler.linear(2),
            ),
          );
          await tester.pump(const Duration(milliseconds: 100));
          expect(find.text(period.$2), findsOneWidget);
          await tester.scrollUntilVisible(
            find.text('回顾正文'),
            260,
            scrollable: find
                .descendant(
                  of: find.byType(ReviewPage),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          final issue = tester.takeException();
          if (issue is FlutterError) {
            debugPrint('${period.$1}: ${issue.toStringDeep()}');
          }
          expect(issue, isNull);
        }

        await tester.pumpWidget(
          _host(
            FocusHubPage(controller: controller),
            theme: theme,
            textScaler: const TextScaler.linear(2),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.scrollUntilVisible(
          find.text('近七日专注节奏'),
          260,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.text('近七日专注节奏'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('core pages render populated desktop states', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = await _createController();
    addTearDown(controller.dispose);
    final semantics = tester.ensureSemantics();

    final pages = <Widget>[
      PlanPage(
        controller: controller,
        onOpenInbox: () {},
        onOpenCalendar: () {},
        onOpenProjects: () {},
      ),
      ReviewPage(controller: controller),
      GoalsPage(controller: controller),
      InboxPage(controller: controller),
      NotesPage(controller: controller),
      ProjectsPage(controller: controller),
      SettingsPage(controller: controller),
      FocusHubPage(controller: controller),
    ];

    for (final page in pages) {
      await _pumpPage(tester, page);
    }

    expect(find.text('开始专注'), findsOneWidget);
    await tester.tap(find.text('开始专注'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
    expect(find.text('25 / 5'), findsWidgets);
    await tester.tap(find.text('开始专注').last);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('暂停'), findsOneWidget);
    await tester.tap(find.text('暂停'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byTooltip('退出专注'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('退出').last);
    await tester.pump(const Duration(milliseconds: 200));

    await _pumpPage(tester, ProjectsPage(controller: controller));
    await tester.tap(find.text('看板').first);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('清单').first);
    await tester.pump(const Duration(milliseconds: 100));

    await _pumpPage(tester, SettingsPage(controller: controller));
    await tester.scrollUntilVisible(
      find.text('回收站（1）'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(SettingsPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('回收站（1）'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('永久删除'));
    await tester.pump();
    await tester.tap(find.byTooltip('永久删除'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('取消'));
    await tester.pump(const Duration(milliseconds: 100));
    semantics.dispose();
  });

  testWidgets(
    'search and quick capture cover empty, error, and success states',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1000, 760);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final controller = await _createController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => Column(
              children: [
                FilledButton(
                  onPressed: () => showGlobalSearch(context, controller),
                  child: const Text('Open search'),
                ),
                FilledButton(
                  onPressed: () => showQuickCapture(context, controller),
                  child: const Text('Open capture'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open search'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(SearchBar), 'Angular spectrum');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Angular spectrum notes'), findsOneWidget);
      await tester.tap(find.byTooltip('关闭'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Open capture'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('收下'));
      await tester.pump();
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'New captured task');
      await tester.tap(find.text('收下'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        controller.tasks.any((task) => task.title == 'New captured task'),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('compact pages and capture sheet avoid layout exceptions', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = await _createController();
    addTearDown(controller.dispose);

    await _pumpPage(tester, ProjectsPage(controller: controller));
    await _pumpPage(tester, SettingsPage(controller: controller));
    await _pumpPage(tester, QuickCaptureSheet(controller: controller));

    expect(find.text('新增'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop navigation stays reachable at minimum desktop height', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1300, 620);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = await _createController();
    addTearDown(controller.dispose);

    await _pumpPage(
      tester,
      WorkbenchShell(controller: controller, enableSystemHotkey: false),
    );
    final navigation = find.byKey(const ValueKey('desktop-navigation-scroll'));
    expect(navigation, findsOneWidget);
    await tester.drag(navigation, const Offset(0, -1000));
    await tester.pump(const Duration(milliseconds: 200));

    expect(navigation, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ctrl+K opens global search from the workbench shell', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = await _createController();
    addTearDown(controller.dispose);

    await _pumpPage(
      tester,
      WorkbenchShell(controller: controller, enableSystemHotkey: false),
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(SearchBar), findsOneWidget);
    expect(find.text('输入关键词开始搜索'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SearchBar),
        matching: find.byType(EditableText),
      ),
      findsOneWidget,
    );
    expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    var focusedContext = FocusManager.instance.primaryFocus?.context;
    expect(focusedContext, isNotNull);
    expect(
      find.ancestor(
        of: find.byWidget(focusedContext!.widget),
        matching: find.byType(Dialog),
      ),
      findsOneWidget,
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    focusedContext = FocusManager.instance.primaryFocus?.context;
    expect(focusedContext, isNotNull);
    expect(
      find.ancestor(
        of: find.byWidget(focusedContext!.widget),
        matching: find.byType(Dialog),
      ),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(SearchBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'global search can reuse and clear recent queries in a short window',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetViewInsets);
      final controller = await _createController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => showGlobalSearch(context, controller),
                child: const Text('打开搜索'),
              ),
            ),
          ),
          textScaler: const TextScaler.linear(2),
        ),
      );
      await tester.tap(find.text('打开搜索'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(SearchBar), 'Daily review');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.text('Daily review').last);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('关闭').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('打开搜索'));
      await tester.pumpAndSettle();
      expect(find.text('最近搜索'), findsOneWidget);
      expect(find.text('Daily review'), findsOneWidget);
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      await tester.pumpAndSettle();
      expect(tester.getBottomLeft(find.text('清除记录')).dy, lessThan(368));
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Daily review'));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('recent-searches')), findsNothing);
      await tester.tap(find.byTooltip('清空搜索'));
      await tester.pump();
      await tester.tap(find.text('清除记录'));
      await tester.pump();
      expect(find.text('输入关键词开始搜索'), findsOneWidget);
      expect(controller.recentSearchQueries, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
