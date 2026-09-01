// 自律（SelfControl 式限制）领域逻辑，从 WorkbenchController 拆出。
// 依赖 WorkbenchControllerBase 契约访问宿主状态与方法。
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/models/attachment.dart';
import '../core/models/restriction_models.dart';
import '../core/models/workspace_record.dart';
import '../services/restriction_defaults.dart';
import '../services/restriction_monitor.dart';
import '../services/restriction_policy_engine.dart';
import '../services/restriction_security_service.dart';
import '../services/self_control_importer.dart';
import 'workbench_controller_base.dart';

mixin RestrictionControllerMixin on WorkbenchControllerBase {
  RestrictionMonitor? _restrictionMonitor;
  RestrictionMonitorState _restrictionMonitorState =
      const RestrictionMonitorState();
  RestrictionSecurityState _restrictionSecurityState =
      const RestrictionSecurityState();
  RestrictionHostsStatus _restrictionHostsStatus =
      const RestrictionHostsStatus();
  StreamSubscription<void>? _restrictionExitSubscription;
  StreamSubscription<String>? _restrictionPowerSubscription;
  Timer? _restrictionCooldownTimer;
  DateTime? _restrictionCooldownEndsAt;
  RestrictionProfile? _pendingRestrictionProfile;
  bool _restrictionExitRequested = false;
  bool _restrictionRecoveredAfterAbnormalExit = false;
  File? _lastSelfControlImportBackup;

  RestrictionMonitorState get restrictionMonitorState =>
      _restrictionMonitorState;
  RestrictionSecurityState get restrictionSecurityState =>
      _restrictionSecurityState;
  RestrictionHostsStatus get restrictionHostsStatus => _restrictionHostsStatus;
  DateTime? get restrictionCooldownEndsAt => _restrictionCooldownEndsAt;
  RestrictionProfile? get pendingRestrictionProfile =>
      _pendingRestrictionProfile;
  bool get restrictionExitRequested => _restrictionExitRequested;
  bool get restrictionRecoveredAfterAbnormalExit =>
      _restrictionRecoveredAfterAbnormalExit;
  File? get lastSelfControlImportBackup => _lastSelfControlImportBackup;

  /// 恢复/初始化自律运行时。仅在 Windows 上生效（`supported` 为 false
  /// 时立即返回），Android 端调用无副作用。
  Future<void> initializeRestrictionRuntime() async {
    _restrictionSecurityState = RestrictionSecurityState.decode(
      await database.readMetadata('restriction_security_v1'),
    );
    if (!windowsActivityService.supported) return;

    RestrictionProfile? recoveredSnapshot;
    DateTime? pausedUntil;
    var breakDayKey = '';
    var breaksUsed = 0;
    var previousCleanShutdown = true;
    final runtimeValue = await database.readMetadata('restriction_runtime_v1');
    if (runtimeValue != null) {
      try {
        final runtime = jsonDecode(runtimeValue) as Map<String, dynamic>;
        previousCleanShutdown = runtime['cleanShutdown'] == true;
        recoveredSnapshot = _restrictionProfileFromLocalJson(
          runtime['activeSnapshot'],
        );
        pausedUntil = DateTime.tryParse(
          runtime['pausedUntil']?.toString() ?? '',
        )?.toLocal();
        breakDayKey = runtime['breakDayKey']?.toString() ?? '';
        breaksUsed = (runtime['breaksUsed'] as num?)?.toInt() ?? 0;
      } catch (_) {
        recoveredSnapshot = null;
      }
    }

    final engine = const RestrictionPolicyEngine();
    if (recoveredSnapshot != null &&
        !previousCleanShutdown &&
        engine.isRestricted(recoveredSnapshot, currentTime())) {
      _restrictionRecoveredAfterAbnormalExit = true;
    } else {
      if (!previousCleanShutdown) {
        await windowsActivityService.clearHostsPolicy();
      }
      recoveredSnapshot = null;
      pausedUntil = null;
    }

    _restrictionMonitor?.dispose();
    _restrictionMonitor =
        RestrictionMonitor(
          activityService: windowsActivityService,
          profileProvider: () => restrictionProfile,
          onEvent: _recordRestrictionViolation,
          onStateChanged: (state) async {
            _restrictionMonitorState = state;
            await _persistRestrictionRuntime(cleanShutdown: false);
            notifyListeners();
          },
          now: currentTime,
        )..restore(
          activeSnapshot: recoveredSnapshot,
          pausedUntil: pausedUntil,
          breakDayKey: breakDayKey,
          breaksUsed: breaksUsed,
        );
    await _restrictionMonitor!.start();
    await refreshRestrictionHostsStatus();

    await _restrictionExitSubscription?.cancel();
    _restrictionExitSubscription = windowsActivityService.exitRequests.listen((
      _,
    ) {
      if (_restrictionMonitorState.activeSnapshot?.strongProtection == true) {
        _restrictionExitRequested = true;
        notifyListeners();
      } else {
        unawaited(shutdownRestrictionsAndExit());
      }
    });
    await _restrictionPowerSubscription?.cancel();
    _restrictionPowerSubscription = windowsActivityService.powerEvents.listen((
      event,
    ) {
      if (event == 'resume') unawaited(_restrictionMonitor?.poll());
    });
    await _restorePendingRestrictionAction();
  }

  /// 首次初始化时创建默认自律规则；已有用户配置只补齐缺失条目，不覆盖
  /// 个人设置。
  Future<void> ensureRestrictionDefaults() async {
    final existing = restrictionProfileRecords.firstOrNull;
    if (existing == null) {
      final profile = RestrictionDefaults.create(
        id: 'restriction-profile-${newRecordId()}',
      );
      await addRecord(profile.toRecord());
      return;
    }

    final current = RestrictionProfile.fromRecord(existing);
    final merged = RestrictionDefaults.mergeMissing(current);
    final currentJson = jsonEncode(current.toData());
    final mergedJson = jsonEncode(merged.toData());
    if (currentJson == mergedJson) return;

    // Keep a readable recovery copy before adding source defaults to an
    // existing user's custom profile.
    await backupService.writeJsonExport(allRecords);
    await updateRecord(merged.toRecord(existing: existing));
  }

  RestrictionProfile createRestrictionProfile() =>
      RestrictionDefaults.create(id: 'restriction-profile-${newRecordId()}');

  Future<DateTime?> saveRestrictionProfile(
    RestrictionProfile profile, {
    String credential = '',
  }) async {
    final active = _restrictionMonitorState.activeSnapshot;
    final needsCooldown =
        _restrictionMonitorState.active &&
        active?.strongProtection == true &&
        const RestrictionPolicyEngine().weakens(active!, profile);
    if (!needsCooldown) {
      await _applyRestrictionProfile(profile);
      return null;
    }

    var emergency = false;
    if (_restrictionSecurityState.hasPassword) {
      if (credential.isEmpty) {
        throw const FormatException('当前规则处于强保护，请输入保护密码。');
      }
      final result = await restrictionSecurityService.verifyCredential(
        _restrictionSecurityState,
        credential,
        currentTime(),
      );
      _restrictionSecurityState = result.state;
      await _persistRestrictionSecurity();
      if (!result.valid) throw const FormatException('保护密码或紧急恢复码无效。');
      emergency = result.emergency;
    }
    if (emergency) {
      await _applyRestrictionProfile(profile);
      return null;
    }
    return _scheduleRestrictionProfile(profile);
  }

  Future<void> _applyRestrictionProfile(RestrictionProfile profile) async {
    final existing = restrictionProfileRecords
        .where((record) => record.id == profile.id)
        .firstOrNull;
    await updateRecord(profile.toRecord(existing: existing));
    _pendingRestrictionProfile = null;
    _restrictionCooldownEndsAt = null;
    _restrictionCooldownTimer?.cancel();
    await database.writeMetadata('restriction_pending_v1', '');
    await _restrictionMonitor?.poll();
    await refreshRestrictionHostsStatus();
  }

  Future<DateTime> _scheduleRestrictionProfile(
    RestrictionProfile profile,
  ) async {
    _pendingRestrictionProfile = profile;
    _restrictionCooldownEndsAt = currentTime().add(
      RestrictionSecurityService.cooldown,
    );
    await database.writeMetadata(
      'restriction_pending_v1',
      jsonEncode({
        'type': 'profile',
        'executeAt': _restrictionCooldownEndsAt!.toUtc().toIso8601String(),
        'profile': _restrictionProfileToLocalJson(profile),
      }),
    );
    _armRestrictionCooldown();
    notifyListeners();
    return _restrictionCooldownEndsAt!;
  }

  Future<void> cancelPendingRestrictionAction() async {
    _restrictionCooldownTimer?.cancel();
    _restrictionCooldownTimer = null;
    _restrictionCooldownEndsAt = null;
    _pendingRestrictionProfile = null;
    await database.writeMetadata('restriction_pending_v1', '');
    notifyListeners();
  }

  Future<void> _restorePendingRestrictionAction() async {
    final value = await database.readMetadata('restriction_pending_v1');
    if (value == null || value.isEmpty) return;
    try {
      final pending = jsonDecode(value) as Map<String, dynamic>;
      _restrictionCooldownEndsAt = DateTime.tryParse(
        pending['executeAt']?.toString() ?? '',
      )?.toLocal();
      if (pending['type'] == 'exit') {
        if (_restrictionCooldownEndsAt == null) {
          await cancelPendingRestrictionAction();
        } else if (!currentTime().isBefore(_restrictionCooldownEndsAt!)) {
          await shutdownRestrictionsAndExit();
        } else {
          _armRestrictionExitCooldown();
          notifyListeners();
        }
        return;
      }
      _pendingRestrictionProfile = _restrictionProfileFromLocalJson(
        pending['profile'],
      );
      if (_restrictionCooldownEndsAt == null ||
          _pendingRestrictionProfile == null) {
        await cancelPendingRestrictionAction();
        return;
      }
      if (!currentTime().isBefore(_restrictionCooldownEndsAt!)) {
        await _applyRestrictionProfile(_pendingRestrictionProfile!);
      } else {
        _armRestrictionCooldown();
      }
    } catch (_) {
      await cancelPendingRestrictionAction();
    }
  }

  void _armRestrictionCooldown() {
    _restrictionCooldownTimer?.cancel();
    final executeAt = _restrictionCooldownEndsAt;
    final profile = _pendingRestrictionProfile;
    if (executeAt == null || profile == null) return;
    final delay = executeAt.difference(currentTime());
    _restrictionCooldownTimer = Timer(
      delay.isNegative ? Duration.zero : delay,
      () => unawaited(_applyRestrictionProfile(profile)),
    );
  }

  void _armRestrictionExitCooldown() {
    _restrictionCooldownTimer?.cancel();
    final executeAt = _restrictionCooldownEndsAt;
    if (executeAt == null) return;
    final delay = executeAt.difference(currentTime());
    _restrictionCooldownTimer = Timer(
      delay.isNegative ? Duration.zero : delay,
      () => unawaited(shutdownRestrictionsAndExit()),
    );
  }

  Future<void> setRestrictionPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_restrictionSecurityState.hasPassword &&
        !await restrictionSecurityService.verifyPassword(
          _restrictionSecurityState,
          currentPassword,
        )) {
      throw const FormatException('当前保护密码错误。');
    }
    _restrictionSecurityState = await restrictionSecurityService.setPassword(
      _restrictionSecurityState,
      newPassword,
    );
    await _persistRestrictionSecurity();
    notifyListeners();
  }

  Future<void> clearRestrictionPassword(String currentPassword) async {
    if (_restrictionSecurityState.hasPassword &&
        !await restrictionSecurityService.verifyPassword(
          _restrictionSecurityState,
          currentPassword,
        )) {
      throw const FormatException('当前保护密码错误。');
    }
    _restrictionSecurityState = const RestrictionSecurityState();
    await _persistRestrictionSecurity();
    notifyListeners();
  }

  Future<String> generateRestrictionEmergencyCode() async {
    final result = await restrictionSecurityService.generateEmergencyCode(
      _restrictionSecurityState,
      currentTime(),
    );
    _restrictionSecurityState = result.state;
    await _persistRestrictionSecurity();
    notifyListeners();
    return result.code;
  }

  Future<DateTime?> requestRestrictionExit(String credential) async {
    final active = _restrictionMonitorState.activeSnapshot;
    if (!_restrictionMonitorState.active || active?.strongProtection != true) {
      await shutdownRestrictionsAndExit();
      return null;
    }
    var emergency = false;
    if (_restrictionSecurityState.hasPassword) {
      final result = await restrictionSecurityService.verifyCredential(
        _restrictionSecurityState,
        credential,
        currentTime(),
      );
      _restrictionSecurityState = result.state;
      await _persistRestrictionSecurity();
      if (!result.valid) throw const FormatException('保护密码或紧急恢复码无效。');
      emergency = result.emergency;
    }
    if (emergency) {
      await shutdownRestrictionsAndExit();
      return null;
    }
    final executeAt = currentTime().add(RestrictionSecurityService.cooldown);
    _restrictionCooldownEndsAt = executeAt;
    await database.writeMetadata(
      'restriction_pending_v1',
      jsonEncode({
        'type': 'exit',
        'executeAt': executeAt.toUtc().toIso8601String(),
      }),
    );
    _armRestrictionExitCooldown();
    notifyListeners();
    return executeAt;
  }

  Future<void> shutdownRestrictionsAndExit() async {
    await _restrictionMonitor?.stop(cleanup: true);
    await _persistRestrictionRuntime(cleanShutdown: true);
    await database.writeMetadata('restriction_pending_v1', '');
    await windowsActivityService.exitApplication();
  }

  Future<void> takeRestrictionBreak() async {
    await _restrictionMonitor?.takeBreak();
  }

  Future<void> resumeRestrictionNow() async {
    await _restrictionMonitor?.resumeNow();
  }

  Future<RestrictionHostsStatus> refreshRestrictionHostsStatus() async {
    final status = await windowsActivityService.hostsStatus(
      restrictionProfile?.blockedWebsites ?? const [],
    );
    _restrictionHostsStatus = status;
    notifyListeners();
    return status;
  }

  Future<bool> repairRestrictionHosts() async {
    final profile =
        _restrictionMonitorState.activeSnapshot ?? restrictionProfile;
    if (profile == null || !profile.websiteBlocking) return false;
    final result = await windowsActivityService.applyHostsPolicy(
      profile.blockedWebsites,
    );
    await refreshRestrictionHostsStatus();
    return result;
  }

  Future<bool> clearRestrictionHosts() async {
    final result = await windowsActivityService.clearHostsPolicy();
    await refreshRestrictionHostsStatus();
    return result;
  }

  Future<SelfControlImportPreview> previewSelfControlImport(
    String directoryPath,
  ) => selfControlImporter.preview(Directory(directoryPath));

  Future<File> importSelfControl(
    SelfControlImportPreview preview, {
    required bool enableProfile,
  }) async {
    final backup = await backupService.writeJsonExport(allRecords);
    final records = preview.records.toList(growable: true);
    final profileIndex = records.indexWhere(
      (record) => record.data['recordType'] == 'restrictionProfile',
    );
    if (profileIndex >= 0) {
      final profile = preview.profile.copyWith(enabled: enableProfile);
      records[profileIndex] = profile.toRecord(existing: records[profileIndex]);
    }

    final archiveRecord = records
        .where((record) => record.data['recordType'] == 'restrictionLogArchive')
        .firstOrNull;
    final existingArchiveAttachments = archiveRecord == null
        ? const <Attachment>[]
        : await attachmentService.forRecord(archiveRecord.id);
    Attachment? importedArchive;
    if (archiveRecord != null &&
        preview.blockLog != null &&
        existingArchiveAttachments.isEmpty) {
      importedArchive = await attachmentService.importText(
        owner: archiveRecord,
        source: preview.blockLog!,
      );
    }
    try {
      await database.applyDomainMigration(
        records,
        jsonEncode({
          'sourceImportId': SelfControlImporter.sourceImportId,
          'importedAt': currentTime().toUtc().toIso8601String(),
          'recordCount': records.length,
          'backupPath': backup.path,
        }),
        metadataKey: 'self_control_import_v1',
      );
    } catch (_) {
      if (importedArchive != null) {
        await attachmentService.delete(importedArchive);
      }
      rethrow;
    }
    await reloadRecordsFromDatabase();
    _lastSelfControlImportBackup = backup;
    await _restrictionMonitor?.poll();
    await refreshRestrictionHostsStatus();
    notifyListeners();
    return backup;
  }

  Future<void> _recordRestrictionViolation(
    RestrictionViolation violation,
    bool actionSucceeded,
  ) async {
    final now = currentTime();
    await addRecord(
      WorkspaceRecord.create(
        kind: RecordKind.protocolEvent,
        title: violation.process.name,
        status: actionSucceeded ? WorkStatus.done : WorkStatus.failed,
        scheduledFor: now,
        data: {
          'recordType': 'restrictionEvent',
          'process': violation.process.name,
          'pid': violation.process.pid,
          'executablePath': violation.process.executablePath,
          'action': violation.action.name,
          'reasonCode': violation.reasonCode,
          'reason': violation.reason,
          'matched': violation.matched,
          'detectedAt': now.toUtc().toIso8601String(),
          'executionResult': actionSucceeded ? 'succeeded' : 'failed',
          if (!actionSucceeded) 'error': 'Windows 原生动作执行失败',
        },
      ),
    );
  }

  Future<void> _persistRestrictionSecurity() => database.writeMetadata(
    'restriction_security_v1',
    _restrictionSecurityState.encode(),
  );

  Future<void> _persistRestrictionRuntime({required bool cleanShutdown}) {
    final state = _restrictionMonitor?.state ?? _restrictionMonitorState;
    return database.writeMetadata(
      'restriction_runtime_v1',
      jsonEncode({
        'version': 1,
        'cleanShutdown': cleanShutdown,
        'activeSnapshot': state.activeSnapshot == null
            ? null
            : _restrictionProfileToLocalJson(state.activeSnapshot!),
        'pausedUntil': state.pausedUntil?.toUtc().toIso8601String(),
        'breakDayKey': state.breakDayKey,
        'breaksUsed': state.breaksUsed,
        'updatedAt': currentTime().toUtc().toIso8601String(),
      }),
    );
  }

  Map<String, dynamic> _restrictionProfileToLocalJson(
    RestrictionProfile profile,
  ) => {'id': profile.id, 'title': profile.title, 'data': profile.toData()};

  RestrictionProfile? _restrictionProfileFromLocalJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    final now = currentTime();
    return RestrictionProfile.fromRecord(
      WorkspaceRecord(
        id: json['id']?.toString() ?? 'restriction-runtime-snapshot',
        kind: RecordKind.template,
        title: json['title']?.toString() ?? '自律规则快照',
        createdAt: now,
        updatedAt: now,
        data: Map<String, dynamic>.from(json['data'] as Map? ?? const {}),
      ),
    );
  }

  /// 释放自律运行时资源。宿主控制器拥有自己的 [dispose]，因此不能
  /// 依赖 mixin 的同名覆盖；由宿主显式调用该清理钩子。
  void disposeRestrictionController() {
    _restrictionCooldownTimer?.cancel();
    _restrictionMonitor?.dispose();
    unawaited(_restrictionExitSubscription?.cancel());
    unawaited(_restrictionPowerSubscription?.cancel());
  }
}
