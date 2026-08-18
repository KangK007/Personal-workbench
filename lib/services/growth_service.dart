import '../core/models/workspace_record.dart';

class GrowthSnapshot {
  const GrowthSnapshot({
    required this.totalXp,
    required this.level,
    required this.levelXp,
    required this.nextLevelXp,
    required this.streak,
    required this.closedDays,
    required this.availableRecoveries,
    required this.categoryXp,
  });

  final int totalXp;
  final int level;
  final int levelXp;
  final int nextLevelXp;
  final int streak;
  final int closedDays;
  final int availableRecoveries;
  final Map<String, int> categoryXp;

  double get levelProgress => nextLevelXp == 0 ? 0 : levelXp / nextLevelXp;
}

class GrowthService {
  const GrowthService({this.logicalDayBoundaryHour = 4});

  final int logicalDayBoundaryHour;

  DateTime logicalDay(DateTime value) {
    final local = value.toLocal();
    final shifted = local.subtract(Duration(hours: logicalDayBoundaryHour));
    return DateTime(shifted.year, shifted.month, shifted.day);
  }

  String dayKey(DateTime value) {
    final day = logicalDay(value);
    return '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
  }

  WorkspaceRecord? planForDay(
    Iterable<WorkspaceRecord> records,
    DateTime value,
  ) {
    final key = dayKey(value);
    for (final record in records) {
      if (!record.isDeleted &&
          record.kind == RecordKind.dailyPlan &&
          record.data['dayKey'] == key) {
        return record;
      }
    }
    return null;
  }

  DateTime? recoveryCandidate(Iterable<WorkspaceRecord> records, DateTime now) {
    final active = records.where((record) => !record.isDeleted);
    final closedKeys = active
        .where(
          (record) =>
              record.kind == RecordKind.dailyPlan &&
              record.data['closedAt'] != null,
        )
        .map((record) => record.data['dayKey']?.toString())
        .whereType<String>()
        .toSet();
    final plannedKeys = active
        .where((record) => record.kind == RecordKind.dailyPlan)
        .map((record) => record.data['dayKey']?.toString())
        .whereType<String>()
        .toSet();
    final today = logicalDay(now);
    for (var offset = 1; offset <= 14; offset++) {
      final candidate = today.subtract(Duration(days: offset));
      final key = dayKey(candidate);
      final hasClosedNextDay =
          offset == 1 ||
          closedKeys.contains(dayKey(candidate.add(const Duration(days: 1))));
      if (!plannedKeys.contains(key) && hasClosedNextDay) return candidate;
    }
    return null;
  }

  GrowthSnapshot snapshot(Iterable<WorkspaceRecord> records, DateTime now) {
    final active = records.where((record) => !record.isDeleted).toList();
    final events = active.where(
      (record) => record.kind == RecordKind.growthEvent,
    );
    var totalXp = 0;
    final categories = <String, int>{};
    for (final event in events) {
      final xp = (event.data['xp'] as num?)?.toInt() ?? 0;
      totalXp += xp;
      final category = event.data['category']?.toString() ?? 'other';
      categories.update(category, (value) => value + xp, ifAbsent: () => xp);
    }
    totalXp = totalXp.clamp(0, 1 << 30);

    var level = 1;
    var remaining = totalXp;
    while (level < 16 && remaining >= xpForNextLevel(level)) {
      remaining -= xpForNextLevel(level);
      level++;
    }
    if (level == 16 && remaining >= 1000) {
      level += remaining ~/ 1000;
      remaining %= 1000;
    }

    final closed = active
        .where(
          (record) =>
              record.kind == RecordKind.dailyPlan &&
              record.data['closedAt'] != null,
        )
        .toList();
    final closedKeys = closed
        .map((record) => record.data['dayKey']?.toString())
        .whereType<String>()
        .toSet();
    var streak = 0;
    var cursor = logicalDay(now);
    if (!closedKeys.contains(dayKey(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    while (closedKeys.contains(dayKey(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    final usedRecoveries = active.where((record) {
      return record.kind == RecordKind.growthEvent &&
          record.data['category'] == 'recovery' &&
          ((record.data['used'] as bool?) ?? false);
    }).length;
    final available = ((closed.length ~/ 14) - usedRecoveries).clamp(0, 2);

    return GrowthSnapshot(
      totalXp: totalXp,
      level: level,
      levelXp: remaining,
      nextLevelXp: xpForNextLevel(level),
      streak: streak,
      closedDays: closed.length,
      availableRecoveries: available,
      categoryXp: Map.unmodifiable(categories),
    );
  }

  int xpForNextLevel(int level) => (250 + 50 * (level - 1)).clamp(250, 1000);

  int netXpForBaseKey(Iterable<WorkspaceRecord> records, String baseKey) {
    return records
        .where(
          (record) =>
              !record.isDeleted &&
              record.kind == RecordKind.growthEvent &&
              record.data['baseKey'] == baseKey,
        )
        .fold<int>(
          0,
          (sum, record) => sum + ((record.data['xp'] as num?)?.toInt() ?? 0),
        );
  }
}
