import 'dart:math';

import '../core/models/game_state.dart';
import '../core/models/workspace_record.dart';

class CheckinResult {
  const CheckinResult({required this.state, required this.completed});

  final LocalGameState state;
  final bool completed;
}

class BetPlacementResult {
  const BetPlacementResult({required this.state, required this.session});

  final LocalGameState state;
  final BetSession session;
}

class GameService {
  const GameService();

  CheckinResult checkin(LocalGameState state, String dayKey, DateTime now) {
    if (state.profile.lastCheckinDay == dayKey) {
      return CheckinResult(state: state, completed: false);
    }
    final last = state.profile.lastCheckinDay == null
        ? null
        : DateTime.tryParse(state.profile.lastCheckinDay!);
    final today = DateTime.tryParse(dayKey)!;
    final streak = last != null && today.difference(last).inDays == 1
        ? state.profile.currentStreak + 1
        : 1;
    final balance = state.profile.points + 10;
    final transaction = PointTransaction(
      id: newRecordId(),
      amount: 10,
      balanceAfter: balance,
      type: 'checkin',
      createdAt: now,
      referenceId: dayKey,
      description: '每日签到',
    );
    return CheckinResult(
      completed: true,
      state: state.copyWith(
        profile: state.profile.copyWith(
          points: balance,
          currentStreak: streak,
          longestStreak: max(streak, state.profile.longestStreak),
          lastCheckinDay: dayKey,
          lastReward: '签到 +10 积分',
        ),
        transactions: [...state.transactions, transaction],
      ),
    );
  }

  BetPlacementResult placeBet(
    LocalGameState state, {
    required String focusSessionId,
    required String taskId,
    required int amount,
    required DateTime now,
    required String dayKey,
  }) {
    if (!state.profile.gamblingEnabled) {
      throw const FormatException('请先在成长页开启押注。');
    }
    if (amount <= 0) throw const FormatException('押注金额必须是正整数。');
    if (state.profile.maxSingleBet != null &&
        amount > state.profile.maxSingleBet!) {
      throw FormatException('单次押注不能超过 ${state.profile.maxSingleBet} 积分。');
    }
    if (state.profile.points < amount) throw const FormatException('积分余额不足。');
    if (state.bets.any(
      (bet) =>
          bet.focusSessionId == focusSessionId &&
          bet.status == BetStatus.pending,
    )) {
      throw const FormatException('一个专注会话只能有一笔押注。');
    }
    final usedToday = state.bets
        .where(
          (bet) =>
              bet.status != BetStatus.refunded &&
              (bet.dayKey.isEmpty ? _dayKey(bet.placedAt) : bet.dayKey) ==
                  dayKey,
        )
        .fold<int>(0, (sum, bet) => sum + bet.amount);
    if (state.profile.dailyBetLimit != null &&
        usedToday + amount > state.profile.dailyBetLimit!) {
      throw FormatException(
        '今日押注额度还剩 ${max(0, state.profile.dailyBetLimit! - usedToday)} 积分。',
      );
    }
    final balance = state.profile.points - amount;
    final bet = BetSession(
      id: newRecordId(),
      focusSessionId: focusSessionId,
      taskId: taskId,
      amount: amount,
      status: BetStatus.pending,
      placedAt: now,
      dayKey: dayKey,
    );
    final transaction = PointTransaction(
      id: newRecordId(),
      amount: -amount,
      balanceAfter: balance,
      type: 'bet_placed',
      createdAt: now,
      referenceId: bet.id,
      description: '专注押注',
    );
    return BetPlacementResult(
      session: bet,
      state: state.copyWith(
        profile: state.profile.copyWith(
          points: balance,
          lastReward: '押注 $amount 积分',
        ),
        transactions: [...state.transactions, transaction],
        bets: [...state.bets, bet],
      ),
    );
  }

  LocalGameState settleBet(
    LocalGameState state,
    String focusSessionId,
    bool successful,
    DateTime now,
  ) {
    final index = state.bets.indexWhere(
      (bet) =>
          bet.focusSessionId == focusSessionId &&
          bet.status == BetStatus.pending,
    );
    if (index < 0) return state;
    final bet = state.bets[index];
    final status = successful ? BetStatus.won : BetStatus.lost;
    final payout = successful ? bet.amount * 2 : 0;
    final transactions = [...state.transactions];
    var profile = state.profile.copyWith(
      lastReward: successful ? '押注成功，返还 $payout 积分' : '押注未命中',
    );
    if (payout > 0) {
      final balance = profile.points + payout;
      profile = profile.copyWith(points: balance);
      transactions.add(
        PointTransaction(
          id: newRecordId(),
          amount: payout,
          balanceAfter: balance,
          type: 'bet_won',
          createdAt: now,
          referenceId: bet.id,
          description: '专注完成返还',
        ),
      );
    }
    final nextBets = [...state.bets];
    nextBets[index] = bet.copyWith(status: status, settledAt: now);
    return state.copyWith(
      profile: profile,
      transactions: transactions,
      bets: nextBets,
    );
  }

  LocalGameState refundBet(
    LocalGameState state,
    String focusSessionId,
    DateTime now,
  ) {
    final index = state.bets.indexWhere(
      (bet) =>
          bet.focusSessionId == focusSessionId &&
          bet.status == BetStatus.pending,
    );
    if (index < 0) return state;
    final bet = state.bets[index];
    final balance = state.profile.points + bet.amount;
    final nextBets = [...state.bets];
    nextBets[index] = bet.copyWith(status: BetStatus.refunded, settledAt: now);
    return state.copyWith(
      profile: state.profile.copyWith(points: balance, lastReward: '已撤销押注'),
      transactions: [
        ...state.transactions,
        PointTransaction(
          id: newRecordId(),
          amount: bet.amount,
          balanceAfter: balance,
          type: 'bet_refunded',
          createdAt: now,
          referenceId: bet.id,
          description: '撤销未结算押注',
        ),
      ],
      bets: nextBets,
    );
  }

  String _dayKey(DateTime value) {
    final local = value.toLocal().subtract(const Duration(hours: 4));
    return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}
