import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../core/models/attachment.dart';
import '../../core/models/workspace_record.dart';
import '../../core/models/workspace_models_v3.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../state/workbench_controller.dart';
import '../widgets/attachment_panel.dart';
import '../widgets/common.dart';
import '../widgets/relation_picker_dialog.dart';
import '../widgets/workbench_illustration.dart';

enum ReviewTab { diary, weekly, monthly }

class ReviewPage extends StatefulWidget {
  const ReviewPage({
    super.key,
    required this.controller,
    this.initialTab = ReviewTab.diary,
    this.showHeader = true,
    this.showPeriodSwitcher = true,
    this.initialPreview,
    this.openRequestSerial = 0,
    this.onBackToProject,
  });

  final WorkbenchController controller;
  final ReviewTab initialTab;
  final bool showHeader;
  final bool showPeriodSwitcher;
  final WorkspaceRecord? initialPreview;
  final int openRequestSerial;
  final VoidCallback? onBackToProject;

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  late ReviewPeriodType type;
  late DateTime anchor;
  late final TextEditingController titleController;
  late final TextEditingController bodyController;
  late final TextEditingController completedController;
  late final TextEditingController blockersController;
  late final TextEditingController tomorrowController;
  late final TextEditingController searchController;
  final FocusNode relationFocusNode = FocusNode(
    debugLabel: 'ReviewPage.relations',
  );
  final Set<String> relatedTaskIds = {};
  final Set<String> relatedProjectIds = {};
  WorkspaceRecord? existing;
  WorkspaceRecord? legacyDiary;
  bool legacyNoticeVisible = true;
  int? mood;
  bool preview = false;
  bool saving = false;
  bool libraryVisible = false;
  WorkspaceRecord? libraryPreview;
  String libraryFilter = 'all';
  late String _savedDraftSignature;

  WorkbenchController get controller => widget.controller;
  ReviewPeriod get period => _periodFor(type, anchor);

  @override
  void initState() {
    super.initState();
    type = switch (widget.initialTab) {
      ReviewTab.diary => ReviewPeriodType.daily,
      ReviewTab.weekly => ReviewPeriodType.weekly,
      ReviewTab.monthly => ReviewPeriodType.monthly,
    };
    anchor = controller.growthService.logicalDay(controller.currentTime());
    titleController = TextEditingController();
    bodyController = TextEditingController();
    completedController = TextEditingController();
    blockersController = TextEditingController();
    tomorrowController = TextEditingController();
    searchController = TextEditingController()..addListener(_refreshLibrary);
    _loadPeriod();
    if (widget.initialPreview != null) {
      libraryVisible = true;
      libraryPreview = widget.initialPreview;
    }
  }

  @override
  void didUpdateWidget(covariant ReviewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPreview != null &&
        widget.onBackToProject == null &&
        libraryPreview?.id == oldWidget.initialPreview?.id) {
      libraryPreview = null;
      libraryVisible = false;
    }
    if (widget.openRequestSerial > oldWidget.openRequestSerial) {
      final requestSerial = widget.openRequestSerial;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted || widget.openRequestSerial != requestSerial) return;
        final requestedPreview = widget.initialPreview;
        if (requestedPreview != null) {
          setState(() {
            libraryVisible = true;
            libraryPreview = requestedPreview;
          });
          return;
        }
        if (!await _confirmLeaveDraft() || !mounted) return;
        setState(() {
          type = ReviewPeriodType.daily;
          anchor = controller.growthService.logicalDay(
            controller.currentTime(),
          );
          libraryVisible = false;
          libraryPreview = null;
          _loadPeriod();
        });
      });
    }
  }

  @override
  void dispose() {
    bodyController.dispose();
    titleController.dispose();
    completedController.dispose();
    blockersController.dispose();
    tomorrowController.dispose();
    searchController
      ..removeListener(_refreshLibrary)
      ..dispose();
    relationFocusNode.dispose();
    super.dispose();
  }

  void _refreshLibrary() {
    if (mounted && libraryVisible) setState(() {});
  }

  Future<void> _toggleLibrary() async {
    if (!libraryVisible &&
        libraryPreview == null &&
        !await _confirmLeaveDraft()) {
      return;
    }
    if (!mounted) return;
    setState(() {
      if (libraryPreview != null) {
        libraryPreview = null;
        libraryVisible = true;
      } else {
        libraryVisible = !libraryVisible;
      }
    });
  }

  void _loadPeriod() {
    existing = controller.reviewForPeriod(type, period.key);
    legacyDiary = type == ReviewPeriodType.daily && existing == null
        ? controller.latestDiaryForDay(period.start)
        : null;
    legacyNoticeVisible = legacyDiary != null;
    final source = existing ?? legacyDiary;
    titleController.text = source?.title ?? '';
    bodyController.text = existing?.body ?? '';
    if (existing == null && legacyDiary != null) {
      bodyController.text = legacyDiary!.body;
    }
    completedController.text = source?.data['completedToday']?.toString() ?? '';
    blockersController.text = source?.data['blockers']?.toString() ?? '';
    tomorrowController.text = source?.data['tomorrowPlan']?.toString() ?? '';
    mood = (source?.data['mood'] as num?)?.toInt();
    relatedTaskIds
      ..clear()
      ..addAll(_ids(existing?.data['relatedTaskIds']));
    relatedProjectIds
      ..clear()
      ..addAll(_ids(existing?.data['relatedProjectIds']));
    preview = false;
    _savedDraftSignature = _draftSignature;
  }

  String get _draftSignature => jsonEncode([
    titleController.text,
    bodyController.text,
    completedController.text,
    blockersController.text,
    tomorrowController.text,
    mood,
    [...relatedTaskIds]..sort(),
    [...relatedProjectIds]..sort(),
  ]);

  Future<bool> _confirmLeaveDraft({bool includeHiddenDraft = false}) async {
    if ((!includeHiddenDraft && (libraryVisible || libraryPreview != null)) ||
        !_isCurrentPeriod ||
        _draftSignature == _savedDraftSignature) {
      return true;
    }
    final choice = await showWorkbenchDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('保存当前回顾？'),
        content: const Text('当前周期有未保存的修改。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'stay'),
            child: const Text('继续编辑'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'discard'),
            child: const Text('放弃修改'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'save'),
            child: const Text('保存并继续'),
          ),
        ],
      ),
    );
    if (!mounted) return false;
    if (choice == 'save') return _save();
    return choice == 'discard';
  }

  Future<void> _backToProject() async {
    if (await _confirmLeaveDraft() && mounted) widget.onBackToProject?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.onBackToProject != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: _backToProject,
                icon: const Icon(Icons.arrow_back),
                label: const Text('返回项目'),
              ),
            ),
          ),
        if (widget.showHeader)
          PageHeader(
            maxWidth: AppLayout.formMax,
            title: '回顾',
            subtitle: '先核对期间事实，再记录判断与下一步',
            actions: [
              OutlinedButton.icon(
                onPressed: _toggleLibrary,
                icon: Icon(
                  libraryVisible || libraryPreview != null
                      ? Icons.edit_note_outlined
                      : Icons.library_books_outlined,
                ),
                label: Text(
                  libraryVisible || libraryPreview != null ? '返回编辑' : '回顾库',
                ),
              ),
              FilledButton.icon(
                onPressed: _addReview,
                icon: const Icon(Icons.add),
                label: const Text('添加回顾'),
              ),
            ],
          ),
        if (!widget.showHeader)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: _toggleLibrary,
                    tooltip: libraryVisible || libraryPreview != null
                        ? '返回编辑'
                        : '回顾库',
                    icon: Icon(
                      libraryVisible || libraryPreview != null
                          ? Icons.edit_note_outlined
                          : Icons.library_books_outlined,
                    ),
                  ),
                  IconButton(
                    onPressed: _addReview,
                    tooltip: '添加回顾',
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
          ),
        const Divider(),
        Expanded(
          child: libraryPreview != null
              ? _buildLibraryPreview(libraryPreview!)
              : libraryVisible
              ? _buildLibrary()
              : _buildEditor(),
        ),
      ],
    );
  }

  Widget _buildEditor() {
    final currentPeriod = period;
    final editable = _isCurrentPeriod;
    final snapshot = _snapshotForDisplay(currentPeriod);
    final statisticsChanged =
        existing != null && controller.reviewStatisticsChanged(existing!);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppLayout.formMax),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            20,
            8,
            20,
            AppSpacing.bottomNavClearance,
          ),
          children: [
            if (widget.showPeriodSwitcher)
              _PeriodToolbar(
                type: type,
                period: currentPeriod,
                onTypeChanged: _selectType,
                onPrevious: () => _movePeriod(-1),
                onNext: () => _movePeriod(1),
                onToday: _goCurrent,
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _periodLabel(currentPeriod),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            _PeriodEvidence(period: currentPeriod, snapshot: snapshot),
            const SizedBox(height: 12),
            _ReviewFacts(snapshot: snapshot),
            if (statisticsChanged) ...[
              const SizedBox(height: 12),
              MaterialBanner(
                content: const Text('统计已变化。手写正文不会自动改写，可按需刷新事实快照。'),
                leading: const Icon(Icons.change_circle_outlined),
                actions: [
                  TextButton(
                    onPressed: _refreshStatistics,
                    child: const Text('刷新统计'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            if (type == ReviewPeriodType.daily) ...[
              if (legacyDiary != null &&
                  existing == null &&
                  legacyNoticeVisible)
                MaterialBanner(
                  content: const Text('这是旧日记生成的迁移草稿，保存后会成为规范日回顾。'),
                  leading: const Icon(Icons.history_outlined),
                  actions: [
                    TextButton(
                      onPressed: () =>
                          setState(() => legacyNoticeVisible = false),
                      child: const Text('知道了'),
                    ),
                  ],
                ),
              ExternalField(
                label: '标题',
                child: TextField(
                  controller: titleController,
                  readOnly: !editable,
                  decoration: const InputDecoration(),
                ),
              ),
              const SizedBox(height: 12),
              ExternalField(
                label: '今日心情',
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wrapChoices =
                        constraints.maxWidth < 340 ||
                        MediaQuery.textScalerOf(context).scale(14) > 20;
                    if (wrapChoices) {
                      return Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (var value = 1; value <= 5; value++)
                            ChoiceChip(
                              label: Text('$value'),
                              selected: mood == value,
                              onSelected: editable
                                  ? (selected) => setState(
                                      () => mood = selected ? value : null,
                                    )
                                  : null,
                            ),
                        ],
                      );
                    }
                    return SegmentedButton<int>(
                      emptySelectionAllowed: true,
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: 1, label: Text('1')),
                        ButtonSegment(value: 2, label: Text('2')),
                        ButtonSegment(value: 3, label: Text('3')),
                        ButtonSegment(value: 4, label: Text('4')),
                        ButtonSegment(value: 5, label: Text('5')),
                      ],
                      selected: mood == null ? const {} : {mood!},
                      onSelectionChanged: editable
                          ? (value) => setState(
                              () => mood = value.isEmpty ? null : value.first,
                            )
                          : null,
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              _DailyReviewField(
                controller: completedController,
                label: '今天完成了什么',
                icon: Icons.check_circle_outline,
                readOnly: !editable,
              ),
              const SizedBox(height: 12),
              _DailyReviewField(
                controller: blockersController,
                label: '遇到的问题',
                icon: Icons.block_outlined,
                readOnly: !editable,
              ),
              const SizedBox(height: 12),
              _DailyReviewField(
                controller: tomorrowController,
                label: '明日计划',
                icon: Icons.next_plan_outlined,
                readOnly: !editable,
              ),
              const SizedBox(height: 18),
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                final compactMode =
                    constraints.maxWidth < 340 ||
                    MediaQuery.textScalerOf(context).scale(14) > 20;
                final relationButton = IconButton(
                  focusNode: relationFocusNode,
                  onPressed: editable ? _showRelations : null,
                  tooltip: '关联任务和项目',
                  icon: Badge(
                    isLabelVisible:
                        relatedTaskIds.isNotEmpty ||
                        relatedProjectIds.isNotEmpty,
                    label: Text(
                      '${relatedTaskIds.length + relatedProjectIds.length}',
                    ),
                    child: const Icon(Icons.account_tree_outlined),
                  ),
                );
                final versionButton =
                    (existing?.data['versions'] as List<dynamic>? ?? const [])
                        .isNotEmpty
                    ? IconButton(
                        onPressed: _showVersions,
                        tooltip: '恢复正文版本',
                        icon: const Icon(Icons.history_outlined),
                      )
                    : null;
                final modeSelector = SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: false,
                      label: const Text('编辑'),
                      icon: compactMode
                          ? null
                          : const Icon(Icons.edit_outlined),
                    ),
                    ButtonSegment(
                      value: true,
                      label: const Text('预览'),
                      icon: compactMode
                          ? null
                          : const Icon(Icons.visibility_outlined),
                    ),
                  ],
                  selected: {preview},
                  onSelectionChanged: (value) =>
                      setState(() => preview = value.first),
                );
                if (constraints.maxWidth < 420) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '回顾正文',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          relationButton,
                          ?versionButton,
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: modeSelector,
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Text(
                      '回顾正文',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    relationButton,
                    ?versionButton,
                    modeSelector,
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            if (preview)
              LogSurface(
                child: MarkdownBody(
                  data: bodyController.text.isEmpty
                      ? '*暂无正文*'
                      : bodyController.text,
                  selectable: true,
                ),
              )
            else ...[
              _MarkdownToolbar(
                controller: bodyController,
                onChanged: () => setState(() {}),
                enabled: editable,
              ),
              TextField(
                controller: bodyController,
                readOnly: !editable,
                minLines: 10,
                maxLines: 24,
                decoration: const InputDecoration(
                  hintText: '## 完成\n\n## 阻塞\n\n## 下一步',
                  alignLabelWithHint: true,
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (existing != null && editable)
              AttachmentPanel(owner: existing!, controller: controller)
            else if (existing != null)
              _ReadOnlyAttachments(owner: existing!, controller: controller)
            else
              Text(
                '第一次保存后可以添加本地图片附件。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (editable && existing?.data['draft'] == true) ...[
                  TextButton.icon(
                    onPressed: saving ? null : _skip,
                    icon: const Icon(Icons.skip_next_outlined),
                    label: const Text('跳过本期'),
                  ),
                  const SizedBox(width: 8),
                ],
                if (editable)
                  FilledButton.icon(
                    onPressed: saving ? null : () => _save(),
                    icon: saving
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text('保存${_reviewLabel(type)}'),
                  )
                else
                  Text(
                    '历史回顾仅供查看，当前周期可编辑。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  ReviewSnapshot _snapshotForDisplay(ReviewPeriod currentPeriod) {
    final stored = existing?.data['snapshot'];
    if (existing != null && existing!.data['draft'] != true && stored is Map) {
      return ReviewSnapshot.fromJson(Map<String, dynamic>.from(stored));
    }
    return controller.reviewSnapshotForPeriod(
      type: type,
      periodKey: currentPeriod.key,
      periodStart: currentPeriod.start,
      periodEnd: currentPeriod.end,
    );
  }

  Widget _buildLibrary() {
    final query = searchController.text.trim().toLowerCase();
    final canonicalDailyKeys = controller.periodReviews
        .where((review) => review.data['periodType'] == 'daily')
        .map((review) => review.data['periodKey']?.toString())
        .whereType<String>()
        .toSet();
    final newestLegacyByDay = <String, WorkspaceRecord>{};
    for (final diary in controller.diaries) {
      final day = diary.scheduledFor;
      if (day == null) continue;
      final key = _dateKey(day);
      if (canonicalDailyKeys.contains(key)) continue;
      final current = newestLegacyByDay[key];
      if (current == null || diary.updatedAt.isAfter(current.updatedAt)) {
        newestLegacyByDay[key] = diary;
      }
    }
    final records =
        <WorkspaceRecord>[
            ...controller.periodReviews,
            ...newestLegacyByDay.values,
          ].where((review) {
            final periodType = review.kind == RecordKind.diary
                ? 'daily'
                : review.data['periodType']?.toString() ?? 'daily';
            if (libraryFilter != 'all' && periodType != libraryFilter) {
              return false;
            }
            if (query.isEmpty) return true;
            return review.title.toLowerCase().contains(query) ||
                review.body.toLowerCase().contains(query);
          }).toList()
          ..sort(
            (a, b) => (b.scheduledFor ?? b.updatedAt).compareTo(
              a.scheduledFor ?? a.updatedAt,
            ),
          );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final search = ExternalField(
                label: '搜索标题或正文',
                child: TextField(
                  controller: searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              );
              final filter = DropdownButton<String>(
                value: libraryFilter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('全部回顾')),
                  DropdownMenuItem(value: 'daily', child: Text('日回顾')),
                  DropdownMenuItem(value: 'weekly', child: Text('周回顾')),
                  DropdownMenuItem(value: 'monthly', child: Text('月回顾')),
                  DropdownMenuItem(value: 'yearly', child: Text('历史年回顾')),
                ],
                onChanged: (value) =>
                    setState(() => libraryFilter = value ?? 'all'),
              );
              if (constraints.maxWidth < 520) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [search, const SizedBox(height: 8), filter],
                );
              }
              return Row(
                children: [
                  Expanded(child: search),
                  const SizedBox(width: 12),
                  filter,
                ],
              );
            },
          ),
        ),
        Expanded(
          child: records.isEmpty
              ? const EmptyState(
                  icon: Icons.library_books_outlined,
                  title: '没有符合条件的回顾',
                  message: '调整期间筛选或搜索内容。',
                )
              : ListView.separated(
                  key: const PageStorageKey('review-library'),
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    4,
                    20,
                    AppSpacing.bottomNavClearance,
                  ),
                  itemCount: records.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (context, index) {
                    final review = records[index];
                    final isLegacyDiary = review.kind == RecordKind.diary;
                    final periodType = review.data['periodType']?.toString();
                    final legacy = periodType == 'yearly';
                    final status = isLegacyDiary
                        ? '待迁移'
                        : review.data['reviewSkipped'] == true
                        ? '已跳过'
                        : review.data['draft'] == true
                        ? '草稿'
                        : '已完成';
                    return ListTile(
                      leading: Icon(
                        legacy || isLegacyDiary
                            ? Icons.history_outlined
                            : Icons.menu_book_outlined,
                      ),
                      title: Text(review.title),
                      subtitle: Text(
                        '${isLegacyDiary ? _dateKey(review.scheduledFor ?? review.updatedAt) : review.data['periodKey'] ?? formatShortDate(review.scheduledFor ?? review.updatedAt)}'
                        ' · 保存于 ${formatDateTime(review.updatedAt)} · $status',
                      ),
                      trailing: Icon(
                        legacy
                            ? Icons.visibility_outlined
                            : Icons.chevron_right,
                      ),
                      onTap: () => _openLibraryReview(review),
                    );
                  },
                ),
        ),
      ],
    );
  }

  bool get _isCurrentPeriod {
    final current = reviewPeriodFor(
      type,
      controller.growthService.logicalDay(controller.currentTime()),
    );
    return !period.start.isAfter(current.start) && period.key == current.key;
  }

  Widget _buildLibraryPreview(WorkspaceRecord review) {
    final isLegacy = review.kind == RecordKind.diary;
    final reviewType = isLegacy
        ? ReviewPeriodType.daily
        : ReviewPeriodType.values.firstWhere(
            (value) => value.name == review.data['periodType'],
            orElse: () => ReviewPeriodType.daily,
          );
    final start =
        DateTime.tryParse(
          review.data['periodStart']?.toString() ?? '',
        )?.toLocal() ??
        review.scheduledFor ??
        review.updatedAt;
    final current =
        reviewType != ReviewPeriodType.yearly &&
        reviewPeriodFor(
              reviewType,
              controller.growthService.logicalDay(controller.currentTime()),
            ).key ==
            (isLegacy
                ? _dateKey(start)
                : review.data['periodKey']?.toString() ?? '');
    final relatedTasks = _ids(
      review.data['relatedTaskIds'],
    ).map(_findRecord).whereType<WorkspaceRecord>().toList(growable: false);
    final relatedProjects = _ids(
      review.data['relatedProjectIds'],
    ).map(_findRecord).whereType<WorkspaceRecord>().toList(growable: false);
    final snapshot = review.data['snapshot'];
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        20,
        12,
        20,
        AppSpacing.bottomNavClearance,
      ),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: '返回回顾库',
              onPressed: () => setState(() => libraryPreview = null),
              icon: const Icon(Icons.arrow_back),
            ),
            Expanded(
              child: Text(
                '回顾预览',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (current && !isLegacy)
              FilledButton.icon(
                onPressed: () => _editLibraryReview(review),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('编辑本期'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        LogSurface(
          child: Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _previewMeta('类型', _reviewLabel(reviewType)),
              _previewMeta(
                '周期',
                isLegacy
                    ? _dateKey(start)
                    : review.data['periodKey']?.toString() ?? _dateKey(start),
              ),
              _previewMeta('保存时间', formatDateTime(review.updatedAt)),
              _previewMeta(
                '状态',
                isLegacy
                    ? '旧日记（只读）'
                    : review.data['draft'] == true
                    ? '草稿'
                    : review.data['reviewSkipped'] == true
                    ? '已跳过'
                    : '已完成',
              ),
            ],
          ),
        ),
        if (!current && !isLegacy) ...[
          const SizedBox(height: 10),
          const MaterialBanner(
            content: Text('历史周期只读，不能修改或保存。'),
            leading: Icon(Icons.lock_outline),
            actions: [],
          ),
        ],
        const SizedBox(height: 16),
        Text(review.title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        LogSurface(
          padding: const EdgeInsets.all(16),
          child: MarkdownBody(
            data: review.body.isEmpty ? '*暂无正文*' : review.body,
            selectable: true,
          ),
        ),
        if (reviewType == ReviewPeriodType.daily) ...[
          const SizedBox(height: 16),
          _PreviewFields(review: review),
        ],
        if (snapshot is Map) ...[
          const SizedBox(height: 16),
          Text('事实快照', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          LogSurface(
            padding: const EdgeInsets.all(16),
            child: Text(_snapshotSummary(snapshot)),
          ),
        ],
        const SizedBox(height: 16),
        _PreviewRelations(
          title: '关联任务',
          icon: Icons.checklist_outlined,
          records: relatedTasks,
        ),
        const SizedBox(height: 12),
        _PreviewRelations(
          title: '关联项目',
          icon: Icons.folder_outlined,
          records: relatedProjects,
        ),
        const SizedBox(height: 16),
        _ReadOnlyAttachments(owner: review, controller: controller),
      ],
    );
  }

  WorkspaceRecord? _findRecord(String id) {
    for (final record in controller.allRecords) {
      if (record.id == id) return record;
    }
    return null;
  }

  Widget _previewMeta(String label, String value) => SizedBox(
    width: 170,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 2),
        Text(value),
      ],
    ),
  );

  String _snapshotSummary(Map snapshot) {
    final completed = snapshot['completed'] ?? 0;
    final failed = snapshot['failed'] ?? 0;
    final skipped = snapshot['skipped'] ?? 0;
    final focus = snapshot['focusSeconds'] ?? 0;
    return '完成 $completed · 失败 $failed · 跳过 $skipped · 专注 ${((focus as num) / 60).round()} 分';
  }

  Future<void> _editLibraryReview(WorkspaceRecord review) async {
    if (!await _confirmLeaveDraft(includeHiddenDraft: true) || !mounted) return;
    final value = ReviewPeriodType.values.firstWhere(
      (candidate) => candidate.name == review.data['periodType'],
      orElse: () => ReviewPeriodType.daily,
    );
    final date =
        DateTime.tryParse(
          review.data['periodStart']?.toString() ?? '',
        )?.toLocal() ??
        review.scheduledFor ??
        review.updatedAt;
    setState(() {
      type = value;
      anchor = date;
      libraryPreview = null;
      libraryVisible = false;
      _loadPeriod();
    });
  }

  Future<bool> _save() async {
    if (!_isCurrentPeriod) {
      _message('只能编辑当前逻辑周期的回顾。');
      return false;
    }
    if (saving) return false;
    setState(() => saving = true);
    try {
      final current = period;
      existing = await controller.savePeriodReview(
        type: type,
        periodKey: current.key,
        periodStart: current.start,
        periodEnd: current.end,
        body: bodyController.text,
        relatedTaskIds: relatedTaskIds,
        relatedProjectIds: relatedProjectIds,
        title: type == ReviewPeriodType.daily ? titleController.text : null,
        mood: type == ReviewPeriodType.daily ? mood : null,
        completedToday: type == ReviewPeriodType.daily
            ? completedController.text
            : '',
        blockers: type == ReviewPeriodType.daily ? blockersController.text : '',
        tomorrowPlan: type == ReviewPeriodType.daily
            ? tomorrowController.text
            : '',
        legacyDiaryId: type == ReviewPeriodType.daily ? legacyDiary?.id : null,
      );
      legacyDiary = null;
      _savedDraftSignature = _draftSignature;
      if (!mounted) return true;
      final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text('${_reviewLabel(type)}已保存')),
      );
      return true;
    } on FormatException catch (error) {
      if (mounted) _message(error.message);
      return false;
    } catch (_) {
      if (mounted) _message('保存回顾失败，请重试。');
      return false;
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _refreshStatistics() async {
    final review = existing;
    if (review == null) return;
    final field = TextEditingController();
    final reason = await showWorkbenchDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('刷新事实快照'),
        content: ExternalField(
          label: '刷新原因（必填）',
          child: TextField(
            controller: field,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(hintText: '例如：任务结算已留痕更正'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, field.text.trim()),
            child: const Text('刷新'),
          ),
        ],
      ),
    );
    field.dispose();
    if (reason == null || reason.isEmpty) return;
    existing = await controller.refreshPeriodReviewSnapshot(
      review,
      reason: reason,
    );
    if (mounted) setState(() {});
  }

  Future<void> _skip() async {
    final review = existing;
    if (review == null) return;
    final field = TextEditingController();
    final reason = await showWorkbenchDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('跳过本期回顾'),
        content: ExternalField(
          label: '跳过原因（必填）',
          child: TextField(
            controller: field,
            autofocus: true,
            decoration: const InputDecoration(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, field.text.trim()),
            child: const Text('确认跳过'),
          ),
        ],
      ),
    );
    field.dispose();
    if (reason == null || reason.isEmpty) return;
    await controller.skipPeriodReview(review, reason: reason);
    if (mounted) {
      setState(() => existing = controller.reviewForPeriod(type, period.key));
    }
  }

  Future<void> _addReview() async {
    var selectedType = ReviewPeriodType.daily;
    var selectedDate = controller.growthService.logicalDay(
      controller.currentTime(),
    );
    final accepted = await showWorkbenchDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('添加回顾'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<ReviewPeriodType>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: ReviewPeriodType.daily,
                      label: Text('日'),
                    ),
                    ButtonSegment(
                      value: ReviewPeriodType.weekly,
                      label: Text('周'),
                    ),
                    ButtonSegment(
                      value: ReviewPeriodType.monthly,
                      label: Text('月'),
                    ),
                  ],
                  selected: {selectedType},
                  onSelectionChanged: (value) =>
                      setDialogState(() => selectedType = value.first),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: const Text('目标期间'),
                  subtitle: Text(_periodFor(selectedType, selectedDate).key),
                  trailing: OutlinedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedDate = picked);
                      }
                    },
                    child: const Text('选择'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('打开'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || !mounted) return;
    final targetPeriod = _periodFor(selectedType, selectedDate);
    final samePeriod = type == selectedType && period.key == targetPeriod.key;
    if (!samePeriod && !await _confirmLeaveDraft()) return;
    if (!mounted) return;
    setState(() {
      type = selectedType;
      anchor = selectedDate;
      libraryVisible = false;
      libraryPreview = null;
      if (!samePeriod) _loadPeriod();
    });
  }

  Future<void> _selectType(ReviewPeriodType value) async {
    if (value == type || !await _confirmLeaveDraft() || !mounted) return;
    setState(() {
      type = value;
      _loadPeriod();
    });
  }

  Future<void> _movePeriod(int direction) async {
    final nextAnchor = switch (type) {
      ReviewPeriodType.daily => anchor.add(Duration(days: direction)),
      ReviewPeriodType.weekly => anchor.add(Duration(days: 7 * direction)),
      ReviewPeriodType.monthly => DateTime(
        anchor.year,
        anchor.month + direction,
        1,
      ),
      ReviewPeriodType.yearly => anchor,
    };
    final current = reviewPeriodFor(
      type,
      controller.growthService.logicalDay(controller.currentTime()),
    );
    final next = reviewPeriodFor(type, nextAnchor);
    if (direction > 0 && next.start.isAfter(current.start)) {
      _message('不能导航到未来周期。');
      return;
    }
    if (!await _confirmLeaveDraft() || !mounted) return;
    setState(() {
      anchor = nextAnchor;
      _loadPeriod();
    });
  }

  Future<void> _goCurrent() async {
    final current = controller.growthService.logicalDay(
      controller.currentTime(),
    );
    if (reviewPeriodFor(type, current).key == period.key) return;
    if (!await _confirmLeaveDraft() || !mounted) return;
    setState(() {
      anchor = current;
      _loadPeriod();
    });
  }

  void _openLibraryReview(WorkspaceRecord review) {
    setState(() {
      libraryVisible = true;
      libraryPreview = review;
    });
  }

  Future<void> _showRelations() async {
    final selection = await showRelationPickerDialog(
      context: context,
      controller: controller,
      initialTaskIds: relatedTaskIds,
      initialProjectIds: relatedProjectIds,
      returnFocusNode: relationFocusNode,
    );
    if (selection == null || !mounted) return;
    setState(() {
      relatedTaskIds
        ..clear()
        ..addAll(selection.taskIds);
      relatedProjectIds
        ..clear()
        ..addAll(selection.projectIds);
    });
  }

  Future<void> _showVersions() async {
    final versions = (existing?.data['versions'] as List<dynamic>? ?? const [])
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList()
        .reversed
        .toList();
    final body = await showWorkbenchDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('恢复正文版本'),
        children: [
          for (final version in versions)
            SimpleDialogOption(
              onPressed: () =>
                  Navigator.pop(context, version['body']?.toString() ?? ''),
              child: ListTile(
                leading: const Icon(Icons.history_outlined),
                title: Text(_versionTitle(version['body']?.toString() ?? '')),
                subtitle: Text(version['savedAt']?.toString() ?? ''),
              ),
            ),
        ],
      ),
    );
    if (body != null && mounted) {
      setState(() => bodyController.text = body);
    }
  }

  void _message(String message) {
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

/// The summary shape changes with the period. Only actual completion timestamps
/// are plotted; unscheduled or unresolved tasks remain in the facts below.
class _PeriodEvidence extends StatelessWidget {
  const _PeriodEvidence({required this.period, required this.snapshot});

  final ReviewPeriod period;
  final ReviewSnapshot snapshot;

  int _completedOn(DateTime day) => snapshot.taskFacts.where((fact) {
    final at = fact.completedAt?.toLocal();
    return fact.status == WorkStatus.done &&
        at != null &&
        at.year == day.year &&
        at.month == day.month &&
        at.day == day.day;
  }).length;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final title = switch (period.type) {
      ReviewPeriodType.daily => '日事实卡',
      ReviewPeriodType.weekly => '七日完成分布',
      ReviewPeriodType.monthly => '月度完成日历',
      ReviewPeriodType.yearly => '期间记录',
    };
    final completed = snapshot.count(WorkStatus.done);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tokens.heroStart, tokens.heroEnd],
        ),
        borderRadius: BorderRadius.circular(tokens.panelRadius),
        border: Border.all(color: tokens.panelBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$completed 项完成 · ${snapshot.taskFacts.length} 项期间任务',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: tokens.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  width: 96,
                  height: 72,
                  child: ClipRect(
                    child: WorkbenchIllustration(
                      kind: WorkbenchIllustrationKind.review,
                      width: 96,
                      height: 72,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            switch (period.type) {
              ReviewPeriodType.daily => _buildDaily(context, completed),
              ReviewPeriodType.weekly => _buildWeekly(context),
              ReviewPeriodType.monthly => _buildMonthly(context),
              ReviewPeriodType.yearly => Text(
                '历史期间只读',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            },
          ],
        ),
      ),
    );
  }

  Widget _buildDaily(BuildContext context, int completed) {
    final total = snapshot.taskFacts.length;
    return Row(
      children: [
        SizedBox.square(
          dimension: 68,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.square(
                dimension: 68,
                child: CircularProgressIndicator(
                  value: total == 0 ? 0 : completed / total,
                  strokeWidth: 5,
                  backgroundColor: context.tokens.orbitTrack,
                ),
              ),
              NumericText(
                '${period.start.day}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            total == 0
                ? '今天尚无可结算任务，可直接记录收获与下一步。'
                : '已完成 $completed / $total 项期间任务；其余状态见下方事实快照。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildWeekly(BuildContext context) {
    final days = List.generate(
      7,
      (index) => DateTime(
        period.start.year,
        period.start.month,
        period.start.day + index,
      ),
    );
    final values = [for (final day in days) _completedOn(day)];
    final largest = values.fold<int>(
      1,
      (max, value) => value > max ? value : max,
    );
    const weekday = ['一', '二', '三', '四', '五', '六', '日'];
    return SizedBox(
      height: 86,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var index = 0; index < days.length; index++)
            Expanded(
              child: Semantics(
                label:
                    '${days[index].month}月${days[index].day}日完成 ${values[index]} 项',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            widthFactor: 0.72,
                            heightFactor: values[index] == 0
                                ? 0.07
                                : values[index] / largest,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: values[index] == 0
                                    ? context.tokens.orbitTrack
                                    : Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.xs,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      ExcludeSemantics(
                        child: Text(
                          weekday[days[index].weekday - 1],
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMonthly(BuildContext context) {
    final first = DateTime(period.start.year, period.start.month);
    final daysInMonth = DateTime(first.year, first.month + 1, 0).day;
    final leading = first.weekday - 1;
    const weekday = ['一', '二', '三', '四', '五', '六', '日'];
    return Column(
      children: [
        Row(
          children: [
            for (final name in weekday)
              Expanded(
                child: Center(
                  child: Text(
                    name,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 5),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth / 7;
            return Wrap(
              children: [
                for (var slot = 0; slot < leading + daysInMonth; slot++)
                  SizedBox(
                    width: width,
                    height: 42,
                    child: slot < leading
                        ? const SizedBox.shrink()
                        : _monthDay(
                            context,
                            DateTime(
                              first.year,
                              first.month,
                              slot - leading + 1,
                            ),
                          ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '实心标记代表当天有完成记录。',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.tokens.mutedText),
          ),
        ),
      ],
    );
  }

  Widget _monthDay(BuildContext context, DateTime day) {
    final count = _completedOn(day);
    return Semantics(
      label: '${day.month}月${day.day}日完成 $count 项',
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: count == 0
                ? Colors.transparent
                : Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
          child: Center(
            child: ExcludeSemantics(
              child: Text(
                '${day.day}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: count == 0
                      ? context.tokens.mutedText
                      : Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: count == 0 ? FontWeight.w400 : FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PeriodToolbar extends StatelessWidget {
  const _PeriodToolbar({
    required this.type,
    required this.period,
    required this.onTypeChanged,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  final ReviewPeriodType type;
  final ReviewPeriod period;
  final ValueChanged<ReviewPeriodType> onTypeChanged;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final controls = SegmentedButton<ReviewPeriodType>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: ReviewPeriodType.daily, label: Text('日')),
            ButtonSegment(value: ReviewPeriodType.weekly, label: Text('周')),
            ButtonSegment(value: ReviewPeriodType.monthly, label: Text('月')),
          ],
          selected: {type},
          onSelectionChanged: (value) => onTypeChanged(value.first),
        );
        if (constraints.maxWidth < 420) {
          return Column(
            children: [
              controls,
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    onPressed: onPrevious,
                    tooltip: '上一期间',
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      _periodLabel(period),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  IconButton(
                    onPressed: onNext,
                    tooltip: '下一期间',
                    icon: const Icon(Icons.chevron_right),
                  ),
                  IconButton.filledTonal(
                    onPressed: onToday,
                    tooltip: '回到本期',
                    icon: const Icon(Icons.today_outlined),
                  ),
                ],
              ),
            ],
          );
        }
        final navigation = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: onPrevious,
              tooltip: '上一期间',
              icon: const Icon(Icons.chevron_left),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 170),
              child: Text(
                _periodLabel(period),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            IconButton(
              onPressed: onNext,
              tooltip: '下一期间',
              icon: const Icon(Icons.chevron_right),
            ),
            TextButton(onPressed: onToday, child: const Text('本期')),
          ],
        );
        return constraints.maxWidth < 620
            ? Column(
                children: [controls, const SizedBox(height: 8), navigation],
              )
            : Row(children: [controls, const Spacer(), navigation]);
      },
    );
  }
}

class _ReviewFacts extends StatelessWidget {
  const _ReviewFacts({required this.snapshot});

  final ReviewSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final factsById = {
      for (final fact in snapshot.taskFacts) fact.taskId: fact,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(
          title: '期间事实',
          scale:
              '${snapshot.taskFacts.length} 项任务 · ${snapshot.groupFacts.length} 个任务群',
        ),
        SizedBox(
          width: double.infinity,
          child: LogSurface(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const gap = 8.0;
                final columns = constraints.maxWidth >= 560
                    ? 3
                    : constraints.maxWidth >= 280
                    ? 2
                    : 1;
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                final metrics = [
                  _metric(
                    '完成',
                    snapshot.count(WorkStatus.done),
                    Icons.check_circle_outline,
                  ),
                  _metric(
                    '失败',
                    snapshot.count(WorkStatus.failed),
                    Icons.cancel_outlined,
                  ),
                  _metric(
                    '跳过',
                    snapshot.count(WorkStatus.skipped),
                    Icons.skip_next_outlined,
                  ),
                  _metric(
                    '改期',
                    snapshot.count(WorkStatus.rescheduled),
                    Icons.event_repeat_outlined,
                  ),
                  _metric(
                    '专注',
                    snapshot.focusSeconds ~/ 60,
                    Icons.timer_outlined,
                    suffix: '分',
                  ),
                ];
                return Wrap(
                  spacing: gap,
                  runSpacing: 4,
                  children: [
                    for (final metric in metrics)
                      SizedBox(width: width, child: metric),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (snapshot.taskFacts.isEmpty)
          const Text('本期间没有计划或结算任务。')
        else
          for (final fact in snapshot.taskFacts) _TaskFactTile(fact: fact),
        if (snapshot.groupFacts.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('任务群', style: Theme.of(context).textTheme.titleSmall),
          for (final group in snapshot.groupFacts)
            ExpansionTile(
              leading: const Icon(Icons.account_tree_outlined),
              title: Text(group.title),
              subtitle: Text(
                '${group.mode == 'sequential' ? '顺序链' : '并行群'} · '
                '${group.memberTaskIds.length} 个期间相关成员',
              ),
              children: [
                for (final id in group.memberTaskIds)
                  if (factsById[id] != null)
                    ListTile(
                      dense: true,
                      title: Text(factsById[id]!.title),
                      trailing: Text(_statusLabel(factsById[id]!.status)),
                    ),
              ],
            ),
        ],
      ],
    );
  }

  Widget _metric(
    String label,
    int value,
    IconData icon, {
    String suffix = '',
  }) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
    leading: Icon(icon),
    title: Text('$value$suffix'),
    subtitle: Text(label),
  );
}

class _TaskFactTile extends StatelessWidget {
  const _TaskFactTile({required this.fact});

  final ReviewTaskFact fact;

  @override
  Widget build(BuildContext context) {
    final reason = fact.failureReason.isNotEmpty
        ? '失败原因：${fact.failureReason}'
        : fact.skipReason.isNotEmpty
        ? '跳过原因：${fact.skipReason}'
        : fact.rescheduledTo != null
        ? '改期至 ${formatDateTime(fact.rescheduledTo!)}'
        : fact.result.isNotEmpty
        ? '结果：${fact.result}'
        : '';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(_statusIcon(fact.status)),
      title: Text(fact.title),
      subtitle: Text(
        [
          if (fact.projectTitles.isNotEmpty) fact.projectTitles.join('、'),
          if (fact.groupTitle != null)
            '${fact.groupTitle}${fact.chainPosition == null ? '' : ' · #${fact.chainPosition}'}',
          if (fact.completedAt != null) formatDateTime(fact.completedAt!),
          if (reason.isNotEmpty) reason,
        ].join(' · '),
      ),
      trailing: Text(_statusLabel(fact.status)),
    );
  }
}

class _MarkdownToolbar extends StatelessWidget {
  const _MarkdownToolbar({
    required this.controller,
    required this.onChanged,
    this.enabled = true,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      children: [
        IconButton(
          onPressed: enabled ? () => _insert('**', '**') : null,
          tooltip: '加粗',
          icon: const Icon(Icons.format_bold),
        ),
        IconButton(
          onPressed: enabled ? () => _insert('_', '_') : null,
          tooltip: '斜体',
          icon: const Icon(Icons.format_italic),
        ),
        IconButton(
          onPressed: enabled ? () => _insert('## ', '') : null,
          tooltip: '标题',
          icon: const Icon(Icons.title),
        ),
        IconButton(
          onPressed: enabled ? () => _insert('- ', '') : null,
          tooltip: '列表',
          icon: const Icon(Icons.format_list_bulleted),
        ),
        IconButton(
          onPressed: enabled ? () => _insert('[', '](https://)') : null,
          tooltip: '链接',
          icon: const Icon(Icons.link),
        ),
      ],
    );
  }

  void _insert(String before, String after) {
    final selection = controller.selection;
    final start = selection.isValid ? selection.start : controller.text.length;
    final end = selection.isValid ? selection.end : controller.text.length;
    final selected = controller.text.substring(start, end);
    controller.text = controller.text.replaceRange(
      start,
      end,
      '$before$selected$after',
    );
    controller.selection = TextSelection.collapsed(
      offset: start + before.length + selected.length,
    );
    onChanged();
  }
}

class _DailyReviewField extends StatelessWidget {
  const _DailyReviewField({
    required this.controller,
    required this.label,
    required this.icon,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return ExternalField(
      label: label,
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        minLines: 2,
        maxLines: 5,
        decoration: InputDecoration(
          alignLabelWithHint: true,
          prefixIcon: Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: Icon(icon),
          ),
        ),
      ),
    );
  }
}

class _PreviewFields extends StatelessWidget {
  const _PreviewFields({required this.review});

  final WorkspaceRecord review;

  @override
  Widget build(BuildContext context) {
    final values = [
      ('今天完成了什么', review.data['completedToday']?.toString() ?? ''),
      ('遇到的问题', review.data['blockers']?.toString() ?? ''),
      ('明日计划', review.data['tomorrowPlan']?.toString() ?? ''),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('日回顾字段', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final value in values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: LogSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value.$1, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(value.$2.isEmpty ? '未填写' : value.$2),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _PreviewRelations extends StatelessWidget {
  const _PreviewRelations({
    required this.title,
    required this.icon,
    required this.records,
  });

  final String title;
  final IconData icon;
  final List<WorkspaceRecord> records;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        if (records.isEmpty)
          Text('无关联', style: TextStyle(color: context.tokens.mutedText))
        else
          LogSurface(
            child: Column(
              children: [
                for (final record in records)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(icon),
                    title: Text(record.title),
                    subtitle: Text(record.kind.name),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ReadOnlyAttachments extends StatelessWidget {
  const _ReadOnlyAttachments({required this.owner, required this.controller});

  final WorkspaceRecord owner;
  final WorkbenchController controller;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Attachment>>(
      future: controller.attachmentService.forRecord(owner.id),
      builder: (context, snapshot) {
        final attachments = snapshot.data ?? const <Attachment>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('附件', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            if (snapshot.connectionState != ConnectionState.done)
              const LinearProgressIndicator(),
            if (snapshot.connectionState == ConnectionState.done &&
                attachments.isEmpty)
              Text('暂无附件', style: TextStyle(color: context.tokens.mutedText)),
            for (final attachment in attachments)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.attachment_outlined),
                title: Text(attachment.fileName),
                subtitle: Text(formatAttachmentBytes(attachment.sizeBytes)),
              ),
          ],
        );
      },
    );
  }
}

ReviewPeriod _periodFor(ReviewPeriodType type, DateTime value) {
  final day = DateTime(value.year, value.month, value.day);
  return switch (type) {
    ReviewPeriodType.daily => ReviewPeriod(
      type: type,
      key: _dateKey(day),
      start: day,
      end: day.add(const Duration(days: 1)),
    ),
    ReviewPeriodType.weekly => _weekPeriod(day),
    ReviewPeriodType.monthly => ReviewPeriod(
      type: type,
      key: '${day.year}-${day.month.toString().padLeft(2, '0')}',
      start: DateTime(day.year, day.month),
      end: DateTime(day.year, day.month + 1),
    ),
    ReviewPeriodType.yearly => ReviewPeriod(
      type: type,
      key: '${day.year}',
      start: DateTime(day.year),
      end: DateTime(day.year + 1),
    ),
  };
}

ReviewPeriod _weekPeriod(DateTime day) {
  final monday = day.subtract(Duration(days: day.weekday - 1));
  final thursday = monday.add(const Duration(days: 3));
  final firstThursday = DateTime(thursday.year, 1, 4);
  final firstMonday = firstThursday.subtract(
    Duration(days: firstThursday.weekday - 1),
  );
  final week = thursday.difference(firstMonday).inDays ~/ 7 + 1;
  return ReviewPeriod(
    type: ReviewPeriodType.weekly,
    key: '${thursday.year}-W${week.toString().padLeft(2, '0')}',
    start: monday,
    end: monday.add(const Duration(days: 7)),
  );
}

String _periodLabel(ReviewPeriod period) => switch (period.type) {
  ReviewPeriodType.daily => formatFullDate(period.start),
  ReviewPeriodType.weekly =>
    '${formatShortDate(period.start)}—${formatShortDate(period.end.subtract(const Duration(days: 1)))}',
  ReviewPeriodType.monthly => '${period.start.year} 年 ${period.start.month} 月',
  ReviewPeriodType.yearly => '${period.start.year} 年',
};

String _dateKey(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _reviewLabel(ReviewPeriodType type) => switch (type) {
  ReviewPeriodType.daily => '日回顾',
  ReviewPeriodType.weekly => '周回顾',
  ReviewPeriodType.monthly => '月回顾',
  ReviewPeriodType.yearly => '年回顾',
};

String _statusLabel(String status) => switch (status) {
  WorkStatus.done => '完成',
  WorkStatus.failed => '失败',
  WorkStatus.skipped => '跳过',
  WorkStatus.rescheduled => '改期',
  WorkStatus.doing => '进行中',
  _ => '待处理',
};

IconData _statusIcon(String status) => switch (status) {
  WorkStatus.done => Icons.check_circle_outline,
  WorkStatus.failed => Icons.cancel_outlined,
  WorkStatus.skipped => Icons.skip_next_outlined,
  WorkStatus.rescheduled => Icons.event_repeat_outlined,
  WorkStatus.doing => Icons.play_circle_outline,
  _ => Icons.radio_button_unchecked,
};

Set<String> _ids(Object? value) => (value as List<dynamic>? ?? const [])
    .map((item) => item.toString())
    .toSet();

String _versionTitle(String body) {
  final first = body
      .split('\n')
      .map((line) => line.trim())
      .firstWhere((line) => line.isNotEmpty, orElse: () => '');
  return first.isEmpty ? '空正文' : first;
}
