// RSIP 国策（习惯协议）领域逻辑，从 WorkbenchController 拆出。
// 依赖 WorkbenchControllerBase 契约访问宿主状态与方法。
import 'dart:async';
import 'dart:math';

import '../core/models/workspace_record.dart';
import '../core/models/workspace_models_v3.dart';
import 'workbench_controller_base.dart';

mixin RsipControllerMixin on WorkbenchControllerBase {
  final Set<String> _settlingRsipNodeIds = {};

  Future<void> setRsipStrictMode(bool value) async {
    if (activeRsipHabits.any((node) => node.rsipTimerRunning)) {
      throw const FormatException('请先结束运行中的国策计时。');
    }
    final pending = activeRsipHabits.any(
      (node) => rsipExecutionForDay(node.id, currentTime()) == null,
    );
    if (pending) {
      throw const FormatException('当天仍有待结算国策节点，暂不能切换模式。');
    }
    rsipStrictMode = value;
    rsipAllowMultiplePerDay = !value;
    await database.writeMetadata('rsip_strict_mode', '$value');
    await database.writeMetadata('rsip_allow_multiple_per_day', '${!value}');
    final event = WorkspaceRecord.create(
      kind: RecordKind.protocolEvent,
      title: value ? '切换为 RSIP 严格模式' : '切换为 RSIP 自由模式',
      scheduledFor: currentTime(),
      data: {
        'protocol': 'rsip',
        'action': 'mode_changed',
        'mode': value ? 'strict' : 'free',
      },
    );
    await addRecord(event);
    notifyListeners();
  }

  Future<void> setRsipAllowMultiplePerDay(bool value) async {
    await setRsipStrictMode(!value);
  }

  List<WorkspaceRecord> rsipSubtree(WorkspaceRecord root) {
    final result = <WorkspaceRecord>[];
    final queue = <WorkspaceRecord>[root];
    final visited = <String>{};
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      if (!visited.add(current.id)) continue;
      result.add(current);
      queue.addAll(
        habits.where(
          (node) => node.hasRsipProtocol && node.parentId == current.id,
        ),
      );
    }
    return result;
  }

  Future<void> moveRsipNode(
    WorkspaceRecord node, {
    String? parentId,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      throw const FormatException('请记录调整树结构的原因。');
    }
    if (!canUseRsipParent(recordId: node.id, parentId: parentId)) {
      throw const FormatException('无法移动：目标父节点会形成循环引用。');
    }
    final current = latestRecordById(node);
    await updateRecord(current.copyWith(parentId: parentId));
    await addProtocolEvent(
      protocol: 'rsip',
      action: 'node_moved',
      subject: current,
      data: {
        'fromParentId': current.parentId,
        'toParentId': parentId,
        'reason': reason.trim(),
        'affectedNodeCount': rsipSubtree(current).length,
      },
    );
  }

  RsipExecutionRecord? rsipExecutionForDay(String nodeId, DateTime day) {
    final key = growthService.dayKey(day);
    return _rsipExecutionForKey(nodeId, key);
  }

  RsipExecutionRecord? _rsipExecutionForKey(String nodeId, String key) {
    return rsipExecutionRecords
        .where(
          (record) => record.nodeId == nodeId && record.logicalDayKey == key,
        )
        .firstOrNull;
  }

  Future<WorkspaceRecord> saveRsipNode({
    WorkspaceRecord? existing,
    required String title,
    required String rule,
    required RsipNodeType type,
    String emoji = '',
    String? parentId,
    String? groupId,
    bool passive = false,
    bool useTimer = false,
    int timerMinutes = 1,
  }) async {
    final normalizedTitle = title.trim();
    final normalizedRule = rule.trim();
    if (normalizedTitle.isEmpty || normalizedRule.isEmpty) {
      throw const FormatException('国策标题和精准规则不能为空。');
    }
    if (useTimer && (timerMinutes < 1 || timerMinutes > 180)) {
      throw const FormatException('国策计时必须在 1 到 180 分钟之间。');
    }
    if (groupId != null &&
        !rsipNodeGroups.any((group) => group.record.id == groupId)) {
      throw const FormatException('所选国策组不存在。');
    }

    final now = currentTime();
    final dayKey = growthService.dayKey(now);
    late WorkspaceRecord record;
    if (existing == null) {
      if (!canAddRsipNode()) {
        throw const FormatException('严格模式下每个逻辑日只能新增一次国策。');
      }
      final draft = WorkspaceRecord.create(
        kind: RecordKind.habit,
        title: normalizedTitle,
        body: normalizedRule,
        parentId: parentId,
        data: const {},
      );
      if (!canUseRsipParent(recordId: draft.id, parentId: parentId)) {
        throw const FormatException('所选父节点无效或会形成循环引用。');
      }
      record = draft.copyWith(
        data: {
          'protocol': 'rsip',
          'recordType': 'rsipNode',
          'rsipRule': normalizedRule,
          'rsipNodeType': type.name,
          'rsipEmoji': emoji.trim().isEmpty
              ? _rsipTypeEmoji(type)
              : emoji.trim(),
          'rsipPassive': passive,
          'rsipUseTimer': useTimer,
          'rsipTimerMinutes': timerMinutes,
          'rsipGroupId': ?groupId,
          'rsipActive': true,
          'rsipStage': 'E0',
          'rsipChainCount': 0,
          'rsipCumulativeExecutionDays': 0,
          'rsipTotalExecutions': 0,
          'rsipTotalViolations': 0,
          'rsipReinforcement': 0,
          'rsipMaxReinforcement': 0,
          'rsipAddedAt': now.toUtc().toIso8601String(),
          'rsipAddedDayKey': dayKey,
        },
      );
      await addRecord(record);
      await _ensureCurrentRsipRun();
      await _updateCurrentRsipRunPeak();
      await addProtocolEvent(
        protocol: 'rsip',
        action: 'node_created',
        subject: record,
        data: {'nodeType': type.name, 'passive': passive},
      );
      return record;
    }

    final current = latestRecordById(existing);
    if (!canUseRsipParent(recordId: current.id, parentId: parentId)) {
      throw const FormatException('所选父节点无效或会形成循环引用。');
    }
    record = current.copyWith(
      title: normalizedTitle,
      body: normalizedRule,
      parentId: parentId,
      data: {
        ...current.data,
        'protocol': 'rsip',
        'recordType': 'rsipNode',
        'rsipRule': normalizedRule,
        'rsipNodeType': type.name,
        'rsipEmoji': emoji.trim().isEmpty ? _rsipTypeEmoji(type) : emoji.trim(),
        'rsipPassive': passive,
        'rsipUseTimer': useTimer,
        'rsipTimerMinutes': timerMinutes,
        'rsipGroupId': ?groupId,
      },
    );
    await updateRecord(record);
    await addProtocolEvent(
      protocol: 'rsip',
      action: 'node_edited',
      subject: record,
    );
    return record;
  }

  Future<WorkspaceRecord> saveRsipNodeGroup({
    WorkspaceRecord? existing,
    required String title,
    String emoji = '组',
    required int initialTolerance,
  }) async {
    final normalized = title.trim();
    if (normalized.isEmpty) {
      throw const FormatException('国策组名称不能为空。');
    }
    if (initialTolerance < 0 || initialTolerance > 99) {
      throw const FormatException('初始容错次数必须在 0 到 99 之间。');
    }
    final duplicate = rsipNodeGroups.any(
      (group) =>
          group.record.id != existing?.id && group.record.title == normalized,
    );
    if (duplicate) throw const FormatException('已存在同名国策组。');

    final record = existing == null
        ? WorkspaceRecord.create(
            kind: RecordKind.template,
            title: normalized,
            data: {
              'recordType': 'rsipNodeGroup',
              'emoji': emoji.trim().isEmpty ? '组' : emoji.trim(),
              'initialTolerance': initialTolerance,
              'remainingTolerance': initialTolerance,
            },
          )
        : latestRecordById(existing).copyWith(
            title: normalized,
            data: {
              ...existing.data,
              'recordType': 'rsipNodeGroup',
              'emoji': emoji.trim().isEmpty ? '组' : emoji.trim(),
              'initialTolerance': initialTolerance,
              'remainingTolerance': min(
                initialTolerance,
                (existing.data['remainingTolerance'] as num?)?.toInt() ??
                    initialTolerance,
              ),
            },
          );
    if (existing == null) {
      await addRecord(record);
    } else {
      await updateRecord(record);
    }
    return record;
  }

  Future<List<WorkspaceRecord>> splitRsipGoal({
    required String goal,
    required List<Map<String, dynamic>> items,
    String? parentId,
    String? groupId,
  }) async {
    final normalizedGoal = goal.trim();
    if (normalizedGoal.isEmpty) {
      throw const FormatException('请填写要拆分的目标。');
    }
    if (items.isEmpty) throw const FormatException('至少需要一个子国策。');
    if (!canAddRsipNode()) {
      throw const FormatException('严格模式下今日已完成一次新增。');
    }
    if (parentId != null &&
        !activeRsipHabits.any((node) => node.id == parentId)) {
      throw const FormatException('所选父节点不存在。');
    }
    if (groupId != null &&
        !rsipNodeGroups.any((group) => group.record.id == groupId)) {
      throw const FormatException('所选国策组不存在。');
    }

    final now = currentTime();
    final dayKey = growthService.dayKey(now);
    final batchId = newRecordId();
    final created = <WorkspaceRecord>[];
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      final title = item['title']?.toString().trim() ?? '';
      final rule = item['rule']?.toString().trim() ?? '';
      if (title.isEmpty || rule.isEmpty) {
        throw FormatException('第 ${index + 1} 个子国策缺少标题或精准规则。');
      }
      final type = RsipNodeType.values.firstWhere(
        (value) => value.name == item['type']?.toString(),
        orElse: () => RsipNodeType.policy,
      );
      final record = WorkspaceRecord.create(
        kind: RecordKind.habit,
        title: title,
        body: rule,
        parentId: parentId,
        data: {
          'protocol': 'rsip',
          'recordType': 'rsipNode',
          'rsipRule': rule,
          'rsipNodeType': type.name,
          'rsipEmoji': item['emoji']?.toString().trim().isNotEmpty == true
              ? item['emoji'].toString().trim()
              : _rsipTypeEmoji(type),
          'rsipPassive': item['passive'] == true,
          'rsipGroupId': ?groupId,
          'rsipActive': true,
          'rsipStage': 'E0',
          'rsipChainCount': 0,
          'rsipCumulativeExecutionDays': 0,
          'rsipTotalExecutions': 0,
          'rsipTotalViolations': 0,
          'rsipReinforcement': 0,
          'rsipMaxReinforcement': 0,
          'splitFromGoal': normalizedGoal,
          'splitBatchId': batchId,
          'rsipAddedAt': now.toUtc().toIso8601String(),
          'rsipAddedDayKey': dayKey,
        },
      );
      await addRecord(record);
      created.add(record);
    }
    await _ensureCurrentRsipRun();
    await _updateCurrentRsipRunPeak();
    await addProtocolEvent(
      protocol: 'rsip',
      action: 'split_batch_created',
      subject: created.first,
      data: {
        'batchId': batchId,
        'goal': normalizedGoal,
        'nodeIds': created.map((node) => node.id).toList(),
        'nodeCount': created.length,
      },
    );
    return created;
  }

  RsipViolationPreview previewRsipViolation(WorkspaceRecord node) {
    final current = latestRecordById(node);
    if (!current.hasRsipProtocol || !current.rsipActive) {
      throw const FormatException('该国策节点当前不可结算。');
    }
    final reinforcement =
        (current.data['rsipReinforcement'] as num?)?.toInt() ?? 0;
    if (reinforcement > 0) {
      return RsipViolationPreview(
        node: current,
        reinforcementBefore: reinforcement,
        reinforcementAfter: reinforcement - 1,
        remainingToleranceBefore: null,
        remainingToleranceAfter: null,
        archiveNodeIds: const [],
        collapsesWholeGroup: false,
        endsRun: false,
      );
    }

    final groupId = current.data['rsipGroupId']?.toString();
    final group = rsipNodeGroups
        .where((value) => value.record.id == groupId)
        .firstOrNull;
    final subtreeIds = _activeRsipSubtreeIds(current);
    var archiveIds = subtreeIds;
    var wholeGroup = false;
    int? toleranceBefore;
    int? toleranceAfter;
    if (group != null) {
      toleranceBefore = group.remainingTolerance;
      toleranceAfter = max(0, toleranceBefore - 1);
      wholeGroup = toleranceBefore <= 1;
      if (wholeGroup) {
        final ids = <String>{};
        for (final groupNode in activeRsipHabits.where(
          (candidate) => candidate.data['rsipGroupId'] == group.record.id,
        )) {
          ids.addAll(_activeRsipSubtreeIds(groupNode));
        }
        archiveIds = ids.toList(growable: false);
      }
    }
    final activeIds = activeRsipHabits.map((value) => value.id).toSet();
    final endsRun =
        wholeGroup ||
        current.parentId == null ||
        activeIds.difference(archiveIds.toSet()).isEmpty;
    return RsipViolationPreview(
      node: current,
      reinforcementBefore: 0,
      reinforcementAfter: 0,
      remainingToleranceBefore: toleranceBefore,
      remainingToleranceAfter: toleranceAfter,
      archiveNodeIds: archiveIds,
      collapsesWholeGroup: wholeGroup,
      endsRun: endsRun,
    );
  }

  Future<RsipExecutionRecord> settleRsipNode(
    WorkspaceRecord node, {
    required RsipExecutionStatus status,
    String reason = '',
    String repairHint = '',
    String sourceId = '',
    String sourceEvent = '',
    String correctionReason = '',
    bool reinforce = false,
    DateTime? logicalDay,
  }) async {
    final current = latestRecordById(node);
    final day = growthService.logicalDay(logicalDay ?? currentTime());
    final dayKey = calendarDayKey(day);
    final existing = _rsipExecutionForKey(current.id, dayKey);
    if (existing != null) {
      if (existing.status == status) return existing;
      if (correctionReason.trim().isEmpty) {
        throw const FormatException('同一逻辑日只能有一个有效结算；更正时必须填写原因。');
      }
      final correctedAt = currentTime();
      final corrected = existing.record.copyWith(
        status: _rsipWorkStatus(status),
        body: reason.trim(),
        data: {
          ...existing.record.data,
          'executionStatus': status.name,
          'reason': reason.trim(),
          'repairHint': repairHint.trim(),
          'correctedAt': correctedAt.toUtc().toIso8601String(),
          'correctionReason': correctionReason.trim(),
          'previousStatus': existing.status.name,
          'structuralEffectRequiresReview':
              existing.status == RsipExecutionStatus.violated ||
              status == RsipExecutionStatus.violated,
        },
      );
      await updateRecord(corrected);
      await _adjustRsipCountersForCorrection(
        current,
        from: existing.status,
        to: status,
      );
      await addProtocolEvent(
        protocol: 'rsip',
        action: 'execution_corrected',
        subject: current,
        data: {
          'logicalDayKey': dayKey,
          'from': existing.status.name,
          'to': status.name,
          'reason': correctionReason.trim(),
          'structuralEffectReversed': false,
        },
      );
      return RsipExecutionRecord.fromRecord(corrected);
    }
    if (!current.hasRsipProtocol || !current.rsipActive) {
      throw const FormatException('该国策节点当前不可结算。');
    }
    if (status == RsipExecutionStatus.violated && reason.trim().isEmpty) {
      throw const FormatException('违反国策时必须填写原因。');
    }
    if (!_settlingRsipNodeIds.add(current.id)) {
      throw const FormatException('该国策正在结算，请稍候。');
    }
    try {
      switch (status) {
        case RsipExecutionStatus.executed:
          await _markRsipExecuted(current, day, reinforce: reinforce);
          break;
        case RsipExecutionStatus.violated:
          await _applyRsipViolation(
            previewRsipViolation(current),
            reason: reason.trim(),
          );
          break;
        case RsipExecutionStatus.skipped:
          await updateRecord(
            current.copyWith(
              data: {
                ...current.data,
                'rsipChainCount': 0,
                'rsipTimerRunning': false,
                'rsipLastSkippedAt': currentTime().toUtc().toIso8601String(),
              },
            ),
          );
          break;
      }
      final record = WorkspaceRecord.create(
        kind: RecordKind.protocolEvent,
        title: '${current.title} · ${_rsipStatusLabel(status)}',
        body: reason.trim(),
        status: _rsipWorkStatus(status),
        parentId: current.id,
        scheduledFor: day,
        data: {
          'protocol': 'rsip',
          'recordType': 'rsipExecution',
          'action': 'node_settled',
          'rsipNodeId': current.id,
          'logicalDayKey': dayKey,
          'executionStatus': status.name,
          'reason': reason.trim(),
          'repairHint': repairHint.trim(),
          'sourceId': sourceId,
          'sourceEvent': sourceEvent,
        },
      );
      await addRecord(record);
      if (status == RsipExecutionStatus.executed) {
        await _runAutomaticRsipTaskActions(current.id);
      }
      return RsipExecutionRecord.fromRecord(record);
    } finally {
      _settlingRsipNodeIds.remove(current.id);
    }
  }

  Future<void> reinforceRsipNode(WorkspaceRecord node) async {
    final current = latestRecordById(node);
    final value = RsipNode.fromRecord(current);
    if (!current.rsipActive || value.stage != 'E2') {
      throw const FormatException('只有活动的 E2 国策可以强化。');
    }
    final next = value.reinforcement + 1;
    await updateRecord(
      current.copyWith(
        data: {
          ...current.data,
          'rsipReinforcement': next,
          'rsipMaxReinforcement': max(value.maxReinforcement, next),
        },
      ),
    );
    await addProtocolEvent(
      protocol: 'rsip',
      action: 'node_reinforced',
      subject: current,
      data: {'level': next},
    );
  }

  Future<void> archiveRsipNode(
    WorkspaceRecord node, {
    required String reason,
  }) async {
    if (reason.trim().isEmpty) throw const FormatException('请填写归档原因。');
    final current = latestRecordById(node);
    final ids = _activeRsipSubtreeIds(current);
    await _archiveRsipNodes(ids, reason: reason.trim());
    if (current.parentId == null || activeRsipHabits.isEmpty) {
      await _endCurrentRsipRun(
        reason: reason.trim(),
        collapseNodeTitle: current.title,
      );
    }
  }

  Future<void> restoreRsipNode(WorkspaceRecord node, {String? parentId}) async {
    final current = latestRecordById(node);
    if (current.rsipActive) return;
    if (!canUseRsipParent(recordId: current.id, parentId: parentId)) {
      throw const FormatException('恢复位置无效或会形成循环引用。');
    }
    await updateRecord(
      current.copyWith(
        parentId: parentId,
        data: {
          ...current.data,
          'rsipActive': true,
          'rsipStage': 'E0',
          'rsipChainCount': 0,
          'rsipReinforcement': 0,
          'rsipTimerRunning': false,
          'rsipRestoredAt': currentTime().toUtc().toIso8601String(),
          'rsipLibraryUses':
              ((current.data['rsipLibraryUses'] as num?)?.toInt() ?? 0) + 1,
        },
      ),
    );
    await _ensureCurrentRsipRun();
    await _updateCurrentRsipRunPeak();
    await addProtocolEvent(
      protocol: 'rsip',
      action: 'node_restored',
      subject: current,
      data: {'parentId': parentId},
    );
  }

  Future<WorkspaceRecord> saveRsipTaskLink({
    WorkspaceRecord? existing,
    required String nodeId,
    required String chainId,
    required RsipTaskChainKind chainKind,
    required RsipTaskLinkTriggerEvent triggerEvent,
    required RsipTaskLinkEffect effect,
    RsipTaskLinkAutomation automation = RsipTaskLinkAutomation.automatic,
    bool active = true,
  }) async {
    if (!rsipNodes.any((node) => node.record.id == nodeId)) {
      throw const FormatException('关联的国策节点不存在。');
    }
    final targetExists = chainKind == RsipTaskChainKind.unit
        ? [...taskDefinitions, ...tasks].any((task) => task.id == chainId)
        : taskGroups.any((group) => group.id == chainId);
    if (!targetExists) throw const FormatException('关联的任务或任务群不存在。');
    final taskToRsip =
        triggerEvent != RsipTaskLinkTriggerEvent.rsipMarkedExecuted;
    final effectIsTaskToRsip =
        effect == RsipTaskLinkEffect.markRsipExecuted ||
        effect == RsipTaskLinkEffect.markRsipViolated;
    if (taskToRsip != effectIsTaskToRsip) {
      throw const FormatException('联动触发方向和执行效果不匹配。');
    }
    final matching = rsipTaskLinks
        .where(
          (link) =>
              link.nodeId == nodeId &&
              link.chainId == chainId &&
              link.chainKind == chainKind &&
              link.triggerEvent == triggerEvent &&
              link.effect == effect,
        )
        .firstOrNull;
    final effectiveExisting = existing ?? matching?.record;
    final data = {
      'recordType': 'rsipTaskLink',
      'relationType': 'rsipTaskLink',
      'rsipNodeId': nodeId,
      'chainId': chainId,
      'chainKind': chainKind.name,
      'triggerEvent': triggerEvent.name,
      'effect': effect.name,
      'automation': automation.name,
      'active': active,
    };
    final record = effectiveExisting == null
        ? WorkspaceRecord.create(
            kind: RecordKind.relation,
            title: 'RSIP 任务联动',
            data: data,
          )
        : latestRecordById(
            effectiveExisting,
          ).copyWith(data: {...effectiveExisting.data, ...data});
    if (effectiveExisting == null) {
      await addRecord(record);
    } else {
      await updateRecord(record);
    }
    return record;
  }

  List<RsipTaskLink> pendingRsipTaskActions(String nodeId) => rsipTaskLinks
      .where(
        (link) =>
            link.active &&
            link.nodeId == nodeId &&
            link.triggerEvent == RsipTaskLinkTriggerEvent.rsipMarkedExecuted &&
            !_rsipLinkTriggeredToday(link),
      )
      .toList(growable: false);

  Future<void> applyRsipTaskAction(RsipTaskLink link) async {
    if (_rsipLinkTriggeredToday(link)) return;
    final targets = link.chainKind == RsipTaskChainKind.unit
        ? tasks
              .where(
                (task) =>
                    task.id == link.chainId ||
                    task.data['definitionId'] == link.chainId,
              )
              .toList()
        : tasks.where((task) => task.parentId == link.chainId).toList();
    final now = currentTime();
    for (final task in targets.where(
      (task) => !WorkStatus.terminal.contains(task.status),
    )) {
      if (link.effect == RsipTaskLinkEffect.promptStartChain) {
        await updateRecord(task.copyWith(status: WorkStatus.doing));
      } else if (link.effect == RsipTaskLinkEffect.promptScheduleChain) {
        final scheduled = task.scheduledFor;
        await updateRecord(
          task.copyWith(
            scheduledFor: DateTime(
              now.year,
              now.month,
              now.day,
              scheduled?.hour ?? 9,
              scheduled?.minute ?? 0,
            ),
          ),
        );
      }
    }
    await _recordRsipLinkTrigger(link);
  }

  Future<void> handleRsipGroupCycleCompleted(String groupId) async {
    await handleTaskRsipLinks(
      groupId,
      RsipTaskChainKind.group,
      RsipTaskLinkTriggerEvent.groupCycleCompleted,
    );
  }

  List<RsipInsight> get rsipInsights {
    final end = currentTime();
    final start = end.subtract(const Duration(days: 14));
    final records = rsipExecutionRecords.where(
      (record) => !record.record.createdAt.isBefore(start),
    );
    final executed = records
        .where((record) => record.status == RsipExecutionStatus.executed)
        .length;
    final violated = records
        .where((record) => record.status == RsipExecutionStatus.violated)
        .length;
    final tracked = executed + violated;
    final metrics = <String, num>{
      'activeNodes': activeRsipHabits.length,
      'passiveNodes': rsipNodes.where((node) => node.passive).length,
      'reinforcedNodes': rsipNodes
          .where((node) => node.reinforcement > 0)
          .length,
      'executed14d': executed,
      'violated14d': violated,
      'successRate14d': tracked == 0 ? 0 : executed / tracked,
      'runs': rsipRunRecords.length,
    };
    final result = <RsipInsight>[
      RsipInsight(
        windowStart: start,
        windowEnd: end,
        metrics: metrics,
        rule: '14 日执行率 = 已执行 /（已执行 + 已违反）',
        message: tracked == 0
            ? '近 14 日尚无可分析的执行或违反记录。'
            : violated > executed
            ? '违反次数高于执行次数，建议缩小精准规则的最小动作。'
            : '当前 14 日执行记录未出现明显的整体风险信号。',
      ),
    ];
    for (final node in rsipNodes.where((node) => node.record.rsipActive)) {
      final descendants = _activeRsipSubtreeIds(node.record).length - 1;
      final phaseWeight = switch (node.stage) {
        'E2' => 3,
        'E1' => 2,
        _ => 1,
      };
      final cost =
          (descendants + 1) * phaseWeight * (node.reinforcement > 0 ? 0.3 : 1);
      if (cost < 4) continue;
      result.add(
        RsipInsight(
          windowStart: start,
          windowEnd: end,
          metrics: {'descendants': descendants, 'failureCost': cost},
          rule: '风险成本 =（子孙数 + 1）× 阶段权重 × 强化修正',
          message: '「${node.record.title}」失败会影响较大子树，结算前应先检查规则是否可执行。',
        ),
      );
    }
    return result;
  }

  String _rsipTypeEmoji(RsipNodeType type) => switch (type) {
    RsipNodeType.policy => '策',
    RsipNodeType.habit => '习',
    RsipNodeType.reward => '赏',
    RsipNodeType.penalty => '罚',
    RsipNodeType.ritual => '仪',
    RsipNodeType.goal => '标',
    RsipNodeType.trigger => '触',
    RsipNodeType.reminder => '醒',
  };

  String _rsipWorkStatus(RsipExecutionStatus status) => switch (status) {
    RsipExecutionStatus.executed => WorkStatus.done,
    RsipExecutionStatus.violated => WorkStatus.failed,
    RsipExecutionStatus.skipped => WorkStatus.skipped,
  };

  String _rsipStatusLabel(RsipExecutionStatus status) => switch (status) {
    RsipExecutionStatus.executed => '已执行',
    RsipExecutionStatus.violated => '已违反',
    RsipExecutionStatus.skipped => '已跳过',
  };

  List<String> _activeRsipSubtreeIds(WorkspaceRecord root) {
    final result = <String>[];
    final queue = <WorkspaceRecord>[root];
    final visited = <String>{};
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      if (!current.rsipActive || !visited.add(current.id)) continue;
      result.add(current.id);
      queue.addAll(
        activeRsipHabits.where((node) => node.parentId == current.id),
      );
    }
    return result;
  }

  Future<void> _markRsipExecuted(
    WorkspaceRecord node,
    DateTime logicalDay, {
    bool reinforce = false,
  }) async {
    final current = latestRecordById(node);
    final previous = _rsipExecutionForKey(
      current.id,
      calendarDayKey(logicalDay.subtract(const Duration(days: 1))),
    );
    final chain = previous?.status == RsipExecutionStatus.executed
        ? current.rsipChainCount + 1
        : 1;
    final previousStage = (current.data['rsipStage']?.toString() ?? 'E0')
        .toUpperCase();
    final stage = chain >= 21
        ? 'E2'
        : chain >= 7
        ? 'E1'
        : 'E0';
    var reinforcement =
        (current.data['rsipReinforcement'] as num?)?.toInt() ?? 0;
    var maxReinforcement =
        (current.data['rsipMaxReinforcement'] as num?)?.toInt() ?? 0;
    if (stage == 'E2' && reinforce) {
      reinforcement += 1;
      maxReinforcement = max(maxReinforcement, reinforcement);
    }
    final now = currentTime();
    await updateRecord(
      current.copyWith(
        data: {
          ...current.data,
          'rsipActive': true,
          'rsipChainCount': chain,
          'rsipStage': stage,
          if (stage != previousStage)
            'rsipStageStartedAt': now.toUtc().toIso8601String(),
          'rsipCumulativeExecutionDays':
              ((current.data['rsipCumulativeExecutionDays'] as num?)?.toInt() ??
                  0) +
              1,
          'rsipTotalExecutions':
              ((current.data['rsipTotalExecutions'] as num?)?.toInt() ?? 0) + 1,
          'rsipConsecutiveViolations': 0,
          'rsipReinforcement': reinforcement,
          'rsipMaxReinforcement': maxReinforcement,
          'rsipLastSuccessAt': now.toUtc().toIso8601String(),
          'rsipTimerRunning': false,
        },
      ),
    );
  }

  Future<void> _applyRsipViolation(
    RsipViolationPreview preview, {
    required String reason,
  }) async {
    final node = latestRecordById(preview.node);
    final now = currentTime();
    final violationData = {
      ...node.data,
      'rsipChainCount': 0,
      'rsipTotalViolations':
          ((node.data['rsipTotalViolations'] as num?)?.toInt() ?? 0) + 1,
      'rsipConsecutiveViolations':
          ((node.data['rsipConsecutiveViolations'] as num?)?.toInt() ?? 0) + 1,
      'rsipFailureCount': node.rsipFailureCount + 1,
      'rsipLastFailureAt': now.toUtc().toIso8601String(),
      'rsipFailureReason': reason,
      'rsipTimerRunning': false,
    };
    if (preview.onlyConsumesReinforcement) {
      await updateRecord(
        node.copyWith(
          data: {
            ...violationData,
            'rsipReinforcement': preview.reinforcementAfter,
          },
        ),
      );
      await addProtocolEvent(
        protocol: 'rsip',
        action: 'reinforcement_consumed',
        subject: node,
        successful: false,
        data: {
          'from': preview.reinforcementBefore,
          'to': preview.reinforcementAfter,
          'reason': reason,
        },
      );
      return;
    }

    await updateRecord(node.copyWith(data: violationData));
    final groupId = node.data['rsipGroupId']?.toString();
    if (groupId != null) {
      final group = rsipNodeGroups
          .where((value) => value.record.id == groupId)
          .firstOrNull;
      if (group != null) {
        await updateRecord(
          group.record.copyWith(
            data: {
              ...group.record.data,
              'remainingTolerance': preview.remainingToleranceAfter,
              'lastConsumedAt': now.toUtc().toIso8601String(),
            },
          ),
        );
      }
    }
    await _archiveRsipNodes(preview.archiveNodeIds, reason: reason);
    await addProtocolEvent(
      protocol: 'rsip',
      action: preview.collapsesWholeGroup
          ? 'group_collapsed'
          : 'subtree_collapsed',
      subject: node,
      successful: false,
      data: {
        'reason': reason,
        'nodeIds': preview.archiveNodeIds,
        'nodeCount': preview.archiveNodeIds.length,
        'groupId': groupId,
        'remainingTolerance': preview.remainingToleranceAfter,
      },
    );
    if (preview.endsRun) {
      await _endCurrentRsipRun(reason: reason, collapseNodeTitle: node.title);
    }
  }

  Future<void> _archiveRsipNodes(
    Iterable<String> nodeIds, {
    required String reason,
  }) async {
    final ids = nodeIds.toSet();
    final now = currentTime();
    for (final node in habits.where((record) => ids.contains(record.id))) {
      final current = latestRecordById(node);
      final stage = (current.data['rsipStage']?.toString() ?? 'E0')
          .toUpperCase();
      final currentHighest =
          current.data['rsipHighestStage']?.toString().toUpperCase() ?? 'E0';
      final highest = _rsipStageRank(stage) >= _rsipStageRank(currentHighest)
          ? stage
          : currentHighest;
      await updateRecord(
        current.copyWith(
          data: {
            ...current.data,
            'rsipActive': false,
            'rsipTimerRunning': false,
            'rsipArchivedAt': now.toUtc().toIso8601String(),
            'rsipArchiveReason': reason,
            'rsipLastActiveAt': now.toUtc().toIso8601String(),
            'rsipHighestStage': highest,
            'rsipLibraryUses':
                ((current.data['rsipLibraryUses'] as num?)?.toInt() ?? 0) + 1,
          },
        ),
      );
    }
  }

  int _rsipStageRank(String stage) => switch (stage.toUpperCase()) {
    'E2' => 2,
    'E1' => 1,
    _ => 0,
  };

  WorkspaceRecord? get _currentRsipRun => protocolEvents
      .where(
        (record) =>
            record.data['recordType'] == 'rsipRun' &&
            record.data['endedAt'] == null,
      )
      .firstOrNull;

  Future<WorkspaceRecord> _ensureCurrentRsipRun() async {
    final existing = _currentRsipRun;
    if (existing != null) return existing;
    final lastNumber = rsipRunRecords.fold<int>(
      0,
      (value, record) => max(value, record.runNumber),
    );
    final now = currentTime();
    for (final group in rsipNodeGroups) {
      await updateRecord(
        group.record.copyWith(
          data: {
            ...group.record.data,
            'remainingTolerance': group.initialTolerance,
          },
        ),
      );
    }
    final run = WorkspaceRecord.create(
      kind: RecordKind.protocolEvent,
      title: 'RSIP 第 ${lastNumber + 1} 轮',
      scheduledFor: now,
      data: {
        'protocol': 'rsip',
        'recordType': 'rsipRun',
        'action': 'run_started',
        'runNumber': lastNumber + 1,
        'startedAt': now.toUtc().toIso8601String(),
        'peakNodeCount': activeRsipHabits.length,
        'nodeIds': activeRsipHabits.map((node) => node.id).toList(),
      },
    );
    await addRecord(run);
    return run;
  }

  Future<void> _updateCurrentRsipRunPeak() async {
    final run = await _ensureCurrentRsipRun();
    final currentPeak = (run.data['peakNodeCount'] as num?)?.toInt() ?? 0;
    if (activeRsipHabits.length <= currentPeak) return;
    await updateRecord(
      run.copyWith(
        data: {
          ...run.data,
          'peakNodeCount': activeRsipHabits.length,
          'nodeIds': activeRsipHabits.map((node) => node.id).toList(),
        },
      ),
    );
  }

  Future<void> _endCurrentRsipRun({
    required String reason,
    required String collapseNodeTitle,
  }) async {
    final run = _currentRsipRun;
    if (run == null) return;
    final started =
        DateTime.tryParse(run.data['startedAt']?.toString() ?? '')?.toLocal() ??
        run.createdAt;
    final now = currentTime();
    final duration = max(
      1,
      growthService
              .logicalDay(now)
              .difference(growthService.logicalDay(started))
              .inDays +
          1,
    );
    await updateRecord(
      run.copyWith(
        status: WorkStatus.done,
        data: {
          ...run.data,
          'action': 'run_ended',
          'endedAt': now.toUtc().toIso8601String(),
          'durationDays': duration,
          'collapseReason': reason,
          'collapseNodeTitle': collapseNodeTitle,
        },
      ),
    );
  }

  Future<void> _adjustRsipCountersForCorrection(
    WorkspaceRecord node, {
    required RsipExecutionStatus from,
    required RsipExecutionStatus to,
  }) async {
    final current = latestRecordById(node);
    var executions =
        (current.data['rsipTotalExecutions'] as num?)?.toInt() ?? 0;
    var violations =
        (current.data['rsipTotalViolations'] as num?)?.toInt() ?? 0;
    if (from == RsipExecutionStatus.executed) {
      executions = max(0, executions - 1);
    }
    if (from == RsipExecutionStatus.violated) {
      violations = max(0, violations - 1);
    }
    if (to == RsipExecutionStatus.executed) executions += 1;
    if (to == RsipExecutionStatus.violated) violations += 1;
    await updateRecord(
      current.copyWith(
        data: {
          ...current.data,
          'rsipTotalExecutions': executions,
          'rsipTotalViolations': violations,
          'rsipLastCorrectionAt': currentTime().toUtc().toIso8601String(),
        },
      ),
    );
  }

  Future<void> handleTaskRsipLinks(
    String chainId,
    RsipTaskChainKind chainKind,
    RsipTaskLinkTriggerEvent event,
  ) async {
    for (final link in rsipTaskLinks.where(
      (link) =>
          link.active &&
          link.chainId == chainId &&
          link.chainKind == chainKind &&
          link.triggerEvent == event &&
          !_rsipLinkTriggeredToday(link),
    )) {
      if (link.automation == RsipTaskLinkAutomation.confirm) {
        final subject = rsipNodes
            .where((node) => node.record.id == link.nodeId)
            .firstOrNull
            ?.record;
        if (subject == null) continue;
        await addProtocolEvent(
          protocol: 'rsip',
          action: 'task_link_confirmation_pending',
          subject: subject,
          data: {'linkId': link.record.id, 'sourceId': chainId},
        );
        continue;
      }
      final node = rsipNodes
          .where((node) => node.record.id == link.nodeId)
          .firstOrNull
          ?.record;
      if (node == null || !node.rsipActive) continue;
      final status = link.effect == RsipTaskLinkEffect.markRsipExecuted
          ? RsipExecutionStatus.executed
          : RsipExecutionStatus.violated;
      await settleRsipNode(
        node,
        status: status,
        reason: status == RsipExecutionStatus.violated ? '关联任务中断' : '',
        sourceId: chainId,
        sourceEvent: event.name,
      );
      await _recordRsipLinkTrigger(link);
    }
  }

  Future<void> _runAutomaticRsipTaskActions(String nodeId) async {
    for (final link in pendingRsipTaskActions(
      nodeId,
    ).where((link) => link.automation == RsipTaskLinkAutomation.automatic)) {
      await applyRsipTaskAction(link);
    }
  }

  bool _rsipLinkTriggeredToday(RsipTaskLink link) {
    final key = growthService.dayKey(currentTime());
    return protocolEvents.any(
      (record) =>
          record.data['action'] == 'rsip_task_link_triggered' &&
          record.data['linkId'] == link.record.id &&
          record.data['logicalDayKey'] == key,
    );
  }

  Future<void> _recordRsipLinkTrigger(RsipTaskLink link) async {
    final subject = rsipNodes
        .where((node) => node.record.id == link.nodeId)
        .firstOrNull
        ?.record;
    if (subject == null) return;
    await addProtocolEvent(
      protocol: 'rsip',
      action: 'rsip_task_link_triggered',
      subject: subject,
      data: {
        'linkId': link.record.id,
        'logicalDayKey': growthService.dayKey(currentTime()),
        'chainId': link.chainId,
        'effect': link.effect.name,
      },
    );
  }

  bool canAddRsipNode({String? excludingId}) {
    if (rsipAllowMultiplePerDay) return true;
    final todayKey = growthService.dayKey(currentTime());
    return habits.every((habit) {
      if (!habit.hasRsipProtocol || habit.id == excludingId) return true;
      final addedAt = DateTime.tryParse(
        habit.data['rsipAddedAt']?.toString() ?? '',
      )?.toLocal();
      if (addedAt != null) return growthService.dayKey(addedAt) != todayKey;
      final addedDayKey = habit.data['rsipAddedDayKey']?.toString();
      return addedDayKey == null ||
          addedDayKey.isEmpty ||
          addedDayKey != todayKey;
    });
  }

  bool canUseRsipParent({required String recordId, String? parentId}) {
    if (parentId == null) return true;
    final byId = {
      for (final habit in habits)
        if (habit.hasRsipProtocol) habit.id: habit,
    };
    String? currentId = parentId;
    final visited = <String>{};
    while (currentId != null) {
      if (!visited.add(currentId)) return false;
      if (currentId == recordId) return false;
      currentId = byId[currentId]?.parentId;
    }
    return byId.containsKey(parentId);
  }

  WorkspaceRecord normalizeRsipRecord(WorkspaceRecord record) {
    if (!record.hasRsipProtocol) return record;
    final chain = record.rsipChainCount;
    final stage = chain >= 21
        ? 'E2'
        : chain >= 7
        ? 'E1'
        : 'E0';
    final addedAt =
        DateTime.tryParse(
          record.data['rsipAddedAt']?.toString() ?? '',
        )?.toLocal() ??
        record.createdAt;
    return record.copyWith(
      body: record.rsipRule,
      data: {
        ...record.data,
        'recordType': 'rsipNode',
        'rsipRule': record.rsipRule,
        'rsipNodeType': record.data['rsipNodeType']?.toString() ?? 'policy',
        'rsipEmoji': record.data['rsipEmoji']?.toString() ?? '策',
        'rsipPassive': record.data['rsipPassive'] == true,
        'rsipStage': (record.data['rsipStage']?.toString() ?? stage)
            .toUpperCase(),
        'rsipCumulativeExecutionDays':
            (record.data['rsipCumulativeExecutionDays'] as num?)?.toInt() ??
            chain,
        'rsipTotalExecutions':
            (record.data['rsipTotalExecutions'] as num?)?.toInt() ?? chain,
        'rsipTotalViolations':
            (record.data['rsipTotalViolations'] as num?)?.toInt() ??
            record.rsipFailureCount,
        'rsipReinforcement':
            (record.data['rsipReinforcement'] as num?)?.toInt() ?? 0,
        'rsipMaxReinforcement':
            (record.data['rsipMaxReinforcement'] as num?)?.toInt() ?? 0,
        'rsipAddedAt': addedAt.toUtc().toIso8601String(),
        'rsipAddedDayKey':
            record.data['rsipAddedDayKey']?.toString() ??
            growthService.dayKey(addedAt),
      },
      touch: false,
    );
  }

  Future<void> reactivateRsipHabit(WorkspaceRecord habit) async {
    final current = latestRecordById(habit);
    if (!current.hasRsipProtocol) return;
    final parentIsActive =
        current.parentId != null &&
        activeRsipHabits.any((node) => node.id == current.parentId);
    await restoreRsipNode(
      current,
      parentId: parentIsActive ? current.parentId : null,
    );
  }

  Future<void> startRsipTimer(WorkspaceRecord habit) async {
    final current = latestRecordById(habit);
    if (!current.hasRsipProtocol || !current.rsipActive) {
      throw const FormatException('该国策节点当前不可执行');
    }
    if (current.rsipFrozen) {
      throw const FormatException('该国策分支处于冻结保护期');
    }
    if (!current.rsipUseTimer) {
      throw const FormatException('该节点没有启用计时');
    }
    final now = currentTime();
    final dueAt = now.add(Duration(minutes: current.rsipTimerMinutes));
    await updateRecord(
      current.copyWith(
        data: {
          ...current.data,
          'rsipTimerRunning': true,
          'rsipTimerStartedAt': now.toUtc().toIso8601String(),
          'rsipTimerDueAt': dueAt.toUtc().toIso8601String(),
        },
      ),
    );
    await notificationService.scheduleTaskReminder(
      id: notificationId('rsip:${current.id}'),
      title: 'RSIP 最小动作可以结算',
      body: '${current.title} · ${current.rsipMinimumAction}',
      when: dueAt,
    );
    await addProtocolEvent(
      protocol: 'rsip',
      action: 'timer_started',
      subject: current,
      data: {'dueAt': dueAt.toUtc().toIso8601String()},
    );
  }

  Future<void> completeRsipTimer(WorkspaceRecord habit) async {
    final current = latestRecordById(habit);
    if (!current.rsipTimerRunning) {
      throw const FormatException('该节点尚未开始计时');
    }
    final dueAt = DateTime.tryParse(
      current.data['rsipTimerDueAt']?.toString() ?? '',
    )?.toLocal();
    if (dueAt != null && currentTime().isBefore(dueAt)) {
      final remaining = dueAt.difference(currentTime()).inSeconds;
      throw FormatException('计时尚未完成，还需 $remaining 秒');
    }
    await updateRecord(
      current.copyWith(
        data: {
          ...current.data,
          'rsipTimerRunning': false,
          'rsipTimerCompletedAt': currentTime().toUtc().toIso8601String(),
        },
      ),
    );
    await settleRsipNode(current, status: RsipExecutionStatus.executed);
    await addProtocolEvent(
      protocol: 'rsip',
      action: 'timer_completed',
      subject: current,
    );
  }

  Future<void> freezeRsipBranch(
    WorkspaceRecord root, {
    required DateTime until,
    String reason = '',
  }) async {
    final current = latestRecordById(root);
    if (!current.hasRsipProtocol) return;
    if (!until.isAfter(currentTime())) {
      throw const FormatException('冻结截止时间必须晚于当前时间');
    }
    final queue = <WorkspaceRecord>[current];
    final visited = <String>{};
    while (queue.isNotEmpty) {
      final item = queue.removeAt(0);
      if (!visited.add(item.id)) continue;
      await updateRecord(
        item.copyWith(
          data: {
            ...item.data,
            'rsipFrozen': true,
            'rsipFrozenUntil': until.toUtc().toIso8601String(),
            'rsipFreezeReason': reason.trim(),
            'rsipTimerRunning': false,
          },
        ),
      );
      queue.addAll(
        habits.where(
          (habit) => habit.hasRsipProtocol && habit.parentId == item.id,
        ),
      );
    }
    await addProtocolEvent(
      protocol: 'rsip',
      action: 'branch_frozen',
      subject: current,
      data: {
        'until': until.toUtc().toIso8601String(),
        'reason': reason.trim(),
        'nodeCount': visited.length,
      },
    );
  }

  Future<WorkspaceRecord> recordRsipVictory({
    required String title,
    required String grade,
    String notes = '',
  }) async {
    if (!const {'small', 'medium', 'big'}.contains(grade)) {
      throw const FormatException('未知的胜利等级');
    }
    final day = startOfDay(currentTime());
    final existing = protocolEvents.where((event) {
      return event.data['protocol'] == 'rsip' &&
          event.data['action'] == 'daily_victory' &&
          isSameDay(event.scheduledFor ?? event.createdAt, day);
    }).firstOrNull;
    final record = existing == null
        ? WorkspaceRecord.create(
            kind: RecordKind.protocolEvent,
            title: title.trim().isEmpty ? '今日胜利' : title.trim(),
            body: notes.trim(),
            scheduledFor: day,
            status: WorkStatus.done,
            data: {
              'protocol': 'rsip',
              'action': 'daily_victory',
              'grade': grade,
              'successful': true,
            },
          )
        : existing.copyWith(
            title: title.trim().isEmpty ? existing.title : title.trim(),
            body: notes.trim(),
            data: {...existing.data, 'grade': grade},
          );
    await updateRecord(record);
    return record;
  }

  Future<void> settlePreviousRsipDay(DateTime now) async {
    final day = startOfDay(now).subtract(const Duration(days: 1));
    final alreadySettled = protocolEvents.any(
      (event) =>
          event.data['protocol'] == 'rsip' &&
          event.data['action'] == 'daily_settlement' &&
          isSameDay(event.scheduledFor ?? event.createdAt, day),
    );
    if (alreadySettled) return;
    final rsipIds = habits
        .where((habit) => habit.hasRsipProtocol)
        .map((habit) => habit.id)
        .toSet();
    if (rsipIds.isEmpty) return;
    final logs = recordsOf(RecordKind.habitLog).where((log) {
      return rsipIds.contains(log.parentId) &&
          isSameDay(log.scheduledFor ?? log.createdAt, day);
    });
    final completed = logs.where((log) => log.status == WorkStatus.done).length;
    final failed = logs.where((log) => log.status == WorkStatus.skipped).length;
    final grade = completed >= 3
        ? 'big'
        : completed >= 1
        ? 'medium'
        : 'small';
    await addProtocolEvent(
      protocol: 'rsip',
      action: 'daily_settlement',
      subject: habits.firstWhere((habit) => habit.hasRsipProtocol),
      successful: completed > 0,
      scheduledFor: day,
      data: {'grade': grade, 'completed': completed, 'failed': failed},
    );
  }
}
