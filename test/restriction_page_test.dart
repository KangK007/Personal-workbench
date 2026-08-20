import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
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

class _MemoryDatabase extends AppDatabase {
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
  testWidgets('restriction section renders compact guidance', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
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

  testWidgets('focus hub keeps focus and legacy restriction tabs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(FocusHubPage(controller: controller)));
    await tester.pump();
    expect(find.text('专注'), findsWidgets); // PageHeader 标题 + Tab
    expect(find.text('导入 SelfControl'), findsNothing);
    // Tab 2 惰性构建：未选中时不渲染自律内容
    expect(find.text('保护设置'), findsNothing);
    await tester.tap(find.text('自律'));
    await tester.pumpAndSettle();
    expect(find.text('保护设置'), findsOneWidget);
    expect(find.text('当前状态'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact focus hub keeps restriction creation actions', (
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

    expect(find.byTooltip('新建专注预设'), findsOneWidget);
    expect(find.byTooltip('编辑自律规则'), findsOneWidget);
    expect(find.byTooltip('导入 SelfControl'), findsNothing);
  });
}
