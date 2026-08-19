import 'dart:async';

import '../core/models/restriction_models.dart';
import 'restriction_policy_engine.dart';
import 'windows_activity_service.dart';

class RestrictionMonitorState {
  const RestrictionMonitorState({
    this.running = false,
    this.active = false,
    this.activeRule,
    this.activeSnapshot,
    this.pausedUntil,
    this.breakDayKey = '',
    this.breaksUsed = 0,
    this.lastError = '',
  });

  final bool running;
  final bool active;
  final RestrictionScheduleRule? activeRule;
  final RestrictionProfile? activeSnapshot;
  final DateTime? pausedUntil;
  final String breakDayKey;
  final int breaksUsed;
  final String lastError;

  bool isPaused(DateTime now) => pausedUntil?.isAfter(now) == true;
}

typedef RestrictionEventCallback =
    Future<void> Function(
      RestrictionViolation violation,
      bool actionSucceeded,
    );
typedef RestrictionStateCallback =
    Future<void> Function(RestrictionMonitorState state);

class RestrictionMonitor {
  RestrictionMonitor({
    required this.activityService,
    required this.profileProvider,
    required this.onEvent,
    required this.onStateChanged,
    this.policyEngine = const RestrictionPolicyEngine(),
    DateTime Function()? now,
  }) : _clock = now ?? DateTime.now;

  final WindowsActivityService activityService;
  final RestrictionProfile? Function() profileProvider;
  final RestrictionEventCallback onEvent;
  final RestrictionStateCallback onStateChanged;
  final RestrictionPolicyEngine policyEngine;
  final DateTime Function() _clock;

  final Map<String, DateTime> _violationCooldowns = {};
  Timer? _timer;
  RestrictionProfile? _activeSnapshot;
  RestrictionScheduleRule? _activeRule;
  DateTime? _pausedUntil;
  String _breakDayKey = '';
  int _breaksUsed = 0;
  bool _running = false;
  bool _active = false;
  bool _hostsApplied = false;
  String _hostsFingerprint = '';
  String _lastError = '';

  RestrictionMonitorState get state => RestrictionMonitorState(
    running: _running,
    active: _active,
    activeRule: _activeRule,
    activeSnapshot: _activeSnapshot,
    pausedUntil: _pausedUntil,
    breakDayKey: _breakDayKey,
    breaksUsed: _breaksUsed,
    lastError: _lastError,
  );

  void restore({
    RestrictionProfile? activeSnapshot,
    DateTime? pausedUntil,
    String breakDayKey = '',
    int breaksUsed = 0,
  }) {
    _activeSnapshot = activeSnapshot;
    _pausedUntil = pausedUntil;
    _breakDayKey = breakDayKey;
    _breaksUsed = breaksUsed;
  }

  Future<bool> start() async {
    if (_running || !await activityService.bridgeAvailable()) return false;
    _running = true;
    await poll();
    _scheduleNext();
    return true;
  }

  Future<void> stop({bool cleanup = true}) async {
    _timer?.cancel();
    _timer = null;
    _running = false;
    if (cleanup) await _leaveRestriction();
    await _emitState();
  }

  Future<void> poll() async {
    final now = _clock();
    _rollBreakDay(now);
    if (_pausedUntil != null && !now.isBefore(_pausedUntil!)) {
      _pausedUntil = null;
    }

    final current = profileProvider();
    final effective = _activeSnapshot?.strongProtection == true
        ? _activeSnapshot
        : current;
    final rule = effective == null || !effective.enabled
        ? null
        : policyEngine.activeRule(effective, now);
    if (rule == null) {
      if (_active) await _leaveRestriction();
      return;
    }

    if (!_active) {
      _active = true;
      _activeRule = rule;
      _activeSnapshot = effective;
      _lastError = '';
      await activityService.setExitGuard(true);
      if (effective!.websiteBlocking && effective.blockedWebsites.isNotEmpty) {
        _hostsApplied = await activityService.applyHostsPolicy(
          effective.blockedWebsites,
        );
        _hostsFingerprint = _fingerprint(effective.blockedWebsites);
        if (!_hostsApplied) _lastError = '网站拦截未能写入 hosts。';
      }
      await _emitState();
    } else {
      _activeRule = rule;
      if (_activeSnapshot?.strongProtection != true) {
        _activeSnapshot = effective;
      }
    }

    final profile = _activeSnapshot!;
    final nextFingerprint = _fingerprint(profile.blockedWebsites);
    if ((!profile.websiteBlocking || profile.blockedWebsites.isEmpty) &&
        _hostsApplied) {
      await activityService.clearHostsPolicy();
      _hostsApplied = false;
      _hostsFingerprint = '';
    }
    if (_pausedUntil?.isAfter(now) == true) {
      await _emitState();
      return;
    }
    if (profile.websiteBlocking &&
        profile.blockedWebsites.isNotEmpty &&
        (!_hostsApplied || _hostsFingerprint != nextFingerprint)) {
      if (_hostsApplied) await activityService.clearHostsPolicy();
      _hostsApplied = await activityService.applyHostsPolicy(
        profile.blockedWebsites,
      );
      _hostsFingerprint = nextFingerprint;
      if (!_hostsApplied) _lastError = '网站拦截未能写入 hosts。';
    }
    for (final process in await activityService.processSnapshot()) {
      final violation = policyEngine.evaluateProcess(profile, process);
      if (violation == null || !_shouldReport(violation, now)) continue;
      var succeeded = true;
      if (violation.action == RestrictionAction.forceClose) {
        succeeded = await activityService.terminateProcess(
          pid: process.pid,
          expectedName: process.name,
        );
      }
      await activityService.showNotification(
        title: violation.action == RestrictionAction.forceClose
            ? succeeded
                  ? '已结束受限应用'
                  : '受限应用未能结束'
            : '自律规则提醒',
        body: '${process.name} · ${violation.reason}',
      );
      await onEvent(violation, succeeded);
    }
  }

  Future<void> takeBreak() async {
    final now = _clock();
    _rollBreakDay(now);
    final profile = _activeSnapshot ?? profileProvider();
    if (!_active || profile == null || !profile.allowBreak) {
      throw const FormatException('当前限制规则不允许临时休息。');
    }
    if (profile.maxBreaksPerDay > 0 &&
        _breaksUsed >= profile.maxBreaksPerDay) {
      throw const FormatException('今日临时休息次数已用完。');
    }
    _breaksUsed++;
    _pausedUntil = now.add(Duration(minutes: profile.breakMinutes));
    if (_hostsApplied) {
      await activityService.clearHostsPolicy();
      _hostsApplied = false;
      _hostsFingerprint = '';
    }
    await _emitState();
  }

  Future<void> resumeNow() async {
    _pausedUntil = null;
    final profile = _activeSnapshot;
    if (_active &&
        profile != null &&
        profile.websiteBlocking &&
        profile.blockedWebsites.isNotEmpty) {
      _hostsApplied = await activityService.applyHostsPolicy(
        profile.blockedWebsites,
      );
      _hostsFingerprint = _fingerprint(profile.blockedWebsites);
    }
    await _emitState();
  }

  Future<void> _leaveRestriction() async {
    if (_hostsApplied || _activeSnapshot?.websiteBlocking == true) {
      await activityService.clearHostsPolicy();
    }
    await activityService.setExitGuard(false);
    _active = false;
    _activeRule = null;
    _activeSnapshot = null;
    _pausedUntil = null;
    _hostsApplied = false;
    _hostsFingerprint = '';
    _violationCooldowns.clear();
    await _emitState();
  }

  bool _shouldReport(RestrictionViolation violation, DateTime now) {
    final key = '${violation.process.pid}:${violation.reasonCode}:${violation.matched}';
    final previous = _violationCooldowns[key];
    if (previous != null && now.difference(previous) < const Duration(seconds: 30)) {
      return false;
    }
    _violationCooldowns[key] = now;
    return true;
  }

  void _rollBreakDay(DateTime now) {
    final key =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (_breakDayKey == key) return;
    _breakDayKey = key;
    _breaksUsed = 0;
    _pausedUntil = null;
  }

  void _scheduleNext() {
    _timer?.cancel();
    if (!_running) return;
    final seconds = (profileProvider()?.pollIntervalSeconds ?? 3).clamp(1, 60);
    _timer = Timer(Duration(seconds: seconds), () async {
      try {
        await poll();
      } catch (error) {
        _lastError = '$error';
        await _emitState();
      } finally {
        _scheduleNext();
      }
    });
  }

  Future<void> _emitState() => onStateChanged(state);

  String _fingerprint(Iterable<String> domains) =>
      (domains.map((value) => value.trim().toLowerCase()).toSet().toList()
            ..sort())
          .join('|');

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _running = false;
  }
}
