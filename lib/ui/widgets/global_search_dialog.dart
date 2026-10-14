import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/workspace_record.dart';
import '../../state/workbench_controller.dart';
import 'common.dart';
import 'record_editor_dialog.dart';

Future<void> showGlobalSearch(
  BuildContext context,
  WorkbenchController controller, {
  RecordKind? initialKind,
}) {
  return showWorkbenchDialog<void>(
    context: context,
    builder: (context) {
      final size = MediaQuery.sizeOf(context);
      return Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: size.width < 600 ? 8 : 20,
          vertical: size.height < 600 ? 8 : 20,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 680),
          child: _GlobalSearch(
            controller: controller,
            initialKind: initialKind,
          ),
        ),
      );
    },
  );
}

class _GlobalSearch extends StatefulWidget {
  const _GlobalSearch({required this.controller, this.initialKind});

  final WorkbenchController controller;
  final RecordKind? initialKind;

  @override
  State<_GlobalSearch> createState() => _GlobalSearchState();
}

class _GlobalSearchState extends State<_GlobalSearch> {
  final queryController = TextEditingController();
  final resultScrollController = ScrollController();
  Timer? debounce;
  String query = '';
  String searchedQuery = '';
  bool searching = false;
  List<WorkspaceRecord> results = const [];
  late RecordKind? kindFilter;
  int selectedIndex = 0;

  static const _filterKinds = <RecordKind>[
    RecordKind.task,
    RecordKind.project,
    RecordKind.note,
    RecordKind.goal,
    RecordKind.link,
  ];

  @override
  void initState() {
    super.initState();
    kindFilter = widget.initialKind;
  }

  @override
  void dispose() {
    debounce?.cancel();
    queryController.dispose();
    resultScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final windowSize = MediaQuery.sizeOf(context);
    final compact = windowSize.width < 600;
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final rowHeight = 56.0 * scale.clamp(1.0, 2.0);
    final recentCount = widget.controller.recentSearchQueries.length;
    final preferredHeight = query.isEmpty
        ? recentCount == 0
              ? 300.0
              : 240.0 + recentCount * 56.0 * scale.clamp(1.0, 1.5)
        : searching || results.isEmpty
        ? 320.0
        : 680.0;
    final availableHeight = math.max(
      180.0,
      windowSize.height -
          MediaQuery.viewInsetsOf(context).bottom -
          (compact ? 16 : 40),
    );
    final panelHeight = math.min(
      math.min(preferredHeight, availableHeight),
      680.0,
    );
    final grouped = <RecordKind, List<WorkspaceRecord>>{};
    for (final record in results) {
      grouped.putIfAbsent(record.kind, () => []).add(record);
    }
    final entries = <({RecordKind kind, WorkspaceRecord? record, int index})>[];
    var resultIndex = 0;
    for (final group in grouped.entries) {
      entries.add((kind: group.key, record: null, index: -1));
      for (final record in group.value) {
        entries.add((kind: group.key, record: record, index: resultIndex++));
      }
    }
    return SizedBox(
      key: const ValueKey('global-search-panel'),
      height: panelHeight,
      child: Focus(
        onKeyEvent: _handleKey,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 12 : 20,
                16,
                compact ? 12 : 20,
                0,
              ),
              child: SearchBar(
                controller: queryController,
                autoFocus: true,
                hintText: compact ? '搜索工作台' : '搜索任务、项目、笔记、日记、目标和链接',
                leading: const Icon(Icons.search),
                trailing: [
                  if (queryController.text.isNotEmpty)
                    IconButton(
                      onPressed: () {
                        queryController.clear();
                        _onQueryChanged('');
                      },
                      tooltip: '清空搜索',
                      icon: const Icon(Icons.backspace_outlined),
                    ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    tooltip: '关闭',
                    icon: const Icon(Icons.close),
                  ),
                ],
                onChanged: _onQueryChanged,
                onSubmitted: (_) => _openSelected(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48 * scale.clamp(1.0, 1.35),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 20),
                children: [
                  _kindChip(null, '全部'),
                  for (final kind in _filterKinds) ...[
                    const SizedBox(width: 8),
                    _kindChip(kind, kind.label),
                  ],
                  if (kindFilter != null &&
                      !_filterKinds.contains(kindFilter)) ...[
                    const SizedBox(width: 8),
                    _kindChip(kindFilter, kindFilter!.label),
                  ],
                ],
              ),
            ),
            if (searching)
              const LinearProgressIndicator(minHeight: 2)
            else
              const SizedBox(height: 2),
            const Divider(height: 1),
            Expanded(
              child: AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 120),
                child: query.isEmpty
                    ? KeyedSubtree(
                        key: const ValueKey('search-empty'),
                        child: _emptyContent(),
                      )
                    : searching
                    ? const Center(
                        key: ValueKey('search-loading'),
                        child: Text('正在搜索…'),
                      )
                    : results.isEmpty
                    ? KeyedSubtree(
                        key: const ValueKey('search-no-results'),
                        child: _message(
                          Icons.search_off,
                          '没有匹配内容',
                          '可以换一个关键词或检查分类。',
                        ),
                      )
                    : Semantics(
                        key: ValueKey(
                          'search-results-$searchedQuery-${kindFilter?.name}',
                        ),
                        liveRegion: true,
                        label: '找到 ${results.length} 条结果',
                        child: ListView.builder(
                          controller: resultScrollController,
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                          itemCount: entries.length,
                          itemBuilder: (context, index) {
                            final entry = entries[index];
                            final record = entry.record;
                            if (record == null) {
                              return Padding(
                                padding: EdgeInsets.fromLTRB(
                                  12,
                                  index == 0 ? 8 : 20,
                                  12,
                                  8,
                                ),
                                child: Text(
                                  entry.kind.label,
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                              );
                            }
                            return _resultRow(record, entry.index, rowHeight);
                          },
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kindChip(RecordKind? kind, String label) => FilterChip(
    label: Text(label),
    selected: kindFilter == kind,
    onSelected: (_) {
      setState(() {
        kindFilter = kind;
        selectedIndex = 0;
      });
      if (query.isNotEmpty) _runSearch(query);
    },
  );

  Widget _emptyContent() {
    final recent = widget.controller.recentSearchQueries;
    if (recent.isEmpty) {
      return _message(Icons.manage_search, '输入关键词开始搜索', '标题、正文和标签均可检索。');
    }
    return ListView(
      key: const ValueKey('recent-searches'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '最近搜索',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            TextButton(
              onPressed: () =>
                  setState(widget.controller.clearRecentSearchQueries),
              child: const Text('清除记录'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final value in recent)
          ListTile(
            leading: const Icon(Icons.history),
            title: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
            minVerticalPadding: 12,
            onTap: () {
              queryController.text = value;
              queryController.selection = TextSelection.collapsed(
                offset: value.length,
              );
              _onQueryChanged(value);
            },
          ),
      ],
    );
  }

  Widget _message(IconData icon, String title, String subtitle) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );

  Widget _resultRow(WorkspaceRecord record, int index, double height) {
    final selected = selectedIndex == index;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: () {
          setState(() => selectedIndex = index);
          _openRecord(record);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primaryContainer.withValues(alpha: 0.55)
                : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(iconForKind(record.kind), size: 20, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _HighlightedText(
                      text: record.title,
                      query: searchedQuery,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (record.body.isNotEmpty)
                      _HighlightedText(
                        text: record.body.replaceAll(RegExp(r'\s+'), ' '),
                        query: searchedQuery,
                        maxLines: 1,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(fontSize: 13),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || results.isEmpty) {
      return KeyEventResult.ignored;
    }
    final composing = queryController.value.composing;
    if (composing.isValid && !composing.isCollapsed) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
        event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final direction = event.logicalKey == LogicalKeyboardKey.arrowDown
          ? 1
          : -1;
      setState(
        () => selectedIndex = (selectedIndex + direction).clamp(
          0,
          results.length - 1,
        ),
      );
      if (resultScrollController.hasClients) {
        _revealSelected();
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      _openSelected();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _revealSelected() {
    final position = resultScrollController.positions.last;
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final rowHeight = 56.0 * scale.clamp(1.0, 2.0);
    final headingTextHeight = 24.0 * scale;
    var rowTop = 8.0;
    RecordKind? previousKind;
    for (var index = 0; index <= selectedIndex; index++) {
      final kind = results[index].kind;
      if (kind != previousKind) {
        rowTop += (previousKind == null ? 16.0 : 28.0) + headingTextHeight;
        previousKind = kind;
      }
      if (index < selectedIndex) rowTop += rowHeight;
    }
    final rowBottom = rowTop + rowHeight;
    final visibleTop = position.pixels;
    final visibleBottom = visibleTop + position.viewportDimension;
    final target = rowTop < visibleTop
        ? rowTop
        : rowBottom > visibleBottom
        ? rowBottom - position.viewportDimension
        : null;
    if (target == null) return;
    final clamped = target.clamp(0.0, position.maxScrollExtent);
    if (MediaQuery.disableAnimationsOf(context)) {
      resultScrollController.jumpTo(clamped);
    } else {
      resultScrollController.animateTo(
        clamped,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    }
  }

  void _openSelected() {
    if (results.isEmpty) return;
    _openRecord(results[selectedIndex]);
  }

  Future<void> _openRecord(WorkspaceRecord record) async {
    widget.controller.rememberSearchQuery(searchedQuery);
    if (_isEditable(record.kind)) {
      await showRecordEditor(
        context,
        widget.controller,
        kind: record.kind,
        record: record,
      );
      if (mounted && query.isNotEmpty) _runSearch(query);
      return;
    }
    await showWorkbenchDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(record.title),
        content: SingleChildScrollView(
          child: Text(record.body.isEmpty ? record.kind.label : record.body),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _onQueryChanged(String value) {
    debounce?.cancel();
    final next = value.trim();
    setState(() {
      query = next;
      searching = next.isNotEmpty;
      results = const [];
      selectedIndex = 0;
      if (next.isEmpty) {
        searchedQuery = '';
      }
    });
    if (next.isEmpty) return;
    debounce = Timer(const Duration(milliseconds: 200), () => _runSearch(next));
  }

  void _runSearch(String value) {
    final found = widget.controller
        .search(value)
        .where((record) => record.data['recordType'] != 'taskDefinition')
        .where((record) => kindFilter == null || record.kind == kindFilter)
        .take(50)
        .toList();
    final byKind = <RecordKind, List<WorkspaceRecord>>{};
    for (final record in found) {
      byKind.putIfAbsent(record.kind, () => []).add(record);
    }
    if (!mounted || query != value) return;
    setState(() {
      searchedQuery = value;
      results = [for (final group in byKind.values) ...group];
      selectedIndex = 0;
      searching = false;
    });
  }

  bool _isEditable(RecordKind kind) => const {
    RecordKind.task,
    RecordKind.project,
    RecordKind.note,
    RecordKind.link,
    RecordKind.goal,
    RecordKind.milestone,
    RecordKind.habit,
  }.contains(kind);
}

class _HighlightedText extends StatelessWidget {
  const _HighlightedText({
    required this.text,
    required this.query,
    required this.maxLines,
    this.style,
  });

  final String text;
  final String query;
  final int maxLines;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final lower = text.toLowerCase();
    final highlighted = List<bool>.filled(text.length, false);
    for (final term
        in query
            .toLowerCase()
            .split(RegExp(r'\s+'))
            .where((value) => value.isNotEmpty)) {
      var start = 0;
      while (start < lower.length) {
        final index = lower.indexOf(term, start);
        if (index < 0) break;
        for (var offset = index; offset < index + term.length; offset++) {
          highlighted[offset] = true;
        }
        start = index + term.length;
      }
    }

    final spans = <TextSpan>[];
    var start = 0;
    while (start < text.length) {
      final marked = highlighted[start];
      var end = start + 1;
      while (end < text.length && highlighted[end] == marked) {
        end++;
      }
      spans.add(
        TextSpan(
          text: text.substring(start, end),
          style: marked
              ? TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  fontWeight: FontWeight.w700,
                )
              : null,
        ),
      );
      start = end;
    }
    return Semantics(
      label: text,
      child: ExcludeSemantics(
        child: Text.rich(
          TextSpan(style: style, children: spans),
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
