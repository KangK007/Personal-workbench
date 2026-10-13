import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_workbench/core/models/workspace_record.dart';
import 'package:personal_workbench/core/theme/app_theme.dart';
import 'package:personal_workbench/data/app_database.dart';
import 'package:personal_workbench/data/backup_service.dart';
import 'package:personal_workbench/services/focus_service.dart';
import 'package:personal_workbench/services/notification_service.dart';
import 'package:personal_workbench/services/search_service.dart';
import 'package:personal_workbench/services/share_capture_service.dart';
import 'package:personal_workbench/services/supabase_sync_service.dart';
import 'package:personal_workbench/state/workbench_controller.dart';
import 'package:personal_workbench/ui/pages/behavior_page.dart';

class _MemoryDatabase extends AppDatabase {
  final records = <String, WorkspaceRecord>{};
  final metadata = <String, String>{};

  @override
  Future<List<WorkspaceRecord>> loadRecords({
    bool includeDeleted = true,
    String? accountId,
  }) async => records.values.toList();

  @override
  Future<String?> readMetadata(String key) async => metadata[key];

  @override
  Future<void> writeMetadata(String key, String value) async {
    metadata[key] = value;
  }

  @override
  Future<void> saveRecord(
    WorkspaceRecord record, {
    bool markDirty = true,
  }) async {
    records['${record.kind.name}:${record.id}'] = record;
  }

  @override
  Future<void> permanentlyDelete(String id, RecordKind kind) async {
    records.remove('${kind.name}:$id');
  }
}

WorkbenchController _controller(_MemoryDatabase database) =>
    WorkbenchController(
      database: database,
      backupService: BackupService(),
      searchService: SearchService(),
      focusService: FocusService(tickInterval: const Duration(hours: 1)),
      notificationService: NotificationService(),
      shareCaptureService: ShareCaptureService(),
      syncService: SupabaseSyncService(null),
      now: () => DateTime(2026, 8, 10, 10),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeDateFormatting('zh_CN');
  });

  testWidgets('behavior center separates ordinary habits from RSIP habits', (
    tester,
  ) async {
    final database = _MemoryDatabase();
    final controller = _controller(database);
    addTearDown(controller.dispose);
    await controller.addRecord(
      WorkspaceRecord.create(kind: RecordKind.habit, title: '普通习惯'),
    );
    await controller.addRecord(
      WorkspaceRecord.create(
        kind: RecordKind.habit,
        title: '国策节点',
        data: {'protocol': 'rsip', 'rsipActive': true},
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: BehaviorPage(controller: controller)),
      ),
    );
    await tester.pump();
    expect(find.text('普通习惯'), findsOneWidget);
    expect(find.text('国策节点'), findsNothing);
    await tester.tap(find.text('国策协议'));
    await tester.pump();
    expect(find.text('国策节点'), findsWidgets);
    expect(find.text('普通习惯'), findsNothing);
    expect(database.metadata['behavior_mode'], 'policies');
  });

  testWidgets('behavior mode fades briefly and stops hidden page tickers', (
    tester,
  ) async {
    final database = _MemoryDatabase();
    final controller = _controller(database);
    addTearDown(controller.dispose);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Widget host({required bool disableAnimations, double textScale = 1}) =>
        MaterialApp(
          theme: AppTheme.light(),
          home: MediaQuery(
            data: MediaQueryData(
              disableAnimations: disableAnimations,
              textScaler: TextScaler.linear(textScale),
            ),
            child: Scaffold(body: BehaviorPage(controller: controller)),
          ),
        );
    final transition = find.byKey(const ValueKey('behavior-mode-transition'));
    double opacity() => tester.widget<FadeTransition>(transition).opacity.value;
    final habitTickers = find.byKey(
      const ValueKey('behavior-habits-tickers'),
      skipOffstage: false,
    );
    final policyTickers = find.byKey(
      const ValueKey('behavior-policies-tickers'),
      skipOffstage: false,
    );

    await tester.pumpWidget(host(disableAnimations: false));
    await tester.pump();
    expect(opacity(), 1);
    expect(tester.widget<TickerMode>(habitTickers).enabled, isTrue);
    expect(tester.widget<TickerMode>(policyTickers).enabled, isFalse);
    await tester.tap(find.text('国策协议'));
    await tester.pump();
    expect(opacity(), 0);
    expect(tester.widget<TickerMode>(habitTickers).enabled, isFalse);
    expect(tester.widget<TickerMode>(policyTickers).enabled, isTrue);
    await tester.pump(const Duration(milliseconds: 90));
    expect(opacity(), greaterThan(0));
    expect(opacity(), lessThan(1));
    await tester.pump(const Duration(milliseconds: 100));
    expect(opacity(), 1);

    tester.view.physicalSize = const Size(320, 568);
    await tester.pumpWidget(host(disableAnimations: true, textScale: 2));
    await tester.pump();
    await tester.ensureVisible(find.text('习惯追踪'));
    await tester.tap(find.text('习惯追踪'));
    await tester.pump();
    expect(opacity(), 1);
    expect(tester.widget<TickerMode>(habitTickers).enabled, isTrue);
    expect(tester.widget<TickerMode>(policyTickers).enabled, isFalse);
    expect(tester.takeException(), isNull);
  });
}
