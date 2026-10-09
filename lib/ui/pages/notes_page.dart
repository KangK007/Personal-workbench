import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../core/models/workspace_record.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../state/workbench_controller.dart';
import '../widgets/common.dart';
import '../widgets/attachment_panel.dart';
import '../widgets/ink_decoration.dart';
import '../widgets/markdown_editor_dialog.dart';
import '../widgets/workbench_illustration.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({
    super.key,
    required this.controller,
    this.showHeader = true,
  });

  final WorkbenchController controller;
  final bool showHeader;

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  String? selectedId;
  String query = '';
  bool mobileReading = false;
  final TextEditingController searchController = TextEditingController();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notes = widget.controller.notes.toList()
      ..sort((a, b) {
        if (a.favorite != b.favorite) return a.favorite ? -1 : 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
    final search = query.trim().toLowerCase();
    final visibleNotes = search.isEmpty
        ? notes
        : notes
              .where(
                (note) =>
                    note.title.toLowerCase().contains(search) ||
                    note.body.toLowerCase().contains(search) ||
                    note.tags.any((tag) => tag.toLowerCase().contains(search)),
              )
              .toList();
    final selected =
        visibleNotes.where((note) => note.id == selectedId).firstOrNull ??
        visibleNotes.firstOrNull;
    return Column(
      children: [
        if (widget.showHeader)
          PageHeader(
            maxWidth: AppLayout.formMax,
            title: '笔记',
            subtitle:
                '${notes.length.toString().padLeft(2, '0')} 条记录 · 标题 / 正文 / 标签',
            actions: [
              FilledButton.icon(
                onPressed: () =>
                    showMarkdownNoteEditor(context, widget.controller),
                icon: const Icon(Icons.add),
                label: const Text('新建笔记'),
              ),
            ],
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: () =>
                    showMarkdownNoteEditor(context, widget.controller),
                tooltip: '新建笔记',
                icon: const Icon(Icons.add),
              ),
            ),
          ),
        if (notes.isNotEmpty && !mobileReading)
          WorkbenchContentFrame(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: SearchBar(
                controller: searchController,
                hintText: '查找标题、正文或标签',
                leading: const Icon(Icons.search),
                trailing: query.isEmpty
                    ? null
                    : [
                        IconButton(
                          tooltip: '清除笔记搜索',
                          onPressed: () {
                            searchController.clear();
                            setState(() => query = '');
                          },
                          icon: const Icon(Icons.close),
                        ),
                      ],
                onChanged: (value) => setState(() => query = value),
              ),
            ),
          ),
        Expanded(
          child: notes.isEmpty
              ? Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const WorkbenchIllustration(
                          kind: WorkbenchIllustrationKind.notes,
                          width: 190,
                          height: 120,
                        ),
                        EmptyState(
                          icon: Icons.note_alt_outlined,
                          title: '还没有笔记',
                          message: '从顶部新增入口开始记录资料、思路或项目上下文。',
                          action: FilledButton.icon(
                            onPressed: () => showMarkdownNoteEditor(
                              context,
                              widget.controller,
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('新建笔记'),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : visibleNotes.isEmpty
              ? const EmptyState(
                  icon: Icons.manage_search_outlined,
                  title: '没有匹配的笔记',
                  message: '试试标题、正文中的其他词，或清除搜索条件。',
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final textScale =
                        MediaQuery.textScalerOf(context).scale(14) / 14;
                    final desktop =
                        constraints.maxWidth >=
                        AppLayout.masterDetailMin * textScale.clamp(1, 1.5);
                    if (!desktop) {
                      if (mobileReading && selected != null) {
                        return _NoteReader(
                          note: selected,
                          controller: widget.controller,
                          onBack: () => setState(() => mobileReading = false),
                          onEdit: () => _editNote(selected),
                          onDelete: () => _moveNoteToTrash(selected, notes),
                        );
                      }
                      return _NoteIndex(
                        notes: visibleNotes,
                        totalCount: notes.length,
                        favoriteCount: notes
                            .where((note) => note.favorite)
                            .length,
                        linkedCount: notes
                            .where((note) => note.projectId != null)
                            .length,
                        selectedId: selected?.id,
                        onSelected: (note) => setState(() {
                          selectedId = note.id;
                          mobileReading = true;
                        }),
                        onEdit: _editNote,
                        onDelete: (note) => _moveNoteToTrash(note, notes),
                      );
                    }
                    return WorkbenchContentFrame(
                      child: Row(
                        children: [
                          SizedBox(
                            width: (constraints.maxWidth * 0.28).clamp(
                              280.0,
                              320.0,
                            ),
                            child: _NoteIndex(
                              notes: visibleNotes,
                              totalCount: notes.length,
                              favoriteCount: notes
                                  .where((note) => note.favorite)
                                  .length,
                              linkedCount: notes
                                  .where((note) => note.projectId != null)
                                  .length,
                              selectedId: selected?.id,
                              onSelected: (note) =>
                                  setState(() => selectedId = note.id),
                              onEdit: _editNote,
                              onDelete: (note) => _moveNoteToTrash(note, notes),
                            ),
                          ),
                          const VerticalDivider(),
                          Expanded(
                            child: _NoteReader(
                              note: selected!,
                              controller: widget.controller,
                              onEdit: () => _editNote(selected),
                              onDelete: () => _moveNoteToTrash(selected, notes),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _editNote(WorkspaceRecord note) async {
    final updated = await showMarkdownNoteEditor(
      context,
      widget.controller,
      note: note,
    );
    if (updated != null && mounted) {
      setState(() => selectedId = updated.id);
    }
  }

  Future<void> _moveNoteToTrash(
    WorkspaceRecord note,
    List<WorkspaceRecord> visibleNotes,
  ) async {
    final confirmed =
        await showWorkbenchDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('将笔记移入回收站？'),
            content: Text('“${note.title}”将从笔记列表中隐藏。图片附件会继续保留，只有永久删除时才会清理。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.delete_outline),
                label: const Text('移入回收站'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    final index = visibleNotes.indexWhere((value) => value.id == note.id);
    final remaining = visibleNotes
        .where((value) => value.id != note.id)
        .toList();
    final nextIndex = index < remaining.length ? index : remaining.length - 1;
    await widget.controller.moveToTrash(note);
    if (!mounted) return;
    setState(() {
      selectedId = nextIndex >= 0 ? remaining[nextIndex].id : null;
      if (selectedId == null) mobileReading = false;
    });
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('笔记已移入回收站。'),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () async {
            await widget.controller.restoreFromTrash(note);
            if (mounted) setState(() => selectedId = note.id);
          },
        ),
      ),
    );
  }
}

class _NoteIndex extends StatelessWidget {
  const _NoteIndex({
    required this.notes,
    required this.totalCount,
    required this.favoriteCount,
    required this.linkedCount,
    required this.selectedId,
    required this.onSelected,
    required this.onEdit,
    required this.onDelete,
  });

  final List<WorkspaceRecord> notes;
  final int totalCount;
  final int favoriteCount;
  final int linkedCount;
  final String? selectedId;
  final ValueChanged<WorkspaceRecord> onSelected;
  final ValueChanged<WorkspaceRecord> onEdit;
  final ValueChanged<WorkspaceRecord> onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      key: const PageStorageKey('notes-index'),
      padding: const EdgeInsets.fromLTRB(
        12,
        8,
        12,
        AppSpacing.bottomNavClearance,
      ),
      itemCount: notes.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 3),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '知识索引',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const WorkbenchIllustration(
                      kind: WorkbenchIllustrationKind.notes,
                      width: 74,
                      height: 54,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    StatusPill(
                      label: '$totalCount 篇笔记',
                      icon: Icons.menu_book_outlined,
                    ),
                    StatusPill(
                      label: '$favoriteCount 篇收藏',
                      icon: Icons.star_outline,
                    ),
                    StatusPill(
                      label: '$linkedCount 篇关联项目',
                      icon: Icons.folder_outlined,
                    ),
                  ],
                ),
              ],
            ),
          );
        }
        final note = notes[index - 1];
        final selected = note.id == selectedId;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.control),
            border: Border(
              left: BorderSide(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: BorderRadius.circular(AppRadius.control),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              selected: selected,
              title: Text(
                note.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                note.body.isEmpty
                    ? formatDateTime(note.updatedAt)
                    : note.body.replaceAll('\n', ' '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (note.favorite)
                    Icon(Icons.star, size: 16, color: context.tokens.reward),
                  PopupMenuButton<String>(
                    tooltip: '笔记操作',
                    onSelected: (value) {
                      if (value == 'edit') onEdit(note);
                      if (value == 'trash') onDelete(note);
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('编辑')),
                      PopupMenuItem(value: 'trash', child: Text('移入回收站')),
                    ],
                  ),
                ],
              ),
              onTap: () => onSelected(note),
            ),
          ),
        );
      },
    );
  }
}

class _NoteReader extends StatelessWidget {
  const _NoteReader({
    required this.note,
    required this.controller,
    this.onBack,
    required this.onEdit,
    required this.onDelete,
  });

  final WorkspaceRecord note;
  final WorkbenchController controller;
  final VoidCallback? onBack;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppLayout.readingMax),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 80),
          children: [
            if (onBack != null) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('返回笔记索引'),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    note.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => controller.updateRecord(
                    note.copyWith(favorite: !note.favorite),
                  ),
                  tooltip: note.favorite ? '取消收藏' : '收藏',
                  icon: Icon(
                    note.favorite ? Icons.star : Icons.star_border,
                    color: note.favorite ? context.tokens.reward : null,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('编辑'),
                ),
                IconButton(
                  onPressed: onDelete,
                  tooltip: '移入回收站',
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusPill(
                  label: '更新 ${formatDateTime(note.updatedAt)}',
                  icon: Icons.schedule_outlined,
                ),
                if (note.projectId != null)
                  StatusPill(
                    label:
                        controller.projects
                            .where((project) => project.id == note.projectId)
                            .firstOrNull
                            ?.title ??
                        '已关联项目',
                    icon: Icons.folder_outlined,
                  ),
                if (note.favorite)
                  StatusPill(
                    label: '已收藏',
                    icon: Icons.star,
                    color: context.tokens.rewardContainer,
                    foreground: context.tokens.rewardOnContainer,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const TickDivider(height: 8),
            const SizedBox(height: 20),
            MarkdownBody(
              data: note.body.isEmpty ? '*暂无正文*' : note.body,
              selectable: true,
            ),
            const SizedBox(height: 24),
            AttachmentPanel(owner: note, controller: controller),
            if (note.tags.isNotEmpty) ...[
              const SizedBox(height: 28),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: note.tags
                    .map((tag) => Tag(label: tag, size: TagSize.small))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
