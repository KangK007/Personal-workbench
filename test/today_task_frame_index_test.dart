import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_workbench/core/models/workspace_record.dart';
import 'package:personal_workbench/data/app_database.dart';
import 'package:personal_workbench/data/backup_service.dart';
import 'package:personal_workbench/services/focus_service.dart';
import 'package:personal_workbench/services/notification_service.dart';
import 'package:personal_workbench/services/search_service.dart';
import 'package:personal_workbench/services/share_capture_service.dart';
import 'package:personal_workbench/services/supabase_sync_service.dart';
import 'package:personal_workbench/state/workbench_controller.dart';

class _MemoryDatabase extends AppDatabase {
  @override
  Future<void> saveRecord(
    WorkspaceRecord record, {
    bool markDirty = true,
  }) async {}

  @override
  Future<void> saveRecords(
    Iterable<WorkspaceRecord> records, {
    bool markDirty = true,
  }) async {}

  @override
  Future<void> close() async {}
}

void main() {
  testWidgets('today task frame lookup respects the logical day and updates', (
    tester,
  ) async {
    final controller = WorkbenchController(
      database: _MemoryDatabase(),
      backupService: BackupService(),
      searchService: SearchService(),
      focusService: FocusService(),
      notificationService: NotificationService(),
      shareCaptureService: ShareCaptureService(),
      syncService: SupabaseSyncService(null),
      now: () => DateTime(2026, 8, 10, 12),
    );
    addTearDown(controller.dispose);

    Future<void> add(String title, DateTime when) => controller.addRecord(
      WorkspaceRecord.create(
        kind: RecordKind.task,
        title: title,
        scheduledFor: when,
      ),
    );
    await add('previous', DateTime(2026, 8, 10, 3, 59));
    await add('first', DateTime(2026, 8, 10, 4));
    await add('last', DateTime(2026, 8, 11, 3, 59));
    await add('next', DateTime(2026, 8, 11, 4));

    Map<String, List<String>> observed = {};
    Widget page() => Directionality(
      textDirection: TextDirection.ltr,
      child: Builder(
        builder: (_) {
          observed = {
            for (final (label, day) in [
              ('previous', DateTime(2026, 8, 9, 12)),
              ('today', DateTime(2026, 8, 10, 12)),
              ('next', DateTime(2026, 8, 11, 12)),
            ])
              label: controller
                  .tasksForDay(day)
                  .map((task) => task.title)
                  .toList(),
          };
          return const SizedBox.shrink();
        },
      ),
    );

    await tester.pumpWidget(page());
    expect(observed['previous'], ['previous']);
    expect(observed['today'], ['first', 'last']);
    expect(observed['next'], ['next']);

    await add('added', DateTime(2026, 8, 10, 18));
    await tester.pumpWidget(page());
    expect(observed['today'], ['first', 'added', 'last']);
  });
}
