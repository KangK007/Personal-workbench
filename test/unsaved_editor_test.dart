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
import 'package:personal_workbench/ui/widgets/markdown_editor_dialog.dart';
import 'package:personal_workbench/ui/widgets/quick_capture_sheet.dart';
import 'package:personal_workbench/ui/widgets/record_editor_dialog.dart';
import 'package:personal_workbench/ui/widgets/task_group_editor_dialog.dart';

class _MemoryDatabase extends AppDatabase {
  @override
  Future<void> saveRecord(
    WorkspaceRecord record, {
    bool markDirty = true,
  }) async {}

  @override
  Future<void> close() async {}
}

void main() {
  for (final editor in ['capture', 'record', 'markdown', 'task-group']) {
    testWidgets('$editor protects input on cancel and Escape', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = WorkbenchController(
        database: _MemoryDatabase(),
        backupService: BackupService(),
        searchService: SearchService(),
        focusService: FocusService(),
        notificationService: NotificationService(),
        shareCaptureService: ShareCaptureService(),
        syncService: SupabaseSyncService(null),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () {
                  switch (editor) {
                    case 'capture':
                      showQuickCapture(context, controller);
                    case 'record':
                      showRecordEditor(
                        context,
                        controller,
                        kind: RecordKind.task,
                      );
                    case 'markdown':
                      showMarkdownNoteEditor(context, controller);
                    case 'task-group':
                      showTaskGroupEditor(
                        context: context,
                        controller: controller,
                      );
                  }
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '保留的草稿');
      if (editor == 'capture') {
        await tester.tap(find.byTooltip('关闭'));
      } else {
        await tester.tap(find.widgetWithText(TextButton, '取消'));
      }
      await tester.pumpAndSettle();
      expect(find.text('放弃未保存的修改？'), findsOneWidget);
      await tester.tap(find.text('继续编辑'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '保留的草稿',
      );
      if (editor == 'capture') {
        await tester.binding.handlePopRoute();
      } else {
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      }
      await tester.pumpAndSettle();
      expect(find.text('放弃未保存的修改？'), findsOneWidget);
      await tester.tap(find.text('放弃修改'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
