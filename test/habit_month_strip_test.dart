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
  for (final scenario in [(320.0, 1.0), (390.0, 1.0), (320.0, 2.0)]) {
    final (width, textScale) = scenario;
    testWidgets(
      'habit month stays readable and scrollable at ${width.toInt()}dp / ${textScale}x text',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 700);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);

        final today = DateTime(2026, 8, 19, 10);
        final controller = WorkbenchController(
          database: _MemoryDatabase(),
          backupService: BackupService(),
          searchService: SearchService(),
          focusService: FocusService(),
          notificationService: NotificationService(),
          shareCaptureService: ShareCaptureService(),
          syncService: SupabaseSyncService(null),
          now: () => today,
        );
        addTearDown(controller.dispose);
        final habit = WorkspaceRecord.create(
          kind: RecordKind.habit,
          title: '每日整理资料',
          data: const {'frequency': 'daily'},
        );
        await controller.addRecord(habit);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            home: Scaffold(
              body: HabitsPage(controller: controller, showHeader: false),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final strip = find.byWidgetPredicate(
          (widget) =>
              widget is SingleChildScrollView &&
              widget.scrollDirection == Axis.horizontal,
        );
        final todayCell = find.byTooltip('修改今日打卡');
        final dayLabel = find.byKey(
          ValueKey('habit-day:${habit.id}:2026-8-19'),
        );
        expect(strip, findsOneWidget);
        expect(find.text('近两周 · 今天可点按修改'), findsOneWidget);
        expect(find.text('展开整月'), findsOneWidget);
        expect(
          find.byKey(ValueKey('habit-day:${habit.id}:2026-8-5')),
          findsNothing,
        );
        expect(todayCell, findsOneWidget);
        expect(tester.getSize(todayCell).width, greaterThanOrEqualTo(48));
        expect(tester.getSize(todayCell).height, greaterThanOrEqualTo(48));

        final before = tester.getTopLeft(dayLabel).dx;
        await tester.drag(strip, const Offset(80, 0));
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(dayLabel).dx, greaterThan(before));
        await tester.tap(find.text('展开整月'));
        await tester.pumpAndSettle();
        expect(find.text('左右滑动查看整月 · 今天可点按修改'), findsOneWidget);
        expect(
          find.byKey(ValueKey('habit-day:${habit.id}:2026-8-1')),
          findsOneWidget,
        );
        expect(
          find.byKey(ValueKey('habit-day:${habit.id}:2026-8-31')),
          findsOneWidget,
        );
        await tester.tap(find.text('收起整月'));
        await tester.pumpAndSettle();
        expect(find.text('近两周 · 今天可点按修改'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
