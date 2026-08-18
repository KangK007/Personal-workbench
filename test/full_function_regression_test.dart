import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_workbench/core/models/workspace_record.dart';
import 'package:personal_workbench/core/models/attachment.dart';
import 'package:personal_workbench/data/app_database.dart';
import 'package:personal_workbench/data/backup_service.dart';
import 'package:personal_workbench/services/focus_service.dart';
import 'package:personal_workbench/services/notification_service.dart';
import 'package:personal_workbench/services/search_service.dart';
import 'package:personal_workbench/services/share_capture_service.dart';
import 'package:personal_workbench/services/supabase_sync_service.dart';
import 'package:personal_workbench/state/workbench_controller.dart';

String _key(WorkspaceRecord record) => '${record.kind.name}:${record.id}';

class _MemoryDatabase extends AppDatabase {
  final Map<String, WorkspaceRecord> records = {};
  final Map<String, String> metadata = {};

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
  Future<void> permanentlyDelete(String id, RecordKind kind) async {
    records.remove('${kind.name}:$id');
  }

  @override
  Future<List<Attachment>> loadAttachments({String? ownerRecordId}) async =>
      const [];

  @override
  Future<String?> readMetadata(String key) async => metadata[key];

  @override
  Future<void> writeMetadata(String key, String value) async {
    metadata[key] = value;
  }

  @override
  Future<void> close() async {}
}

final _now = DateTime(2026, 8, 10, 10);

WorkbenchController _controller(_MemoryDatabase database) =>
    WorkbenchController(
      database: database,
      backupService: BackupService(),
      searchService: SearchService(),
      focusService: FocusService(),
      notificationService: NotificationService(),
      shareCaptureService: ShareCaptureService(),
      syncService: SupabaseSyncService(null),
      now: () => _now,
    );

void main() {
  test(
    'quick capture validates input and creates every supported kind',
    () async {
      final controller = _controller(_MemoryDatabase());
      addTearDown(controller.dispose);

      await expectLater(
        controller.quickCapture(kind: RecordKind.task, text: '   '),
        throwsFormatException,
      );
      await expectLater(
        controller.quickCapture(kind: RecordKind.link, text: 'example.com'),
        throwsFormatException,
      );

      final task = await controller.quickCapture(
        kind: RecordKind.task,
        text: '  Verify sampling  ',
      );
      final note = await controller.quickCapture(
        kind: RecordKind.note,
        text: 'Experiment note',
        body: 'Keep the raw image unchanged.',
      );
      final diary = await controller.quickCapture(
        kind: RecordKind.diary,
        text: 'Daily review',
      );
      final link = await controller.quickCapture(
        kind: RecordKind.link,
        text: 'https://example.com/paper',
      );

      expect(task.title, 'Verify sampling');
      expect(task.status, WorkStatus.inbox);
      expect(task.hasCtdpProtocol, isFalse);
      expect(note.data['inbox'], isTrue);
      expect(diary.scheduledFor, _now);
      expect(link.data['url'], 'https://example.com/paper');
      expect(controller.allRecords, hasLength(5));
      expect(controller.taskDefinitions, hasLength(1));
      expect(controller.tasks, hasLength(1));
    },
  );

  test(
    'record lifecycle, relations, and permanent deletion stay consistent',
    () async {
      final database = _MemoryDatabase();
      final controller = _controller(database);
      addTearDown(controller.dispose);
      final source = WorkspaceRecord.create(
        kind: RecordKind.note,
        title: 'Source note',
      );
      final target = WorkspaceRecord.create(
        kind: RecordKind.project,
        title: 'Target project',
      );
      await controller.addRecord(source);
      await controller.addRecord(target);

      await controller.addRelation(source: source, target: target);
      await controller.addRelation(source: source, target: target);
      expect(controller.recordsOf(RecordKind.relation), hasLength(1));
      expect(controller.linkedRecords(source).single.id, target.id);

      await controller.moveToTrash(source);
      expect(controller.notes, isEmpty);
      expect(controller.trashRecords.single.id, source.id);
      await controller.restoreFromTrash(controller.trashRecords.single);
      expect(controller.notes.single.id, source.id);
      await controller.permanentlyDelete(controller.notes.single);

      expect(
        controller.allRecords.any((record) => record.id == source.id),
        isFalse,
      );
      expect(database.records.containsKey(_key(source)), isFalse);
    },
  );

  test(
    'time blocks, focus, diary, and habit logs cover boundary updates',
    () async {
      final controller = _controller(_MemoryDatabase());
      addTearDown(controller.dispose);
      final task = WorkspaceRecord.create(
        kind: RecordKind.task,
        title: 'Calibrate system',
        status: WorkStatus.inbox,
      );
      final habit = WorkspaceRecord.create(
        kind: RecordKind.habit,
        title: 'Write lab note',
      );
      await controller.addRecord(task);
      await controller.addRecord(habit);

      await controller.createTimeBlock(task: task, start: _now, minutes: 1);
      final block = controller.timeBlocks.single;
      expect(block.data['durationMinutes'], 5);
      expect(controller.tasks.single.status, WorkStatus.todo);
      await controller.updateTimeBlock(
        block: block,
        start: _now.add(const Duration(hours: 1)),
        minutes: 900,
      );
      expect(controller.timeBlocks.single.data['durationMinutes'], 720);

      await controller.completeFocusSession(
        controller.tasks.single,
        Duration.zero,
        FocusMode.stopwatch,
      );
      expect(controller.recordsOf(RecordKind.focusSession), isEmpty);
      await controller.completeFocusSession(
        controller.tasks.single,
        const Duration(seconds: 59),
        FocusMode.stopwatch,
        description: '  calibration  ',
        notes: '  stable  ',
        earlyCompletion: true,
      );
      expect(controller.recordsOf(RecordKind.focusSession), hasLength(1));
      expect(controller.tasks.single.actualMinutes, 1);

      await controller.saveDiary(
        day: _now,
        title: '',
        body: 'First version',
        mood: 9,
      );
      await controller.saveDiary(
        day: _now,
        title: 'Updated review',
        body: 'Second version',
        mood: -2,
      );
      expect(controller.diaries, hasLength(1));
      expect(controller.diaries.single.title, 'Updated review');
      expect(controller.diaries.single.data['mood'], 1);

      await controller.logHabit(habit, _now, WorkStatus.done);
      await controller.logHabit(habit, _now, WorkStatus.skipped);
      expect(controller.recordsOf(RecordKind.habitLog), hasLength(1));
      expect(
        controller.recordsOf(RecordKind.habitLog).single.status,
        WorkStatus.skipped,
      );
    },
  );

  test('appearance and profile settings are trimmed and persisted', () async {
    final database = _MemoryDatabase();
    final controller = _controller(database);
    addTearDown(controller.dispose);

    await controller.setThemeMode(ThemeMode.dark);
    await controller.setNavigationCollapsed(true);
    await controller.setRsipAllowMultiplePerDay(true);
    await controller.setProfileAlias('  Researcher  ');

    expect(controller.themeMode, ThemeMode.dark);
    expect(controller.navigationCollapsed, isTrue);
    expect(controller.rsipAllowMultiplePerDay, isTrue);
    expect(controller.profileAlias, 'Researcher');
    expect(database.metadata, {
      'theme_mode': 'dark',
      'navigation_collapsed': 'true',
      'rsip_strict_mode': 'false',
      'rsip_allow_multiple_per_day': 'true',
    });
  });

  test(
    'JSON, CSV, Markdown, and text imports handle normal and duplicate data',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'workbench-formats-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final controller = _controller(_MemoryDatabase());
      addTearDown(controller.dispose);
      final importedTask = WorkspaceRecord.create(
        kind: RecordKind.task,
        title: 'Imported JSON task',
      );
      final jsonFile = File(
        '${directory.path}${Platform.pathSeparator}records.json',
      );
      final csvFile = File(
        '${directory.path}${Platform.pathSeparator}records.csv',
      );
      final markdownFile = File(
        '${directory.path}${Platform.pathSeparator}record.md',
      );
      final textFile = File(
        '${directory.path}${Platform.pathSeparator}record.txt',
      );
      await jsonFile.writeAsString(jsonEncode([importedTask.toJson()]));
      await csvFile.writeAsString(
        'title,description\nTask A,Body A\n,ignored\nTask B,Body B\n',
      );
      await markdownFile.writeAsString('# Optical notes\nKeep units explicit.');
      await textFile.writeAsString('\nPlain text note');

      expect(await controller.importFile(jsonFile.path), 1);
      expect(await controller.importFile(jsonFile.path), 1);
      expect(await controller.importFile(csvFile.path), 2);
      expect(await controller.importFile(markdownFile.path), 1);
      expect(await controller.importFile(textFile.path), 1);

      expect(
        controller.tasks.where(
          (task) => task.title.startsWith('Imported JSON task'),
        ),
        hasLength(2),
      );
      expect(
        controller.tasks.any(
          (task) => task.title == 'Imported JSON task（导入副本）',
        ),
        isTrue,
      );
      expect(
        controller.notes.any((note) => note.title == 'Optical notes'),
        isTrue,
      );
      expect(
        controller.notes.any((note) => note.title == 'Plain text note'),
        isTrue,
      );
    },
  );

  test(
    'imports reject missing, unsupported, and malformed files without changes',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'workbench-invalid-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final controller = _controller(_MemoryDatabase());
      addTearDown(controller.dispose);
      final unsupported = File(
        '${directory.path}${Platform.pathSeparator}records.xml',
      );
      final malformed = File(
        '${directory.path}${Platform.pathSeparator}records.json',
      );
      await unsupported.writeAsString('<records />');
      await malformed.writeAsString('{"not": "a list"}');

      await expectLater(
        controller.importFile(
          '${directory.path}${Platform.pathSeparator}missing.txt',
        ),
        throwsFormatException,
      );
      await expectLater(
        controller.importFile(unsupported.path),
        throwsFormatException,
      );
      await expectLater(
        controller.importFile(malformed.path),
        throwsA(isA<Object>()),
      );
      expect(controller.allRecords, isEmpty);
    },
  );
}
