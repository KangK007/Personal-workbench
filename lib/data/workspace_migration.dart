import 'dart:convert';

import '../core/models/workspace_record.dart';
import 'app_database.dart';

class WorkspaceMigrationReport {
  const WorkspaceMigrationReport({
    required this.created,
    required this.updated,
    required this.completedAt,
  });

  final int created;
  final int updated;
  final DateTime completedAt;

  Map<String, Object> toJson() => {
    'version': 2,
    'created': created,
    'updated': updated,
    'completedAt': completedAt.toUtc().toIso8601String(),
  };
}

class WorkspaceMigrationV3Report {
  const WorkspaceMigrationV3Report({
    required this.created,
    required this.updated,
    required this.rsipNodes,
    required this.rsipGroups,
    required this.reviews,
    required this.completedAt,
  });

  final int created;
  final int updated;
  final int rsipNodes;
  final int rsipGroups;
  final int reviews;
  final DateTime completedAt;

  Map<String, Object> toJson() => {
    'version': 3,
    'created': created,
    'updated': updated,
    'rsipNodes': rsipNodes,
    'rsipGroups': rsipGroups,
    'reviews': reviews,
    'completedAt': completedAt.toUtc().toIso8601String(),
  };
}

class WorkspaceMigration {
  const WorkspaceMigration();

  Future<WorkspaceMigrationReport?> migrateToVersionTwo({
    required AppDatabase database,
    required List<WorkspaceRecord> records,
  }) async {
    if (await database.readMetadata('domain_migration_v2') != null) {
      return null;
    }
    if (records.isEmpty) return null;

    final changes = <WorkspaceRecord>[];
    var created = 0;
    var updated = 0;
    final now = DateTime.now();
    final goalProjectIds = {
      for (final record in records.where(
        (value) => value.kind == RecordKind.goal,
      ))
        record.id: 'v2-project-${record.id}',
    };

    for (final record in records.where((value) => !value.isDeleted)) {
      if (record.kind == RecordKind.task && record.data['recordType'] == null) {
        final definitionId = 'v2-definition-${record.id}';
        changes.add(
          _copyRecord(
            record,
            id: definitionId,
            status: WorkStatus.todo,
            projectId: goalProjectIds[record.projectId],
            data: {
              ...record.data,
              'recordType': 'taskDefinition',
              'sourceId': record.id,
              'migratedToId': definitionId,
              'migrationVersion': 2,
            },
          ),
        );
        changes.add(
          record.copyWith(
            projectId: goalProjectIds[record.projectId] ?? record.projectId,
            data: {
              ...record.data,
              'recordType': 'taskInstance',
              'definitionId': definitionId,
              'occurrenceKey': _dateKey(record.scheduledFor),
              'sourceId': record.id,
              'migratedToId': definitionId,
              'migrationVersion': 2,
            },
          ),
        );
        created++;
        updated++;
        continue;
      }

      if (record.kind == RecordKind.habit) {
        if (record.hasRsipProtocol) {
          changes.add(
            record.copyWith(
              data: {
                ...record.data,
                'recordType': 'rsipNode',
                'sourceId': record.id,
                'migratedToId': record.id,
                'migrationVersion': 2,
              },
            ),
          );
          updated++;
        } else if (record.data['migratedToId'] == null) {
          final definitionId = 'v2-habit-definition-${record.id}';
          changes.add(
            _copyRecord(
              record,
              id: definitionId,
              kind: RecordKind.task,
              projectId: goalProjectIds[record.projectId],
              data: {
                ...record.data,
                'recordType': 'taskDefinition',
                'recurrence': _habitRecurrence(record),
                'sourceId': record.id,
                'migrationVersion': 2,
              },
            ),
          );
          changes.add(
            record.copyWith(
              data: {
                ...record.data,
                'migratedToId': definitionId,
                'migrationVersion': 2,
              },
            ),
          );
          created++;
          updated++;
        }
        continue;
      }

      if (record.kind == RecordKind.habitLog &&
          record.data['migratedToId'] == null &&
          record.parentId != null) {
        final instanceId = 'v2-habit-instance-${record.id}';
        changes.add(
          _copyRecord(
            record,
            id: instanceId,
            kind: RecordKind.task,
            data: {
              ...record.data,
              'recordType': 'taskInstance',
              'definitionId': 'v2-habit-definition-${record.parentId}',
              'occurrenceKey': _dateKey(record.scheduledFor),
              'sourceId': record.id,
              'migrationVersion': 2,
            },
          ),
        );
        changes.add(
          record.copyWith(
            data: {
              ...record.data,
              'migratedToId': instanceId,
              'migrationVersion': 2,
            },
          ),
        );
        created++;
        updated++;
        continue;
      }

      if (record.kind == RecordKind.goal &&
          record.data['migratedToId'] == null) {
        final projectId = 'v2-project-${record.id}';
        changes.add(
          _copyRecord(
            record,
            id: projectId,
            kind: RecordKind.project,
            data: {
              ...record.data,
              'recordType': 'project',
              'sourceId': record.id,
              'migrationVersion': 2,
            },
          ),
        );
        changes.add(
          record.copyWith(
            data: {
              ...record.data,
              'migratedToId': projectId,
              'migrationVersion': 2,
            },
          ),
        );
        created++;
        updated++;
        continue;
      }

      if (record.kind == RecordKind.milestone &&
          record.parentId != null &&
          goalProjectIds.containsKey(record.parentId)) {
        changes.add(
          record.copyWith(
            projectId: goalProjectIds[record.parentId],
            data: {
              ...record.data,
              'sourceId': record.id,
              'migratedToId': record.id,
              'migratedFromGoalId': record.parentId,
              'migrationVersion': 2,
            },
          ),
        );
        updated++;
        continue;
      }

      if (record.kind == RecordKind.diary &&
          record.data['migratedToId'] == null) {
        final reviewId = 'v2-review-${record.id}';
        final type = record.data['periodType']?.toString() ?? 'daily';
        changes.add(
          _copyRecord(
            record,
            id: reviewId,
            kind: RecordKind.note,
            data: {
              ...record.data,
              'recordType': 'periodReview',
              'periodType': type,
              'periodKey':
                  record.data['periodKey'] ?? _dateKey(record.scheduledFor),
              'sourceId': record.id,
              'versions': const <Map<String, dynamic>>[],
              'migrationVersion': 2,
            },
          ),
        );
        changes.add(
          record.copyWith(
            data: {
              ...record.data,
              'migratedToId': reviewId,
              'migrationVersion': 2,
            },
          ),
        );
        created++;
        updated++;
      }
    }

    final report = WorkspaceMigrationReport(
      created: created,
      updated: updated,
      completedAt: now,
    );
    await database.applyDomainMigration(changes, jsonEncode(report.toJson()));
    return report;
  }

  Future<WorkspaceMigrationV3Report?> migrateToVersionThree({
    required AppDatabase database,
    required List<WorkspaceRecord> records,
  }) async {
    if (await database.readMetadata('domain_migration_v3') != null) {
      return null;
    }

    final changes = <WorkspaceRecord>[];
    final groupsByName = <String, WorkspaceRecord>{};
    var updated = 0;
    var rsipNodes = 0;
    var reviews = 0;

    for (final record in records.where((value) => !value.isDeleted)) {
      if (record.hasRsipProtocol) {
        final groupName = record.data['rsipGroup']?.toString().trim() ?? '';
        String? groupId = record.data['rsipGroupId']?.toString();
        if (groupId == null && groupName.isNotEmpty) {
          final encoded = base64Url
              .encode(utf8.encode(groupName))
              .replaceAll('=', '');
          groupId = 'v3-rsip-group-$encoded';
          groupsByName.putIfAbsent(
            groupName,
            () => WorkspaceRecord(
              id: groupId!,
              kind: RecordKind.template,
              title: groupName,
              createdAt: record.createdAt,
              updatedAt: DateTime.now(),
              data: const {
                'recordType': 'rsipNodeGroup',
                'emoji': '组',
                'initialTolerance': 0,
                'remainingTolerance': 0,
                'migrationVersion': 3,
              },
            ),
          );
        }
        final chain = record.rsipChainCount;
        final stage = chain >= 21
            ? 'E2'
            : chain >= 7
            ? 'E1'
            : 'E0';
        changes.add(
          record.copyWith(
            data: {
              ...record.data,
              'recordType': 'rsipNode',
              'sourceId': record.data['sourceId'] ?? record.id,
              'migratedToId': record.data['migratedToId'] ?? record.id,
              'migrationVersion': 3,
              'rsipNodeType':
                  record.data['rsipNodeType']?.toString() ?? 'policy',
              'rsipEmoji': record.data['rsipEmoji']?.toString() ?? '策',
              'rsipPassive': record.data['rsipPassive'] == true,
              'rsipStage': (record.data['rsipStage']?.toString() ?? stage)
                  .toUpperCase(),
              'rsipCumulativeExecutionDays':
                  (record.data['rsipCumulativeExecutionDays'] as num?)
                      ?.toInt() ??
                  chain,
              'rsipTotalExecutions':
                  (record.data['rsipTotalExecutions'] as num?)?.toInt() ??
                  chain,
              'rsipTotalViolations':
                  (record.data['rsipTotalViolations'] as num?)?.toInt() ??
                  record.rsipFailureCount,
              'rsipReinforcement':
                  (record.data['rsipReinforcement'] as num?)?.toInt() ?? 0,
              'rsipGroupId': ?groupId,
              if (record.data['rsipLegacyInternalization'] == null)
                'rsipLegacyInternalization': record.rsipInternalization,
            },
          ),
        );
        updated++;
        rsipNodes++;
        continue;
      }

      if (record.kind == RecordKind.note &&
          record.data['recordType'] == 'periodReview' &&
          record.data['reviewSchemaVersion'] != 3) {
        final yearly = record.data['periodType'] == 'yearly';
        changes.add(
          record.copyWith(
            data: {
              ...record.data,
              'reviewSchemaVersion': 3,
              if (yearly) 'legacyReadOnly': true,
            },
          ),
        );
        updated++;
        reviews++;
      }
    }

    changes.addAll(groupsByName.values);
    final report = WorkspaceMigrationV3Report(
      created: groupsByName.length,
      updated: updated,
      rsipNodes: rsipNodes,
      rsipGroups: groupsByName.length,
      reviews: reviews,
      completedAt: DateTime.now(),
    );
    await database.applyDomainMigration(
      changes,
      jsonEncode(report.toJson()),
      metadataKey: 'domain_migration_v3',
    );
    return report;
  }
}

WorkspaceRecord _copyRecord(
  WorkspaceRecord source, {
  required String id,
  RecordKind? kind,
  String? status,
  String? projectId,
  required Map<String, dynamic> data,
}) {
  return WorkspaceRecord(
    id: id,
    kind: kind ?? source.kind,
    title: source.title,
    body: source.body,
    status: status ?? source.status,
    scheduledFor: source.scheduledFor,
    dueAt: source.dueAt,
    projectId: projectId ?? source.projectId,
    parentId: source.parentId,
    tags: source.tags,
    favorite: source.favorite,
    createdAt: source.createdAt,
    updatedAt: DateTime.now(),
    deletedAt: source.deletedAt,
    data: data,
  );
}

String _dateKey(DateTime? value) {
  if (value == null) return '';
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

String _habitRecurrence(WorkspaceRecord record) {
  return switch (record.data['frequency']?.toString()) {
    'weekdays' => 'weekdays',
    'weekly' => 'weekly',
    'monthly' => 'monthly',
    'yearly' => 'yearly',
    _ => 'daily',
  };
}
