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
import 'package:personal_workbench/services/windows_activity_service.dart';
import 'package:personal_workbench/state/workbench_controller.dart';
import 'package:personal_workbench/ui/widgets/quick_capture_sheet.dart';
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

Widget _host(WorkbenchController controller) => MaterialApp(
  theme: AppTheme.light(),
  locale: const Locale('zh', 'CN'),
  supportedLocales: const [Locale('zh', 'CN')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: WorkbenchShell(controller: controller, enableSystemHotkey: false),
);

void _useAuditEmulatorViewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

bool _overlaps(Rect a, Rect b) =>
    a.left < b.right &&
    a.right > b.left &&
    a.top < b.bottom &&
    a.bottom > b.top;

Rect _intersection(Rect a, Rect b) => Rect.fromLTRB(
  a.left > b.left ? a.left : b.left,
  a.top > b.top ? a.top : b.top,
  a.right < b.right ? a.right : b.right,
  a.bottom < b.bottom ? a.bottom : b.bottom,
);

void main() {
  testWidgets(
    'quick capture keeps save above the keyboard without losing input',
    (tester) async {
      _useAuditEmulatorViewport(tester);
      addTearDown(tester.view.resetViewInsets);
      final controller = _controller();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(controller));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mobile-quick-capture')));
      await tester.pumpAndSettle();
      final input = find.descendant(
        of: find.byType(QuickCaptureSheet),
        matching: find.byType(TextField),
      );
      await tester.enterText(input, '键盘弹出后仍保留的快速记录');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, '收下');
      expect(save.hitTestable(), findsOneWidget);
      expect(tester.getBottomRight(save).dy, lessThanOrEqualTo(544));
      expect(tester.widget<TextField>(input).controller!.text, '键盘弹出后仍保留的快速记录');
      expect(tester.takeException(), isNull);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(controller.tasks.single.title, '键盘弹出后仍保留的快速记录');
      expect(find.byType(QuickCaptureSheet), findsNothing);
    },
  );

  testWidgets('daily review reminder switch stays clear of quick capture FAB', (
    tester,
  ) async {
    _useAuditEmulatorViewport(tester);
    final controller = _controller();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('个人设置'));
    await tester.pumpAndSettle();

    final reminder = find.widgetWithText(SwitchListTile, '日回顾');
    final toggle = find.descendant(of: reminder, matching: find.byType(Switch));
    await tester.scrollUntilVisible(
      reminder,
      180,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    final fabRect = tester.getRect(
      find.byKey(const ValueKey('mobile-quick-capture')),
    );
    final toggleRect = tester.getRect(toggle);
    final overlap = _intersection(toggleRect, fabRect);
    if (!overlap.isEmpty) {
      await tester.tapAt(overlap.center);
      await tester.pumpAndSettle();
      expect(find.byType(QuickCaptureSheet), findsOneWidget);
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
    }
    expect(_overlaps(toggleRect, fabRect), isFalse);

    final wasEnabled = controller.reviewReminderEnabled(ReviewPeriodType.daily);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(
      controller.reviewReminderEnabled(ReviewPeriodType.daily),
      !wasEnabled,
    );
    await tester.tap(find.byKey(const ValueKey('mobile-quick-capture')));
    await tester.pumpAndSettle();
    expect(find.byType(QuickCaptureSheet), findsOneWidget);
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'daily review editor and preview controls stay clear of quick capture FAB',
    (tester) async {
      _useAuditEmulatorViewport(tester);
      final controller = _controller();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_host(controller));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('记录'));
      await tester.pumpAndSettle();

      final previewLabel = find.text('预览');
      await tester.scrollUntilVisible(
        previewLabel,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      final reviewPosition = Scrollable.of(
        tester.element(previewLabel),
      ).position;
      reviewPosition.jumpTo(reviewPosition.maxScrollExtent - 550);
      await tester.pumpAndSettle();
      final fabRect = tester.getRect(
        find.byKey(const ValueKey('mobile-quick-capture')),
      );
      final editorPreviewRect = tester.getRect(
        find.byType(SegmentedButton<bool>).last,
      );
      final overlap = _intersection(editorPreviewRect, fabRect);
      if (!overlap.isEmpty) {
        await tester.tapAt(overlap.center);
        await tester.pumpAndSettle();
        expect(find.byType(QuickCaptureSheet), findsOneWidget);
        await tester.tap(find.byTooltip('关闭'));
        await tester.pumpAndSettle();
      }
      expect(_overlaps(editorPreviewRect, fabRect), isFalse);

      final editorPreview = find.byType(SegmentedButton<bool>).last;
      expect(tester.widget<SegmentedButton<bool>>(editorPreview).selected, {
        false,
      });
      final currentPosition = Scrollable.of(
        tester.element(previewLabel),
      ).position;
      currentPosition.jumpTo(currentPosition.maxScrollExtent - 420);
      await tester.pumpAndSettle();
      await tester.tap(previewLabel);
      await tester.pumpAndSettle();
      expect(tester.widget<SegmentedButton<bool>>(editorPreview).selected, {
        true,
      });
      await tester.tap(find.text('编辑').last);
      await tester.pumpAndSettle();
      expect(tester.widget<SegmentedButton<bool>>(editorPreview).selected, {
        false,
      });
      await tester.tap(find.byKey(const ValueKey('mobile-quick-capture')));
      await tester.pumpAndSettle();
      expect(find.byType(QuickCaptureSheet), findsOneWidget);
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
    },
  );
}
