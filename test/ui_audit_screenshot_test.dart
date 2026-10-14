import 'dart:ui' as ui;
import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_workbench/app.dart';
import 'package:personal_workbench/core/models/attachment.dart';
import 'package:personal_workbench/core/models/restriction_models.dart';
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
import 'package:personal_workbench/ui/pages/behavior_page.dart';
import 'package:personal_workbench/ui/pages/calendar_page.dart';
import 'package:personal_workbench/ui/pages/focus_page.dart';
import 'package:personal_workbench/ui/pages/goals_page.dart';
import 'package:personal_workbench/ui/pages/growth_page.dart';
import 'package:personal_workbench/ui/pages/habits_page.dart';
import 'package:personal_workbench/ui/pages/inbox_page.dart';
import 'package:personal_workbench/ui/pages/notes_page.dart';
import 'package:personal_workbench/ui/pages/plan_page.dart';
import 'package:personal_workbench/ui/pages/policies_page.dart';
import 'package:personal_workbench/ui/pages/projects_page.dart';
import 'package:personal_workbench/ui/pages/protocols_page.dart';
import 'package:personal_workbench/ui/pages/review_page.dart';
import 'package:personal_workbench/ui/pages/restriction_page.dart';
import 'package:personal_workbench/ui/pages/settings_page.dart';
import 'package:personal_workbench/ui/pages/today_page.dart';
import 'package:personal_workbench/ui/widgets/celebration.dart';
import 'package:personal_workbench/ui/widgets/common.dart';
import 'package:personal_workbench/ui/widgets/global_search_dialog.dart';
import 'package:personal_workbench/ui/widgets/jade_icon.dart';
import 'package:personal_workbench/ui/widgets/markdown_editor_dialog.dart';
import 'package:personal_workbench/ui/widgets/quick_capture_sheet.dart';
import 'package:personal_workbench/ui/widgets/record_editor_dialog.dart';
import 'package:personal_workbench/ui/widgets/relation_picker_dialog.dart';
import 'package:personal_workbench/ui/widgets/task_group_editor_dialog.dart';

class _MemoryDatabase extends AppDatabase {
  final Map<String, WorkspaceRecord> records = {};

  @override
  Future<void> saveRecord(
    WorkspaceRecord record, {
    bool markDirty = true,
  }) async {
    records['${record.kind.name}:${record.id}'] = record;
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
  Future<void> permanentlyDeleteRecords(
    Iterable<({String id, RecordKind kind})> values,
  ) async {
    for (final value in values) {
      records.remove('${value.kind.name}:${value.id}');
    }
  }

  @override
  Future<void> close() async {}

  @override
  Future<List<Attachment>> loadAttachments({String? ownerRecordId}) async =>
      const [];

  @override
  Future<int> attachmentBytes() async => 0;
}

class _AuditCloudRemote implements WorkspaceSyncRemote {
  @override
  String get userId => 'audit-account';

  @override
  Future<void> upsert(List<Map<String, dynamic>> rows) async {}

  @override
  Future<void> delete(List<Map<String, dynamic>> keys) async {}

  @override
  Future<List<Map<String, dynamic>>> fetchPage({
    required int offset,
    required int limit,
  }) async => const [];
}

class _AuditSignedInController extends WorkbenchController {
  _AuditSignedInController()
    : super(
        database: _MemoryDatabase(),
        backupService: BackupService(),
        searchService: SearchService(),
        focusService: FocusService(),
        notificationService: NotificationService(),
        shareCaptureService: ShareCaptureService(),
        syncService: SupabaseSyncService.withRemote(_AuditCloudRemote()),
        now: () => _auditNow,
      );

  @override
  String? get signedInEmail => 'member@example.com';

  @override
  SyncPhase get syncPhase => SyncPhase.error;

  @override
  String get syncMessage => '当前离线，保留本地修改；连接恢复后可重试同步。';
}

final _auditNow = DateTime(2026, 8, 9, 10);

Future<void> _loadAuditFonts() async {
  final materialIcons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  final display = FontLoader(AppFonts.display)
    ..addFont(rootBundle.load('assets/fonts/LXGWWenKaiGB-Medium.ttf'));
  final goldenCjk = FontLoader('GoldenCjk')
    ..addFont(rootBundle.load('assets/fonts/LXGWWenKaiGB-Medium.ttf'));
  final body = FontLoader(AppFonts.body)
    ..addFont(rootBundle.load('assets/fonts/IBMPlexSansSC-Regular.otf'))
    ..addFont(rootBundle.load('assets/fonts/IBMPlexSansSC-Medium.otf'))
    ..addFont(rootBundle.load('assets/fonts/IBMPlexSansSC-SemiBold.otf'));
  final numeric = FontLoader(AppFonts.numeric)
    ..addFont(rootBundle.load('assets/fonts/IBMPlexMono-Medium.ttf'));
  await Future.wait([
    materialIcons.load(),
    display.load(),
    goldenCjk.load(),
    body.load(),
    numeric.load(),
  ]);
}

Future<WorkbenchController> _createEmptyController({
  bool cloudConfigured = false,
}) async => WorkbenchController(
  database: _MemoryDatabase(),
  backupService: BackupService(),
  searchService: SearchService(),
  focusService: FocusService(),
  notificationService: NotificationService(),
  shareCaptureService: ShareCaptureService(),
  syncService: cloudConfigured
      ? SupabaseSyncService.withRemote(_AuditCloudRemote())
      : SupabaseSyncService(null),
  now: () => _auditNow,
);

Future<WorkbenchController> _createCompletedReviewController() async {
  final controller = await _createEmptyController();
  for (final (id, day, status) in <(String, int, String)>[
    ('one', 8, WorkStatus.done),
    ('two', 8, WorkStatus.done),
    ('three', 9, WorkStatus.done),
    ('failed', 8, WorkStatus.failed),
    ('prior-week', 2, WorkStatus.done),
  ]) {
    final at = DateTime(2026, 8, day, 12);
    await controller.addRecord(
      WorkspaceRecord(
        id: 'review-date-$id',
        kind: RecordKind.task,
        title: '期间任务 $id',
        status: status,
        scheduledFor: at,
        createdAt: at,
        updatedAt: at,
        data: {'settledAt': at.toUtc().toIso8601String()},
      ),
    );
  }
  return controller;
}

Future<WorkbenchController> _createController({bool withRsip = false}) async {
  final controller = await _createEmptyController();
  final project = WorkspaceRecord.create(
    kind: RecordKind.project,
    title: '行射实验论文复核',
    body: '整理数据、复核误差来源，并形成可追溯的论文图。',
    favorite: true,
  );
  final task = WorkspaceRecord.create(
    kind: RecordKind.task,
    title: '核对采样间隔与单位',
    body: '确认 Nyquist 条件和传播距离。',
    scheduledFor: _auditNow,
    projectId: project.id,
    data: const {'isFocus': true, 'priority': 3, 'estimatedMinutes': 25},
  );
  final records = <WorkspaceRecord>[
    project,
    task,
    WorkspaceRecord.create(
      kind: RecordKind.task,
      title: '整理实验数据与误差记录',
      status: WorkStatus.done,
      projectId: project.id,
      data: const {'estimatedMinutes': 50},
    ),
    WorkspaceRecord.create(
      kind: RecordKind.task,
      title: '阅读角谱传播采样条件笔记',
      status: WorkStatus.todo,
      projectId: project.id,
    ),
    WorkspaceRecord(
      id: newRecordId(),
      kind: RecordKind.note,
      title: '角谱传播采样检查清单',
      body: '记录输入场、波长、采样间隔和单位。',
      projectId: project.id,
      tags: const ['ASM', '采样'],
      createdAt: _auditNow,
      updatedAt: _auditNow,
    ),
    WorkspaceRecord(
      id: newRecordId(),
      kind: RecordKind.note,
      title: '论文复核周回顾',
      body: '本周完成了测量数据整理，下一步核对图轴单位。',
      createdAt: _auditNow.subtract(const Duration(days: 1)),
      updatedAt: _auditNow.subtract(const Duration(days: 1)),
      data: {
        'recordType': 'periodReview',
        'periodType': 'weekly',
        'periodKey': '2026-W32',
        'relatedProjectIds': [project.id],
      },
    ),
    WorkspaceRecord.create(
      kind: RecordKind.link,
      title: '待整理的参考链接',
      body: 'https://example.com',
      status: WorkStatus.inbox,
      data: const {'inbox': true},
    ),
    WorkspaceRecord.create(
      kind: RecordKind.goal,
      title: '完成论文图表复核',
      dueAt: _auditNow.add(const Duration(days: 30)),
    ),
    WorkspaceRecord.create(
      kind: RecordKind.milestone,
      title: '确认图轴单位',
      body: '逐张核对横纵轴单位、图注和误差线说明，完成后可以开始论文图表的最终复核。',
      dueAt: _auditNow.add(const Duration(days: 7)),
      projectId: project.id,
      data: {
        'relatedTaskIds': [task.id],
      },
    ),
    WorkspaceRecord.create(
      kind: RecordKind.milestone,
      title: '整理首批测量结果',
      status: WorkStatus.done,
      dueAt: _auditNow.subtract(const Duration(days: 3)),
      projectId: project.id,
    ),
    WorkspaceRecord.create(
      kind: RecordKind.habit,
      title: '每日记录实验进展',
      data: const {'frequency': 'daily'},
    ),
    WorkspaceRecord.create(
      kind: RecordKind.diary,
      title: '今日实验回顾',
      body: '完成数据清洗，下一步检查误差来源。',
      scheduledFor: _auditNow,
      data: const {'mood': 4, 'completedToday': '采样复核'},
    ),
    WorkspaceRecord.create(
      kind: RecordKind.focusSession,
      title: '角谱传播复核',
      scheduledFor: _auditNow.subtract(const Duration(hours: 1)),
      data: const {'seconds': 1500},
    ),
    WorkspaceRecord(
      id: 'audit-focus-preset-review',
      kind: RecordKind.template,
      title: '论文图参数复核',
      createdAt: _auditNow,
      updatedAt: _auditNow,
      data: const {
        'recordType': 'focusPreset',
        'mode': 'custom',
        'minutes': 45,
        'scheduleMode': 'weekly',
        'listMode': 'none',
      },
    ),
    WorkspaceRecord(
      id: 'audit-focus-preset-stopwatch',
      kind: RecordKind.template,
      title: '不限时实验记录整理与交叉检查',
      createdAt: _auditNow,
      updatedAt: _auditNow,
      data: const {
        'recordType': 'focusPreset',
        'mode': 'stopwatch',
        'minutes': 25,
        'scheduleMode': 'none',
        'listMode': 'none',
      },
    ),
    WorkspaceRecord.create(
      kind: RecordKind.timeBlock,
      title: '论文图表复核时段',
      parentId: task.id,
      scheduledFor: DateTime(2026, 8, 9, 9),
      data: const {'durationMinutes': 60},
    ),
  ];
  for (final record in records) {
    await controller.addRecord(record);
  }
  await controller.addRecord(
    const RestrictionProfile(
      id: 'restriction-profile-audit',
      title: '论文冲刺自律',
      enabled: true,
      schedules: [
        RestrictionScheduleRule(
          id: 'weekday-daytime',
          label: '工作日实验与写作',
          days: [1, 2, 3, 4, 5],
          startMinutes: 9 * 60,
          endMinutes: 18 * 60,
        ),
        RestrictionScheduleRule(
          id: 'evening-review',
          label: '晚间论文复核',
          days: [1, 3, 5],
          startMinutes: 19 * 60 + 30,
          endMinutes: 22 * 60,
        ),
      ],
      blockedApps: ['game.exe', 'video.exe'],
      blockedTitleKeywords: ['短视频', '游戏直播'],
      websiteBlocking: true,
      blockedWebsites: ['example-video.test', 'example-game.test'],
      allowBreak: true,
      strongProtection: true,
    ).toRecord(),
  );
  await controller.addRecord(
    WorkspaceRecord(
      id: 'restriction-event-audit',
      kind: RecordKind.protocolEvent,
      title: 'video.exe',
      body: '',
      status: WorkStatus.done,
      scheduledFor: _auditNow.subtract(const Duration(minutes: 18)),
      createdAt: _auditNow.subtract(const Duration(minutes: 18)),
      updatedAt: _auditNow.subtract(const Duration(minutes: 18)),
      data: const {
        'recordType': 'restrictionEvent',
        'reason': '窗口标题命中：短视频',
        'action': 'forceClose',
      },
    ),
  );
  if (withRsip) {
    final protocolTask = WorkspaceRecord(
      id: 'audit-ctdp-task',
      kind: RecordKind.task,
      title: '论文复核专注链',
      projectId: project.id,
      createdAt: _auditNow.subtract(const Duration(days: 1)),
      updatedAt: _auditNow.subtract(const Duration(days: 1)),
      data: const {
        'protocol': 'ctdp',
        'ctdpTrigger': '打开论文草稿',
        'ctdpAuxSignal': '清空桌面',
        'ctdpSessionMinutes': 25,
      },
    );
    await controller.addRecord(protocolTask);
    await controller.createExceptionRule(
      name: '设备安全警报暂停',
      description: '仅在设备发出持续安全警报且现场负责人确认后暂停；恢复前记录设备编号、处置经过和复核结果。',
      ruleType: 'pause',
      scope: 'chain',
      chainId: protocolTask.id,
    );
    final archivedRule = await controller.createExceptionRule(
      name: '紧急疏散允许中断',
      description: '建筑物疏散警报响起时立即中断专注并离开工作区。',
      ruleType: 'interruption',
      scope: 'global',
    );
    await controller.archiveExceptionRule(archivedRule, true);
    await controller.addRecord(
      WorkspaceRecord(
        id: 'audit-ctdp-focus-session',
        kind: RecordKind.focusSession,
        title: '论文图表聚焦',
        parentId: protocolTask.id,
        status: WorkStatus.done,
        scheduledFor: _auditNow.subtract(const Duration(minutes: 40)),
        createdAt: _auditNow.subtract(const Duration(minutes: 40)),
        updatedAt: _auditNow.subtract(const Duration(minutes: 15)),
        data: const {'seconds': 1500},
      ),
    );
    final childTask = controller.tasks.firstWhere(
      (record) => record.title == '阅读角谱传播采样条件笔记',
    );
    await controller.updateRecord(childTask.copyWith(parentId: task.id));
    final group = WorkspaceRecord(
      id: 'audit-task-group',
      kind: RecordKind.template,
      title: '论文复核任务群',
      projectId: project.id,
      createdAt: _auditNow,
      updatedAt: _auditNow,
      data: const {'recordType': 'taskGroup', 'mode': 'parallel', 'version': 1},
    );
    await controller.addRecord(group);
    final groupMembers = [
      task,
      controller.tasks.firstWhere((record) => record.id == childTask.id),
      controller.tasks.firstWhere((record) => record.isDone),
    ];
    for (var index = 0; index < groupMembers.length; index++) {
      final member = groupMembers[index];
      await controller.addRecord(
        WorkspaceRecord(
          id: 'audit-task-group-member-$index',
          kind: RecordKind.relation,
          title: '${group.title} · ${member.title}',
          parentId: group.id,
          createdAt: _auditNow,
          updatedAt: _auditNow,
          data: {
            'relationType': 'taskGroupMember',
            'groupId': group.id,
            'taskId': member.id,
            'position': index,
            'active': true,
          },
        ),
      );
    }
    final node = await controller.saveRsipNode(
      title: '实验结束后登记参数',
      rule: '结束实验十分钟内记录采样间隔、单位与误差来源',
      type: RsipNodeType.policy,
    );
    await controller.settleRsipNode(
      node,
      status: RsipExecutionStatus.executed,
      reason: '已保存实验记录',
    );
    // RSIP records are created within milliseconds. Give the screenshot fixture
    // stable event times so the recent-activity list has a reproducible order.
    const eventOffsets = {
      'run_started': -2,
      'node_created': -1,
      'node_settled': 0,
    };
    for (final event in controller.protocolEvents.where(
      (record) => record.data['protocol'] == 'rsip',
    )) {
      final offset = eventOffsets[event.data['action']];
      if (offset == null) continue;
      final createdAt = _auditNow.add(Duration(minutes: offset));
      await controller.updateRecord(
        WorkspaceRecord.fromJson({
          ...event.toJson(),
          'createdAt': createdAt.toIso8601String(),
          'updatedAt': createdAt.toIso8601String(),
        }),
      );
    }
  }
  return controller;
}

Widget _host(
  Widget page, {
  Brightness brightness = Brightness.light,
  TextScaler textScaler = TextScaler.noScaling,
  bool disableAnimations = false,
  bool windowChrome = false,
}) {
  final theme = brightness == Brightness.dark
      ? AppTheme.dark()
      : AppTheme.light();
  final goldenTheme = theme.copyWith(
    textTheme: theme.textTheme.apply(fontFamily: 'GoldenCjk'),
    primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: 'GoldenCjk'),
  );
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: goldenTheme,
    locale: const Locale('zh', 'CN'),
    supportedLocales: const [Locale('zh', 'CN')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) {
      final media = MediaQuery.of(context);
      return MediaQuery(
        data: media.copyWith(
          textScaler: textScaler,
          disableAnimations: disableAnimations,
        ),
        child: child!,
      );
    },
    home: Scaffold(
      body: RepaintBoundary(
        key: const ValueKey('audit-window-capture'),
        child: Builder(
          builder: (context) {
            if (!windowChrome) return WorkbenchViewport(child: page);
            final size = MediaQuery.sizeOf(context);
            if (size.width < AppBreakpoints.compact) {
              return Padding(
                padding: const EdgeInsets.only(top: 64, bottom: 84),
                child: WorkbenchViewport(child: page),
              );
            }
            return Row(
              children: [
                SizedBox(
                  width:
                      (size.width < AppBreakpoints.expanded
                          ? AppLayout.desktopNavCollapsed
                          : AppLayout.desktopNavExpanded) +
                      1,
                ),
                Expanded(child: WorkbenchViewport(child: page)),
              ],
            );
          },
        ),
      ),
    ),
  );
}

Finder _enabledAuditControls() => find.byWidgetPredicate((widget) {
  if (widget is ButtonStyleButton) return widget.onPressed != null;
  if (widget is IconButton) return widget.onPressed != null;
  if (widget is FloatingActionButton) return widget.onPressed != null;
  if (widget is InkWell) return widget.onTap != null;
  if (widget is ListTile) return widget.onTap != null;
  return false;
}).hitTestable();

Finder _openableMenuControls() => find.byWidgetPredicate((widget) {
  if (widget is PopupMenuButton) return widget.enabled;
  if (widget.runtimeType.toString().startsWith('DropdownButton<')) return true;
  return false;
}).hitTestable();

Future<void> _verifyInteractiveStates(
  WidgetTester tester,
  _AuditSurface surface,
  Size size,
) async {
  await _verifySurface(tester, surface, size, scenario: 'interaction-states');

  final controls = _enabledAuditControls();
  if (controls.evaluate().isEmpty) {
    expect(
      surface.name,
      'growth',
      reason: '${surface.name} unexpectedly has no enabled control at $size',
    );
    return;
  }
  expect(
    controls,
    findsWidgets,
    reason: '${surface.name} exposes no enabled control at $size',
  );
  final target = controls.first;
  final originalRect = tester.getRect(target);

  final mouse = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
  await mouse.addPointer();
  await mouse.moveTo(originalRect.center);
  await tester.pump(const Duration(milliseconds: 180));
  expect(
    tester.getRect(target),
    originalRect,
    reason: '${surface.name} hover changes layout geometry at $size',
  );
  expect(
    tester.takeException(),
    isNull,
    reason: '${surface.name} failed during hover at $size',
  );

  await mouse.down(originalRect.center);
  await tester.pump(const Duration(milliseconds: 60));
  expect(
    tester.getRect(target),
    originalRect,
    reason: '${surface.name} press changes layout geometry at $size',
  );
  expect(
    tester.takeException(),
    isNull,
    reason: '${surface.name} failed during press at $size',
  );
  await mouse.cancel();
  await mouse.removePointer();
  await tester.pump(const Duration(milliseconds: 180));
  expect(
    tester.takeException(),
    isNull,
    reason: '${surface.name} failed after leaving the pressed state at $size',
  );

  FocusManager.instance.primaryFocus?.unfocus();
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pump(const Duration(milliseconds: 180));
  final focusedNode = FocusManager.instance.primaryFocus;
  expect(
    focusedNode?.context,
    isNotNull,
    reason: '${surface.name} cannot receive keyboard focus at $size',
  );
  final focusException = tester.takeException();
  expect(
    focusException,
    isNull,
    reason:
        '${surface.name} failed during pointer/keyboard states at $size; '
        'focused=${focusedNode?.debugLabel}/'
        '${focusedNode?.context?.widget.runtimeType}',
  );
}

Future<void> _verifyOpenMenus(
  WidgetTester tester,
  _AuditSurface surface,
  Size size,
) async {
  await _verifySurface(tester, surface, size, scenario: 'open-menus');
  final menuCount = _openableMenuControls().evaluate().length;
  for (var index = 0; index < menuCount; index++) {
    await _verifySurface(tester, surface, size, scenario: 'open-menu-$index');
    // Freeze the exact element before scrolling. A finder based on
    // `.hitTestable().at(index)` is recomputed after ensureVisible; moving a
    // lazy task list can change which menu occupies that index.
    final menus = _openableMenuControls().evaluate().toList(growable: false);
    expect(
      menus.length,
      greaterThan(index),
      reason: '${surface.name} menu $index disappeared at $size',
    );
    final menuElement = menus[index];
    final menuType = menuElement.widget.runtimeType;
    final menuKey = menuElement.widget.key;
    final trigger = menuKey == null
        ? find.byElementPredicate((element) => identical(element, menuElement))
        : find.byKey(menuKey);
    if (trigger.hitTestable().evaluate().isEmpty) {
      await tester.ensureVisible(trigger);
      await tester.pumpAndSettle();
    }
    expect(
      trigger.hitTestable(),
      findsOneWidget,
      reason:
          '${surface.name} menu $index ($menuType) '
          'is obscured at $size',
    );
    final baselineBarrierCount = find.byType(ModalBarrier).evaluate().length;
    await tester.tap(trigger.hitTestable());
    await tester.pumpAndSettle();
    expect(
      find.byType(ModalBarrier).evaluate().length,
      greaterThan(baselineBarrierCount),
      reason:
          '${surface.name} menu $index ($menuType) '
          'did not open at $size',
    );
    expect(
      tester.takeException(),
      isNull,
      reason: '${surface.name} menu $index failed while open at $size',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(
      find.byType(ModalBarrier).evaluate().length,
      baselineBarrierCount,
      reason: '${surface.name} menu $index did not close with Escape at $size',
    );
    expect(
      tester.takeException(),
      isNull,
      reason: '${surface.name} menu $index failed while closing at $size',
    );
  }
}

class _DialogAudit {
  const _DialogAudit(this.name, this.open);

  final String name;
  final void Function(BuildContext context) open;
}

Future<void> _verifyDialogState(
  WidgetTester tester,
  _DialogAudit audit,
  Size size, {
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pumpWidget(
    _host(
      Builder(
        builder: (context) => Center(
          child: FilledButton(
            onPressed: () => audit.open(context),
            child: const Text('打开'),
          ),
        ),
      ),
      textScaler: textScaler,
    ),
  );
  await tester.pumpAndSettle();
  final baselineBarrierCount = find.byType(ModalBarrier).evaluate().length;
  await tester.tap(find.text('打开'));
  await tester.pumpAndSettle();
  expect(
    find.byType(ModalBarrier).evaluate().length,
    greaterThan(baselineBarrierCount),
    reason: '${audit.name} did not open at $size / $textScaler',
  );
  expect(
    tester.takeException(),
    isNull,
    reason: '${audit.name} failed while opening at $size / $textScaler',
  );

  for (var index = 0; index < 4; index++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      tester.takeException(),
      isNull,
      reason:
          '${audit.name} failed after Tab ${index + 1} at $size / $textScaler',
    );
  }

  // Keep the route open while crossing navigation and dialog breakpoints.
  for (final resized in const [
    Size(1200, 900),
    Size(320, 568),
    Size(800, 450),
    Size(1920, 1080),
  ]) {
    tester.view.physicalSize = resized;
    await tester.pumpAndSettle();
    expect(
      find.byType(ModalBarrier).evaluate().length,
      greaterThan(baselineBarrierCount),
      reason: '${audit.name} lost its open route after resizing to $resized',
    );
    expect(
      tester.takeException(),
      isNull,
      reason: '${audit.name} failed after resizing to $resized / $textScaler',
    );
  }

  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pumpAndSettle();
  expect(
    find.byType(ModalBarrier).evaluate().length,
    baselineBarrierCount,
    reason: '${audit.name} did not close with Escape at $size / $textScaler',
  );
  expect(
    tester.takeException(),
    isNull,
    reason: '${audit.name} failed while closing at $size / $textScaler',
  );
}

Future<void> _capture(
  WidgetTester tester,
  String name,
  Widget child, {
  Size size = const Size(1200, 900),
  Brightness brightness = Brightness.light,
  bool disableAnimations = false,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  // 每张页面截图使用全新的 Navigator，避免前一张图的弹窗路由残留。
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pumpWidget(
    _host(
      child,
      brightness: brightness,
      disableAnimations: disableAnimations,
      textScaler: textScaler,
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
  final images = tester.widgetList<Image>(find.byType(Image)).toList();
  if (images.isNotEmpty) {
    final context = tester.element(find.byType(Scaffold).first);
    await tester.runAsync(() async {
      for (final image in images) {
        await precacheImage(image.image, context);
      }
    });
    await tester.pump();
  }
  expect(tester.takeException(), isNull);
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/ui_audit/$name.png'),
  );
}

Future<void> _captureRestrictionEditor(
  WidgetTester tester,
  WorkbenchController controller,
  String name, {
  required Size size,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  final compact = size.width < AppBreakpoints.compact;
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pumpWidget(
    _host(RestrictionPage(controller: controller, showHeader: !compact)),
  );
  await tester.pump(const Duration(milliseconds: 600));
  await tester.tap(
    compact ? find.byTooltip('编辑自律规则') : find.byTooltip('编辑规则').first,
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/ui_audit/$name.png'),
  );
}

class _AuditSurface {
  const _AuditSurface(this.name, this.builder);

  final String name;
  final Widget Function(Size size) builder;
}

List<_AuditSurface> _auditSurfaces(WorkbenchController controller) => [
  _AuditSurface(
    'today',
    (size) => TodayPage(
      controller: controller,
      showHeader: size.width >= AppBreakpoints.compact,
      onOpenFocus: () {},
    ),
  ),
  for (final tab in PlanTab.values)
    _AuditSurface(
      'tasks_${tab.name}',
      (size) => PlanPage(
        controller: controller,
        initialTab: tab,
        showHeader: size.width >= AppBreakpoints.compact,
        showTabs: false,
      ),
    ),
  for (final tab in ProjectDetailTab.values)
    _AuditSurface(
      'projects_${tab.name}',
      (size) => ProjectsPage(
        controller: controller,
        initialTab: tab,
        showHeader: size.width >= AppBreakpoints.compact,
        showTabs: false,
      ),
    ),
  _AuditSurface(
    'focus_hub',
    (size) => FocusHubPage(
      controller: controller,
      showHeader: size.width >= AppBreakpoints.compact,
    ),
  ),
  _AuditSurface(
    'focus_session',
    (_) => FocusPage(
      controller: controller,
      task: controller.focusTasks.firstOrNull,
    ),
  ),
  _AuditSurface(
    'restriction',
    (size) => RestrictionPage(
      controller: controller,
      showHeader: size.width >= AppBreakpoints.compact,
    ),
  ),
  _AuditSurface(
    'notes',
    (size) => NotesPage(
      controller: controller,
      showHeader: size.width >= AppBreakpoints.compact,
    ),
  ),
  for (final tab in ReviewTab.values)
    _AuditSurface(
      'review_${tab.name}',
      (size) => ReviewPage(
        controller: controller,
        initialTab: tab,
        showHeader: size.width >= AppBreakpoints.compact,
        showPeriodSwitcher: false,
      ),
    ),
  _AuditSurface(
    'goals',
    (size) => GoalsPage(
      controller: controller,
      showHeader: size.width >= AppBreakpoints.compact,
    ),
  ),
  _AuditSurface(
    'habits',
    (size) => HabitsPage(
      controller: controller,
      showHeader: size.width >= AppBreakpoints.compact,
    ),
  ),
  _AuditSurface(
    'behavior_habits',
    (size) => BehaviorPage(
      controller: controller,
      initialMode: BehaviorMode.habits,
      showHeader: size.width >= AppBreakpoints.compact,
    ),
  ),
  for (final tab in PolicyTab.values)
    _AuditSurface(
      'behavior_policies_${tab.name}',
      (size) => BehaviorPage(
        controller: controller,
        initialMode: BehaviorMode.policies,
        initialPolicyTab: tab,
        showHeader: size.width >= AppBreakpoints.compact,
      ),
    ),
  for (final tab in PolicyTab.values)
    _AuditSurface(
      'policies_${tab.name}',
      (size) => PoliciesPage(
        controller: controller,
        initialTab: tab,
        showHeader: size.width >= AppBreakpoints.compact,
        showTabs: false,
      ),
    ),
  for (final tab in ProtocolTab.values)
    _AuditSurface(
      'legacy_protocols_${tab.name}',
      (size) => ProtocolsPage(
        controller: controller,
        initialTab: tab,
        showHeader: size.width >= AppBreakpoints.compact,
      ),
    ),
  _AuditSurface(
    'growth',
    (size) => GrowthPage(
      controller: controller,
      showHeader: size.width >= AppBreakpoints.compact,
    ),
  ),
  _AuditSurface(
    'settings',
    (size) => SettingsPage(
      controller: controller,
      showHeader: size.width >= AppBreakpoints.compact,
    ),
  ),
];

Future<void> _verifySurface(
  WidgetTester tester,
  _AuditSurface surface,
  Size size, {
  Brightness brightness = Brightness.light,
  TextScaler textScaler = TextScaler.noScaling,
  double devicePixelRatio = 1,
  bool disableAnimations = false,
  bool windowChrome = false,
  required String scenario,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = devicePixelRatio;
  final logicalSize = Size(
    size.width / devicePixelRatio,
    size.height / devicePixelRatio,
  );
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  expect(
    tester.takeException(),
    isNull,
    reason:
        'previous surface failed while switching to ${surface.name} '
        'at $size ($scenario)',
  );
  await tester.pumpWidget(
    _host(
      surface.builder(logicalSize),
      brightness: brightness,
      textScaler: textScaler,
      disableAnimations: disableAnimations,
      windowChrome: windowChrome,
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  expect(
    tester.takeException(),
    isNull,
    reason: '${surface.name} failed at $size ($scenario)',
  );
  expect(
    find.byType(Semantics),
    findsWidgets,
    reason: '${surface.name} has no semantics at $size ($scenario)',
  );
}

void main() {
  setUpAll(_loadAuditFonts);

  testWidgets('focus completion settles within 400ms and keeps next action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var dismissed = false;
    await tester.pumpWidget(
      _host(
        FocusCelebration(
          title: '本次专注已记录',
          subtitle: '核对采样间隔与单位 · 25 分钟',
          actionLabel: '返回专注中心',
          onDone: () => dismissed = true,
        ),
        textScaler: const TextScaler.linear(2),
      ),
    );
    final ring = find.byKey(const ValueKey('focus-completion-ring'));
    await tester.pump(const Duration(milliseconds: 180));
    expect(
      tester.widget<CircularProgressIndicator>(ring).value,
      allOf(greaterThan(0), lessThan(1)),
    );
    await tester.pump(const Duration(milliseconds: 220));
    expect(tester.widget<CircularProgressIndicator>(ring).value, 1);
    final action = find.widgetWithText(FilledButton, '返回专注中心');
    expect(tester.getRect(action).bottom, lessThanOrEqualTo(568));
    await tester.pump(const Duration(seconds: 2));
    expect(action, findsOneWidget);
    await tester.tap(action);
    expect(dismissed, isTrue);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      _host(
        const FocusCelebration(title: '本次专注已记录'),
        textScaler: const TextScaler.linear(2),
        disableAnimations: true,
      ),
    );
    await tester.pump();
    expect(tester.widget<CircularProgressIndicator>(ring).value, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('captures focus completion in both themes and window sizes', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final brightness in Brightness.values) {
      for (final size in const [Size(320, 568), Size(1200, 900)]) {
        final narrow = size.width == 320;
        await _capture(
          tester,
          'focus_completion_${brightness.name}_${size.width.toInt()}x${size.height.toInt()}${narrow ? '_text200' : ''}',
          const FocusCelebration(
            title: '本次专注已记录',
            subtitle: '核对采样间隔与单位 · 25 分钟',
            actionLabel: '返回专注中心',
          ),
          size: size,
          brightness: brightness,
          textScaler: narrow
              ? const TextScaler.linear(2)
              : TextScaler.noScaling,
        );
      }
    }
  });

  testWidgets('review week and month count only real completed dates', (
    tester,
  ) async {
    final controller = await _createCompletedReviewController();
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    Finder dayLabel(String label) => find.byWidgetPredicate(
      (widget) => widget is Semantics && widget.properties.label == label,
    );

    await tester.pumpWidget(
      _host(
        ReviewPage(
          controller: controller,
          initialTab: ReviewTab.weekly,
          showHeader: false,
          showPeriodSwitcher: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(dayLabel('8月8日完成 2 项'), findsOneWidget);
    expect(dayLabel('8月9日完成 1 项'), findsOneWidget);
    expect(dayLabel('8月2日完成 1 项'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(
      _host(
        ReviewPage(
          controller: controller,
          initialTab: ReviewTab.monthly,
          showHeader: false,
          showPeriodSwitcher: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(dayLabel('8月2日完成 1 项'), findsOneWidget);
    expect(dayLabel('8月8日完成 2 项'), findsOneWidget);
    expect(dayLabel('8月9日完成 1 项'), findsOneWidget);
    expect(dayLabel('8月10日完成 0 项'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'daily review summary reflows below ring at 320dp and 200% text',
    (tester) async {
      final controller = await _createCompletedReviewController();
      addTearDown(controller.dispose);
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _host(
          ReviewPage(
            controller: controller,
            initialTab: ReviewTab.diary,
            showHeader: false,
            showPeriodSwitcher: false,
          ),
          textScaler: const TextScaler.linear(2),
        ),
      );
      await tester.pumpAndSettle();

      final ring = find.byType(CircularProgressIndicator).first;
      final summary = find.textContaining('项期间任务；其余状态').first;
      expect(
        tester.getRect(summary).top,
        greaterThan(tester.getRect(ring).bottom),
      );
      expect(tester.getSize(summary).width, greaterThan(200));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'today overview gives its title a full row at 320dp and 200% text',
    (tester) async {
      final controller = await _createController(withRsip: true);
      addTearDown(controller.dispose);
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _host(
          TodayPage(
            controller: controller,
            showHeader: false,
            onOpenFocus: () {},
          ),
          textScaler: const TextScaler.linear(2),
        ),
      );
      await tester.pumpAndSettle();

      final title = find.text('还剩 1 件事');
      final facts = find.textContaining('已完成 0 项\n专注');
      final ring = find.byKey(const ValueKey('today-progress-ring'));
      final focus = find.widgetWithText(FilledButton, '开始专注');
      expect(title, findsOneWidget);
      expect(tester.widget<Text>(title).overflow, TextOverflow.clip);
      expect(
        tester.getRect(ring).top,
        greaterThan(tester.getRect(title).bottom),
      );
      expect(
        tester.getRect(ring).left,
        greaterThan(tester.getRect(facts).right),
      );
      expect(tester.getSize(facts).width, greaterThan(150));
      expect(tester.getRect(focus).bottom, lessThanOrEqualTo(568));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('review period controls retain selection through live resizing', (
    tester,
  ) async {
    final controller = await _createEmptyController();
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    await tester.pumpWidget(
      _host(
        ReviewPage(controller: controller, showHeader: false),
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('周').first);
    await tester.pumpAndSettle();
    expect(find.text('七日完成分布'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('月').first);
    await tester.pumpAndSettle();
    expect(find.text('月度完成日历'), findsOneWidget);
    expect(tester.takeException(), isNull);

    for (final size in const [Size(800, 450), Size(1440, 900)]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(find.text('月度完成日历'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('captures completed review periods in both themes', (
    tester,
  ) async {
    final controller = await _createCompletedReviewController();
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final tab in ReviewTab.values) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        for (final size in const [Size(390, 844), Size(1200, 900)]) {
          await _capture(
            tester,
            'review_completed_${tab.name}_${brightness.name}_${size.width.toInt()}x${size.height.toInt()}',
            ReviewPage(
              controller: controller,
              initialTab: tab,
              showHeader: size.width >= AppBreakpoints.compact,
              showPeriodSwitcher: false,
            ),
            size: size,
            brightness: brightness,
          );
        }
      }
    }
  });

  testWidgets('focus modes stay readable and retain selection across resize', (
    tester,
  ) async {
    final controller = await _createController();
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 700);
    await tester.pumpWidget(
      _host(FocusPage(controller: controller, task: null)),
    );
    await tester.pumpAndSettle();
    final dropdown = find.byType(DropdownButtonFormField<FocusMode>);
    expect(dropdown, findsOneWidget);
    expect(find.byType(SegmentedButton<FocusMode>), findsNothing);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('50 / 10').last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<DropdownButtonFormField<FocusMode>>(dropdown).initialValue,
      FocusMode.pomodoro50,
    );
    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SegmentedButton<FocusMode>>(
            find.byType(SegmentedButton<FocusMode>),
          )
          .selected,
      {FocusMode.pomodoro50},
    );
    await tester.pumpWidget(
      _host(
        FocusPage(controller: controller, task: null),
        textScaler: TextScaler.linear(2),
      ),
    );
    await tester.pumpAndSettle();
    expect(dropdown, findsOneWidget);
    expect(
      tester.widget<DropdownButtonFormField<FocusMode>>(dropdown).initialValue,
      FocusMode.pomodoro50,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'focus hub presets reflow and honor selection and statistics motion',
    (tester) async {
      final controller = await _createController();
      addTearDown(controller.dispose);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;

      Future<void> pumpAt(
        Size size, {
        bool reducedMotion = false,
        TextScaler textScaler = TextScaler.noScaling,
      }) async {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          _host(
            FocusHubPage(controller: controller, showHeader: false),
            disableAnimations: reducedMotion,
            textScaler: textScaler,
          ),
        );
        await tester.pumpAndSettle();
      }

      await pumpAt(const Size(1200, 900));
      final first = find.byKey(
        const ValueKey('focus-preset-audit-focus-preset-review'),
      );
      final second = find.byKey(
        const ValueKey('focus-preset-audit-focus-preset-stopwatch'),
      );
      expect(first, findsOneWidget);
      expect(second, findsOneWidget);
      expect(tester.getTopLeft(first).dy, tester.getTopLeft(second).dy);
      expect(
        find.descendant(of: first, matching: find.text('45')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: second, matching: find.text('∞')),
        findsOneWidget,
      );
      final chartAnimations = find.byWidgetPredicate(
        (widget) =>
            widget is TweenAnimationBuilder<double> &&
            widget.duration == const Duration(milliseconds: 240),
      );
      expect(chartAnimations, findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is JadeIcon && widget.glyph == JadeGlyph.focus,
        ),
        findsOneWidget,
      );

      await tester.tap(first);
      await tester.pump();
      final selectedAnimation = tester.widget<AnimatedContainer>(
        find.descendant(of: first, matching: find.byType(AnimatedContainer)),
      );
      expect(selectedAnimation.duration, AppMotion.micro);
      final selectedSemantics = tester.widgetList<Semantics>(
        find.descendant(of: first, matching: find.byType(Semantics)),
      );
      expect(
        selectedSemantics.any((widget) => widget.properties.selected == true),
        isTrue,
      );

      await pumpAt(
        const Size(320, 568),
        textScaler: const TextScaler.linear(2),
      );
      await tester.scrollUntilVisible(
        first,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      final compactFirstWidth = tester.getSize(first).width;
      await tester.scrollUntilVisible(
        second,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.getSize(second).width, compactFirstWidth);
      expect(compactFirstWidth, greaterThan(250));
      expect(tester.takeException(), isNull);

      await pumpAt(const Size(390, 844), reducedMotion: true);
      final reducedChartAnimations = tester
          .widgetList<TweenAnimationBuilder<double>>(
            find.byWidgetPredicate(
              (widget) => widget is TweenAnimationBuilder<double>,
            ),
          );
      expect(
        reducedChartAnimations
            .where((widget) => widget.tween.end != null)
            .every((widget) => widget.duration == Duration.zero),
        isTrue,
      );
      await tester.scrollUntilVisible(
        first,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(first);
      await tester.pump();
      expect(
        tester
            .widget<AnimatedContainer>(
              find.descendant(
                of: first,
                matching: find.byType(AnimatedContainer),
              ),
            )
            .duration,
        Duration.zero,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('scheduled focus choices wrap at narrow width and large text', (
    tester,
  ) async {
    final controller = await _createController();
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    await controller.addRecord(
      WorkspaceRecord(
        id: 'audit-pending-focus',
        kind: RecordKind.template,
        title: '跨多次实验的长名称定时专注预设',
        createdAt: _auditNow,
        updatedAt: _auditNow,
        data: {
          'recordType': 'focusPreset',
          'mode': 'custom',
          'minutes': 25,
          'scheduleMode': 'once',
          'pendingScheduledStartAt': _auditNow.toUtc().toIso8601String(),
        },
      ),
    );
    final pending = find.byKey(
      const ValueKey('pending-focus-audit-pending-focus'),
    );
    for (final brightness in [Brightness.light, Brightness.dark]) {
      tester.view.physicalSize = const Size(320, 568);
      await tester.pumpWidget(
        _host(
          FocusHubPage(controller: controller, showHeader: false),
          brightness: brightness,
          textScaler: const TextScaler.linear(2),
        ),
      );
      await tester.scrollUntilVisible(
        pending,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(pending, findsOneWidget);
      final row = tester.getRect(pending);
      final skip = tester.getRect(
        find.descendant(of: pending, matching: find.text('跳过')),
      );
      final start = tester.getRect(
        find.descendant(of: pending, matching: find.text('确认开始')),
      );
      expect(skip.left, greaterThanOrEqualTo(row.left));
      expect(start.right, lessThanOrEqualTo(row.right));
      expect(tester.takeException(), isNull);
      await Scrollable.ensureVisible(tester.element(pending), alignment: 0.2);
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/ui_audit/focus_pending_${brightness.name}_320x568.png',
        ),
      );
    }

    await tester.tap(find.descendant(of: pending, matching: find.text('跳过')));
    await tester.pump();
    expect(controller.pendingFocusPresets, isEmpty);
  });

  testWidgets(
    'a single focus preset expands and centers without spare column',
    (tester) async {
      final controller = await _createEmptyController();
      addTearDown(controller.dispose);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      await controller.addRecord(
        WorkspaceRecord(
          id: 'single-focus-preset',
          kind: RecordKind.template,
          title: '论文图参数复核',
          createdAt: _auditNow,
          updatedAt: _auditNow,
          data: const {
            'recordType': 'focusPreset',
            'mode': 'custom',
            'minutes': 45,
            'scheduleMode': 'none',
          },
        ),
      );
      final card = find.byKey(
        const ValueKey('focus-preset-single-focus-preset'),
      );

      tester.view.physicalSize = const Size(1200, 900);
      await tester.pumpWidget(
        _host(FocusHubPage(controller: controller, showHeader: false)),
      );
      await tester.pumpAndSettle();
      final desktop = tester.getRect(card);
      expect(desktop.width, 600);
      expect(desktop.center.dx, closeTo(600, 1));
      expect(tester.getRect(find.text('专注预设')).left, closeTo(desktop.left, 1));

      tester.view.physicalSize = const Size(320, 568);
      await tester.pumpWidget(
        _host(
          FocusHubPage(controller: controller, showHeader: false),
          textScaler: const TextScaler.linear(2),
        ),
      );
      await tester.scrollUntilVisible(
        card,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(card).width, closeTo(280, 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('focus rhythm animates new real sessions only after an update', (
    tester,
  ) async {
    final controller = await _createController();
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);

    Widget page({bool reducedMotion = false}) => _host(
      FocusHubPage(controller: controller, showHeader: false),
      disableAnimations: reducedMotion,
    );

    Future<void> addSession(int daysAgo, int minutes) => controller.addRecord(
      WorkspaceRecord(
        id: 'new-focus-session-$daysAgo',
        kind: RecordKind.focusSession,
        title: '真实专注记录',
        scheduledFor: _auditNow.subtract(Duration(days: daysAgo)),
        createdAt: _auditNow,
        updatedAt: _auditNow,
        data: {'seconds': minutes * 60},
      ),
    );

    double barHeight(int daysAgo) {
      final day = _auditNow.subtract(Duration(days: daysAgo));
      final key = ValueKey(
        'focus-bar-${DateTime(day.year, day.month, day.day).toIso8601String()}',
      );
      return tester
          .widget<FractionallySizedBox>(
            find.descendant(
              of: find.byKey(key),
              matching: find.byType(FractionallySizedBox),
            ),
          )
          .heightFactor!;
    }

    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    expect(barHeight(0), 1);
    await addSession(1, 10);
    await tester.pumpWidget(page());
    expect(barHeight(1), 0);
    await tester.pump(const Duration(milliseconds: 120));
    expect(barHeight(1), greaterThan(0));
    expect(barHeight(1), lessThan(0.4));
    await tester.pump(const Duration(milliseconds: 140));
    expect(barHeight(1), closeTo(0.4, 0.001));

    await tester.pumpWidget(page(reducedMotion: true));
    await addSession(2, 15);
    await tester.pumpWidget(page(reducedMotion: true));
    await tester.pump();
    expect(barHeight(2), closeTo(0.6, 0.001));
    expect(tester.takeException(), isNull);
  });

  testWidgets('focus controls stay on screen in short windows', (tester) async {
    final controller = await _createController();
    final focusTask = controller.focusTasks.firstOrNull;
    expect(focusTask, isNotNull);
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    for (final size in const [Size(320, 568), Size(390, 568), Size(800, 450)]) {
      for (final scale in const [1.0, 2.0]) {
        for (final task in [null, focusTask]) {
          tester.view.physicalSize = size;
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await tester.pumpWidget(
            _host(
              FocusPage(controller: controller, task: task),
              textScaler: TextScaler.linear(scale),
            ),
          );
          await tester.pumpAndSettle();
          for (final action in [
            find.widgetWithText(FilledButton, '开始专注'),
            find.widgetWithText(OutlinedButton, '完成本次专注'),
          ]) {
            expect(action, findsOneWidget);
            expect(
              tester.getRect(action).bottom,
              lessThanOrEqualTo(size.height),
              reason:
                  'Focus action is below $size at ${scale}x text '
                  'with ${task == null ? 'no task' : 'a task'}',
            );
          }
          expect(tester.takeException(), isNull);
        }
      }
    }
  });

  testWidgets('task groups build visible branches and collapse child tasks', (
    tester,
  ) async {
    final controller = await _createController(withRsip: true);
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(390, 568);
    tester.view.devicePixelRatio = 1;
    for (final reducedMotion in [false, true]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(
        _host(
          PlanPage(
            controller: controller,
            initialTab: PlanTab.groups,
            showHeader: false,
            showTabs: false,
          ),
          textScaler: const TextScaler.linear(2),
          disableAnimations: reducedMotion,
        ),
      );
      await tester.pumpAndSettle();
      final groupTitle = find.text('论文复核任务群');
      expect(groupTitle, findsOneWidget);
      expect(find.text('阅读角谱传播采样条件笔记'), findsNothing);
      await tester.ensureVisible(groupTitle);
      await tester.pumpAndSettle();
      await tester.tap(groupTitle);
      await tester.pumpAndSettle();
      expect(find.text('阅读角谱传播采样条件笔记'), findsOneWidget);
      final collapse = find.byTooltip('收起子任务');
      await tester.ensureVisible(collapse);
      await tester.tap(collapse);
      await tester.pumpAndSettle();
      expect(find.text('阅读角谱传播采样条件笔记'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('captures deep group drill paths in plan and project views', (
    tester,
  ) async {
    final controller = await _createController(withRsip: true);
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final project = controller.projects.first;
    final group = await controller.createTaskGroup(
      title: '图表核验分支',
      sequential: false,
      projectId: project.id,
    );
    const titles = [
      '论文图表复核',
      '测量图与单位',
      '图三坐标轴',
      '横轴采样尺度',
      '校验单位换算',
      '误差条计算',
      '确认最终图注',
    ];
    WorkspaceRecord? parent;
    for (final title in titles) {
      final task = WorkspaceRecord.create(
        kind: RecordKind.task,
        title: title,
        parentId: parent?.id,
        projectId: project.id,
      );
      await controller.addRecord(task);
      await controller.addTaskToGroup(task: task, group: group);
      parent = task;
    }
    for (final inProject in [false, true]) {
      for (final size in const [Size(390, 844), Size(1200, 900)]) {
        for (final brightness in Brightness.values) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          final page = inProject
              ? ProjectsPage(
                  controller: controller,
                  selectedProjectId: project.id,
                  initialTab: ProjectDetailTab.groups,
                  showHeader: false,
                  showTabs: false,
                )
              : PlanPage(
                  controller: controller,
                  initialTab: PlanTab.groups,
                  showHeader: false,
                  showTabs: false,
                );
          await tester.pumpWidget(_host(page, brightness: brightness));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('图表核验分支'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('图表核验分支'));
          await tester.pumpAndSettle();
          var drills = 0;
          while (find
                  .widgetWithText(ListTile, titles.last)
                  .evaluate()
                  .isEmpty &&
              drills < 3) {
            await tester.ensureVisible(find.byTooltip('进入子层'));
            await tester.pumpAndSettle();
            await tester.tap(find.byTooltip('进入子层'));
            await tester.pumpAndSettle();
            drills++;
          }
          expect(find.widgetWithText(ListTile, titles.last), findsOneWidget);
          await tester.ensureVisible(find.byTooltip('返回上一层'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              'goldens/ui_audit/groups_drill_${inProject ? 'project' : 'plan'}_${brightness.name}_${size.width.toInt()}x${size.height.toInt()}.png',
            ),
          );
        }
      }
    }
  });

  testWidgets('captures expanded task group branches at compact and wide sizes', (
    tester,
  ) async {
    final controller = await _createController(withRsip: true);
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in const [Size(390, 844), Size(1200, 900)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      for (final brightness in [Brightness.light, Brightness.dark]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pumpWidget(
          _host(
            PlanPage(
              controller: controller,
              initialTab: PlanTab.groups,
              showHeader: size.width >= AppBreakpoints.compact,
              showTabs: false,
            ),
            brightness: brightness,
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));
        final groupTitle = find.text('论文复核任务群');
        await tester.ensureVisible(groupTitle);
        await tester.pumpAndSettle();
        await tester.tap(groupTitle);
        await tester.pumpAndSettle();
        expect(find.text('阅读角谱传播采样条件笔记'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final dimensions = '${size.width.toInt()}x${size.height.toInt()}';
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/ui_audit/groups_expanded_${brightness.name}_$dimensions.png',
          ),
        );
      }
    }
  });

  testWidgets('project overview animates selection and changed progress only', (
    tester,
  ) async {
    final controller = await _createController();
    addTearDown(controller.dispose);
    final primary = controller.projects.first;
    final alternate = WorkspaceRecord.create(
      kind: RecordKind.project,
      title: '第二个项目',
    );
    await controller.addRecord(alternate);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(1200, 900);

    Widget page({bool reducedMotion = false}) => _host(
      ProjectsPage(
        controller: controller,
        initialTab: ProjectDetailTab.overview,
        showHeader: false,
      ),
      disableAnimations: reducedMotion,
    );
    final fadeFinder = find.byKey(const ValueKey('project-detail-fade'));
    double opacity() => tester.widget<FadeTransition>(fadeFinder).opacity.value;
    double progress() => tester
        .widget<LinearProgressIndicator>(
          find.descendant(
            of: find.byKey(const ValueKey('project-overview-progress')),
            matching: find.byType(LinearProgressIndicator),
          ),
        )
        .value!;

    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    expect(opacity(), 1);
    final originalProgress = progress();
    expect(originalProgress, greaterThan(0));
    expect(originalProgress, lessThan(1));

    await tester.tap(find.text(alternate.title).first);
    await tester.pump();
    expect(opacity(), 0);
    await tester.pump(const Duration(milliseconds: 90));
    expect(opacity(), greaterThan(0));
    expect(opacity(), lessThan(1));
    await tester.pump(const Duration(milliseconds: 90));
    expect(opacity(), 1);
    expect(progress(), 0);

    await tester.pumpWidget(page(reducedMotion: true));
    await tester.pumpAndSettle();
    await tester.tap(find.text(primary.title).first);
    await tester.pump();
    expect(opacity(), 1);
    expect(progress(), originalProgress);

    final unfinished = controller
        .projectTasks(primary.id)
        .firstWhere((task) => !task.isDone);
    await controller.updateRecord(unfinished.copyWith(status: WorkStatus.done));
    final changedTasks = controller.projectTasks(primary.id);
    final changedProgress =
        changedTasks.where((task) => task.isDone).length / changedTasks.length;
    await tester.pumpWidget(page());
    await tester.pump();
    expect(progress(), originalProgress);
    await tester.pump(const Duration(milliseconds: 120));
    expect(progress(), greaterThan(originalProgress));
    expect(progress(), lessThan(changedProgress));
    await tester.pump(const Duration(milliseconds: 120));
    expect(progress(), changedProgress);
    expect(tester.takeException(), isNull);
  });

  testWidgets('project overview shows real next task and milestone state', (
    tester,
  ) async {
    final controller = await _createController();
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(320, 568);
    final project = controller.projects.first;
    final earlierMilestone = WorkspaceRecord.create(
      kind: RecordKind.milestone,
      title: '完成复核草稿',
      dueAt: _auditNow.add(const Duration(days: 1)),
      projectId: project.id,
    );
    await controller.addRecord(earlierMilestone);
    Widget page() => _host(
      ProjectsPage(
        controller: controller,
        selectedProjectId: project.id,
        showHeader: false,
        showTabs: false,
      ),
      textScaler: const TextScaler.linear(2),
      disableAnimations: true,
    );
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    final overview = find.byKey(ValueKey('project-overview-${project.id}'));
    expect(
      find.descendant(of: overview, matching: find.text('核对采样间隔与单位')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: overview, matching: find.text('完成复核草稿')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await controller.updateRecord(
      earlierMilestone.copyWith(status: WorkStatus.cancelled),
    );
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: overview, matching: find.text('确认图轴单位')),
      findsOneWidget,
    );

    final pending = controller
        .recordsOf(RecordKind.milestone)
        .firstWhere((item) => item.title == '确认图轴单位');
    await controller.updateRecord(pending.copyWith(status: WorkStatus.done));
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: overview, matching: find.text('最近达成')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: overview, matching: find.text('确认图轴单位')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('project board uses actual detail width and one compact lane', (
    tester,
  ) async {
    final controller = await _createController();
    addTearDown(controller.dispose);
    final project = controller.projects.first;
    await controller.addRecord(
      WorkspaceRecord.create(
        kind: RecordKind.task,
        title: '复核图表与统计输出',
        status: WorkStatus.doing,
        projectId: project.id,
      ),
    );
    for (final entry in const [
      (WorkStatus.todo, '待办：核对实验论文中所有采样条件、图轴单位和误差线说明是否完整一致'),
      (WorkStatus.doing, '进行中：逐项复核传播距离、采样间隔与图注来源并记录修订依据'),
      (WorkStatus.done, '已完成：整理首轮测量结果并归档可追溯的数据处理记录'),
    ]) {
      await controller.addRecord(
        WorkspaceRecord.create(
          kind: RecordKind.task,
          title: entry.$2,
          status: entry.$1,
          projectId: project.id,
        ),
      );
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    for (final brightness in Brightness.values) {
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpWidget(
        _host(
          ProjectsPage(
            controller: controller,
            initialTab: ProjectDetailTab.tasks,
            showHeader: false,
            showTabs: false,
          ),
          brightness: brightness,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('清单视图'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('看板视图').last);
      await tester.pumpAndSettle();
      expect(find.byType(ChoiceChip), findsNWidgets(3));
      expect(find.byType(LongPressDraggable<WorkspaceRecord>), findsNothing);
      expect(find.text('整理实验数据与误差记录'), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, '进行中 2'));
      await tester.pumpAndSettle();
      expect(find.text('复核图表与统计输出'), findsOneWidget);
      expect(find.textContaining('进行中：逐项复核'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/ui_audit/projects_board_compact_${brightness.name}.png',
        ),
      );

      tester.view.physicalSize = const Size(1200, 900);
      await tester.pumpAndSettle();
      expect(find.byType(ChoiceChip), findsNWidgets(3));
      expect(find.byType(LongPressDraggable<WorkspaceRecord>), findsNothing);
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(1440, 900);
      await tester.pumpAndSettle();
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.byType(LongPressDraggable<WorkspaceRecord>), findsWidgets);
      expect(find.text('整理实验数据与误差记录'), findsOneWidget);
      expect(find.text('复核图表与统计输出'), findsOneWidget);
      expect(find.textContaining('待办：核对实验论文'), findsOneWidget);
      expect(find.textContaining('进行中：逐项复核'), findsOneWidget);
      expect(find.textContaining('已完成：整理首轮'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/ui_audit/projects_board_wide_${brightness.name}.png',
        ),
      );
      if (brightness == Brightness.light) {
        final source = find.byType(LongPressDraggable<WorkspaceRecord>).first;
        final movedTask = tester
            .widget<LongPressDraggable<WorkspaceRecord>>(source)
            .data!;
        final originalStatus = movedTask.status;
        expect(originalStatus, WorkStatus.todo);
        final target = find.byType(DragTarget<WorkspaceRecord>).at(1);
        final gesture = await tester.startGesture(tester.getCenter(source));
        await tester.pump(const Duration(milliseconds: 600));
        await gesture.moveBy(const Offset(0, 12));
        await tester.pump(const Duration(milliseconds: 50));
        await gesture.moveTo(tester.getCenter(target));
        await tester.pump(const Duration(milliseconds: 100));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(controller.latestRecordById(movedTask).status, WorkStatus.doing);
        await tester.tap(find.text('撤销'));
        await tester.pumpAndSettle();
        expect(controller.latestRecordById(movedTask).status, originalStatus);
        expect(tester.takeException(), isNull);
      }
      tester.view.physicalSize = const Size(320, 568);
      await tester.pumpWidget(
        _host(
          ProjectsPage(
            controller: controller,
            initialTab: ProjectDetailTab.tasks,
            showHeader: false,
            showTabs: false,
          ),
          brightness: brightness,
          textScaler: const TextScaler.linear(2),
          disableAnimations: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ChoiceChip), findsNWidgets(3));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('project groups keep parent branches usable in short windows', (
    tester,
  ) async {
    final controller = await _createController(withRsip: true);
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      _host(
        ProjectsPage(
          controller: controller,
          initialTab: ProjectDetailTab.groups,
          showHeader: false,
          showTabs: false,
        ),
        textScaler: const TextScaler.linear(2),
        disableAnimations: true,
      ),
    );
    await tester.pumpAndSettle();
    final group = find.text('论文复核任务群');
    await tester.ensureVisible(group);
    await tester.pumpAndSettle();
    await tester.tap(group);
    await tester.pumpAndSettle();
    expect(find.text('核对采样间隔与单位'), findsOneWidget);
    expect(find.text('阅读角谱传播采样条件笔记'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byTooltip('收起子任务'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('收起子任务'));
    await tester.pumpAndSettle();
    expect(find.text('阅读角谱传播采样条件笔记'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('captures project group move selection and result', (
    tester,
  ) async {
    final controller = await _createController(withRsip: true);
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final project = controller.projects.first;
    final source = await controller.createTaskGroup(
      title: '图注核验',
      sequential: false,
      projectId: project.id,
    );
    final target = await controller.createTaskGroup(
      title: '图注归档',
      sequential: false,
      projectId: project.id,
    );
    final task = WorkspaceRecord.create(
      kind: RecordKind.task,
      title: '确认图注内容',
      projectId: project.id,
    );
    await controller.addRecord(task);
    await controller.addTaskToGroup(task: task, group: source);
    for (final size in const [Size(320, 568), Size(1200, 900)]) {
      for (final brightness in Brightness.values) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pumpWidget(
          _host(
            ProjectsPage(
              controller: controller,
              selectedProjectId: project.id,
              initialTab: ProjectDetailTab.groups,
              showHeader: false,
              showTabs: false,
            ),
            brightness: brightness,
            textScaler: size.width == 320
                ? const TextScaler.linear(2)
                : TextScaler.noScaling,
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('图注核验'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('图注核验'));
        await tester.pumpAndSettle();
        final menu = find.descendant(
          of: find.widgetWithText(ListTile, task.title),
          matching: find.byType(PopupMenuButton<String>),
        );
        await tester.ensureVisible(menu);
        await tester.pumpAndSettle();
        await tester.tap(menu);
        await tester.pumpAndSettle();
        await tester.tap(find.text('移到其他任务群'));
        await tester.pumpAndSettle();
        final targetChoice = find.widgetWithText(
          RadioListTile<String>,
          target.title,
        );
        await tester.scrollUntilVisible(
          targetChoice,
          100,
          scrollable: find
              .descendant(
                of: find.byType(AlertDialog),
                matching: find.byType(Scrollable),
              )
              .last,
          maxScrolls: 20,
        );
        await tester.pumpAndSettle();
        await tester.tap(targetChoice);
        await tester.pumpAndSettle();
        final suffix =
            '${brightness.name}_${size.width.toInt()}x${size.height.toInt()}';
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/ui_audit/project_group_move_picker_$suffix.png',
          ),
        );
        await tester.tap(find.text('移动'));
        await tester.pumpAndSettle();
        expect(controller.groupMembers(target.id).single.id, task.id);
        if (size.width == 320) {
          expect(
            tester.getRect(find.widgetWithText(ListTile, task.title)).bottom,
            lessThanOrEqualTo(tester.getTopLeft(find.byType(SnackBar)).dy),
          );
        }
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/ui_audit/project_group_move_result_$suffix.png',
          ),
        );
        await tester.tap(find.text('撤销'));
        await tester.pumpAndSettle();
        expect(controller.groupMembers(source.id).single.id, task.id);
      }
    }
  });

  testWidgets('captures project group branches at compact and wide sizes', (
    tester,
  ) async {
    final controller = await _createController(withRsip: true);
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    for (final size in const [Size(390, 844), Size(1200, 900)]) {
      for (final brightness in Brightness.values) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          _host(
            ProjectsPage(
              controller: controller,
              initialTab: ProjectDetailTab.groups,
              showHeader: false,
              showTabs: false,
            ),
            brightness: brightness,
          ),
        );
        await tester.pumpAndSettle();
        final group = find.text('论文复核任务群');
        await tester.ensureVisible(group);
        await tester.pumpAndSettle();
        await tester.tap(group);
        await tester.pumpAndSettle();
        expect(find.text('阅读角谱传播采样条件笔记'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final dimensions = '${size.width.toInt()}x${size.height.toInt()}';
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/ui_audit/projects_groups_expanded_${brightness.name}_$dimensions.png',
          ),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
  });

  testWidgets('project milestones show dates links and reversible completion', (
    tester,
  ) async {
    final controller = await _createController();
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    final milestone = controller
        .recordsOf(RecordKind.milestone)
        .firstWhere((record) => record.title == '确认图轴单位');
    for (final brightness in Brightness.values) {
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpWidget(
        _host(
          ProjectsPage(
            controller: controller,
            initialTab: ProjectDetailTab.milestones,
            showHeader: false,
            showTabs: false,
          ),
          brightness: brightness,
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('确认图轴单位').last);
      await tester.pumpAndSettle();
      expect(find.text('关联任务 1'), findsOneWidget);
      expect(find.text('整理首批测量结果'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/ui_audit/projects_milestones_compact_${brightness.name}.png',
        ),
      );
      if (brightness == Brightness.light) {
        await tester.ensureVisible(find.text('标记达成'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('标记达成'));
        await tester.pumpAndSettle();
        expect(controller.latestRecordById(milestone).isDone, isTrue);
        await tester.tap(find.text('撤销'));
        await tester.pumpAndSettle();
        expect(controller.latestRecordById(milestone).isDone, isFalse);
      }
      tester.view.physicalSize = const Size(1200, 900);
      await tester.pumpAndSettle();
      expect(find.text('当前节点'), findsOneWidget);
      expect(find.text('关联任务 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/ui_audit/projects_milestones_wide_${brightness.name}.png',
        ),
      );
      tester.view.physicalSize = const Size(320, 568);
      await tester.pumpWidget(
        _host(
          ProjectsPage(
            controller: controller,
            initialTab: ProjectDetailTab.milestones,
            showHeader: false,
            showTabs: false,
          ),
          brightness: brightness,
          textScaler: const TextScaler.linear(2),
          disableAnimations: true,
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('确认图轴单位').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets(
    'project milestone animations stay local and honor reduced motion',
    (tester) async {
      final controller = await _createController();
      addTearDown(controller.dispose);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(390, 844);
      final project = controller.projects.first;
      final milestone = controller
          .recordsOf(RecordKind.milestone)
          .firstWhere((record) => record.title == '确认图轴单位');
      var reducedMotion = false;
      Widget page() => _host(
        ProjectsPage(
          controller: controller,
          selectedProjectId: project.id,
          initialTab: ProjectDetailTab.milestones,
          showHeader: false,
          showTabs: false,
        ),
        disableAnimations: reducedMotion,
      );
      final stateFinder = find.byKey(
        ValueKey('milestone-state-${milestone.id}'),
      );
      double completionOpacity() => tester
          .widget<Opacity>(
            find.descendant(of: stateFinder, matching: find.byType(Opacity)),
          )
          .opacity;

      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      expect(completionOpacity(), 0);
      await controller.updateRecord(
        milestone.copyWith(status: WorkStatus.done),
      );
      await tester.pumpWidget(page());
      await tester.pump();
      expect(completionOpacity(), 0);
      await tester.pump(const Duration(milliseconds: 120));
      expect(completionOpacity(), greaterThan(0));
      expect(completionOpacity(), lessThan(1));
      await tester.pump(const Duration(milliseconds: 120));
      expect(completionOpacity(), 1);

      final added = WorkspaceRecord.create(
        kind: RecordKind.milestone,
        title: '提交最终复核结果',
        dueAt: _auditNow.add(const Duration(days: 14)),
        projectId: project.id,
      );
      await controller.addRecord(added);
      await tester.pumpWidget(page());
      final addedFinder = find.byKey(ValueKey('milestone-node-${added.id}'));
      double entranceOpacity() => tester
          .widget<FadeTransition>(
            find.descendant(
              of: addedFinder,
              matching: find.byType(FadeTransition),
            ),
          )
          .opacity
          .value;
      expect(entranceOpacity(), 0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      expect(entranceOpacity(), greaterThan(0));
      expect(entranceOpacity(), lessThan(1));
      await tester.pump(const Duration(milliseconds: 90));
      expect(entranceOpacity(), 1);

      reducedMotion = true;
      final reducedAdded = WorkspaceRecord.create(
        kind: RecordKind.milestone,
        title: '减少动效新增节点',
        dueAt: _auditNow.subtract(const Duration(days: 30)),
        projectId: project.id,
      );
      await controller.addRecord(reducedAdded);
      await tester.pumpWidget(page());
      await tester.pump();
      final reducedFinder = find.byKey(
        ValueKey('milestone-node-${reducedAdded.id}'),
      );
      expect(
        tester
            .widget<FadeTransition>(
              find.descendant(
                of: reducedFinder,
                matching: find.byType(FadeTransition),
              ),
            )
            .opacity
            .value,
        1,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('milestone editor saves project task associations', (
    tester,
  ) async {
    final controller = await _createController();
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    final milestone = controller
        .recordsOf(RecordKind.milestone)
        .firstWhere((record) => record.title == '确认图轴单位');
    await controller.addRecord(
      WorkspaceRecord.create(kind: RecordKind.task, title: '外部项目排程'),
    );
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showRecordEditor(
              context,
              controller,
              kind: RecordKind.milestone,
              record: milestone,
            ),
            child: const Text('打开里程碑编辑器'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开里程碑编辑器'));
    await tester.pumpAndSettle();
    expect(find.text('选择关联任务（1）'), findsOneWidget);
    await tester.ensureVisible(find.text('选择关联任务（1）'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('选择关联任务（1）'));
    await tester.pumpAndSettle();
    expect(find.text('外部项目排程'), findsNothing);
    final other = find.widgetWithText(CheckboxListTile, '阅读角谱传播采样条件笔记');
    expect(tester.widget<CheckboxListTile>(other).value, isFalse);
    await tester.tap(other);
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(find.text('选择关联任务（2）'), findsOneWidget);
    await tester.tap(find.text('取消').last);
    await tester.pumpAndSettle();
    expect(find.text('保存修改？'), findsOneWidget);
    await tester.tap(find.text('继续编辑'));
    await tester.pumpAndSettle();
    expect(find.text('选择关联任务（2）'), findsOneWidget);
    await tester.tap(find.text('保存修改'));
    await tester.pumpAndSettle();
    final saved = controller.latestRecordById(milestone);
    expect((saved.data['relatedTaskIds'] as List<dynamic>).length, 2);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(1200, 900);
    await tester.pumpWidget(
      _host(
        ProjectsPage(
          controller: controller,
          initialTab: ProjectDetailTab.milestones,
          showHeader: false,
          showTabs: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('关联任务 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('project icon choices wrap and persist in a narrow window', (
    tester,
  ) async {
    final controller = await _createController();
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    final project = controller.projects.first;
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showRecordEditor(
              context,
              controller,
              kind: RecordKind.project,
              record: project,
            ),
            child: const Text('编辑项目图标'),
          ),
        ),
        textScaler: const TextScaler.linear(2),
        disableAnimations: true,
      ),
    );
    await tester.tap(find.text('编辑项目图标'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('project-icon-options')),
        matching: find.byType(ChoiceChip),
      ),
      findsNWidgets(8),
    );
    final eco = find.byKey(const ValueKey('project-icon-eco'));
    await tester.ensureVisible(eco);
    await tester.pumpAndSettle();
    await tester.tap(eco);
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(eco).selected, isTrue);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('保存修改'));
    await tester.pumpAndSettle();
    expect(controller.latestRecordById(project).data['projectIcon'], 'eco');
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(1200, 900);
    await tester.pumpWidget(
      _host(
        ProjectsPage(
          controller: controller,
          selectedProjectId: project.id,
          showHeader: false,
          showTabs: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.eco_outlined), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long project titles reflow beside the icon', (tester) async {
    final controller = await _createController();
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    final project = controller.projects.first;
    await controller.updateRecord(
      project.copyWith(title: '长期项目：核对实验论文、整理采样图轴与里程碑，并跟进下一阶段的全部工作事项'),
    );
    for (final brightness in Brightness.values) {
      for (final size in const [
        Size(320, 568),
        Size(800, 450),
        Size(1440, 900),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          _host(
            ProjectsPage(
              controller: controller,
              selectedProjectId: project.id,
              showHeader: false,
              showTabs: false,
            ),
            brightness: brightness,
            textScaler: size.width == 320
                ? const TextScaler.linear(2)
                : const TextScaler.linear(1),
            disableAnimations: true,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
  });

  testWidgets('milestone task picker stays usable at 320dp and 200% text', (
    tester,
  ) async {
    final controller = await _createController();
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    final milestone = controller
        .recordsOf(RecordKind.milestone)
        .firstWhere((record) => record.title == '确认图轴单位');
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showRecordEditor(
              context,
              controller,
              kind: RecordKind.milestone,
              record: milestone,
            ),
            child: const Text('打开里程碑编辑器'),
          ),
        ),
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.tap(find.text('打开里程碑编辑器'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('选择关联任务（1）'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('选择关联任务（1）'));
    await tester.pumpAndSettle();
    expect(find.text('关联任务'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('取消').last);
    await tester.pumpAndSettle();
    expect(find.text('选择关联任务（1）'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('project notes and reviews reflow and open the correct editor', (
    tester,
  ) async {
    final controller = await _createController();
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    final review = controller.periodReviews.single;
    WorkspaceRecord? openedReview;

    Future<void> showKnowledge({
      required Size size,
      required Brightness brightness,
      TextScaler textScaler = TextScaler.noScaling,
    }) async {
      tester.view.physicalSize = size;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(
        _host(
          ProjectsPage(
            controller: controller,
            initialTab: ProjectDetailTab.notes,
            showHeader: false,
            showTabs: false,
            onOpenReview: (value) => openedReview = value,
          ),
          brightness: brightness,
          textScaler: textScaler,
          disableAnimations: true,
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('论文复核周回顾').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    for (final brightness in Brightness.values) {
      for (final size in [const Size(390, 844), const Size(1200, 900)]) {
        await showKnowledge(size: size, brightness: brightness);
        expect(find.widgetWithText(Card, '角谱传播采样检查清单'), findsOneWidget);
        expect(find.widgetWithText(Card, '论文复核周回顾'), findsOneWidget);
        final dimensions = '${size.width.toInt()}x${size.height.toInt()}';
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/ui_audit/projects_knowledge_${brightness.name}_$dimensions.png',
          ),
        );
        await tester.tap(find.widgetWithText(ChoiceChip, '回顾 1'));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(Card, '角谱传播采样检查清单'), findsNothing);
        expect(find.widgetWithText(Card, '论文复核周回顾'), findsOneWidget);
        await tester.tap(find.widgetWithText(Card, '论文复核周回顾'));
        await tester.pumpAndSettle();
        expect(openedReview?.id, review.id);
        expect(find.text('编辑笔记'), findsNothing);

        await tester.tap(find.widgetWithText(ChoiceChip, '笔记 1'));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(Card, '论文复核周回顾'), findsNothing);
        final noteCard = find.widgetWithText(Card, '角谱传播采样检查清单');
        expect(noteCard, findsOneWidget);
        await tester.ensureVisible(noteCard);
        await tester.pumpAndSettle();
        await tester.tap(noteCard);
        await tester.pumpAndSettle();
        expect(find.text('编辑笔记'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
      }
    }

    for (final size in [const Size(320, 568), const Size(800, 450)]) {
      await showKnowledge(
        size: size,
        brightness: Brightness.light,
        textScaler: const TextScaler.linear(2),
      );
      expect(find.widgetWithText(Card, '论文复核周回顾'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('project detail lists build rows as they scroll', (tester) async {
    final controller = await _createController();
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    final project = controller.projects.first;
    for (var index = 0; index < 120; index++) {
      await controller.addRecord(
        WorkspaceRecord.create(
          kind: RecordKind.task,
          title: '批量任务 $index',
          projectId: project.id,
        ),
      );
      await controller.addRecord(
        WorkspaceRecord.create(
          kind: RecordKind.note,
          title: '批量笔记 $index',
          projectId: project.id,
        ),
      );
      await controller.addRecord(
        WorkspaceRecord.create(
          kind: RecordKind.milestone,
          title: '批量里程碑 $index',
          projectId: project.id,
          dueAt: _auditNow.add(Duration(days: index + 10)),
        ),
      );
    }

    await tester.pumpWidget(
      _host(
        ProjectsPage(
          controller: controller,
          initialTab: ProjectDetailTab.tasks,
          showHeader: false,
        ),
        disableAnimations: true,
      ),
    );
    await tester.pumpAndSettle();
    final taskList = find.byKey(
      const PageStorageKey('project-task-list-scroll'),
    );
    expect(taskList, findsOneWidget);
    expect(find.text('批量任务 119'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('批量任务 119'),
      500,
      scrollable: find.descendant(
        of: taskList,
        matching: find.byType(Scrollable),
      ),
      maxScrolls: 80,
    );
    expect(find.text('批量任务 119'), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(
      _host(
        ProjectsPage(
          key: const ValueKey('board-page'),
          controller: controller,
          initialTab: ProjectDetailTab.tasks,
          showHeader: false,
        ),
        disableAnimations: true,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('清单视图'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('看板视图').last);
    await tester.pumpAndSettle();
    final boardList = find.byKey(
      const PageStorageKey('project-kanban-scroll-todo'),
    );
    expect(boardList, findsOneWidget);
    expect(find.text('批量任务 119'), findsNothing);
    await tester.ensureVisible(boardList);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('批量任务 119'),
      500,
      scrollable: find.descendant(
        of: boardList,
        matching: find.byType(Scrollable),
      ),
      maxScrolls: 80,
    );
    expect(find.text('批量任务 119'), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(1200, 900);

    await tester.pumpWidget(
      _host(
        ProjectsPage(
          key: const ValueKey('knowledge-page'),
          controller: controller,
          initialTab: ProjectDetailTab.notes,
          showHeader: false,
        ),
        disableAnimations: true,
      ),
    );
    await tester.pumpAndSettle();
    final notesList = find.byKey(
      const PageStorageKey('project-knowledge-scroll'),
    );
    expect(notesList, findsOneWidget);
    expect(find.text('批量笔记 0'), findsNothing);
    await tester.ensureVisible(notesList);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('批量笔记 0'),
      500,
      scrollable: find.descendant(
        of: notesList,
        matching: find.byType(Scrollable),
      ),
      maxScrolls: 80,
    );
    expect(find.text('批量笔记 0'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      _host(
        ProjectsPage(
          key: const ValueKey('milestone-page'),
          controller: controller,
          initialTab: ProjectDetailTab.milestones,
          showHeader: false,
        ),
        disableAnimations: true,
      ),
    );
    await tester.pumpAndSettle();
    final milestoneList = find.byKey(
      const PageStorageKey('project-milestone-scroll'),
    );
    expect(milestoneList, findsOneWidget);
    expect(find.text('批量里程碑 119'), findsNothing);
    await tester.ensureVisible(milestoneList);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('批量里程碑 119'),
      500,
      scrollable: find.descendant(
        of: milestoneList,
        matching: find.byType(Scrollable),
      ),
      maxScrolls: 100,
    );
    expect(find.text('批量里程碑 119'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('project index builds only visible rows and reaches late items', (
    tester,
  ) async {
    final controller = await _createController();
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(1200, 900);
    for (var index = 0; index < 120; index++) {
      await controller.addRecord(
        WorkspaceRecord.create(
          kind: RecordKind.project,
          title: '性能项目 ${index.toString().padLeft(3, '0')}',
        ),
      );
    }
    await tester.pumpWidget(
      _host(
        ProjectsPage(
          controller: controller,
          showHeader: false,
          showTabs: false,
        ),
        disableAnimations: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('性能项目 119'), findsNothing);
    final indexList = find.byKey(const PageStorageKey('project-index-scroll'));
    expect(indexList, findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('性能项目 119'),
      500,
      scrollable: find.descendant(
        of: indexList,
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('性能项目 119'), findsOneWidget);
    await tester.tap(find.text('性能项目 119'));
    await tester.pumpAndSettle();
    expect(find.text('性能项目 119'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('today keeps a long task list reachable in a compact window', (
    tester,
  ) async {
    final controller = await _createController();
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    for (var index = 0; index < 120; index++) {
      await controller.addRecord(
        WorkspaceRecord.create(
          kind: RecordKind.task,
          title: '今日批量任务 $index',
          scheduledFor: _auditNow,
        ),
      );
    }
    await controller.startToday(
      commitments: controller.todayTasks
          .where((task) => !task.isDone)
          .take(3)
          .toList(),
      plannedHabits: const [],
    );
    await tester.pumpWidget(
      _host(TodayPage(controller: controller), disableAnimations: true),
    );
    await tester.pumpAndSettle();
    final builtRows = find.byWidgetPredicate((widget) {
      final key = widget.key;
      return key is ValueKey<String> &&
          key.value.startsWith('today-task-') &&
          key.value != 'today-task-check' &&
          key.value != 'today-task-unchecked';
    });
    expect(builtRows.evaluate().length, lessThan(20));
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    final todayList = find.byKey(const PageStorageKey('today-task-scroll-今日'));
    expect(todayList, findsOneWidget);
    expect(find.text('今日批量任务 119'), findsNothing);
    await tester.ensureVisible(todayList);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('今日批量任务 119'),
      500,
      scrollable: find.descendant(
        of: todayList,
        matching: find.byType(Scrollable),
      ),
      maxScrolls: 80,
    );
    expect(find.text('今日批量任务 119'), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(320, 568);
    await tester.pumpWidget(
      _host(
        TodayPage(
          key: const ValueKey('today-large-text'),
          controller: controller,
        ),
        textScaler: const TextScaler.linear(2),
        disableAnimations: true,
      ),
    );
    await tester.pumpAndSettle();
    final largeTextList = find.byKey(
      const PageStorageKey('today-task-scroll-今日'),
    );
    await tester.ensureVisible(largeTextList);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('今日批量任务 119'),
      450,
      scrollable: find.descendant(
        of: largeTextList,
        matching: find.byType(Scrollable),
      ),
      maxScrolls: 160,
    );
    expect(find.text('今日批量任务 119'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('goal tree keeps late branches reachable at large text', (
    tester,
  ) async {
    final controller = await _createEmptyController();
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    for (var index = 0; index < 120; index++) {
      await controller.addRecord(
        WorkspaceRecord.create(
          kind: RecordKind.goal,
          title: '批量目标 $index',
          dueAt: _auditNow.add(Duration(days: index)),
        ),
      );
    }
    await tester.pumpWidget(
      _host(
        GoalsPage(controller: controller),
        textScaler: const TextScaler.linear(2),
        disableAnimations: true,
      ),
    );
    await tester.pumpAndSettle();
    final goals = find.byKey(const PageStorageKey('goal-branch-scroll'));
    await tester.scrollUntilVisible(
      goals,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    expect(goals, findsOneWidget);
    expect(find.text('批量目标 119'), findsNothing);
    await tester.ensureVisible(goals);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('批量目标 119'),
      500,
      scrollable: find
          .descendant(of: goals, matching: find.byType(Scrollable))
          .first,
      maxScrolls: 100,
    );
    expect(find.text('批量目标 119'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'goal content fills compact windows and caps wide reading width',
    (tester) async {
      final controller = await _createController();
      addTearDown(controller.dispose);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 900);
      await tester.pumpWidget(_host(GoalsPage(controller: controller)));
      await tester.pumpAndSettle();

      for (final (size, expectedBandWidth) in [
        (const Size(1440, 900), 920.0),
        (const Size(1200, 900), 920.0),
        (const Size(800, 450), 760.0),
        (const Size(390, 844), 350.0),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.byType(LogSurface).first).width,
          expectedBandWidth,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('habit matrix reaches late rows without building every card', (
    tester,
  ) async {
    final controller = await _createEmptyController();
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    for (var index = 0; index < 120; index++) {
      await controller.addRecord(
        WorkspaceRecord.create(kind: RecordKind.habit, title: '批量习惯 $index'),
      );
    }
    for (final (size, scale) in [
      (const Size(390, 844), 1.0),
      (const Size(320, 568), 2.0),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        _host(
          HabitsPage(
            key: ValueKey('habits-${size.width}-$scale'),
            controller: controller,
          ),
          textScaler: TextScaler.linear(scale),
          disableAnimations: true,
        ),
      );
      await tester.pumpAndSettle();
      final matrix = find.byKey(const PageStorageKey('habit-matrix-scroll'));
      expect(matrix, findsOneWidget);
      expect(find.text('批量习惯 119'), findsNothing);
      await tester.ensureVisible(matrix);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('批量习惯 119'),
        500,
        scrollable: find
            .descendant(of: matrix, matching: find.byType(Scrollable))
            .first,
        maxScrolls: 100,
      );
      expect(find.text('批量习惯 119'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('habit month expands without losing the compact overview', (
    tester,
  ) async {
    final controller = await _createController();
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    for (final brightness in Brightness.values) {
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(
        _host(
          HabitsPage(controller: controller, showHeader: false),
          brightness: brightness,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('近两周 · 今天可点按修改'), findsOneWidget);
      await tester.tap(find.text('展开整月'));
      await tester.pumpAndSettle();
      expect(find.text('左右滑动查看整月 · 今天可点按修改'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/ui_audit/habits_month_expanded_${brightness.name}_390x844.png',
        ),
      );
    }
  });

  testWidgets(
    'growth month grid uses available width and keeps compact scroll',
    (tester) async {
      final controller = await _createController();
      addTearDown(controller.dispose);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 900);
      await tester.pumpWidget(
        _host(GrowthPage(controller: controller, now: _auditNow)),
      );
      await tester.pumpAndSettle();

      for (final (size, minimumSlot, minimumRightEdge) in [
        (const Size(1200, 900), 30.0, 1140.0),
        (const Size(800, 450), 20.0, 740.0),
        (const Size(1440, 900), 36.0, 1300.0),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.byKey(const ValueKey('growth-day:1'))).width,
          greaterThan(minimumSlot),
        );
        expect(
          tester.getRect(find.byKey(const ValueKey('growth-day:31'))).right,
          greaterThan(minimumRightEdge),
        );
        expect(tester.takeException(), isNull);
      }

      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('growth-day:1')), findsNothing);
      await tester.ensureVisible(find.text('本月执行账本'));
      await tester.tap(find.text('本月执行账本'));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const ValueKey('growth-day:1'))).width,
        20,
      );
      expect(find.text('左右滑动查看整月'), findsOneWidget);
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(320, 568);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(
        _host(
          GrowthPage(controller: controller, now: _auditNow, showHeader: false),
          textScaler: const TextScaler.linear(2),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('本月执行账本'));
      await tester.tap(find.text('本月执行账本'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('growth-day:31')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('initialization error keeps details optional and retry local', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var retries = 0;
    Widget errorView({bool retrying = false, bool retried = false}) => _host(
      InitializationErrorView(
        message: '数据库访问失败：模拟详细路径与异常信息',
        onRetry: () => retries++,
        retrying: retrying,
        retryAttempted: retried,
      ),
      textScaler: const TextScaler.linear(2),
    );
    await tester.pumpWidget(errorView());
    await tester.pumpAndSettle();
    expect(find.text('数据库访问失败：模拟详细路径与异常信息'), findsNothing);
    final details = find.text('查看错误详情');
    await tester.ensureVisible(details);
    await tester.tap(details);
    await tester.pumpAndSettle();
    expect(find.text('数据库访问失败：模拟详细路径与异常信息'), findsOneWidget);
    await tester.ensureVisible(find.text('重试载入'));
    await tester.tap(find.text('重试载入'));
    expect(retries, 1);
    await tester.pumpWidget(errorView(retrying: true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.pumpWidget(errorView(retried: true));
    await tester.pumpAndSettle();
    expect(find.textContaining('重试仍未成功'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed database initialization stays recoverable after retry', (
    tester,
  ) async {
    final blockedPath = io.Directory.systemTemp.createTempSync(
      'workbench-initialization-error-',
    );
    addTearDown(() => blockedPath.deleteSync(recursive: true));
    tester.view.physicalSize = const Size(390, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      PersonalWorkbenchApp(databasePath: blockedPath.path),
    );
    for (
      var attempt = 0;
      attempt < 20 && find.text('工作台初始化失败').evaluate().isEmpty;
      attempt++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    expect(find.text('工作台初始化失败'), findsOneWidget);
    await tester.tap(find.text('重试载入'));
    await tester.pump();
    expect(find.text('正在重试'), findsOneWidget);
    for (
      var attempt = 0;
      attempt < 20 && find.textContaining('重试仍未成功').evaluate().isEmpty;
      attempt++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    expect(find.textContaining('重试仍未成功'), findsOneWidget);
    expect(find.text('正在重试'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('theme transition follows the system motion preference', (
    tester,
  ) async {
    final blockedPath = io.Directory.systemTemp.createTempSync(
      'workbench-theme-motion-',
    );
    addTearDown(() => blockedPath.deleteSync(recursive: true));
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      PersonalWorkbenchApp(databasePath: blockedPath.path),
    );
    expect(
      tester
          .widget<MaterialApp>(find.byType(MaterialApp))
          .themeAnimationDuration,
      const Duration(milliseconds: 180),
    );
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeAnimationStyle,
      isNull,
    );

    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: true);
    await tester.pump();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeAnimationStyle,
      AnimationStyle.noAnimation,
    );
    tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
    await tester.pump();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeAnimationStyle,
      isNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('captures initialization error in both themes and window sizes', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in const [Size(390, 568), Size(1200, 900)]) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        final dimensions = '${size.width.toInt()}x${size.height.toInt()}';
        await _capture(
          tester,
          'initialization_error_${brightness.name}_$dimensions',
          InitializationErrorView(message: '数据库访问失败：模拟错误详情', onRetry: () {}),
          size: size,
          brightness: brightness,
        );
      }
    }
    for (final brightness in [Brightness.light, Brightness.dark]) {
      await _capture(
        tester,
        'initialization_retrying_${brightness.name}_390x568',
        InitializationErrorView(
          message: '数据库访问失败：模拟错误详情',
          onRetry: () {},
          retrying: true,
        ),
        size: const Size(390, 568),
        brightness: brightness,
        disableAnimations: true,
      );
    }
  });

  testWidgets(
    'markdown drafts remain editable and saveable in short windows with large text',
    (tester) async {
      final controller = await _createController();
      addTearDown(controller.dispose);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(800, 450);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showMarkdownNoteEditor(context, controller),
              child: const Text('打开笔记编辑器'),
            ),
          ),
          textScaler: TextScaler.linear(2),
        ),
      );
      await tester.tap(find.text('打开笔记编辑器'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '缩放窗口中的笔记草稿');
      await tester.enterText(
        find.byType(TextField).last,
        '# 完整正文\n调整窗口大小后仍可保存。',
      );
      for (final size in const [
        Size(320, 568),
        Size(1440, 500),
        Size(800, 450),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        final save = find.widgetWithText(FilledButton, '保存');
        expect(save.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();
      final saved = controller
          .recordsOf(RecordKind.note)
          .singleWhere((note) => note.title == '缩放窗口中的笔记草稿');
      expect(saved.body, '# 完整正文\n调整窗口大小后仍可保存。');
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('all surfaces fit the actual window content after navigation', (
    tester,
  ) async {
    final controller = await _createController(withRsip: true);
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final surface in _auditSurfaces(controller)) {
      for (final brightness in Brightness.values) {
        for (final size in const [
          Size(320, 568),
          Size(390, 568),
          Size(700, 420),
          Size(767, 900),
          Size(768, 900),
          Size(800, 450),
          Size(1024, 600),
          Size(1200, 700),
          Size(1440, 500),
          Size(1876, 979),
          Size(1920, 1080),
          Size(2560, 1440),
        ]) {
          await _verifySurface(
            tester,
            surface,
            size,
            brightness: brightness,
            windowChrome: true,
            scenario: 'actual-window-content',
          );
          final captureDirectory =
              io.Platform.environment['WORKBENCH_RESPONSIVE_CAPTURE_DIR'];
          if (captureDirectory != null &&
              [320, 800, 1876].contains(size.width)) {
            await tester.pump(const Duration(milliseconds: 600));
            final images = tester
                .widgetList<Image>(find.byType(Image))
                .toList();
            final context = tester.element(find.byType(Scaffold).first);
            await tester.runAsync(() async {
              for (final image in images) {
                await precacheImage(image.image, context);
              }
            });
            await tester.pump();
            debugPrint(
              'Capture ${surface.name} ${brightness.name} ${size.width}',
            );
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                io.File(
                  '$captureDirectory/${surface.name}-${brightness.name}-${size.width.toInt()}.png',
                ).uri,
              ),
            );
          }
        }
        for (final size in const [
          Size(320, 568),
          Size(390, 568),
          Size(767, 900),
          Size(768, 900),
          Size(800, 450),
          Size(1024, 600),
          Size(1876, 979),
        ]) {
          await _verifySurface(
            tester,
            surface,
            size,
            brightness: brightness,
            textScaler: TextScaler.linear(2),
            windowChrome: true,
            scenario: 'actual-window-content-large-text',
          );
        }
      }
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets(
    'all surfaces keep scrolled content inside compact and wide windows',
    (tester) async {
      final controller = await _createController(withRsip: true);
      addTearDown(controller.dispose);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final surface in _auditSurfaces(controller)) {
        for (final brightness in Brightness.values) {
          for (final (size, scaler) in [
            (const Size(320, 568), const TextScaler.linear(2)),
            (const Size(1200, 900), TextScaler.noScaling),
          ]) {
            final scenario = 'scrolled-${brightness.name}-$size';
            await _verifySurface(
              tester,
              surface,
              size,
              brightness: brightness,
              textScaler: scaler,
              scenario: scenario,
            );
            final scrollables = find.byType(Scrollable).evaluate().where((
              element,
            ) {
              final widget = element.widget as Scrollable;
              final renderObject = element.renderObject;
              return widget.axisDirection == AxisDirection.down &&
                  renderObject is RenderBox &&
                  renderObject.hasSize &&
                  renderObject.size.height > 120;
            }).toList();
            if (scrollables.isEmpty) continue;
            scrollables.sort((a, b) {
              final aSize = (a.renderObject as RenderBox).size;
              final bSize = (b.renderObject as RenderBox).size;
              return (bSize.width * bSize.height).compareTo(
                aSize.width * aSize.height,
              );
            });
            final pageScroll = find.byElementPredicate(
              (element) => identical(element, scrollables.first),
            );
            final position = tester.state<ScrollableState>(pageScroll).position;
            if (position.maxScrollExtent <= 0) continue;
            position.jumpTo(position.maxScrollExtent / 2);
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '${surface.name} failed halfway down at $scenario',
            );
            position.jumpTo(position.maxScrollExtent);
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '${surface.name} failed at the bottom at $scenario',
            );
          }
        }
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('empty pages scroll in short windows and at large font sizes', (
    tester,
  ) async {
    final controller = await _createEmptyController();
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final surface in _auditSurfaces(controller)) {
      for (final brightness in Brightness.values) {
        for (final size in const [
          Size(320, 568),
          Size(800, 450),
          Size(1440, 500),
        ]) {
          await _verifySurface(
            tester,
            surface,
            size,
            brightness: brightness,
            textScaler: TextScaler.linear(2),
            windowChrome: true,
            scenario: 'empty-short-window-large-text',
          );
        }
      }
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('today columns expand together with a stable gap on resize', (
    tester,
  ) async {
    final controller = await _createController();
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    double? previousWidth;
    for (final width in [1200.0, 1440.0, 1876.0, 2560.0]) {
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpWidget(
        _host(TodayPage(controller: controller), windowChrome: true),
      );
      await tester.pumpAndSettle();
      final main = tester.getRect(
        find.byKey(const PageStorageKey('today-main-column')),
      );
      final side = tester.getRect(
        find.byKey(const PageStorageKey('today-side-column')),
      );
      expect(side.left - main.right, closeTo(AppLayout.columnGap, 0.1));
      expect(side.width, inInclusiveRange(AppLayout.scheduleColumnMin, 416));
      expect(main.width, greaterThanOrEqualTo(AppLayout.taskColumnMin));
      if (previousWidth != null) {
        expect(main.width, greaterThanOrEqualTo(previousWidth));
      }
      previousWidth = main.width;
      expect(tester.takeException(), isNull);
    }
    // A large font needs a single readable column at this available width.
    tester.view.physicalSize = const Size(1200, 900);
    await tester.pumpWidget(
      _host(
        TodayPage(controller: controller),
        textScaler: TextScaler.linear(2),
        windowChrome: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const PageStorageKey('today-single-column')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('markdown editor keeps its cursor through preview and resize', (
    tester,
  ) async {
    final controller = await _createEmptyController();
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showMarkdownNoteEditor(context, controller),
            child: const Text('打开笔记编辑器'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开笔记编辑器'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '视图往返笔记');
    final editor = find.byKey(const ValueKey('markdown-edit-pane'));
    await tester.enterText(editor, '# 标题\n\n> 引用\n\n`code`');
    final body = tester.widget<TextField>(editor).controller!;
    body.selection = const TextSelection.collapsed(offset: 5);
    await tester.tap(find.text('预览'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    expect(find.byType(MarkdownBody), findsOneWidget);
    final style = tester
        .widget<MarkdownBody>(find.byType(MarkdownBody))
        .styleSheet!;
    expect(style.p!.fontSize, 16);
    expect(style.p!.height, 1.65);
    expect(style.code!.fontSize, 14);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(1200, 900);
    await tester.pump(const Duration(milliseconds: 220));
    expect(find.byKey(const ValueKey('markdown-edit-pane')), findsOneWidget);
    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(body.selection.baseOffset, 5);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(390, 844);
    await tester.pump(const Duration(milliseconds: 220));
    await tester.tap(find.text('编辑'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    expect(
      tester.widget<TextField>(editor).controller!.selection.baseOffset,
      5,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('captures markdown editing and preview in both themes', (
    tester,
  ) async {
    final controller = await _createEmptyController();
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final brightness in Brightness.values) {
      for (final size in const [Size(390, 844), Size(1200, 900)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pumpWidget(
          _host(
            Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () => showMarkdownNoteEditor(context, controller),
                  child: const Text('打开笔记编辑器'),
                ),
              ),
            ),
            brightness: brightness,
          ),
        );
        await tester.pump();
        await tester.tap(find.text('打开笔记编辑器'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        final suffix =
            '${brightness.name}_${size.width.toInt()}x${size.height.toInt()}';
        if (size.width < 700) {
          await tester.tap(find.widgetWithText(FilledButton, '保存'));
          await tester.pump();
          expect(find.text('请填写笔记标题。'), findsOneWidget);
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              'goldens/ui_audit/markdown_editor_validation_$suffix.png',
            ),
          );
        }
        await tester.enterText(find.byType(TextField).first, '采样核查笔记');
        await tester.enterText(
          find.byKey(const ValueKey('markdown-edit-pane')),
          '# 数据来源\n\n> 先核对单位。\n\n`dx = 1`',
        );
        await tester.pump(const Duration(milliseconds: 220));
        expect(find.text('请填写笔记标题。'), findsNothing);
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/ui_audit/markdown_editor_${size.width < 700 ? 'edit' : 'split'}_$suffix.png',
          ),
        );
        if (size.width < 700) {
          await tester.tap(find.text('预览'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 220));
          expect(find.byType(MarkdownBody), findsOneWidget);
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              'goldens/ui_audit/markdown_editor_preview_$suffix.png',
            ),
          );
        }
      }
    }
  });

  testWidgets('global search navigates results by keyboard in a short window', (
    tester,
  ) async {
    final controller = await _createController();
    addTearDown(controller.dispose);
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () => showGlobalSearch(context, controller),
              child: const Text('打开全局搜索'),
            ),
          ),
        ),
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.tap(find.text('打开全局搜索'));
    await tester.pump();
    await tester.enterText(find.byType(SearchBar), '采样');
    await tester.pump(const Duration(milliseconds: 220));
    expect(find.text('核对采样间隔与单位'), findsOneWidget);
    expect(find.text('阅读角谱传播采样条件笔记'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('编辑任务'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('global search keeps keyboard selection visible in a long list', (
    tester,
  ) async {
    final controller = await _createEmptyController();
    addTearDown(controller.dispose);
    for (var index = 0; index < 25; index++) {
      await controller.addRecord(
        WorkspaceRecord.create(kind: RecordKind.task, title: '候选任务 $index'),
      );
    }
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () => showGlobalSearch(context, controller),
              child: const Text('打开全局搜索'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开全局搜索'));
    await tester.pump();
    await tester.enterText(find.byType(SearchBar), '候选');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.showKeyboard(find.byType(SearchBar));
    await tester.pump();
    for (var index = 0; index < 12; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    final resultList = find.byType(ListView).last;
    final selected = find.descendant(
      of: resultList,
      matching: find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.selected == true,
      ),
    );
    expect(selected, findsOneWidget);
    final listRect = tester.getRect(resultList);
    final selectedRect = tester.getRect(selected);
    expect(selectedRect.top, greaterThanOrEqualTo(listRect.top - 1));
    expect(selectedRect.bottom, lessThanOrEqualTo(listRect.bottom + 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('captures global search results across window sizes', (
    tester,
  ) async {
    final controller = await _createController();
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final brightness in Brightness.values) {
      for (final size in const [
        Size(320, 568),
        Size(390, 844),
        Size(1200, 900),
      ]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pumpWidget(
          _host(
            Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () => showGlobalSearch(context, controller),
                  child: const Text('打开全局搜索'),
                ),
              ),
            ),
            brightness: brightness,
            textScaler: size.width == 320
                ? const TextScaler.linear(2)
                : TextScaler.noScaling,
          ),
        );
        await tester.tap(find.text('打开全局搜索'));
        await tester.pump();
        await tester.enterText(find.byType(SearchBar), '采样');
        await tester.pump(const Duration(milliseconds: 350));
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/ui_audit/global_search_results_${brightness.name}_${size.width.toInt()}x${size.height.toInt()}.png',
          ),
        );
      }
    }
  });

  testWidgets('captures recent search history in compact and wide windows', (
    tester,
  ) async {
    final controller = await _createController();
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    controller.rememberSearchQuery('采样');
    controller.rememberSearchQuery('论文图表');
    for (final brightness in Brightness.values) {
      for (final size in const [
        Size(320, 568),
        Size(390, 844),
        Size(1200, 900),
      ]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pumpWidget(
          _host(
            Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () => showGlobalSearch(context, controller),
                  child: const Text('打开全局搜索'),
                ),
              ),
            ),
            brightness: brightness,
            textScaler: size.width == 320
                ? const TextScaler.linear(2)
                : TextScaler.noScaling,
          ),
        );
        await tester.tap(find.text('打开全局搜索'));
        await tester.pumpAndSettle();
        expect(find.text('最近搜索'), findsOneWidget);
        if (size.width >= 1200) {
          expect(
            tester
                .getSize(find.byKey(const ValueKey('global-search-panel')))
                .height,
            lessThan(450),
          );
        }
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/ui_audit/global_search_recent_${brightness.name}_${size.width.toInt()}x${size.height.toInt()}.png',
          ),
        );
      }
    }
  });

  testWidgets('quick capture finds a project beyond the first lazy batch', (
    tester,
  ) async {
    final controller = await _createEmptyController();
    addTearDown(controller.dispose);
    for (var index = 0; index < 75; index++) {
      await controller.addRecord(
        WorkspaceRecord.create(kind: RecordKind.project, title: '候选项目 $index'),
      );
    }
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () => showQuickCapture(context, controller),
              child: const Text('打开快速新增'),
            ),
          ),
        ),
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.tap(find.text('打开快速新增'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('选择'));
    await tester.pump();
    await tester.tap(find.text('选择'));
    await tester.pump(const Duration(milliseconds: 220));
    tester.view.viewInsets = const FakeViewPadding(bottom: 200);
    await tester.pump();
    expect(find.text('候选项目 74'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('候选项目 74'),
      400,
      scrollable: find.byType(Scrollable).last,
      maxScrolls: 40,
    );
    expect(find.text('候选项目 74'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '项目 74');
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('候选项目 74'), findsOneWidget);
    await tester.tap(find.text('候选项目 74'));
    await tester.pumpAndSettle();
    expect(find.text('候选项目 74'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quick capture focuses the first error in a short window', (
    tester,
  ) async {
    final controller = await _createEmptyController();
    addTearDown(controller.dispose);
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () => showQuickCapture(context, controller),
              child: const Text('打开快速新增'),
            ),
          ),
        ),
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.tap(find.text('打开快速新增'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('收下'));
    await tester.pump();
    expect(find.text('请先输入标题。'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byType(TextField).first)
          .focusNode!
          .hasFocus,
      isTrue,
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        'goldens/ui_audit/quick_capture_validation_light_320x568.png',
      ),
    );
  });

  testWidgets('captures the quick project picker in both themes', (
    tester,
  ) async {
    final controller = await _createEmptyController();
    addTearDown(controller.dispose);
    for (var index = 0; index < 75; index++) {
      await controller.addRecord(
        WorkspaceRecord.create(kind: RecordKind.project, title: '候选项目 $index'),
      );
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final brightness in Brightness.values) {
      for (final size in const [
        Size(320, 568),
        Size(390, 844),
        Size(1200, 900),
      ]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pumpWidget(
          _host(
            Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () => showQuickCapture(context, controller),
                  child: const Text('打开快速新增'),
                ),
              ),
            ),
            brightness: brightness,
            textScaler: size.width == 320
                ? const TextScaler.linear(2)
                : TextScaler.noScaling,
          ),
        );
        await tester.tap(find.text('打开快速新增'));
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/ui_audit/quick_capture_${brightness.name}_${size.width.toInt()}x${size.height.toInt()}.png',
          ),
        );
        await tester.ensureVisible(find.text('选择'));
        await tester.pump();
        await tester.tap(find.text('选择'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/ui_audit/quick_project_picker_${brightness.name}_${size.width.toInt()}x${size.height.toInt()}.png',
          ),
        );
      }
    }
  });

  testWidgets('captures the restriction editor and schedule preview', (
    tester,
  ) async {
    final controller = await _createController();
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final brightness in Brightness.values) {
      for (final size in const [
        Size(320, 568),
        Size(390, 844),
        Size(1200, 900),
      ]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        final compact = size.width < AppBreakpoints.compact;
        await tester.pumpWidget(
          _host(
            RestrictionPage(controller: controller, showHeader: !compact),
            brightness: brightness,
            textScaler: size.width == 320
                ? const TextScaler.linear(2)
                : TextScaler.noScaling,
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
        await tester.tap(
          compact ? find.byTooltip('编辑自律规则') : find.byTooltip('编辑规则').first,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final suffix =
            '${brightness.name}_${size.width.toInt()}x${size.height.toInt()}';
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/ui_audit/restriction_editor_top_$suffix.png',
          ),
        );
        await tester.ensureVisible(find.text('每周时段预览').last);
        await tester.pump();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/ui_audit/restriction_editor_schedule_$suffix.png',
          ),
        );
        await tester.ensureVisible(find.byTooltip('添加时段'));
        await tester.tap(find.byTooltip('添加时段'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(FilterChip).first);
        await tester.tap(find.byType(FilterChip).first);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('每周时段预览').last);
        await tester.pump();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/ui_audit/restriction_schedule_dialog_$suffix.png',
          ),
        );
      }
    }
  });

  testWidgets('captures the configured account form across window sizes', (
    tester,
  ) async {
    final controller = await _createEmptyController(cloudConfigured: true);
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final brightness in Brightness.values) {
      for (final size in const [
        Size(320, 568),
        Size(390, 844),
        Size(1200, 900),
      ]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pumpWidget(
          _host(
            SettingsPage(controller: controller, showHeader: size.width >= 768),
            brightness: brightness,
            textScaler: size.width == 320
                ? const TextScaler.linear(2)
                : TextScaler.noScaling,
          ),
        );
        await tester.pump();
        await tester.scrollUntilVisible(
          find.text('账号与同步'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(find.text('账号与同步'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final suffix =
            '${brightness.name}_${size.width.toInt()}x${size.height.toInt()}';
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/ui_audit/settings_auth_top_$suffix.png'),
        );
        await tester.ensureVisible(find.text('登录'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/ui_audit/settings_auth_action_$suffix.png',
          ),
        );
        if (brightness == Brightness.light && size.width == 320) {
          await tester.tap(find.text('登录'));
          await tester.pump();
          await tester.ensureVisible(find.text('请输入有效邮箱。'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              'goldens/ui_audit/settings_auth_validation_light_320x568.png',
            ),
          );
        }
      }
    }
  });

  testWidgets('captures sync conflict comparison in compact and wide windows', (
    tester,
  ) async {
    final controller = _AuditSignedInController();
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final cloud = WorkspaceRecord.create(
      kind: RecordKind.note,
      title: '论文结论云端版',
      body: '云端保留原图表口径。',
    );
    final local = cloud
        .copyWith(title: '论文结论本地版', body: '本地补充误差分析与复核步骤。')
        .asConflictCopy();
    await controller.addRecord(cloud);
    await controller.addRecord(local);
    for (final brightness in Brightness.values) {
      for (final size in const [Size(320, 568), Size(1200, 900)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pumpWidget(
          _host(
            SettingsPage(controller: controller, showHeader: size.width >= 768),
            brightness: brightness,
            textScaler: size.width == 320
                ? const TextScaler.linear(2)
                : TextScaler.noScaling,
          ),
        );
        await tester.pump();
        await tester.scrollUntilVisible(
          find.text('对照并解决'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(find.text('对照并解决'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('对照并解决'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('差异字段'));
        await tester.pump();
        expect(tester.takeException(), isNull);
        final suffix =
            '${brightness.name}_${size.width.toInt()}x${size.height.toInt()}';
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/ui_audit/sync_conflict_diff_$suffix.png'),
        );
        await tester.ensureVisible(find.text('选择保留版本'));
        await tester.pump();
        await tester.ensureVisible(find.byType(ChoiceChip).last);
        await tester.pump();
        await tester.tap(find.byType(ChoiceChip).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/ui_audit/sync_conflict_choice_$suffix.png',
          ),
        );
      }
    }
  });

  testWidgets('captures the remaining UI audit surfaces', (tester) async {
    final controller = await _createController();
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _capture(
      tester,
      'plan_desktop',
      PlanPage(
        controller: controller,
        onOpenInbox: () {},
        onOpenCalendar: () {},
        onOpenProjects: () {},
      ),
    );
    await _capture(
      tester,
      'calendar_desktop',
      CalendarPage(controller: controller),
    );
    await _capture(tester, 'inbox_desktop', InboxPage(controller: controller));
    await _capture(
      tester,
      'projects_desktop',
      ProjectsPage(controller: controller),
    );
    await _capture(
      tester,
      'focus_hub_desktop',
      FocusHubPage(controller: controller),
    );
    await _capture(tester, 'notes_desktop', NotesPage(controller: controller));
    await _capture(
      tester,
      'review_desktop',
      ReviewPage(controller: controller),
    );
    await _capture(tester, 'goals_desktop', GoalsPage(controller: controller));
    await _capture(
      tester,
      'habits_desktop',
      HabitsPage(controller: controller),
    );
    await _capture(
      tester,
      'policies_desktop',
      PoliciesPage(controller: controller),
    );
    await _capture(
      tester,
      'protocols_desktop',
      ProtocolsPage(controller: controller),
    );
    await _capture(
      tester,
      'restriction_desktop',
      RestrictionPage(controller: controller),
    );
    await _capture(
      tester,
      'restriction_mobile',
      RestrictionPage(controller: controller, showHeader: false),
      size: const Size(412, 915),
    );
    await _captureRestrictionEditor(
      tester,
      controller,
      'restriction_editor_desktop',
      size: const Size(1200, 900),
    );
    await _captureRestrictionEditor(
      tester,
      controller,
      'restriction_editor_mobile',
      size: const Size(412, 915),
    );
    await _capture(
      tester,
      'growth_desktop',
      GrowthPage(controller: controller),
    );
    await _capture(
      tester,
      'settings_desktop',
      SettingsPage(controller: controller),
    );
    await _capture(
      tester,
      'focus_session_desktop',
      FocusPage(controller: controller, task: controller.tasks.first),
    );
    await _capture(
      tester,
      'today_mobile',
      TodayPage(controller: controller, onOpenFocus: () {}),
      size: const Size(412, 915),
    );
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final themeName = brightness == Brightness.light ? 'day' : 'night';
      const mobileSize = Size(390, 844);
      await _capture(
        tester,
        'projects_mobile_$themeName',
        ProjectsPage(controller: controller, showHeader: false),
        size: mobileSize,
        brightness: brightness,
      );
      await _capture(
        tester,
        'focus_mobile_$themeName',
        FocusHubPage(controller: controller, showHeader: false),
        size: mobileSize,
        brightness: brightness,
      );
      await _capture(
        tester,
        'notes_mobile_$themeName',
        NotesPage(controller: controller, showHeader: false),
        size: mobileSize,
        brightness: brightness,
      );
      await _capture(
        tester,
        'review_mobile_$themeName',
        ReviewPage(controller: controller, showHeader: false),
        size: mobileSize,
        brightness: brightness,
      );
    }
  });

  testWidgets('captures all 35 audit targets in both themes at 1200dp', (
    tester,
  ) async {
    final controller = await _createController(withRsip: true);
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final surfaces = _auditSurfaces(controller);
    expect(surfaces.length, 35);
    for (final surface in surfaces) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        await _capture(
          tester,
          'matrix_${surface.name}_${brightness.name}_1200x900',
          surface.builder(const Size(1200, 900)),
          brightness: brightness,
        );
      }
    }
  });

  testWidgets('captures linked execution history after scrolling', (
    tester,
  ) async {
    final controller = await _createController(withRsip: true);
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in const [Size(390, 844), Size(1200, 900)]) {
      final dimensions = '${size.width.toInt()}x${size.height.toInt()}';
      for (final brightness in Brightness.values) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pumpWidget(
          _host(
            ProtocolsPage(controller: controller, showHeader: false),
            brightness: brightness,
          ),
        );
        await tester.pumpAndSettle();
        final pageScroll = find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(
          find.text('论文图表聚焦'),
          180,
          scrollable: pageScroll,
        );
        await tester.pumpAndSettle();
        expect(find.text('关联任务：论文复核专注链'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/ui_audit/protocols_linked_${brightness.name}_$dimensions.png',
          ),
        );
      }
    }
  });

  testWidgets('captures grouped protocol entries in compact and wide windows', (
    tester,
  ) async {
    final controller = await _createEmptyController();
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await controller.addRecord(
      WorkspaceRecord.create(
        kind: RecordKind.task,
        title: '论文任务组',
        data: const {
          'protocol': 'ctdp',
          'ctdpUnitType': 'group',
          'ctdpGroupTimeLimitHours': 3,
        },
      ),
    );
    await controller.addRecord(
      WorkspaceRecord.create(
        kind: RecordKind.task,
        title: '论文复核专注链',
        data: const {'protocol': 'ctdp', 'ctdpTrigger': '打开论文'},
      ),
    );
    await controller.addRecord(
      WorkspaceRecord.create(
        kind: RecordKind.habit,
        title: '论文晨读',
        data: const {
          'protocol': 'rsip',
          'rsipGroup': '科研',
          'rsipMinimumAction': '读一段摘要',
        },
      ),
    );
    await controller.addRecord(
      WorkspaceRecord.create(
        kind: RecordKind.habit,
        title: '实验室收尾',
        data: const {
          'protocol': 'rsip',
          'rsipGroup': '实验室',
          'rsipMinimumAction': '整理一件器材',
        },
      ),
    );
    for (final brightness in Brightness.values) {
      for (final size in const [Size(390, 844), Size(1200, 900)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pumpWidget(
          _host(
            ProtocolsPage(
              controller: controller,
              showHeader: size.width >= AppBreakpoints.compact,
            ),
            brightness: brightness,
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text('任务组'), findsOneWidget);
        expect(find.text('执行链'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final suffix =
            '${brightness.name}_${size.width.toInt()}x${size.height.toInt()}';
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/ui_audit/protocol_groups_execution_$suffix.png',
          ),
        );

        await tester.tap(
          find.descendant(of: find.byType(TabBar), matching: find.text('行为协议')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text('科研'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/ui_audit/protocol_groups_behavior_$suffix.png',
          ),
        );
      }
    }
  });

  testWidgets('captures relation picker across compact wide and large text', (
    tester,
  ) async {
    final controller = await _createController();
    final editableNotes = controller.notes
        .where(
          (note) =>
              note.data['recordType'] != 'periodReview' &&
              note.data['recordType'] != 'restrictionLogArchive',
        )
        .toList();
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final brightness in Brightness.values) {
      for (final size in const [
        Size(320, 568),
        Size(390, 844),
        Size(1200, 900),
      ]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pumpWidget(
          _host(
            Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () => showRelationPickerDialog(
                    context: context,
                    controller: controller,
                    initialTaskIds: [controller.tasks.first.id],
                    initialProjectIds: [controller.projects.first.id],
                    initialGoalIds: [controller.goals.first.id],
                    initialNoteIds: [editableNotes.first.id],
                  ),
                  child: const Text('打开关系选择'),
                ),
              ),
            ),
            brightness: brightness,
            textScaler: size.width == 320
                ? const TextScaler.linear(2)
                : TextScaler.noScaling,
          ),
        );
        await tester.pump();
        await tester.tap(find.text('打开关系选择'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
        final suffix =
            '${brightness.name}_${size.width.toInt()}x${size.height.toInt()}';
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/ui_audit/relation_picker_$suffix.png'),
        );
        final noteChip = find.widgetWithText(
          ChoiceChip,
          '笔记 ${editableNotes.length}',
        );
        await tester.ensureVisible(noteChip);
        await tester.pumpAndSettle();
        await tester.tap(noteChip);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/ui_audit/relation_picker_notes_$suffix.png',
          ),
        );
      }
    }
  });

  testWidgets('captures note reading in compact and wide windows', (
    tester,
  ) async {
    final controller = await _createController();
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await controller.addRecord(
      WorkspaceRecord(
        id: 'audit-note-reading',
        kind: RecordKind.note,
        title: '采样说明与复核依据',
        body:
            '# 采样说明\n\n先核对输入场、波长和采样间隔，再复核图轴单位。\n\n'
            '> 原始数据与结论应能相互追溯。\n\n'
            '计算记录：`dx = 1.0 mm`。',
        createdAt: _auditNow,
        updatedAt: _auditNow.add(const Duration(minutes: 1)),
        data: {
          'recordType': 'markdownNote',
          'relatedProjectIds': [controller.projects.first.id],
          'relatedTaskIds': [controller.tasks.first.id],
          'relatedGoalIds': [controller.goals.first.id],
          'relatedNoteIds': [
            controller.notes
                .firstWhere((note) => note.data['recordType'] != 'periodReview')
                .id,
          ],
        },
      ),
    );
    for (final size in const [Size(390, 844), Size(1200, 900)]) {
      final dimensions = '${size.width.toInt()}x${size.height.toInt()}';
      for (final brightness in Brightness.values) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pumpWidget(
          _host(
            NotesPage(
              controller: controller,
              showHeader: size.width >= AppBreakpoints.compact,
            ),
            brightness: brightness,
          ),
        );
        await tester.pumpAndSettle();
        if (size.width < AppBreakpoints.compact) {
          await tester.tap(find.text('采样说明与复核依据'));
          await tester.pumpAndSettle();
        }
        expect(
          tester.widget<MarkdownBody>(find.byType(MarkdownBody)).data,
          contains('原始数据与结论应能相互追溯。'),
        );
        expect(find.text(controller.goals.first.title), findsOneWidget);
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/ui_audit/notes_reader_${brightness.name}_$dimensions.png',
          ),
        );
      }
    }
  });

  testWidgets('captures the structured rule editor in compact and wide windows', (
    tester,
  ) async {
    final controller = await _createController(withRsip: true);
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in const [Size(390, 844), Size(1200, 900)]) {
      final dimensions = '${size.width.toInt()}x${size.height.toInt()}';
      for (final brightness in Brightness.values) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pumpWidget(
          _host(
            ProtocolsPage(
              controller: controller,
              initialTab: ProtocolTab.rules,
              showHeader: size.width >= AppBreakpoints.compact,
            ),
            brightness: brightness,
          ),
        );
        await tester.pumpAndSettle();
        final action = find.byTooltip('判例操作：设备安全警报暂停');
        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.pumpAndSettle();
        await tester.tap(find.text('编辑判例'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('设备安全警报暂停'), findsWidgets);
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/ui_audit/protocols_rule_editor_${brightness.name}_$dimensions.png',
          ),
        );
      }
    }
  });

  testWidgets('captures all 35 audit targets across responsive boundaries', (
    tester,
  ) async {
    final controller = await _createController(withRsip: true);
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in const [
      Size(390, 844),
      Size(767, 900),
      Size(768, 900),
      Size(1440, 900),
    ]) {
      final dimensions = '${size.width.toInt()}x${size.height.toInt()}';
      for (final surface in _auditSurfaces(controller)) {
        for (final brightness in [Brightness.light, Brightness.dark]) {
          await _capture(
            tester,
            'matrix_${surface.name}_${brightness.name}_$dimensions',
            surface.builder(size),
            size: size,
            brightness: brightness,
          );
        }
      }
    }
  });

  testWidgets('captures all 35 audit targets in short windows', (tester) async {
    final controller = await _createController(withRsip: true);
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in const [Size(390, 568), Size(800, 450)]) {
      final dimensions = '${size.width.toInt()}x${size.height.toInt()}';
      for (final surface in _auditSurfaces(controller)) {
        for (final brightness in [Brightness.light, Brightness.dark]) {
          await _capture(
            tester,
            'matrix_${surface.name}_${brightness.name}_$dimensions',
            surface.builder(size),
            size: size,
            brightness: brightness,
          );
        }
      }
    }
  });

  testWidgets('captures all 35 audit targets at 320dp with 200% text', (
    tester,
  ) async {
    final controller = await _createController(withRsip: true);
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const size = Size(320, 568);
    for (final surface in _auditSurfaces(controller)) {
      for (final brightness in Brightness.values) {
        await _capture(
          tester,
          'matrix_${surface.name}_${brightness.name}_320x568_text200',
          surface.builder(size),
          size: size,
          brightness: brightness,
          textScaler: const TextScaler.linear(2),
        );
        if (surface.name == 'tasks_week') {
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Text &&
                  widget.data == '一' &&
                  widget.semanticsLabel == '周一',
            ),
            findsOneWidget,
          );
        }
      }
    }
  });

  testWidgets('captures all 35 audit targets at 800x450 with 200% text', (
    tester,
  ) async {
    final controller = await _createController(withRsip: true);
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const size = Size(800, 450);
    for (final surface in _auditSurfaces(controller)) {
      for (final brightness in Brightness.values) {
        await _capture(
          tester,
          'matrix_${surface.name}_${brightness.name}_800x450_text200',
          surface.builder(size),
          size: size,
          brightness: brightness,
          textScaler: const TextScaler.linear(2),
        );
        if (surface.name == 'today') {
          expect(find.text('00'), findsOneWidget);
          expect(find.text('01'), findsNothing);
          expect(find.text('02'), findsOneWidget);
          expect(find.bySemanticsLabel('01:00'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('time-ruler-hour-23')),
            findsOneWidget,
          );
        }
      }
    }
  });

  testWidgets('reduced-motion skeletons can unmount repeatedly', (
    tester,
  ) async {
    final controller = await _createController();
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(1200, 864);
    tester.view.devicePixelRatio = 1;
    for (var index = 0; index < 3; index++) {
      await tester.pumpWidget(
        _host(NotesPage(controller: controller), disableAnimations: true),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('all mapped surfaces survive the complete layout matrix', (
    tester,
  ) async {
    final populated = await _createController();
    final empty = await _createEmptyController();
    addTearDown(populated.dispose);
    addTearDown(empty.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const viewports = [
      Size(320, 568),
      Size(320, 700),
      Size(375, 812),
      Size(390, 568),
      Size(390, 844),
      Size(412, 915),
      Size(767, 900),
      Size(768, 864),
      Size(800, 450),
      Size(1024, 864),
      Size(1200, 500),
      Size(1200, 864),
      Size(1440, 900),
      Size(1536, 864),
    ];
    for (final surface in _auditSurfaces(populated)) {
      for (final brightness in Brightness.values) {
        for (final size in viewports) {
          await _verifySurface(
            tester,
            surface,
            size,
            brightness: brightness,
            scenario: brightness.name,
          );
        }
        for (final size in const [Size(390, 844), Size(1200, 864)]) {
          await _verifySurface(
            tester,
            surface,
            size,
            brightness: brightness,
            disableAnimations: true,
            scenario: 'reduced-motion-${brightness.name}',
          );
        }
        for (final size in const [Size(320, 568), Size(800, 450)]) {
          await _verifySurface(
            tester,
            surface,
            size,
            brightness: brightness,
            textScaler: const TextScaler.linear(2),
            scenario: 'text-200-percent-${brightness.name}',
          );
        }
      }
    }

    for (final surface in _auditSurfaces(empty)) {
      for (final brightness in Brightness.values) {
        for (final size in const [
          Size(320, 700),
          Size(390, 844),
          Size(1200, 864),
        ]) {
          await _verifySurface(
            tester,
            surface,
            size,
            brightness: brightness,
            scenario: 'empty-${brightness.name}',
          );
        }
      }
    }
  });

  testWidgets(
    'all mapped surfaces fit a fixed physical window at common scale factors',
    (tester) async {
      final controller = await _createController(withRsip: true);
      addTearDown(controller.dispose);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final scale in const [1.0, 1.25, 1.5, 2.0]) {
        for (final surface in _auditSurfaces(controller)) {
          for (final brightness in Brightness.values) {
            await _verifySurface(
              tester,
              surface,
              const Size(1600, 900),
              brightness: brightness,
              devicePixelRatio: scale,
              windowChrome: true,
              scenario: 'simulated-${(scale * 100).round()}-percent-dpi',
            );
          }
        }
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'all mapped surfaces reflow while their page state stays mounted',
    (tester) async {
      final controller = await _createController(withRsip: true);
      addTearDown(controller.dispose);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      for (final surface in _auditSurfaces(controller)) {
        for (final brightness in Brightness.values) {
          for (final scaler in const [
            TextScaler.noScaling,
            TextScaler.linear(2),
          ]) {
            final pageKey = GlobalKey();
            tester.view.physicalSize = const Size(1440, 900);
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
            await tester.pumpWidget(
              _host(
                Builder(
                  key: pageKey,
                  builder: (context) =>
                      surface.builder(MediaQuery.sizeOf(context)),
                ),
                brightness: brightness,
                textScaler: scaler,
                windowChrome: true,
              ),
            );
            await tester.pump(const Duration(milliseconds: 200));
            final mountedPage = tester.element(find.byKey(pageKey));
            for (final size in const [
              Size(1440, 900),
              Size(767, 900),
              Size(800, 450),
              Size(320, 568),
              Size(768, 568),
              Size(1200, 500),
              Size(1920, 1080),
            ]) {
              tester.view.physicalSize = size;
              await tester.pump(const Duration(milliseconds: 200));
              expect(
                tester.element(find.byKey(pageKey)),
                same(mountedPage),
                reason: '${surface.name} was remounted while resizing to $size',
              );
              expect(
                tester.getSize(
                  find.byKey(const ValueKey('audit-window-capture')),
                ),
                size,
                reason: '${surface.name} did not resize to $size',
              );
              expect(
                tester.takeException(),
                isNull,
                reason:
                    '${surface.name} overflowed while resizing to $size / '
                    '${brightness.name} / $scaler',
              );
            }
          }
        }
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('task filters remain reachable in a short wide window', (
    tester,
  ) async {
    final controller = await _createController();
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(800, 450);
    tester.view.devicePixelRatio = 1;
    for (final scaler in const [TextScaler.noScaling, TextScaler.linear(2)]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(
        _host(
          PlanPage(controller: controller, showTabs: false),
          textScaler: scaler,
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      final toggle = find.byKey(const ValueKey('task-filter-toggle'));
      expect(toggle, findsOneWidget);
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('task-filter-status')), findsOneWidget);
      expect(find.text('核对采样间隔与单位'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('notes keep reviews out and preserve the reader through resize', (
    tester,
  ) async {
    final controller = await _createController();
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final project = controller.projects.first;
    await controller.addRecord(
      WorkspaceRecord.create(
        kind: RecordKind.note,
        title: '项目关联笔记',
        body: '# 采样说明\n\n> 先核对单位。\n\n`dx = 1`',
        data: {
          'recordType': 'markdownNote',
          'relatedProjectIds': [project.id],
        },
      ),
    );
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      _host(
        NotesPage(controller: controller, showHeader: false),
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('论文复核周回顾'), findsNothing);
    expect(find.text('2 篇笔记'), findsOneWidget);
    expect(find.text('2 篇关联项目'), findsOneWidget);
    await tester.tap(find.text('项目关联笔记'));
    await tester.pumpAndSettle();
    expect(find.text('返回笔记索引'), findsOneWidget);
    expect(find.text(project.title), findsOneWidget);
    final style = tester
        .widget<MarkdownBody>(find.byType(MarkdownBody))
        .styleSheet!;
    expect(style.p!.fontSize, 16);
    expect(style.p!.height, 1.65);
    expect(style.blockquote!.fontSize, 14);
    expect(style.code!.fontSize, 14);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(1600, 900);
    await tester.pumpAndSettle();
    expect(find.text('知识索引'), findsOneWidget);
    expect(find.text('返回笔记索引'), findsNothing);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(320, 568);
    await tester.pumpAndSettle();
    expect(find.text('返回笔记索引'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'all mapped surfaces expose hover press and keyboard focus at minimum normal and large sizes',
    (tester) async {
      final controller = await _createController();
      addTearDown(controller.dispose);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const sizes = [Size(375, 812), Size(1200, 864), Size(1536, 864)];
      for (final surface in _auditSurfaces(controller)) {
        for (final size in sizes) {
          await _verifyInteractiveStates(tester, surface, size);
        }
      }
    },
  );

  testWidgets(
    'all mapped surfaces open every popup and dropdown at minimum normal and large sizes',
    (tester) async {
      final controller = await _createController();
      addTearDown(controller.dispose);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const sizes = [Size(375, 812), Size(1200, 864), Size(1536, 864)];
      for (final surface in _auditSurfaces(controller)) {
        for (final size in sizes) {
          await _verifyOpenMenus(tester, surface, size);
        }
      }
    },
  );

  testWidgets(
    'shared dialogs survive open focus and escape across the window matrix',
    (tester) async {
      final controller = await _createController();
      addTearDown(controller.dispose);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final audits = [
        _DialogAudit('record editor', (context) {
          showRecordEditor(context, controller, kind: RecordKind.task);
        }),
        _DialogAudit('task group editor', (context) {
          showTaskGroupEditor(context: context, controller: controller);
        }),
        _DialogAudit('relation picker', (context) {
          showRelationPickerDialog(
            context: context,
            controller: controller,
            initialTaskIds: const [],
            initialProjectIds: const [],
          );
        }),
        _DialogAudit('markdown note editor', (context) {
          showMarkdownNoteEditor(context, controller);
        }),
        _DialogAudit('global search', (context) {
          showGlobalSearch(context, controller);
        }),
        _DialogAudit('quick capture', (context) {
          showQuickCapture(context, controller);
        }),
      ];
      const scenarios = [
        (Size(375, 812), TextScaler.noScaling),
        (Size(375, 812), TextScaler.linear(2)),
        (Size(1200, 864), TextScaler.noScaling),
        (Size(1536, 864), TextScaler.noScaling),
        (Size(320, 568), TextScaler.linear(2)),
        (Size(800, 450), TextScaler.linear(2)),
        (Size(1440, 500), TextScaler.linear(2)),
      ];
      for (final audit in audits) {
        for (final scenario in scenarios) {
          await _verifyDialogState(
            tester,
            audit,
            scenario.$1,
            textScaler: scenario.$2,
          );
        }
      }
    },
  );

  testWidgets(
    'focus preset dialog supports keyboard focus and dropdowns at minimum width',
    (tester) async {
      final controller = await _createController();
      addTearDown(controller.dispose);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;

      await tester.pumpWidget(
        _host(FocusHubPage(controller: controller, showHeader: false)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('新建专注预设'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);

      for (var index = 0; index < 8; index++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump(const Duration(milliseconds: 180));
        expect(
          tester.takeException(),
          isNull,
          reason: 'focus preset dialog failed after Tab ${index + 1}',
        );
      }

      final dropdowns = find.byWidgetPredicate(
        (widget) => widget is DropdownButtonFormField,
        skipOffstage: false,
      );
      expect(dropdowns, findsNWidgets(4));
      for (var index = 0; index < 4; index++) {
        final dropdown = find
            .byWidgetPredicate(
              (widget) => widget is DropdownButtonFormField,
              skipOffstage: false,
            )
            .at(index);
        await tester.ensureVisible(dropdown);
        await tester.tap(dropdown);
        await tester.pumpAndSettle();
        expect(
          find.byWidgetPredicate((widget) => widget is DropdownMenuItem),
          findsWidgets,
        );
        expect(tester.takeException(), isNull);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );
}
