import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_workbench/core/models/attachment.dart';
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
import 'package:personal_workbench/ui/pages/notes_page.dart';
import 'package:personal_workbench/ui/pages/review_page.dart';
import 'package:personal_workbench/ui/workbench_shell.dart';

class _MemoryDatabase extends AppDatabase {
  @override
  Future<void> saveRecord(
    WorkspaceRecord record, {
    bool markDirty = true,
  }) async {}

  @override
  Future<List<Attachment>> loadAttachments({String? ownerRecordId}) async => [];

  @override
  Future<void> close() async {}
}

final _now = DateTime(2026, 10, 15, 10);

WorkbenchController _controller() => WorkbenchController(
  database: _MemoryDatabase(),
  backupService: BackupService(),
  searchService: SearchService(),
  focusService: FocusService(),
  notificationService: NotificationService(),
  shareCaptureService: ShareCaptureService(),
  syncService: SupabaseSyncService(null),
  now: () => _now,
);

Widget _host(Widget child, {double textScale = 1}) => MaterialApp(
  theme: AppTheme.light(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: Scaffold(body: child),
);

void _resize(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
}

IconButton _periodNext(WidgetTester tester) => tester.widget<IconButton>(
  find.ancestor(of: find.byTooltip('下一期间'), matching: find.byType(IconButton)),
);

void main() {
  setUpAll(() => initializeDateFormatting('zh_CN'));
  tearDown(() {});

  testWidgets(
    'notes recover search and keep search visible after window expansion',
    (tester) async {
      _resize(tester, const Size(390, 844));
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = _controller();
      addTearDown(controller.dispose);
      await controller.addRecord(
        WorkspaceRecord.create(
          kind: RecordKind.note,
          title: '采样检查清单',
          body: '检查输入场、波长与间隔。',
        ),
      );
      await tester.pumpWidget(_host(NotesPage(controller: controller)));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(SearchBar), '不存在的词');
      await tester.pumpAndSettle();
      expect(find.text('没有匹配的笔记'), findsOneWidget);
      await tester.tap(find.text('显示全部笔记'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SearchBar>(find.byType(SearchBar)).controller!.text,
        isEmpty,
      );
      await tester.tap(find.text('采样检查清单'));
      await tester.pumpAndSettle();
      expect(find.byType(SearchBar), findsNothing);
      expect(find.text('返回笔记索引'), findsOneWidget);
      _resize(tester, const Size(1200, 900));
      await tester.pumpAndSettle();
      expect(find.byType(SearchBar), findsOneWidget);
      expect(find.text('返回笔记索引'), findsNothing);
      _resize(tester, const Size(390, 844));
      await tester.pumpAndSettle();
      await tester.tap(find.text('返回笔记索引'));
      await tester.pumpAndSettle();
      expect(find.byType(SearchBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('shell returns from note reading before leaving notes', (
    tester,
  ) async {
    _resize(tester, const Size(390, 844));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _controller();
    addTearDown(controller.dispose);
    await controller.addRecord(
      WorkspaceRecord.create(
        kind: RecordKind.note,
        title: '阅读中的笔记',
        body: '保留阅读位置。',
      ),
    );
    await tester.pumpWidget(
      _host(WorkbenchShell(controller: controller, enableSystemHotkey: false)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('导航'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('笔记').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('阅读中的笔记'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(SearchBar), findsOneWidget);
    expect(find.text('返回笔记索引'), findsNothing);
    expect(find.text('知识索引'), findsOneWidget);
    await tester.tap(find.text('阅读中的笔记'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.text('知识索引'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(SearchBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'day week and month show editable or history state and disable future navigation',
    (tester) async {
      _resize(tester, const Size(390, 844));
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = _controller();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ReviewPage(controller: controller)));
      await tester.pumpAndSettle();
      for (final label in ['日', '周', '月']) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(find.text('本期 · 可编辑'), findsOneWidget);
        expect(_periodNext(tester).onPressed, isNull);
        await tester.tap(find.byTooltip('上一期间'));
        await tester.pumpAndSettle();
        expect(find.text('历史 · 只读'), findsOneWidget);
        expect(_periodNext(tester).onPressed, isNotNull);
        await tester.tap(find.byTooltip('下一期间'));
        await tester.pumpAndSettle();
        expect(find.text('本期 · 可编辑'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'review library recovers searches and labels preview return accurately',
    (tester) async {
      _resize(tester, const Size(1200, 900));
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = _controller();
      addTearDown(controller.dispose);
      final review = await controller.savePeriodReview(
        type: ReviewPeriodType.daily,
        periodKey: '2026-10-15',
        periodStart: DateTime(2026, 10, 15),
        periodEnd: DateTime(2026, 10, 16),
        title: '阶段判断',
        body: '继续核对采样条件。',
      );
      await tester.pumpWidget(_host(ReviewPage(controller: controller)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('回顾库'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '没有对应记录');
      await tester.pumpAndSettle();
      expect(find.text('没有符合条件的回顾'), findsOneWidget);
      await tester.tap(find.text('显示全部回顾'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      await tester.tap(find.text(review.title));
      await tester.pumpAndSettle();
      expect(find.text('回顾预览'), findsOneWidget);
      expect(find.text('返回回顾库'), findsOneWidget);
      await tester.tap(find.text('返回回顾库'));
      await tester.pumpAndSettle();
      expect(find.text('搜索标题或正文'), findsOneWidget);
      expect(find.text('返回编辑'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('add review date picker ends on current logical day', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(ReviewPage(controller: controller)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加回顾'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('选择'));
    await tester.pumpAndSettle();
    final picker = tester.widget<DatePickerDialog>(
      find.byType(DatePickerDialog),
    );
    expect(picker.lastDate, DateTime(2026, 10, 15));
    expect(tester.takeException(), isNull);
  });
}
