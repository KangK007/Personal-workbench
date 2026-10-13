import 'package:flutter/material.dart';

import '../../core/models/workspace_record.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../state/workbench_controller.dart';
import 'jade_icon.dart';
import 'markdown_editor_dialog.dart';
import 'solid_panel.dart';
import 'workbench_layout.dart';

enum _RecordFilter { all, notes, reviews }

/// A shared visual list for a project's notes and period reviews.
class ProjectKnowledgeSection extends StatefulWidget {
  const ProjectKnowledgeSection({
    super.key,
    required this.controller,
    required this.project,
    required this.notes,
    required this.reviews,
    required this.onOpenReview,
  });

  final WorkbenchController controller;
  final WorkspaceRecord project;
  final List<WorkspaceRecord> notes;
  final List<WorkspaceRecord> reviews;
  final ValueChanged<WorkspaceRecord?>? onOpenReview;

  @override
  State<ProjectKnowledgeSection> createState() =>
      _ProjectKnowledgeSectionState();
}

class _ProjectKnowledgeSectionState extends State<ProjectKnowledgeSection> {
  _RecordFilter _filter = _RecordFilter.all;

  bool _isReview(WorkspaceRecord record) =>
      record.data['recordType'] == 'periodReview';

  String _kindLabel(WorkspaceRecord record) {
    if (!_isReview(record)) return '笔记';
    return switch (record.data['periodType']) {
      'weekly' => '周回顾',
      'monthly' => '月回顾',
      'yearly' => '年回顾',
      _ => '日回顾',
    };
  }

  Widget _recordCard(WorkspaceRecord record) {
    final theme = Theme.of(context);
    final clay = context.accents.clay;
    final review = _isReview(record);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: review
            ? widget.onOpenReview == null
                  ? null
                  : () => widget.onOpenReview!(record)
            : () => showMarkdownNoteEditor(
                context,
                widget.controller,
                note: record,
              ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                review ? Icons.auto_graph_outlined : Icons.description_outlined,
                color: clay.color,
                size: AppIconSize.md,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          _kindLabel(record),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: clay.color,
                          ),
                        ),
                        Text(
                          formatShortDate(record.updatedAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: AppFonts.numeric,
                            fontSize: 13,
                            color: context.tokens.mutedText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      record.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (record.body.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        record.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                          color: context.tokens.mutedText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (review && widget.onOpenReview != null)
                const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final records = [
      if (_filter != _RecordFilter.reviews) ...widget.notes,
      if (_filter != _RecordFilter.notes) ...widget.reviews,
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final clay = context.accents.clay;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              ChoiceChip(
                label: Text(
                  '全部 ${widget.notes.length + widget.reviews.length}',
                ),
                selected: _filter == _RecordFilter.all,
                onSelected: (_) => setState(() => _filter = _RecordFilter.all),
              ),
              ChoiceChip(
                label: Text('笔记 ${widget.notes.length}'),
                selected: _filter == _RecordFilter.notes,
                onSelected: (_) =>
                    setState(() => _filter = _RecordFilter.notes),
              ),
              ChoiceChip(
                label: Text('回顾 ${widget.reviews.length}'),
                selected: _filter == _RecordFilter.reviews,
                onSelected: (_) =>
                    setState(() => _filter = _RecordFilter.reviews),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              FilledButton.icon(
                onPressed: () => showMarkdownNoteEditor(
                  context,
                  widget.controller,
                  initialProjectId: widget.project.id,
                ),
                icon: const Icon(Icons.add),
                label: const Text('新增笔记'),
              ),
              OutlinedButton.icon(
                onPressed: widget.onOpenReview == null
                    ? null
                    : () => widget.onOpenReview!(null),
                icon: const Icon(Icons.insights_outlined),
                label: const Text('打开当前回顾'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AnimatedSwitcher(
            duration: reducedMotion
                ? Duration.zero
                : const Duration(milliseconds: 180),
            child: records.isEmpty
                ? SolidPanel(
                    key: ValueKey('project-knowledge-empty-${_filter.name}'),
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      children: [
                        JadeIcon(
                          glyph: JadeGlyph.records,
                          size: AppIconSize.lg,
                          color: clay.color,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            _filter == _RecordFilter.reviews
                                ? '还没有关联回顾'
                                : _filter == _RecordFilter.notes
                                ? '还没有关联笔记'
                                : '这里还没有笔记或回顾',
                          ),
                        ),
                      ],
                    ),
                  )
                : ConstrainedBox(
                    key: ValueKey(
                      'project-knowledge-${_filter.name}-${Object.hashAll(records.map((record) => record.id))}',
                    ),
                    constraints: BoxConstraints(
                      maxHeight:
                          (WorkbenchViewport.sizeOf(context).height * 0.65)
                              .clamp(240.0, 680.0),
                    ),
                    child: ListView.builder(
                      key: const PageStorageKey('project-knowledge-scroll'),
                      primary: false,
                      shrinkWrap: true,
                      itemCount: records.length,
                      itemBuilder: (context, index) {
                        final record = records[index];
                        final date = formatShortDate(record.updatedAt);
                        final showDate =
                            index == 0 ||
                            date !=
                                formatShortDate(records[index - 1].updatedAt);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (showDate)
                              Padding(
                                padding: EdgeInsets.only(
                                  top: index == 0 ? 0 : AppSpacing.lg,
                                  bottom: AppSpacing.sm,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      date,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            fontFamily: AppFonts.numeric,
                                            fontSize: 13,
                                            color: context.tokens.mutedText,
                                          ),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    const Expanded(child: Divider()),
                                  ],
                                ),
                              ),
                            _recordCard(record),
                          ],
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
