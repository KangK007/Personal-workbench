import 'dart:convert';
import 'dart:math';

enum RecordKind {
  task,
  project,
  note,
  diary,
  link,
  goal,
  milestone,
  habit,
  habitLog,
  focusSession,
  timeBlock,
  template,
  savedView,
  relation,
  dailyPlan,
  growthEvent,
  profile,
  exceptionRule,
  protocolEvent,
}

enum SyncState { clean, dirty }

abstract final class WorkStatus {
  static const inbox = 'inbox';
  static const todo = 'todo';
  static const doing = 'doing';
  static const done = 'done';
  static const cancelled = 'cancelled';
  static const skipped = 'skipped';
  static const failed = 'failed';
  static const rescheduled = 'rescheduled';

  static const terminal = {done, failed, skipped, rescheduled, cancelled};
}

enum RecurrenceType { none, daily, weekdays, weekly, monthly, yearly }

enum TaskEditScope { occurrence, future, series }

enum ReviewPeriodType { daily, weekly, monthly, yearly }

const activeReviewPeriodTypes = [
  ReviewPeriodType.daily,
  ReviewPeriodType.weekly,
  ReviewPeriodType.monthly,
];

class PeriodReview {
  const PeriodReview({
    required this.record,
    required this.type,
    required this.periodKey,
  });

  factory PeriodReview.fromRecord(WorkspaceRecord record) => PeriodReview(
    record: record,
    type: ReviewPeriodType.values.firstWhere(
      (value) => value.name == record.data['periodType'],
      orElse: () => ReviewPeriodType.daily,
    ),
    periodKey: record.data['periodKey']?.toString() ?? '',
  );

  final WorkspaceRecord record;
  final ReviewPeriodType type;
  final String periodKey;
}

/// Stable task definition stored inside a [WorkspaceRecord] sync envelope.
class TaskDefinition {
  const TaskDefinition({
    required this.id,
    required this.title,
    required this.recurrence,
    this.weekdays = const [],
    this.startAt,
    this.endAt,
    this.completionWindowMinutes = 24 * 60,
    this.projectId,
    this.groupId,
  });

  factory TaskDefinition.fromRecord(WorkspaceRecord record) {
    final recurrence = record.data['recurrence']?.toString() ?? 'none';
    return TaskDefinition(
      id: record.id,
      title: record.title,
      recurrence: RecurrenceType.values.firstWhere(
        (value) => value.name == recurrence,
        orElse: () => RecurrenceType.none,
      ),
      weekdays:
          (record.data['recurrenceWeekdays'] as List<dynamic>? ?? const [])
              .map((value) => (value as num).toInt())
              .toList(growable: false),
      startAt: record.scheduledFor,
      endAt: DateTime.tryParse(
        record.data['recurrenceEndAt']?.toString() ?? '',
      )?.toLocal(),
      completionWindowMinutes:
          (record.data['completionWindowMinutes'] as num?)?.toInt() ?? 24 * 60,
      projectId: record.projectId,
      groupId: record.parentId,
    );
  }

  final String id;
  final String title;
  final RecurrenceType recurrence;
  final List<int> weekdays;
  final DateTime? startAt;
  final DateTime? endAt;
  final int completionWindowMinutes;
  final String? projectId;
  final String? groupId;

  bool get isRecurring => recurrence != RecurrenceType.none;
}

class TaskInstance {
  const TaskInstance({
    required this.record,
    required this.definitionId,
    required this.occurrenceKey,
  });

  factory TaskInstance.fromRecord(WorkspaceRecord record) => TaskInstance(
    record: record,
    definitionId: record.data['definitionId']?.toString() ?? record.id,
    occurrenceKey:
        record.data['occurrenceKey']?.toString() ??
        _dateKey(record.scheduledFor),
  );

  final WorkspaceRecord record;
  final String definitionId;
  final String occurrenceKey;

  bool get isTerminal => WorkStatus.terminal.contains(record.status);
  bool get isOverduePending => record.data['overduePending'] == true;
}

String _dateKey(DateTime? value) {
  final date = value?.toLocal();
  if (date == null) return '';
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

DateTime? nextOccurrence(DateTime base, String recurrence) {
  switch (recurrence) {
    case 'daily':
      return DateTime(
        base.year,
        base.month,
        base.day + 1,
        base.hour,
        base.minute,
      );
    case 'weekly':
      return base.add(const Duration(days: 7));
    case 'monthly':
      final targetMonth = DateTime(base.year, base.month + 1, 1);
      final lastDay = DateTime(targetMonth.year, targetMonth.month + 1, 0).day;
      return DateTime(
        targetMonth.year,
        targetMonth.month,
        min(base.day, lastDay),
        base.hour,
        base.minute,
      );
    case 'weekdays':
      var next = base.add(const Duration(days: 1));
      while (next.weekday == DateTime.saturday ||
          next.weekday == DateTime.sunday) {
        next = next.add(const Duration(days: 1));
      }
      return next;
    default:
      return null;
  }
}

const _unset = Object();
final _random = Random.secure();

String newRecordId() {
  final time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final random = _random.nextInt(0x7fffffff).toRadixString(36);
  return '$time-$random';
}

DateTime startOfDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);

bool isSameDay(DateTime? a, DateTime? b) {
  if (a == null || b == null) return false;
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

/// A typed record envelope shared by the local database and cloud sync layer.
/// Business screens only read fields relevant to their [kind].
class WorkspaceRecord {
  const WorkspaceRecord({
    required this.id,
    required this.kind,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.body = '',
    this.status = WorkStatus.todo,
    this.scheduledFor,
    this.dueAt,
    this.projectId,
    this.parentId,
    this.tags = const [],
    this.favorite = false,
    this.deletedAt,
    this.syncState = SyncState.dirty,
    this.data = const {},
  });

  factory WorkspaceRecord.create({
    required RecordKind kind,
    required String title,
    String body = '',
    String status = WorkStatus.todo,
    DateTime? scheduledFor,
    DateTime? dueAt,
    String? projectId,
    String? parentId,
    List<String> tags = const [],
    bool favorite = false,
    Map<String, dynamic> data = const {},
  }) {
    final now = DateTime.now();
    return WorkspaceRecord(
      id: newRecordId(),
      kind: kind,
      title: title.trim(),
      body: body.trim(),
      status: status,
      scheduledFor: scheduledFor,
      dueAt: dueAt,
      projectId: projectId,
      parentId: parentId,
      tags: tags,
      favorite: favorite,
      createdAt: now,
      updatedAt: now,
      data: Map<String, dynamic>.from(data),
    );
  }

  factory WorkspaceRecord.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(Object? value) {
      final text = value?.toString();
      if (text == null || text.isEmpty) return null;
      return DateTime.tryParse(text)?.toLocal();
    }

    return WorkspaceRecord(
      id: json['id'] as String,
      kind: RecordKind.values.firstWhere(
        (value) => value.name == json['kind'],
        orElse: () => RecordKind.note,
      ),
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      status: json['status']?.toString() ?? WorkStatus.todo,
      scheduledFor: parseDate(json['scheduledFor']),
      dueAt: parseDate(json['dueAt']),
      projectId: json['projectId']?.toString(),
      parentId: json['parentId']?.toString(),
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
      favorite: json['favorite'] == true,
      createdAt: parseDate(json['createdAt']) ?? DateTime.now(),
      updatedAt: parseDate(json['updatedAt']) ?? DateTime.now(),
      deletedAt: parseDate(json['deletedAt']),
      syncState: SyncState.values.firstWhere(
        (value) => value.name == json['syncState'],
        orElse: () => SyncState.dirty,
      ),
      data: Map<String, dynamic>.from(
        json['data'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }

  final String id;
  final RecordKind kind;
  final String title;
  final String body;
  final String status;
  final DateTime? scheduledFor;
  final DateTime? dueAt;
  final String? projectId;
  final String? parentId;
  final List<String> tags;
  final bool favorite;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final SyncState syncState;
  final Map<String, dynamic> data;

  bool get isDeleted => deletedAt != null;
  bool get isDone => status == WorkStatus.done;
  int get priority => (data['priority'] as num?)?.toInt() ?? 0;
  int get estimatedMinutes => (data['estimatedMinutes'] as num?)?.toInt() ?? 0;
  int get actualMinutes => (data['actualMinutes'] as num?)?.toInt() ?? 0;
  bool get isFocus => data['isFocus'] == true;

  /// CTDP task protocol state. Older tasks stay compatible and simply return
  /// false when they were created before protocol fields existed.
  bool get hasCtdpProtocol =>
      kind == RecordKind.task && data['protocol'] == 'ctdp';
  String get ctdpTrigger => data['ctdpTrigger']?.toString() ?? '';
  int get ctdpSessionMinutes =>
      (data['ctdpSessionMinutes'] as num?)?.toInt() ?? estimatedMinutes;
  int get ctdpDelayMinutes => (data['ctdpDelayMinutes'] as num?)?.toInt() ?? 15;
  int get ctdpChainCount => (data['ctdpChainCount'] as num?)?.toInt() ?? 0;
  int get ctdpReservationCount =>
      (data['ctdpReservationCount'] as num?)?.toInt() ?? 0;
  int get ctdpAuxChainCount =>
      (data['ctdpAuxChainCount'] as num?)?.toInt() ?? ctdpReservationCount;
  bool get ctdpReservationPending => data['ctdpReservationPending'] == true;
  String get ctdpUnitType => data['ctdpUnitType']?.toString() ?? 'unit';
  bool get ctdpIsGroup => ctdpUnitType == 'group';
  String get ctdpAuxSignal => data['ctdpAuxSignal']?.toString() ?? '';
  String get ctdpAuxCompletionTrigger =>
      data['ctdpAuxCompletionTrigger']?.toString() ?? '';
  bool get ctdpIsDurationless => data['ctdpIsDurationless'] == true;
  int get ctdpMinimumMinutes =>
      (data['ctdpMinimumMinutes'] as num?)?.toInt() ?? 0;
  int get ctdpTotalCompletions =>
      (data['ctdpTotalCompletions'] as num?)?.toInt() ?? 0;
  int get ctdpTotalFailures =>
      (data['ctdpTotalFailures'] as num?)?.toInt() ?? 0;
  int get ctdpAuxFailures => (data['ctdpAuxFailures'] as num?)?.toInt() ?? 0;
  int get ctdpGroupTimeLimitHours =>
      (data['ctdpGroupTimeLimitHours'] as num?)?.toInt() ?? 0;

  /// RSIP habit protocol state. The internalization counter is intentionally
  /// independent from the active tree, so a failed branch can be retried.
  bool get hasRsipProtocol =>
      kind == RecordKind.habit && data['protocol'] == 'rsip';
  String get rsipTrigger => data['rsipTrigger']?.toString() ?? '';
  String get rsipMinimumAction => data['rsipMinimumAction']?.toString() ?? '';
  bool get rsipActive => data['rsipActive'] != false;
  int get rsipChainCount => (data['rsipChainCount'] as num?)?.toInt() ?? 0;
  int get rsipInternalization =>
      (data['rsipInternalization'] as num?)?.toInt() ?? 0;
  int get rsipFailureCount => (data['rsipFailureCount'] as num?)?.toInt() ?? 0;
  String get rsipRule => data['rsipRule']?.toString() ?? body;
  String get rsipGroup => data['rsipGroup']?.toString() ?? '默认国策组';
  bool get rsipUseTimer => data['rsipUseTimer'] == true;
  int get rsipTimerMinutes => (data['rsipTimerMinutes'] as num?)?.toInt() ?? 1;
  bool get rsipTimerRunning => data['rsipTimerRunning'] == true;
  bool get rsipFrozen => data['rsipFrozen'] == true;

  WorkspaceRecord copyWith({
    String? title,
    String? body,
    String? status,
    Object? scheduledFor = _unset,
    Object? dueAt = _unset,
    Object? projectId = _unset,
    Object? parentId = _unset,
    List<String>? tags,
    bool? favorite,
    Object? deletedAt = _unset,
    SyncState? syncState,
    Map<String, dynamic>? data,
    bool touch = true,
  }) {
    return WorkspaceRecord(
      id: id,
      kind: kind,
      title: title ?? this.title,
      body: body ?? this.body,
      status: status ?? this.status,
      scheduledFor: identical(scheduledFor, _unset)
          ? this.scheduledFor
          : scheduledFor as DateTime?,
      dueAt: identical(dueAt, _unset) ? this.dueAt : dueAt as DateTime?,
      projectId: identical(projectId, _unset)
          ? this.projectId
          : projectId as String?,
      parentId: identical(parentId, _unset)
          ? this.parentId
          : parentId as String?,
      tags: tags ?? this.tags,
      favorite: favorite ?? this.favorite,
      createdAt: createdAt,
      updatedAt: touch ? DateTime.now() : updatedAt,
      deletedAt: identical(deletedAt, _unset)
          ? this.deletedAt
          : deletedAt as DateTime?,
      syncState: syncState ?? (touch ? SyncState.dirty : this.syncState),
      data: data ?? this.data,
    );
  }

  WorkspaceRecord withData(String key, Object? value) {
    final next = Map<String, dynamic>.from(data);
    if (value == null) {
      next.remove(key);
    } else {
      next[key] = value;
    }
    return copyWith(data: next);
  }

  WorkspaceRecord asConflictCopy() {
    return WorkspaceRecord.create(
      kind: kind,
      title: '$title（冲突副本）',
      body: body,
      status: status,
      scheduledFor: scheduledFor,
      dueAt: dueAt,
      projectId: projectId,
      parentId: parentId,
      tags: [...tags, '同步冲突'],
      favorite: favorite,
      data: {...data, 'conflictSourceId': id},
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'title': title,
    'body': body,
    'status': status,
    'scheduledFor': scheduledFor?.toUtc().toIso8601String(),
    'dueAt': dueAt?.toUtc().toIso8601String(),
    'projectId': projectId,
    'parentId': parentId,
    'tags': tags,
    'favorite': favorite,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'deletedAt': deletedAt?.toUtc().toIso8601String(),
    'syncState': syncState.name,
    'data': data,
  };

  String encode() => jsonEncode(toJson());
}

class BackupManifest {
  const BackupManifest({
    required this.version,
    required this.createdAt,
    required this.recordCount,
    required this.kinds,
  });

  factory BackupManifest.fromJson(Map<String, dynamic> json) {
    return BackupManifest(
      version: (json['version'] as num?)?.toInt() ?? 1,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      recordCount: (json['recordCount'] as num?)?.toInt() ?? 0,
      kinds: Map<String, int>.from(json['kinds'] as Map? ?? const {}),
    );
  }

  final int version;
  final DateTime createdAt;
  final int recordCount;
  final Map<String, int> kinds;

  Map<String, dynamic> toJson() => {
    'version': version,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'recordCount': recordCount,
    'kinds': kinds,
  };
}

extension RecordKindLabel on RecordKind {
  String get label => switch (this) {
    RecordKind.task => '任务',
    RecordKind.project => '项目',
    RecordKind.note => '笔记',
    RecordKind.diary => '日记',
    RecordKind.link => '链接',
    RecordKind.goal => '目标',
    RecordKind.milestone => '里程碑',
    RecordKind.habit => '习惯',
    RecordKind.habitLog => '习惯记录',
    RecordKind.focusSession => '专注记录',
    RecordKind.timeBlock => '时间块',
    RecordKind.template => '模板',
    RecordKind.savedView => '筛选',
    RecordKind.relation => '关联',
    RecordKind.dailyPlan => '每日计划',
    RecordKind.growthEvent => '成长记录',
    RecordKind.profile => '个人档案',
    RecordKind.exceptionRule => '协议判例',
    RecordKind.protocolEvent => '协议记录',
  };
}
