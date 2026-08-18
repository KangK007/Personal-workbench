import 'workspace_record.dart';

enum RsipNodeType {
  policy,
  habit,
  reward,
  penalty,
  ritual,
  goal,
  trigger,
  reminder,
}

enum RsipExecutionStatus { executed, violated, skipped }

enum RsipTaskChainKind { unit, group }

enum RsipTaskLinkTriggerEvent {
  taskCompleted,
  taskInterrupted,
  groupCycleCompleted,
  rsipMarkedExecuted,
}

enum RsipTaskLinkEffect {
  markRsipExecuted,
  markRsipViolated,
  promptStartChain,
  promptScheduleChain,
}

enum RsipTaskLinkAutomation { automatic, confirm }

class TaskContextSummary {
  const TaskContextSummary({
    required this.taskId,
    required this.status,
    required this.recurring,
    required this.projectTitles,
    required this.additionalProjectCount,
    required this.ctdpEnabled,
    this.primaryProjectTitle,
    this.primaryProjectInTrash = false,
    this.groupId,
    this.groupTitle,
    this.groupMode,
    this.chainPosition,
    this.chainLength,
    this.previousTaskTitle,
    this.nextTaskTitle,
    this.lockReason,
    this.scheduledFor,
    this.dueAt,
    this.settledAt,
    this.result,
    this.failureReason,
    this.skipReason,
    this.rescheduledTo,
    this.rescheduledFromId,
  });

  final String taskId;
  final String status;
  final bool recurring;
  final String? primaryProjectTitle;
  final bool primaryProjectInTrash;
  final List<String> projectTitles;
  final int additionalProjectCount;
  final bool ctdpEnabled;
  final String? groupId;
  final String? groupTitle;
  final String? groupMode;
  final int? chainPosition;
  final int? chainLength;
  final String? previousTaskTitle;
  final String? nextTaskTitle;
  final String? lockReason;
  final DateTime? scheduledFor;
  final DateTime? dueAt;
  final DateTime? settledAt;
  final String? result;
  final String? failureReason;
  final String? skipReason;
  final DateTime? rescheduledTo;
  final String? rescheduledFromId;
}

class ReviewPeriod {
  const ReviewPeriod({
    required this.type,
    required this.key,
    required this.start,
    required this.end,
  });

  final ReviewPeriodType type;
  final String key;
  final DateTime start;
  final DateTime end;

  bool get isLegacy => type == ReviewPeriodType.yearly;

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'key': key,
    'start': start.toUtc().toIso8601String(),
    'end': end.toUtc().toIso8601String(),
  };

  factory ReviewPeriod.fromJson(Map<String, dynamic> json) => ReviewPeriod(
    type: ReviewPeriodType.values.firstWhere(
      (value) => value.name == json['type'],
      orElse: () => ReviewPeriodType.daily,
    ),
    key: json['key']?.toString() ?? '',
    start: _date(json['start']) ?? DateTime.now(),
    end: _date(json['end']) ?? DateTime.now(),
  );
}

class ReviewTaskFact {
  const ReviewTaskFact({
    required this.taskId,
    required this.title,
    required this.status,
    this.projectTitles = const [],
    this.groupId,
    this.groupTitle,
    this.groupMode,
    this.chainPosition,
    this.completedAt,
    this.result = '',
    this.failureReason = '',
    this.skipReason = '',
    this.rescheduledTo,
    this.rescheduledFromId,
  });

  final String taskId;
  final String title;
  final String status;
  final List<String> projectTitles;
  final String? groupId;
  final String? groupTitle;
  final String? groupMode;
  final int? chainPosition;
  final DateTime? completedAt;
  final String result;
  final String failureReason;
  final String skipReason;
  final DateTime? rescheduledTo;
  final String? rescheduledFromId;

  Map<String, dynamic> toJson() => {
    'taskId': taskId,
    'id': taskId,
    'title': title,
    'status': status,
    'projectTitles': projectTitles,
    if (groupId != null) 'groupId': groupId,
    if (groupTitle != null) 'groupTitle': groupTitle,
    if (groupMode != null) 'groupMode': groupMode,
    if (chainPosition != null) 'chainPosition': chainPosition,
    if (completedAt != null)
      'completedAt': completedAt!.toUtc().toIso8601String(),
    'result': result,
    'failureReason': failureReason,
    'skipReason': skipReason,
    'reason': failureReason.isNotEmpty ? failureReason : skipReason,
    if (rescheduledTo != null)
      'rescheduledTo': rescheduledTo!.toUtc().toIso8601String(),
    if (rescheduledFromId != null) 'rescheduledFromId': rescheduledFromId,
  };

  factory ReviewTaskFact.fromJson(Map<String, dynamic> json) => ReviewTaskFact(
    taskId: (json['taskId'] ?? json['id'])?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    status: json['status']?.toString() ?? WorkStatus.todo,
    projectTitles: (json['projectTitles'] as List<dynamic>? ?? const [])
        .map((value) => value.toString())
        .toList(growable: false),
    groupId: json['groupId']?.toString(),
    groupTitle: json['groupTitle']?.toString(),
    groupMode: json['groupMode']?.toString(),
    chainPosition: (json['chainPosition'] as num?)?.toInt(),
    completedAt: _date(json['completedAt']),
    result: json['result']?.toString() ?? '',
    failureReason: json['failureReason']?.toString() ?? '',
    skipReason: json['skipReason']?.toString() ?? '',
    rescheduledTo: _date(json['rescheduledTo']),
    rescheduledFromId: json['rescheduledFromId']?.toString(),
  );
}

class ReviewGroupFact {
  const ReviewGroupFact({
    required this.groupId,
    required this.title,
    required this.mode,
    required this.memberTaskIds,
  });

  final String groupId;
  final String title;
  final String mode;
  final List<String> memberTaskIds;

  Map<String, dynamic> toJson() => {
    'groupId': groupId,
    'title': title,
    'mode': mode,
    'memberTaskIds': memberTaskIds,
  };

  factory ReviewGroupFact.fromJson(Map<String, dynamic> json) =>
      ReviewGroupFact(
        groupId: json['groupId']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        mode: json['mode']?.toString() ?? 'parallel',
        memberTaskIds: (json['memberTaskIds'] as List<dynamic>? ?? const [])
            .map((value) => value.toString())
            .toList(growable: false),
      );
}

class ReviewSnapshot {
  const ReviewSnapshot({
    required this.period,
    required this.capturedAt,
    required this.taskFacts,
    required this.groupFacts,
    this.focusSessionIds = const [],
    this.projectIds = const [],
    this.focusSeconds = 0,
  });

  final ReviewPeriod period;
  final DateTime capturedAt;
  final List<ReviewTaskFact> taskFacts;
  final List<ReviewGroupFact> groupFacts;
  final List<String> focusSessionIds;
  final List<String> projectIds;
  final int focusSeconds;

  int count(String status) =>
      taskFacts.where((fact) => fact.status == status).length;

  Map<String, dynamic> toJson() => {
    'version': 3,
    'period': period.toJson(),
    'capturedAt': capturedAt.toUtc().toIso8601String(),
    'taskFacts': taskFacts.map((fact) => fact.toJson()).toList(),
    'groupFacts': groupFacts.map((fact) => fact.toJson()).toList(),
    'taskIds': taskFacts.map((fact) => fact.taskId).toList(),
    'focusSessionIds': focusSessionIds,
    'projectIds': projectIds,
    'focusSeconds': focusSeconds,
    'completed': count(WorkStatus.done),
    'failed': count(WorkStatus.failed),
    'skipped': count(WorkStatus.skipped),
    'rescheduled': count(WorkStatus.rescheduled),
  };

  factory ReviewSnapshot.fromJson(Map<String, dynamic> json) {
    final facts = (json['taskFacts'] as List<dynamic>? ?? const [])
        .map(
          (value) =>
              ReviewTaskFact.fromJson(Map<String, dynamic>.from(value as Map)),
        )
        .toList(growable: false);
    return ReviewSnapshot(
      period: ReviewPeriod.fromJson(
        Map<String, dynamic>.from(json['period'] as Map? ?? const {}),
      ),
      capturedAt: _date(json['capturedAt']) ?? DateTime.now(),
      taskFacts: facts,
      groupFacts: (json['groupFacts'] as List<dynamic>? ?? const [])
          .map(
            (value) => ReviewGroupFact.fromJson(
              Map<String, dynamic>.from(value as Map),
            ),
          )
          .toList(growable: false),
      focusSessionIds: (json['focusSessionIds'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
      projectIds: (json['projectIds'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
      focusSeconds: (json['focusSeconds'] as num?)?.toInt() ?? 0,
    );
  }
}

class RsipNode {
  const RsipNode({
    required this.record,
    required this.type,
    required this.rule,
    required this.emoji,
    required this.passive,
    required this.stage,
    this.groupId,
    this.reinforcement = 0,
  });

  factory RsipNode.fromRecord(WorkspaceRecord record) => RsipNode(
    record: record,
    type: RsipNodeType.values.firstWhere(
      (value) => value.name == record.data['rsipNodeType'],
      orElse: () => RsipNodeType.policy,
    ),
    rule: record.data['rsipRule']?.toString() ?? record.body,
    emoji: record.data['rsipEmoji']?.toString() ?? '策',
    passive: record.data['rsipPassive'] == true,
    stage: (record.data['rsipStage']?.toString() ?? 'E0').toUpperCase(),
    groupId: record.data['rsipGroupId']?.toString(),
    reinforcement: (record.data['rsipReinforcement'] as num?)?.toInt() ?? 0,
  );

  final WorkspaceRecord record;
  final RsipNodeType type;
  final String rule;
  final String emoji;
  final bool passive;
  final String stage;
  final String? groupId;
  final int reinforcement;

  int get consecutiveExecutions => record.rsipChainCount;
  int get cumulativeExecutionDays =>
      (record.data['rsipCumulativeExecutionDays'] as num?)?.toInt() ??
      record.rsipChainCount;
  int get totalExecutions =>
      (record.data['rsipTotalExecutions'] as num?)?.toInt() ?? 0;
  int get totalViolations =>
      (record.data['rsipTotalViolations'] as num?)?.toInt() ?? 0;
  int get maxReinforcement =>
      (record.data['rsipMaxReinforcement'] as num?)?.toInt() ?? reinforcement;
}

class RsipNodeGroup {
  const RsipNodeGroup({
    required this.record,
    required this.emoji,
    required this.initialTolerance,
    required this.remainingTolerance,
  });

  factory RsipNodeGroup.fromRecord(WorkspaceRecord record) => RsipNodeGroup(
    record: record,
    emoji: record.data['emoji']?.toString() ?? '组',
    initialTolerance: (record.data['initialTolerance'] as num?)?.toInt() ?? 0,
    remainingTolerance:
        (record.data['remainingTolerance'] as num?)?.toInt() ??
        (record.data['initialTolerance'] as num?)?.toInt() ??
        0,
  );

  final WorkspaceRecord record;
  final String emoji;
  final int initialTolerance;
  final int remainingTolerance;
}

class RsipExecutionRecord {
  const RsipExecutionRecord({
    required this.record,
    required this.nodeId,
    required this.logicalDayKey,
    required this.status,
  });

  factory RsipExecutionRecord.fromRecord(WorkspaceRecord record) =>
      RsipExecutionRecord(
        record: record,
        nodeId: record.data['rsipNodeId']?.toString() ?? record.parentId ?? '',
        logicalDayKey: record.data['logicalDayKey']?.toString() ?? '',
        status: RsipExecutionStatus.values.firstWhere(
          (value) => value.name == record.data['executionStatus'],
          orElse: () => RsipExecutionStatus.skipped,
        ),
      );

  final WorkspaceRecord record;
  final String nodeId;
  final String logicalDayKey;
  final RsipExecutionStatus status;

  String get reason => record.data['reason']?.toString() ?? record.body;
  String get sourceId => record.data['sourceId']?.toString() ?? '';
  String get sourceEvent => record.data['sourceEvent']?.toString() ?? '';
  bool get corrected => record.data['correctedAt'] != null;
}

class RsipRunRecord {
  const RsipRunRecord({
    required this.record,
    required this.startedAt,
    this.endedAt,
    this.peakNodeCount = 0,
    this.collapseReason = '',
    this.nodeIds = const [],
  });

  factory RsipRunRecord.fromRecord(WorkspaceRecord record) => RsipRunRecord(
    record: record,
    startedAt: _date(record.data['startedAt']) ?? record.createdAt,
    endedAt: _date(record.data['endedAt']),
    peakNodeCount: (record.data['peakNodeCount'] as num?)?.toInt() ?? 0,
    collapseReason: record.data['collapseReason']?.toString() ?? '',
    nodeIds: (record.data['nodeIds'] as List<dynamic>? ?? const [])
        .map((value) => value.toString())
        .toList(growable: false),
  );

  final WorkspaceRecord record;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int peakNodeCount;
  final String collapseReason;
  final List<String> nodeIds;

  int get runNumber => (record.data['runNumber'] as num?)?.toInt() ?? 1;
  int get durationDays => (record.data['durationDays'] as num?)?.toInt() ?? 0;
  String get collapseNodeTitle =>
      record.data['collapseNodeTitle']?.toString() ?? '';
}

class RsipTaskLink {
  const RsipTaskLink({
    required this.record,
    required this.chainId,
    required this.nodeId,
    required this.chainKind,
    required this.triggerEvent,
    required this.effect,
    required this.automation,
    required this.active,
  });

  factory RsipTaskLink.fromRecord(WorkspaceRecord record) => RsipTaskLink(
    record: record,
    chainId:
        record.data['chainId']?.toString() ??
        record.data['taskId']?.toString() ??
        '',
    nodeId: record.data['rsipNodeId']?.toString() ?? '',
    chainKind: _enumByName(
      RsipTaskChainKind.values,
      record.data['chainKind'],
      RsipTaskChainKind.unit,
    ),
    triggerEvent: _enumByName(
      RsipTaskLinkTriggerEvent.values,
      record.data['triggerEvent'],
      RsipTaskLinkTriggerEvent.taskCompleted,
    ),
    effect: _enumByName(
      RsipTaskLinkEffect.values,
      record.data['effect'],
      RsipTaskLinkEffect.markRsipExecuted,
    ),
    automation: _enumByName(
      RsipTaskLinkAutomation.values,
      record.data['automation'],
      record.data['taskToRsipAutomatic'] == false
          ? RsipTaskLinkAutomation.confirm
          : RsipTaskLinkAutomation.automatic,
    ),
    active: record.data['active'] != false,
  );

  final WorkspaceRecord record;
  final String chainId;
  final String nodeId;
  final RsipTaskChainKind chainKind;
  final RsipTaskLinkTriggerEvent triggerEvent;
  final RsipTaskLinkEffect effect;
  final RsipTaskLinkAutomation automation;
  final bool active;

  String get taskId => chainKind == RsipTaskChainKind.unit ? chainId : '';
  bool get taskToRsipAutomatic =>
      automation == RsipTaskLinkAutomation.automatic &&
      (effect == RsipTaskLinkEffect.markRsipExecuted ||
          effect == RsipTaskLinkEffect.markRsipViolated);
  bool get rsipToTaskNeedsConfirmation =>
      automation == RsipTaskLinkAutomation.confirm &&
      (effect == RsipTaskLinkEffect.promptStartChain ||
          effect == RsipTaskLinkEffect.promptScheduleChain);
}

class RsipViolationPreview {
  const RsipViolationPreview({
    required this.node,
    required this.reinforcementBefore,
    required this.reinforcementAfter,
    required this.remainingToleranceBefore,
    required this.remainingToleranceAfter,
    required this.archiveNodeIds,
    required this.collapsesWholeGroup,
    required this.endsRun,
  });

  final WorkspaceRecord node;
  final int reinforcementBefore;
  final int reinforcementAfter;
  final int? remainingToleranceBefore;
  final int? remainingToleranceAfter;
  final List<String> archiveNodeIds;
  final bool collapsesWholeGroup;
  final bool endsRun;

  bool get onlyConsumesReinforcement => reinforcementBefore > 0;
}

class RsipInsight {
  const RsipInsight({
    required this.windowStart,
    required this.windowEnd,
    required this.metrics,
    required this.rule,
    required this.message,
  });

  final DateTime windowStart;
  final DateTime windowEnd;
  final Map<String, num> metrics;
  final String rule;
  final String message;
}

DateTime? _date(Object? value) {
  final text = value?.toString();
  if (text == null || text.isEmpty) return null;
  return DateTime.tryParse(text)?.toLocal();
}

T _enumByName<T extends Enum>(List<T> values, Object? value, T fallback) {
  final normalized = value?.toString().replaceAll('_', '').toLowerCase();
  return values.firstWhere(
    (item) => item.name.toLowerCase() == normalized,
    orElse: () => fallback,
  );
}
