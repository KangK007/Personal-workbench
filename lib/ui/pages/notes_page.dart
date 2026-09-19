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

  @override
  Widget build(BuildContext context) {
    final notes = widget.controller.notes.toList()
      ..sort((a, b) {
        if (a.favorite != b.favorite) return a.favorite ? -1 : 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
    final selected =
        notes.where((note) => note.id == selectedId).firstOrNull ??
        notes.firstOrNull;
    return Column(
      children: [
        if (widget.showHeader)
          PageHeader(
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
        Expanded(
          child: notes.isEmpty
              ? EmptyState(
                  icon: Icons.note_alt_outlined,
                  title: '还没有笔记',
                  message: '从顶部新增入口开始记录资料、思路或项目上下文。',
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final desktop = constraints.maxWidth >= 800;
                    if (!desktop) {
                      return _NoteIndex(
                        notes: notes,
                        selectedId: selected?.id,
                        onSelected: _editNote,
                        onEdit: _editNote,
                        onDelete: (note) => _moveNoteToTrash(note, notes),
                      );
                    }
                    return Row(
                      children: [
                        SizedBox(
                          width: 330,
                          child: _NoteIndex(
                            notes: notes,
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
    setState(
      () => selectedId = nextIndex >= 0 ? remaining[nextIndex].id : null,
    );
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
    required this.selectedId,
    required this.onSelected,
    required this.onEdit,
    required this.onDelete,
  });

  final List<WorkspaceRecord> notes;
  final String? selectedId;
  final ValueChanged<WorkspaceRecord> onSelected;
  final ValueChanged<WorkspaceRecord> onEdit;
  final ValueChanged<WorkspaceRecord> onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        12,
        8,
        12,
        AppSpacing.bottomNavClearance,
      ),
      itemCount: notes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 3),
      itemBuilder: (context, index) {
        final note = notes[index];
        final selected = note.id == selectedId;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border(
              left: BorderSide(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
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
        );
      },
    );
  }
}

class _NoteReader extends StatelessWidget {
  const _NoteReader({
    required this.note,
    required this.controller,
    required this.onEdit,
    required this.onDelete,
  });

  final WorkspaceRecord note;
  final WorkbenchController controller;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 80),
      children: [
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
        const SizedBox(height: 4),
        Text(
          formatDateTime(note.updatedAt),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.tokens.mutedText),
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
    );
  }
}
