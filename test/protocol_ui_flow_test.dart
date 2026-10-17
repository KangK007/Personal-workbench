import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
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
import 'package:personal_workbench/ui/pages/habits_page.dart';
import 'package:personal_workbench/ui/pages/protocols_page.dart';
import 'package:personal_workbench/ui/widgets/common.dart';
import 'package:personal_workbench/ui/widgets/record_editor_dialog.dart';
import 'package:personal_workbench/ui/widgets/task_row.dart';

class _MemoryAppDatabase extends AppDatabase {
  _MemoryAppDatabase({this.failSaves = false});

  bool failSaves;
  final Map<String, WorkspaceRecord> savedRecords = {};

  @override
  Future<void> saveRecord(
    WorkspaceRecord record, {
    bool markDirty = true,
  }) async {
    if (failSaves) throw Exception('disk full');
    savedRecords['${record.kind.name}:${record.id}'] = record;
  }

  @override
  Future<void> close() async {}
}

WorkbenchController _newController({
  AppDatabase? database,
  DateTime Function()? now,
}) {
  return WorkbenchController(
    database: database ?? _MemoryAppDatabase(),
    backupService: BackupService(),
    searchService: SearchService(),
    focusService: FocusService(),
    notificationService: NotificationService(),
    shareCaptureService: ShareCaptureService(),
    syncService: SupabaseSyncService(null),
    now: now,
  );
}

Finder _textFieldWithLabel(String label) {
  return find.descendant(
    of: find.ancestor(
      of: find.text(label),
      matching: find.byType(ExternalField),
    ),
    matching: find.byType(TextField),
  );
}

Finder _dropdownWithLabel(String label) {
  return find.descendant(
    of: find.ancestor(
      of: find.text(label),
      matching: find.byType(ExternalField),
    ),
    matching: find.byWidgetPredicate(
      (widget) => widget is DropdownButtonFormField,
    ),
  );
}

Future<void> _pumpAnimation(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 50 && !condition(); attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(condition(), isTrue, reason: 'Timed out waiting for controller state');
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _openEditor(
  WidgetTester tester,
  WorkbenchController controller,
  RecordKind kind,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            key: const ValueKey('open-editor'),
            onPressed: () => showRecordEditor(context, controller, kind: kind),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open-editor')));
  await _pumpAnimation(tester);
}

Future<void> _enableProtocol(WidgetTester tester, String label) async {
  final reveal = find.text('补充更多信息');
  if (reveal.evaluate().isNotEmpty) {
    await tester.tap(reveal);
    await _pumpAnimation(tester);
  }
  final switchLabel = find.text(label);
  await tester.ensureVisible(switchLabel);
  await tester.tap(switchLabel);
  await _pumpAnimation(tester);
}

Future<void> _pumpTaskRow(
  WidgetTester tester,
  WorkbenchController controller,
  WorkspaceRecord task,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: TaskRow(task: task, controller: controller),
      ),
    ),
  );
  await _pumpAnimation(tester);
}

Future<void> _pumpHabitsPage(
  WidgetTester tester,
  WorkbenchController controller,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: HabitsPage(controller: controller)),
    ),
  );
  await _pumpAnimation(tester);
}

void main() {
  setUpAll(() => initializeDateFormatting('zh_CN'));
  final reducedMotion = ValueVariant<bool>({false, true});
  testWidgets(
    'large CTDP group builds visible rows and keeps the last unit reachable',
    (tester) async {
      final controller = _newController();
      addTearDown(controller.dispose);
      tester.view.physicalSize = const Size(390, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final group = WorkspaceRecord.create(
        kind: RecordKind.task,
        title: '长任务组',
        data: const {'protocol': 'ctdp', 'ctdpUnitType': 'group'},
      );
      await controller.addRecord(group);
      for (var index = 0; index < 96; index++) {
        await controller.addRecord(
          WorkspaceRecord.create(
            kind: RecordKind.task,
            parentId: group.id,
            title: 'CTDP 子项 ${index.toString().padLeft(3, '0')}',
            data: const {'protocol': 'ctdp', 'ctdpTrigger': '打开文档'},
          ),
        );
      }

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: ProtocolsPage(controller: controller)),
        ),
      );
      await _pumpAnimation(tester);
      expect(find.text('长任务组'), findsOneWidget);
      expect(find.textContaining('96 个单元'), findsOneWidget);
      expect(find.text('CTDP 子项 095'), findsNothing);
      final protocolList = find.byType(ListView).first;
      await tester.scrollUntilVisible(
        find.text('CTDP 子项 095'),
        700,
        scrollable: find.descendant(
          of: protocolList,
          matching: find.byType(Scrollable),
        ),
        maxScrolls: 80,
      );
      expect(find.text('CTDP 子项 095'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'protocol stages follow saved reservation and daily settlement',
    (tester) async {
      final now = DateTime(2026, 10, 12, 10);
      final controller = _newController(now: () => now);
      addTearDown(controller.dispose);
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final task = WorkspaceRecord.create(
        kind: RecordKind.task,
        title: '协议阶段核查',
        data: const {'protocol': 'ctdp', 'ctdpTrigger': '打开论文'},
      );
      final habit = WorkspaceRecord.create(
        kind: RecordKind.habit,
        title: '每天阅读摘要',
        data: const {'protocol': 'rsip', 'rsipMinimumAction': '阅读一段'},
      );
      await controller.addRecord(task);
      await controller.addRecord(habit);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              disableAnimations: reducedMotion.currentValue!,
            ),
            child: child!,
          ),
          home: Scaffold(
            body: AnimatedBuilder(
              animation: controller,
              builder: (context, _) =>
                  ProtocolsPage(controller: controller, showHeader: false),
            ),
          ),
        ),
      );
      await _pumpAnimation(tester);
      final pageScroll = find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('protocol-stage-${task.id}')),
        160,
        scrollable: pageScroll,
      );
      String currentStage(WorkspaceRecord record) => tester
          .widget<Semantics>(
            find
                .descendant(
                  of: find.byKey(ValueKey('protocol-stage-${record.id}')),
                  matching: find.byType(Semantics),
                )
                .first,
          )
          .properties
          .value!;
      expect(currentStage(task), contains('当前：等待触发'));
      await controller.startCtdpReservation(task);
      await tester.pump();
      expect(currentStage(task), contains('当前：预约缓冲中'));
      await controller.confirmCtdpTrigger(task);
      await tester.pump();
      expect(currentStage(task), contains('当前：等待触发'));

      await tester.ensureVisible(find.byTooltip('CTDP 链操作'));
      await tester.pump();
      await tester.tap(find.byTooltip('CTDP 链操作'));
      await _pumpAnimation(tester);
      await tester.tap(find.text('编辑 / 移动'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      final editor = find.byType(RecordEditorDialog);
      final route = ModalRoute.of(tester.element(editor));
      expect(
        route!.transitionDuration,
        reducedMotion.currentValue! ? Duration.zero : AppMotion.standard,
      );
      final entrance = find.ancestor(
        of: editor,
        matching: find.byType(FadeTransition),
      );
      if (reducedMotion.currentValue!) {
        expect(entrance, findsNothing);
      } else {
        expect(
          tester.widget<FadeTransition>(entrance.first).opacity.value,
          inExclusiveRange(0, 1),
        );
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _pumpAnimation(tester);
      expect(editor, findsNothing);

      final tabs = find
          .descendant(
            of: find.byType(TabBar),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(find.text('行为协议'), 120, scrollable: tabs);
      await tester.tap(find.text('行为协议'));
      await _pumpAnimation(tester);
      final stage = find.byKey(ValueKey('protocol-stage-${habit.id}'));
      await tester.scrollUntilVisible(
        stage,
        160,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pump();
      expect(currentStage(habit), contains('当前：最小行动'));
      final yesterday = WorkspaceRecord.create(
        kind: RecordKind.habitLog,
        title: habit.title,
        parentId: habit.id,
        scheduledFor: now.subtract(const Duration(days: 1)),
        status: WorkStatus.done,
      );
      await controller.addRecord(yesterday);
      await tester.pump();
      expect(currentStage(habit), contains('当前：最小行动'));
      await controller.logHabit(habit, now, WorkStatus.done);
      await tester.pump();
      expect(currentStage(habit), contains('当前：今日已结算'));
      await controller.updateRecord(
        controller.latestRecordById(habit).withData('rsipFrozen', true),
      );
      await tester.pump();
      expect(currentStage(habit), contains('当前：水密隔舱'));
      expect(tester.takeException(), isNull);
    },
    variant: reducedMotion,
  );

  testWidgets('empty protocol groups stay in execution after they start', (
    tester,
  ) async {
    final controller = _newController();
    addTearDown(controller.dispose);
    final group = WorkspaceRecord.create(
      kind: RecordKind.task,
      title: '无成员任务组',
      data: const {'protocol': 'ctdp', 'ctdpUnitType': 'group'},
    );
    await controller.addRecord(group);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: AnimatedBuilder(
            animation: controller,
            builder: (context, _) => ProtocolsPage(controller: controller),
          ),
        ),
      ),
    );
    await tester.pump();
    final stage = find.byKey(ValueKey('protocol-stage-${group.id}'));
    String currentStage() => tester
        .widget<Semantics>(
          find.descendant(of: stage, matching: find.byType(Semantics)).first,
        )
        .properties
        .value!;
    expect(currentStage(), contains('当前：待启动'));
    await controller.startCtdpGroup(group);
    await tester.pump();
    expect(currentStage(), contains('当前：单元执行'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('protocol creation uses dedicated CTDP and RSIP editors', (
    tester,
  ) async {
    final controller = _newController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: ProtocolsPage(controller: controller)),
      ),
    );
    await _pumpAnimation(tester);

    await tester.tap(find.byKey(const ValueKey('ctdp-create-chain')));
    await _pumpAnimation(tester);
    expect(find.text('新建 CTDP 执行链'), findsOneWidget);
    expect(find.text('创建链条'), findsOneWidget);
    expect(find.text('触发标志'), findsOneWidget);
    expect(find.text('补充更多信息'), findsNothing);
    await tester.tap(find.text('取消'));
    await _pumpAnimation(tester);

    await tester.tap(find.text('行为协议'));
    await _pumpAnimation(tester);
    await tester.tap(find.text('新增国策'));
    await _pumpAnimation(tester);
    expect(find.text('新建 RSIP 国策'), findsOneWidget);
    expect(find.text('创建国策'), findsOneWidget);
    expect(find.text('最小动作'), findsOneWidget);
    expect(find.text('补充更多信息'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('CTDP chain creation keeps the add-chain entry after saving', (
    tester,
  ) async {
    final controller = _newController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: ProtocolsPage(controller: controller)),
      ),
    );
    await _pumpAnimation(tester);

    await tester.tap(find.byKey(const ValueKey('ctdp-create-chain')));
    await _pumpAnimation(tester);
    await tester.enterText(find.byType(TextField).first, '持续新增入口测试');
    await tester.enterText(_textFieldWithLabel('触发标志'), '打开工作台');
    await tester.tap(find.text('创建链条'));
    await _pumpUntil(
      tester,
      () => find.byType(RecordEditorDialog).evaluate().isEmpty,
    );

    expect(controller.ctdpTasks, hasLength(1));
    expect(find.byKey(const ValueKey('ctdp-create-chain')), findsOneWidget);
    expect(find.text('新增链条'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new task editor starts with an empty estimate', (tester) async {
    final controller = _newController();
    addTearDown(controller.dispose);
    await _openEditor(tester, controller, RecordKind.task);

    final estimate = tester.widget<TextField>(_textFieldWithLabel('预计分钟'));
    expect(estimate.controller?.text, isEmpty);
    expect(find.text('补充更多信息'), findsNothing);
  });

  testWidgets('editor keeps input and recovers after a save failure', (
    tester,
  ) async {
    final controller = _newController(
      database: _MemoryAppDatabase(failSaves: true),
    );
    addTearDown(controller.dispose);
    await _openEditor(tester, controller, RecordKind.task);

    await tester.enterText(find.byType(TextField).first, '无法落盘的任务');
    await tester.tap(find.text('创建任务'));
    await tester.pump();

    expect(find.byType(RecordEditorDialog), findsOneWidget);
    expect(find.text('保存失败，内容仍保留在当前窗口，请稍后重试。'), findsOneWidget);
    expect(find.text('无法落盘的任务'), findsOneWidget);
    expect(controller.tasks, isEmpty);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '创建任务'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('task editor creates a CTDP task with protocol fields', (
    tester,
  ) async {
    final controller = _newController();
    addTearDown(controller.database.close);
    await _openEditor(tester, controller, RecordKind.task);
    await _enableProtocol(tester, '启用 CTDP 任务协议');

    await tester.enterText(find.byType(TextField).first, 'Read paper');
    await tester.enterText(_textFieldWithLabel('触发标志'), '戴上蓝色帽子');
    await tester.enterText(_textFieldWithLabel('主链时长'), '40');
    await tester.enterText(_textFieldWithLabel('预约缓冲'), '12');
    await tester.tap(find.text('创建任务'));
    await _pumpUntil(
      tester,
      () => find.byType(RecordEditorDialog).evaluate().isEmpty,
    );

    final task = controller.tasks.single;
    expect(task.hasCtdpProtocol, isTrue);
    expect(task.ctdpTrigger, '戴上蓝色帽子');
    expect(task.ctdpSessionMinutes, 40);
    expect(task.ctdpDelayMinutes, 12);
  });

  testWidgets('mobile task editor is fullscreen and validates inline', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 915);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = _newController();
    addTearDown(controller.database.close);

    await _openEditor(tester, controller, RecordKind.task);

    expect(find.byTooltip('关闭'), findsOneWidget);
    expect(find.text('创建任务'), findsOneWidget);
    await tester.tap(find.text('创建任务'));
    await tester.pump();

    expect(find.text('请输入标题'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets(
    'habit editor creates a RSIP tree and enforces the daily node limit',
    (tester) async {
      final controller = _newController();
      addTearDown(controller.database.close);

      await _openEditor(tester, controller, RecordKind.habit);
      await _enableProtocol(tester, '启用 RSIP 习惯协议');
      final groupField = tester.widget<TextField>(_textFieldWithLabel('国策组'));
      expect(groupField.textAlignVertical, TextAlignVertical.center);
      expect(groupField.decoration?.prefixIconConstraints?.minHeight, 44);
      await tester.enterText(find.byType(TextField).first, 'Wash dishes');
      await tester.enterText(_textFieldWithLabel('最小动作'), '洗一个碗');
      await tester.enterText(_textFieldWithLabel('触发条件'), '晚饭后');
      await tester.tap(find.text('创建习惯'));
      await _pumpUntil(
        tester,
        () => find.byType(RecordEditorDialog).evaluate().isEmpty,
      );

      final root = controller.habits.single;
      expect(root.hasRsipProtocol, isTrue);
      expect(root.parentId, isNull);

      await controller.updateRecord(
        root.copyWith(
          data: {
            ...root.data,
            'rsipAddedAt': DateTime.now()
                .subtract(const Duration(days: 1))
                .toUtc()
                .toIso8601String(),
          },
        ),
      );

      await _openEditor(tester, controller, RecordKind.habit);
      await _enableProtocol(tester, '启用 RSIP 习惯协议');
      await tester.enterText(find.byType(TextField).first, 'Clear desk');
      await tester.enterText(_textFieldWithLabel('最小动作'), '收起一件物品');
      await tester.enterText(_textFieldWithLabel('触发条件'), '坐到桌前');
      final parentDropdown = _dropdownWithLabel('父节点（国策树）');
      await tester.ensureVisible(parentDropdown);
      await tester.tap(parentDropdown);
      await _pumpAnimation(tester);
      await tester.tap(find.text('Wash dishes').last);
      await _pumpAnimation(tester);
      await tester.tap(find.text('创建习惯'));
      await _pumpUntil(
        tester,
        () => find.byType(RecordEditorDialog).evaluate().isEmpty,
      );

      final child = controller.habits.firstWhere(
        (habit) => habit.title == 'Clear desk',
      );
      expect(child.parentId, root.id);

      await _openEditor(tester, controller, RecordKind.habit);
      await _enableProtocol(tester, '启用 RSIP 习惯协议');
      await tester.enterText(find.byType(TextField).first, 'Third node');
      await tester.enterText(_textFieldWithLabel('最小动作'), '做一个动作');
      await tester.enterText(_textFieldWithLabel('触发条件'), '开始工作');
      await tester.tap(find.text('创建习惯'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(controller.habits, hasLength(2));
      expect(find.text('RSIP 每天最多新增一个习惯节点'), findsOneWidget);
    },
  );

  testWidgets('CTDP task menu completes the reservation and failure loop', (
    tester,
  ) async {
    final controller = _newController();
    addTearDown(controller.database.close);
    final task = WorkspaceRecord.create(
      kind: RecordKind.task,
      title: 'Protocol task',
      data: const {
        'protocol': 'ctdp',
        'ctdpTrigger': '戴上帽子',
        'ctdpSessionMinutes': 25,
        'ctdpDelayMinutes': 15,
        'ctdpChainCount': 4,
        'ctdpAuxChainCount': 2,
      },
    );
    await controller.addRecord(task);

    await _pumpTaskRow(tester, controller, task);
    await tester.tap(find.byTooltip('展开任务详情'));
    await _pumpAnimation(tester);
    expect(find.text('CTDP 主 #4 · 辅 #2'), findsOneWidget);
    await tester.tap(find.byTooltip('更多操作'));
    await _pumpAnimation(tester);
    await tester.tap(find.text('预约 15 分钟后开始'));
    await _pumpUntil(
      tester,
      () =>
          controller.tasks.single.ctdpReservationPending &&
          controller.protocolEvents.any(
            (event) => event.data['action'] == 'reservation_started',
          ),
    );

    var current = controller.tasks.single;
    await _pumpTaskRow(tester, controller, current);
    await tester.tap(find.byTooltip('更多操作'));
    await _pumpAnimation(tester);
    await tester.tap(find.text('触发主链'));
    await _pumpUntil(
      tester,
      () => controller.tasks.single.ctdpAuxChainCount == 3,
    );

    current = controller.tasks.single;
    await _pumpTaskRow(tester, controller, current);
    await tester.tap(find.byTooltip('更多操作'));
    await _pumpAnimation(tester);
    await tester.tap(find.text('记录判例'));
    await _pumpAnimation(tester);
    await tester.enterText(_textFieldWithLabel('本次允许的例外行为'), '接听紧急电话');
    await tester.tap(find.text('写入判例'));
    await _pumpUntil(
      tester,
      () => (controller.tasks.single.data['ctdpPrecedents'] as List<dynamic>)
          .contains('接听紧急电话'),
    );

    current = controller.tasks.single;
    await _pumpTaskRow(tester, controller, current);
    await tester.tap(find.byTooltip('更多操作'));
    await _pumpAnimation(tester);
    await tester.tap(find.text('主链失败并重置'));
    await _pumpUntil(tester, () => controller.tasks.single.ctdpChainCount == 0);
    expect(controller.tasks.single.ctdpAuxChainCount, 3);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('RSIP habit menu extinguishes and reactivates a branch', (
    tester,
  ) async {
    final controller = _newController();
    addTearDown(controller.database.close);
    final root = WorkspaceRecord.create(
      kind: RecordKind.habit,
      title: 'Read',
      data: const {
        'protocol': 'rsip',
        'rsipMinimumAction': '读一页',
        'rsipActive': true,
        'rsipChainCount': 3,
        'rsipInternalization': 40,
      },
    );
    final child = WorkspaceRecord.create(
      kind: RecordKind.habit,
      title: 'Take notes',
      parentId: root.id,
      data: const {
        'protocol': 'rsip',
        'rsipMinimumAction': '写一句',
        'rsipActive': true,
      },
    );
    await controller.addRecord(root);
    await controller.addRecord(child);

    await _pumpHabitsPage(tester, controller);
    expect(find.text('最小动作：读一页'), findsOneWidget);
    expect(find.textContaining('子节点 · Read'), findsOneWidget);
    await tester.tap(find.byTooltip('RSIP 节点操作').first);
    await _pumpAnimation(tester);
    await tester.tap(find.text('今日失败并熄灭分支'));
    await _pumpUntil(
      tester,
      () => controller.habits.every((habit) => !habit.rsipActive),
    );

    var currentRoot = controller.habits.firstWhere(
      (habit) => habit.id == root.id,
    );
    var currentChild = controller.habits.firstWhere(
      (habit) => habit.id == child.id,
    );
    expect(currentRoot.rsipInternalization, 40);
    expect(currentChild.rsipActive, isFalse);

    await _pumpHabitsPage(tester, controller);
    expect(find.textContaining('已熄灭 · 根节点'), findsOneWidget);
    await tester.tap(find.byTooltip('RSIP 节点操作').first);
    await _pumpAnimation(tester);
    await tester.tap(find.text('重新启用节点'));
    await _pumpUntil(
      tester,
      () => controller.habits
          .firstWhere((habit) => habit.id == root.id)
          .rsipActive,
    );

    currentRoot = controller.habits.firstWhere((habit) => habit.id == root.id);
    currentChild = controller.habits.firstWhere(
      (habit) => habit.id == child.id,
    );
    expect(currentRoot.rsipChainCount, 0);
    expect(currentRoot.rsipInternalization, 40);
    expect(currentChild.rsipActive, isFalse);
  });

  testWidgets('protocol workbench exposes CTDP, RSIP, rules, and analytics', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _newController();
    addTearDown(controller.database.close);
    final task = WorkspaceRecord.create(
      kind: RecordKind.task,
      title: 'Protocol task',
      data: const {
        'protocol': 'ctdp',
        'ctdpTrigger': '打开论文',
        'ctdpAuxSignal': '预约闹钟',
        'ctdpDelayMinutes': 15,
      },
    );
    final habit = WorkspaceRecord.create(
      kind: RecordKind.habit,
      title: 'Protocol habit',
      data: const {
        'protocol': 'rsip',
        'rsipMinimumAction': '读一段摘要',
        'rsipRule': '读完并写一个关键词',
        'rsipActive': true,
      },
    );
    await controller.addRecord(task);
    await controller.addRecord(habit);
    await controller.createExceptionRule(
      name: '实验室安全警报',
      description: '设备报警时允许暂停',
      ruleType: 'pause',
      scope: 'global',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: ProtocolsPage(controller: controller)),
      ),
    );
    await _pumpAnimation(tester);
    expect(find.text('Protocol task'), findsOneWidget);
    expect(find.textContaining('触发：打开论文'), findsOneWidget);

    await tester.tap(find.byTooltip('CTDP 链操作'));
    await _pumpAnimation(tester);
    await tester.tap(find.text('预约 15 分钟后开始'));
    await _pumpUntil(
      tester,
      () =>
          controller.tasks.single.ctdpReservationPending &&
          controller.protocolEvents.any(
            (event) => event.data['action'] == 'reservation_started',
          ),
    );

    await tester.tap(find.text('行为协议'));
    await _pumpAnimation(tester);
    expect(find.text('Protocol habit'), findsOneWidget);
    expect(find.textContaining('规则：读完并写一个关键词'), findsOneWidget);

    await tester.tap(find.text('判例'));
    await _pumpAnimation(tester);
    expect(find.text('实验室安全警报'), findsOneWidget);
    expect(find.textContaining('使用 0 次'), findsOneWidget);

    await tester.tap(find.text('分析'));
    await _pumpAnimation(tester);
    expect(find.text('最近协议记录'), findsOneWidget);
    expect(find.text('协议事件'), findsOneWidget);
    expect(
      controller.protocolEvents.map((event) => event.data['action']),
      contains('reservation_started'),
    );
  });

  testWidgets('protocol workbench keeps the mobile first viewport usable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _newController();
    addTearDown(controller.database.close);
    await controller.addRecord(
      WorkspaceRecord.create(
        kind: RecordKind.task,
        title: '移动端协议任务',
        data: const {'protocol': 'ctdp', 'ctdpTrigger': '打开记录'},
      ),
    );
    await controller.addRecord(
      WorkspaceRecord.create(
        kind: RecordKind.habit,
        title: '移动端国策',
        data: const {
          'protocol': 'rsip',
          'rsipMinimumAction': '读一段',
          'rsipActive': true,
        },
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: ProtocolsPage(controller: controller)),
      ),
    );
    await _pumpAnimation(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('移动端协议任务'), findsOneWidget);
    expect(find.text('执行协议'), findsOneWidget);
  });

  testWidgets(
    'protocol roots group by type and keep orphaned records visible',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = _newController();
      addTearDown(controller.dispose);
      await controller.addRecord(
        WorkspaceRecord.create(
          kind: RecordKind.task,
          title: '实验任务组',
          data: const {'protocol': 'ctdp', 'ctdpUnitType': 'group'},
        ),
      );
      await controller.addRecord(
        WorkspaceRecord.create(
          kind: RecordKind.task,
          title: '孤立执行链',
          parentId: 'missing-task',
          data: const {'protocol': 'ctdp', 'ctdpTrigger': '打开文档'},
        ),
      );
      for (final group in const ['科研组', '生活组']) {
        await controller.addRecord(
          WorkspaceRecord.create(
            kind: RecordKind.habit,
            title: '$group 节点',
            parentId: group == '生活组' ? 'missing-habit' : null,
            data: {'protocol': 'rsip', 'rsipGroup': group},
          ),
        );
      }
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ProtocolsPage(controller: controller, showHeader: false),
          ),
        ),
      );
      await _pumpAnimation(tester);
      expect(find.text('任务组'), findsOneWidget);
      expect(find.text('执行链'), findsOneWidget);
      expect(find.text('实验任务组'), findsOneWidget);
      expect(find.text('孤立执行链'), findsOneWidget);

      await tester.tap(
        find.descendant(of: find.byType(TabBar), matching: find.text('行为协议')),
      );
      await _pumpAnimation(tester);
      expect(find.text('科研组'), findsOneWidget);
      expect(find.text('生活组'), findsOneWidget);
      expect(find.text('生活组 节点'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('protocol tabs stay reachable in a narrow Android window', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      debugDefaultTargetPlatformOverride = null;
    });
    final controller = _newController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: ProtocolsPage(controller: controller, showHeader: false),
          ),
        ),
      ),
    );
    await _pumpAnimation(tester);
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(TabBar), const Offset(-400, 0));
    await _pumpAnimation(tester);
    await tester.tap(find.text('分析'));
    await _pumpAnimation(tester);
    expect(find.text('协议事件'), findsOneWidget);
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('execution protocol lists only its linked focus sessions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _newController();
    addTearDown(controller.dispose);
    final task = WorkspaceRecord.create(
      kind: RecordKind.task,
      title: '关联协议任务',
      data: const {'protocol': 'ctdp', 'ctdpTrigger': '打开文档'},
    );
    await controller.addRecord(task);
    await controller.addRecord(
      WorkspaceRecord.create(
        kind: RecordKind.focusSession,
        title: '无关专注',
        status: WorkStatus.done,
        scheduledFor: DateTime(2026, 8, 10, 8),
        data: const {'seconds': 900},
      ),
    );

    Widget page() => MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(2)),
        child: child!,
      ),
      home: Scaffold(
        body: ProtocolsPage(controller: controller, showHeader: false),
      ),
    );
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    final pageScroll = find
        .descendant(
          of: find.byType(ListView).first,
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('关联专注'),
      180,
      scrollable: pageScroll,
    );
    await tester.pumpAndSettle();
    expect(find.text('尚无关联专注。可从上方执行协议启动一轮。'), findsOneWidget);
    expect(find.text('无关专注'), findsNothing);
    expect(tester.takeException(), isNull);

    await controller.addRecord(
      WorkspaceRecord.create(
        kind: RecordKind.focusSession,
        title: '论文聚焦',
        parentId: task.id,
        status: WorkStatus.done,
        scheduledFor: DateTime(2026, 8, 10, 9, 30),
        data: const {'seconds': 1500},
      ),
    );
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('论文聚焦'),
      180,
      scrollable: pageScroll,
    );
    await tester.pumpAndSettle();
    expect(find.text('关联任务：关联协议任务'), findsOneWidget);
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('无关专注'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'rule editor retains input after failure and updates a precedent',
    (tester) async {
      tester.view.physicalSize = const Size(390, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final database = _MemoryAppDatabase();
      final controller = _newController(database: database);
      addTearDown(controller.dispose);
      await controller.addRecord(
        WorkspaceRecord.create(
          kind: RecordKind.task,
          title: '论文专注链',
          data: const {'protocol': 'ctdp', 'ctdpTrigger': '打开文档'},
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ProtocolsPage(
              controller: controller,
              initialTab: ProtocolTab.rules,
              showHeader: false,
            ),
          ),
        ),
      );
      await _pumpAnimation(tester);
      await tester.tap(find.text('新建判例'));
      await _pumpAnimation(tester);
      await tester.tap(find.widgetWithText(FilledButton, '创建'));
      await _pumpAnimation(tester);
      expect(find.text('判例名称不能为空'), findsOneWidget);

      await tester.enterText(_textFieldWithLabel('判例名称'), '仪器报警可暂停');
      await tester.enterText(_textFieldWithLabel('适用条件'), '设备发出安全警报时允许暂停');
      database.failSaves = true;
      await tester.tap(find.widgetWithText(FilledButton, '创建'));
      await _pumpAnimation(tester);
      expect(find.text('保存失败，请重试；输入已保留。'), findsOneWidget);
      expect(_textFieldWithLabel('判例名称'), findsOneWidget);
      expect(
        tester.widget<TextField>(_textFieldWithLabel('判例名称')).controller?.text,
        '仪器报警可暂停',
      );
      expect(controller.exceptionRules, isEmpty);

      database.failSaves = false;
      await tester.tap(find.widgetWithText(FilledButton, '创建'));
      await _pumpUntil(tester, () => controller.exceptionRules.length == 1);
      await _pumpAnimation(tester);
      expect(find.text('仪器报警可暂停'), findsOneWidget);
      expect(find.text('生效中 · 可引用'), findsOneWidget);
      expect(find.text('作用范围：所有 CTDP 链'), findsOneWidget);

      await tester.tap(find.text('提前完成 0'));
      await _pumpAnimation(tester);
      expect(find.text('没有符合条件的判例'), findsOneWidget);
      await tester.tap(find.text('暂停 1'));
      await _pumpAnimation(tester);
      expect(find.text('仪器报警可暂停'), findsOneWidget);

      await tester.tap(find.byTooltip('判例操作：仪器报警可暂停'));
      await _pumpAnimation(tester);
      await tester.tap(find.text('编辑判例'));
      await _pumpAnimation(tester);
      await tester.enterText(_textFieldWithLabel('判例名称'), '更新后的安全判例');
      await tester.tap(_dropdownWithLabel('作用范围'));
      await _pumpAnimation(tester);
      await tester.tap(find.text('指定 CTDP 链').last);
      await _pumpAnimation(tester);
      await tester.tap(_dropdownWithLabel('适用任务'));
      await _pumpAnimation(tester);
      await tester.tap(find.text('论文专注链').last);
      await _pumpAnimation(tester);
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await _pumpUntil(
        tester,
        () => controller.exceptionRules.single.title == '更新后的安全判例',
      );
      await _pumpAnimation(tester);
      expect(find.text('更新后的安全判例'), findsOneWidget);
      expect(find.text('作用范围：论文专注链'), findsOneWidget);
      expect(
        controller.exceptionRules.single.parentId,
        controller.ctdpTasks.single.id,
      );

      database.failSaves = true;
      await tester.tap(find.byTooltip('判例操作：更新后的安全判例'));
      await _pumpAnimation(tester);
      await tester.tap(find.text('归档判例'));
      await _pumpAnimation(tester);
      expect(find.text('归档判例失败，请重试。'), findsOneWidget);
      expect(controller.exceptionRules.single.data['archived'], isFalse);
      database.failSaves = false;
      await tester.tap(find.byTooltip('判例操作：更新后的安全判例'));
      await _pumpAnimation(tester);
      await tester.tap(find.text('归档判例'));
      await _pumpUntil(
        tester,
        () => controller.exceptionRules.single.data['archived'] == true,
      );
      expect(find.text('已归档 · 不可引用'), findsOneWidget);
      await tester.tap(find.byTooltip('判例操作：更新后的安全判例'));
      await _pumpAnimation(tester);
      await tester.tap(find.text('编辑判例'));
      await _pumpAnimation(tester);
      await tester.enterText(_textFieldWithLabel('判例名称'), '丢弃的修改');
      await tester.tap(find.text('取消'));
      await _pumpAnimation(tester);
      expect(find.text('放弃未保存的判例？'), findsOneWidget);
      await tester.tap(find.text('继续编辑'));
      await _pumpAnimation(tester);
      expect(
        tester.widget<TextField>(_textFieldWithLabel('判例名称')).controller?.text,
        '丢弃的修改',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _pumpAnimation(tester);
      await tester.tap(find.text('放弃更改'));
      await _pumpAnimation(tester);
      expect(controller.exceptionRules.single.title, '更新后的安全判例');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('rule cards and editor reflow at 320dp with 200% text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _newController();
    addTearDown(controller.dispose);
    final task = WorkspaceRecord.create(
      kind: RecordKind.task,
      title: '很长的实验室论文图表复核专注链',
      data: const {'protocol': 'ctdp', 'ctdpTrigger': '打开文档'},
    );
    await controller.addRecord(task);
    await controller.createExceptionRule(
      name: '安全警报暂停规则',
      description:
          '只有设备持续发出安全警报，而且现场人员确认需要停止记录时才允许暂停本轮专注；恢复之前必须登记设备编号、值班人员和处理结果。',
      ruleType: 'pause',
      scope: 'chain',
      chainId: task.id,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: ProtocolsPage(
            controller: controller,
            initialTab: ProtocolTab.rules,
            showHeader: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final rulesList = find
        .ancestor(of: find.text('新建判例'), matching: find.byType(ListView))
        .first;
    final pageScroll = find
        .descendant(of: rulesList, matching: find.byType(Scrollable))
        .first;
    final position = tester.state<ScrollableState>(pageScroll).position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
    await tester.tap(find.text('展开详情'));
    await tester.pumpAndSettle();
    expect(find.text('收起详情'), findsOneWidget);
    expect(tester.takeException(), isNull);

    position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.tap(find.text('新建判例'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.widgetWithText(FilledButton, '创建'));
    await tester.pumpAndSettle();
    expect(find.text('判例名称不能为空'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('protocol analytics distinguishes no outcomes from a zero rate', (
    tester,
  ) async {
    final controller = _newController();
    addTearDown(controller.dispose);
    final task = WorkspaceRecord.create(
      kind: RecordKind.task,
      title: '论文复核专注链',
      data: const {'protocol': 'ctdp'},
    );
    await controller.addRecord(task);
    await controller.addProtocolEvent(
      protocol: 'ctdp',
      action: 'reservation_started',
      subject: task,
    );
    Widget page() => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: ProtocolsPage(
          controller: controller,
          initialTab: ProtocolTab.analytics,
          showHeader: false,
        ),
      ),
    );
    await tester.pumpWidget(page());
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('暂无可判定结算。完成或失败'), findsOneWidget);
    expect(find.text('近 7 日暂无可判定结算。'), findsOneWidget);
    expect(find.textContaining('0.0%'), findsNothing);

    await controller.addProtocolEvent(
      protocol: 'ctdp',
      action: 'main_failed',
      subject: task,
      successful: false,
    );
    await tester.pumpWidget(page());
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('0.0% · 1 次有效结算'), findsOneWidget);
    expect(find.text('近 7 日暂无可判定结算。'), findsNothing);

    await controller.addProtocolEvent(
      protocol: 'ctdp',
      action: 'round_completed',
      subject: task,
    );
    await controller.addRecord(
      WorkspaceRecord.create(
        kind: RecordKind.protocolEvent,
        title: '每日规则 · 已执行',
        scheduledFor: controller.currentTime(),
        data: const {
          'protocol': 'rsip',
          'recordType': 'rsipExecution',
          'action': 'node_settled',
          'executionStatus': 'executed',
        },
      ),
    );
    await controller.addRecord(
      WorkspaceRecord.create(
        kind: RecordKind.protocolEvent,
        title: '每日规则 · 跳过',
        scheduledFor: controller.currentTime(),
        data: const {
          'protocol': 'rsip',
          'recordType': 'rsipExecution',
          'action': 'node_settled',
          'executionStatus': 'skipped',
        },
      ),
    );
    await tester.pumpWidget(page());
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('66.7% · 3 次有效结算'), findsOneWidget);
    final todayBar = tester.getSize(
      find.byKey(const ValueKey('protocol-outcome-bar-6')),
    );
    expect(todayBar.width, greaterThan(0));
    expect(todayBar.height, greaterThan(0));
    final paintedBar = tester.getSize(
      find
          .descendant(
            of: find.byKey(const ValueKey('protocol-outcome-bar-6')),
            matching: find.byType(ColoredBox),
          )
          .first,
    );
    expect(paintedBar.width, greaterThan(0));
    expect(paintedBar.height, greaterThan(0));
    await tester.tap(find.text('30 日'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.textContaining('每格汇总 5 日'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
