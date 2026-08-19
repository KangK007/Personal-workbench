import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_workbench/core/models/restriction_models.dart';
import 'package:personal_workbench/core/models/workspace_record.dart';
import 'package:personal_workbench/services/self_control_importer.dart';

void main() {
  late Directory source;

  setUp(() async {
    source = await Directory.systemTemp.createTemp('selfcontrol-import-');
    await File(
      '${source.path}${Platform.pathSeparator}config.json',
    ).writeAsString(
      jsonEncode({
        'schedule': [
          {
            'days': [0, 1, 2, 3, 4],
            'start': '22:00',
            'end': '06:00',
            'label': 'Research',
            'enabled': true,
          },
        ],
        'block_mode': 'blacklist',
        'action': 'force_close',
        'blocked_apps': ['Steam.EXE'],
        'allowed_apps': ['Code.exe'],
        'app_risk_levels': {'music.exe': 'warn'},
        'title_keyword_blocking': true,
        'title_keyword_processes': ['chrome.exe'],
        'blocked_title_keywords': ['video'],
        'website_blocking': true,
        'blocked_websites': ['example.com'],
        'poll_interval': 3,
        'allow_break': true,
        'break_minutes': 10,
        'max_breaks_per_day': 2,
        'strong_protection': true,
        'password_hash': 'must-not-import',
      }),
    );
    await File(
      '${source.path}${Platform.pathSeparator}events.jsonl',
    ).writeAsString(
      '${jsonEncode({'event_type': 'process_block', 'detected_at': '2026-08-18T10:00:00', 'process': 'steam.exe', 'pid': 42, 'action': 'force_close', 'reason': '应用黑名单', 'matched': 'steam.exe'})}\n',
    );
    await File(
      '${source.path}${Platform.pathSeparator}habits.json',
    ).writeAsString(
      jsonEncode({
        'habits': [
          {
            'id': 'reading',
            'name': '阅读',
            'frequency': 'daily',
            'linked_pomodoro': true,
            'created_at': '2026-08-01',
          },
        ],
        'checkins': {
          'reading': ['2026-08-18'],
        },
      }),
    );
    await File(
      '${source.path}${Platform.pathSeparator}pomodoro_state.json',
    ).writeAsString(
      jsonEncode({
        'session_history': [
          {
            'session_id': 'focus-1',
            'session_type': 'focus',
            'date': '2026-08-18',
            'started_at': '09:00:00',
            'duration_minutes': 25,
            'completed': true,
          },
          {
            'session_id': 'break-1',
            'session_type': 'short_break',
            'date': '2026-08-18',
            'started_at': '09:25:00',
            'duration_minutes': 5,
            'completed': true,
          },
        ],
      }),
    );
    await File(
      '${source.path}${Platform.pathSeparator}block_log.txt',
    ).writeAsString('archive');
  });

  tearDown(() async {
    if (await source.exists()) await source.delete(recursive: true);
  });

  test('preview maps rules, events, habits, focus and archive', () async {
    const importer = SelfControlImporter();
    final preview = await importer.preview(source);

    expect(preview.profile.enabled, isFalse);
    expect(preview.profile.schedules.single.days.first, DateTime.monday);
    expect(preview.profile.schedules.single.crossesMidnight, isTrue);
    expect(preview.profile.defaultAction, RestrictionAction.forceClose);
    expect(preview.eventCount, 1);
    expect(preview.habitCount, 1);
    expect(preview.habitLogCount, 1);
    expect(preview.focusSessionCount, 1);
    expect(preview.records, hasLength(6));
    expect(
      preview.records.where((record) => record.kind == RecordKind.focusSession),
      hasLength(1),
    );
    expect(preview.warnings, isNotEmpty);
  });

  test('repeated previews generate stable record identifiers', () async {
    const importer = SelfControlImporter();
    final first = await importer.preview(source);
    final second = await importer.preview(source);
    expect(
      second.records.map((record) => record.id).toList(),
      first.records.map((record) => record.id).toList(),
    );
  });
}
