import 'package:flutter_test/flutter_test.dart';
import 'package:personal_workbench/core/models/workspace_record.dart';
import 'package:personal_workbench/services/growth_service.dart';

WorkspaceRecord _plan(String id, String dayKey) {
  final stamp = DateTime.parse('${dayKey}T12:00:00');
  return WorkspaceRecord(
    id: id,
    kind: RecordKind.dailyPlan,
    title: '日结 $dayKey',
    createdAt: stamp,
    updatedAt: stamp,
    scheduledFor: stamp,
    status: WorkStatus.done,
    data: {'dayKey': dayKey, 'closedAt': stamp.toUtc().toIso8601String()},
  );
}

WorkspaceRecord _event(
  String id,
  int xp, {
  String category = 'commitment',
  String baseKey = 'demo',
  String dayKey = '2026-08-07',
  bool used = false,
}) {
  final stamp = DateTime.parse('${dayKey}T12:00:00');
  return WorkspaceRecord(
    id: id,
    kind: RecordKind.growthEvent,
    title: '成长事件',
    createdAt: stamp,
    updatedAt: stamp,
    status: WorkStatus.done,
    data: {
      'xp': xp,
      'category': category,
      'baseKey': baseKey,
      'dayKey': dayKey,
      'used': used,
    },
  );
}

void main() {
  const service = GrowthService();

  test('logical day changes at 04:00', () {
    expect(service.dayKey(DateTime(2026, 8, 7, 3, 59)), '2026-08-06');
    expect(service.dayKey(DateTime(2026, 8, 7, 4)), '2026-08-07');
  });

  test('xp thresholds and append-only reversals produce stable levels', () {
    final records = [
      _event('one', 250, baseKey: 'task:1'),
      _event('two', 300, baseKey: 'task:2'),
      _event('undo', -50, baseKey: 'task:2'),
    ];
    final snapshot = service.snapshot(records, DateTime(2026, 8, 7, 12));
    expect(service.netXpForBaseKey(records, 'task:2'), 250);
    expect(snapshot.totalXp, 500);
    expect(snapshot.level, 2);
    expect(snapshot.levelXp, 250);
  });

  test('very large xp totals use bounded level calculation', () {
    final snapshot = service.snapshot([
      _event('large', 1 << 30),
    ], DateTime(2026, 8, 7, 12));

    expect(snapshot.totalXp, 1 << 30);
    expect(snapshot.level, greaterThan(1000000));
    expect(snapshot.levelXp, inInclusiveRange(0, 999));
  });

  test(
    'fourteen closed days unlock one recovery and expose the nearest gap',
    () {
      final now = DateTime(2026, 8, 20, 12);
      final records = <WorkspaceRecord>[];
      var id = 0;
      for (var offset = 1; offset <= 15; offset++) {
        if (offset == 2) continue;
        final day = now.subtract(Duration(days: offset));
        final key = service.dayKey(day);
        records.add(_plan('plan-${id++}', key));
      }
      final snapshot = service.snapshot(records, now);
      expect(snapshot.closedDays, 14);
      expect(snapshot.streak, 1);
      expect(snapshot.availableRecoveries, 1);
      expect(
        service.dayKey(service.recoveryCandidate(records, now)!),
        service.dayKey(now.subtract(const Duration(days: 2))),
      );

      records.add(_event('recovery-1', 0, category: 'recovery', used: true));
      expect(service.snapshot(records, now).availableRecoveries, 0);
    },
  );
}
