import 'package:flutter/material.dart';
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
import 'package:personal_workbench/ui/pages/habits_page.dart';
import 'package:personal_workbench/ui/pages/protocols_page.dart';
import 'package:personal_workbench/ui/widgets/common.dart';
import 'package:personal_workbench/ui/widgets/record_editor_dialog.dart';
import 'package:personal_workbench/ui/widgets/task_row.dart';

class _MemoryAppDatabase extends AppDatabase {
  _MemoryAppDatabase({this.failSaves = false});

  final bool failSaves;
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

WorkbenchController _newController({AppDatabase? database}) {
  return WorkbenchController(
    database: database ?? _MemoryAppDatabase(),
    backupService: BackupService(),
    searchService: SearchService(),
    focusService: FocusService(),
    notificationService: NotificationService(),
    shareCaptureService: ShareCaptureService(),
    syncService: SupabaseSyncService(null),
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
  await tester.tap(find.text('补充更多信息'));
  await _pumpAnimation(tester);
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
  testWidgets('new task editor starts with an empty estimate', (tester) async {
    final controller = _newController();
    addTearDown(controller.dispose);
    await _openEditor(tester, controller, RecordKind.task);
    await tester.tap(find.text('补充更多信息'));
    await _pumpAnimation(tester);

    final estimate = tester.widget<TextField>(_textFieldWithLabel('预计分钟'));
    expect(estimate.controller?.text, isEmpty);
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

    await tester.tap(find.text('习惯'));
    await _pumpAnimation(tester);
    expect(find.text('Protocol habit'), findsOneWidget);
    await tester.tap(find.text('RSIP 规则树'));
    await _pumpAnimation(tester);
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
}
