import 'package:flutter/foundation.dart';

import '../core/models/restriction_models.dart';
import '../core/models/workspace_record.dart';
import '../core/models/workspace_models_v3.dart';
import '../data/app_database.dart';
import '../data/backup_service.dart';
import '../services/attachment_service.dart';
import '../services/growth_service.dart';
import '../services/notification_service.dart';
import '../services/restriction_security_service.dart';
import '../services/self_control_importer.dart';
import '../services/windows_activity_service.dart';

/// 领域 mixin 与 [WorkbenchController] 共享的抽象契约。
///
/// 拆分后的领域 mixin（自律、RSIP、CTDP 等）通过 `on WorkbenchControllerBase`
/// 访问宿主状态与方法，避免 mixin 与宿主类之间的循环继承。
abstract class WorkbenchControllerBase extends ChangeNotifier {
  AppDatabase get database;
  BackupService get backupService;
  AttachmentService get attachmentService;
  WindowsActivityService get windowsActivityService;
  RestrictionSecurityService get restrictionSecurityService;
  SelfControlImporter get selfControlImporter;
  GrowthService get growthService;
  NotificationService get notificationService;

  DateTime currentTime();

  List<WorkspaceRecord> get allRecords;
  List<WorkspaceRecord> get restrictionProfileRecords;
  RestrictionProfile? get restrictionProfile;

  Future<void> addRecord(WorkspaceRecord record);
  Future<void> updateRecord(WorkspaceRecord record);

  /// 从数据库重新加载全部记录到内存（导入/恢复场景）。
  Future<void> reloadRecordsFromDatabase();

  // ---- 通用记录查询 ----
  List<WorkspaceRecord> recordsOf(RecordKind kind);
  List<WorkspaceRecord> get habits;
  List<WorkspaceRecord> get tasks;
  List<WorkspaceRecord> get taskDefinitions;
  List<WorkspaceRecord> get taskGroups;
  List<WorkspaceRecord> get protocolEvents;

  // ---- RSIP 国策 ----
  List<WorkspaceRecord> get activeRsipHabits;
  List<RsipNode> get rsipNodes;
  List<RsipNodeGroup> get rsipNodeGroups;
  List<RsipExecutionRecord> get rsipExecutionRecords;
  List<RsipRunRecord> get rsipRunRecords;
  List<RsipTaskLink> get rsipTaskLinks;
  bool get rsipAllowMultiplePerDay;
  set rsipAllowMultiplePerDay(bool value);
  bool get rsipStrictMode;
  set rsipStrictMode(bool value);

  // ---- 共享工具（原 WorkbenchController 私有方法，公开给领域 mixin）----
  String calendarDayKey(DateTime day);
  int notificationId(String id);
  WorkspaceRecord latestRecordById(WorkspaceRecord record);
  Future<WorkspaceRecord> addProtocolEvent({
    required String protocol,
    required String action,
    required WorkspaceRecord subject,
    bool successful = true,
    Map<String, dynamic> data = const {},
    DateTime? scheduledFor,
  });
}
