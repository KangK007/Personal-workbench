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
import 'package:personal_workbench/ui/pages/projects_page.dart';

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

Widget _host(
  Widget child, {
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) => MaterialApp(
  theme: brightness == Brightness.light ? AppTheme.light() : AppTheme.dark(),
  locale: const Locale('zh', 'CN'),
  supportedLocales: const [Locale('zh', 'CN')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(textScale),
      disableAnimations: true,
    ),
    child: child!,
  ),
  home: Scaffold(body: child),
);

void _viewport(WidgetTester tester, Size size) {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('empty project page disposes without creating a late ticker', (
    tester,
  ) async {
    _viewport(tester, const Size(1200, 900));
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(ProjectsPage(controller: controller)));
    await tester.pumpAndSettle();
    expect(find.text('创建第一个项目'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('project view control follows the task area and stays unique', (
    tester,
  ) async {
    _viewport(tester, const Size(1440, 900));
    final controller = _controller();
    addTearDown(controller.dispose);
    await controller.addRecord(
      WorkspaceRecord.create(kind: RecordKind.project, title: '界面升级'),
    );
    for (final tab in ProjectDetailTab.values) {
      await tester.pumpWidget(
        _host(
          ProjectsPage(
            key: ValueKey(tab),
            controller: controller,
            initialTab: tab,
            showHeader: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final taskView =
          tab == ProjectDetailTab.tasks || tab == ProjectDetailTab.overview;
      expect(
        find.byType(SegmentedButton<ProjectViewMode>),
        taskView ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'project master detail uses the width remaining beside navigation',
    (tester) async {
      _viewport(tester, const Size(1440, 900));
      final controller = _controller();
      addTearDown(controller.dispose);
      await controller.addRecord(
        WorkspaceRecord.create(kind: RecordKind.project, title: '窄工作区项目'),
      );
      await tester.pumpWidget(
        _host(
          Row(
            children: [
              const SizedBox(width: 700),
              Expanded(
                child: ProjectsPage(controller: controller, showHeader: false),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      expect(
        find.byKey(const PageStorageKey('project-index-scroll')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('overview task action reveals the task section at 200% text', (
    tester,
  ) async {
    _viewport(tester, const Size(320, 568));
    final controller = _controller();
    addTearDown(controller.dispose);
    final project = WorkspaceRecord.create(
      kind: RecordKind.project,
      title: '完整界面升级与验证',
    );
    await controller.addRecord(project);
    await controller.addRecord(
      WorkspaceRecord.create(
        kind: RecordKind.task,
        title: '复核所有主要页面的文字、导航、状态反馈和触控尺寸',
        projectId: project.id,
      ),
    );
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        _host(
          ProjectsPage(
            key: ValueKey(brightness),
            controller: controller,
            showHeader: false,
          ),
          textScale: 2,
          brightness: brightness,
        ),
      );
      await tester.pumpAndSettle();
      final action = find.byKey(const ValueKey('project-overview-open-tasks'));
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      await tester.tap(action);
      await tester.pumpAndSettle();
      final taskSection = find.widgetWithText(ExpansionTile, '任务').first;
      final sectionTop = tester.getTopLeft(taskSection).dy;
      expect(sectionTop, greaterThanOrEqualTo(0));
      expect(sectionTop, lessThan(360));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('cancelled milestones do not appear as pending or overdue', (
    tester,
  ) async {
    _viewport(tester, const Size(1200, 900));
    final controller = _controller();
    addTearDown(controller.dispose);
    final project = WorkspaceRecord.create(
      kind: RecordKind.project,
      title: '真实里程碑状态',
    );
    await controller.addRecord(project);
    await controller.addRecord(
      WorkspaceRecord.create(
        kind: RecordKind.milestone,
        title: '已取消的旧目标',
        status: WorkStatus.cancelled,
        dueAt: DateTime(2026, 10, 1),
        projectId: project.id,
      ),
    );
    await tester.pumpWidget(
      _host(
        ProjectsPage(
          controller: controller,
          initialTab: ProjectDetailTab.milestones,
          showHeader: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('待到达 0'), findsOneWidget);
    expect(find.text('已逾期'), findsNothing);
    expect(find.text('已取消'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
