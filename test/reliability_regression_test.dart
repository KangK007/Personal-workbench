import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_workbench/core/models/workspace_record.dart';
import 'package:personal_workbench/core/models/attachment.dart';
import 'package:personal_workbench/core/models/game_state.dart';
import 'package:personal_workbench/data/app_database.dart';
import 'package:personal_workbench/data/backup_service.dart';
import 'package:personal_workbench/services/focus_service.dart';
import 'package:personal_workbench/services/attachment_service.dart';
import 'package:personal_workbench/services/notification_service.dart';
import 'package:personal_workbench/services/search_service.dart';
import 'package:personal_workbench/services/share_capture_service.dart';
import 'package:personal_workbench/services/supabase_sync_service.dart';
import 'package:personal_workbench/state/workbench_controller.dart';
import 'package:personal_workbench/ui/platform_feedback.dart';
import 'package:sqflite/sqflite.dart' show Database;

String _key(WorkspaceRecord record) => '${record.kind.name}:${record.id}';

class _MemoryDatabase extends AppDatabase {
  final Map<String, WorkspaceRecord> records = {};
  String? localGameState;

  @override
  Future<void> saveRecord(
    WorkspaceRecord record, {
    bool markDirty = true,
  }) async {
    records[_key(record)] = record.copyWith(
      syncState: markDirty ? SyncState.dirty : SyncState.clean,
      touch: false,
    );
  }

  @override
  Future<void> replaceAll(
    Iterable<WorkspaceRecord> values, {
    bool markDirty = true,
  }) async {
    records
      ..clear()
      ..addEntries(
        values.map(
          (record) => MapEntry(
            _key(record),
            record.copyWith(
              syncState: markDirty ? SyncState.dirty : SyncState.clean,
              touch: false,
            ),
          ),
        ),
      );
  }

  @override
  Future<void> replaceAllWithAttachments(
    Iterable<WorkspaceRecord> values,
    Iterable<Attachment> attachments, {
    bool markDirty = true,
  }) => replaceAll(values, markDirty: markDirty);

  @override
  Future<String?> readLocalGameState() async => localGameState;

  @override
  Future<void> writeLocalGameState(String value) async {
    localGameState = value;
  }

  @override
  Future<void> close() async {}
}

class _FailingDatabase extends AppDatabase {
  @override
  Future<Database> get database => Future.error(Exception('open failed'));

  @override
  Future<void> close() async {}
}

WorkbenchController _controller(
  _MemoryDatabase database, {
  AttachmentService? attachmentService,
  BackupService? backupService,
}) => WorkbenchController(
  database: database,
  backupService: backupService ?? BackupService(),
  searchService: SearchService(),
  focusService: FocusService(),
  notificationService: NotificationService(),
  shareCaptureService: ShareCaptureService(),
  syncService: SupabaseSyncService(null),
  attachmentService: attachmentService,
  now: () => DateTime(2026, 8, 9, 10),
);

void main() {
  test('initialization failures leave a retryable error state', () async {
    final controller = WorkbenchController(
      database: _FailingDatabase(),
      backupService: BackupService(),
      searchService: SearchService(),
      focusService: FocusService(),
      notificationService: NotificationService(),
      shareCaptureService: ShareCaptureService(),
      syncService: SupabaseSyncService(null),
    );
    addTearDown(controller.dispose);

    await controller.initialize();

    expect(controller.loading, isFalse);
    expect(controller.error, contains('open failed'));
  });

  test('stable notification IDs keep a known value and valid range', () {
    expect(stableNotificationId('task:abc'), 1994244102);
    expect(stableNotificationId('task:abc'), inInclusiveRange(1, 0x7fffffff));
    expect(
      stableNotificationId('task:abc'),
      isNot(stableNotificationId('task:def')),
    );
  });

  test('text import stores only the source file name', () async {
    final directory = await Directory.systemTemp.createTemp(
      'workbench-import-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File(
      '${directory.path}${Platform.pathSeparator}private-note.txt',
    );
    await file.writeAsString('Research note');
    final database = _MemoryDatabase();
    final controller = _controller(database);
    addTearDown(controller.dispose);

    await controller.importFile(file.path);

    expect(controller.notes.single.data['importSource'], 'private-note.txt');
    expect(
      controller.notes.single.data['importSource'],
      isNot(contains(directory.path)),
    );
  });

  test('oversized imports are rejected before parsing', () async {
    final directory = await Directory.systemTemp.createTemp('workbench-large-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}${Platform.pathSeparator}large.txt');
    final handle = await file.open(mode: FileMode.write);
    await handle.truncate(10 * 1024 * 1024 + 1);
    await handle.close();
    final controller = _controller(_MemoryDatabase());
    addTearDown(controller.dispose);

    await expectLater(controller.importFile(file.path), throwsFormatException);
    expect(controller.notes, isEmpty);
  });

  test(
    'oversized backups are rejected before file contents are read',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'workbench-large-backup-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}${Platform.pathSeparator}large.pwb');
      await file.writeAsBytes(const [1, 2, 3, 4, 5]);
      final controller = _controller(
        _MemoryDatabase(),
        backupService: BackupService(
          limits: const BackupLimits(maxEncryptedFileBytes: 4),
        ),
      );
      addTearDown(controller.dispose);

      await expectLater(
        controller.previewBackup(file.path, 'correct-password'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('备份文件不能超过'),
          ),
        ),
      );
    },
  );

  test(
    'backup restore keeps restored records clean in memory and storage',
    () async {
      final database = _MemoryDatabase();
      final directory = await Directory.systemTemp.createTemp(
        'workbench-restore-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final controller = _controller(
        database,
        attachmentService: AttachmentService(
          database: database,
          root: directory,
        ),
      );
      addTearDown(controller.dispose);
      final record = WorkspaceRecord.create(
        kind: RecordKind.note,
        title: 'Restored note',
      );
      final bundle = BackupBundle(
        manifest: BackupManifest(
          version: 2,
          createdAt: DateTime(2026, 8, 9),
          recordCount: 1,
          kinds: const {'note': 1},
        ),
        records: [record],
        localGameState: Map<String, dynamic>.from(
          jsonDecode(
                LocalGameState(
                  profile: const GameProfile(points: 40),
                  removedFeatureData: const {
                    'pet': {'name': '墨玉'},
                  },
                ).encode(),
              )
              as Map,
        ),
      );

      await controller.restoreBackup(bundle);

      expect(controller.notes.single.syncState, SyncState.clean);
      expect(database.records.values.single.syncState, SyncState.clean);
      expect(controller.syncPhase, SyncPhase.localOnly);
      expect(controller.gameProfile.points, 40);
    },
  );

  test(
    'desktop notification and haptic APIs fail closed without platform plugins',
    () async {
      final service = NotificationService();
      expect(service.supportsSystemNotifications, isFalse);
      expect(await service.requestPermission(), isFalse);
      await service.scheduleTaskReminder(
        id: 1,
        title: 'Task',
        when: DateTime(2030),
      );
      await service.showNow(id: 1, title: 'Title', body: 'Body');
      await service.scheduleFocusEnd(
        id: 2,
        taskTitle: 'Focus',
        when: DateTime(2030),
        restMinutes: 5,
      );
      await service.cancel(1);
      await WorkbenchFeedback.selection();
      await WorkbenchFeedback.completion();
    },
  );
}
