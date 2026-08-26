import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key, required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    const entries = [
      ('calendar', '日历', '安排任务与时间块', Icons.calendar_month_outlined),
      ('notes', '笔记', '沉淀资料与项目记录', Icons.note_alt_outlined),
      ('diary', '日记', '结构化记录每天的进展', Icons.menu_book_outlined),
      ('goals', '目标', '目标、截止日期与里程碑', Icons.flag_outlined),
      ('habits', '习惯', '完成、跳过与趋势回顾', Icons.event_repeat_outlined),
      ('review', '回顾', '每日收尾和每周复盘', Icons.insights_outlined),
      ('settings', '设置', '主题、同步、备份和回收站', Icons.settings_outlined),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 132),
      children: [
        Text('更多', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(
          '沉淀、成长与数据管理',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Column(
            children: [
              for (var index = 0; index < entries.length; index++) ...[
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  leading: Icon(entries[index].$4),
                  title: Text(entries[index].$2),
                  subtitle: Text(entries[index].$3),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onSelected(entries[index].$1),
                ),
                if (index != entries.length - 1) const Divider(),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
