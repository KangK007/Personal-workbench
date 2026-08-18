import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/models/workspace_record.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/backup_service.dart';
import '../../services/notification_service.dart';
import '../../state/workbench_controller.dart';
import '../widgets/common.dart';

String _reviewName(ReviewPeriodType type) => switch (type) {
  ReviewPeriodType.daily => '日回顾',
  ReviewPeriodType.weekly => '周回顾',
  ReviewPeriodType.monthly => '月回顾',
  ReviewPeriodType.yearly => '年回顾',
};

IconData _reviewIcon(ReviewPeriodType type) => switch (type) {
  ReviewPeriodType.daily => Icons.today_outlined,
  ReviewPeriodType.weekly => Icons.view_week_outlined,
  ReviewPeriodType.monthly => Icons.calendar_month_outlined,
  ReviewPeriodType.yearly => Icons.event_note_outlined,
};

String _reviewSchedule(ReviewPeriodType type, WorkbenchController controller) {
  final prefix = switch (type) {
    ReviewPeriodType.daily => '每日',
    ReviewPeriodType.weekly => '每周日',
    ReviewPeriodType.monthly => '每月末',
    ReviewPeriodType.yearly => '每年 12 月 31 日',
  };
  return '$prefix ${controller.reviewReminderTime(type)}';
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.controller,
    this.showHeader = true,
  });

  final WorkbenchController controller;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showHeader) ...[
          const PageHeader(title: '设置', subtitle: '外观、提醒、同步与本地数据管理'),
          const Divider(),
        ],
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.sizeOf(context).width < AppBreakpoints.compact
                  ? 132
                  : 96,
            ),
            children: [
              _CloudSection(controller: controller),
              const SizedBox(height: 16),
              _AppearanceSection(
                controller: controller,
                onEditAlias: () => _editAlias(context),
              ),
              const SizedBox(height: 16),
              _Section(
                title: '任务与周期',
                children: [
                  ListTile(
                    leading: const _SettingsIcon(Icons.schedule_outlined),
                    title: const Text('逻辑日分界'),
                    subtitle: const Text('修改只影响今后生成的任务实例'),
                    trailing: DropdownButton<int>(
                      value: controller.logicalDayBoundaryHour,
                      underline: const SizedBox.shrink(),
                      items: [
                        for (var hour = 0; hour <= 6; hour++)
                          DropdownMenuItem(
                            value: hour,
                            child: Text(
                              '${hour.toString().padLeft(2, '0')}:00',
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          controller.setLogicalDayBoundaryHour(value);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _Section(
                title: '专注与检测',
                children: [
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    secondary: const _SettingsIcon(Icons.visibility_outlined),
                    title: const Text('前台应用检测'),
                    subtitle: const Text('默认关闭；只保存应用标识、开始时间、持续时间和预设'),
                    value: controller.foregroundDetectionEnabled,
                    onChanged: controller.setForegroundDetectionEnabled,
                  ),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    secondary: const _SettingsIcon(Icons.open_in_new_outlined),
                    title: const Text('定时专注显示工作台'),
                    subtitle: const Text('到点先提醒并恢复窗口；Windows 拒绝置前时闪烁任务栏'),
                    value: controller.bringToFrontOnFocusSchedule,
                    onChanged: controller.setBringToFrontOnFocusSchedule,
                  ),
                  ListTile(
                    leading: const _SettingsIcon(Icons.delete_sweep_outlined),
                    title: const Text('前台日志'),
                    subtitle: const Text('本地保留 30 天，不上传云端'),
                    trailing: TextButton(
                      onPressed: () => _clearForegroundHistory(context),
                      child: const Text('立即清除'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _Section(
                title: '回顾与提醒',
                children: [
                  for (final type in activeReviewPeriodTypes)
                    SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      secondary: _SettingsIcon(_reviewIcon(type)),
                      title: Text(_reviewName(type)),
                      subtitle: Text(_reviewSchedule(type, controller)),
                      value: controller.reviewReminderEnabled(type),
                      onChanged: (enabled) => controller.setReviewReminder(
                        type: type,
                        enabled: enabled,
                      ),
                    ),
                  for (final type in activeReviewPeriodTypes)
                    ListTile(
                      leading: const SizedBox(width: 34),
                      title: Text('修改${_reviewName(type)}时间'),
                      trailing: OutlinedButton(
                        onPressed: () => _editReviewReminder(context, type),
                        child: Text(controller.reviewReminderTime(type)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _Section(
                title: '通知与后台',
                children: [
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    secondary: const _SettingsIcon(Icons.minimize_outlined),
                    title: const Text('关闭窗口时最小化到托盘'),
                    subtitle: const Text('启用后请通过托盘菜单退出应用'),
                    value: controller.closeToTray,
                    onChanged: controller.windowsActivityService.supported
                        ? controller.setCloseToTray
                        : null,
                  ),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    secondary: const _SettingsIcon(Icons.power_settings_new_outlined),
                    title: const Text('开机启动'),
                    subtitle: const Text('默认关闭，仅当前 Windows 用户'),
                    value: controller.startupEnabled,
                    onChanged: controller.windowsActivityService.supported
                        ? controller.setStartupEnabled
                        : null,
                  ),
                  ListTile(
                    leading: const _SettingsIcon(Icons.exit_to_app_outlined),
                    title: const Text('真正退出'),
                    subtitle: const Text('停止托盘、计时和后台提醒'),
                    trailing: OutlinedButton(
                      onPressed: controller.windowsActivityService.supported
                          ? controller.windowsActivityService.exitApplication
                          : null,
                      child: const Text('退出'),
                    ),
                  ),
                  ListTile(
                    leading: const _SettingsIcon(Icons.notifications_outlined),
                    title: const Text('任务和休息提醒'),
                    subtitle: Text(
                      controller.notificationService.supportsSystemNotifications
                          ? '由 Android 或 Windows 系统管理通知'
                          : '当前平台仅显示应用内提示',
                    ),
                    trailing: OutlinedButton(
                      onPressed:
                          controller
                              .notificationService
                              .supportsSystemNotifications
                          ? () => _requestNotifications(context)
                          : null,
                      child: const Text('申请权限'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _Section(
                title: '数据与备份',
                children: [
                  ListTile(
                    leading: const _SettingsIcon(Icons.lock_outline),
                    title: const Text('创建加密备份'),
                    subtitle: const Text('保存全部本地内容，密码至少 8 个字符'),
                    trailing: FilledButton.tonal(
                      onPressed: () => _createBackup(context),
                      child: const Text('备份'),
                    ),
                  ),
                  ListTile(
                    leading: const _SettingsIcon(Icons.restore_outlined),
                    title: const Text('预览并恢复备份'),
                    subtitle: const Text('确认数据范围后才会替换当前数据'),
                    trailing: OutlinedButton(
                      onPressed: () => _restoreBackup(context),
                      child: const Text('选择文件'),
                    ),
                  ),
                  ListTile(
                    leading: const _SettingsIcon(Icons.download_outlined),
                    title: const Text('导出 JSON'),
                    subtitle: const Text('生成可读取的完整数据副本'),
                    trailing: OutlinedButton(
                      onPressed: () => _exportJson(context),
                      child: const Text('导出'),
                    ),
                  ),
                  ListTile(
                    leading: const _SettingsIcon(Icons.toll_outlined),
                    title: const Text('导出本地游戏状态'),
                    subtitle: const Text('把积分和押注账本加入 JSON；这些数据不会上传云端'),
                    trailing: OutlinedButton(
                      onPressed: () =>
                          _exportJson(context, includeGameState: true),
                      child: const Text('含游戏状态'),
                    ),
                  ),
                  ListTile(
                    leading: const _SettingsIcon(Icons.upload_file_outlined),
                    title: const Text('导入文件'),
                    subtitle: const Text('支持 JSON、CSV、Markdown 和 TXT'),
                    trailing: OutlinedButton(
                      onPressed: () => _importFile(context),
                      child: const Text('导入'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _ExperimentalSection(controller: controller),
              const SizedBox(height: 16),
              _TrashSection(controller: controller),
              const SizedBox(height: 16),
              _Section(
                title: '示例内容',
                children: [
                  ListTile(
                    leading: const _SettingsIcon(Icons.cleaning_services_outlined),
                    title: const Text('清除首次使用示例'),
                    subtitle: const Text('只移除带有示例标记的内容'),
                    trailing: TextButton(
                      onPressed: () => _clearSamples(context),
                      child: const Text('清除'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                '个人工作台 0.1',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _requestNotifications(BuildContext context) async {
    try {
      final granted = await controller.notificationService.requestPermission();
      if (!context.mounted) return;
      if (granted) {
        await controller.notificationService.showNow(
          id: stableNotificationId('notification-permission-confirmation'),
          title: '通知已启用',
          body: '任务、CTDP、RSIP 与专注提醒将由 Android 系统送达',
        );
      }
      if (!context.mounted) return;
      _message(context, granted ? '通知权限已启用' : '通知权限未启用，可在系统设置中调整');
    } catch (error) {
      if (context.mounted) _message(context, '通知设置失败：$error');
    }
  }

  Future<void> _clearForegroundHistory(BuildContext context) async {
    await controller.purgeForegroundEvents(all: true);
    if (context.mounted) _message(context, '前台应用日志已清除');
  }

  Future<void> _editReviewReminder(
    BuildContext context,
    ReviewPeriodType type,
  ) async {
    final parts = controller.reviewReminderTime(type).split(':');
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      ),
    );
    if (selected == null) return;
    await controller.setReviewReminder(
      type: type,
      enabled: controller.reviewReminderEnabled(type),
      time:
          '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}',
    );
  }

  Future<void> _editAlias(BuildContext context) async {
    final field = TextEditingController(text: controller.profileAlias);
    final value = await showWorkbenchDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('个人别名'),
        content: TextField(
          controller: field,
          autofocus: true,
          maxLength: 24,
          decoration: const InputDecoration(
            labelText: '别名',
            hintText: '显示在侧栏标题下方',
          ),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, field.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    field.dispose();
    if (value != null) await controller.setProfileAlias(value);
  }

  Future<void> _createBackup(BuildContext context) async {
    final password = await _askPassword(context, title: '创建加密备份');
    if (password == null || !context.mounted) return;
    try {
      final file = await controller.createEncryptedBackup(password);
      if (context.mounted) _message(context, '备份已保存：${file.path}');
    } catch (error) {
      if (context.mounted) _message(context, '$error');
    }
  }

  Future<void> _restoreBackup(BuildContext context) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pwb'],
    );
    final path = result?.files.single.path;
    if (path == null || !context.mounted) return;
    final password = await _askPassword(context, title: '输入备份密码');
    if (password == null || !context.mounted) return;
    try {
      final bundle = await controller.previewBackup(path, password);
      if (!context.mounted) return;
      final confirmed = await _confirmRestore(context, bundle);
      if (!confirmed) return;
      await controller.restoreBackup(bundle);
      if (context.mounted) _message(context, '备份恢复完成');
    } catch (error) {
      if (context.mounted) _message(context, '$error');
    }
  }

  Future<void> _exportJson(
    BuildContext context, {
    bool includeGameState = false,
  }) async {
    try {
      final file = await controller.exportJson(
        includeLocalGameState: includeGameState,
      );
      if (context.mounted) _message(context, '数据已导出：${file.path}');
    } catch (error) {
      if (context.mounted) _message(context, '导出失败：$error');
    }
  }

  Future<void> _importFile(BuildContext context) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json', 'csv', 'md', 'markdown', 'txt'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    try {
      final count = await controller.importFile(path);
      if (context.mounted) _message(context, '已导入 $count 条内容');
    } catch (error) {
      if (context.mounted) _message(context, '$error');
    }
  }

  Future<void> _clearSamples(BuildContext context) async {
    final confirmed =
        await showWorkbenchDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('清除示例内容？'),
            content: const Text('真实内容不会被删除。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('清除示例'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await controller.clearSampleData();
    if (context.mounted) _message(context, '示例内容已清除');
  }
}

// 设置行统一图标：翠绿圆角容器 + 描边图标，保证与标题文字对齐
class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon(this.icon, {this.color});

  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = color ?? scheme.primary;
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 18, color: tint),
    );
  }
}

class _AccentPreview extends StatelessWidget {
  const _AccentPreview();

  @override
  Widget build(BuildContext context) {
    final colors = [
      Theme.of(context).colorScheme.primary,
      const Color(0xFF0D9488),
      const Color(0xFF0E7490),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < colors.length; index++)
          Container(
            width: 18,
            height: 28,
            margin: const EdgeInsets.only(left: 3),
            decoration: BoxDecoration(
              color: colors[index],
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: index == 0
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: index == 0
                ? Icon(
                    Icons.check,
                    size: 12,
                    color: Theme.of(context).colorScheme.onPrimary,
                  )
                : null,
          ),
      ],
    );
  }
}

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection({
    required this.controller,
    required this.onEditAlias,
  });

  final WorkbenchController controller;
  final VoidCallback onEditAlias;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: '外观与导航',
      children: [
        ListTile(
          leading: const _SettingsIcon(Icons.brightness_6_outlined),
          title: const Text('主题'),
          trailing: DropdownButton<ThemeMode>(
            value: controller.themeMode,
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(value: ThemeMode.system, child: Text('跟随系统')),
              DropdownMenuItem(value: ThemeMode.light, child: Text('浅色')),
              DropdownMenuItem(value: ThemeMode.dark, child: Text('深色')),
            ],
            onChanged: (value) {
              if (value != null) controller.setThemeMode(value);
            },
          ),
        ),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          secondary: const _SettingsIcon(Icons.vertical_split_outlined),
          title: const Text('默认折叠 Windows 侧栏'),
          subtitle: const Text('仅改变八栏导航宽度，不隐藏任何页面'),
          value: controller.navigationCollapsed,
          onChanged: controller.setNavigationCollapsed,
        ),
        ListTile(
          leading: const _SettingsIcon(Icons.badge_outlined),
          title: const Text('个人别名'),
          subtitle: Text(
            controller.profileAlias.isEmpty
                ? '未设置，仅显示系统标题'
                : controller.profileAlias,
          ),
          trailing: OutlinedButton(
            onPressed: onEditAlias,
            child: const Text('编辑'),
          ),
        ),
      ],
    );
  }
}

class _ExperimentalSection extends StatelessWidget {
  const _ExperimentalSection({required this.controller});

  final WorkbenchController controller;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: '实验功能',
      children: [
        ExpansionTile(
          leading: const _SettingsIcon(Icons.science_outlined),
          title: const Text('成长、XP、签到与押注'),
          subtitle: const Text('关闭功能只隐藏入口，不删除本地记录'),
          children: [
            SwitchListTile(
              secondary: const _SettingsIcon(Icons.tune_outlined),
              title: const Text('高级工作流'),
              subtitle: const Text('显示 CTDP、RSIP、成长和协议入口'),
              value: controller.advancedFeaturesEnabled,
              onChanged: controller.setAdvancedFeaturesEnabled,
            ),
            SwitchListTile(
              secondary: const _SettingsIcon(Icons.toll_outlined),
              title: const Text('本地激励'),
              subtitle: const Text('显示签到、虚拟积分和专注押注'),
              value: controller.gameFeaturesEnabled,
              onChanged: controller.setGameFeaturesEnabled,
            ),
            const ListTile(
              leading: _SettingsIcon(Icons.palette_outlined),
              title: Text('成长主题'),
              subtitle: Text('翠绿主题已启用；更多冷色主题随等级解锁'),
              trailing: _AccentPreview(),
            ),
          ],
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _CloudSection extends StatefulWidget {
  const _CloudSection({required this.controller});

  final WorkbenchController controller;

  @override
  State<_CloudSection> createState() => _CloudSectionState();
}

class _CloudSectionState extends State<_CloudSection> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool busy = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final signedIn = controller.signedInEmail != null;
    final syncFailed = controller.syncPhase == SyncPhase.error;
    final syncing = controller.syncPhase == SyncPhase.syncing;
    return _Section(
      title: '账号与同步',
      children: [
        if (!controller.cloudConfigured)
          const ListTile(
            leading: _SettingsIcon(Icons.cloud_off_outlined),
            title: Text('当前为纯本地模式'),
            subtitle: Text('配置 Supabase 环境参数后可启用跨端同步'),
          )
        else if (signedIn) ...[
          ListTile(
            leading: _SettingsIcon(
              syncFailed
                  ? Icons.cloud_off_outlined
                  : syncing
                  ? Icons.cloud_sync_outlined
                  : Icons.cloud_done_outlined,
              color: syncFailed ? Theme.of(context).colorScheme.error : null,
            ),
            title: Text(controller.signedInEmail!),
            subtitle: Semantics(
              liveRegion: true,
              label: '同步状态：${controller.syncMessage}',
              child: ExcludeSemantics(child: Text(controller.syncMessage)),
            ),
            trailing: FilledButton.tonalIcon(
              onPressed: busy ? null : _sync,
              icon: busy
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(syncFailed ? Icons.refresh : Icons.sync),
              label: Text(syncFailed ? '重试同步' : '立即同步'),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 16, bottom: 12),
              child: TextButton(
                onPressed: busy ? null : _signOut,
                child: const Text('退出账号'),
              ),
            ),
          ),
        ] else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: '邮箱'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '密码'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: busy ? null : () => _authenticate(false),
                  child: const Text('注册'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: busy ? null : () => _authenticate(true),
                  child: const Text('登录'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _authenticate(bool signIn) async {
    setState(() => busy = true);
    try {
      if (signIn) {
        await widget.controller.signIn(
          emailController.text,
          passwordController.text,
        );
      } else {
        await widget.controller.signUp(
          emailController.text,
          passwordController.text,
        );
      }
      if (mounted) _message(context, widget.controller.syncMessage);
    } catch (error) {
      if (mounted) _message(context, '$error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _sync() async {
    setState(() => busy = true);
    try {
      await widget.controller.syncNow();
      if (mounted) _message(context, widget.controller.syncMessage);
    } catch (error) {
      if (mounted) _message(context, '同步失败：$error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => busy = true);
    try {
      await widget.controller.signOut();
    } catch (error) {
      if (mounted) _message(context, '退出失败：$error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class _TrashSection extends StatelessWidget {
  const _TrashSection({required this.controller});

  final WorkbenchController controller;

  @override
  Widget build(BuildContext context) {
    final records = controller.trashRecords;
    return _Section(
      title: '回收站（${records.length}）',
      children: records.isEmpty
          ? const [
              ListTile(
                leading: _SettingsIcon(Icons.delete_outline),
                title: Text('回收站为空'),
              ),
            ]
          : records
                .map(
                  (record) => ListTile(
                    leading: Icon(iconForKind(record.kind)),
                    title: Text(record.title, maxLines: 1),
                    subtitle: Text(
                      '${record.kind.label} · ${formatDateTime(record.deletedAt!)}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => controller.restoreFromTrash(record),
                          tooltip: '恢复',
                          icon: const Icon(Icons.restore),
                        ),
                        IconButton(
                          onPressed: () => _deleteForever(context, record),
                          tooltip: '永久删除',
                          icon: const Icon(Icons.delete_forever_outlined),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
    );
  }

  Future<void> _deleteForever(
    BuildContext context,
    WorkspaceRecord record,
  ) async {
    final confirmed =
        await showWorkbenchDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('永久删除？'),
            content: Text('“${record.title}”删除后无法从回收站恢复。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('永久删除'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    try {
      await controller.permanentlyDelete(record);
      if (context.mounted) _message(context, '记录已从本地和云端永久删除');
    } catch (error) {
      if (context.mounted) _message(context, '永久删除失败，记录仍保留：$error');
    }
  }
}

Future<String?> _askPassword(
  BuildContext context, {
  required String title,
}) async {
  final passwordController = TextEditingController();
  final value = await showWorkbenchDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: passwordController,
        autofocus: true,
        obscureText: true,
        decoration: const InputDecoration(labelText: '备份密码'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, passwordController.text),
          child: const Text('继续'),
        ),
      ],
    ),
  );
  passwordController.dispose();
  return value;
}

Future<bool> _confirmRestore(BuildContext context, BackupBundle bundle) async {
  return await showWorkbenchDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('确认恢复备份'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('创建时间：${formatDateTime(bundle.manifest.createdAt)}'),
              Text('记录数量：${bundle.manifest.recordCount}'),
              const SizedBox(height: 12),
              const Text('恢复会替换当前本地数据，请先为当前数据创建备份。'),
              const SizedBox(height: 8),
              const Text('恢复结果只写入本地，不会自动覆盖云端；需要时请手动同步。'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('恢复'),
            ),
          ],
        ),
      ) ??
      false;
}

void _message(BuildContext context, String message) {
  showWorkbenchSnackBar(context, SnackBar(content: Text(message)));
}
