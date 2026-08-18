import 'dart:convert';

import 'workspace_record.dart';

class GameProfile {
  const GameProfile({
    this.points = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastCheckinDay,
    this.gamblingEnabled = false,
    this.maxSingleBet,
    this.dailyBetLimit,
    this.lastReward,
  });

  factory GameProfile.fromJson(Map<String, dynamic> json) => GameProfile(
    points: (json['points'] as num?)?.toInt().clamp(0, 1 << 30) ?? 0,
    currentStreak:
        (json['currentStreak'] as num?)?.toInt().clamp(0, 1 << 30) ?? 0,
    longestStreak:
        (json['longestStreak'] as num?)?.toInt().clamp(0, 1 << 30) ?? 0,
    lastCheckinDay: json['lastCheckinDay']?.toString(),
    gamblingEnabled: json['gamblingEnabled'] == true,
    maxSingleBet: (json['maxSingleBet'] as num?)?.toInt(),
    dailyBetLimit: (json['dailyBetLimit'] as num?)?.toInt(),
    lastReward: json['lastReward']?.toString(),
  );

  final int points;
  final int currentStreak;
  final int longestStreak;
  final String? lastCheckinDay;
  final bool gamblingEnabled;
  final int? maxSingleBet;
  final int? dailyBetLimit;
  final String? lastReward;

  GameProfile copyWith({
    int? points,
    int? currentStreak,
    int? longestStreak,
    Object? lastCheckinDay = _unset,
    bool? gamblingEnabled,
    Object? maxSingleBet = _unset,
    Object? dailyBetLimit = _unset,
    Object? lastReward = _unset,
  }) => GameProfile(
    points: points ?? this.points,
    currentStreak: currentStreak ?? this.currentStreak,
    longestStreak: longestStreak ?? this.longestStreak,
    lastCheckinDay: identical(lastCheckinDay, _unset)
        ? this.lastCheckinDay
        : lastCheckinDay as String?,
    gamblingEnabled: gamblingEnabled ?? this.gamblingEnabled,
    maxSingleBet: identical(maxSingleBet, _unset)
        ? this.maxSingleBet
        : maxSingleBet as int?,
    dailyBetLimit: identical(dailyBetLimit, _unset)
        ? this.dailyBetLimit
        : dailyBetLimit as int?,
    lastReward: identical(lastReward, _unset)
        ? this.lastReward
        : lastReward as String?,
  );

  Map<String, dynamic> toJson() => {
    'points': points,
    'currentStreak': currentStreak,
    'longestStreak': longestStreak,
    'lastCheckinDay': lastCheckinDay,
    'gamblingEnabled': gamblingEnabled,
    'maxSingleBet': maxSingleBet,
    'dailyBetLimit': dailyBetLimit,
    'lastReward': lastReward,
  };
}

const _unset = Object();

class PointTransaction {
  const PointTransaction({
    required this.id,
    required this.amount,
    required this.balanceAfter,
    required this.type,
    required this.createdAt,
    this.referenceId,
    this.description = '',
  });

  factory PointTransaction.fromJson(Map<String, dynamic> json) =>
      PointTransaction(
        id: json['id']?.toString() ?? newRecordId(),
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        balanceAfter: (json['balanceAfter'] as num?)?.toInt() ?? 0,
        type: json['type']?.toString() ?? 'unknown',
        createdAt:
            DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ??
            DateTime.now(),
        referenceId: json['referenceId']?.toString(),
        description: json['description']?.toString() ?? '',
      );

  final String id;
  final int amount;
  final int balanceAfter;
  final String type;
  final DateTime createdAt;
  final String? referenceId;
  final String description;

  Map<String, dynamic> toJson() => {
    'id': id,
    'amount': amount,
    'balanceAfter': balanceAfter,
    'type': type,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'referenceId': referenceId,
    'description': description,
  };
}

enum BetStatus { pending, won, lost, refunded }

class BetSession {
  const BetSession({
    required this.id,
    required this.focusSessionId,
    required this.taskId,
    required this.amount,
    required this.status,
    required this.placedAt,
    this.dayKey = '',
    this.settledAt,
  });

  factory BetSession.fromJson(Map<String, dynamic> json) => BetSession(
    id: json['id']?.toString() ?? newRecordId(),
    focusSessionId: json['focusSessionId']?.toString() ?? '',
    taskId: json['taskId']?.toString() ?? '',
    amount: (json['amount'] as num?)?.toInt() ?? 0,
    status: BetStatus.values.firstWhere(
      (value) => value.name == json['status'],
      orElse: () => BetStatus.pending,
    ),
    placedAt:
        DateTime.tryParse(json['placedAt']?.toString() ?? '')?.toLocal() ??
        DateTime.now(),
    dayKey: json['dayKey']?.toString() ?? '',
    settledAt: DateTime.tryParse(
      json['settledAt']?.toString() ?? '',
    )?.toLocal(),
  );

  final String id;
  final String focusSessionId;
  final String taskId;
  final int amount;
  final BetStatus status;
  final DateTime placedAt;
  final String dayKey;
  final DateTime? settledAt;

  BetSession copyWith({BetStatus? status, DateTime? settledAt}) => BetSession(
    id: id,
    focusSessionId: focusSessionId,
    taskId: taskId,
    amount: amount,
    status: status ?? this.status,
    placedAt: placedAt,
    dayKey: dayKey,
    settledAt: settledAt ?? this.settledAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'focusSessionId': focusSessionId,
    'taskId': taskId,
    'amount': amount,
    'status': status.name,
    'placedAt': placedAt.toUtc().toIso8601String(),
    'dayKey': dayKey,
    'settledAt': settledAt?.toUtc().toIso8601String(),
  };
}

class LocalGameState {
  const LocalGameState({
    this.profile = const GameProfile(),
    this.transactions = const [],
    this.bets = const [],
    this.removedFeatureData = const {},
  });

  factory LocalGameState.fromJson(String? encoded) {
    if (encoded == null || encoded.trim().isEmpty) {
      return const LocalGameState();
    }
    try {
      final json = jsonDecode(encoded) as Map<String, dynamic>;
      return LocalGameState(
        profile: GameProfile.fromJson(
          Map<String, dynamic>.from(json['profile'] as Map? ?? const {}),
        ),
        transactions: (json['transactions'] as List<dynamic>? ?? const [])
            .map(
              (value) => PointTransaction.fromJson(
                Map<String, dynamic>.from(value as Map),
              ),
            )
            .toList(growable: false),
        bets: (json['bets'] as List<dynamic>? ?? const [])
            .map(
              (value) =>
                  BetSession.fromJson(Map<String, dynamic>.from(value as Map)),
            )
            .toList(growable: false),
        removedFeatureData: {
          if (json.containsKey('pet')) 'pet': json['pet'],
          if (json.containsKey('rewardEvents'))
            'rewardEvents': json['rewardEvents'],
        },
      );
    } on Object {
      return const LocalGameState();
    }
  }

  final GameProfile profile;
  final List<PointTransaction> transactions;
  final List<BetSession> bets;
  final Map<String, dynamic> removedFeatureData;

  LocalGameState copyWith({
    GameProfile? profile,
    List<PointTransaction>? transactions,
    List<BetSession>? bets,
    Map<String, dynamic>? removedFeatureData,
  }) => LocalGameState(
    profile: profile ?? this.profile,
    transactions: transactions ?? this.transactions,
    bets: bets ?? this.bets,
    removedFeatureData: removedFeatureData ?? this.removedFeatureData,
  );

  String encode() => jsonEncode({
    // Keep data from removed features round-trippable without loading it.
    ...removedFeatureData,
    'profile': profile.toJson(),
    'transactions': transactions.map((value) => value.toJson()).toList(),
    'bets': bets.map((value) => value.toJson()).toList(),
  });
}
