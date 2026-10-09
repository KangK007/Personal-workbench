import 'dart:ui' as ui;
import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:personal_workbench/ui/widgets/workbench_layout.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_workbench/core/models/attachment.dart';
import 'package:personal_workbench/core/models/restriction_models.dart';
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
import 'package:personal_workbench/ui/widgets/global_search_dialog.dart';
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

Future<WorkbenchController> _createEmptyController() async =>
    WorkbenchController(
      database: _MemoryDatabase(),
      backupService: BackupService(),
      searchService: SearchService(),
      focusService: FocusService(),
      notificationService: NotificationService(),
      shareCaptureService: ShareCaptureService(),
      syncService: SupabaseSyncService(null),
      now: () => _auditNow,
    );

Future<WorkbenchController> _createController() async {
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
      dueAt: _auditNow.add(const Duration(days: 7)),
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
                  width: size.width < AppBreakpoints.expanded ? 81 : 237,
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
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  // 每张页面截图使用全新的 Navigator，避免前一张图的弹窗路由残留。
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pumpWidget(_host(child, brightness: brightness));
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
  bool disableAnimations = false,
  bool windowChrome = false,
  required String scenario,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
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
      surface.builder(size),
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
    final controller = await _createController();
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final surface in _auditSurfaces(controller)) {
      for (final brightness in Brightness.values) {
        for (final size in const [
          Size(320, 568),
          Size(700, 420),
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
        for (final size in const [Size(1024, 600), Size(1876, 979)]) {
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
      expect(side.width, inInclusiveRange(280, 360));
      expect(main.width, greaterThanOrEqualTo(560));
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
      TodayPage(controller: controller),
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
      Size(320, 700),
      Size(375, 812),
      Size(390, 844),
      Size(412, 915),
      Size(768, 864),
      Size(1024, 864),
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
        await _verifySurface(
          tester,
          surface,
          const Size(320, 700),
          brightness: brightness,
          textScaler: const TextScaler.linear(2),
          scenario: 'text-200-percent-${brightness.name}',
        );
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
