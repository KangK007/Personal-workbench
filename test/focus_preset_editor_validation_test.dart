import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:personal_workbench/ui/widgets/common.dart';

class _MemoryDatabase extends AppDatabase {
  Completer<void>? gate;
  bool fail = false;
  int saveCalls = 0;

  @override
  Future<void> saveRecord(
    WorkspaceRecord record, {
    bool markDirty = true,
  }) async {
    saveCalls++;
    await gate?.future;
    if (fail) throw StateError('storage unavailable');
  }

  @override
  Future<void> close() async {}
}

WorkbenchController _controller(_MemoryDatabase database) =>
    WorkbenchController(
      database: database,
      backupService: BackupService(),
      searchService: SearchService(),
      focusService: FocusService(),
      notificationService: NotificationService(),
      shareCaptureService: ShareCaptureService(),
      syncService: SupabaseSyncService(null),
    );

Finder _field(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(ExternalField)),
  matching: find.byType(TextField),
);

Future<void> _openEditor(
  WidgetTester tester,
  WorkbenchController controller,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: FocusHubPage(controller: controller, showHeader: false),
      ),
    ),
  );
  await tester.tap(find.byTooltip('新建专注预设'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('invalid preset minutes stay in the field and never save', (
    tester,
  ) async {
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final database = _MemoryDatabase();
    final controller = _controller(database);
    addTearDown(controller.dispose);
    await _openEditor(tester, controller);
    await tester.enterText(_field('预设名称'), '阅读资料');

    for (final invalid in ['abc', '0', '721']) {
      await tester.enterText(_field('时长（分钟）'), invalid);
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pump();
      expect(find.text('请输入 1–720 的整数分钟。'), findsOneWidget);
      expect(database.saveCalls, 0);
    }

    await tester.enterText(_field('时长（分钟）'), '45');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    expect(database.saveCalls, 1);
    expect(controller.focusPresets.single.data['minutes'], 45);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preset save disables duplicate submit and shows write errors', (
    tester,
  ) async {
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final database = _MemoryDatabase()..gate = Completer<void>();
    final controller = _controller(database);
    addTearDown(controller.dispose);
    await _openEditor(tester, controller);
    await tester.enterText(_field('预设名称'), '整理访谈');
    await tester.enterText(_field('时长（分钟）'), '30');

    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pump();
    final savingButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '保存中'),
    );
    expect(savingButton.onPressed, isNull);
    expect(database.saveCalls, 1);

    database.fail = true;
    database.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('保存失败：'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '保存'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancel and Escape protect an unsaved preset draft', (
    tester,
  ) async {
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final database = _MemoryDatabase();
    final controller = _controller(database);
    addTearDown(controller.dispose);
    await _openEditor(tester, controller);
    await tester.enterText(_field('预设名称'), '尚未保存的阅读预设');

    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
    expect(find.text('放弃预设修改？'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '继续编辑'));
    await tester.pumpAndSettle();
    expect(find.text('尚未保存的阅读预设'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('放弃预设修改？'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '放弃修改'));
    await tester.pumpAndSettle();
    expect(find.text('新建专注预设'), findsNothing);
    expect(database.saveCalls, 0);
    expect(tester.takeException(), isNull);
  });
}
