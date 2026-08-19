import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/models/restriction_models.dart';
import '../core/models/workspace_record.dart';

class SelfControlImportPreview {
  const SelfControlImportPreview({
    required this.profile,
    required this.records,
    required this.eventCount,
    required this.habitCount,
    required this.habitLogCount,
    required this.focusSessionCount,
    required this.warnings,
    this.blockLog,
  });

  final RestrictionProfile profile;
  final List<WorkspaceRecord> records;
  final int eventCount;
  final int habitCount;
  final int habitLogCount;
  final int focusSessionCount;
  final List<String> warnings;
  final File? blockLog;

  int get totalRecordCount => records.length;
}

class SelfControlImporter {
  const SelfControlImporter();

  static const sourceImportId = 'selfcontrol-legacy-v2';
  static const maxSourceFileBytes = 10 * 1024 * 1024;

  Future<SelfControlImportPreview> preview(Directory source) async {
    if (!await source.exists()) {
      throw const FormatException('SelfControl 来源目录不存在。');
    }
    final configFile = File(p.join(source.path, 'config.json'));
    if (!await configFile.exists()) {
      throw const FormatException('所选目录中没有 config.json。');
    }
    final config = await _readJsonMap(configFile);
    final warnings = <String>[];
    if ((config['password_hash']?.toString() ?? '').isNotEmpty) {
      warnings.add('旧管理密码不会导入，请在个人工作台重新设置保护密码。');
    }
    final profile = _profileFromConfig(config);
    final records = <WorkspaceRecord>[profile.toRecord()];

    var eventCount = 0;
    final eventsFile = File(p.join(source.path, 'events.jsonl'));
    if (await eventsFile.exists()) {
      await _checkSize(eventsFile);
      final lines = await eventsFile.readAsLines();
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        try {
          final json = jsonDecode(trimmed) as Map<String, dynamic>;
          records.add(_eventRecord(json, trimmed));
          eventCount++;
        } catch (_) {
          warnings.add('结构化事件中有一行无法解析，已跳过。');
        }
      }
    }

    var habitCount = 0;
    var habitLogCount = 0;
    final habitsFile = File(p.join(source.path, 'habits.json'));
    if (await habitsFile.exists()) {
      final habitsJson = await _readJsonMap(habitsFile);
      final habitIds = <String, String>{};
      for (final value in habitsJson['habits'] as List<dynamic>? ?? const []) {
        if (value is! Map) continue;
        final legacy = Map<String, dynamic>.from(value);
        final legacyId = legacy['id']?.toString() ?? '${habitCount + 1}';
        final id = 'legacy-selfcontrol-habit-${_stableHash(legacyId)}';
        habitIds[legacyId] = id;
        records.add(_habitRecord(id, legacy));
        habitCount++;
      }
      final checkins = habitsJson['checkins'];
      if (checkins is Map) {
        for (final entry in checkins.entries) {
          final habitId = habitIds[entry.key.toString()];
          if (habitId == null || entry.value is! List) continue;
          for (final dateValue in entry.value as List<dynamic>) {
            final day = DateTime.tryParse(dateValue.toString());
            if (day == null) continue;
            records.add(_habitLogRecord(habitId, day));
            habitLogCount++;
          }
        }
      }
    }

    var focusSessionCount = 0;
    final pomodoroFile = File(p.join(source.path, 'pomodoro_state.json'));
    if (await pomodoroFile.exists()) {
      final state = await _readJsonMap(pomodoroFile);
      for (final value
          in state['session_history'] as List<dynamic>? ?? const []) {
        if (value is! Map) continue;
        final session = Map<String, dynamic>.from(value);
        if (session['session_type']?.toString() != 'focus') continue;
        final record = _focusRecord(session);
        if (record == null) continue;
        records.add(record);
        focusSessionCount++;
      }
    }

    final blockLog = File(p.join(source.path, 'block_log.txt'));
    final archive = await blockLog.exists() ? blockLog : null;
    if (archive != null) await _checkSize(archive);
    if (archive != null) records.add(_logArchiveRecord(archive));

    return SelfControlImportPreview(
      profile: profile,
      records: records,
      eventCount: eventCount,
      habitCount: habitCount,
      habitLogCount: habitLogCount,
      focusSessionCount: focusSessionCount,
      warnings: warnings.toSet().toList(growable: false),
      blockLog: archive,
    );
  }

  RestrictionProfile _profileFromConfig(Map<String, dynamic> config) {
    final schedules = <RestrictionScheduleRule>[];
    for (final value in config['schedule'] as List<dynamic>? ?? const []) {
      if (value is! Map) continue;
      final rule = Map<String, dynamic>.from(value);
      final start = _parseTime(rule['start']?.toString());
      final end = _parseTime(rule['end']?.toString());
      if (start == null || end == null) continue;
      final days = (rule['days'] as List<dynamic>? ?? const [])
          .map((value) => (value as num).toInt() + 1)
          .where(
            (value) => value >= DateTime.monday && value <= DateTime.sunday,
          )
          .toList(growable: false);
      schedules.add(
        RestrictionScheduleRule(
          id: 'legacy-schedule-${schedules.length + 1}',
          label: rule['label']?.toString() ?? '限制时段',
          days: days,
          startMinutes: start,
          endMinutes: end,
          enabled: rule['enabled'] != false,
        ),
      );
    }
    final actions = <String, RestrictionAction>{};
    final rawActions = config['app_risk_levels'];
    if (rawActions is Map) {
      for (final entry in rawActions.entries) {
        actions[entry.key.toString().trim().toLowerCase()] =
            restrictionActionFromJson(entry.value);
      }
    }
    return RestrictionProfile(
      id: 'legacy-selfcontrol-restriction-profile',
      title: 'SelfControl 导入规则',
      enabled: false,
      schedules: schedules,
      blockMode: config['block_mode'] == 'whitelist'
          ? RestrictionBlockMode.whitelist
          : RestrictionBlockMode.blacklist,
      defaultAction: restrictionActionFromJson(config['action']),
      blockedApps: _strings(config['blocked_apps']),
      allowedApps: _strings(config['allowed_apps']),
      appActions: actions,
      titleKeywordBlocking: config['title_keyword_blocking'] != false,
      titleKeywordAction: restrictionActionFromJson(
        config['title_keyword_action'],
      ),
      titleKeywordProcesses: _strings(config['title_keyword_processes']),
      blockedTitleKeywords: _strings(config['blocked_title_keywords']),
      websiteBlocking: config['website_blocking'] == true,
      blockedWebsites: _strings(config['blocked_websites']),
      pollIntervalSeconds: ((config['poll_interval'] as num?)?.toInt() ?? 3)
          .clamp(1, 60),
      allowBreak: config['allow_break'] == true,
      breakMinutes: ((config['break_minutes'] as num?)?.toInt() ?? 15).clamp(
        1,
        240,
      ),
      maxBreaksPerDay: ((config['max_breaks_per_day'] as num?)?.toInt() ?? 3)
          .clamp(0, 99),
      strongProtection: config['strong_protection'] == true,
      sourceImportId: sourceImportId,
    );
  }

  WorkspaceRecord _eventRecord(Map<String, dynamic> json, String sourceLine) {
    final detectedAt =
        DateTime.tryParse(
          json['detected_at']?.toString() ??
              json['recorded_at']?.toString() ??
              '',
        ) ??
        DateTime.now();
    return WorkspaceRecord(
      id: 'legacy-selfcontrol-event-${_stableHash(sourceLine)}',
      kind: RecordKind.protocolEvent,
      title: json['process']?.toString() ?? 'SelfControl 拦截事件',
      status: WorkStatus.done,
      scheduledFor: detectedAt,
      createdAt: detectedAt,
      updatedAt: detectedAt,
      data: {
        'recordType': 'restrictionEvent',
        'sourceImportId': sourceImportId,
        'process': json['process']?.toString() ?? '',
        'pid': (json['pid'] as num?)?.toInt() ?? 0,
        'action': restrictionActionFromJson(json['action']).name,
        'reason': json['reason']?.toString() ?? '',
        'matched': json['matched']?.toString() ?? '',
        'detectedAt': detectedAt.toUtc().toIso8601String(),
        'executionResult': 'legacyImported',
      },
    );
  }

  WorkspaceRecord _habitRecord(String id, Map<String, dynamic> legacy) {
    final createdAt =
        DateTime.tryParse(legacy['created_at']?.toString() ?? '') ??
        DateTime.now();
    return WorkspaceRecord(
      id: id,
      kind: RecordKind.habit,
      title: legacy['name']?.toString().trim().isNotEmpty == true
          ? legacy['name'].toString().trim()
          : 'SelfControl 习惯',
      status: WorkStatus.todo,
      createdAt: createdAt,
      updatedAt: createdAt,
      data: {
        'sourceImportId': sourceImportId,
        'legacyId': legacy['id']?.toString() ?? '',
        'frequency': legacy['frequency']?.toString() ?? 'daily',
        'linkedPomodoro': legacy['linked_pomodoro'] == true,
        if (legacy['icon'] != null) 'emoji': legacy['icon'].toString(),
      },
    );
  }

  WorkspaceRecord _habitLogRecord(String habitId, DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    return WorkspaceRecord(
      id: 'legacy-selfcontrol-checkin-${_stableHash('$habitId:${day.toIso8601String()}')}',
      kind: RecordKind.habitLog,
      title: 'SelfControl 习惯打卡',
      status: WorkStatus.done,
      parentId: habitId,
      scheduledFor: normalized,
      createdAt: normalized,
      updatedAt: normalized,
      data: {'sourceImportId': sourceImportId},
    );
  }

  WorkspaceRecord? _focusRecord(Map<String, dynamic> session) {
    final day = DateTime.tryParse(session['date']?.toString() ?? '');
    if (day == null) return null;
    final parts = (session['started_at']?.toString() ?? '00:00:00').split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final second = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
    final startedAt = DateTime(
      day.year,
      day.month,
      day.day,
      hour,
      minute,
      second,
    );
    final duration = ((session['duration_minutes'] as num?)?.toInt() ?? 0)
        .clamp(0, 24 * 60);
    if (duration < 1) return null;
    final legacyId =
        session['session_id']?.toString() ??
        '${day.toIso8601String()}:$hour:$minute:$duration';
    return WorkspaceRecord(
      id: 'legacy-selfcontrol-focus-${_stableHash(legacyId)}',
      kind: RecordKind.focusSession,
      title: 'SelfControl 番茄专注',
      status: session['completed'] == false
          ? WorkStatus.cancelled
          : WorkStatus.done,
      scheduledFor: startedAt,
      createdAt: startedAt,
      updatedAt: startedAt,
      data: {
        'sourceImportId': sourceImportId,
        'legacyId': legacyId,
        'seconds': duration * 60,
        'mode': 'pomodoro25',
        'pausedSeconds': (session['paused_seconds'] as num?)?.toInt() ?? 0,
        'legacyCompleted': session['completed'] != false,
      },
    );
  }

  WorkspaceRecord _logArchiveRecord(File source) {
    final now = DateTime.now();
    return WorkspaceRecord(
      id: 'legacy-selfcontrol-log-archive',
      kind: RecordKind.note,
      title: 'SelfControl 旧版文本日志归档',
      body: '旧版纯文本日志仅作为只读附件保存；结构化统计使用已导入的 events.jsonl。',
      status: WorkStatus.done,
      createdAt: now,
      updatedAt: now,
      data: {
        'sourceImportId': sourceImportId,
        'recordType': 'restrictionLogArchive',
        'sourceFileName': p.basename(source.path),
      },
    );
  }

  Future<Map<String, dynamic>> _readJsonMap(File file) async {
    await _checkSize(file);
    try {
      final value = jsonDecode(await file.readAsString());
      if (value is! Map) throw const FormatException('JSON 根节点必须是对象。');
      return Map<String, dynamic>.from(value);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw FormatException('${p.basename(file.path)} 无法读取。');
    }
  }

  Future<void> _checkSize(File file) async {
    if (await file.length() > maxSourceFileBytes) {
      throw FormatException('${p.basename(file.path)} 超过 10 MB，已停止导入。');
    }
  }

  int? _parseTime(String? value) {
    final parts = value?.split(':');
    if (parts == null || parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }
    return hour * 60 + minute;
  }

  List<String> _strings(Object? value) {
    final result = <String>[];
    final seen = <String>{};
    for (final item in value as List<dynamic>? ?? const []) {
      final normalized = item.toString().trim().toLowerCase();
      if (normalized.isNotEmpty && seen.add(normalized)) result.add(normalized);
    }
    return result;
  }

  String _stableHash(String value) {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(value)) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
