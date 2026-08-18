import 'dart:async';

import 'package:flutter/material.dart';

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
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 680),
        child: _GlobalSearch(controller: controller, initialKind: initialKind),
      ),
    ),
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
  Timer? debounce;
  String query = '';
  String searchedQuery = '';
  bool searching = false;
  List<WorkspaceRecord> results = const [];
  late RecordKind? kindFilter;

  @override
  void initState() {
    super.initState();
    kindFilter = widget.initialKind;
  }

  @override
  void dispose() {
    debounce?.cancel();
    queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SearchBar(
            controller: queryController,
            autoFocus: true,
            hintText: '搜索任务、项目、笔记、日记、目标和链接',
            leading: const Icon(Icons.search),
            trailing: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                tooltip: '关闭',
                icon: const Icon(Icons.close),
              ),
            ],
            onChanged: _onQueryChanged,
          ),
        ),
        if (widget.initialKind != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilterChip(
                label: Text(kindFilter == RecordKind.note ? '仅笔记' : '全部内容'),
                selected: kindFilter == RecordKind.note,
                onSelected: (_) {
                  setState(() {
                    kindFilter = kindFilter == null ? widget.initialKind : null;
                  });
                  if (query.isNotEmpty) _runSearch(query);
                },
              ),
            ),
          ),
        if (searching) const LinearProgressIndicator(minHeight: 2),
        const Divider(),
        Expanded(
          child: query.isEmpty
              ? const EmptyState(
                  icon: Icons.manage_search,
                  title: '输入关键词开始搜索',
                  message: '标题、正文、标签、类型和关联字段均可检索。',
                )
              : !searching && results.isEmpty
              ? const EmptyState(
                  icon: Icons.search_off,
                  title: '没有匹配内容',
                  message: '可以换一个关键词或检查标签。',
                )
              : Semantics(
                  liveRegion: true,
                  label: searching ? '正在搜索' : '找到 ${results.length} 条结果',
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: results.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, index) {
                      final record = results[index];
                      final subtitle = record.body.isEmpty
                          ? record.kind.label
                          : record.body;
                      return ListTile(
                        leading: Icon(iconForKind(record.kind)),
                        title: _HighlightedText(
                          text: record.title,
                          query: searchedQuery,
                          maxLines: 1,
                        ),
                        subtitle: _HighlightedText(
                          text: subtitle,
                          query: searchedQuery,
                          maxLines: 2,
                        ),
                        trailing: StatusPill(label: record.kind.label),
                        onTap: () async {
                          if (_isEditable(record.kind)) {
                            await showRecordEditor(
                              context,
                              widget.controller,
                              kind: record.kind,
                              record: record,
                            );
                            if (mounted) _runSearch(query);
                          }
                        },
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  void _onQueryChanged(String value) {
    debounce?.cancel();
    final next = value.trim();
    setState(() {
      query = next;
      searching = next.isNotEmpty;
      results = const [];
      if (next.isEmpty) {
        searchedQuery = '';
      }
    });
    if (next.isEmpty) return;
    debounce = Timer(const Duration(milliseconds: 250), () => _runSearch(next));
  }

  void _runSearch(String value) {
    final found = widget.controller
        .search(value)
        .where((record) => kindFilter == null || record.kind == kindFilter)
        .take(50)
        .toList();
    if (!mounted || query != value) return;
    setState(() {
      searchedQuery = value;
      results = found;
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
  });

  final String text;
  final String query;
  final int maxLines;

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
          TextSpan(children: spans),
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
