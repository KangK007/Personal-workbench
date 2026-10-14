import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_workbench/core/models/workspace_record.dart';
import 'package:personal_workbench/data/app_database.dart';
import 'package:personal_workbench/services/growth_service.dart';

// Flutter test supplies dart:ui for AppDatabase's path_provider dependency.
// Run with WORKBENCH_PROFILE_SEED_PATH set to a new temporary SQLite path.
void main() {
  test('seed an isolated Windows Profile database', () async {
    final target = Platform.environment['WORKBENCH_PROFILE_SEED_PATH'];
    if (target == null || target.isEmpty) {
      throw StateError('WORKBENCH_PROFILE_SEED_PATH is required');
    }
    await _seedDatabase(target);
  });
}

Future<void> _seedDatabase(String target) async {
  final path = File(target).absolute;
  if (await path.exists()) {
    throw StateError(
      'Refusing to overwrite an existing database: ${path.path}',
    );
  }

  final growth = const GrowthService();
  final now = DateTime.now();
  final logicalDay = growth.logicalDay(now);
  final today = DateTime(logicalDay.year, logicalDay.month, logicalDay.day, 12);
  final records = <WorkspaceRecord>[];
  final projects = <WorkspaceRecord>[
    for (var index = 0; index < 12; index++)
      WorkspaceRecord.create(
        kind: RecordKind.project,
        title: '性能验证项目 ${index.toString().padLeft(2, '0')}',
      ),
  ];
  records.addAll(projects);
  final todayTasks = <WorkspaceRecord>[];
  for (var index = 0; index < 600; index++) {
    final scheduledFor = index < 120
        ? today.add(Duration(minutes: index % 360))
        : today.add(Duration(days: 1 + (index % 7)));
    final projectId = projects[index % projects.length].id;
    final definition = WorkspaceRecord.create(
      kind: RecordKind.task,
      title: '批量任务 ${index.toString().padLeft(3, '0')}',
      scheduledFor: scheduledFor,
      projectId: projectId,
      data: const {'recordType': 'taskDefinition', 'recurrence': 'none'},
    );
    final instance = WorkspaceRecord.create(
      kind: RecordKind.task,
      title: definition.title,
      status: index >= 3 && index % 7 == 0 ? WorkStatus.done : WorkStatus.todo,
      scheduledFor: scheduledFor,
      dueAt: scheduledFor.add(const Duration(days: 1)),
      projectId: projectId,
      data: {
        'recordType': 'taskInstance',
        'definitionId': definition.id,
        'occurrenceKey': growth.dayKey(scheduledFor),
        'estimatedMinutes': 20 + index % 45,
        'priority': 1 + index % 3,
      },
    );
    records
      ..add(definition.withData('sourceId', instance.id))
      ..add(instance);
    if (index < 120) todayTasks.add(instance);
  }
  records.add(
    WorkspaceRecord.create(
      kind: RecordKind.dailyPlan,
      title: '今日承诺',
      status: WorkStatus.doing,
      scheduledFor: logicalDay,
      data: {
        'dayKey': growth.dayKey(now),
        'commitmentIds': todayTasks.take(3).map((task) => task.id).toList(),
        'plannedHabitIds': <String>[],
        'previousFocusIds': <String>[],
        'replacements': <Map<String, dynamic>>[],
        'startedAt': now.toUtc().toIso8601String(),
      },
    ),
  );

  final database = AppDatabase(overridePath: path.path);
  try {
    await database.saveRecords(records, markDirty: false);
    final saved = await database.loadRecords();
    if (saved.length != records.length) {
      throw StateError('Saved ${saved.length} of ${records.length} records');
    }
    stdout.writeln(
      'Seeded ${path.path}: 600 task definitions, 600 task instances '
      '(120 today), 12 projects, 1 daily plan.',
    );
  } finally {
    await database.close();
  }
}
