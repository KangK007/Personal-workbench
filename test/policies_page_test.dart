import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
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
import 'package:personal_workbench/ui/pages/policies_page.dart';
import 'package:personal_workbench/ui/widgets/common.dart';

Finder _textFieldWithLabel(String label) => find.descendant(
  of: find.widgetWithText(ExternalField, label),
  matching: find.byType(TextField),
);

String _key(WorkspaceRecord record) => '${record.kind.name}:${record.id}';

class _MemoryDatabase extends AppDatabase {
  final Map<String, WorkspaceRecord> records = {};
  final Map<String, String> metadata = {};

  @override
  Future<void> saveRecord(
    WorkspaceRecord record, {
    bool markDirty = true,
  }) async {
    records[_key(record)] = record;
  }

  @override
  Future<String?> readMetadata(String key) async => metadata[key];

  @override
  Future<void> writeMetadata(String key, String value) async {
    metadata[key] = value;
  }

  @override
  Future<void> close() async {}
}

WorkbenchController _controller({DateTime? now}) => WorkbenchController(
  database: _MemoryDatabase(),
  backupService: BackupService(),
  searchService: SearchService(),
  focusService: FocusService(),
  notificationService: NotificationService(),
  shareCaptureService: ShareCaptureService(),
  syncService: SupabaseSyncService(null),
  now: () => now ?? DateTime(2026, 8, 14, 10),
);

Future<void> _pump(
  WidgetTester tester,
  WorkbenchController controller, {
  Size size = const Size(1280, 900),
  PolicyTab initialTab = PolicyTab.tree,
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: PoliciesPage(
          controller: controller,
          showHeader: size.width >= AppBreakpoints.compact,
          initialTab: initialTab,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('zh_CN'));

  testWidgets('RSIP page creates a complete typed node', (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await _pump(tester, controller);

    expect(find.text('国策树'), findsOneWidget);
    expect(find.text('国策库'), findsOneWidget);
    expect(find.text('轮次历史'), findsOneWidget);
    expect(find.text('高级分析'), findsOneWidget);
    expect(tester.getSize(find.byType(TabBar)).height, 50);
    expect(find.byIcon(Icons.rule_outlined), findsOneWidget);
    final policyChip = find.widgetWithText(FilterChip, '国策');
    final policyIcon = find.descendant(
      of: policyChip,
      matching: find.byIcon(Icons.policy_outlined),
    );
    final policyLabel = find.descendant(
      of: policyChip,
      matching: find.text('国策'),
    );
    expect(
      (tester.getCenter(policyIcon).dy - tester.getCenter(policyLabel).dy)
          .abs(),
      lessThanOrEqualTo(1),
    );
    expect(
      tester.getCenter(policyLabel).dy,
      greaterThanOrEqualTo(tester.getCenter(policyIcon).dy),
    );

    await tester.tap(find.text('添加国策'));
    await tester.pumpAndSettle();
    await tester.enterText(_textFieldWithLabel('标题 *'), '实验后记录');
    await tester.enterText(_textFieldWithLabel('精准规则 *'), '实验结束后十分钟内记录关键参数');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(controller.rsipNodes, hasLength(1));
    expect(controller.rsipNodes.single.record.title, '实验后记录');
    expect(controller.rsipNodes.single.rule, '实验结束后十分钟内记录关键参数');
    expect(controller.rsipNodes.single.stage, 'E0');
    expect(
      find.descendant(
        of: find.byType(InteractiveViewer),
        matching: find.text('实验后记录'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('violation previews group collapse and archives to library', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await controller.setRsipAllowMultiplePerDay(true);
    final group = await controller.saveRsipNodeGroup(
      title: '零容错组',
      initialTolerance: 0,
    );
    await controller.saveRsipNode(
      title: '固定记录',
      rule: '离开实验室前保存记录',
      type: RsipNodeType.ritual,
      groupId: group.id,
    );
    await _pump(tester, controller, size: const Size(620, 780));

    await tester.scrollUntilVisible(
      find.byTooltip('标记已违反'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byTooltip('标记已违反'));
    await tester.pumpAndSettle();
    expect(find.textContaining('容错耗尽'), findsOneWidget);
    expect(find.textContaining('将归档：固定记录'), findsOneWidget);
    await tester.enterText(_textFieldWithLabel('违反原因 *'), '未在离开前保存');
    await tester.tap(find.widgetWithText(FilledButton, '确认违反'));
    await tester.pumpAndSettle();

    expect(controller.activeRsipHabits, isEmpty);
    expect(controller.rsipLibraryNodes.single.record.title, '固定记录');
    await tester.tap(find.text('国策库'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('恢复 固定记录'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow RSIP page keeps actions and tabs usable', (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await controller.saveRsipNode(
      title: '晨间检查',
      rule: '开始工作前检查今日任务',
      type: RsipNodeType.trigger,
    );
    await _pump(tester, controller, size: const Size(620, 780));

    expect(find.byTooltip('添加国策'), findsOneWidget);
    expect(tester.getTopLeft(find.byType(TabBar)).dy, 0);
    expect(
      tester.getCenter(find.byType(TabBar)).dy,
      tester.getCenter(find.byTooltip('添加国策')).dy,
    );
    expect(find.text('晨间检查'), findsWidgets);
    expect(find.text('触发器'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(TabBar), const Offset(-220, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, '高级分析'));
    await tester.pumpAndSettle();
    expect(find.text('规则启发式'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact policy tabs remain fully visible at large text', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    for (final size in const [Size(320, 568), Size(390, 568)]) {
      for (final scale in const [1.0, 2.0]) {
        await _pump(tester, controller, size: size, textScale: scale);
        final bounds = tester.getRect(find.byType(TabBar));
        for (final name in ['tree', 'library', 'history', 'analytics']) {
          final tab = find.byKey(ValueKey('policy-tab-$name'));
          expect(tab, findsOneWidget);
          final rect = tester.getRect(tab);
          expect(rect.left, greaterThanOrEqualTo(bounds.left));
          expect(rect.right, lessThanOrEqualTo(bounds.right));
        }
        await tester.tap(find.byKey(const ValueKey('policy-tab-analytics')));
        await tester.pumpAndSettle();
        expect(find.text('规则启发式'), findsOneWidget);
        expect(find.byTooltip('国策操作'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('desktop policy tree exposes the graph and all root nodes', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await controller.setRsipAllowMultiplePerDay(true);
    await controller.saveRsipNode(
      title: '桌面图形根节点',
      rule: '工作开始前核对任务',
      type: RsipNodeType.trigger,
    );
    await _pump(tester, controller);
    final graph = find.byType(InteractiveViewer);
    expect(graph, findsOneWidget);
    expect(
      find.descendant(of: graph, matching: find.text('桌面图形根节点')),
      findsOneWidget,
    );
    for (final size in const [Size(1024, 600), Size(1920, 1080)]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      final node = find.descendant(of: graph, matching: find.text('桌面图形根节点'));
      expect(tester.getRect(graph).contains(tester.getCenter(node)), isTrue);
      expect(find.byTooltip('适应窗口'), findsOneWidget);
      await tester.tap(find.byTooltip('适应窗口'));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('policy group chip keeps marker and label on one baseline', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await controller.saveRsipNodeGroup(title: '默认国策组', initialTolerance: 0);
    await _pump(tester, controller);

    final groupChip = find.widgetWithText(ActionChip, '默认国策组 · 容错 0/0');
    final marker = find.descendant(of: groupChip, matching: find.text('组'));
    final label = find.descendant(
      of: groupChip,
      matching: find.text('默认国策组 · 容错 0/0'),
    );
    expect(groupChip, findsOneWidget);
    expect(
      (tester.getCenter(marker).dy - tester.getCenter(label).dy).abs(),
      lessThanOrEqualTo(1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('library groups in-use and archived rules and filters them', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await controller.setRsipAllowMultiplePerDay(true);
    await controller.saveRsipNode(
      title: '在用晨间规则',
      rule: '开始工作前核对清单',
      type: RsipNodeType.ritual,
    );
    final archived = await controller.saveRsipNode(
      title: '归档阅读规则',
      rule: '午后阅读报告',
      type: RsipNodeType.policy,
    );
    await controller.archiveRsipNode(archived, reason: '阶段结束');
    await _pump(tester, controller, initialTab: PolicyTab.library);

    expect(find.text('在用国策'), findsOneWidget);
    expect(find.text('已归档国策'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, '归档 1'));
    await tester.pumpAndSettle();
    expect(find.text('在用国策'), findsNothing);
    expect(find.text('已归档国策'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('policy-library-search')),
      '不存在的规则',
    );
    await tester.pumpAndSettle();
    expect(find.text('没有匹配的国策'), findsOneWidget);
    await tester.tap(find.text('查看全部'));
    await tester.pumpAndSettle();
    expect(find.text('在用国策'), findsOneWidget);
    expect(find.text('已归档国策'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'library grid uses three two and one columns by available width',
    (tester) async {
      final controller = _controller();
      addTearDown(controller.dispose);
      await controller.setRsipAllowMultiplePerDay(true);
      for (var index = 0; index < 7; index++) {
        await controller.saveRsipNode(
          title: '网格国策 $index',
          rule: '完成第 $index 项记录',
          type: RsipNodeType.policy,
        );
      }
      for (final (size, expectedColumns, textScale) in [
        (const Size(1200, 900), 3, 1.0),
        (const Size(767, 900), 2, 1.0),
        (const Size(320, 700), 1, 1.0),
        (const Size(1200, 900), 3, 2.0),
        (const Size(767, 900), 1, 2.0),
      ]) {
        await _pump(
          tester,
          controller,
          size: size,
          initialTab: PolicyTab.library,
          textScale: textScale,
        );
        final firstRow = find.byKey(
          const ValueKey('policy-library-row-active-0'),
        );
        expect(firstRow, findsOneWidget);
        expect(
          find.descendant(of: firstRow, matching: find.byType(ListTile)),
          findsNWidgets(expectedColumns),
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('library builds a large policy collection as it scrolls', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await controller.setRsipAllowMultiplePerDay(true);
    for (var index = 0; index < 75; index++) {
      await controller.saveRsipNode(
        title: '批量国策 $index',
        rule: '完成第 $index 项记录',
        type: RsipNodeType.policy,
      );
    }
    await _pump(tester, controller, initialTab: PolicyTab.library);
    final library = find.byKey(const PageStorageKey('policy-library-scroll'));
    expect(library, findsOneWidget);
    expect(find.text('批量国策 74'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('批量国策 74'),
      500,
      scrollable: find
          .descendant(of: library, matching: find.byType(Scrollable))
          .first,
      maxScrolls: 60,
    );
    expect(find.text('批量国策 74'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('run timeline expands to settlement evidence', (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    final node = await controller.saveRsipNode(
      title: '证据节点',
      rule: '记录完成证据',
      type: RsipNodeType.policy,
    );
    await controller.settleRsipNode(
      node,
      status: RsipExecutionStatus.executed,
      reason: '已保存记录',
    );
    await _pump(tester, controller, initialTab: PolicyTab.history);

    expect(find.textContaining('第 1 轮'), findsOneWidget);
    expect(find.text('已执行 1'), findsOneWidget);
    await tester.tap(find.text('证据节点 · 已执行'));
    await tester.pumpAndSettle();
    expect(find.text('结算原因：已保存记录'), findsOneWidget);
    expect(find.textContaining('来源：手动结算'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('history builds old rounds when they enter the viewport', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    for (var index = 0; index < 75; index++) {
      final started = DateTime(2026, 1, 1).add(Duration(days: index));
      await controller.addRecord(
        WorkspaceRecord.create(
          kind: RecordKind.protocolEvent,
          title: '第 ${index + 1} 轮',
          data: {
            'recordType': 'rsipRun',
            'runNumber': index + 1,
            'startedAt': started.toIso8601String(),
            'endedAt': started.add(const Duration(days: 1)).toIso8601String(),
          },
        ),
      );
    }
    await _pump(tester, controller, initialTab: PolicyTab.history);
    final history = find.byKey(const PageStorageKey('policy-history-scroll'));
    expect(history, findsOneWidget);
    expect(find.text('第 1 轮 · 已结束'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('第 1 轮 · 已结束'),
      500,
      scrollable: find
          .descendant(of: history, matching: find.byType(Scrollable))
          .first,
      maxScrolls: 50,
    );
    expect(find.text('第 1 轮 · 已结束'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('analysis plots real settlements and explains no sample', (
    tester,
  ) async {
    final now = DateTime.now();
    final controller = _controller(now: now);
    addTearDown(controller.dispose);
    final node = await controller.saveRsipNode(
      title: '分析节点',
      rule: '完成一次清点',
      type: RsipNodeType.policy,
    );
    await controller.settleRsipNode(node, status: RsipExecutionStatus.executed);
    await _pump(tester, controller, initialTab: PolicyTab.analytics);
    expect(find.text('14 日结算分布'), findsOneWidget);
    expect(find.text('已执行 1'), findsOneWidget);
    expect(find.text('已违反 0'), findsOneWidget);
    final todayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    expect(find.byKey(ValueKey('policy-day-bar-$todayKey')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _pump(
      tester,
      controller,
      size: const Size(320, 700),
      initialTab: PolicyTab.analytics,
      textScale: 2,
    );
    expect(find.text('14 日结算分布'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final empty = _controller();
    addTearDown(empty.dispose);
    await _pump(tester, empty, initialTab: PolicyTab.analytics);
    expect(find.text('暂无可分析的协议记录'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('analysis bars fill wide windows and scroll in compact windows', (
    tester,
  ) async {
    final now = DateTime(2026, 8, 14, 10);
    final controller = _controller(now: now);
    addTearDown(controller.dispose);
    final node = await controller.saveRsipNode(
      title: '图表宽度节点',
      rule: '完成一次清点',
      type: RsipNodeType.policy,
    );
    await controller.settleRsipNode(node, status: RsipExecutionStatus.executed);
    final day = find.byKey(const ValueKey('policy-day-bar-2026-08-14'));

    for (final (size, scale, minimum, maximum) in [
      (const Size(1200, 900), 1.0, 75.0, 90.0),
      (const Size(1440, 900), 1.0, 90.0, 110.0),
      (const Size(390, 844), 1.0, 67.0, 69.0),
      (const Size(320, 568), 2.0, 95.0, 97.0),
    ]) {
      await _pump(
        tester,
        controller,
        size: size,
        initialTab: PolicyTab.analytics,
        textScale: scale,
      );
      final width = tester.getSize(day).width;
      expect(width, greaterThan(minimum));
      expect(width, lessThan(maximum));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('library stays usable at 320dp and 200 percent text', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await controller.saveRsipNode(
      title: '小屏国策',
      rule: '核对任务',
      type: RsipNodeType.policy,
    );
    await _pump(
      tester,
      controller,
      size: const Size(320, 700),
      initialTab: PolicyTab.library,
      textScale: 2,
    );
    expect(find.byKey(const ValueKey('policy-library-search')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
