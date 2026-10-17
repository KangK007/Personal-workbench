import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/models/workspace_record.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/backup_service.dart';
import '../../services/notification_service.dart';
import '../../state/workbench_controller.dart';
import '../widgets/common.dart';
import '../widgets/sync_conflict_dialog.dart';

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

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.controller,
    this.showHeader = true,
  });

  final WorkbenchController controller;
  final bool showHeader;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _scrollController = ScrollController();
  final _scrollViewportKey = GlobalKey();
  final _sectionKeys = List.generate(5, (_) => GlobalKey());
  int _selectedSection = 0;

  WorkbenchController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateSelectedSection);
  }

  void _updateSelectedSection() {
    final viewport = _scrollViewportKey.currentContext?.findRenderObject();
    if (viewport is! RenderBox || !viewport.attached) return;
    final top = viewport.localToGlobal(Offset.zero).dy;
    var current = 0;
    for (var index = 0; index < _sectionKeys.length; index++) {
      final section = _sectionKeys[index].currentContext?.findRenderObject();
      if (section is RenderBox &&
          section.attached &&
          section.localToGlobal(Offset.zero).dy <= top + 32) {
        current = index;
      }
    }
    if (_scrollController.position.extentAfter < 1) {
      current = _sectionKeys.length - 1;
    }
    if (current != _selectedSection && mounted) {
      setState(() => _selectedSection = current);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _jumpToSection(int index) async {
    final destination = _sectionKeys[index].currentContext;
    if (destination == null) return;
    setState(() => _selectedSection = index);
    await Scrollable.ensureVisible(
      destination,
      alignment: 0,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : AppMotion.standard,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final windows = controller.windowsActivityService.supported;
    return Column(
      children: [
        if (widget.showHeader) ...[
          const PageHeader(
            title: '设置',
            subtitle: '外观、提醒、同步与本地数据管理',
            maxWidth: AppLayout.workspaceMax,
          ),
        ],
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppLayout.workspaceMax,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final textScale =
                      MediaQuery.textScalerOf(context).scale(14) / 14;
                  final showIndex =
                      constraints.maxWidth >= 1000 &&
                      constraints.maxHeight >= 600 &&
                      textScale < 1.5;
                  final settings = SingleChildScrollView(
                    key: _scrollViewportKey,
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(
                      20,
                      20,
                      20,
                      WorkbenchViewport.sizeOf(context).width <
                              AppBreakpoints.compact
                          ? AppSpacing.bottomNavClearance
                          : 96,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _AppearanceSection(
                          key: _sectionKeys[0],
                          controller: controller,
                          onEditAlias: () => _editAlias(context),
                        ),
                        const SizedBox(height: 32),
                        _CloudSection(
                          key: _sectionKeys[1],
                          controller: controller,
                        ),
                        const SizedBox(height: 32),
                        _Section(
                          key: _sectionKeys[2],
                          title: '任务与周期',
                          children: [
                            _LogicalDayBoundaryTile(controller: controller),
                          ],
                        ),
                        if (windows) ...[
                          const SizedBox(height: 16),
                          _Section(
                            title: '专注与检测',
                            children: [
                              SwitchListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                secondary: const _SettingsIcon(
                                  Icons.visibility_outlined,
                                ),
                                title: const Text('前台应用检测'),
                                subtitle: const Text(
                                  '默认关闭；只保存应用标识、开始时间、持续时间和预设',
                                ),
                                value: controller.foregroundDetectionEnabled,
                                onChanged:
                                    controller.setForegroundDetectionEnabled,
                              ),
                              SwitchListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                secondary: const _SettingsIcon(
                                  Icons.open_in_new_outlined,
                                ),
                                title: const Text('定时专注显示工作台'),
                                subtitle: const Text(
                                  '到点先提醒并恢复窗口；Windows 拒绝置前时闪烁任务栏',
                                ),
                                value: controller.bringToFrontOnFocusSchedule,
                                onChanged:
                                    controller.setBringToFrontOnFocusSchedule,
                              ),
                              _SettingsActionTile(
                                leading: const _SettingsIcon(
                                  Icons.delete_sweep_outlined,
                                ),
                                title: const Text('前台日志'),
                                subtitle: const Text('本地保留 30 天，不上传云端'),
                                trailing: TextButton(
                                  onPressed: () =>
                                      _clearForegroundHistory(context),
                                  child: const Text('立即清除'),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),
                        _Section(
                          title: '回顾与提醒',
                          children: [
                            for (final type in activeReviewPeriodTypes)
                              SwitchListTile(
                                contentPadding: EdgeInsets.only(
                                  left: 16,
                                  right:
                                      WorkbenchViewport.sizeOf(context).width <
                                          AppBreakpoints.compact
                                      ? 80
                                      : 16,
                                ),
                                secondary: _SettingsIcon(_reviewIcon(type)),
                                title: Text(_reviewName(type)),
                                subtitle: Text(
                                  _reviewSchedule(type, controller),
                                ),
                                value: controller.reviewReminderEnabled(type),
                                onChanged: (enabled) =>
                                    controller.setReviewReminder(
                                      type: type,
                                      enabled: enabled,
                                    ),
                              ),
                            for (final type in activeReviewPeriodTypes)
                              _SettingsActionTile(
                                leading: const SizedBox(width: 34),
                                title: Text('修改${_reviewName(type)}时间'),
                                trailing: OutlinedButton(
                                  onPressed: () =>
                                      _editReviewReminder(context, type),
                                  child: Text(
                                    controller.reviewReminderTime(type),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _Section(
                          title: '通知与后台',
                          children: [
                            if (windows) ...[
                              SwitchListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                secondary: const _SettingsIcon(
                                  Icons.minimize_outlined,
                                ),
                                title: const Text('关闭窗口时最小化到托盘'),
                                subtitle: const Text('启用后请通过托盘菜单退出应用'),
                                value: controller.closeToTray,
                                onChanged: controller.setCloseToTray,
                              ),
                              SwitchListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                secondary: const _SettingsIcon(
                                  Icons.power_settings_new_outlined,
                                ),
                                title: const Text('开机启动'),
                                subtitle: const Text('默认关闭，仅当前 Windows 用户'),
                                value: controller.startupEnabled,
                                onChanged: controller.setStartupEnabled,
                              ),
                              _SettingsActionTile(
                                leading: const _SettingsIcon(
                                  Icons.exit_to_app_outlined,
                                ),
                                title: const Text('真正退出'),
                                subtitle: const Text('停止托盘、计时和后台提醒'),
                                trailing: OutlinedButton(
                                  onPressed: controller
                                      .windowsActivityService
                                      .exitApplication,
                                  child: const Text('退出'),
                                ),
                              ),
                            ],
                            _SettingsActionTile(
                              leading: const _SettingsIcon(
                                Icons.notifications_outlined,
                              ),
                              title: const Text('任务和休息提醒'),
                              subtitle: Text(
                                defaultTargetPlatform == TargetPlatform.android
                                    ? '由 Android 系统管理通知'
                                    : controller
                                          .notificationService
                                          .supportsSystemNotifications
                                    ? '由 Windows 系统管理通知'
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
                        if (windows) ...[
                          const SizedBox(height: 16),
                          _Section(
                            title: '诊断与恢复',
                            children: [
                              _SettingsActionTile(
                                leading: const _SettingsIcon(
                                  Icons.admin_panel_settings_outlined,
                                ),
                                title: const Text('管理员权限'),
                                subtitle: Text(
                                  controller
                                          .restrictionHostsStatus
                                          .administrator
                                      ? '已具备 Windows 管理员权限'
                                      : '未具备，写入 hosts 时可能需要 UAC',
                                ),
                              ),
                              _SettingsActionTile(
                                leading: _SettingsIcon(
                                  controller.restrictionHostsStatus.active
                                      ? Icons.check_circle_outline
                                      : Icons.cloud_off_outlined,
                                ),
                                title: const Text('hosts 健康状态'),
                                subtitle: Text(_hostsSummary(controller)),
                                trailing: Wrap(
                                  spacing: 4,
                                  children: [
                                    IconButton(
                                      tooltip: '重新检查',
                                      onPressed: controller
                                          .refreshRestrictionHostsStatus,
                                      icon: const Icon(Icons.refresh),
                                    ),
                                    if (controller
                                            .restrictionProfile
                                            ?.websiteBlocking ==
                                        true)
                                      IconButton(
                                        tooltip: '修复 hosts',
                                        onPressed:
                                            controller.repairRestrictionHosts,
                                        icon: const Icon(Icons.build_outlined),
                                      ),
                                    if (controller
                                        .restrictionHostsStatus
                                        .active)
                                      IconButton(
                                        tooltip: '清理 hosts',
                                        onPressed:
                                            controller.clearRestrictionHosts,
                                        icon: const Icon(
                                          Icons.cleaning_services_outlined,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              _SettingsActionTile(
                                leading: const _SettingsIcon(
                                  Icons.power_settings_new_outlined,
                                ),
                                title: const Text('异常退出恢复'),
                                subtitle: Text(
                                  controller
                                          .restrictionRecoveredAfterAbnormalExit
                                      ? '检测到上次异常退出，活动限制已恢复'
                                      : '未发现异常退出',
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),
                        _Section(
                          key: _sectionKeys[3],
                          title: '数据与备份',
                          children: [
                            _SettingsActionTile(
                              leading: const _SettingsIcon(Icons.lock_outline),
                              title: const Text('创建加密备份'),
                              subtitle: const Text('保存全部本地内容，密码至少 8 个字符'),
                              trailing: FilledButton.tonal(
                                onPressed: () => _createBackup(context),
                                child: const Text('备份'),
                              ),
                            ),
                            _SettingsActionTile(
                              leading: const _SettingsIcon(
                                Icons.restore_outlined,
                              ),
                              title: const Text('预览并恢复备份'),
                              subtitle: const Text('确认数据范围后才会替换当前数据'),
                              trailing: OutlinedButton(
                                onPressed: () => _restoreBackup(context),
                                child: const Text('选择文件'),
                              ),
                            ),
                            _SettingsActionTile(
                              leading: const _SettingsIcon(
                                Icons.download_outlined,
                              ),
                              title: const Text('导出 JSON'),
                              subtitle: const Text('生成可读取的完整数据副本'),
                              trailing: OutlinedButton(
                                onPressed: () => _exportJson(context),
                                child: const Text('导出'),
                              ),
                            ),
                            _SettingsActionTile(
                              leading: const _SettingsIcon(Icons.toll_outlined),
                              title: const Text('导出本地游戏状态'),
                              subtitle: const Text(
                                '把积分和押注账本加入 JSON；这些数据不会上传云端',
                              ),
                              trailing: OutlinedButton(
                                onPressed: () => _exportJson(
                                  context,
                                  includeGameState: true,
                                ),
                                child: const Text('含游戏状态'),
                              ),
                            ),
                            _SettingsActionTile(
                              leading: const _SettingsIcon(
                                Icons.upload_file_outlined,
                              ),
                              title: const Text('导入文件'),
                              subtitle: const Text(
                                '支持 JSON、CSV、Markdown 和 TXT',
                              ),
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
                        _TrashSection(
                          key: _sectionKeys[4],
                          controller: controller,
                        ),
                        const SizedBox(height: 16),
                        _Section(
                          title: '示例内容',
                          children: [
                            _SettingsActionTile(
                              leading: const _SettingsIcon(
                                Icons.cleaning_services_outlined,
                              ),
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
                          '个人工作台 0.2',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  );
                  if (!showIndex) return settings;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 4, 20),
                        child: _SettingsIndex(
                          selectedIndex: _selectedSection,
                          onSelected: _jumpToSection,
                        ),
                      ),
                      Expanded(child: settings),
                    ],
                  );
                },
              ),
            ),
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

  String _hostsSummary(WorkbenchController controller) {
    final hosts = controller.restrictionHostsStatus;
    if (hosts.error.isNotEmpty) return hosts.error;
    if (hosts.externallyModified) return '检测到受管区块缺失或被外部修改';
    if (hosts.active) return '受管区块完整';
    return hosts.supported ? '未发现活动受管区块' : 'Android 不执行 Windows hosts 限制';
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
        content: ExternalField(
          label: '别名',
          child: TextField(
            controller: field,
            autofocus: true,
            maxLength: 24,
            decoration: const InputDecoration(hintText: '显示在侧栏标题下方'),
            onSubmitted: (value) => Navigator.pop(context, value),
          ),
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

// 保留本页名称兼容；视觉实现由共享 SurfaceIcon 统一。
class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon(this.icon, {this.color});

  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) =>
      SurfaceIcon(icon, color: color ?? context.accents.slate.color);
}

class _AccentPreview extends StatelessWidget {
  const _AccentPreview();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final reward = context.tokens.reward;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 28,
          decoration: BoxDecoration(
            color: primary,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Container(
          width: 12,
          height: 28,
          decoration: BoxDecoration(
            color: reward,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ],
    );
  }
}

class _ThemeChoiceCard extends StatelessWidget {
  const _ThemeChoiceCard({
    required this.mode,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final ThemeMode mode;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: '$title，$subtitle',
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: context.tokens.panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.tokens.cardRadius),
            side: BorderSide(
              color: selected ? scheme.primary : context.tokens.panelBorder,
              width: selected ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ThemeMiniPreview(mode: mode),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      Icon(
                        selected ? Icons.check_circle : Icons.circle_outlined,
                        color: selected
                            ? scheme.primary
                            : context.tokens.mutedText,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeMiniPreview extends StatelessWidget {
  const _ThemeMiniPreview({required this.mode});

  final ThemeMode mode;

  @override
  Widget build(BuildContext context) {
    final night = mode == ThemeMode.dark;
    final canvas = night ? AppColors.darkCanvas : AppColors.lightCanvas;
    final navigation = night
        ? AppColors.darkNavigation
        : AppColors.lightNavigation;
    final surface = night ? AppColors.darkSurface : AppColors.lightSurface;
    final raised = night
        ? AppColors.darkEmphasisSurface
        : AppColors.lightEmphasisSurface;
    final accent = night ? AppColors.darkPrimary : AppColors.lightPrimary;
    final achievement = night ? AppColors.darkReward : AppColors.lightReward;
    return Container(
      height: 82,
      decoration: BoxDecoration(
        color: canvas,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: night ? AppColors.darkPanelBorder : AppColors.lightPanelBorder,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Container(
            width: 28,
            color: navigation,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Column(
              children: [
                _MiniBar(color: accent, height: 8),
                const SizedBox(height: 9),
                _MiniBar(color: raised, height: 4),
                const SizedBox(height: 7),
                _MiniBar(color: raised, height: 4),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FractionallySizedBox(
                    widthFactor: 0.48,
                    child: _MiniBar(color: accent, height: 5),
                  ),
                  const SizedBox(height: 7),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: surface,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(7),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  FractionallySizedBox(
                                    widthFactor: 0.72,
                                    child: _MiniBar(color: raised, height: 5),
                                  ),
                                  const Spacer(),
                                  _MiniBar(color: accent, height: 4),
                                  const SizedBox(height: 4),
                                  FractionallySizedBox(
                                    widthFactor: 0.68,
                                    child: _MiniBar(color: raised, height: 4),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 2,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: surface,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Center(
                              child: Container(
                                width: 21,
                                height: 21,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: achievement,
                                    width: 4,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBar extends StatelessWidget {
  const _MiniBar({required this.color, required this.height});

  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(height / 2),
    ),
  );
}

class _SettingsIndex extends StatelessWidget {
  const _SettingsIndex({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _destinations = [
    (icon: Icons.palette_outlined, label: '外观与导航'),
    (icon: Icons.cloud_outlined, label: '账户与同步'),
    (icon: Icons.tune_outlined, label: '工作与提醒'),
    (icon: Icons.backup_outlined, label: '数据与备份'),
    (icon: Icons.delete_outline, label: '回收站'),
  ];

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 188,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
          child: Text('设置目录', style: Theme.of(context).textTheme.titleMedium),
        ),
        for (var index = 0; index < _destinations.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Semantics(
              selected: index == selectedIndex,
              child: TextButton.icon(
                key: ValueKey('settings-index:$index'),
                onPressed: () => onSelected(index),
                icon: Icon(_destinations[index].icon, size: 20),
                label: Text(_destinations[index].label),
                style: TextButton.styleFrom(
                  alignment: AlignmentDirectional.centerStart,
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: index == selectedIndex
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : context.tokens.mutedText,
                  backgroundColor: index == selectedIndex
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                ),
              ),
            ),
          ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '修改会保存到本机。云同步由你选择开启。',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.tokens.mutedText),
          ),
        ),
      ],
    ),
  );
}

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection({
    super.key,
    required this.controller,
    required this.onEditAlias,
  });

  final WorkbenchController controller;
  final VoidCallback onEditAlias;

  Future<void> _selectTheme(BuildContext context, ThemeMode mode) async {
    try {
      await controller.setThemeMode(mode);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('主题保存失败，已恢复原设置，请重试')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final windows = controller.windowsActivityService.supported;
    return _Section(
      title: '外观与导航',
      children: [
        const _SettingsActionTile(
          leading: _SettingsIcon(Icons.brightness_6_outlined),
          title: Text('主题外观'),
          subtitle: Text('选择白天或夜间主题；跟随系统会响应设备外观设置'),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final day = _ThemeChoiceCard(
                mode: ThemeMode.light,
                title: '白天 · 薄荷青玉',
                subtitle: '薄荷白纸面与青玉行动色',
                selected: controller.themeMode == ThemeMode.light,
                onTap: () => _selectTheme(context, ThemeMode.light),
              );
              final night = _ThemeChoiceCard(
                mode: ThemeMode.dark,
                title: '夜间 · 森林青玉',
                subtitle: '森林绿层次与柔和青玉高光',
                selected: controller.themeMode == ThemeMode.dark,
                onTap: () => _selectTheme(context, ThemeMode.dark),
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (constraints.maxWidth >= 560)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: day),
                        const SizedBox(width: 12),
                        Expanded(child: night),
                      ],
                    )
                  else ...[
                    day,
                    const SizedBox(height: 12),
                    night,
                  ],
                  const SizedBox(height: 12),
                  Semantics(
                    selected: controller.themeMode == ThemeMode.system,
                    child: OutlinedButton.icon(
                      onPressed: () => _selectTheme(context, ThemeMode.system),
                      icon: Icon(
                        controller.themeMode == ThemeMode.system
                            ? Icons.check_circle
                            : Icons.brightness_auto_outlined,
                        size: 20,
                      ),
                      label: const Text('跟随系统'),
                      style: OutlinedButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor:
                            controller.themeMode == ThemeMode.system
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        if (windows)
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            secondary: const _SettingsIcon(Icons.vertical_split_outlined),
            title: const Text('默认折叠 Windows 侧栏'),
            subtitle: const Text('仅改变八栏导航宽度，不隐藏任何页面'),
            value: controller.navigationCollapsed,
            onChanged: controller.setNavigationCollapsed,
          ),
        _SettingsActionTile(
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
            _SettingsActionTile(
              leading: _SettingsIcon(Icons.palette_outlined),
              title: const Text('成果标记'),
              subtitle: const Text('成果颜色随薄荷青玉与森林青玉主题切换'),
              trailing: _AccentPreview(),
            ),
          ],
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
          child: Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        Material(
          color: Theme.of(context).colorScheme.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
            side: BorderSide(color: context.tokens.panelBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < children.length; index++) ...[
                if (index > 0)
                  const Divider(height: 1, indent: 16, endIndent: 16),
                children[index],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Keep explanations readable when actions would squeeze a narrow text column.
class _SettingsActionTile extends StatelessWidget {
  const _SettingsActionTile({
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
      if (trailing == null ||
          (constraints.maxWidth >= 480 &&
              (textScale < 1.4 || constraints.maxWidth >= 720))) {
        return ListTile(
          leading: leading,
          title: title,
          subtitle: subtitle,
          trailing: trailing,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        );
      }
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 12)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DefaultTextStyle.merge(
                        style: Theme.of(context).textTheme.bodyLarge,
                        child: title,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        DefaultTextStyle.merge(
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: context.tokens.mutedText),
                          child: subtitle!,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(alignment: AlignmentDirectional.centerEnd, child: trailing!),
          ],
        ),
      );
    },
  );
}

class _LogicalDayBoundaryTile extends StatelessWidget {
  const _LogicalDayBoundaryTile({required this.controller});

  final WorkbenchController controller;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final compact =
          constraints.maxWidth < 330 ||
          (textScale > 1.4 && constraints.maxWidth < 600);
      final selector = DropdownButton<int>(
        value: controller.logicalDayBoundaryHour,
        underline: const SizedBox.shrink(),
        items: [
          for (var hour = 0; hour <= 6; hour++)
            DropdownMenuItem(
              value: hour,
              child: Text('${hour.toString().padLeft(2, '0')}:00'),
            ),
        ],
        onChanged: (value) {
          if (value != null) controller.setLogicalDayBoundaryHour(value);
        },
      );
      if (!compact) {
        return ListTile(
          leading: const _SettingsIcon(Icons.schedule_outlined),
          title: const Text('逻辑日分界'),
          subtitle: const Text('修改只影响今后生成的任务实例'),
          trailing: selector,
        );
      }
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SettingsIcon(Icons.schedule_outlined),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '逻辑日分界',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text('修改只影响今后生成的任务实例'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Align(alignment: Alignment.centerRight, child: selector),
          ],
        ),
      );
    },
  );
}

class _CloudSection extends StatefulWidget {
  const _CloudSection({super.key, required this.controller});

  final WorkbenchController controller;

  @override
  State<_CloudSection> createState() => _CloudSectionState();
}

class _CloudSectionState extends State<_CloudSection> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final emailFocusNode = FocusNode();
  final passwordFocusNode = FocusNode();
  bool busy = false;
  bool? authenticatingSignIn;
  bool passwordVisible = false;
  String? emailError;
  String? passwordError;
  String? authMessage;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    emailFocusNode.dispose();
    passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final signedIn = controller.signedInEmail != null;
    return _Section(
      title: '账号与同步',
      children: [
        if (!controller.cloudConfigured)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SettingsIcon(
                  Icons.cloud_off_outlined,
                  color: context.accents.teal.color,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '当前为纯本地模式',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '启用跨端同步需要在启动配置中提供 SUPABASE_URL 和 SUPABASE_ANON_KEY。配置完成前，本地数据仍可使用。',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else if (signedIn) ...[
          _signedInContent(context, controller),
        ] else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: _SettingsIcon(Icons.spa_outlined),
                ),
                const SizedBox(height: AppSpacing.md),
                ExternalField(
                  label: '邮箱',
                  child: TextField(
                    controller: emailController,
                    focusNode: emailFocusNode,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {
                      emailError = null;
                      authMessage = null;
                    }),
                    decoration: InputDecoration(errorText: emailError),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ExternalField(
                  label: '密码',
                  child: TextField(
                    controller: passwordController,
                    focusNode: passwordFocusNode,
                    obscureText: !passwordVisible,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) {
                      if (!busy) _authenticate(true);
                    },
                    onChanged: (_) => setState(() {
                      passwordError = null;
                      authMessage = null;
                    }),
                    decoration: InputDecoration(
                      errorText: passwordError,
                      suffixIcon: IconButton(
                        tooltip: passwordVisible ? '隐藏密码' : '显示密码',
                        onPressed: () =>
                            setState(() => passwordVisible = !passwordVisible),
                        icon: Icon(
                          passwordVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                  ),
                ),
                if (authMessage != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      authMessage!,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(fontSize: 13),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    TextButton(
                      onPressed: busy ? null : () => _authenticate(false),
                      child: Text(
                        busy && authenticatingSignIn == false ? '注册中…' : '注册',
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: busy ? null : () => _authenticate(true),
                      icon: busy && authenticatingSignIn == true
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login_outlined),
                      label: Text(
                        busy && authenticatingSignIn == true ? '登录中…' : '登录',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _signedInContent(
    BuildContext context,
    WorkbenchController controller,
  ) {
    final phase = controller.syncPhase;
    final syncing = phase == SyncPhase.syncing;
    final failed = phase == SyncPhase.error;
    final icon = switch (phase) {
      SyncPhase.syncing => Icons.cloud_sync_outlined,
      SyncPhase.success => Icons.cloud_done_outlined,
      SyncPhase.error => Icons.cloud_off_outlined,
      _ => Icons.cloud_queue_outlined,
    };
    final accent = failed
        ? Theme.of(context).colorScheme.error
        : context.accents.teal.color;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SettingsIcon(icon, color: accent),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.signedInEmail!,
                      style: Theme.of(context).textTheme.bodyLarge,
                      softWrap: true,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Semantics(
                      liveRegion: true,
                      label: '同步状态：${controller.syncMessage}',
                      child: ExcludeSemantics(
                        child: Text(
                          controller.syncMessage,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      controller.lastSuccessfulSyncAt == null
                          ? '本次启动尚未成功同步'
                          : '本次启动最近同步：${formatDateTime(controller.lastSuccessfulSyncAt!)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 13,
                        fontFamily: AppFonts.numeric,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (syncing) ...[
            const SizedBox(height: AppSpacing.md),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: AppSpacing.xl),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              TextButton(
                onPressed: busy || syncing ? null : _signOut,
                child: const Text('退出账号'),
              ),
              FilledButton.tonalIcon(
                onPressed: busy || syncing ? null : _sync,
                icon: busy || syncing
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(failed ? Icons.refresh : Icons.sync),
                label: Text(failed ? '重试同步' : '立即同步'),
              ),
            ],
          ),
          if (controller.syncConflictCopies.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            Divider(color: context.tokens.divider),
            const SizedBox(height: AppSpacing.md),
            Text(
              '待处理同步冲突 ${controller.syncConflictCopies.length} 项',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.md),
            for (final copy in controller.syncConflictCopies) ...[
              LogSurface(
                accent: context.accents.teal.color,
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      copy.title,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Text('本地修改已另存为冲突副本，请对照云端当前版本。'),
                    const SizedBox(height: AppSpacing.md),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.tonalIcon(
                        onPressed: busy
                            ? null
                            : () async {
                                final resolved = await showSyncConflictDialog(
                                  context: context,
                                  controller: controller,
                                  conflictCopy: copy,
                                );
                                if (!mounted || !context.mounted || !resolved) {
                                  return;
                                }
                                setState(() {});
                                showWorkbenchSnackBar(
                                  context,
                                  const SnackBar(content: Text('同步冲突已解决')),
                                );
                              },
                        icon: const Icon(Icons.compare_arrows_outlined),
                        label: const Text('对照并解决'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _authenticate(bool signIn) async {
    if (busy) return;
    final email = emailController.text.trim();
    final password = passwordController.text;
    final validEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    if (!validEmail || password.isEmpty) {
      setState(() {
        emailError = validEmail ? null : '请输入有效邮箱。';
        passwordError = password.isEmpty ? '请输入密码。' : null;
      });
      (validEmail ? passwordFocusNode : emailFocusNode).requestFocus();
      return;
    }
    setState(() {
      busy = true;
      authenticatingSignIn = signIn;
      emailError = null;
      passwordError = null;
      authMessage = null;
    });
    try {
      if (signIn) {
        await widget.controller.signIn(email, password);
      } else {
        await widget.controller.signUp(email, password);
      }
      if (mounted) setState(() => authMessage = widget.controller.syncMessage);
    } catch (_) {
      if (mounted) {
        setState(
          () => passwordError = signIn
              ? '登录失败，请检查账号、密码或网络后重试。'
              : '注册失败，请检查账号、密码或网络后重试。',
        );
        passwordFocusNode.requestFocus();
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          authenticatingSignIn = null;
        });
      }
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

class _TrashSection extends StatefulWidget {
  const _TrashSection({super.key, required this.controller});

  final WorkbenchController controller;

  @override
  State<_TrashSection> createState() => _TrashSectionState();
}

class _TrashSectionState extends State<_TrashSection> {
  final Set<String> _selectedKeys = <String>{};

  String _key(WorkspaceRecord record) => '${record.kind.name}:${record.id}';

  @override
  Widget build(BuildContext context) {
    final records = widget.controller.trashRecords;
    final selected = records
        .where((record) => _selectedKeys.contains(_key(record)))
        .toList(growable: false);
    final allSelected = records.isNotEmpty && selected.length == records.length;
    return _Section(
      title: '回收站（${records.length}）',
      children: records.isEmpty
          ? const [
              ListTile(
                leading: _SettingsIcon(Icons.delete_outline),
                title: Text('回收站为空'),
              ),
            ]
          : [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: 4,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 260),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: allSelected
                                ? true
                                : (selected.isEmpty ? false : null),
                            tristate: true,
                            onChanged: (value) => setState(() {
                              _selectedKeys
                                ..clear()
                                ..addAll(
                                  value == true
                                      ? records.map(_key)
                                      : const <String>[],
                                );
                            }),
                          ),
                          Flexible(child: Text('已选 ${selected.length} 项')),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (selected.isNotEmpty) ...[
                          IconButton(
                            tooltip: '恢复所选',
                            onPressed: () => _restoreSelected(selected),
                            icon: const Icon(Icons.restore),
                          ),
                          IconButton(
                            tooltip: '永久删除所选',
                            onPressed: () => _deleteSelected(selected),
                            icon: const Icon(Icons.delete_forever_outlined),
                          ),
                        ],
                        IconButton(
                          tooltip: '清空回收站',
                          onPressed: () => _clearAll(records.length),
                          icon: const Icon(Icons.delete_sweep_outlined),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (records.length > 8)
                SizedBox(
                  height: 480,
                  child: Scrollbar(
                    child: ListView.builder(
                      key: const ValueKey('settings-trash-list'),
                      primary: false,
                      itemCount: records.length,
                      itemBuilder: (context, index) =>
                          _recordTile(records[index]),
                    ),
                  ),
                )
              else
                ...records.map(_recordTile),
            ],
    );
  }

  Widget _recordTile(WorkspaceRecord record) => _SettingsActionTile(
    leading: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: _selectedKeys.contains(_key(record)),
          onChanged: (value) => setState(() {
            if (value == true) {
              _selectedKeys.add(_key(record));
            } else {
              _selectedKeys.remove(_key(record));
            }
          }),
        ),
        Icon(iconForKind(record.kind)),
      ],
    ),
    title: Text(record.title, maxLines: 1),
    subtitle: Text(
      '${record.kind.label} · ${formatDateTime(record.deletedAt!)}',
    ),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => _restoreOne(record),
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
  );

  Future<void> _restoreSelected(List<WorkspaceRecord> selected) async {
    try {
      final result = await widget.controller.restoreRecords(selected);
      if (mounted) {
        _retainFailedSelection(result);
        _message(
          context,
          '已恢复 ${result.succeeded} 项${result.failed == 0 ? '' : '，失败 ${result.failed} 项'}',
        );
      }
    } catch (error) {
      if (mounted) _message(context, '恢复失败：$error');
    }
  }

  Future<void> _deleteSelected(List<WorkspaceRecord> selected) async {
    final confirmed =
        await showWorkbenchDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('永久删除所选？'),
            content: Text('将永久删除 ${selected.length} 项记录及其附件。此操作无法撤销。'),
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
      final result = await widget.controller.permanentlyDeleteRecords(selected);
      if (mounted) {
        _retainFailedSelection(result);
        _message(
          context,
          '已永久删除 ${result.succeeded} 项${result.failed == 0 ? '' : '，失败 ${result.failed} 项'}',
        );
      }
    } catch (error) {
      if (mounted) _message(context, '永久删除失败：$error');
    }
  }

  Future<void> _clearAll(int count) async {
    if (count == 0) return;
    late final int attachmentCount;
    try {
      attachmentCount = await widget.controller.attachmentCountForRecords(
        widget.controller.trashRecords,
      );
    } catch (error) {
      if (mounted) _message(context, '无法读取附件数量：$error');
      return;
    }
    if (!mounted) return;
    final first =
        await showWorkbenchDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('清空回收站？'),
            content: Text('回收站共有 $count 项记录和 $attachmentCount 个附件，将永久删除。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('继续'),
              ),
            ],
          ),
        ) ??
        false;
    if (!first || !mounted) return;
    final second =
        await showWorkbenchDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('最后确认'),
            content: Text(
              '将永久删除 $count 项记录和 $attachmentCount 个附件，清空后无法恢复。确定继续吗？',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('永久清空'),
              ),
            ],
          ),
        ) ??
        false;
    if (!second) return;
    try {
      final result = await widget.controller.clearTrash();
      if (mounted) {
        _retainFailedSelection(result);
        _message(
          context,
          '已清空回收站（${result.succeeded} 项${result.failed == 0 ? '' : '，失败 ${result.failed} 项'}）',
        );
      }
    } catch (error) {
      if (mounted) _message(context, '清空失败：$error');
    }
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
      await widget.controller.permanentlyDelete(record);
      if (context.mounted) _message(context, '记录已从本地和云端永久删除');
    } catch (error) {
      if (context.mounted) _message(context, '永久删除失败，记录仍保留：$error');
    }
  }

  Future<void> _restoreOne(WorkspaceRecord record) async {
    try {
      final result = await widget.controller.restoreRecords([record]);
      if (mounted) {
        _message(
          context,
          '已恢复 ${result.succeeded} 项${result.failed == 0 ? '' : '，失败 ${result.failed} 项'}',
        );
      }
    } catch (error) {
      if (mounted) _message(context, '恢复失败：$error');
    }
  }

  void _retainFailedSelection(BatchOperationResult result) {
    final failedIds = result.failures
        .map((failure) => failure.recordId)
        .toSet();
    setState(() {
      _selectedKeys
        ..clear()
        ..addAll(
          widget.controller.trashRecords
              .where((record) => failedIds.contains(record.id))
              .map(_key),
        );
    });
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
      content: ExternalField(
        label: '备份密码',
        child: TextField(
          controller: passwordController,
          autofocus: true,
          obscureText: true,
          decoration: const InputDecoration(),
        ),
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
