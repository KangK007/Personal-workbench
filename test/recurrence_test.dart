import 'package:flutter_test/flutter_test.dart';
import 'package:personal_workbench/core/models/workspace_record.dart';

void main() {
  test('monthly recurrence clamps to the last valid day', () {
    final next = nextOccurrence(DateTime(2026, 1, 31, 9, 30), 'monthly');

    expect(next, DateTime(2026, 2, 28, 9, 30));
  });

  test('weekday recurrence skips a weekend', () {
    final next = nextOccurrence(DateTime(2026, 8, 7, 9), 'weekdays');

    expect(next, DateTime(2026, 8, 10, 9));
  });
}
