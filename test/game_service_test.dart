import 'package:flutter_test/flutter_test.dart';
import 'package:personal_workbench/core/models/game_state.dart';
import 'package:personal_workbench/services/game_service.dart';

void main() {
  const service = GameService();
  final start = DateTime(2026, 8, 12, 8);

  test('checkin pays once per logical day and tracks streak', () {
    final state = LocalGameState();
    final first = service.checkin(state, '2026-08-12', start);
    expect(first.completed, isTrue);
    expect(first.state.profile.points, 10);
    final duplicate = service.checkin(first.state, '2026-08-12', start);
    expect(duplicate.completed, isFalse);
    final next = service.checkin(
      duplicate.state,
      '2026-08-13',
      start.add(const Duration(days: 1)),
    );
    expect(next.state.profile.currentStreak, 2);
    expect(next.state.profile.points, 20);
  });

  test('betting protects balance, settles once and refunds pending bets', () {
    final state = LocalGameState(
      profile: const GameProfile(points: 50, gamblingEnabled: true),
    );
    final placed = service.placeBet(
      state,
      focusSessionId: 'focus-1',
      taskId: 'task-1',
      amount: 20,
      now: start,
      dayKey: '2026-08-12',
    );
    expect(placed.session.dayKey, '2026-08-12');
    expect(placed.state.profile.points, 30);
    final won = service.settleBet(placed.state, 'focus-1', true, start);
    expect(won.profile.points, 70);
    final unchanged = service.settleBet(won, 'focus-1', true, start);
    expect(unchanged.profile.points, 70);
    final pending = service.placeBet(
      won,
      focusSessionId: 'focus-2',
      taskId: 'task-2',
      amount: 10,
      now: start,
      dayKey: '2026-08-12',
    );
    expect(
      service.refundBet(pending.state, 'focus-2', start).profile.points,
      70,
    );
    expect(
      () => service.placeBet(
        state,
        focusSessionId: 'focus-3',
        taskId: 'task-3',
        amount: 100,
        now: start,
        dayKey: '2026-08-12',
      ),
      throwsFormatException,
    );
  });

  test('daily bet limit uses the supplied logical day', () {
    final state = LocalGameState(
      profile: const GameProfile(
        points: 100,
        gamblingEnabled: true,
        dailyBetLimit: 30,
      ),
    );
    final first = service.placeBet(
      state,
      focusSessionId: 'focus-1',
      taskId: 'task-1',
      amount: 20,
      now: DateTime(2026, 8, 13, 1),
      dayKey: '2026-08-12',
    );
    expect(
      () => service.placeBet(
        first.state,
        focusSessionId: 'focus-2',
        taskId: 'task-2',
        amount: 11,
        now: DateTime(2026, 8, 13, 2),
        dayKey: '2026-08-12',
      ),
      throwsFormatException,
    );
  });
}
