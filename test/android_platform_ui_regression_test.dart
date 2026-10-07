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
import 'package:personal_workbench/services/windows_activity_service.dart';
import 'package:personal_workbench/state/workbench_controller.dart';
import 'package:personal_workbench/ui/pages/focus_page.dart';
import 'package:personal_workbench/ui/pages/execution_page.dart';
import 'package:personal_workbench/ui/pages/growth_hub_page.dart';
import 'package:personal_workbench/ui/pages/plan_page.dart';
import 'package:personal_workbench/ui/pages/protocols_page.dart';
import 'package:personal_workbench/ui/pages/restriction_page.dart';
import 'package:personal_workbench/ui/pages/settings_page.dart';
import 'package:personal_workbench/ui/workbench_shell.dart';

class _MemoryDatabase extends AppDatabase {
  @override
  Future<void> saveRecord(
    WorkspaceRecord record, {
    bool markDirty = true,
  }) async {}

  @override
  Future<void> close() async {}
}

class _UnsupportedWindowsActivityService extends WindowsActivityService {
  @override
  bool get supported => false;
}

WorkbenchController _controller() => WorkbenchController(
  database: _MemoryDatabase(),
  backupService: BackupService(),
  searchService: SearchService(),
  focusService: FocusService(),
  notificationService: NotificationService(),
  shareCaptureService: ShareCaptureService(),
  syncService: SupabaseSyncService(null),
  windowsActivityService: _UnsupportedWindowsActivityService(),
  now: () => DateTime(2026, 10, 4, 10),
);

Widget _host(Widget child) => MaterialApp(
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

void main() {
  testWidgets(
    'Android settings omit Windows-only controls',
    (tester) async {
      final controller = _controller();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_host(SettingsPage(controller: controller)));
      await tester.pump();
      await tester.drag(find.byType(ListView).first, const Offset(0, -1600));
      await tester.pump();

      expect(find.text('前台应用检测'), findsNothing);
      expect(find.text('定时专注显示工作台'), findsNothing);
      expect(find.text('前台日志'), findsNothing);
      expect(find.text('关闭窗口时最小化到托盘'), findsNothing);
      expect(find.text('开机启动'), findsNothing);
      expect(find.text('真正退出'), findsNothing);
      expect(find.text('管理员权限'), findsNothing);
      expect(find.text('hosts 健康状态'), findsNothing);
      expect(find.text('异常退出恢复'), findsNothing);
      expect(find.text('默认折叠 Windows 侧栏'), findsNothing);
      expect(find.textContaining('Windows 系统管理通知'), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('Android self-discipline page is removed entirely', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(RestrictionPage(controller: controller)));
    await tester.pump();

    expect(find.text('规则'), findsNothing);
    expect(find.text('保护设置'), findsNothing);
    expect(find.text('Windows 后台行为'), findsNothing);
    expect(find.text('hosts 与系统诊断'), findsNothing);
  });

  testWidgets('Android navigation does not expose self-discipline', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _controller();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(WorkbenchShell(controller: controller, enableSystemHotkey: false)),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('navigation-group:execute')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('navigation-leaf:restriction')),
      findsNothing,
    );
    expect(find.text('自律'), findsNothing);
  });

  testWidgets('Android focus preset editor omits Windows-only options', (
    tester,
  ) async {
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
    await tester.tap(find.byTooltip('新建专注预设'));
    await tester.pump();

    expect(find.text('应用检测模式'), findsNothing);
    expect(find.text('应用进程名'), findsNothing);
    expect(find.text('此预设启用前台检测'), findsNothing);
    expect(find.text('到点时显示工作台'), findsNothing);
    expect(find.text('定时启动提醒'), findsOneWidget);
  });

  testWidgets(
    'Android plan tabs stay distributed, selected, and keyboard usable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = _controller();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_host(PlanPage(controller: controller)));
      await tester.pumpAndSettle();

      final tabBarFinder = find.byType(TabBar);
      final tabBarRect = tester.getRect(tabBarFinder);
      final tabRects = [
        for (final label in const ['全部任务', '收件箱', '周视图', '任务群'])
          tester.getRect(find.text(label)),
      ];
      expect(tabRects, hasLength(4));
      final centers = tabRects.map((rect) => rect.center.dx).toList();
      expect(centers[1] - centers[0], greaterThan(40));
      expect(centers[2] - centers[1], greaterThan(40));
      expect(centers[3] - centers[2], greaterThan(40));
      for (final rect in tabRects) {
        expect(rect.left, greaterThanOrEqualTo(tabBarRect.left));
        expect(rect.right, lessThanOrEqualTo(tabBarRect.right));
        expect(rect.top, greaterThanOrEqualTo(tabBarRect.top));
        expect(rect.bottom, lessThanOrEqualTo(tabBarRect.bottom));
      }

      await tester.tap(find.text('任务群'));
      await tester.pumpAndSettle();
      var tabBar = tester.widget<TabBar>(tabBarFinder);
      expect(tabBar.controller!.index, PlanTab.groups.index);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      tabBar = tester.widget<TabBar>(tabBarFinder);
      expect(tabBar.controller!.index, PlanTab.week.index);
      expect(find.text('周视图'), findsOneWidget);

      // Rebuilding the parent must not reset the user's current tab.
      await tester.pumpWidget(_host(PlanPage(controller: controller)));
      await tester.pump();
      tabBar = tester.widget<TabBar>(find.byType(TabBar));
      expect(tabBar.controller!.index, PlanTab.week.index);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'Android execution and growth tabs fill compact width',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = _controller();
      addTearDown(controller.dispose);

      Future<void> expectDistributed(int count) async {
        final tabBar = tester.getRect(find.byType(TabBar));
        final labels = [
          for (final element in find.byType(Tab).evaluate())
            () {
              final box = element.renderObject! as RenderBox;
              final topLeft = box.localToGlobal(Offset.zero);
              return Rect.fromLTWH(
                topLeft.dx,
                topLeft.dy,
                box.size.width,
                box.size.height,
              );
            }(),
        ];
        expect(labels, hasLength(count));
        expect(
          labels.map((rect) => rect.center.dx).toList().last,
          lessThanOrEqualTo(tabBar.right),
        );
        for (var index = 1; index < labels.length; index++) {
          expect(
            labels[index].center.dx - labels[index - 1].center.dx,
            greaterThan(30),
          );
        }
      }

      await tester.pumpWidget(
        _host(ExecutionPage(controller: controller, showHeader: false)),
      );
      await tester.pumpAndSettle();
      await expectDistributed(2);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        _host(GrowthHubPage(controller: controller, showHeader: false)),
      );
      await tester.pumpAndSettle();
      await expectDistributed(4);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'Android protocol tabs show all advanced views without crowding',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = _controller();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(ProtocolsPage(controller: controller, showHeader: false)),
      );
      await tester.pumpAndSettle();

      expect(find.text('执行协议'), findsOneWidget);
      expect(find.text('行为协议'), findsOneWidget);
      expect(find.text('判例'), findsOneWidget);
      expect(find.text('分析'), findsOneWidget);
      final tabBar = tester.getRect(find.byType(TabBar));
      final tabRects = [
        for (final element in find.byType(Tab).evaluate())
          () {
            final box = element.renderObject! as RenderBox;
            final topLeft = box.localToGlobal(Offset.zero);
            return Rect.fromLTWH(
              topLeft.dx,
              topLeft.dy,
              box.size.width,
              box.size.height,
            );
          }(),
      ];
      expect(tabRects, hasLength(4));
      expect(tabRects.last.right, lessThanOrEqualTo(tabBar.right));
      for (var index = 1; index < tabRects.length; index++) {
        expect(
          tabRects[index].center.dx - tabRects[index - 1].center.dx,
          greaterThan(30),
        );
      }
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'Android top-left back always returns to Today',
    (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = _controller();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(
          WorkbenchShell(controller: controller, enableSystemHotkey: false),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('个人设置'));
      await tester.pumpAndSettle();
      expect(find.text('设置'), findsWidgets);
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('今日')),
        findsOneWidget,
      );
      expect(find.byTooltip('导航'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'Windows plan, execution, and growth pages omit page tabs',
    (tester) async {
      final controller = _controller();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(PlanPage(controller: controller, showHeader: false)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TabBar), findsNothing);

      await tester.pumpWidget(
        _host(ExecutionPage(controller: controller, showHeader: false)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TabBar), findsNothing);

      await tester.pumpWidget(
        _host(GrowthHubPage(controller: controller, showHeader: false)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TabBar), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
