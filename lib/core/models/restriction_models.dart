import 'workspace_record.dart';

enum RestrictionBlockMode { blacklist, whitelist }

enum RestrictionAction { warn, forceClose }

class RestrictionScheduleRule {
  const RestrictionScheduleRule({
    required this.id,
    required this.label,
    required this.days,
    required this.startMinutes,
    required this.endMinutes,
    this.enabled = true,
  });

  factory RestrictionScheduleRule.fromJson(Map<String, dynamic> json) {
    return RestrictionScheduleRule(
      id: json['id']?.toString() ?? newRecordId(),
      label: json['label']?.toString() ?? '限制时段',
      days: (json['days'] as List<dynamic>? ?? const [])
          .map((value) => (value as num).toInt())
          .where(
            (value) => value >= DateTime.monday && value <= DateTime.sunday,
          )
          .toSet()
          .toList(growable: false),
      startMinutes: ((json['startMinutes'] as num?)?.toInt() ?? 0).clamp(
        0,
        1439,
      ),
      endMinutes: ((json['endMinutes'] as num?)?.toInt() ?? 0).clamp(0, 1439),
      enabled: json['enabled'] != false,
    );
  }

  final String id;
  final String label;
  final List<int> days;
  final int startMinutes;
  final int endMinutes;
  final bool enabled;

  bool get crossesMidnight => startMinutes > endMinutes;

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'days': days,
    'startMinutes': startMinutes,
    'endMinutes': endMinutes,
    'enabled': enabled,
  };
}

class RestrictionProfile {
  const RestrictionProfile({
    required this.id,
    required this.title,
    this.enabled = false,
    this.schedules = const [],
    this.blockMode = RestrictionBlockMode.blacklist,
    this.defaultAction = RestrictionAction.warn,
    this.blockedApps = const [],
    this.allowedApps = const [],
    this.appActions = const {},
    this.titleKeywordBlocking = true,
    this.titleKeywordAction = RestrictionAction.warn,
    this.titleKeywordProcesses = const [],
    this.blockedTitleKeywords = const [],
    this.websiteBlocking = false,
    this.blockedWebsites = const [],
    this.pollIntervalSeconds = 3,
    this.allowBreak = false,
    this.breakMinutes = 15,
    this.maxBreaksPerDay = 3,
    this.strongProtection = false,
    this.sourceImportId,
  });

  factory RestrictionProfile.fromRecord(WorkspaceRecord record) {
    final data = record.data;
    return RestrictionProfile(
      id: record.id,
      title: record.title,
      enabled: data['enabled'] == true,
      schedules: (data['schedules'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (value) => RestrictionScheduleRule.fromJson(
              Map<String, dynamic>.from(value),
            ),
          )
          .toList(growable: false),
      blockMode: RestrictionBlockMode.values.firstWhere(
        (value) => value.name == data['blockMode'],
        orElse: () => RestrictionBlockMode.blacklist,
      ),
      defaultAction: restrictionActionFromJson(data['defaultAction']),
      blockedApps: _normalizedList(data['blockedApps']),
      allowedApps: _normalizedList(data['allowedApps']),
      appActions: (data['appActions'] as Map? ?? const {}).map(
        (key, value) => MapEntry(
          key.toString().trim().toLowerCase(),
          restrictionActionFromJson(value),
        ),
      ),
      titleKeywordBlocking: data['titleKeywordBlocking'] != false,
      titleKeywordAction: restrictionActionFromJson(data['titleKeywordAction']),
      titleKeywordProcesses: _normalizedList(data['titleKeywordProcesses']),
      blockedTitleKeywords: _normalizedList(data['blockedTitleKeywords']),
      websiteBlocking: data['websiteBlocking'] == true,
      blockedWebsites: _normalizedList(data['blockedWebsites']),
      pollIntervalSeconds: ((data['pollIntervalSeconds'] as num?)?.toInt() ?? 3)
          .clamp(1, 60),
      allowBreak: data['allowBreak'] == true,
      breakMinutes: ((data['breakMinutes'] as num?)?.toInt() ?? 15).clamp(
        1,
        240,
      ),
      maxBreaksPerDay: ((data['maxBreaksPerDay'] as num?)?.toInt() ?? 3).clamp(
        0,
        99,
      ),
      strongProtection: data['strongProtection'] == true,
      sourceImportId: data['sourceImportId']?.toString(),
    );
  }

  final String id;
  final String title;
  final bool enabled;
  final List<RestrictionScheduleRule> schedules;
  final RestrictionBlockMode blockMode;
  final RestrictionAction defaultAction;
  final List<String> blockedApps;
  final List<String> allowedApps;
  final Map<String, RestrictionAction> appActions;
  final bool titleKeywordBlocking;
  final RestrictionAction titleKeywordAction;
  final List<String> titleKeywordProcesses;
  final List<String> blockedTitleKeywords;
  final bool websiteBlocking;
  final List<String> blockedWebsites;
  final int pollIntervalSeconds;
  final bool allowBreak;
  final int breakMinutes;
  final int maxBreaksPerDay;
  final bool strongProtection;
  final String? sourceImportId;

  RestrictionProfile copyWith({
    String? title,
    bool? enabled,
    List<RestrictionScheduleRule>? schedules,
    RestrictionBlockMode? blockMode,
    RestrictionAction? defaultAction,
    List<String>? blockedApps,
    List<String>? allowedApps,
    Map<String, RestrictionAction>? appActions,
    bool? titleKeywordBlocking,
    RestrictionAction? titleKeywordAction,
    List<String>? titleKeywordProcesses,
    List<String>? blockedTitleKeywords,
    bool? websiteBlocking,
    List<String>? blockedWebsites,
    int? pollIntervalSeconds,
    bool? allowBreak,
    int? breakMinutes,
    int? maxBreaksPerDay,
    bool? strongProtection,
    String? sourceImportId,
  }) {
    return RestrictionProfile(
      id: id,
      title: title ?? this.title,
      enabled: enabled ?? this.enabled,
      schedules: schedules ?? this.schedules,
      blockMode: blockMode ?? this.blockMode,
      defaultAction: defaultAction ?? this.defaultAction,
      blockedApps: blockedApps ?? this.blockedApps,
      allowedApps: allowedApps ?? this.allowedApps,
      appActions: appActions ?? this.appActions,
      titleKeywordBlocking: titleKeywordBlocking ?? this.titleKeywordBlocking,
      titleKeywordAction: titleKeywordAction ?? this.titleKeywordAction,
      titleKeywordProcesses:
          titleKeywordProcesses ?? this.titleKeywordProcesses,
      blockedTitleKeywords: blockedTitleKeywords ?? this.blockedTitleKeywords,
      websiteBlocking: websiteBlocking ?? this.websiteBlocking,
      blockedWebsites: blockedWebsites ?? this.blockedWebsites,
      pollIntervalSeconds: pollIntervalSeconds ?? this.pollIntervalSeconds,
      allowBreak: allowBreak ?? this.allowBreak,
      breakMinutes: breakMinutes ?? this.breakMinutes,
      maxBreaksPerDay: maxBreaksPerDay ?? this.maxBreaksPerDay,
      strongProtection: strongProtection ?? this.strongProtection,
      sourceImportId: sourceImportId ?? this.sourceImportId,
    );
  }

  Map<String, dynamic> toData() => {
    'recordType': 'restrictionProfile',
    'schemaVersion': 1,
    'enabled': enabled,
    'schedules': schedules.map((value) => value.toJson()).toList(),
    'blockMode': blockMode.name,
    'defaultAction': defaultAction.name,
    'blockedApps': _dedupe(blockedApps),
    'allowedApps': _dedupe(allowedApps),
    'appActions': appActions.map(
      (key, value) => MapEntry(key.trim().toLowerCase(), value.name),
    ),
    'titleKeywordBlocking': titleKeywordBlocking,
    'titleKeywordAction': titleKeywordAction.name,
    'titleKeywordProcesses': _dedupe(titleKeywordProcesses),
    'blockedTitleKeywords': _dedupe(blockedTitleKeywords),
    'websiteBlocking': websiteBlocking,
    'blockedWebsites': _dedupe(blockedWebsites),
    'pollIntervalSeconds': pollIntervalSeconds.clamp(1, 60),
    'allowBreak': allowBreak,
    'breakMinutes': breakMinutes.clamp(1, 240),
    'maxBreaksPerDay': maxBreaksPerDay.clamp(0, 99),
    'strongProtection': strongProtection,
    if (sourceImportId != null) 'sourceImportId': sourceImportId,
  };

  WorkspaceRecord toRecord({WorkspaceRecord? existing}) {
    if (existing != null) {
      return existing.copyWith(title: title.trim(), data: toData());
    }
    final now = DateTime.now();
    return WorkspaceRecord(
      id: id,
      kind: RecordKind.template,
      title: title.trim(),
      status: WorkStatus.todo,
      createdAt: now,
      updatedAt: now,
      data: toData(),
    );
  }
}

class RestrictionProcessSnapshot {
  const RestrictionProcessSnapshot({
    required this.pid,
    required this.name,
    this.executablePath = '',
    this.windowTitles = const [],
  });

  factory RestrictionProcessSnapshot.fromJson(Map<dynamic, dynamic> json) {
    return RestrictionProcessSnapshot(
      pid: (json['pid'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      executablePath: json['executablePath']?.toString() ?? '',
      windowTitles: (json['windowTitles'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
    );
  }

  final int pid;
  final String name;
  final String executablePath;
  final List<String> windowTitles;
}

class RestrictionViolation {
  const RestrictionViolation({
    required this.process,
    required this.action,
    required this.reasonCode,
    required this.reason,
    required this.matched,
  });

  final RestrictionProcessSnapshot process;
  final RestrictionAction action;
  final String reasonCode;
  final String reason;
  final String matched;
}

class RestrictionTransition {
  const RestrictionTransition({
    required this.kind,
    required this.at,
    required this.label,
  });

  final String kind;
  final DateTime? at;
  final String label;
}

class RestrictionHostsStatus {
  const RestrictionHostsStatus({
    this.supported = false,
    this.administrator = false,
    this.active = false,
    this.markerPresent = false,
    this.externallyModified = false,
    this.missingEntries = const [],
    this.error = '',
  });

  factory RestrictionHostsStatus.fromJson(Map<dynamic, dynamic> json) {
    return RestrictionHostsStatus(
      supported: json['supported'] == true,
      administrator: json['administrator'] == true,
      active: json['active'] == true,
      markerPresent: json['markerPresent'] == true,
      externallyModified: json['externallyModified'] == true,
      missingEntries: (json['missingEntries'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
      error: json['error']?.toString() ?? '',
    );
  }

  final bool supported;
  final bool administrator;
  final bool active;
  final bool markerPresent;
  final bool externallyModified;
  final List<String> missingEntries;
  final String error;
}

RestrictionAction restrictionActionFromJson(Object? value) {
  final text = value?.toString();
  return text == 'forceClose' || text == 'force_close'
      ? RestrictionAction.forceClose
      : RestrictionAction.warn;
}

List<String> _normalizedList(Object? value) => _dedupe(
  (value as List<dynamic>? ?? const []).map((item) => item.toString()),
);

List<String> _dedupe(Iterable<String> values) {
  final result = <String>[];
  final seen = <String>{};
  for (final value in values) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isNotEmpty && seen.add(normalized)) result.add(normalized);
  }
  return result;
}
