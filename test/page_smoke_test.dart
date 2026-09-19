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

  @override
  Future<void> saveRecord(
    WorkspaceRecord record, {
    bool markDirty = true,
  }) async {
    records[_key(record)] = record;
  }

  @override
  Future<void> close() async {}
}

final _now = DateTime(2026, 8, 9, 10);

Future<WorkbenchController> _createController() async {
  final controller = WorkbenchController(
    database: _MemoryDatabase(),
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

Widget _host(Widget child) => MaterialApp(
  key: UniqueKey(),
  theme: AppTheme.light(),
  locale: const Locale('zh', 'CN'),
  supportedLocales: const [Locale('zh', 'CN')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Scaffold(body: child),
);

Future<void> _pumpPage(WidgetTester tester, Widget page) async {
  await tester.pumpWidget(_host(page));
  await tester.pump(const Duration(milliseconds: 100));
  expect(tester.takeException(), isNull);
}

void main() {
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
    await tester.tap(find.text('看板'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('清单'));
    await tester.pump(const Duration(milliseconds: 100));

    await _pumpPage(tester, SettingsPage(controller: controller));
    final settingsList = find.byType(ListView).first;
    await tester.drag(settingsList, const Offset(0, -1600));
    await tester.pump(const Duration(milliseconds: 200));
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
    final navigation = find.descendant(
      of: find.byType(Scrollbar),
      matching: find.byType(ListView),
    );
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
}
