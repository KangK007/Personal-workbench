import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';

import '../core/models/game_state.dart';
import '../core/models/workspace_record.dart';
import '../core/models/workspace_models_v3.dart';
import '../data/app_database.dart';
import '../data/backup_service.dart';
import '../data/workspace_migration.dart';
import '../services/focus_service.dart';
import '../services/attachment_service.dart';
import '../services/game_service.dart';
import '../services/growth_service.dart';
import '../services/notification_service.dart';
import '../services/search_service.dart';
import '../services/share_capture_service.dart';
import '../services/supabase_sync_service.dart';
import '../services/windows_activity_service.dart';

enum SyncPhase { localOnly, signedOut, idle, syncing, success, error }

enum BatchTaskAction {
  setStatus,
  setDate,
  setProject,
  setTaskGroup,
  moveToTrash,
}

class BatchOperationFailure {
  const BatchOperationFailure({required this.recordId, required this.message});

  final String recordId;
  final String message;
}

class BatchOperationResult {
  const BatchOperationResult({
    required this.succeeded,
    this.failures = const [],
  });

  final int succeeded;
  final List<BatchOperationFailure> failures;

  int get failed => failures.length;
  bool get isSuccessful => failures.isEmpty;
}

class WorkbenchController extends ChangeNotifier {
  static const _maxImportBytes = 10 * 1024 * 1024;

  WorkbenchController({
    required this.database,
    required this.backupService,
    required this.searchService,
    required this.focusService,
    required this.notificationService,
    required this.shareCaptureService,
    required this.syncService,
    this.growthService = const GrowthService(),
    this.gameService = const GameService(),
    AttachmentService? attachmentService,
    WindowsActivityService? windowsActivityService,
    DateTime Function()? now,
  }) : attachmentService =
           attachmentService ?? AttachmentService(database: database),
       windowsActivityService =
           windowsActivityService ?? WindowsActivityService(),
       _clock = now ?? DateTime.now;

  final AppDatabase database;
  final BackupService backupService;
  final SearchService searchService;
  final FocusService focusService;
  final NotificationService notificationService;
  final ShareCaptureService shareCaptureService;
  final SupabaseSyncService syncService;
  GrowthService growthService;
  final GameService gameService;
  final AttachmentService attachmentService;
  final WindowsActivityService windowsActivityService;
  final DateTime Function() _clock;

  DateTime currentTime() => _clock();

  final List<WorkspaceRecord> _records = [];
  Map<String, WorkspaceRecord>? _projectIndex;
  bool _loading = true;
  String? _error;
  ThemeMode _themeMode = ThemeMode.system;
  SyncPhase _syncPhase = SyncPhase.localOnly;
  String _syncMessage = '本地数据已就绪';
  bool _navigationCollapsed = false;
  bool _rsipAllowMultiplePerDay = false;
  bool _rsipStrictMode = true;
  int _logicalDayBoundaryHour = 4;
  bool _closeToTray = true;
  bool _startupEnabled = false;
  bool _foregroundDetectionEnabled = false;
  bool _bringToFrontOnFocusSchedule = true;
  final Map<ReviewPeriodType, bool> _reviewReminderEnabled = {
    for (final type in ReviewPeriodType.values)
      type: type != ReviewPeriodType.yearly,
  };
  final Map<ReviewPeriodType, String> _reviewReminderTimes = {
    ReviewPeriodType.daily: '21:30',
    ReviewPeriodType.weekly: '20:00',
    ReviewPeriodType.monthly: '20:00',
    ReviewPeriodType.yearly: '20:00',
  };
  // Controllers created directly by unit tests are not initialized. Keep the
  // legacy-visible default there; initialize() applies the persisted product
  // preference for real app sessions.
  bool _advancedFeaturesEnabled = true;
  bool _gameFeaturesEnabled = false;
  bool _gameFeaturesPromptPending = false;
  LocalGameState _localGameState = const LocalGameState();
  bool _settlingProtocols = false;
  Timer? _protocolSettlementTimer;
  final Map<String, Timer> _focusScheduleTimers = {};
  final Map<String, Timer> _focusMissTimers = {};
  final Set<String> _settlingRsipNodeIds = {};

  bool get loading => _loading;
  String? get error => _error;
  ThemeMode get themeMode => _themeMode;
  SyncPhase get syncPhase => _syncPhase;
  String get syncMessage => _syncMessage;
  String? get signedInEmail => syncService.currentUser?.email;
  bool get cloudConfigured => syncService.configured;
  bool get navigationCollapsed => _navigationCollapsed;
  bool get rsipAllowMultiplePerDay => _rsipAllowMultiplePerDay;
  bool get rsipStrictMode => _rsipStrictMode;
  int get logicalDayBoundaryHour => _logicalDayBoundaryHour;
  bool get closeToTray => _closeToTray;
  bool get startupEnabled => _startupEnabled;
  bool get foregroundDetectionEnabled => _foregroundDetectionEnabled;
  bool get bringToFrontOnFocusSchedule => _bringToFrontOnFocusSchedule;
  bool reviewReminderEnabled(ReviewPeriodType type) =>
      _reviewReminderEnabled[type] ?? true;
  String reviewReminderTime(ReviewPeriodType type) =>
      _reviewReminderTimes[type] ?? '20:00';
  bool get advancedFeaturesEnabled => _advancedFeaturesEnabled;
  bool get gameFeaturesEnabled => _gameFeaturesEnabled;
  bool get gameFeaturesPromptPending => _gameFeaturesPromptPending;

  GameProfile get gameProfile => _localGameState.profile;
  List<PointTransaction> get pointTransactions =>
      List.unmodifiable(_localGameState.transactions.reversed);
  List<BetSession> get betSessions =>
      List.unmodifiable(_localGameState.bets.reversed);
  BetSession? pendingLocalBet(String sessionId) => _localGameState.bets
      .where(
        (bet) =>
            bet.focusSessionId == sessionId && bet.status == BetStatus.pending,
      )
      .firstOrNull;
  int get todayBetUsed {
    final today = growthService.dayKey(currentTime());
    return _localGameState.bets
        .where(
          (bet) =>
              bet.status != BetStatus.refunded &&
              (bet.dayKey.isEmpty
                      ? growthService.dayKey(bet.placedAt)
                      : bet.dayKey) ==
                  today,
        )
        .fold(0, (sum, bet) => sum + bet.amount);
  }

  List<WorkspaceRecord> get allRecords => List.unmodifiable(_records);
  List<WorkspaceRecord> get activeRecords =>
      _records.where((record) => !record.isDeleted).toList(growable: false);
  List<WorkspaceRecord> get trashRecords => _records
      .where((record) => record.isDeleted && !_isHiddenTrashRecord(record))
      .toList(growable: false);

  bool _isHiddenTrashRecord(WorkspaceRecord record) =>
      record.kind == RecordKind.relation &&
      record.data['deletedWithTaskGroupId'] != null;

  List<WorkspaceRecord> recordsOf(RecordKind kind) => activeRecords
      .where((record) => record.kind == kind)
      .toList(growable: false);

  List<WorkspaceRecord> get taskDefinitions => recordsOf(RecordKind.task)
      .where((record) => record.data['recordType'] == 'taskDefinition')
      .toList(growable: false);
  List<WorkspaceRecord> get tasks => recordsOf(RecordKind.task)
      .where((record) => record.data['recordType'] != 'taskDefinition')
      .toList(growable: false);
  List<WorkspaceRecord> get projects => recordsOf(RecordKind.project);
  WorkspaceRecord? projectById(String? id) {
    if (id == null) return null;
    _projectIndex ??= {for (final project in projects) project.id: project};
    return _projectIndex![id];
  }

  WorkspaceRecord? projectByIdIncludingTrash(String? id) {
    if (id == null) return null;
    return _records
        .where((record) => record.kind == RecordKind.project && record.id == id)
        .firstOrNull;
  }

  List<WorkspaceRecord> get notes => recordsOf(RecordKind.note);
  List<WorkspaceRecord> get periodReviews => notes
      .where((record) => record.data['recordType'] == 'periodReview')
      .toList(growable: false);
  List<WorkspaceRecord> get legacyYearlyReviews => periodReviews
      .where((record) => record.data['periodType'] == 'yearly')
      .toList(growable: false);
  List<WorkspaceRecord> get diaries => recordsOf(RecordKind.diary);
  List<WorkspaceRecord> get goals => recordsOf(RecordKind.goal);
  List<WorkspaceRecord> get habits => recordsOf(RecordKind.habit);
  List<WorkspaceRecord> get ctdpTasks =>
      tasks.where((task) => task.hasCtdpProtocol).toList(growable: false);
  List<WorkspaceRecord> get exceptionRules =>
      recordsOf(RecordKind.exceptionRule);
  List<WorkspaceRecord> get protocolEvents {
    final result = recordsOf(RecordKind.protocolEvent);
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  List<WorkspaceRecord> get activeRsipHabits => habits
      .where((habit) => habit.hasRsipProtocol && habit.rsipActive)
      .toList(growable: false);
  List<RsipNode> get rsipNodes => habits
      .where((record) => record.hasRsipProtocol)
      .map(RsipNode.fromRecord)
      .toList(growable: false);
  List<RsipNodeGroup> get rsipNodeGroups => recordsOf(RecordKind.template)
      .where((record) => record.data['recordType'] == 'rsipNodeGroup')
      .map(RsipNodeGroup.fromRecord)
      .toList(growable: false);
  List<RsipExecutionRecord> get rsipExecutionRecords => protocolEvents
      .where((record) => record.data['recordType'] == 'rsipExecution')
      .map(RsipExecutionRecord.fromRecord)
      .toList(growable: false);
  List<RsipRunRecord> get rsipRunRecords => protocolEvents
      .where((record) => record.data['recordType'] == 'rsipRun')
      .map(RsipRunRecord.fromRecord)
      .toList(growable: false);
  List<RsipTaskLink> get rsipTaskLinks => relations
      .where((record) => record.data['recordType'] == 'rsipTaskLink')
      .map(RsipTaskLink.fromRecord)
      .toList(growable: false);
  List<RsipNode> get rsipLibraryNodes => rsipNodes
      .where((node) => !node.record.rsipActive)
      .toList(growable: false);
  int get activeRsipMaintenanceCount =>
      rsipNodes.where((node) => node.record.rsipActive && !node.passive).length;
  List<WorkspaceRecord> get timeBlocks => recordsOf(RecordKind.timeBlock);
  List<WorkspaceRecord> get focusPresets => recordsOf(RecordKind.template)
      .where((record) => record.data['recordType'] == 'focusPreset')
      .toList(growable: false);
  List<WorkspaceRecord> get pendingFocusPresets => focusPresets
      .where((preset) => preset.data['pendingScheduledStartAt'] != null)
      .toList(growable: false);
  List<WorkspaceRecord> get taskGroups => recordsOf(RecordKind.template)
      .where((record) => record.data['recordType'] == 'taskGroup')
      .toList(growable: false);
  List<WorkspaceRecord> get relations => recordsOf(RecordKind.relation);
  List<WorkspaceRecord> get foregroundEvents =>
      recordsOf(RecordKind.protocolEvent)
          .where((record) => record.data['recordType'] == 'foregroundEvent')
          .toList(growable: false);
  List<WorkspaceRecord> get growthEvents => recordsOf(RecordKind.growthEvent);
  WorkspaceRecord? get todayPlan =>
      growthService.planForDay(activeRecords, currentTime());
  GrowthSnapshot get growthSnapshot =>
      growthService.snapshot(activeRecords, currentTime());
  bool get todayStarted => todayPlan != null;
  bool get todayClosed => todayPlan?.data['closedAt'] != null;
  String get profileAlias {
    final profiles = recordsOf(RecordKind.profile);
    return profiles.isEmpty
        ? ''
        : profiles.first.data['alias']?.toString() ?? '';
  }

  List<String> get commitmentIds {
    final values =
        todayPlan?.data['commitmentIds'] as List<dynamic>? ?? const [];
    return values.map((value) => value.toString()).toList(growable: false);
  }

  List<String> get replacementCommitmentIds {
    final replacements =
        todayPlan?.data['replacements'] as List<dynamic>? ?? const [];
    return replacements
        .map(
          (value) => Map<String, dynamic>.from(
            value as Map,
          )['replacementId']?.toString(),
        )
        .whereType<String>()
        .toList(growable: false);
  }

  List<String> get activeCommitmentIds {
    final originals = commitmentIds;
    final replacements =
        todayPlan?.data['replacements'] as List<dynamic>? ?? const [];
    return List<String>.generate(originals.length, (slot) {
      final candidates = replacements
          .map((value) => Map<String, dynamic>.from(value as Map))
          .where((value) => (value['slot'] as num?)?.toInt() == slot)
          .toList();
      return candidates.isEmpty
          ? originals[slot]
          : candidates.last['replacementId']?.toString() ?? originals[slot];
    });
  }

  List<WorkspaceRecord> get commitmentTasks {
    return activeCommitmentIds
        .map((id) => tasks.where((task) => task.id == id).firstOrNull)
        .whereType<WorkspaceRecord>()
        .toList(growable: false);
  }

  List<String> get plannedHabitIds {
    final values =
        todayPlan?.data['plannedHabitIds'] as List<dynamic>? ?? const [];
    return values.map((value) => value.toString()).toList(growable: false);
  }

  List<WorkspaceRecord> tasksForDay(DateTime day) {
    final targetKey = growthService.dayKey(day);
    final result = tasks.where((task) {
      final belonging = task.scheduledFor ?? task.createdAt;
      return growthService.dayKey(belonging) == targetKey;
    }).toList();
    result.sort(_taskOrder);
    return result;
  }

  List<WorkspaceRecord> get todayTasks => tasksForDay(currentTime());

  List<WorkspaceRecord> get overdueTasks {
    final now = currentTime();
    final today = growthService.logicalDay(now);
    final result = tasks.where((task) {
      if (WorkStatus.terminal.contains(task.status)) return false;
      final deadline = task.dueAt;
      if (deadline != null) return deadline.isBefore(now);
      final scheduled = task.scheduledFor;
      return scheduled != null && startOfDay(scheduled).isBefore(today);
    }).toList();
    result.sort(_taskOrder);
    return result;
  }

  List<WorkspaceRecord> get settledTodayTasks {
    final today = growthService.logicalDay(currentTime());
    final result = tasks.where((task) {
      if (!WorkStatus.terminal.contains(task.status)) return false;
      final settledAt = DateTime.tryParse(
        task.data['settledAt']?.toString() ??
            task.data['completedAt']?.toString() ??
            '',
      )?.toLocal();
      return isSameDay(settledAt ?? task.scheduledFor, today);
    }).toList();
    result.sort(_taskOrder);
    return result;
  }

  /// Returns the first three unfinished tasks for today's one-step start flow.
  /// Priority is the primary signal; scheduled/due time and creation time make
  /// ties deterministic without changing the existing task list ordering.
  List<WorkspaceRecord> get suggestedTodayTasks {
    final result = todayTasks.where((task) => !task.isDone).toList();
    result.sort((a, b) {
      if (a.priority != b.priority) {
        return b.priority.compareTo(a.priority);
      }
      final aTime = a.dueAt ?? a.scheduledFor ?? a.createdAt;
      final bTime = b.dueAt ?? b.scheduledFor ?? b.createdAt;
      final byTime = aTime.compareTo(bTime);
      return byTime != 0 ? byTime : a.createdAt.compareTo(b.createdAt);
    });
    return result.take(3).toList(growable: false);
  }

  bool get canUpdateTodayCommitments {
    final plan = todayPlan;
    if (plan == null || todayClosed) return false;
    if (commitmentTasks.any((task) => task.isDone)) return false;
    final startedAt = DateTime.tryParse(
      plan.data['startedAt']?.toString() ?? '',
    );
    if (startedAt == null) return true;
    return !recordsOf(RecordKind.focusSession).any((session) {
      final timestamp = session.scheduledFor ?? session.createdAt;
      return timestamp.isAfter(startedAt);
    });
  }

  List<WorkspaceRecord> get focusTasks {
    final result = todayTasks.where((task) => task.isFocus).toList();
    result.sort(_taskOrder);
    return result;
  }

  List<WorkspaceRecord> get inboxRecords {
    final result = activeRecords.where((record) {
      if (record.kind == RecordKind.task) {
        return record.data['recordType'] != 'taskDefinition' &&
            (record.status == WorkStatus.inbox ||
                (record.scheduledFor == null && record.projectId == null));
      }
      return (record.kind == RecordKind.note ||
              record.kind == RecordKind.link) &&
          record.data['inbox'] == true;
    }).toList();
    result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return result;
  }

  List<WorkspaceRecord> projectTasks(String projectId) {
    final relatedTaskIds = relations
        .where(
          (record) =>
              record.data['relationType'] == 'taskProject' &&
              record.data['projectId'] == projectId,
        )
        .map((record) => record.data['taskId']?.toString())
        .whereType<String>()
        .toSet();
    final result = tasks
        .where(
          (task) =>
              task.projectId == projectId || relatedTaskIds.contains(task.id),
        )
        .toList();
    result.sort(_taskOrder);
    return result;
  }

  List<WorkspaceRecord> milestonesForGoal(String goalId) {
    final result = recordsOf(
      RecordKind.milestone,
    ).where((item) => item.parentId == goalId).toList();
    result.sort(
      (a, b) => (a.dueAt ?? a.createdAt).compareTo(b.dueAt ?? b.createdAt),
    );
    return result;
  }

  List<WorkspaceRecord> timeBlocksForDay(DateTime day) {
    final result = timeBlocks
        .where((block) => isSameDay(block.scheduledFor, day))
        .toList();
    result.sort(
      (a, b) => (a.scheduledFor ?? a.createdAt).compareTo(
        b.scheduledFor ?? b.createdAt,
      ),
    );
    return result;
  }

  WorkspaceRecord? diaryForDay(DateTime day) {
    for (final diary in diaries) {
      if (isSameDay(diary.scheduledFor, day)) return diary;
    }
    return null;
  }

  WorkspaceRecord? habitLogForDay(String habitId, DateTime day) {
    for (final log in recordsOf(RecordKind.habitLog)) {
      if (log.parentId == habitId && isSameDay(log.scheduledFor, day)) {
        return log;
      }
    }
    return null;
  }

  Future<void> initialize() async {
    _loading = true;
    _error = null;
    _protocolSettlementTimer?.cancel();
    _protocolSettlementTimer = null;
    notifyListeners();
    (String, String)? migrationBackupPaths;
    var migrationPhaseComplete = false;
    try {
      final migrationBackup = await database.pendingMigrationBackupPaths();
      migrationBackupPaths =
          migrationBackup ?? await database.migrationBackupPaths();
      if (migrationBackup != null && windowsActivityService.supported) {
        final protected = await windowsActivityService.protectFile(
          sourcePath: migrationBackup.$1,
          destinationPath: migrationBackup.$2,
        );
        if (protected == false) {
          throw StateError('无法创建 Windows DPAPI 迁移备份，数据库未升级。');
        }
      }
      await database.database;
      final domainMigrationComplete =
          await database.readMetadata('domain_migration_v3') != null;
      if (domainMigrationComplete) migrationPhaseComplete = true;
      _records
        ..clear()
        ..addAll(await database.loadRecords());
      final hadExistingRecords = _records.isNotEmpty;
      final migration = await const WorkspaceMigration().migrateToVersionTwo(
        database: database,
        records: _records,
      );
      if (migration != null &&
          (migration.created > 0 || migration.updated > 0)) {
        _records
          ..clear()
          ..addAll(await database.loadRecords());
      }
      final migrationV3 = await const WorkspaceMigration()
          .migrateToVersionThree(database: database, records: _records);
      if (migrationV3 != null &&
          (migrationV3.created > 0 || migrationV3.updated > 0)) {
        _records
          ..clear()
          ..addAll(await database.loadRecords());
      }
      migrationPhaseComplete = true;
      _projectIndex = null;
      final theme = await database.readMetadata('theme_mode');
      _themeMode = ThemeMode.values.firstWhere(
        (value) => value.name == theme,
        orElse: () => ThemeMode.system,
      );
      _navigationCollapsed =
          await database.readMetadata('navigation_collapsed') == 'true';
      _rsipAllowMultiplePerDay =
          await database.readMetadata('rsip_allow_multiple_per_day') == 'true';
      final persistedRsipStrictMode = await database.readMetadata(
        'rsip_strict_mode',
      );
      _rsipStrictMode = persistedRsipStrictMode == null
          ? !_rsipAllowMultiplePerDay
          : persistedRsipStrictMode != 'false';
      _rsipAllowMultiplePerDay = !_rsipStrictMode;
      _logicalDayBoundaryHour =
          int.tryParse(
            await database.readMetadata('logical_day_boundary_hour') ?? '',
          )?.clamp(0, 6) ??
          4;
      growthService = GrowthService(
        logicalDayBoundaryHour: _logicalDayBoundaryHour,
      );
      _closeToTray =
          await database.readMetadata('windows_close_to_tray') != 'false';
      _foregroundDetectionEnabled =
          await database.readMetadata('foreground_detection_enabled') == 'true';
      _bringToFrontOnFocusSchedule =
          await database.readMetadata('focus_schedule_bring_to_front') !=
          'false';
      await purgeForegroundEvents();
      if (windowsActivityService.supported) {
        await windowsActivityService.setCloseToTray(_closeToTray);
        _startupEnabled = await windowsActivityService.startupEnabled();
      }
      for (final type in activeReviewPeriodTypes) {
        _reviewReminderEnabled[type] =
            await database.readMetadata(
              'review_reminder_${type.name}_enabled',
            ) !=
            'false';
        _reviewReminderTimes[type] =
            await database.readMetadata('review_reminder_${type.name}_time') ??
            _reviewReminderTimes[type]!;
      }
      await ensureTaskInstancesThrough(
        growthService.logicalDay(currentTime()).add(const Duration(days: 90)),
      );
      final advanced = await database.readMetadata('advanced_features_enabled');
      final freshInstall =
          !hadExistingRecords && _records.isEmpty && advanced == null;
      if (advanced == null) {
        _advancedFeaturesEnabled =
            ctdpTasks.isNotEmpty ||
            habits.any((habit) => habit.hasRsipProtocol) ||
            protocolEvents.isNotEmpty ||
            growthEvents.isNotEmpty;
        await database.writeMetadata(
          'advanced_features_enabled',
          '$_advancedFeaturesEnabled',
        );
      } else {
        _advancedFeaturesEnabled = advanced == 'true';
      }
      _localGameState = LocalGameState.fromJson(
        await database.readLocalGameState(),
      );
      final gameEnabled = await database.readMetadata('game_features_enabled');
      _gameFeaturesEnabled = gameEnabled == null
          ? freshInstall
          : gameEnabled == 'true';
      if (gameEnabled == null) {
        await database.writeMetadata(
          'game_features_enabled',
          '$_gameFeaturesEnabled',
        );
      }
      final gamePromptSeen = await database.readMetadata(
        'game_features_prompt_seen',
      );
      _gameFeaturesPromptPending =
          !freshInstall && !_gameFeaturesEnabled && gamePromptSeen != 'true';
      if (freshInstall && gamePromptSeen == null) {
        await database.writeMetadata('game_features_prompt_seen', 'true');
      }

      await settleProtocols();
      _protocolSettlementTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => settleProtocols(),
      );

      await notificationService.initialize();
      await scheduleReviewReminders();
      await _scheduleAllFocusPresets();
      await shareCaptureService.initialize((capture) async {
        await addRecord(
          WorkspaceRecord.create(
            kind: capture.isUrl ? RecordKind.link : RecordKind.note,
            title: capture.isUrl ? _linkTitle(capture.text) : '来自 Android 的收集',
            body: capture.isUrl ? '' : capture.text,
            status: WorkStatus.inbox,
            data: {
              'inbox': true,
              if (capture.isUrl) 'url': capture.text,
              'source': 'android-share',
            },
          ),
        );
      });
      _syncPhase = !cloudConfigured
          ? SyncPhase.localOnly
          : syncService.currentUser == null
          ? SyncPhase.signedOut
          : SyncPhase.idle;
    } catch (exception) {
      var restored = false;
      final paths = migrationBackupPaths;
      if (!migrationPhaseComplete &&
          paths != null &&
          windowsActivityService.supported &&
          await File(paths.$2).exists()) {
        await database.close();
        restored =
            await windowsActivityService.unprotectFile(
              sourcePath: paths.$2,
              destinationPath: paths.$1,
            ) ==
            true;
      }
      _error = restored
          ? '数据库迁移失败，已从加密备份恢复。请重新启动应用。原始错误：$exception'
          : '初始化失败：$exception';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> setThemeMode(ThemeMode value) async {
    _themeMode = value;
    await database.writeMetadata('theme_mode', value.name);
    notifyListeners();
  }

  Future<void> setNavigationCollapsed(bool value) async {
    _navigationCollapsed = value;
    await database.writeMetadata('navigation_collapsed', '$value');
    notifyListeners();
  }

  Future<void> setRsipAllowMultiplePerDay(bool value) async {
    await setRsipStrictMode(!value);
  }

  Future<void> setAdvancedFeaturesEnabled(bool value) async {
    _advancedFeaturesEnabled = value;
    await database.writeMetadata('advanced_features_enabled', '$value');
    notifyListeners();
  }

  Future<void> setGameFeaturesEnabled(bool value) async {
    _gameFeaturesEnabled = value;
    await database.writeMetadata('game_features_enabled', '$value');
    notifyListeners();
  }

  Future<void> answerGameFeaturesPrompt({required bool enable}) async {
    _gameFeaturesPromptPending = false;
    _gameFeaturesEnabled = enable;
    await database.writeMetadata('game_features_prompt_seen', 'true');
    await database.writeMetadata('game_features_enabled', '$enable');
    notifyListeners();
  }

  Future<bool> performDailyCheckin() async {
    final result = gameService.checkin(
      _localGameState,
      growthService.dayKey(currentTime()),
      currentTime(),
    );
    if (!result.completed) return false;
    _localGameState = result.state;
    await _persistGameState();
    return true;
  }

  Future<void> setBettingEnabled(bool value) async {
    _localGameState = _localGameState.copyWith(
      profile: _localGameState.profile.copyWith(gamblingEnabled: value),
    );
    await _persistGameState();
  }

  Future<void> setBetLimits({int? maxSingleBet, int? dailyBetLimit}) async {
    if (maxSingleBet != null && maxSingleBet <= 0) {
      throw const FormatException('单次上限必须是正整数。');
    }
    if (dailyBetLimit != null && dailyBetLimit <= 0) {
      throw const FormatException('每日上限必须是正整数。');
    }
    _localGameState = _localGameState.copyWith(
      profile: _localGameState.profile.copyWith(
        maxSingleBet: maxSingleBet,
        dailyBetLimit: dailyBetLimit,
      ),
    );
    await _persistGameState();
  }

  Future<BetPlacementResult> placeLocalBet({
    required String sessionId,
    required String taskId,
    required int amount,
  }) async {
    final result = gameService.placeBet(
      _localGameState,
      focusSessionId: sessionId,
      taskId: taskId,
      amount: amount,
      now: currentTime(),
      dayKey: growthService.dayKey(currentTime()),
    );
    _localGameState = result.state;
    await _persistGameState();
    return result;
  }

  Future<void> settleLocalBet({
    required String sessionId,
    required bool successful,
  }) async {
    _localGameState = gameService.settleBet(
      _localGameState,
      sessionId,
      successful,
      currentTime(),
    );
    await _persistGameState();
  }

  Future<void> cancelLocalBet(String sessionId) async {
    _localGameState = gameService.refundBet(
      _localGameState,
      sessionId,
      currentTime(),
    );
    await _persistGameState();
  }

  Future<void> setProfileAlias(String value) async {
    final alias = value.trim();
    final profiles = recordsOf(RecordKind.profile);
    final profile = profiles.isEmpty
        ? WorkspaceRecord.create(
            kind: RecordKind.profile,
            title: '个人档案',
            data: {
              'alias': alias,
              'growthEnabledAt': currentTime().toUtc().toIso8601String(),
              'accent': 'teal',
            },
          )
        : profiles.first.withData('alias', alias);
    await updateRecord(profile);
  }

  Future<void> startToday({
    required List<WorkspaceRecord> commitments,
    required List<WorkspaceRecord> plannedHabits,
  }) async {
    if (todayPlan != null) throw const FormatException('今天已经开始，承诺已锁定。');
    final uniqueCommitments =
        <String, WorkspaceRecord>{for (final task in commitments) task.id: task}
            .values
            .where((task) => task.kind == RecordKind.task && !task.isDone)
            .toList();
    if (uniqueCommitments.isEmpty || uniqueCommitments.length > 3) {
      throw const FormatException('请选择 1–3 项未完成任务作为今日承诺。');
    }
    final uniqueHabits = <String, WorkspaceRecord>{
      for (final habit in plannedHabits) habit.id: habit,
    }.values.where((habit) => habit.kind == RecordKind.habit).take(2).toList();
    final now = currentTime();
    final plan = WorkspaceRecord.create(
      kind: RecordKind.dailyPlan,
      title: '今日承诺',
      scheduledFor: growthService.logicalDay(now),
      status: WorkStatus.doing,
      data: {
        'dayKey': growthService.dayKey(now),
        'commitmentIds': uniqueCommitments.map((task) => task.id).toList(),
        'plannedHabitIds': uniqueHabits.map((habit) => habit.id).toList(),
        'previousFocusIds': todayTasks
            .where((task) => task.isFocus)
            .map((task) => task.id)
            .toList(),
        'replacements': <Map<String, dynamic>>[],
        'startedAt': now.toUtc().toIso8601String(),
      },
    );
    await addRecord(plan);
    for (final task in todayTasks) {
      final selected = uniqueCommitments.any((value) => value.id == task.id);
      if (task.isFocus != selected) {
        await updateRecord(task.withData('isFocus', selected));
      }
    }
  }

  Future<void> updateTodayCommitments(List<WorkspaceRecord> commitments) async {
    final plan = todayPlan;
    if (!canUpdateTodayCommitments || plan == null) {
      throw const FormatException('浠婃棩閲嶇偣宸查攣瀹氾紝鏃犳硶閲嶆柊閫夋嫨。');
    }
    final unique =
        <String, WorkspaceRecord>{for (final task in commitments) task.id: task}
            .values
            .where((task) => task.kind == RecordKind.task && !task.isDone)
            .take(3)
            .toList();
    if (unique.isEmpty) {
      throw const FormatException('璇疯嚦灏戦€夋嫨涓€椤规湭瀹屾垚浠诲姟。');
    }
    await updateRecord(
      plan.copyWith(
        data: {
          ...plan.data,
          'commitmentIds': unique.map((task) => task.id).toList(),
          'replacements': <Map<String, dynamic>>[],
        },
      ),
    );
    final selectedIds = unique.map((task) => task.id).toSet();
    for (final task in todayTasks) {
      final selected = selectedIds.contains(task.id);
      if (task.isFocus != selected) {
        await updateRecord(task.withData('isFocus', selected));
      }
    }
  }

  Future<bool> undoStartToday() async {
    final plan = todayPlan;
    if (plan == null ||
        todayClosed ||
        commitmentTasks.any((task) => task.isDone)) {
      return false;
    }
    final startedAt = DateTime.tryParse(
      plan.data['startedAt']?.toString() ?? '',
    );
    final hasFocusEvidence =
        startedAt != null &&
        recordsOf(RecordKind.focusSession).any((session) {
          final timestamp = session.scheduledFor ?? session.createdAt;
          return timestamp.isAfter(startedAt) &&
              activeCommitmentIds.contains(session.parentId);
        });
    if (hasFocusEvidence) return false;

    final previousFocusIds =
        (plan.data['previousFocusIds'] as List<dynamic>? ?? const [])
            .map((value) => value.toString())
            .toSet();
    for (final task in todayTasks) {
      final shouldBeFocus = previousFocusIds.contains(task.id);
      if (task.isFocus != shouldBeFocus) {
        await updateRecord(task.withData('isFocus', shouldBeFocus));
      }
    }
    await permanentlyDelete(plan);
    return true;
  }

  Future<void> replaceTodayCommitment({
    required int slot,
    required WorkspaceRecord replacement,
    required String reason,
  }) async {
    final plan = todayPlan;
    if (plan == null || slot < 0 || slot >= commitmentIds.length) {
      throw const FormatException('没有可替换的承诺槽位。');
    }
    final currentId = activeCommitmentIds[slot];
    final current = tasks.where((task) => task.id == currentId).firstOrNull;
    if (current?.isDone == true) throw const FormatException('已完成的承诺不能替换。');
    if (replacement.isDone || activeCommitmentIds.contains(replacement.id)) {
      throw const FormatException('请选择尚未列入承诺的未完成任务。');
    }
    if (reason.trim().isEmpty) throw const FormatException('替换承诺必须记录原因。');
    final replacements =
        (plan.data['replacements'] as List<dynamic>? ?? const [])
            .map((value) => Map<String, dynamic>.from(value as Map))
            .toList();
    replacements.add({
      'slot': slot,
      'originalId': commitmentIds[slot],
      'replacedId': currentId,
      'replacementId': replacement.id,
      'reason': reason.trim(),
      'at': currentTime().toUtc().toIso8601String(),
    });
    await updateRecord(plan.withData('replacements', replacements));
    if (current != null) await updateRecord(current.withData('isFocus', false));
    await updateRecord(replacement.withData('isFocus', true));
  }

  Future<void> closeToday({
    required Map<String, String> reasons,
    required Map<String, String> dispositions,
    List<WorkspaceRecord> tomorrowCommitments = const [],
    Map<String, DateTime> rescheduleDates = const {},
    String reflection = '',
  }) async {
    final plan = todayPlan;
    if (plan == null) throw const FormatException('请先开始今天。');
    if (plan.data['closedAt'] != null) {
      throw const FormatException('今天已经完成收尾。');
    }
    final logicalDay = growthService.logicalDay(currentTime());
    final overdueIds = overdueTasks.map((task) => task.id).toSet();
    final incomplete = tasks.where((task) {
      return !WorkStatus.terminal.contains(task.status) &&
          (isSameDay(task.scheduledFor, logicalDay) ||
              overdueIds.contains(task.id));
    }).toList();
    for (final task in incomplete) {
      final disposition = dispositions[task.id]?.trim() ?? '';
      if (disposition.isEmpty) {
        throw const FormatException('每项未结算任务都必须选择失败、跳过、改期或退回收集箱。');
      }
      if (disposition == 'failed' && (reasons[task.id] ?? '').trim().isEmpty) {
        throw const FormatException('将任务标记为失败时必须填写原因。');
      }
      if (disposition == 'rescheduled' && rescheduleDates[task.id] == null) {
        throw const FormatException('改期任务必须选择新的目标日期。');
      }
    }
    final nextDay = logicalDay.add(const Duration(days: 1));
    for (final task in incomplete) {
      final disposition = dispositions[task.id]!;
      if (disposition == 'failed' || disposition == 'cancel') {
        await settleTask(
          task,
          status: WorkStatus.failed,
          reason: reasons[task.id] ?? '收尾时取消',
        );
      } else if (disposition == 'skipped') {
        await settleTask(
          task,
          status: WorkStatus.skipped,
          reason: reasons[task.id] ?? '',
        );
      } else if (disposition == 'tomorrow' || disposition == 'rescheduled') {
        await rescheduleTaskInstance(
          task,
          disposition == 'tomorrow' ? nextDay : rescheduleDates[task.id]!,
          reason: reasons[task.id] ?? '',
        );
      } else if (disposition == 'inbox') {
        await _returnTaskInstanceToInbox(task, reason: reasons[task.id] ?? '');
      }
    }

    final closedAt = currentTime();
    final dayFacts = tasks
        .where((task) {
          return isSameDay(task.scheduledFor, logicalDay) ||
              incomplete.any((source) => source.id == task.id);
        })
        .map(
          (task) => {
            'id': task.id,
            'definitionId': task.data['definitionId'],
            'title': task.title,
            'status': task.status,
            'scheduledFor': task.scheduledFor?.toUtc().toIso8601String(),
            'dueAt': task.dueAt?.toUtc().toIso8601String(),
            'reason': task.data['settlementReason'],
            'rescheduledToId': task.data['rescheduledToId'],
          },
        )
        .toList();
    final snapshot = WorkspaceRecord.create(
      kind: RecordKind.protocolEvent,
      title: '每日收尾快照 · ${growthService.dayKey(closedAt)}',
      scheduledFor: logicalDay,
      status: WorkStatus.done,
      data: {
        'recordType': 'dayCloseSnapshot',
        'dayKey': growthService.dayKey(closedAt),
        'closedAt': closedAt.toUtc().toIso8601String(),
        'taskFacts': dayFacts,
        'dispositions': dispositions,
        'reasons': reasons,
      },
    );
    await addRecord(snapshot);
    await updateRecord(
      plan.copyWith(
        status: WorkStatus.done,
        data: {
          ...plan.data,
          'closedAt': closedAt.toUtc().toIso8601String(),
          'incompleteReasons': reasons,
          'dispositions': dispositions,
          'tomorrowCommitmentIds': tomorrowCommitments
              .map((task) => task.id)
              .toList(),
          'dayCloseSnapshotId': snapshot.id,
          'frozen': true,
        },
      ),
    );
    await _setGrowthXp(
      baseKey: 'close:${plan.id}',
      targetXp: 10,
      category: 'review',
      sourceId: plan.id,
      title: '完成每日收尾',
    );
    await _createDailyReviewDraft(
      day: logicalDay,
      snapshotId: snapshot.id,
      initialBody: reflection,
    );
  }

  Future<void> _returnTaskInstanceToInbox(
    WorkspaceRecord task, {
    String reason = '',
  }) async {
    final current = _latestRecord(task);
    final replacement = WorkspaceRecord.create(
      kind: RecordKind.task,
      title: current.title,
      body: current.body,
      status: WorkStatus.inbox,
      projectId: current.projectId,
      parentId: current.parentId,
      tags: current.tags,
      favorite: current.favorite,
      data: {
        ...current.data,
        'recordType': 'taskInstance',
        'definitionId': current.data['definitionId'] ?? current.id,
        'occurrenceKey': '',
        'returnedFromId': current.id,
        'settledAt': null,
        'completedAt': null,
      },
    );
    await updateRecord(
      current.copyWith(
        status: WorkStatus.rescheduled,
        data: {
          ...current.data,
          'settledAt': currentTime().toUtc().toIso8601String(),
          'settlementDisposition': 'inbox',
          'settlementReason': reason.trim(),
          'rescheduledToId': replacement.id,
        },
      ),
    );
    await addRecord(replacement);
  }

  Future<WorkspaceRecord> _createDailyReviewDraft({
    required DateTime day,
    required String snapshotId,
    String initialBody = '',
  }) async {
    final key = _calendarDayKey(day);
    final existing = reviewForPeriod(ReviewPeriodType.daily, key);
    if (existing != null) return existing;
    final draft = WorkspaceRecord.create(
      kind: RecordKind.note,
      title: '日回顾 · $key',
      body: initialBody,
      scheduledFor: day,
      tags: const ['日回顾'],
      data: {
        'recordType': 'periodReview',
        'periodType': ReviewPeriodType.daily.name,
        'periodKey': key,
        'periodStart': day.toUtc().toIso8601String(),
        'periodEnd': day.add(const Duration(days: 1)).toUtc().toIso8601String(),
        'dayCloseSnapshotId': snapshotId,
        'versions': const <Map<String, dynamic>>[],
        'draft': true,
      },
    );
    await addRecord(draft);
    return draft;
  }

  Future<void> useRecovery() async {
    final snapshot = growthSnapshot;
    if (snapshot.availableRecoveries < 1) {
      throw const FormatException('当前没有可用的恢复次数。');
    }
    final candidate = growthService.recoveryCandidate(
      activeRecords,
      currentTime(),
    );
    if (candidate == null) {
      throw const FormatException('近 14 日没有可恢复的缺失日期。');
    }
    final key = growthService.dayKey(candidate);
    if (growthService.planForDay(activeRecords, candidate) != null) {
      throw const FormatException('该日期已有记录，不能重复恢复。');
    }
    final now = currentTime();
    final plan = WorkspaceRecord.create(
      kind: RecordKind.dailyPlan,
      title: '恢复日结 · $key',
      scheduledFor: candidate,
      status: WorkStatus.done,
      data: {
        'dayKey': key,
        'recovered': true,
        'closedAt': now.toUtc().toIso8601String(),
        'recoveredAt': now.toUtc().toIso8601String(),
      },
    );
    await addRecord(plan);
    await _setGrowthXp(
      baseKey: 'recovery:$key',
      targetXp: 0,
      category: 'recovery',
      sourceId: plan.id,
      title: '恢复连续记录 · $key',
      forceEvent: true,
      data: {'used': true, 'recoveredDayKey': key},
    );
  }

  Future<void> addRecord(WorkspaceRecord record) async {
    record = _normalizeRsipRecord(record);
    if (record.kind == RecordKind.task && record.data['recordType'] == null) {
      record = _withDefaultTaskDeadline(record);
      final definitionId = 'definition-${record.id}';
      final definition = WorkspaceRecord(
        id: definitionId,
        kind: RecordKind.task,
        title: record.title,
        body: record.body,
        status: WorkStatus.todo,
        scheduledFor: record.scheduledFor,
        dueAt: record.dueAt,
        projectId: record.projectId,
        parentId: record.parentId,
        tags: record.tags,
        favorite: record.favorite,
        createdAt: record.createdAt,
        updatedAt: record.updatedAt,
        data: {
          ...record.data,
          'recordType': 'taskDefinition',
          'sourceId': record.id,
        },
      );
      final instance = record.copyWith(
        data: {
          ...record.data,
          'recordType': 'taskInstance',
          'definitionId': definitionId,
          'occurrenceKey': growthService.dayKey(
            record.scheduledFor ?? currentTime(),
          ),
        },
      );
      await database.saveRecord(definition);
      await database.saveRecord(instance);
      _records
        ..add(definition)
        ..add(instance);
      await ensureTaskInstancesThrough(
        growthService.logicalDay(currentTime()).add(const Duration(days: 90)),
      );
    } else {
      await database.saveRecord(record);
      _records.add(record);
    }
    _projectIndex = null;
    notifyListeners();
  }

  WorkspaceRecord _withDefaultTaskDeadline(WorkspaceRecord record) {
    if (record.dueAt != null) return record;
    final recurrence = record.data['recurrence']?.toString() ?? 'none';
    final anchor = record.scheduledFor ?? currentTime();
    if (recurrence != 'none') {
      final minutes =
          (record.data['completionWindowMinutes'] as num?)?.toInt() ?? 1440;
      return record.copyWith(
        dueAt: anchor.add(Duration(minutes: minutes.clamp(1, 525600))),
        touch: false,
      );
    }
    final logicalDay = growthService.logicalDay(anchor);
    return record.copyWith(
      dueAt: logicalDay
          .add(const Duration(days: 1))
          .add(Duration(hours: logicalDayBoundaryHour)),
      touch: false,
    );
  }

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
    _rsipStrictMode = value;
    _rsipAllowMultiplePerDay = !value;
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
    final current = _latestRecord(node);
    await updateRecord(current.copyWith(parentId: parentId));
    await _addProtocolEvent(
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
      await _addProtocolEvent(
        protocol: 'rsip',
        action: 'node_created',
        subject: record,
        data: {'nodeType': type.name, 'passive': passive},
      );
      return record;
    }

    final current = _latestRecord(existing);
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
    await _addProtocolEvent(
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
        : _latestRecord(existing).copyWith(
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
    await _addProtocolEvent(
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
    final current = _latestRecord(node);
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
    final current = _latestRecord(node);
    final day = growthService.logicalDay(logicalDay ?? currentTime());
    final dayKey = _calendarDayKey(day);
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
      await _addProtocolEvent(
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
    final current = _latestRecord(node);
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
    await _addProtocolEvent(
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
    final current = _latestRecord(node);
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
    final current = _latestRecord(node);
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
    await _addProtocolEvent(
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
        : _latestRecord(
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
    await _handleTaskRsipLinks(
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
    final current = _latestRecord(node);
    final previous = _rsipExecutionForKey(
      current.id,
      _calendarDayKey(logicalDay.subtract(const Duration(days: 1))),
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
    final node = _latestRecord(preview.node);
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
      await _addProtocolEvent(
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
    await _addProtocolEvent(
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
      final current = _latestRecord(node);
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
    final current = _latestRecord(node);
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

  Future<void> _handleTaskRsipLinks(
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
        await _addProtocolEvent(
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
    await _addProtocolEvent(
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

  Future<int> ensureTaskInstancesThrough(DateTime through) async {
    final existingKeys = recordsOf(RecordKind.task)
        .where((record) => record.data['recordType'] == 'taskInstance')
        .map(
          (record) =>
              '${record.data['definitionId']}:${record.data['occurrenceKey']}',
        )
        .toSet();
    final created = <WorkspaceRecord>[];
    for (final record in taskDefinitions) {
      final definition = TaskDefinition.fromRecord(record);
      if (!definition.isRecurring) continue;
      final start = startOfDay(
        definition.startAt ?? growthService.logicalDay(currentTime()),
      );
      final end = definition.endAt == null || definition.endAt!.isAfter(through)
          ? through
          : definition.endAt!;
      for (
        var day = start;
        !day.isAfter(startOfDay(end));
        day = day.add(const Duration(days: 1))
      ) {
        if (!_matchesRecurrence(definition, day)) continue;
        final key = _calendarDayKey(day);
        if (!existingKeys.add('${definition.id}:$key')) continue;
        final scheduled = DateTime(
          day.year,
          day.month,
          day.day,
          definition.startAt?.hour ?? 0,
          definition.startAt?.minute ?? 0,
        );
        created.add(
          WorkspaceRecord.create(
            kind: RecordKind.task,
            title: record.title,
            body: record.body,
            scheduledFor: scheduled,
            dueAt: definition.completionWindowMinutes <= 0
                ? null
                : scheduled.add(
                    Duration(minutes: definition.completionWindowMinutes),
                  ),
            projectId: record.projectId,
            parentId: record.parentId,
            tags: record.tags,
            favorite: record.favorite,
            data: {
              ...record.data,
              'recordType': 'taskInstance',
              'definitionId': definition.id,
              'occurrenceKey': key,
            },
          ),
        );
      }
    }
    if (created.isEmpty) return 0;
    for (final record in created) {
      await database.saveRecord(record);
    }
    _records.addAll(created);
    _projectIndex = null;
    notifyListeners();
    return created.length;
  }

  bool _matchesRecurrence(TaskDefinition definition, DateTime day) {
    final start = startOfDay(
      definition.startAt ?? growthService.logicalDay(currentTime()),
    );
    final days = day.difference(start).inDays;
    if (days < 0) return false;
    return switch (definition.recurrence) {
      RecurrenceType.none => days == 0,
      RecurrenceType.daily => true,
      RecurrenceType.weekdays => day.weekday <= DateTime.friday,
      RecurrenceType.weekly =>
        definition.weekdays.isEmpty
            ? day.weekday == start.weekday
            : definition.weekdays.contains(day.weekday),
      RecurrenceType.monthly =>
        day.day == _clampedMonthDay(day.year, day.month, start.day),
      RecurrenceType.yearly =>
        day.month == start.month &&
            day.day == _clampedMonthDay(day.year, start.month, start.day),
    };
  }

  int _clampedMonthDay(int year, int month, int requested) {
    return requested.clamp(1, DateTime(year, month + 1, 0).day).toInt();
  }

  String _calendarDayKey(DateTime day) {
    return '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
  }

  bool canAddRsipNode({String? excludingId}) {
    if (_rsipAllowMultiplePerDay) return true;
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

  bool canUseCtdpParent({required String recordId, String? parentId}) {
    if (parentId == null) return true;
    final byId = {for (final task in ctdpTasks) task.id: task};
    if (byId[parentId]?.ctdpIsGroup != true) return false;
    String? currentId = parentId;
    final visited = <String>{};
    while (currentId != null) {
      if (!visited.add(currentId) || currentId == recordId) return false;
      currentId = byId[currentId]?.parentId;
    }
    return true;
  }

  Future<void> updateRecord(WorkspaceRecord record) async {
    record = _normalizeRsipRecord(record);
    await database.saveRecord(record);
    final index = _records.indexWhere(
      (value) => value.id == record.id && value.kind == record.kind,
    );
    if (index < 0) {
      _records.add(record);
    } else {
      _records[index] = record;
    }
    _projectIndex = null;
    notifyListeners();
  }

  WorkspaceRecord _normalizeRsipRecord(WorkspaceRecord record) {
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

  WorkspaceRecord? taskDefinitionFor(WorkspaceRecord task) {
    final definitionId = task.data['definitionId']?.toString();
    if (definitionId == null) return null;
    return taskDefinitions
        .where((definition) => definition.id == definitionId)
        .firstOrNull;
  }

  Future<void> updateTaskWithScope({
    required WorkspaceRecord original,
    required WorkspaceRecord updated,
    required TaskEditScope scope,
  }) async {
    final definition = taskDefinitionFor(original);
    if (definition == null || scope == TaskEditScope.occurrence) {
      await updateRecord(updated);
      return;
    }

    final stableData = _stableTaskData(updated.data);
    await updateRecord(
      definition.copyWith(
        title: updated.title,
        body: updated.body,
        projectId: updated.projectId,
        parentId: updated.parentId,
        tags: updated.tags,
        favorite: updated.favorite,
        data: {
          ...definition.data,
          ...stableData,
          'recordType': 'taskDefinition',
        },
      ),
    );

    final threshold = original.scheduledFor ?? original.createdAt;
    final instances = tasks
        .where((task) {
          if (task.data['definitionId'] != definition.id ||
              WorkStatus.terminal.contains(task.status)) {
            return false;
          }
          if (scope == TaskEditScope.series) return true;
          final scheduled = task.scheduledFor ?? task.createdAt;
          return !scheduled.isBefore(threshold);
        })
        .toList(growable: false);
    for (final task in instances) {
      final next = task.id == original.id
          ? updated
          : task.copyWith(
              title: updated.title,
              body: updated.body,
              projectId: updated.projectId,
              parentId: updated.parentId,
              tags: updated.tags,
              favorite: updated.favorite,
              data: {
                ...task.data,
                ...stableData,
                'recordType': 'taskInstance',
                'definitionId': definition.id,
                'occurrenceKey': task.data['occurrenceKey'],
              },
            );
      await updateRecord(next);
    }
    await ensureTaskInstancesThrough(
      growthService.logicalDay(currentTime()).add(const Duration(days: 90)),
    );
  }

  Map<String, dynamic> _stableTaskData(Map<String, dynamic> source) {
    const keys = {
      'priority',
      'estimatedMinutes',
      'recurrence',
      'recurrenceWeekdays',
      'recurrenceEndAt',
      'completionWindowMinutes',
      'protocol',
      'ctdpUnitType',
      'ctdpTrigger',
      'ctdpAuxSignal',
      'ctdpAuxCompletionTrigger',
      'ctdpSessionMinutes',
      'ctdpDelayMinutes',
      'ctdpIsDurationless',
      'ctdpMinimumMinutes',
      'ctdpGroupTimeLimitHours',
      'ctdpPrecedents',
    };
    return {
      for (final entry in source.entries)
        if (keys.contains(entry.key)) entry.key: entry.value,
    };
  }

  Future<WorkspaceRecord> quickCapture({
    required RecordKind kind,
    required String text,
    String? body,
    DateTime? scheduledFor,
    String? projectId,
    String? status,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) throw const FormatException('请输入内容。');
    if (kind == RecordKind.link) {
      final uri = Uri.tryParse(trimmed);
      if (uri == null ||
          (uri.scheme != 'http' && uri.scheme != 'https') ||
          uri.host.isEmpty) {
        throw const FormatException('请输入以 http:// 或 https:// 开头的有效链接。');
      }
    }
    final effectiveScheduledFor =
        scheduledFor ?? (kind == RecordKind.diary ? currentTime() : null);
    if (kind == RecordKind.diary && effectiveScheduledFor != null) {
      final existing = diaryForDay(effectiveScheduledFor);
      if (existing != null) {
        final previous = existing.body.trim().isEmpty
            ? existing.title.trim()
            : existing.body.trim();
        final updated = existing.copyWith(
          title: '今日回顾',
          body: previous.isEmpty ? trimmed : '$previous\n$trimmed',
        );
        await updateRecord(updated);
        return updated;
      }
    }
    final record = WorkspaceRecord.create(
      kind: kind,
      title: kind == RecordKind.link ? _linkTitle(trimmed) : trimmed,
      body: body ?? '',
      status:
          status ??
          (kind == RecordKind.task
              ? effectiveScheduledFor == null
                    ? WorkStatus.inbox
                    : WorkStatus.todo
              : WorkStatus.todo),
      scheduledFor: effectiveScheduledFor,
      projectId: projectId,
      data: {
        if (kind == RecordKind.link) 'url': trimmed,
        if ((kind == RecordKind.note || kind == RecordKind.link) &&
            projectId == null &&
            effectiveScheduledFor == null)
          'inbox': true,
      },
    );
    await addRecord(record);
    return record;
  }

  Future<void> toggleTaskDone(WorkspaceRecord task) async {
    if (task.kind != RecordKind.task && task.kind != RecordKind.milestone) {
      return;
    }
    task = _latestRecord(task);
    final completing = !task.isDone;
    final protocolData = task.hasCtdpProtocol
        ? {
            'ctdpReservationPending': false,
            if (completing) ...{
              'ctdpChainCount': task.ctdpChainCount + 1,
              'ctdpTotalCompletions': task.ctdpTotalCompletions + 1,
              'ctdpLastCompletedAt': currentTime().toUtc().toIso8601String(),
            } else ...{
              'ctdpChainCount': 0,
              'ctdpTotalFailures': task.ctdpTotalFailures + 1,
              'ctdpLastFailureAt': currentTime().toUtc().toIso8601String(),
              'ctdpFailureReason': '任务未完成，主链从 #1 重新开始',
            },
          }
        : const <String, dynamic>{};
    final updated = task.copyWith(
      status: completing ? WorkStatus.done : WorkStatus.todo,
      data: {
        ...task.data,
        if (completing) 'completedAt': currentTime().toUtc().toIso8601String(),
        if (!completing) 'completedAt': null,
        ...protocolData,
      },
    );
    await updateRecord(updated);
    if (task.hasCtdpProtocol) {
      await _addProtocolEvent(
        protocol: 'ctdp',
        action: completing ? 'task_closed' : 'task_reopened',
        subject: task,
        successful: completing,
      );
    }
    if (task.kind == RecordKind.task) {
      await _syncCommitmentXp(task.id, completing);
    }
    if (completing && task.kind == RecordKind.task) {
      await _createNextOccurrence(updated);
    }
  }

  Future<void> setTaskStatus(WorkspaceRecord task, String status) {
    return updateRecord(task.copyWith(status: status));
  }

  Future<BatchOperationResult> batchSetTaskStatus(
    Iterable<WorkspaceRecord> selected,
    String status,
  ) async {
    const allowed = {
      WorkStatus.inbox,
      WorkStatus.todo,
      WorkStatus.doing,
      WorkStatus.done,
      WorkStatus.cancelled,
    };
    if (!allowed.contains(status)) {
      throw const FormatException('不支持的批量任务状态。');
    }
    var succeeded = 0;
    final failures = <BatchOperationFailure>[];
    for (final task in selected) {
      try {
        var current = _latestRecord(task);
        if (status == WorkStatus.done) {
          if (!current.isDone) await toggleTaskDone(current);
        } else if (current.isDone) {
          await toggleTaskDone(current);
          current = _latestRecord(current);
          if (status != WorkStatus.todo) {
            await setTaskStatus(current, status);
          }
        } else if (current.status != status) {
          await setTaskStatus(current, status);
        }
        succeeded++;
      } catch (error) {
        failures.add(
          BatchOperationFailure(recordId: task.id, message: '$error'),
        );
      }
    }
    return BatchOperationResult(succeeded: succeeded, failures: failures);
  }

  Future<BatchOperationResult> batchScheduleTasks(
    Iterable<WorkspaceRecord> selected,
    DateTime? date,
  ) async {
    final tasks = selected.toList(growable: false);
    final updates = <WorkspaceRecord>[];
    for (final task in tasks) {
      final current = _latestRecord(task);
      updates.add(
        current.copyWith(
          scheduledFor: date,
          status: date != null && current.status == WorkStatus.inbox
              ? WorkStatus.todo
              : current.status,
        ),
      );
    }
    try {
      await _saveRecordsBatch(updates);
    } catch (error) {
      return BatchOperationResult(
        succeeded: 0,
        failures: [
          for (final task in tasks)
            BatchOperationFailure(recordId: task.id, message: '$error'),
        ],
      );
    }
    var succeeded = 0;
    final failures = <BatchOperationFailure>[];
    for (final task in updates) {
      try {
        await notificationService.cancel(_notificationId(task.id));
        final reminder = task.data['reminderAt']?.toString();
        final reminderAt = reminder == null
            ? null
            : DateTime.tryParse(reminder)?.toLocal();
        if (reminderAt != null) {
          await notificationService.scheduleTaskReminder(
            id: _notificationId(task.id),
            title: task.title,
            when: reminderAt,
          );
        }
        succeeded++;
      } catch (error) {
        failures.add(
          BatchOperationFailure(recordId: task.id, message: '$error'),
        );
      }
    }
    return BatchOperationResult(succeeded: succeeded, failures: failures);
  }

  Future<BatchOperationResult> batchSetTaskProject(
    Iterable<WorkspaceRecord> selected,
    String? projectId,
  ) async {
    if (projectId != null && projectById(projectId) == null) {
      throw const FormatException('项目不存在或已在回收站。');
    }
    final tasks = selected.toList(growable: false);
    try {
      await _saveRecordsBatch(
        tasks.map((task) => _latestRecord(task).copyWith(projectId: projectId)),
      );
      return BatchOperationResult(succeeded: tasks.length);
    } catch (error) {
      return BatchOperationResult(
        succeeded: 0,
        failures: [
          for (final task in tasks)
            BatchOperationFailure(recordId: task.id, message: '$error'),
        ],
      );
    }
  }

  Future<BatchOperationResult> batchMoveTasksToTrash(
    Iterable<WorkspaceRecord> selected,
  ) async {
    final tasks = selected.toList(growable: false);
    try {
      await _saveRecordsBatch(
        tasks.map(
          (task) => _latestRecord(task).copyWith(deletedAt: currentTime()),
        ),
      );
      return BatchOperationResult(succeeded: tasks.length);
    } catch (error) {
      return BatchOperationResult(
        succeeded: 0,
        failures: [
          for (final task in tasks)
            BatchOperationFailure(recordId: task.id, message: '$error'),
        ],
      );
    }
  }

  Future<void> setLogicalDayBoundaryHour(int value) async {
    _logicalDayBoundaryHour = value.clamp(0, 6);
    growthService = GrowthService(
      logicalDayBoundaryHour: _logicalDayBoundaryHour,
    );
    await database.writeMetadata(
      'logical_day_boundary_hour',
      '$_logicalDayBoundaryHour',
    );
    notifyListeners();
  }

  Future<void> _saveRecordsBatch(Iterable<WorkspaceRecord> records) async {
    final values = records.map(_normalizeRsipRecord).toList(growable: false);
    if (values.isEmpty) return;
    await database.saveRecords(values);
    for (final record in values) {
      final index = _records.indexWhere(
        (value) => value.id == record.id && value.kind == record.kind,
      );
      if (index < 0) {
        _records.add(record);
      } else {
        _records[index] = record;
      }
    }
    _projectIndex = null;
    notifyListeners();
  }

  Future<void> setCloseToTray(bool value) async {
    _closeToTray = value;
    await database.writeMetadata('windows_close_to_tray', '$value');
    await windowsActivityService.setCloseToTray(value);
    notifyListeners();
  }

  Future<void> setStartupEnabled(bool value) async {
    _startupEnabled = await windowsActivityService.setStartupEnabled(value);
    await database.writeMetadata('windows_startup_enabled', '$_startupEnabled');
    notifyListeners();
  }

  Future<void> setForegroundDetectionEnabled(bool value) async {
    _foregroundDetectionEnabled = value;
    await database.writeMetadata('foreground_detection_enabled', '$value');
    notifyListeners();
  }

  Future<WorkspaceRecord> saveFocusPreset({
    WorkspaceRecord? preset,
    required String title,
    required FocusMode mode,
    required int minutes,
    String? taskId,
    String listMode = 'none',
    List<String> applications = const [],
    bool detectionEnabled = false,
    String scheduleMode = 'none',
    DateTime? scheduledAt,
    List<int> weekdays = const [],
    bool bringToFrontOnSchedule = true,
  }) async {
    if (title.trim().isEmpty) {
      throw const FormatException('请填写专注预设名称。');
    }
    if (!const {'none', 'allow', 'block'}.contains(listMode)) {
      throw const FormatException('未知的应用列表模式。');
    }
    if (!const {'none', 'once', 'weekly'}.contains(scheduleMode)) {
      throw const FormatException('未知的专注定时模式。');
    }
    if (scheduleMode != 'none' && scheduledAt == null) {
      throw const FormatException('请设置专注提醒时间。');
    }
    if (scheduleMode == 'weekly' && weekdays.isEmpty) {
      throw const FormatException('每周定时至少选择一天。');
    }
    final data = {
      ...?preset?.data,
      'recordType': 'focusPreset',
      'mode': mode.name,
      'minutes': minutes.clamp(1, 720),
      'taskId': taskId,
      'listMode': listMode,
      'applications': applications
          .map((value) => value.trim().toLowerCase())
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList(),
      'detectionEnabled': detectionEnabled,
      'scheduleMode': scheduleMode,
      'scheduledAt': scheduledAt?.toUtc().toIso8601String(),
      'weekdays': weekdays,
      'bringToFrontOnSchedule': bringToFrontOnSchedule,
      if (scheduleMode == 'none') ...{
        'pendingScheduledStartAt': null,
        'scheduledLastTriggered': null,
      },
    };
    final record = preset == null
        ? WorkspaceRecord.create(
            kind: RecordKind.template,
            title: title.trim(),
            data: data,
          )
        : preset.copyWith(title: title.trim(), data: data);
    await updateRecord(record);
    await _scheduleFocusPreset(record);
    return record;
  }

  Future<void> _scheduleAllFocusPresets() async {
    for (final timer in _focusScheduleTimers.values) {
      timer.cancel();
    }
    for (final timer in _focusMissTimers.values) {
      timer.cancel();
    }
    _focusScheduleTimers.clear();
    _focusMissTimers.clear();
    for (final preset in focusPresets) {
      await _scheduleFocusPreset(preset);
    }
  }

  Future<void> _scheduleFocusPreset(WorkspaceRecord preset) async {
    _focusScheduleTimers.remove(preset.id)?.cancel();
    _focusMissTimers.remove(preset.id)?.cancel();
    final mode = preset.data['scheduleMode']?.toString() ?? 'none';
    if (mode == 'none') return;
    final pendingAt = DateTime.tryParse(
      preset.data['pendingScheduledStartAt']?.toString() ?? '',
    )?.toLocal();
    if (pendingAt != null) {
      _scheduleMissedFocus(preset.id, pendingAt);
      return;
    }

    final now = currentTime();
    final recent = _recentFocusSchedule(preset, now);
    final lastTriggered = preset.data['scheduledLastTriggered']?.toString();
    if (recent != null &&
        _focusScheduleKey(recent) != lastTriggered &&
        now.difference(recent) <= const Duration(minutes: 15)) {
      await _activateFocusSchedule(preset.id, recent);
      return;
    }
    if (mode == 'once' && recent != null && lastTriggered == null) {
      await _recordFocusScheduleDecision(
        preset,
        action: 'missed_start',
        scheduledAt: recent,
      );
      return;
    }
    final next = _nextFocusSchedule(preset, now);
    if (next == null) return;
    await notificationService.scheduleTaskReminder(
      id: stableNotificationId('focus-preset:${preset.id}'),
      title: '专注计划待确认',
      body: '${preset.title} 已到计划时间，请确认后开始。',
      when: next,
    );
    _focusScheduleTimers[preset.id] = Timer(next.difference(now), () {
      _activateFocusSchedule(preset.id, next);
    });
  }

  DateTime? _recentFocusSchedule(WorkspaceRecord preset, DateTime now) {
    final scheduled = DateTime.tryParse(
      preset.data['scheduledAt']?.toString() ?? '',
    )?.toLocal();
    if (scheduled == null || scheduled.isAfter(now)) return null;
    if (preset.data['scheduleMode'] == 'once') return scheduled;
    final weekdays = (preset.data['weekdays'] as List<dynamic>? ?? const [])
        .map((value) => (value as num).toInt())
        .toSet();
    for (var offset = 0; offset <= 7; offset++) {
      final day = now.subtract(Duration(days: offset));
      if (!weekdays.contains(day.weekday)) continue;
      final candidate = DateTime(
        day.year,
        day.month,
        day.day,
        scheduled.hour,
        scheduled.minute,
      );
      if (!candidate.isAfter(now)) return candidate;
    }
    return null;
  }

  DateTime? _nextFocusSchedule(WorkspaceRecord preset, DateTime now) {
    final scheduled = DateTime.tryParse(
      preset.data['scheduledAt']?.toString() ?? '',
    )?.toLocal();
    if (scheduled == null) return null;
    if (preset.data['scheduleMode'] == 'once') {
      return scheduled.isAfter(now) ? scheduled : null;
    }
    final weekdays = (preset.data['weekdays'] as List<dynamic>? ?? const [])
        .map((value) => (value as num).toInt())
        .toSet();
    for (var offset = 0; offset <= 7; offset++) {
      final day = now.add(Duration(days: offset));
      if (!weekdays.contains(day.weekday)) continue;
      final candidate = DateTime(
        day.year,
        day.month,
        day.day,
        scheduled.hour,
        scheduled.minute,
      );
      if (candidate.isAfter(now)) return candidate;
    }
    return null;
  }

  Future<void> _activateFocusSchedule(String presetId, DateTime at) async {
    final preset = focusPresets
        .where((record) => record.id == presetId)
        .firstOrNull;
    if (preset == null ||
        preset.data['scheduledLastTriggered'] == _focusScheduleKey(at)) {
      return;
    }
    final updated = preset.copyWith(
      data: {
        ...preset.data,
        'pendingScheduledStartAt': at.toUtc().toIso8601String(),
        'scheduledLastTriggered': _focusScheduleKey(at),
      },
    );
    await updateRecord(updated);
    await notificationService.showNow(
      id: stableNotificationId('focus-preset-now:${updated.id}'),
      title: '专注计划待确认',
      body: '${updated.title} 已到计划时间，请选择“确认开始”或“跳过”。',
    );
    if (_bringToFrontOnFocusSchedule &&
        updated.data['bringToFrontOnSchedule'] != false) {
      await windowsActivityService.showWindow();
    }
    _scheduleMissedFocus(updated.id, at);
  }

  Future<void> setBringToFrontOnFocusSchedule(bool value) async {
    _bringToFrontOnFocusSchedule = value;
    await database.writeMetadata('focus_schedule_bring_to_front', '$value');
    notifyListeners();
  }

  void _scheduleMissedFocus(String presetId, DateTime at) {
    _focusMissTimers.remove(presetId)?.cancel();
    final remaining = at
        .add(const Duration(minutes: 15))
        .difference(currentTime());
    if (remaining <= Duration.zero) {
      _missScheduledFocus(presetId, at);
      return;
    }
    _focusMissTimers[presetId] = Timer(
      remaining,
      () => _missScheduledFocus(presetId, at),
    );
  }

  Future<void> _missScheduledFocus(String presetId, DateTime at) async {
    final preset = focusPresets
        .where((record) => record.id == presetId)
        .firstOrNull;
    if (preset == null || preset.data['pendingScheduledStartAt'] == null) {
      return;
    }
    await _resolveFocusSchedule(
      preset,
      action: 'missed_start',
      scheduledAt: at,
    );
  }

  Future<void> confirmScheduledFocus(WorkspaceRecord selected) async {
    for (final preset in pendingFocusPresets) {
      final scheduledAt = DateTime.tryParse(
        preset.data['pendingScheduledStartAt']?.toString() ?? '',
      )?.toLocal();
      if (scheduledAt == null) continue;
      await _resolveFocusSchedule(
        preset,
        action: preset.id == selected.id
            ? 'start_confirmed'
            : 'conflict_not_selected',
        scheduledAt: scheduledAt,
      );
    }
  }

  Future<void> declineScheduledFocus(WorkspaceRecord preset) async {
    final scheduledAt = DateTime.tryParse(
      preset.data['pendingScheduledStartAt']?.toString() ?? '',
    )?.toLocal();
    if (scheduledAt == null) return;
    await _resolveFocusSchedule(
      preset,
      action: 'start_declined',
      scheduledAt: scheduledAt,
    );
  }

  Future<void> _resolveFocusSchedule(
    WorkspaceRecord preset, {
    required String action,
    required DateTime scheduledAt,
  }) async {
    _focusMissTimers.remove(preset.id)?.cancel();
    final updated = preset.copyWith(
      data: {...preset.data, 'pendingScheduledStartAt': null},
    );
    await updateRecord(updated);
    await _recordFocusScheduleDecision(
      updated,
      action: action,
      scheduledAt: scheduledAt,
    );
    await _scheduleFocusPreset(updated);
  }

  Future<void> _recordFocusScheduleDecision(
    WorkspaceRecord preset, {
    required String action,
    required DateTime scheduledAt,
  }) async {
    await addRecord(
      WorkspaceRecord.create(
        kind: RecordKind.protocolEvent,
        title: preset.title,
        parentId: preset.id,
        scheduledFor: currentTime(),
        data: {
          'recordType': 'focusScheduleEvent',
          'action': action,
          'scheduledAt': scheduledAt.toUtc().toIso8601String(),
        },
      ),
    );
  }

  String _focusScheduleKey(DateTime value) => value.toUtc().toIso8601String();

  Future<WorkspaceRecord> createTaskGroup({
    required String title,
    required bool sequential,
    int? timeLimitMinutes,
  }) async {
    if (title.trim().isEmpty) {
      throw const FormatException('请填写任务群名称。');
    }
    if (timeLimitMinutes != null &&
        (timeLimitMinutes < 1 || timeLimitMinutes > 43200)) {
      throw const FormatException('任务群总时限必须在 1–43200 分钟之间。');
    }
    final group = WorkspaceRecord.create(
      kind: RecordKind.template,
      title: title.trim(),
      data: {
        'recordType': 'taskGroup',
        'mode': sequential ? 'sequential' : 'parallel',
        'timeLimitMinutes': ?timeLimitMinutes,
        'version': 1,
      },
    );
    await addRecord(group);
    return group;
  }

  Future<WorkspaceRecord> updateTaskGroup({
    required WorkspaceRecord group,
    required String title,
    required bool sequential,
    required int? timeLimitMinutes,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('请填写任务群名称。');
    }
    if (timeLimitMinutes != null &&
        (timeLimitMinutes < 1 || timeLimitMinutes > 43200)) {
      throw const FormatException('任务群总时限必须在 1–43200 分钟之间。');
    }
    final current = _latestRecord(group);
    final wasSequential = current.data['mode'] == 'sequential';
    if (wasSequential != sequential &&
        groupMembers(current.id).any(_taskExecutionStarted)) {
      throw const FormatException('任务群已有成员开始执行，暂不能切换模式。');
    }
    final updated = current.copyWith(
      title: trimmed,
      data: {
        ...current.data,
        'recordType': 'taskGroup',
        'mode': sequential ? 'sequential' : 'parallel',
        'timeLimitMinutes': timeLimitMinutes,
        'version': ((current.data['version'] as num?)?.toInt() ?? 1) + 1,
      },
    );
    await updateRecord(updated);
    return updated;
  }

  bool taskGroupModeLocked(WorkspaceRecord group) =>
      groupMembers(group.id).any(_taskExecutionStarted);

  List<WorkspaceRecord> groupMembers(String groupId) {
    final memberRelations =
        relations
            .where(
              (record) =>
                  record.data['relationType'] == 'taskGroupMember' &&
                  record.data['groupId'] == groupId &&
                  record.data['active'] != false,
            )
            .toList()
          ..sort(
            (a, b) => ((a.data['position'] as num?)?.toInt() ?? 0).compareTo(
              (b.data['position'] as num?)?.toInt() ?? 0,
            ),
          );
    return memberRelations
        .map(
          (relation) => tasks
              .where((task) => task.id == relation.data['taskId'])
              .firstOrNull,
        )
        .whereType<WorkspaceRecord>()
        .toList(growable: false);
  }

  Future<void> addTaskToGroup({
    required WorkspaceRecord task,
    required WorkspaceRecord group,
  }) async {
    final existing = relations.where(
      (record) =>
          record.data['relationType'] == 'taskGroupMember' &&
          record.data['taskId'] == task.id &&
          record.data['active'] != false,
    );
    if (existing.isNotEmpty) {
      throw const FormatException('一个任务只能属于一个活动任务群。');
    }
    final position = groupMembers(group.id).length;
    await addRecord(
      WorkspaceRecord.create(
        kind: RecordKind.relation,
        title: '${group.title} · ${task.title}',
        parentId: group.id,
        data: {
          'relationType': 'taskGroupMember',
          'groupId': group.id,
          'taskId': task.id,
          'position': position,
          'active': true,
        },
      ),
    );
  }

  bool taskGroupMemberCanMove(
    WorkspaceRecord task,
    WorkspaceRecord group,
    int targetIndex,
  ) {
    if (group.data['mode'] != 'sequential') return false;
    final members = groupMembers(group.id);
    final currentIndex = members.indexWhere((member) => member.id == task.id);
    if (currentIndex < 0 || targetIndex < 0 || targetIndex >= members.length) {
      return false;
    }
    if (_taskExecutionStarted(task)) return false;
    final lowerBarrier = members
        .take(currentIndex)
        .toList()
        .lastIndexWhere(_taskExecutionStarted);
    final followingBarrier = members
        .skip(currentIndex + 1)
        .toList()
        .indexWhere(_taskExecutionStarted);
    final upperBarrier = followingBarrier < 0
        ? members.length
        : currentIndex + 1 + followingBarrier;
    return targetIndex > lowerBarrier && targetIndex < upperBarrier;
  }

  Future<void> reorderTaskGroupMember({
    required WorkspaceRecord task,
    required WorkspaceRecord group,
    required int targetIndex,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      throw const FormatException('任务链重排必须填写原因。');
    }
    if (!taskGroupMemberCanMove(task, group, targetIndex)) {
      throw const FormatException('只能在同一段未开始任务之间调整顺序。');
    }
    final members = groupMembers(group.id);
    final before = members.map((member) => member.id).toList();
    final currentIndex = members.indexWhere((member) => member.id == task.id);
    final reordered = [...members];
    final moving = reordered.removeAt(currentIndex);
    reordered.insert(targetIndex, moving);
    final nextVersion = ((group.data['version'] as num?)?.toInt() ?? 1) + 1;
    for (var index = 0; index < reordered.length; index++) {
      final relation = relations.firstWhere(
        (record) =>
            record.data['relationType'] == 'taskGroupMember' &&
            record.data['groupId'] == group.id &&
            record.data['taskId'] == reordered[index].id &&
            record.data['active'] != false,
      );
      await updateRecord(
        relation.copyWith(
          data: {
            ...relation.data,
            'position': index,
            'groupVersion': nextVersion,
          },
        ),
      );
    }
    final currentGroup = _latestRecord(group);
    await updateRecord(
      currentGroup.copyWith(
        data: {
          ...currentGroup.data,
          'version': nextVersion,
          'lastReorderedAt': currentTime().toUtc().toIso8601String(),
          'lastReorderReason': reason.trim(),
        },
      ),
    );
    await addRecord(
      WorkspaceRecord.create(
        kind: RecordKind.protocolEvent,
        title: group.title,
        parentId: group.id,
        scheduledFor: currentTime(),
        status: WorkStatus.done,
        data: {
          'recordType': 'taskGroupReorder',
          'groupId': group.id,
          'taskId': task.id,
          'version': nextVersion,
          'reason': reason.trim(),
          'beforeTaskIds': before,
          'afterTaskIds': reordered.map((member) => member.id).toList(),
        },
      ),
    );
  }

  Future<BatchOperationResult> moveTaskGroupToTrash(
    WorkspaceRecord group,
  ) async {
    final current = _latestRecord(group);
    final deletedAt = currentTime();
    final updates = <WorkspaceRecord>[
      current.copyWith(deletedAt: deletedAt),
      for (final relation in _records.where(
        (record) =>
            record.kind == RecordKind.relation &&
            record.data['relationType'] == 'taskGroupMember' &&
            record.data['groupId'] == current.id &&
            record.data['active'] != false &&
            !record.isDeleted,
      ))
        relation.copyWith(
          deletedAt: deletedAt,
          data: {
            ...relation.data,
            'active': false,
            'deletedWithTaskGroupId': current.id,
          },
        ),
    ];
    try {
      await _saveRecordsBatch(updates);
      return BatchOperationResult(succeeded: 1);
    } catch (error) {
      return BatchOperationResult(
        succeeded: 0,
        failures: [
          BatchOperationFailure(recordId: current.id, message: '$error'),
        ],
      );
    }
  }

  Future<BatchOperationResult> restoreTaskGroup(WorkspaceRecord group) async {
    final current = _latestRecord(group);
    final relationsToRestore = _records.where(
      (record) =>
          record.kind == RecordKind.relation &&
          record.isDeleted &&
          record.data['deletedWithTaskGroupId'] == current.id,
    );
    final updates = <WorkspaceRecord>[current.copyWith(deletedAt: null)];
    final conflictFailures = <BatchOperationFailure>[];
    for (final relation in relationsToRestore) {
      final taskId = relation.data['taskId']?.toString();
      final occupied =
          taskId != null &&
          relations.any(
            (candidate) =>
                candidate.data['relationType'] == 'taskGroupMember' &&
                candidate.data['taskId'] == taskId &&
                candidate.data['groupId'] != current.id &&
                candidate.data['active'] != false,
          );
      final data = {...relation.data};
      if (occupied) {
        data['active'] = false;
        data['restoreConflict'] = true;
        updates.add(relation.copyWith(data: data));
        conflictFailures.add(
          BatchOperationFailure(
            recordId: relation.id,
            message: '成员任务已加入其他任务群，关系未恢复。',
          ),
        );
      } else {
        data
          ..remove('deletedWithTaskGroupId')
          ..remove('restoreConflict')
          ..addAll({'active': true});
        updates.add(relation.copyWith(deletedAt: null, data: data));
      }
    }
    try {
      await _saveRecordsBatch(updates);
      return BatchOperationResult(succeeded: 1, failures: conflictFailures);
    } catch (error) {
      return BatchOperationResult(
        succeeded: 0,
        failures: [
          BatchOperationFailure(recordId: current.id, message: '$error'),
        ],
      );
    }
  }

  bool _taskExecutionStarted(WorkspaceRecord task) {
    if (task.status == WorkStatus.doing ||
        WorkStatus.terminal.contains(task.status) ||
        task.data['startedAt'] != null) {
      return true;
    }
    return recordsOf(
      RecordKind.focusSession,
    ).any((session) => session.parentId == task.id);
  }

  bool isTaskGroupMemberLocked(WorkspaceRecord task, WorkspaceRecord group) {
    if (group.data['mode'] != 'sequential') return false;
    final members = groupMembers(group.id);
    final index = members.indexWhere((member) => member.id == task.id);
    if (index <= 0) return false;
    return members.take(index).any((member) {
      if (member.status == WorkStatus.done ||
          member.status == WorkStatus.skipped) {
        return false;
      }
      return member.data['chainSkipContinue'] != true;
    });
  }

  Future<void> skipTaskAndContinueChain(WorkspaceRecord task) async {
    await updateRecord(
      task.copyWith(
        status: WorkStatus.skipped,
        data: {
          ...task.data,
          'chainSkipContinue': true,
          'settledAt': currentTime().toUtc().toIso8601String(),
        },
      ),
    );
  }

  List<WorkspaceRecord> projectsForTask(WorkspaceRecord task) {
    return _projectsForTask(task, includeTrash: false);
  }

  List<WorkspaceRecord> projectsForTaskIncludingTrash(WorkspaceRecord task) {
    return _projectsForTask(task, includeTrash: true);
  }

  List<WorkspaceRecord> _projectsForTask(
    WorkspaceRecord task, {
    required bool includeTrash,
  }) {
    final ids = <String>{if (task.projectId != null) task.projectId!};
    ids.addAll(
      relations
          .where(
            (record) =>
                record.data['relationType'] == 'taskProject' &&
                record.data['taskId'] == task.id,
          )
          .map((record) => record.data['projectId']?.toString())
          .whereType<String>(),
    );
    return ids
        .map(includeTrash ? projectByIdIncludingTrash : projectById)
        .whereType<WorkspaceRecord>()
        .toList();
  }

  Map<String, int> projectAssociationCounts(WorkspaceRecord project) {
    final projectTasks = this.projectTasks(project.id);
    final projectTaskIds = projectTasks.map((task) => task.id).toSet();
    final groups = taskGroups.where(
      (group) => groupMembers(
        group.id,
      ).any((task) => projectTaskIds.contains(task.id)),
    );
    final documents = [...notes, ...diaries].where((record) {
      final related =
          (record.data['relatedProjectIds'] as List<dynamic>? ?? const []).map(
            (value) => value.toString(),
          );
      return record.projectId == project.id || related.contains(project.id);
    });
    return {
      'tasks': projectTasks.length,
      'groups': groups.length,
      'notes': documents
          .where((record) => record.data['recordType'] != 'periodReview')
          .length,
      'reviews': documents
          .where((record) => record.data['recordType'] == 'periodReview')
          .length,
      'milestones': recordsOf(RecordKind.milestone)
          .where(
            (record) =>
                record.projectId == project.id || record.parentId == project.id,
          )
          .length,
    };
  }

  TaskContextSummary taskContextSummary(WorkspaceRecord task) {
    final projectRecords = projectsForTaskIncludingTrash(task);
    final primary = projectByIdIncludingTrash(task.projectId);
    final groupRelation = relations
        .where(
          (record) =>
              record.data['relationType'] == 'taskGroupMember' &&
              record.data['taskId'] == task.id &&
              record.data['active'] != false,
        )
        .firstOrNull;
    final groupId = groupRelation?.data['groupId']?.toString();
    final group = groupId == null
        ? null
        : taskGroups.where((record) => record.id == groupId).firstOrNull;
    final members = group == null
        ? const <WorkspaceRecord>[]
        : groupMembers(group.id);
    final position = members.indexWhere((member) => member.id == task.id);
    final definition = taskDefinitionFor(task);
    DateTime? parseDate(Object? value) =>
        DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    final reason = task.data['settlementReason']?.toString() ?? '';
    return TaskContextSummary(
      taskId: task.id,
      status: task.status,
      recurring:
          (definition?.data['recurrence'] ?? task.data['recurrence']) != null &&
          (definition?.data['recurrence'] ?? task.data['recurrence']) != 'none',
      primaryProjectTitle: primary?.title,
      primaryProjectInTrash: primary?.isDeleted == true,
      projectTitles: projectRecords
          .map(
            (project) =>
                project.isDeleted ? '${project.title}（项目在回收站）' : project.title,
          )
          .toList(growable: false),
      additionalProjectCount: projectRecords
          .where((project) => project.id != task.projectId)
          .length,
      ctdpEnabled: task.hasCtdpProtocol,
      groupId: group?.id,
      groupTitle: group?.title,
      groupMode: group?.data['mode']?.toString(),
      chainPosition: position < 0 ? null : position + 1,
      chainLength: members.isEmpty ? null : members.length,
      previousTaskTitle: position > 0 ? members[position - 1].title : null,
      nextTaskTitle: position >= 0 && position + 1 < members.length
          ? members[position + 1].title
          : null,
      lockReason: group != null && isTaskGroupMemberLocked(task, group)
          ? '前置任务尚未完成或未选择“跳过并继续”'
          : null,
      scheduledFor: task.scheduledFor,
      dueAt: task.dueAt,
      settledAt: parseDate(task.data['settledAt'] ?? task.data['completedAt']),
      result: task.data['resultNote']?.toString(),
      failureReason: task.status == WorkStatus.failed ? reason : null,
      skipReason: task.status == WorkStatus.skipped ? reason : null,
      rescheduledTo: parseDate(task.data['rescheduledTo']),
      rescheduledFromId: task.data['rescheduledFromId']?.toString(),
    );
  }

  Future<void> linkTaskToProject({
    required WorkspaceRecord task,
    required WorkspaceRecord project,
    bool primary = false,
  }) async {
    if (primary) {
      await updateRecord(task.copyWith(projectId: project.id));
      return;
    }
    final exists = relations.any(
      (record) =>
          record.data['relationType'] == 'taskProject' &&
          record.data['taskId'] == task.id &&
          record.data['projectId'] == project.id,
    );
    if (exists || task.projectId == project.id) return;
    await addRecord(
      WorkspaceRecord.create(
        kind: RecordKind.relation,
        title: '${task.title} → ${project.title}',
        data: {
          'relationType': 'taskProject',
          'taskId': task.id,
          'projectId': project.id,
          'primary': false,
        },
      ),
    );
  }

  Future<void> recordForegroundEvent({
    required String applicationId,
    required DateTime startedAt,
    required Duration duration,
    String? presetId,
  }) async {
    if (!_foregroundDetectionEnabled || duration.inSeconds < 1) return;
    await addRecord(
      WorkspaceRecord.create(
        kind: RecordKind.protocolEvent,
        title: applicationId,
        scheduledFor: startedAt,
        data: {
          'recordType': 'foregroundEvent',
          'applicationId': applicationId,
          'startedAt': startedAt.toUtc().toIso8601String(),
          'durationSeconds': duration.inSeconds,
          'presetId': presetId,
        },
      ),
    );
  }

  Future<void> removeTaskFromGroup({
    required WorkspaceRecord task,
    required WorkspaceRecord group,
  }) async {
    final relation = relations
        .where(
          (record) =>
              record.data['relationType'] == 'taskGroupMember' &&
              record.data['groupId'] == group.id &&
              record.data['taskId'] == task.id &&
              record.data['active'] != false,
        )
        .firstOrNull;
    if (relation == null) return;
    final remaining =
        relations
            .where(
              (record) =>
                  record.data['relationType'] == 'taskGroupMember' &&
                  record.data['groupId'] == group.id &&
                  record.id != relation.id &&
                  record.data['active'] != false,
            )
            .toList()
          ..sort(
            (a, b) => ((a.data['position'] as num?)?.toInt() ?? 0).compareTo(
              (b.data['position'] as num?)?.toInt() ?? 0,
            ),
          );
    final updates = <WorkspaceRecord>[
      relation.copyWith(
        data: {
          ...relation.data,
          'active': false,
          'detachedAt': currentTime().toUtc().toIso8601String(),
        },
      ),
      for (var index = 0; index < remaining.length; index++)
        remaining[index].copyWith(
          data: {...remaining[index].data, 'position': index},
        ),
    ];
    await _saveRecordsBatch(updates);
  }

  Future<BatchOperationResult> batchSetTaskGroup(
    Iterable<WorkspaceRecord> selected,
    String? groupId, {
    bool replaceExisting = false,
  }) async {
    final group = groupId == null
        ? null
        : taskGroups.where((record) => record.id == groupId).firstOrNull;
    if (groupId != null && group == null) {
      throw const FormatException('任务群不存在或已在回收站。');
    }
    final tasks = selected.toList(growable: false);
    final updates = <WorkspaceRecord>[];
    final failures = <BatchOperationFailure>[];
    final detachedRelationIds = <String>{};
    final affectedGroupIds = <String>{};
    var nextPosition = group == null ? 0 : groupMembers(group.id).length;
    var succeeded = 0;
    for (final task in tasks) {
      final current = _latestRecord(task);
      final existing = relations
          .where(
            (record) =>
                record.data['relationType'] == 'taskGroupMember' &&
                record.data['taskId'] == current.id &&
                record.data['active'] != false,
          )
          .toList(growable: false);
      final sameGroup =
          group != null &&
          existing.any((record) => record.data['groupId'] == group.id);
      final conflicts = group == null
          ? existing
          : existing
                .where((record) => record.data['groupId'] != group.id)
                .toList(growable: false);
      if (conflicts.isNotEmpty && !replaceExisting) {
        failures.add(
          BatchOperationFailure(recordId: current.id, message: '任务已属于其他任务群。'),
        );
        continue;
      }
      for (final relation in conflicts) {
        detachedRelationIds.add(relation.id);
        final sourceGroupId = relation.data['groupId']?.toString();
        if (sourceGroupId != null) affectedGroupIds.add(sourceGroupId);
        updates.add(
          relation.copyWith(
            data: {
              ...relation.data,
              'active': false,
              'replacedByGroupId': group?.id,
              'detachedAt': currentTime().toUtc().toIso8601String(),
            },
          ),
        );
      }
      if (!sameGroup && group != null) {
        updates.add(
          WorkspaceRecord.create(
            kind: RecordKind.relation,
            title: '${group.title} · ${current.title}',
            parentId: group.id,
            data: {
              'relationType': 'taskGroupMember',
              'groupId': group.id,
              'taskId': current.id,
              'position': nextPosition++,
              'active': true,
            },
          ),
        );
      }
      succeeded++;
    }
    for (final affectedGroupId in affectedGroupIds) {
      final remaining =
          relations
              .where(
                (record) =>
                    record.data['relationType'] == 'taskGroupMember' &&
                    record.data['groupId'] == affectedGroupId &&
                    record.data['active'] != false &&
                    !detachedRelationIds.contains(record.id),
              )
              .toList()
            ..sort(
              (a, b) => ((a.data['position'] as num?)?.toInt() ?? 0).compareTo(
                (b.data['position'] as num?)?.toInt() ?? 0,
              ),
            );
      for (var index = 0; index < remaining.length; index++) {
        updates.add(
          remaining[index].copyWith(
            data: {...remaining[index].data, 'position': index},
          ),
        );
      }
    }
    if (updates.isEmpty) {
      return BatchOperationResult(succeeded: succeeded, failures: failures);
    }
    try {
      await _saveRecordsBatch(updates);
      return BatchOperationResult(succeeded: succeeded, failures: failures);
    } catch (error) {
      final failuresById = {
        for (final failure in failures) failure.recordId: failure,
      };
      for (final task in tasks) {
        failuresById.putIfAbsent(
          task.id,
          () => BatchOperationFailure(recordId: task.id, message: '$error'),
        );
      }
      return BatchOperationResult(
        succeeded: 0,
        failures: failuresById.values.toList(growable: false),
      );
    }
  }

  Future<void> purgeForegroundEvents({bool all = false}) async {
    final cutoff = currentTime().subtract(const Duration(days: 30));
    for (final event in foregroundEvents.where(
      (record) => all || record.createdAt.isBefore(cutoff),
    )) {
      await permanentlyDelete(event);
    }
  }

  Future<void> setReviewReminder({
    required ReviewPeriodType type,
    required bool enabled,
    String? time,
  }) async {
    if (type == ReviewPeriodType.yearly) {
      throw const FormatException('旧年回顾不再提供提醒。');
    }
    final normalized = time ?? _reviewReminderTimes[type] ?? '20:00';
    if (!RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(normalized)) {
      throw const FormatException('提醒时间必须为 HH:mm。');
    }
    _reviewReminderEnabled[type] = enabled;
    _reviewReminderTimes[type] = normalized;
    await database.writeMetadata(
      'review_reminder_${type.name}_enabled',
      '$enabled',
    );
    await database.writeMetadata(
      'review_reminder_${type.name}_time',
      normalized,
    );
    await scheduleReviewReminders();
    notifyListeners();
  }

  Future<void> scheduleReviewReminders() async {
    if (!notificationService.supportsSystemNotifications) return;
    await notificationService.cancel(
      stableNotificationId('period-review:${ReviewPeriodType.yearly.name}'),
    );
    for (final type in activeReviewPeriodTypes) {
      final id = stableNotificationId('period-review:${type.name}');
      await notificationService.cancel(id);
      if (!reviewReminderEnabled(type)) continue;
      final when = _nextReviewReminder(type, currentTime());
      await notificationService.scheduleTaskReminder(
        id: id,
        title: '${_reviewLabel(type)}提醒',
        body: '请记录本期间的事实、阻塞和下一步。',
        when: when,
      );
    }
    await _scheduleOverdueReviewReminder();
  }

  Future<void> _scheduleOverdueReviewReminder() async {
    final id = stableNotificationId('period-review:overdue');
    await notificationService.cancel(id);
    final now = currentTime();
    final pendingEnds = notes
        .map((record) {
          if (record.data['recordType'] != 'periodReview' ||
              record.data['periodType'] == ReviewPeriodType.yearly.name ||
              record.data['draft'] != true ||
              record.data['reviewSkipped'] == true) {
            return null;
          }
          return DateTime.tryParse(
            record.data['periodEnd']?.toString() ?? '',
          )?.toLocal();
        })
        .whereType<DateTime>()
        .toList();
    if (pendingEnds.isEmpty) return;
    pendingEnds.sort();
    final end = pendingEnds.first;
    var firstAt = DateTime(end.year, end.month, end.day, 20);
    final todayAt20 = DateTime(now.year, now.month, now.day, 20);
    if (firstAt.isBefore(todayAt20)) firstAt = todayAt20;
    if (!firstAt.isAfter(now)) firstAt = firstAt.add(const Duration(days: 1));
    await notificationService.scheduleDailyReminder(
      id: id,
      title: '逾期回顾提醒',
      body: '仍有未完成的回顾草稿，请完成或明确跳过。',
      firstAt: firstAt,
    );
  }

  DateTime _nextReviewReminder(ReviewPeriodType type, DateTime now) {
    final parts = reviewReminderTime(type).split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    DateTime candidate;
    switch (type) {
      case ReviewPeriodType.daily:
        candidate = DateTime(now.year, now.month, now.day, hour, minute);
        if (!candidate.isAfter(now)) {
          candidate = candidate.add(const Duration(days: 1));
        }
      case ReviewPeriodType.weekly:
        candidate = DateTime(
          now.year,
          now.month,
          now.day,
          hour,
          minute,
        ).add(Duration(days: DateTime.sunday - now.weekday));
        if (!candidate.isAfter(now)) {
          candidate = candidate.add(const Duration(days: 7));
        }
      case ReviewPeriodType.monthly:
        candidate = DateTime(now.year, now.month + 1, 0, hour, minute);
        if (!candidate.isAfter(now)) {
          candidate = DateTime(now.year, now.month + 2, 0, hour, minute);
        }
      case ReviewPeriodType.yearly:
        candidate = DateTime(now.year, 12, 31, hour, minute);
        if (!candidate.isAfter(now)) {
          candidate = DateTime(now.year + 1, 12, 31, hour, minute);
        }
    }
    return candidate;
  }

  String _reviewLabel(ReviewPeriodType type) => switch (type) {
    ReviewPeriodType.daily => '日回顾',
    ReviewPeriodType.weekly => '周回顾',
    ReviewPeriodType.monthly => '月回顾',
    ReviewPeriodType.yearly => '年回顾',
  };

  Future<void> settleTask(
    WorkspaceRecord task, {
    required String status,
    String reason = '',
    String resultNote = '',
    String resultLink = '',
  }) async {
    if (!const {
      WorkStatus.done,
      WorkStatus.failed,
      WorkStatus.skipped,
    }.contains(status)) {
      throw const FormatException('不支持的任务结算状态。');
    }
    if (status == WorkStatus.failed && reason.trim().isEmpty) {
      throw const FormatException('将任务标记为失败时必须填写原因。');
    }
    final normalizedLink = resultLink.trim();
    final uri = Uri.tryParse(normalizedLink);
    if (normalizedLink.isNotEmpty &&
        (uri == null ||
            !const {'http', 'https'}.contains(uri.scheme) ||
            uri.host.isEmpty)) {
      throw const FormatException('结果链接必须是有效的 http:// 或 https:// 地址。');
    }
    final now = currentTime();
    final current = _latestRecord(task);
    await updateRecord(
      current.copyWith(
        status: status,
        data: {
          ...current.data,
          'settledAt': now.toUtc().toIso8601String(),
          if (status == WorkStatus.done)
            'completedAt': now.toUtc().toIso8601String(),
          if (reason.trim().isNotEmpty) 'settlementReason': reason.trim(),
          if (resultNote.trim().isNotEmpty) 'resultNote': resultNote.trim(),
          if (normalizedLink.isNotEmpty) 'resultLink': normalizedLink,
          'overduePending': false,
        },
      ),
    );
    if (status == WorkStatus.done) {
      await _handleTaskRsipLinks(
        current.id,
        RsipTaskChainKind.unit,
        RsipTaskLinkTriggerEvent.taskCompleted,
      );
      final definitionId = current.data['definitionId']?.toString();
      if (definitionId != null && definitionId != current.id) {
        await _handleTaskRsipLinks(
          definitionId,
          RsipTaskChainKind.unit,
          RsipTaskLinkTriggerEvent.taskCompleted,
        );
      }
    } else if (status == WorkStatus.failed) {
      await _handleTaskRsipLinks(
        current.id,
        RsipTaskChainKind.unit,
        RsipTaskLinkTriggerEvent.taskInterrupted,
      );
      final definitionId = current.data['definitionId']?.toString();
      if (definitionId != null && definitionId != current.id) {
        await _handleTaskRsipLinks(
          definitionId,
          RsipTaskChainKind.unit,
          RsipTaskLinkTriggerEvent.taskInterrupted,
        );
      }
    }
  }

  Future<void> correctSettledTask({
    required WorkspaceRecord task,
    required String status,
    required String reason,
    String actor = 'local-user',
    String failureReason = '',
    String resultNote = '',
  }) async {
    if (reason.trim().isEmpty) {
      throw const FormatException('留痕更正必须填写原因。');
    }
    if (!const {
      WorkStatus.done,
      WorkStatus.failed,
      WorkStatus.skipped,
    }.contains(status)) {
      throw const FormatException('留痕更正仅支持完成、失败或跳过。');
    }
    final current = _latestRecord(task);
    if (!WorkStatus.terminal.contains(current.status)) {
      throw const FormatException('只有已结算任务可以留痕更正。');
    }
    final snapshot = protocolEvents
        .where((record) => record.data['recordType'] == 'dayCloseSnapshot')
        .where((record) {
          final facts = record.data['taskFacts'] as List<dynamic>? ?? const [];
          return facts.whereType<Map>().any(
            (fact) => fact['id']?.toString() == current.id,
          );
        })
        .firstOrNull;
    if (snapshot == null) {
      throw const FormatException('任务尚未进入每日收尾快照，不能使用留痕更正。');
    }
    if (status == WorkStatus.failed &&
        failureReason.trim().isEmpty &&
        reason.trim().isEmpty) {
      throw const FormatException('更正为失败时必须填写失败原因。');
    }
    final correctedAt = currentTime();
    final event = WorkspaceRecord.create(
      kind: RecordKind.protocolEvent,
      title: current.title,
      parentId: current.id,
      scheduledFor: correctedAt,
      status: WorkStatus.done,
      data: {
        'recordType': 'taskCorrection',
        'taskId': current.id,
        'dayCloseSnapshotId': snapshot.id,
        'reason': reason.trim(),
        'actor': actor.trim().isEmpty ? 'local-user' : actor.trim(),
        'beforeStatus': current.status,
        'afterStatus': status,
        'beforeSettlementReason': current.data['settlementReason'],
        if (status == WorkStatus.failed)
          'afterSettlementReason': failureReason.trim().isEmpty
              ? reason.trim()
              : failureReason.trim(),
        if (resultNote.trim().isNotEmpty) 'resultNote': resultNote.trim(),
      },
    );
    await addRecord(event);
    final data = <String, dynamic>{
      ...current.data,
      'correctedAt': correctedAt.toUtc().toIso8601String(),
      'correctionReason': reason.trim(),
      'correctionActor': actor.trim().isEmpty ? 'local-user' : actor.trim(),
      'correctionEventId': event.id,
      'correctionCount':
          ((current.data['correctionCount'] as num?)?.toInt() ?? 0) + 1,
      if (resultNote.trim().isNotEmpty) 'resultNote': resultNote.trim(),
    };
    if (status == WorkStatus.failed) {
      data['settlementReason'] = failureReason.trim().isEmpty
          ? reason.trim()
          : failureReason.trim();
      data.remove('completedAt');
    } else if (status == WorkStatus.done) {
      data.remove('settlementReason');
      data['completedAt'] = correctedAt.toUtc().toIso8601String();
    } else {
      data.remove('completedAt');
    }
    await updateRecord(current.copyWith(status: status, data: data));
  }

  Future<WorkspaceRecord> rescheduleTaskInstance(
    WorkspaceRecord task,
    DateTime targetDate, {
    String reason = '',
  }) async {
    final now = currentTime();
    final current = _latestRecord(task);
    final definitionId = current.data['definitionId']?.toString() ?? current.id;
    final replacement = WorkspaceRecord.create(
      kind: RecordKind.task,
      title: current.title,
      body: current.body,
      status: WorkStatus.todo,
      scheduledFor: targetDate,
      dueAt: current.dueAt == null
          ? null
          : DateTime(
              targetDate.year,
              targetDate.month,
              targetDate.day,
              current.dueAt!.hour,
              current.dueAt!.minute,
            ),
      projectId: current.projectId,
      parentId: current.parentId,
      tags: current.tags,
      data: {
        ...current.data,
        'recordType': 'taskInstance',
        'definitionId': definitionId,
        'occurrenceKey': growthService.dayKey(targetDate),
        'rescheduledFromId': current.id,
        'completedAt': null,
        'settledAt': null,
        'overduePending': false,
      },
    );
    await updateRecord(
      current.copyWith(
        status: WorkStatus.rescheduled,
        data: {
          ...current.data,
          'settledAt': now.toUtc().toIso8601String(),
          'rescheduledToId': replacement.id,
          'rescheduledTo': targetDate.toUtc().toIso8601String(),
          if (reason.trim().isNotEmpty) 'settlementReason': reason.trim(),
          'overduePending': false,
        },
      ),
    );
    await addRecord(replacement);
    return replacement;
  }

  Future<void> scheduleTask(WorkspaceRecord task, DateTime date) async {
    final updated = task.copyWith(
      scheduledFor: date,
      status: task.status == WorkStatus.inbox ? WorkStatus.todo : task.status,
    );
    await updateRecord(updated);
    final reminder = updated.data['reminderAt']?.toString();
    final reminderAt = reminder == null
        ? null
        : DateTime.tryParse(reminder)?.toLocal();
    if (reminderAt != null) {
      await notificationService.scheduleTaskReminder(
        id: _notificationId(updated.id),
        title: updated.title,
        when: reminderAt,
      );
    }
  }

  Future<void> startCtdpReservation(WorkspaceRecord task) async {
    final current = _latestRecord(task);
    if (!current.hasCtdpProtocol) return;
    final now = currentTime();
    final deadline = now.add(Duration(minutes: current.ctdpDelayMinutes));
    await updateRecord(
      current.copyWith(
        data: {
          ...current.data,
          'ctdpReservationPending': true,
          'ctdpReservationAt': now.toUtc().toIso8601String(),
          'ctdpReservationDueAt': deadline.toUtc().toIso8601String(),
        },
      ),
    );
    await _addProtocolEvent(
      protocol: 'ctdp',
      action: 'reservation_started',
      subject: current,
      data: {'dueAt': deadline.toUtc().toIso8601String()},
    );
    await notificationService.scheduleTaskReminder(
      id: _notificationId('ctdp:${current.id}'),
      title: 'CTDP 预约到点：${current.title}',
      body: current.ctdpAuxSignal.isEmpty
          ? '执行触发标志：${current.ctdpTrigger}'
          : '辅助信号：${current.ctdpAuxSignal}',
      when: deadline,
    );
  }

  Future<void> confirmCtdpTrigger(WorkspaceRecord task) async {
    final current = _latestRecord(task);
    if (!current.hasCtdpProtocol) return;
    if (!current.ctdpReservationPending) {
      throw const FormatException('当前没有待确认的 CTDP 预约');
    }
    final deadline = DateTime.tryParse(
      current.data['ctdpReservationDueAt']?.toString() ?? '',
    )?.toLocal();
    if (deadline != null && currentTime().isAfter(deadline)) {
      await updateRecord(
        current.copyWith(
          data: {
            ...current.data,
            'ctdpReservationPending': false,
            'ctdpChainCount': 0,
            'ctdpAuxChainCount': 0,
            'ctdpLastFailureAt': currentTime().toUtc().toIso8601String(),
            'ctdpFailureReason': '预约超时，辅助链重置',
          },
        ),
      );
      throw const FormatException('预约已超时，辅助链已重置');
    }
    await updateRecord(
      current.copyWith(
        data: {
          ...current.data,
          'ctdpReservationPending': false,
          'ctdpLastTriggeredAt': currentTime().toUtc().toIso8601String(),
          'ctdpAuxChainCount': current.ctdpAuxChainCount + 1,
          'ctdpReservationCount': current.ctdpReservationCount + 1,
        },
      ),
    );
    await _addProtocolEvent(
      protocol: 'ctdp',
      action: 'reservation_confirmed',
      subject: current,
    );
  }

  Future<void> failCtdpAuxiliary(
    WorkspaceRecord task, {
    String reason = '预约或辅助条件未完成，辅助链从 #1 重新开始',
  }) async {
    final current = _latestRecord(task);
    if (!current.hasCtdpProtocol) return;
    await notificationService.cancel(_notificationId('ctdp:${current.id}'));
    await updateRecord(
      current.copyWith(
        data: {
          ...current.data,
          'ctdpReservationPending': false,
          'ctdpAuxChainCount': 0,
          'ctdpAuxFailures': current.ctdpAuxFailures + 1,
          'ctdpLastAuxFailureAt': currentTime().toUtc().toIso8601String(),
          'ctdpAuxFailureReason': reason.trim(),
        },
      ),
    );
    await _addProtocolEvent(
      protocol: 'ctdp',
      action: 'auxiliary_failed',
      subject: current,
      successful: false,
      data: {'reason': reason.trim()},
    );
  }

  Future<void> failCtdpTask(
    WorkspaceRecord task, {
    String reason = '本次任务未完成，主链从 #1 重新开始',
  }) async {
    final current = _latestRecord(task);
    if (!current.hasCtdpProtocol) return;
    await updateRecord(
      current.copyWith(
        data: {
          ...current.data,
          'ctdpReservationPending': false,
          'ctdpChainCount': 0,
          'ctdpSessionActive': false,
          'ctdpTotalFailures': current.ctdpTotalFailures + 1,
          'ctdpLastFailureAt': currentTime().toUtc().toIso8601String(),
          'ctdpFailureReason': reason.trim().isEmpty
              ? '本次任务未完成，主链从 #1 重新开始'
              : reason.trim(),
        },
      ),
    );
    await _addProtocolEvent(
      protocol: 'ctdp',
      action: 'main_failed',
      subject: current,
      successful: false,
      data: {'reason': reason.trim()},
    );
  }

  Future<void> recordCtdpPrecedent(
    WorkspaceRecord task,
    String precedent,
  ) async {
    final value = precedent.trim();
    final current = _latestRecord(task);
    if (!current.hasCtdpProtocol || value.isEmpty) return;
    final existing =
        (current.data['ctdpPrecedents'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .toList();
    if (!existing.contains(value)) existing.add(value);
    await updateRecord(
      current.copyWith(
        data: {
          ...current.data,
          'ctdpPrecedents': existing,
          'ctdpLastPrecedentAt': currentTime().toUtc().toIso8601String(),
        },
      ),
    );
    final duplicate = exceptionRules.any(
      (rule) =>
          rule.data['protocol'] == 'ctdp' &&
          rule.parentId == current.id &&
          rule.title == value &&
          rule.data['ruleType'] == 'interruption' &&
          rule.data['archived'] != true,
    );
    if (!duplicate) {
      await createExceptionRule(
        name: value,
        description: '由任务中“下必为例”操作创建',
        ruleType: 'interruption',
        scope: 'chain',
        chainId: current.id,
      );
    }
  }

  Future<WorkspaceRecord> createExceptionRule({
    required String name,
    required String description,
    required String ruleType,
    String scope = 'chain',
    String? chainId,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw const FormatException('判例名称不能为空');
    if (!const {
      'pause',
      'early_completion',
      'interruption',
    }.contains(ruleType)) {
      throw const FormatException('未知的判例类型');
    }
    if (scope == 'chain' && chainId == null) {
      throw const FormatException('任务级判例必须关联 CTDP 任务');
    }
    final record = WorkspaceRecord.create(
      kind: RecordKind.exceptionRule,
      title: trimmed,
      body: description.trim(),
      parentId: scope == 'chain' ? chainId : null,
      data: {
        'protocol': 'ctdp',
        'ruleType': ruleType,
        'scope': scope,
        'usageCount': 0,
        'archived': false,
      },
    );
    await addRecord(record);
    return record;
  }

  List<WorkspaceRecord> exceptionRulesFor(
    WorkspaceRecord task, {
    String? ruleType,
  }) {
    return exceptionRules
        .where((rule) {
          if (rule.data['archived'] == true) return false;
          if (ruleType != null && rule.data['ruleType'] != ruleType) {
            return false;
          }
          return rule.data['scope'] == 'global' || rule.parentId == task.id;
        })
        .toList(growable: false);
  }

  Future<void> useExceptionRule(
    WorkspaceRecord rule,
    WorkspaceRecord task, {
    required String action,
    Duration? elapsed,
    Duration? remaining,
  }) async {
    final currentRule = _latestRecord(rule);
    if (currentRule.kind != RecordKind.exceptionRule ||
        currentRule.data['archived'] == true) {
      throw const FormatException('该判例不可用');
    }
    await updateRecord(
      currentRule.copyWith(
        data: {
          ...currentRule.data,
          'usageCount':
              ((currentRule.data['usageCount'] as num?)?.toInt() ?? 0) + 1,
          'lastUsedAt': currentTime().toUtc().toIso8601String(),
        },
      ),
    );
    await _addProtocolEvent(
      protocol: 'ctdp',
      action: action,
      subject: task,
      data: {
        'ruleId': currentRule.id,
        'ruleName': currentRule.title,
        if (elapsed != null) 'elapsedSeconds': elapsed.inSeconds,
        if (remaining != null) 'remainingSeconds': remaining.inSeconds,
      },
    );
  }

  Future<void> archiveExceptionRule(WorkspaceRecord rule, bool archived) {
    return updateRecord(rule.withData('archived', archived));
  }

  Future<void> startCtdpGroup(WorkspaceRecord group) async {
    final current = _latestRecord(group);
    if (!current.hasCtdpProtocol || !current.ctdpIsGroup) return;
    final now = currentTime();
    final hours = current.ctdpGroupTimeLimitHours;
    await updateRecord(
      current.copyWith(
        data: {
          ...current.data,
          'ctdpGroupStartedAt': now.toUtc().toIso8601String(),
          if (hours > 0)
            'ctdpGroupExpiresAt': now
                .add(Duration(hours: hours))
                .toUtc()
                .toIso8601String(),
        },
      ),
    );
    await _addProtocolEvent(
      protocol: 'ctdp',
      action: 'group_started',
      subject: current,
    );
  }

  List<WorkspaceRecord> ctdpChildren(String groupId) => ctdpTasks
      .where((task) => task.parentId == groupId)
      .toList(growable: false);

  Future<WorkspaceRecord> duplicateCtdpTask(WorkspaceRecord task) async {
    final current = _latestRecord(task);
    if (!current.hasCtdpProtocol) {
      throw const FormatException('只能复制 CTDP 任务');
    }
    final copy = WorkspaceRecord.create(
      kind: RecordKind.task,
      title: '${current.title}（副本）',
      body: current.body,
      status: WorkStatus.todo,
      scheduledFor: current.scheduledFor,
      dueAt: current.dueAt,
      projectId: current.projectId,
      parentId: current.parentId,
      tags: current.tags,
      data: {
        ...current.data,
        'ctdpChainCount': 0,
        'ctdpAuxChainCount': 0,
        'ctdpReservationCount': 0,
        'ctdpTotalCompletions': 0,
        'ctdpTotalFailures': 0,
        'ctdpAuxFailures': 0,
        'ctdpReservationPending': false,
        'ctdpSessionActive': false,
        'ctdpGroupStartedAt': null,
        'ctdpGroupExpiresAt': null,
      },
    );
    await addRecord(copy);
    return copy;
  }

  Future<void> completeCtdpRound(
    WorkspaceRecord task,
    Duration duration, {
    String description = '',
    String notes = '',
    bool earlyCompletion = false,
  }) async {
    final current = _latestRecord(task);
    if (!current.hasCtdpProtocol || current.ctdpIsGroup) return;
    if (duration.inSeconds < 1) return;
    if (current.ctdpMinimumMinutes > 0 &&
        duration < Duration(minutes: current.ctdpMinimumMinutes) &&
        !earlyCompletion) {
      throw FormatException('至少执行 ${current.ctdpMinimumMinutes} 分钟后才能完成');
    }
    final now = currentTime();
    await updateRecord(
      current.copyWith(
        data: {
          ...current.data,
          'ctdpReservationPending': false,
          'ctdpSessionActive': false,
          'ctdpChainCount': current.ctdpChainCount + 1,
          'ctdpTotalCompletions': current.ctdpTotalCompletions + 1,
          'ctdpLastCompletedAt': now.toUtc().toIso8601String(),
          'actualMinutes': current.actualMinutes + max(1, duration.inMinutes),
        },
      ),
    );
    await _addProtocolEvent(
      protocol: 'ctdp',
      action: earlyCompletion ? 'round_completed_early' : 'round_completed',
      subject: current,
      data: {
        'seconds': duration.inSeconds,
        'description': description.trim(),
        'notes': notes.trim(),
      },
    );
    await _settleCtdpParentGroup(current);
  }

  Future<void> _settleCtdpParentGroup(WorkspaceRecord task) async {
    final parentId = task.parentId;
    if (parentId == null) return;
    final group = ctdpTasks.where((item) => item.id == parentId).firstOrNull;
    if (group == null || !group.ctdpIsGroup) return;
    final startedAt = DateTime.tryParse(
      group.data['ctdpGroupStartedAt']?.toString() ?? '',
    )?.toLocal();
    if (startedAt == null) return;
    final children = ctdpChildren(group.id);
    if (children.isEmpty ||
        children.any((child) {
          final completedAt = DateTime.tryParse(
            child.data['ctdpLastCompletedAt']?.toString() ?? '',
          )?.toLocal();
          return completedAt == null || completedAt.isBefore(startedAt);
        })) {
      return;
    }
    await updateRecord(
      group.copyWith(
        data: {
          ...group.data,
          'ctdpChainCount': group.ctdpChainCount + 1,
          'ctdpTotalCompletions': group.ctdpTotalCompletions + 1,
          'ctdpLastCompletedAt': currentTime().toUtc().toIso8601String(),
          'ctdpGroupStartedAt': null,
          'ctdpGroupExpiresAt': null,
        },
      ),
    );
    await _addProtocolEvent(
      protocol: 'ctdp',
      action: 'group_completed',
      subject: group,
    );
  }

  Future<void> setFocusTask(WorkspaceRecord task, bool selected) async {
    if (selected && !task.isFocus && focusTasks.length >= 3) {
      throw const FormatException('今日重点最多保留三项。');
    }
    await updateRecord(task.withData('isFocus', selected));
  }

  Future<void> createTimeBlock({
    required WorkspaceRecord task,
    required DateTime start,
    required int minutes,
  }) async {
    final block = WorkspaceRecord.create(
      kind: RecordKind.timeBlock,
      title: task.title,
      scheduledFor: start,
      parentId: task.id,
      projectId: task.projectId,
      data: {'durationMinutes': minutes.clamp(5, 720)},
    );
    await addRecord(block);
    await scheduleTask(task, start);
  }

  Future<void> updateTimeBlock({
    required WorkspaceRecord block,
    required DateTime start,
    required int minutes,
  }) async {
    if (block.kind != RecordKind.timeBlock) return;
    await updateRecord(
      block.copyWith(
        scheduledFor: start,
        data: {...block.data, 'durationMinutes': minutes.clamp(5, 720)},
      ),
    );
  }

  Future<void> completeFocusSession(
    WorkspaceRecord? task,
    Duration duration,
    FocusMode mode, {
    String? sessionTitle,
    String description = '',
    String notes = '',
    bool earlyCompletion = false,
  }) async {
    if (duration.inSeconds < 1) return;
    await addRecord(
      WorkspaceRecord.create(
        kind: RecordKind.focusSession,
        title: sessionTitle ?? task?.title ?? '临时专注',
        parentId: task?.id,
        projectId: task?.projectId,
        scheduledFor: currentTime(),
        status: WorkStatus.done,
        data: {
          'seconds': duration.inSeconds,
          'mode': mode.name,
          'description': description.trim(),
          'notes': notes.trim(),
          'earlyCompletion': earlyCompletion,
        },
      ),
    );
    if (task == null) return;
    if (task.hasCtdpProtocol) {
      await completeCtdpRound(
        task,
        duration,
        description: description,
        notes: notes,
        earlyCompletion: earlyCompletion,
      );
    } else {
      final current = _latestRecord(task);
      await updateRecord(
        current.withData(
          'actualMinutes',
          current.actualMinutes + max(1, duration.inMinutes),
        ),
      );
    }
    await _syncFocusXp(task.id);
  }

  Future<WorkspaceRecord> saveDiary({
    required DateTime day,
    required String title,
    required String body,
    String completedToday = '',
    String blockers = '',
    String tomorrowPlan = '',
    int? mood,
    String? projectId,
  }) async {
    final existing = diaryForDay(day);
    final data = {
      'completedToday': completedToday.trim(),
      'blockers': blockers.trim(),
      'tomorrowPlan': tomorrowPlan.trim(),
      if (mood != null) 'mood': mood.clamp(1, 5),
    };
    final record = existing == null
        ? WorkspaceRecord.create(
            kind: RecordKind.diary,
            title: title.trim().isEmpty ? '今日回顾' : title,
            body: body,
            scheduledFor: startOfDay(day),
            projectId: projectId,
            data: data,
          )
        : existing.copyWith(
            title: title.trim().isEmpty ? existing.title : title,
            body: body,
            projectId: projectId,
            data: data,
          );
    await updateRecord(record);
    return record;
  }

  WorkspaceRecord? reviewForPeriod(ReviewPeriodType type, String periodKey) {
    return notes.where((record) {
      return record.data['recordType'] == 'periodReview' &&
          record.data['periodType'] == type.name &&
          record.data['periodKey'] == periodKey;
    }).firstOrNull;
  }

  Future<WorkspaceRecord> savePeriodReview({
    required ReviewPeriodType type,
    required String periodKey,
    required DateTime periodStart,
    required DateTime periodEnd,
    required String body,
    bool refreshSnapshot = false,
    String snapshotRefreshReason = '',
    Iterable<String>? relatedTaskIds,
    Iterable<String>? relatedProjectIds,
  }) async {
    final existing = reviewForPeriod(type, periodKey);
    if (type == ReviewPeriodType.yearly && existing == null) {
      throw const FormatException('年回顾仅用于读取旧数据，不能新建。');
    }
    final versions = existing == null
        ? <Map<String, dynamic>>[]
        : (existing.data['versions'] as List<dynamic>? ?? const [])
              .map((value) => Map<String, dynamic>.from(value as Map))
              .toList();
    if (existing != null && existing.body != body) {
      versions.add({
        'body': existing.body,
        'savedAt': existing.updatedAt.toUtc().toIso8601String(),
      });
      if (versions.length > 10) {
        versions.removeRange(0, versions.length - 10);
      }
    }
    final liveSnapshot = reviewSnapshotForPeriod(
      type: type,
      periodKey: periodKey,
      periodStart: periodStart,
      periodEnd: periodEnd,
    ).toJson();
    final snapshot = existing == null || refreshSnapshot
        ? liveSnapshot
        : Map<String, dynamic>.from(
            existing.data['snapshot'] as Map? ?? liveSnapshot,
          );
    final label = switch (type) {
      ReviewPeriodType.daily => '日回顾',
      ReviewPeriodType.weekly => '周回顾',
      ReviewPeriodType.monthly => '月回顾',
      ReviewPeriodType.yearly => '年回顾',
    };
    final refreshHistory =
        (existing?.data['snapshotRefreshHistory'] as List<dynamic>? ?? const [])
            .map((value) => Map<String, dynamic>.from(value as Map))
            .toList();
    if (refreshSnapshot && existing != null) {
      if (snapshotRefreshReason.trim().isEmpty) {
        throw const FormatException('刷新事实快照必须填写原因。');
      }
      refreshHistory.add({
        'refreshedAt': currentTime().toUtc().toIso8601String(),
        'reason': snapshotRefreshReason.trim(),
        'before': _reviewSnapshotSummary(existing.data['snapshot']),
        'after': _reviewSnapshotSummary(liveSnapshot),
      });
    }
    final data = {
      ...?existing?.data,
      'recordType': 'periodReview',
      'reviewSchemaVersion': 3,
      'periodType': type.name,
      'periodKey': periodKey,
      'periodStart': periodStart.toUtc().toIso8601String(),
      'periodEnd': periodEnd.toUtc().toIso8601String(),
      'snapshot': snapshot,
      'versions': versions,
      'snapshotRefreshHistory': refreshHistory,
      if (relatedTaskIds != null)
        'relatedTaskIds': relatedTaskIds.toSet().toList(),
      if (relatedProjectIds != null)
        'relatedProjectIds': relatedProjectIds.toSet().toList(),
      'draft': false,
      'reviewSkipped': false,
    };
    final record = existing == null
        ? WorkspaceRecord.create(
            kind: RecordKind.note,
            title: '$label · $periodKey',
            body: body,
            scheduledFor: periodStart,
            tags: [label],
            data: data,
          )
        : existing.copyWith(body: body, data: data);
    await updateRecord(record);
    await _scheduleOverdueReviewReminder();
    return record;
  }

  Future<void> skipPeriodReview(
    WorkspaceRecord review, {
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      throw const FormatException('跳过回顾必须填写原因。');
    }
    await updateRecord(
      _latestRecord(review).copyWith(
        data: {
          ...review.data,
          'draft': false,
          'reviewSkipped': true,
          'reviewSkipReason': reason.trim(),
          'reviewSkippedAt': currentTime().toUtc().toIso8601String(),
        },
      ),
    );
    await _scheduleOverdueReviewReminder();
  }

  ReviewSnapshot reviewSnapshotForPeriod({
    required ReviewPeriodType type,
    required String periodKey,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) {
    final linkedTasks = tasks.where((task) {
      final settledAt = DateTime.tryParse(
        task.data['settledAt']?.toString() ??
            task.data['completedAt']?.toString() ??
            '',
      )?.toLocal();
      final scheduledAt = task.scheduledFor;
      bool inPeriod(DateTime? value) =>
          value != null &&
          !value.isBefore(periodStart) &&
          value.isBefore(periodEnd);
      return inPeriod(settledAt) || inPeriod(scheduledAt);
    }).toList()..sort(_taskOrder);
    final focusSessions = recordsOf(RecordKind.focusSession).where((session) {
      final timestamp = session.scheduledFor ?? session.createdAt;
      return !timestamp.isBefore(periodStart) && timestamp.isBefore(periodEnd);
    }).toList();
    final projectIds = <String>{};
    for (final task in linkedTasks) {
      if (task.projectId != null) projectIds.add(task.projectId!);
      projectIds.addAll(
        projectsForTaskIncludingTrash(task).map((project) => project.id),
      );
    }
    projectIds.addAll(
      focusSessions.map((session) => session.projectId).whereType<String>(),
    );
    final taskFacts = linkedTasks
        .map((task) {
          final context = taskContextSummary(task);
          return ReviewTaskFact(
            taskId: task.id,
            title: task.title,
            status: task.status,
            projectTitles: context.projectTitles,
            groupId: context.groupId,
            groupTitle: context.groupTitle,
            groupMode: context.groupMode,
            chainPosition: context.chainPosition,
            completedAt: context.settledAt,
            result: context.result ?? '',
            failureReason: context.failureReason ?? '',
            skipReason: context.skipReason ?? '',
            rescheduledTo: context.rescheduledTo,
            rescheduledFromId: context.rescheduledFromId,
          );
        })
        .toList(growable: false);
    final taskIds = taskFacts.map((fact) => fact.taskId).toSet();
    final groupFacts = taskGroups
        .map((group) {
          final memberIds = groupMembers(
            group.id,
          ).map((member) => member.id).where(taskIds.contains).toList();
          if (memberIds.isEmpty) return null;
          return ReviewGroupFact(
            groupId: group.id,
            title: group.title,
            mode: group.data['mode']?.toString() ?? 'parallel',
            memberTaskIds: memberIds,
          );
        })
        .whereType<ReviewGroupFact>()
        .toList(growable: false);
    return ReviewSnapshot(
      period: ReviewPeriod(
        type: type,
        key: periodKey,
        start: periodStart,
        end: periodEnd,
      ),
      capturedAt: currentTime(),
      taskFacts: taskFacts,
      groupFacts: groupFacts,
      focusSessionIds: focusSessions.map((session) => session.id).toList(),
      projectIds: projectIds.toList()..sort(),
      focusSeconds: focusSessions.fold<int>(
        0,
        (sum, session) =>
            sum + ((session.data['seconds'] as num?)?.toInt() ?? 0),
      ),
    );
  }

  bool reviewStatisticsChanged(WorkspaceRecord review) {
    final start = DateTime.tryParse(
      review.data['periodStart']?.toString() ?? '',
    )?.toLocal();
    final end = DateTime.tryParse(
      review.data['periodEnd']?.toString() ?? '',
    )?.toLocal();
    final stored = review.data['snapshot'];
    if (start == null || end == null || stored is! Map) return false;
    final type = ReviewPeriodType.values.firstWhere(
      (value) => value.name == review.data['periodType'],
      orElse: () => ReviewPeriodType.daily,
    );
    final live = reviewSnapshotForPeriod(
      type: type,
      periodKey: review.data['periodKey']?.toString() ?? '',
      periodStart: start,
      periodEnd: end,
    ).toJson();
    for (final key in const [
      'taskIds',
      'focusSessionIds',
      'projectIds',
      'taskFacts',
      'focusSeconds',
      'completed',
      'failed',
      'skipped',
      'rescheduled',
    ]) {
      if (jsonEncode(stored[key]) != jsonEncode(live[key])) return true;
    }
    return false;
  }

  Future<WorkspaceRecord> refreshPeriodReviewSnapshot(
    WorkspaceRecord review, {
    required String reason,
  }) {
    final type = ReviewPeriodType.values.firstWhere(
      (value) => value.name == review.data['periodType'],
    );
    return savePeriodReview(
      type: type,
      periodKey: review.data['periodKey']?.toString() ?? '',
      periodStart: DateTime.parse(
        review.data['periodStart'] as String,
      ).toLocal(),
      periodEnd: DateTime.parse(review.data['periodEnd'] as String).toLocal(),
      body: review.body,
      refreshSnapshot: true,
      snapshotRefreshReason: reason,
    );
  }

  Map<String, dynamic> _reviewSnapshotSummary(Object? value) {
    final snapshot = value is Map
        ? Map<String, dynamic>.from(value)
        : const <String, dynamic>{};
    return {
      for (final key in const [
        'completed',
        'failed',
        'skipped',
        'rescheduled',
        'focusSeconds',
      ])
        key: snapshot[key] ?? 0,
      'taskCount': (snapshot['taskIds'] as List<dynamic>? ?? const []).length,
      'groupCount':
          (snapshot['groupFacts'] as List<dynamic>? ?? const []).length,
    };
  }

  Future<void> logHabit(
    WorkspaceRecord habit,
    DateTime day,
    String status,
  ) async {
    var currentHabit = _latestRecord(habit);
    final existing = habitLogForDay(habit.id, day);
    final log = existing == null
        ? WorkspaceRecord.create(
            kind: RecordKind.habitLog,
            title: habit.title,
            parentId: habit.id,
            scheduledFor: startOfDay(day),
            status: status,
          )
        : existing.copyWith(status: status);
    await updateRecord(log);
    if (currentHabit.hasRsipProtocol) {
      if (!currentHabit.rsipActive) return;
      final rsipStatus = status == WorkStatus.done
          ? RsipExecutionStatus.executed
          : status == WorkStatus.failed || status == WorkStatus.cancelled
          ? RsipExecutionStatus.violated
          : RsipExecutionStatus.skipped;
      await settleRsipNode(
        currentHabit,
        status: rsipStatus,
        reason: rsipStatus == RsipExecutionStatus.violated
            ? '由兼容习惯入口标记为未完成'
            : '',
        correctionReason: existing != null && existing.status != status
            ? '由兼容习惯入口更正'
            : '',
        logicalDay: day,
      );
      currentHabit = _latestRecord(currentHabit);
    }
    final plan = todayPlan;
    if (plan != null && plannedHabitIds.contains(habit.id)) {
      await _setGrowthXp(
        baseKey: 'habit:${plan.id}:${habit.id}',
        targetXp: status == WorkStatus.done ? 5 : 0,
        category: 'habit',
        sourceId: habit.id,
        title: habit.title,
      );
    }
  }

  Future<void> reactivateRsipHabit(WorkspaceRecord habit) async {
    final current = _latestRecord(habit);
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
    final current = _latestRecord(habit);
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
      id: _notificationId('rsip:${current.id}'),
      title: 'RSIP 最小动作可以结算',
      body: '${current.title} · ${current.rsipMinimumAction}',
      when: dueAt,
    );
    await _addProtocolEvent(
      protocol: 'rsip',
      action: 'timer_started',
      subject: current,
      data: {'dueAt': dueAt.toUtc().toIso8601String()},
    );
  }

  Future<void> completeRsipTimer(WorkspaceRecord habit) async {
    final current = _latestRecord(habit);
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
    await _addProtocolEvent(
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
    final current = _latestRecord(root);
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
    await _addProtocolEvent(
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

  Future<void> _syncCommitmentXp(String taskId, bool completed) async {
    final plan = todayPlan;
    if (plan == null) return;
    final ids = activeCommitmentIds;
    final slot = ids.indexOf(taskId);
    if (slot < 0) return;
    final isReplacement = taskId != commitmentIds[slot];
    await _setGrowthXp(
      baseKey: 'commitment:${plan.id}:$slot',
      targetXp: completed ? (isReplacement ? 10 : 20) : 0,
      category: 'commitment',
      sourceId: taskId,
      title: '完成承诺 ${slot + 1}',
    );
  }

  Future<void> _syncFocusXp(String taskId) async {
    final plan = todayPlan;
    if (plan == null || !activeCommitmentIds.contains(taskId)) return;
    final dayKey = growthService.dayKey(currentTime());
    final seconds = recordsOf(RecordKind.focusSession)
        .where((session) {
          return activeCommitmentIds.contains(session.parentId) &&
              growthService.dayKey(session.scheduledFor ?? session.createdAt) ==
                  dayKey;
        })
        .fold<int>(
          0,
          (sum, session) =>
              sum + ((session.data['seconds'] as num?)?.toInt() ?? 0),
        );
    final xp = (seconds ~/ (15 * 60)).clamp(0, 20);
    await _setGrowthXp(
      baseKey: 'focus:${plan.id}',
      targetXp: xp,
      category: 'focus',
      sourceId: taskId,
      title: '承诺专注 ${seconds ~/ 60} 分钟',
    );
  }

  Future<void> _setGrowthXp({
    required String baseKey,
    required int targetXp,
    required String category,
    required String sourceId,
    required String title,
    bool forceEvent = false,
    Map<String, dynamic> data = const {},
  }) async {
    final current = growthService.netXpForBaseKey(activeRecords, baseKey);
    final delta = targetXp - current;
    if (delta == 0 && !forceEvent) return;
    final plan = todayPlan;
    await addRecord(
      WorkspaceRecord.create(
        kind: RecordKind.growthEvent,
        title: title,
        status: WorkStatus.done,
        scheduledFor: growthService.logicalDay(currentTime()),
        parentId: sourceId,
        data: {
          'baseKey': baseKey,
          'eventKey':
              '$baseKey:${growthEvents.where((event) => event.data['baseKey'] == baseKey).length}',
          'xp': delta,
          'category': category,
          'sourceId': sourceId,
          'dailyPlanId': plan?.id,
          'dayKey': growthService.dayKey(currentTime()),
          ...data,
          if (delta < 0) 'reversal': true,
        },
      ),
    );
  }

  double goalProgress(WorkspaceRecord goal) {
    final milestones = milestonesForGoal(goal.id);
    if (milestones.isEmpty) {
      return ((goal.data['progress'] as num?)?.toDouble() ?? 0).clamp(0, 1);
    }
    return milestones.where((item) => item.isDone).length / milestones.length;
  }

  Future<void> addRelation({
    required WorkspaceRecord source,
    required WorkspaceRecord target,
    String relation = 'related',
  }) async {
    final exists = recordsOf(RecordKind.relation).any((record) {
      return record.data['sourceId'] == source.id &&
          record.data['targetId'] == target.id &&
          record.data['relation'] == relation;
    });
    if (exists) return;
    await addRecord(
      WorkspaceRecord.create(
        kind: RecordKind.relation,
        title: '${source.title} → ${target.title}',
        data: {
          'sourceId': source.id,
          'sourceKind': source.kind.name,
          'targetId': target.id,
          'targetKind': target.kind.name,
          'relation': relation,
        },
      ),
    );
  }

  List<WorkspaceRecord> linkedRecords(WorkspaceRecord source) {
    final ids = <String>{};
    for (final relation in recordsOf(RecordKind.relation)) {
      if (relation.data['sourceId'] == source.id) {
        ids.add(relation.data['targetId']?.toString() ?? '');
      }
      if (relation.data['targetId'] == source.id) {
        ids.add(relation.data['sourceId']?.toString() ?? '');
      }
    }
    return activeRecords.where((record) => ids.contains(record.id)).toList();
  }

  List<WorkspaceRecord> search(String query) =>
      searchService.search(activeRecords, query);

  Future<void> moveToTrash(WorkspaceRecord record) async {
    if (record.kind == RecordKind.template &&
        record.data['recordType'] == 'taskGroup') {
      final result = await moveTaskGroupToTrash(record);
      if (!result.isSuccessful) {
        throw StateError(result.failures.first.message);
      }
      return;
    }
    await updateRecord(record.copyWith(deletedAt: currentTime()));
  }

  Future<void> restoreFromTrash(WorkspaceRecord record) async {
    final result = await restoreRecords([record]);
    if (result.succeeded == 0 && result.failed > 0) {
      throw StateError(result.failures.first.message);
    }
  }

  Future<void> permanentlyDelete(WorkspaceRecord record) async {
    final result = await permanentlyDeleteRecords([record]);
    if (!result.isSuccessful) {
      throw StateError(result.failures.first.message);
    }
  }

  Future<BatchOperationResult> restoreRecords(
    Iterable<WorkspaceRecord> selected,
  ) async {
    final records = selected.toList(growable: false);
    final groups = records
        .where(
          (record) =>
              record.kind == RecordKind.template &&
              record.data['recordType'] == 'taskGroup',
        )
        .toList(growable: false);
    final ordinary = records.where((record) => !groups.contains(record));
    var succeeded = 0;
    final failures = <BatchOperationFailure>[];
    final ordinaryUpdates = ordinary
        .map((record) => _latestRecord(record).copyWith(deletedAt: null))
        .toList(growable: false);
    if (ordinaryUpdates.isNotEmpty) {
      try {
        await _saveRecordsBatch(ordinaryUpdates);
        succeeded += ordinaryUpdates.length;
      } catch (error) {
        failures.addAll(
          ordinaryUpdates.map(
            (record) =>
                BatchOperationFailure(recordId: record.id, message: '$error'),
          ),
        );
      }
    }
    for (final group in groups) {
      final result = await restoreTaskGroup(group);
      succeeded += result.succeeded;
      failures.addAll(result.failures);
    }
    return BatchOperationResult(succeeded: succeeded, failures: failures);
  }

  Future<BatchOperationResult> permanentlyDeleteRecords(
    Iterable<WorkspaceRecord> selected,
  ) async {
    final requested = selected.toList(growable: false);
    final targets = _permanentDeleteTargets(requested);
    final values = targets.values.toList(growable: false);
    if (values.isEmpty) return const BatchOperationResult(succeeded: 0);
    try {
      if (syncService.cloudWriteReady) {
        await syncService.deleteRecords(values);
      }
      await attachmentService.deleteForRecordsAtomically(
        values,
        commitDatabase: () => database.permanentlyDeleteRecords(
          values.map((record) => (id: record.id, kind: record.kind)),
        ),
      );
      final keys = targets.keys.toSet();
      _records.removeWhere(
        (record) => keys.contains('${record.kind.name}:${record.id}'),
      );
      _projectIndex = null;
      notifyListeners();
      return BatchOperationResult(succeeded: requested.length);
    } catch (error) {
      return BatchOperationResult(
        succeeded: 0,
        failures: [
          for (final record in requested)
            BatchOperationFailure(recordId: record.id, message: '$error'),
        ],
      );
    }
  }

  Future<BatchOperationResult> clearTrash() {
    return permanentlyDeleteRecords(trashRecords);
  }

  Future<int> attachmentCountForRecords(
    Iterable<WorkspaceRecord> selected,
  ) async {
    final keys = _permanentDeleteTargets(selected).keys;
    return (await database.loadAttachments()).where((attachment) {
      return keys.contains(
        '${attachment.ownerKind.name}:${attachment.ownerRecordId}',
      );
    }).length;
  }

  Map<String, WorkspaceRecord> _permanentDeleteTargets(
    Iterable<WorkspaceRecord> selected,
  ) {
    final targets = <String, WorkspaceRecord>{};
    void addTarget(WorkspaceRecord record) {
      targets['${record.kind.name}:${record.id}'] = record;
    }

    for (final record in selected) {
      final current = _latestRecord(record);
      addTarget(current);
      if (current.kind == RecordKind.template &&
          current.data['recordType'] == 'taskGroup') {
        for (final relation in _records.where(
          (candidate) =>
              candidate.kind == RecordKind.relation &&
              candidate.data['relationType'] == 'taskGroupMember' &&
              candidate.data['groupId'] == current.id,
        )) {
          addTarget(relation);
        }
      }
    }
    return targets;
  }

  Future<void> clearSampleData() async {
    final samples = _records
        .where((record) => record.data['sample'] == true)
        .toList();
    for (final sample in samples) {
      await database.permanentlyDelete(sample.id, sample.kind);
      _records.remove(sample);
    }
    _projectIndex = null;
    notifyListeners();
  }

  Future<File> createEncryptedBackup(String password) async {
    final attachments = await attachmentService.createBackupEntries();
    final bytes = await backupService.createEncryptedBackup(
      password,
      _records,
      localGameState: _gameStateJson,
      attachments: attachments,
    );
    return backupService.writeDefaultBackup(bytes);
  }

  Future<BackupBundle> previewBackup(String path, String password) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const FormatException('备份文件不存在。');
    }
    backupService.validateEncryptedSize(await file.length());
    return backupService.decryptBackup(await file.readAsBytes(), password);
  }

  Future<void> restoreBackup(BackupBundle bundle) async {
    final restored = bundle.records
        .map(
          (record) => record.copyWith(syncState: SyncState.clean, touch: false),
        )
        .toList(growable: false);
    await attachmentService.restoreBackupEntries(
      bundle.attachments,
      commitDatabase: (attachments) => database.replaceAllWithAttachments(
        restored,
        attachments,
        markDirty: false,
      ),
    );
    _records
      ..clear()
      ..addAll(restored);
    if (bundle.localGameState != null) {
      _localGameState = LocalGameState.fromJson(
        jsonEncode(bundle.localGameState),
      );
      await _persistGameState(notify: false);
    }
    _projectIndex = null;
    _syncPhase = !cloudConfigured
        ? SyncPhase.localOnly
        : syncService.currentUser == null
        ? SyncPhase.signedOut
        : SyncPhase.idle;
    _syncMessage = cloudConfigured ? '备份已恢复到本地；确认云端内容后再手动同步' : '备份已恢复到本地';
    notifyListeners();
  }

  Future<File> exportJson({bool includeLocalGameState = false}) {
    return includeLocalGameState
        ? backupService.writeJsonExportWithLocalGameState(
            _records,
            _gameStateJson,
          )
        : backupService.writeJsonExport(_records);
  }

  Future<int> importFile(String path) async {
    final file = File(path);
    if (!await file.exists()) throw const FormatException('导入文件不存在。');
    if (await file.length() > _maxImportBytes) {
      throw const FormatException('导入文件不能超过 10 MiB。');
    }
    final extension = path.split('.').last.toLowerCase();
    final content = await file.readAsString();
    final importSource = file.uri.pathSegments.isEmpty
        ? file.path.split(Platform.pathSeparator).last
        : file.uri.pathSegments.last;
    final imported = <WorkspaceRecord>[];
    Map<String, dynamic>? importedGameState;
    switch (extension) {
      case 'json':
        final decoded = jsonDecode(content);
        final values = decoded is List
            ? decoded
            : (decoded as Map<String, dynamic>)['records'] as List<dynamic>;
        if (decoded is Map && decoded['localGameState'] is Map) {
          importedGameState = Map<String, dynamic>.from(
            decoded['localGameState'] as Map,
          );
        }
        imported.addAll(
          values.map(
            (value) => WorkspaceRecord.fromJson(
              Map<String, dynamic>.from(value as Map),
            ).copyWith(syncState: SyncState.dirty, touch: false),
          ),
        );
      case 'csv':
        final rows = Csv().decode(content);
        if (rows.isEmpty) return 0;
        final header = rows.first.map((value) => value.toString()).toList();
        final titleIndex = header.indexWhere(
          (value) => ['title', '任务', '标题'].contains(value.toLowerCase()),
        );
        final bodyIndex = header.indexWhere(
          (value) =>
              ['body', 'description', '说明', '内容'].contains(value.toLowerCase()),
        );
        for (final row in rows.skip(1)) {
          if (row.isEmpty) continue;
          final title =
              row
                  .elementAtOrNull(titleIndex < 0 ? 0 : titleIndex)
                  ?.toString()
                  .trim() ??
              '';
          if (title.isEmpty) continue;
          imported.add(
            WorkspaceRecord.create(
              kind: RecordKind.task,
              title: title,
              body: bodyIndex >= 0 && bodyIndex < row.length
                  ? row[bodyIndex].toString()
                  : '',
              status: WorkStatus.inbox,
              data: {'importSource': importSource},
            ),
          );
        }
      case 'md':
      case 'markdown':
      case 'txt':
        final lines = content.split(RegExp(r'\r?\n'));
        final heading = lines.firstWhere(
          (line) => line.trim().isNotEmpty,
          orElse: () => file.uri.pathSegments.last,
        );
        imported.add(
          WorkspaceRecord.create(
            kind: RecordKind.note,
            title: heading.replaceFirst(RegExp(r'^#+\s*'), '').trim(),
            body: content,
            data: {'importSource': importSource},
          ),
        );
      default:
        throw const FormatException('仅支持 JSON、CSV、Markdown 和 TXT 文件。');
    }
    for (final record in imported) {
      final duplicate = _records.any(
        (value) => value.id == record.id && value.kind == record.kind,
      );
      await addRecord(
        duplicate
            ? WorkspaceRecord.create(
                kind: record.kind,
                title: '${record.title}（导入副本）',
                body: record.body,
                status: record.status,
                scheduledFor: record.scheduledFor,
                dueAt: record.dueAt,
                projectId: record.projectId,
                tags: record.tags,
                data: record.data,
              )
            : record,
      );
    }
    if (importedGameState != null) {
      _localGameState = LocalGameState.fromJson(jsonEncode(importedGameState));
      await _persistGameState();
    }
    return imported.length;
  }

  Future<void> signIn(String email, String password) async {
    await syncService.signIn(email.trim(), password);
    _syncPhase = SyncPhase.idle;
    _syncMessage = '已登录 ${syncService.currentUser?.email ?? ''}';
    notifyListeners();
  }

  Future<void> signUp(String email, String password) async {
    await syncService.signUp(email.trim(), password);
    _syncPhase = syncService.currentUser == null
        ? SyncPhase.signedOut
        : SyncPhase.idle;
    _syncMessage = '账号已创建，请按邮件提示完成验证';
    notifyListeners();
  }

  Future<void> signOut() async {
    await syncService.signOut();
    _syncPhase = SyncPhase.signedOut;
    _syncMessage = '云端账号已退出，本地数据仍然可用';
    notifyListeners();
  }

  Future<void> syncNow() async {
    _syncPhase = SyncPhase.syncing;
    _syncMessage = '正在同步';
    notifyListeners();
    try {
      final result = await syncService.sync(database);
      _records
        ..clear()
        ..addAll(await database.loadRecords());
      _projectIndex = null;
      _syncPhase = SyncPhase.success;
      _syncMessage =
          '已同步：上传 ${result.uploaded}，下载 ${result.downloaded}，冲突副本 ${result.conflicts}';
    } catch (exception) {
      _syncPhase = SyncPhase.error;
      _syncMessage = exception.toString();
    }
    notifyListeners();
  }

  Future<void> settleProtocols() async {
    if (_settlingProtocols) return;
    _settlingProtocols = true;
    try {
      final now = currentTime();
      for (final task in List<WorkspaceRecord>.from(ctdpTasks)) {
        if (task.ctdpReservationPending) {
          final dueAt = DateTime.tryParse(
            task.data['ctdpReservationDueAt']?.toString() ?? '',
          )?.toLocal();
          if (dueAt != null && !now.isBefore(dueAt)) {
            await updateRecord(
              task.copyWith(
                data: {
                  ...task.data,
                  'ctdpReservationPending': false,
                  'ctdpChainCount': 0,
                  'ctdpAuxChainCount': 0,
                  'ctdpAuxFailures': task.ctdpAuxFailures + 1,
                  'ctdpTotalFailures': task.ctdpTotalFailures + 1,
                  'ctdpLastFailureAt': now.toUtc().toIso8601String(),
                  'ctdpFailureReason': '预约到期未触发，主链与辅助链自动重置',
                },
              ),
            );
            await _addProtocolEvent(
              protocol: 'ctdp',
              action: 'reservation_expired',
              subject: task,
              successful: false,
            );
          }
        }
        if (task.ctdpIsGroup && task.data['ctdpGroupStartedAt'] != null) {
          final expiresAt = DateTime.tryParse(
            task.data['ctdpGroupExpiresAt']?.toString() ?? '',
          )?.toLocal();
          if (expiresAt != null && !now.isBefore(expiresAt)) {
            final exceptions =
                (task.data['ctdpGroupTimeLimitExceptions'] as num?)?.toInt() ??
                0;
            await updateRecord(
              task.copyWith(
                data: {
                  ...task.data,
                  'ctdpChainCount': 0,
                  'ctdpTotalFailures': task.ctdpTotalFailures + 1,
                  'ctdpGroupTimeLimitExceptions': exceptions + 1,
                  'ctdpGroupStartedAt': null,
                  'ctdpGroupExpiresAt': null,
                  'ctdpFailureReason': '任务组未在时限内完成，组链自动重置',
                },
              ),
            );
            await _addProtocolEvent(
              protocol: 'ctdp',
              action: 'group_expired',
              subject: task,
              successful: false,
            );
          }
        }
      }

      for (final habit in List<WorkspaceRecord>.from(habits)) {
        if (!habit.hasRsipProtocol || !habit.rsipFrozen) continue;
        final until = DateTime.tryParse(
          habit.data['rsipFrozenUntil']?.toString() ?? '',
        )?.toLocal();
        if (until == null || now.isBefore(until)) continue;
        await updateRecord(
          habit.copyWith(
            data: {
              ...habit.data,
              'rsipFrozen': false,
              'rsipFrozenUntil': null,
              'rsipThawedAt': now.toUtc().toIso8601String(),
            },
          ),
        );
        await _addProtocolEvent(
          protocol: 'rsip',
          action: 'node_thawed',
          subject: habit,
        );
      }
      await _settlePreviousRsipDay(now);
    } finally {
      _settlingProtocols = false;
    }
  }

  Future<WorkspaceRecord> _addProtocolEvent({
    required String protocol,
    required String action,
    required WorkspaceRecord subject,
    bool successful = true,
    Map<String, dynamic> data = const {},
    DateTime? scheduledFor,
  }) async {
    final record = WorkspaceRecord.create(
      kind: RecordKind.protocolEvent,
      title: subject.title,
      parentId: subject.id,
      projectId: subject.projectId,
      scheduledFor: scheduledFor ?? currentTime(),
      status: successful ? WorkStatus.done : WorkStatus.skipped,
      data: {
        'protocol': protocol,
        'action': action,
        'successful': successful,
        ...data,
      },
    );
    await addRecord(record);
    return record;
  }

  Future<void> _settlePreviousRsipDay(DateTime now) async {
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
    await _addProtocolEvent(
      protocol: 'rsip',
      action: 'daily_settlement',
      subject: habits.firstWhere((habit) => habit.hasRsipProtocol),
      successful: completed > 0,
      scheduledFor: day,
      data: {'grade': grade, 'completed': completed, 'failed': failed},
    );
  }

  Future<void> _createNextOccurrence(WorkspaceRecord task) async {
    final recurrence = task.data['recurrence']?.toString();
    if (recurrence == null || recurrence == 'none') return;
    final base = task.scheduledFor ?? task.dueAt ?? currentTime();
    final next = nextOccurrence(base, recurrence);
    if (next == null) return;
    final definitionId = task.data['definitionId']?.toString();
    if (definitionId != null) {
      final nextInstance = tasks
          .where(
            (candidate) =>
                candidate.data['definitionId'] == definitionId &&
                isSameDay(candidate.scheduledFor, next),
          )
          .firstOrNull;
      if (nextInstance != null) {
        final propagated = nextInstance.copyWith(
          data: {
            ...nextInstance.data,
            if (task.hasCtdpProtocol) ...{
              'ctdpChainCount': task.ctdpChainCount,
              'ctdpAuxChainCount': task.ctdpAuxChainCount,
              'ctdpReservationCount': task.ctdpReservationCount,
              'ctdpTotalCompletions': task.ctdpTotalCompletions,
              'ctdpTotalFailures': task.ctdpTotalFailures,
              'ctdpReservationPending': false,
            },
          },
        );
        await updateRecord(propagated);
        return;
      }
    }
    await addRecord(
      WorkspaceRecord.create(
        kind: RecordKind.task,
        title: task.title,
        body: task.body,
        status: WorkStatus.todo,
        scheduledFor: task.scheduledFor == null ? null : next,
        dueAt: task.dueAt == null ? null : next,
        projectId: task.projectId,
        parentId: task.parentId,
        tags: task.tags,
        data: {
          ...task.data,
          'isFocus': false,
          'completedAt': null,
          if (task.hasCtdpProtocol) 'ctdpReservationPending': false,
        },
      ),
    );
  }

  int _taskOrder(WorkspaceRecord a, WorkspaceRecord b) {
    if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
    if (a.isFocus != b.isFocus) return a.isFocus ? -1 : 1;
    if (a.priority != b.priority) return b.priority.compareTo(a.priority);
    return (a.scheduledFor ?? a.dueAt ?? a.createdAt).compareTo(
      b.scheduledFor ?? b.dueAt ?? b.createdAt,
    );
  }

  WorkspaceRecord _latestRecord(WorkspaceRecord record) {
    return _records.firstWhere(
      (candidate) => candidate.id == record.id && candidate.kind == record.kind,
      orElse: () => record,
    );
  }

  String _linkTitle(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri != null && uri.host.isNotEmpty) return uri.host;
    return value.length > 40 ? '${value.substring(0, 40)}…' : value;
  }

  int _notificationId(String id) => stableNotificationId(id);

  Map<String, dynamic> get _gameStateJson =>
      Map<String, dynamic>.from(jsonDecode(_localGameState.encode()) as Map);

  Future<void> _persistGameState({bool notify = true}) async {
    await database.writeLocalGameState(_localGameState.encode());
    if (notify) notifyListeners();
  }

  @override
  void dispose() {
    _protocolSettlementTimer?.cancel();
    for (final timer in _focusScheduleTimers.values) {
      timer.cancel();
    }
    for (final timer in _focusMissTimers.values) {
      timer.cancel();
    }
    shareCaptureService.dispose();
    focusService.dispose();
    notificationService.dispose();
    database.close();
    super.dispose();
  }
}
