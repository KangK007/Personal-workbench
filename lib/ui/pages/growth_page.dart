import 'package:flutter/material.dart';

import '../../core/models/workspace_record.dart';
import '../../core/models/game_state.dart';
import '../../core/theme/app_theme.dart';
import '../../services/growth_service.dart';
import '../../state/workbench_controller.dart';
import '../widgets/common.dart';

class GrowthPage extends StatelessWidget {
  const GrowthPage({
    super.key,
    required this.controller,
    this.now,
    this.showHeader = true,
  });

  final WorkbenchController controller;
  final DateTime? now;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final snapshot = controller.growthSnapshot;
    return Column(
      children: [
        if (showHeader)
          PageHeader(
            title: '成长',
            subtitle: controller.gameFeaturesEnabled
                ? '虚拟积分 · 签到 · 执行证据'
                : '28 日执行账本 · 承诺 / 专注 / 习惯 / 日结',
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 132),
            children: [
              if (controller.gameFeaturesEnabled) ...[
                _GameProfilePanel(controller: controller),
              ],
              SectionHeading(title: '当前等级', scale: '证据账本'),
              _LevelLedger(snapshot: snapshot),
              if (snapshot.availableRecoveries > 0)
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => showRecoveryDialog(context, controller),
                    icon: const Icon(Icons.restore),
                    label: Text(
                      '恢复最近缺失日 · ${snapshot.availableRecoveries} 次可用',
                    ),
                  ),
                ),
              const SectionHeading(title: '28 日执行账本', scale: '近 28 日'),
              _ActivityLedger(
                controller: controller,
                now: now ?? controller.currentTime(),
              ),
              const SectionHeading(
                title: '里程碑印章',
                scale: 'LV 03 / 07 / 12 / 20',
              ),
              _MilestoneStamps(level: snapshot.level),
              const SectionHeading(title: '最近证据', scale: '最近'),
              _RecentEvents(events: controller.growthEvents.take(8).toList()),
              if (controller.growthEvents.length < 5)
                const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }
}

class _GameProfilePanel extends StatelessWidget {
  const _GameProfilePanel({required this.controller});

  final WorkbenchController controller;

  @override
  Widget build(BuildContext context) {
    final profile = controller.gameProfile;
    final checkedIn =
        profile.lastCheckinDay ==
        controller.growthService.dayKey(controller.currentTime());
    return Column(
      children: [
        LogSurface(
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final values = [
                    Expanded(
                      child: _GameValue(
                        icon: Icons.toll_outlined,
                        label: '虚拟积分',
                        value: '${profile.points}',
                      ),
                    ),
                    Expanded(
                      child: _GameValue(
                        icon: Icons.local_fire_department_outlined,
                        label: '连续签到',
                        value: '${profile.currentStreak} 日',
                      ),
                    ),
                  ];
                  final button = FilledButton.icon(
                    onPressed: checkedIn
                        ? null
                        : () => _checkin(context, controller),
                    icon: Icon(checkedIn ? Icons.check : Icons.event_available),
                    label: Text(checkedIn ? '今日已签到' : '签到 +10'),
                  );
                  if (constraints.maxWidth < 520) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: values),
                        const SizedBox(height: 12),
                        Align(alignment: Alignment.centerRight, child: button),
                      ],
                    );
                  }
                  return Row(children: [...values, button]);
                },
              ),
              if (profile.lastReward != null) ...[
                const Divider(height: 28),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '最近反馈：${profile.lastReward}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        LogSurface(
          padding: EdgeInsets.zero,
          child: ExpansionTile(
            title: const Text('专注押注'),
            subtitle: const Text('仅使用本地虚拟积分，无现金价值，不支持兑换或支付'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.savings_outlined),
                title: const Text('启用虚拟积分押注'),
                subtitle: const Text('成功完成专注返还两倍押注；失败则不返还'),
                value: profile.gamblingEnabled,
                onChanged: controller.setBettingEnabled,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.tune_outlined),
                title: const Text('押注上限'),
                subtitle: Text(
                  '单次 ${profile.maxSingleBet?.toString() ?? '不限'} · '
                  '每日 ${profile.dailyBetLimit?.toString() ?? '不限'}',
                ),
                trailing: OutlinedButton(
                  onPressed: () => _editBetLimits(context, controller),
                  child: const Text('设置'),
                ),
              ),
              if (controller.betSessions.isNotEmpty) ...[
                const Divider(),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '最近押注',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                for (final bet in controller.betSessions.take(5))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(_betIcon(bet.status)),
                    title: Text(
                      '${bet.amount} 积分 · ${_betStatusLabel(bet.status)}',
                    ),
                    subtitle: Text(
                      bet.placedAt.toLocal().toString().substring(0, 16),
                    ),
                    trailing: bet.status == BetStatus.pending
                        ? TextButton(
                            onPressed: () =>
                                controller.cancelLocalBet(bet.focusSessionId),
                            child: const Text('撤销'),
                          )
                        : null,
                  ),
              ],
              if (controller.pointTransactions.isNotEmpty) ...[
                const Divider(),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '积分账本',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                for (final transaction in controller.pointTransactions.take(6))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(transaction.description),
                    subtitle: Text('余额 ${transaction.balanceAfter}'),
                    trailing: NumericText(
                      transaction.amount >= 0
                          ? '+${transaction.amount}'
                          : '${transaction.amount}',
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  IconData _betIcon(BetStatus status) => switch (status) {
    BetStatus.pending => Icons.hourglass_top,
    BetStatus.won => Icons.check_circle_outline,
    BetStatus.lost => Icons.cancel_outlined,
    BetStatus.refunded => Icons.undo,
  };

  String _betStatusLabel(BetStatus status) => switch (status) {
    BetStatus.pending => '待结算',
    BetStatus.won => '已返还',
    BetStatus.lost => '未命中',
    BetStatus.refunded => '已撤销',
  };
}

class _GameValue extends StatelessWidget {
  const _GameValue({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              NumericText(value, style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
        ),
      ],
    );
  }
}

Future<void> _checkin(
  BuildContext context,
  WorkbenchController controller,
) async {
  final completed = await controller.performDailyCheckin();
  if (!context.mounted) return;
  showWorkbenchSnackBar(
    context,
    SnackBar(content: Text(completed ? '签到成功，获得 10 虚拟积分。' : '今天已经签到。')),
  );
}

Future<void> _editBetLimits(
  BuildContext context,
  WorkbenchController controller,
) async {
  final single = TextEditingController(
    text: controller.gameProfile.maxSingleBet?.toString() ?? '',
  );
  final daily = TextEditingController(
    text: controller.gameProfile.dailyBetLimit?.toString() ?? '',
  );
  final confirmed = await showWorkbenchDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('押注上限'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExternalField(
            label: '单次上限',
            child: TextField(
              controller: single,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(helperText: '留空表示不限制'),
            ),
          ),
          const SizedBox(height: 12),
          ExternalField(
            label: '每日上限',
            child: TextField(
              controller: daily,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(helperText: '留空表示不限制'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('保存'),
        ),
      ],
    ),
  );
  try {
    if (confirmed == true) {
      await controller.setBetLimits(
        maxSingleBet: single.text.trim().isEmpty
            ? null
            : int.parse(single.text),
        dailyBetLimit: daily.text.trim().isEmpty ? null : int.parse(daily.text),
      );
    }
  } on Object catch (error) {
    if (context.mounted) {
      showWorkbenchSnackBar(context, SnackBar(content: Text('$error')));
    }
  } finally {
    single.dispose();
    daily.dispose();
  }
}

Future<void> showRecoveryDialog(
  BuildContext context,
  WorkbenchController controller,
) async {
  final candidate = controller.growthService.recoveryCandidate(
    controller.activeRecords,
    controller.currentTime(),
  );
  if (candidate == null) {
    showWorkbenchSnackBar(
      context,
      const SnackBar(content: Text('近 14 日没有可恢复的缺失日期。')),
    );
    return;
  }
  final key = controller.growthService.dayKey(candidate);
  final confirmed = await showWorkbenchDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('恢复连续记录'),
      content: Text('将把 $key 标记为恢复日结，消耗 1 次恢复资格。此操作会留下可追溯记录。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('确认恢复'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await controller.useRecovery();
    if (context.mounted) {
      showWorkbenchSnackBar(
        context,
        SnackBar(content: Text('已恢复 $key 的连续记录。')),
      );
    }
  } on FormatException catch (error) {
    if (context.mounted) {
      showWorkbenchSnackBar(context, SnackBar(content: Text(error.message)));
    }
  }
}

class _LevelLedger extends StatelessWidget {
  const _LevelLedger({required this.snapshot});

  final GrowthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return LogSurface(
      accent: context.tokens.reward,
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 640;
          final level = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '等级',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: context.tokens.mutedText,
                ),
              ),
              AnimatedNumber(
                value: snapshot.level,
                formatter: (v) => v.round().toString().padLeft(2, '0'),
                duration: const Duration(milliseconds: 450),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontSize: 52,
                  color: context.tokens.reward,
                ),
              ),
            ],
          );
          final ruler = Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '升级刻度',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    NumericText(
                      '${snapshot.levelXp} / ${snapshot.nextLevelXp} XP',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _XpRuler(progress: snapshot.levelProgress),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 18,
                  runSpacing: 8,
                  children: [
                    _LedgerValue(label: '总 XP', value: '${snapshot.totalXp}'),
                    _LedgerValue(label: '连续', value: '${snapshot.streak} 日'),
                    _LedgerValue(
                      label: '日结',
                      value: '${snapshot.closedDays} 次',
                    ),
                    _LedgerValue(
                      label: '恢复',
                      value: '${snapshot.availableRecoveries} / 2',
                    ),
                  ],
                ),
              ],
            ),
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                level,
                const SizedBox(height: 12),
                Row(children: [ruler]),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: 112, child: level),
              const SizedBox(width: 18),
              ruler,
            ],
          );
        },
      ),
    );
  }
}

class _XpRuler extends StatelessWidget {
  const _XpRuler({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progress.clamp(0, 1),
            minHeight: 7,
            backgroundColor: context.tokens.rewardContainer.withValues(
              alpha: 0.45,
            ),
            valueColor: AlwaysStoppedAnimation(context.tokens.reward),
          ),
        ),
        const TickDivider(height: 7),
      ],
    );
  }
}

class _LedgerValue extends StatelessWidget {
  const _LedgerValue({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: context.tokens.mutedText),
        ),
        NumericText(value, style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }
}

class _ActivityLedger extends StatelessWidget {
  const _ActivityLedger({required this.controller, required this.now});
  final WorkbenchController controller;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    final cellSize = compact ? 16.0 : 14.0;
    final cellSlot = cellSize + 4;
    const categories = [
      ('承诺', 'commitment'),
      ('专注', 'focus'),
      ('习惯', 'habit'),
      ('日结', 'review'),
    ];
    final days = List.generate(
      28,
      (index) => now.subtract(Duration(days: 27 - index)),
    );
    return LogSurface(
      padding: const EdgeInsets.all(14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(width: 54),
                for (final day in days)
                  SizedBox(
                    width: cellSlot,
                    child: Center(
                      child: NumericText(
                        day.day % 7 == 1 ? '${day.day}' : '·',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: context.tokens.mutedText,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            for (final category in categories)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  children: [
                    SizedBox(
                      width: 54,
                      child: Text(
                        category.$1,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                    for (final day in days)
                      _ActivityCell(
                        state: _stateFor(controller, category.$2, day),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  int _stateFor(WorkbenchController controller, String category, DateTime day) {
    final key = controller.growthService.dayKey(day);
    final planned = controller
        .recordsOf(RecordKind.dailyPlan)
        .any((plan) => plan.data['dayKey'] == key);
    final xp = controller.growthEvents
        .where(
          (event) =>
              event.data['dayKey'] == key && event.data['category'] == category,
        )
        .fold<int>(
          0,
          (sum, event) => sum + ((event.data['xp'] as num?)?.toInt() ?? 0),
        );
    if (xp > 0) return 2;
    return planned ? 1 : 0;
  }
}

class _ActivityCell extends StatelessWidget {
  const _ActivityCell({required this.state});
  final int state;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    final cellSize = compact ? 16.0 : 14.0;
    final color = switch (state) {
      2 => Theme.of(context).colorScheme.primary,
      1 => context.tokens.info,
      _ => context.tokens.divider,
    };
    return Semantics(
      label: switch (state) {
        2 => '已完成',
        1 => '已计划未完成',
        _ => '未计划',
      },
      child: Container(
        width: cellSize,
        height: cellSize,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: state == 0 ? Colors.transparent : color,
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(2),
        ),
        child: state == 2
            ? Icon(
                Icons.check,
                size: compact ? 10 : 9,
                color: Theme.of(context).colorScheme.onPrimary,
              )
            : null,
      ),
    );
  }
}

class _MilestoneStamps extends StatelessWidget {
  const _MilestoneStamps({required this.level});
  final int level;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final target in const [3, 7, 12, 20])
          _Stamp(target: target, unlocked: level >= target),
      ],
    );
  }
}

class _Stamp extends StatelessWidget {
  const _Stamp({required this.target, required this.unlocked});
  final int target;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    // 未解锁印章：边框与说明文字提高对比度（≥1.15:1 边框基准），去掉低对比渐变。
    final borderColor = unlocked
        ? context.tokens.marker
        : context.tokens.mutedText.withValues(alpha: 0.45);
    final detailColor = unlocked
        ? context.tokens.marker
        : context.tokens.mutedText.withValues(alpha: 0.85);
    final titleColor = Theme.of(context).colorScheme.onSurface;
    return Semantics(
      label: unlocked ? '等级 $target 里程碑已解锁' : '等级 $target 里程碑未解锁',
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: unlocked
              ? context.tokens.marker.withValues(alpha: 0.1)
              : context.tokens.subtle,
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              unlocked ? Icons.workspace_premium_outlined : Icons.lock_outline,
              size: 17,
              color: detailColor,
            ),
            NumericText(
              '$target',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
            ),
            Text(
              unlocked ? '已解锁' : '待解锁',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: detailColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentEvents extends StatelessWidget {
  const _RecentEvents({required this.events});
  final List<WorkspaceRecord> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Text(
        '尚无成长记录。从一次明确承诺开始。',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: context.tokens.mutedText),
      );
    }
    return LogSurface(
      child: Column(
        children: [
          for (var index = 0; index < events.length; index++) ...[
            ListTile(
              leading: NumericText(
                ((events[index].data['xp'] as num?)?.toInt() ?? 0) >= 0
                    ? '+${events[index].data['xp']}'
                    : '${events[index].data['xp']}',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(color: context.tokens.reward),
              ),
              title: Text(
                events[index].title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                events[index].data['dayKey']?.toString() ?? '',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: context.tokens.mutedText,
                ),
              ),
            ),
            if (index < events.length - 1) const Divider(),
          ],
        ],
      ),
    );
  }
}
