import 'package:flutter/material.dart';

import '../../core/models/workspace_record.dart';
import '../../core/utils/formatters.dart';
import '../../state/workbench_controller.dart';
import '../widgets/common.dart';

class DiaryPage extends StatefulWidget {
  const DiaryPage({
    super.key,
    required this.controller,
    this.showHeader = true,
    this.showSearch = true,
  });

  final WorkbenchController controller;
  final bool showHeader;
  final bool showSearch;

  @override
  State<DiaryPage> createState() => _DiaryPageState();
}

class _DiaryPageState extends State<DiaryPage> {
  late DateTime selectedDay;
  final titleController = TextEditingController();
  final bodyController = TextEditingController();
  final completedController = TextEditingController();
  final blockersController = TextEditingController();
  final tomorrowController = TextEditingController();
  final searchController = TextEditingController();
  int? mood;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    selectedDay = startOfDay(widget.controller.currentTime());
    _loadDay();
  }

  @override
  void dispose() {
    titleController.dispose();
    bodyController.dispose();
    completedController.dispose();
    blockersController.dispose();
    tomorrowController.dispose();
    searchController.dispose();
    super.dispose();
  }

  void _loadDay() {
    final diary = widget.controller.diaryForDay(selectedDay);
    titleController.text = diary?.title ?? '今日回顾';
    bodyController.text = diary?.body ?? '';
    completedController.text = diary?.data['completedToday']?.toString() ?? '';
    blockersController.text = diary?.data['blockers']?.toString() ?? '';
    tomorrowController.text = diary?.data['tomorrowPlan']?.toString() ?? '';
    mood = (diary?.data['mood'] as num?)?.toInt();
  }

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 980;
    return Column(
      children: [
        if (widget.showHeader)
          PageHeader(title: '日记', subtitle: '结构化记录完成、问题和下一步'),
        if (widget.showHeader) const Divider(),
        Expanded(
          child: desktop
              ? Row(
                  children: [
                    SizedBox(width: 340, child: _navigationPanel()),
                    const VerticalDivider(),
                    Expanded(child: _editor()),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 132),
                  children: [
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(formatFullDate(selectedDay)),
                      leading: const Icon(Icons.calendar_month_outlined),
                      children: [SizedBox(height: 330, child: _calendar())],
                    ),
                    const SizedBox(height: 10),
                    _editorContents(),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _navigationPanel() {
    final query = searchController.text.trim();
    final matches = query.isEmpty
        ? const <WorkspaceRecord>[]
        : widget.controller
              .search(query)
              .where((record) => record.kind == RecordKind.diary)
              .toList();
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        SizedBox(height: 330, child: _calendar()),
        const SizedBox(height: 12),
        if (widget.showSearch)
          SearchBar(
            controller: searchController,
            hintText: '搜索日记',
            leading: const Icon(Icons.search),
            onChanged: (_) => setState(() {}),
          ),
        if (widget.showSearch && query.isNotEmpty) ...[
          const SectionHeading(title: '搜索结果'),
          if (matches.isEmpty)
            const Text('没有匹配的日记。')
          else
            ...matches.map(
              (diary) => ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: Text(diary.title),
                subtitle: Text(
                  diary.scheduledFor == null
                      ? ''
                      : formatShortDate(diary.scheduledFor!),
                ),
                onTap: () {
                  setState(() {
                    selectedDay = startOfDay(
                      diary.scheduledFor ?? widget.controller.currentTime(),
                    );
                    _loadDay();
                  });
                },
              ),
            ),
        ],
      ],
    );
  }

  Widget _calendar() {
    return CalendarDatePicker(
      initialDate: selectedDay,
      currentDate: widget.controller.currentTime(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      onDateChanged: (value) {
        setState(() {
          selectedDay = startOfDay(value);
          _loadDay();
        });
      },
    );
  }

  Widget _editor() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 60),
      children: [_editorContents()],
    );
  }

  Widget _editorContents() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                formatFullDate(selectedDay),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (widget.controller.diaryForDay(selectedDay) != null)
              const StatusPill(label: '已保存'),
          ],
        ),
        const SizedBox(height: 18),
        TextField(
          controller: titleController,
          decoration: const InputDecoration(labelText: '标题'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: bodyController,
          minLines: 5,
          maxLines: 12,
          decoration: const InputDecoration(
            labelText: '正文',
            hintText: '自由记录今天发生的事',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 18),
        Text('今天的状态', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          emptySelectionAllowed: true,
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 1, label: Text('低')),
            ButtonSegment(value: 2, label: Text('偏低')),
            ButtonSegment(value: 3, label: Text('一般')),
            ButtonSegment(value: 4, label: Text('较好')),
            ButtonSegment(value: 5, label: Text('很好')),
          ],
          selected: mood == null ? {} : {mood!},
          onSelectionChanged: (value) =>
              setState(() => mood = value.firstOrNull),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: completedController,
          minLines: 2,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: '今日完成',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: blockersController,
          minLines: 2,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: '遇到的问题',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: tomorrowController,
          minLines: 2,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: '明日计划',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('保存日记'),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      await widget.controller.saveDiary(
        day: selectedDay,
        title: titleController.text,
        body: bodyController.text,
        completedToday: completedController.text,
        blockers: blockersController.text,
        tomorrowPlan: tomorrowController.text,
        mood: mood,
      );
      if (!mounted) return;
      showWorkbenchSnackBar(context, const SnackBar(content: Text('日记已保存到本地')));
    } catch (error) {
      if (!mounted) return;
      showWorkbenchSnackBar(context, SnackBar(content: Text('保存失败：$error')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}
