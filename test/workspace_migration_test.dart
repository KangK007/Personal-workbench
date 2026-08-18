import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_workbench/core/models/workspace_record.dart';
import 'package:personal_workbench/data/app_database.dart';
import 'package:personal_workbench/data/workspace_migration.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);

  test(
    'v2 domain migration preserves sources and reconnects projects',
    () async {
      final database = AppDatabase(
        factory: databaseFactoryFfi,
        overridePath: inMemoryDatabasePath,
      );
      addTearDown(database.close);
      final day = DateTime(2026, 8, 9);
      final goal = WorkspaceRecord.create(
        kind: RecordKind.goal,
        title: '完成光学实验',
      );
      final task = WorkspaceRecord.create(
        kind: RecordKind.task,
        title: '校准光路',
        projectId: goal.id,
        scheduledFor: day,
      );
      final milestone = WorkspaceRecord.create(
        kind: RecordKind.milestone,
        title: '完成标定',
        parentId: goal.id,
        scheduledFor: day,
      );
      final habit = WorkspaceRecord.create(
        kind: RecordKind.habit,
        title: '记录实验日志',
        data: const {'frequency': 'weekdays'},
      );
      final habitLog = WorkspaceRecord.create(
        kind: RecordKind.habitLog,
        title: habit.title,
        parentId: habit.id,
        scheduledFor: day,
        status: WorkStatus.done,
      );
      final rsip = WorkspaceRecord.create(
        kind: RecordKind.habit,
        title: '国策节点',
        data: const {'protocol': 'rsip', 'rsipInternalization': 35},
      );
      final diary = WorkspaceRecord.create(
        kind: RecordKind.diary,
        title: '实验日记',
        body: '原始正文',
        scheduledFor: day,
      );
      final protocol = WorkspaceRecord.create(
        kind: RecordKind.protocolEvent,
        title: 'CTDP 历史',
        data: const {'protocol': 'ctdp', 'action': 'round_completed'},
      );
      final sources = [
        goal,
        task,
        milestone,
        habit,
        habitLog,
        rsip,
        diary,
        protocol,
      ];
      await database.saveRecords(sources);

      final report = await const WorkspaceMigration().migrateToVersionTwo(
        database: database,
        records: sources,
      );
      final records = await database.loadRecords();

      expect(report?.created, 5);
      expect(report?.updated, 7);
      expect(records.any((record) => record.id == protocol.id), isTrue);
      expect(records.where((record) => record.id == task.id), hasLength(1));
      final definition = records.singleWhere(
        (record) => record.id == 'v2-definition-${task.id}',
      );
      expect(definition.data['sourceId'], task.id);
      expect(definition.projectId, 'v2-project-${goal.id}');
      final instance = records.singleWhere((record) => record.id == task.id);
      expect(instance.data['recordType'], 'taskInstance');
      expect(instance.data['migratedToId'], definition.id);
      expect(instance.projectId, 'v2-project-${goal.id}');
      final migratedMilestone = records.singleWhere(
        (record) => record.id == milestone.id,
      );
      expect(migratedMilestone.parentId, goal.id);
      expect(migratedMilestone.projectId, 'v2-project-${goal.id}');
      final habitDefinition = records.singleWhere(
        (record) => record.id == 'v2-habit-definition-${habit.id}',
      );
      expect(habitDefinition.data['recurrence'], 'weekdays');
      expect(
        records
            .singleWhere((record) => record.id == rsip.id)
            .data['recordType'],
        'rsipNode',
      );
      final review = records.singleWhere(
        (record) => record.id == 'v2-review-${diary.id}',
      );
      expect(review.body, diary.body);
      expect(review.data['periodType'], 'daily');

      final metadata =
          jsonDecode((await database.readMetadata('domain_migration_v2'))!)
              as Map<String, dynamic>;
      expect(metadata['created'], report?.created);
      expect(metadata['updated'], report?.updated);
      final second = await const WorkspaceMigration().migrateToVersionTwo(
        database: database,
        records: records,
      );
      expect(second, isNull);
      expect(await database.loadRecords(), hasLength(records.length));
    },
  );

  test(
    'v3 migration normalizes RSIP, focus, and legacy reviews once',
    () async {
      final database = AppDatabase(
        factory: databaseFactoryFfi,
        overridePath: inMemoryDatabasePath,
      );
      addTearDown(database.close);
      final rsip = WorkspaceRecord.create(
        kind: RecordKind.habit,
        title: '旧国策',
        data: const {
          'protocol': 'rsip',
          'rsipGroup': '科研组',
          'rsipInternalization': 72,
          'rsipChainCount': 8,
        },
      );
      final focus = WorkspaceRecord.create(
        kind: RecordKind.template,
        title: '晨间专注',
        data: const {'recordType': 'focusPreset'},
      );
      final yearly = WorkspaceRecord.create(
        kind: RecordKind.note,
        title: '2025 年回顾',
        data: const {
          'recordType': 'periodReview',
          'periodType': 'yearly',
          'periodKey': '2025',
        },
      );
      await database.saveRecords([rsip, focus, yearly]);

      final report = await const WorkspaceMigration().migrateToVersionThree(
        database: database,
        records: [rsip, focus, yearly],
      );
      final records = await database.loadRecords();
      final migratedRsip = records.singleWhere((item) => item.id == rsip.id);
      final group = records.singleWhere(
        (item) => item.data['recordType'] == 'rsipNodeGroup',
      );

      expect(report?.created, 1);
      expect(migratedRsip.data['sourceId'], rsip.id);
      expect(migratedRsip.data['migratedToId'], rsip.id);
      expect(migratedRsip.data['rsipLegacyInternalization'], 72);
      expect(migratedRsip.data['rsipStage'], 'E1');
      expect(migratedRsip.data['rsipGroupId'], group.id);
      expect(
        records
            .singleWhere((item) => item.id == focus.id)
            .data['recordType'],
        'focusPreset',
      );
      expect(
        records
            .singleWhere((item) => item.id == yearly.id)
            .data['legacyReadOnly'],
        isTrue,
      );
      expect(await database.readMetadata('domain_migration_v3'), isNotNull);

      final second = await const WorkspaceMigration().migrateToVersionThree(
        database: database,
        records: records,
      );
      expect(second, isNull);
    },
  );
}
