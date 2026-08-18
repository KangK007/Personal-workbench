import 'package:flutter_test/flutter_test.dart';
import 'package:personal_workbench/services/focus_service.dart';

void main() {
  testWidgets('focus target completes once after lifecycle refresh', (
    tester,
  ) async {
    var now = DateTime(2026, 8, 9, 10);
    var completions = 0;
    final service = FocusService(
      now: () => now,
      tickInterval: const Duration(days: 1),
      onTargetReached: () => completions++,
    );
    addTearDown(service.dispose);

    service.start(FocusMode.custom, customTarget: const Duration(minutes: 5));
    now = now.add(const Duration(minutes: 6));
    service.refresh();
    service.refresh();

    expect(service.running, isFalse);
    expect(service.targetReached, isTrue);
    expect(service.elapsed, const Duration(minutes: 5));
    expect(completions, 1);

    service.start(FocusMode.custom);
    expect(service.running, isTrue);
    expect(service.elapsed, Duration.zero);
    service.reset();
  });

  testWidgets('changing mode after a pause starts a fresh session', (
    tester,
  ) async {
    var now = DateTime(2026, 8, 9, 10);
    final service = FocusService(
      now: () => now,
      tickInterval: const Duration(days: 1),
    );

    service.start(FocusMode.pomodoro25);
    now = now.add(const Duration(minutes: 3));
    service.pause();
    service.start(FocusMode.pomodoro50);

    expect(service.mode, FocusMode.pomodoro50);
    expect(service.elapsed, Duration.zero);
    service.dispose();
  });
}
