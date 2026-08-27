import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/models/restriction_models.dart';
import '../../core/models/workspace_record.dart';
import '../../core/theme/app_theme.dart';
import '../../services/restriction_policy_engine.dart';
import '../../services/restriction_monitor.dart';
import '../../state/workbench_controller.dart';
import '../widgets/common.dart';

/// 自律内容区：无 PageHeader、无外层 Column 的纯内容组件。
///
/// 供「专注」页的「自律」Tab 与旧版 RestrictionPage 复用。
/// 数据全部走 [controller] 的现有 getter，状态逻辑与旧版一致。
class RestrictionSection extends StatelessWidget {
  const RestrictionSection({
    super.key,
    required this.controller,
    this.onOpenSettings,
  });

  final WorkbenchController controller;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final profile = controller.restrictionProfile;
    final monitor = controller.restrictionMonitorState;
    final windows = Platform.isWindows;
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        compact ? AppSpacing.pageCompact : AppSpacing.pageMedium,
        0,
        compact ? AppSpacing.pageCompact : AppSpacing.pageMedium,
        132,
      ),
      children: [
        if (controller.restrictionExitRequested)
          _ExitRequestBanner(controller: controller),
        if (!windows) const _PlatformNotice(),
        _buildOverview(context, profile, monitor),
        const SectionHeading(title: '规则'),
        _buildProfileCard(context, profile),
        const SectionHeading(title: '保护设置'),
        _buildSecurityCard(context, monitor, profile),
        const SectionHeading(title: '日志与统计'),
        _buildEvents(context),
        const SectionHeading(title: '保护状态'),
        _buildProtectionSummary(context, profile),
      ],
    );
  }

  Widget _buildOverview(
    BuildContext context,
    RestrictionProfile? profile,
    RestrictionMonitorState monitor,
  ) {
    final status = monitor.active
        ? monitor.isPaused(controller.currentTime())
              ? '临时休息'
              : '限制中'
        : profile?.enabled == true
        ? '等待时段'
        : '未启用';
    final statusColor =
        monitor.active && !monitor.isPaused(controller.currentTime())
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    final next = profile == null
        ? null
        : const RestrictionPolicyEngine().nextTransition(
            profile,
            controller.currentTime(),
          );
    return LogSurface(
      accent: statusColor,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compactMetrics = constraints.maxWidth < 720;
          final metricWidth = compactMetrics
              ? (constraints.maxWidth - AppSpacing.md) / 2
              : 150.0;
          return Wrap(
            spacing: compactMetrics ? AppSpacing.md : AppSpacing.xl,
            runSpacing: AppSpacing.md,
            children: [
              _Metric(
                width: metricWidth,
                label: '当前状态',
                value: status,
                color: statusColor,
              ),
              _Metric(
                width: metricWidth,
                label: '当前规则',
                value: monitor.activeSnapshot?.title ?? profile?.title ?? '未配置',
              ),
              _Metric(
                width: metricWidth,
                label: '下一次切换',
                value: next?.at == null ? '暂无计划' : _dateTime(next!.at!),
                numeric: next?.at != null,
              ),
              _Metric(
                width: metricWidth,
                label: '今日拦截',
                value: '${controller.todayRestrictionEventCount} 次',
                numeric: true,
              ),
              _Metric(
                width: metricWidth,
                label: 'hosts',
                value: controller.restrictionHostsStatus.active ? '已生效' : '未生效',
                color: controller.restrictionHostsStatus.error.isEmpty
                    ? null
                    : Theme.of(context).colorScheme.error,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, RestrictionProfile? profile) {
    if (profile == null) {
      return const EmptyState(
        icon: Icons.shield_outlined,
        title: '尚未创建自律规则',
        message: '创建规则后可配置时段、应用、窗口标题和网站。',
      );
    }
    return LogSurface(
      child: Column(
        children: [
          SwitchListTile.adaptive(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
            ),
            value: profile.enabled,
            onChanged: (value) async {
              try {
                await controller.saveRestrictionProfile(
                  profile.copyWith(enabled: value),
                );
              } catch (error) {
                if (context.mounted) {
                  showWorkbenchSnackBar(
                    context,
                    SnackBar(content: Text('$error')),
                  );
                }
              }
            },
            title: Text(
              profile.title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(_profileSummary(profile)),
            secondary: SurfaceIcon(
              profile.enabled ? Icons.shield : Icons.shield_outlined,
            ),
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
            ),
            leading: const SurfaceIcon(Icons.schedule_outlined),
            title: const Text('时段规则'),
            subtitle: Text(
              profile.schedules.isEmpty
                  ? '未设置时段'
                  : profile.schedules.map(_scheduleSummary).join('；'),
            ),
            trailing: IconButton(
              onPressed: () => _editProfile(context, controller, profile),
              tooltip: '编辑规则',
              icon: const Icon(Icons.edit_outlined),
            ),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
            ),
            leading: const SurfaceIcon(Icons.apps_outlined),
            title: Text(
              profile.blockMode == RestrictionBlockMode.blacklist
                  ? '应用黑名单'
                  : '应用白名单',
            ),
            subtitle: Text(
              profile.blockedApps.isEmpty && profile.allowedApps.isEmpty
                  ? '未配置应用'
                  : '${profile.blockedApps.length} 个阻止项 · ${profile.allowedApps.length} 个允许项',
            ),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
            ),
            leading: const SurfaceIcon(Icons.public_outlined),
            title: const Text('网站拦截'),
            subtitle: Text(
              profile.websiteBlocking
                  ? '${profile.blockedWebsites.length} 个网站，hosts 受管区块；代理、VPN 和浏览器内置 DNS 可能绕过'
                  : '未启用',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityCard(
    BuildContext context,
    RestrictionMonitorState monitor,
    RestrictionProfile? profile,
  ) {
    final security = controller.restrictionSecurityState;
    final pending = controller.restrictionCooldownEndsAt;
    return LogSurface(
      child: Column(
        children: [
          SwitchListTile.adaptive(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
            ),
            value: security.hasPassword,
            onChanged: (value) => value
                ? _setPassword(context, controller)
                : _clearPassword(context, controller),
            title: const Text('保护密码'),
            subtitle: Text(
              security.hasPassword ? '敏感修改需要密码并进入 5 分钟冷静期' : '未设置本机保护密码',
            ),
            secondary: const SurfaceIcon(Icons.lock_outline),
          ),
          SwitchListTile.adaptive(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
            ),
            value: profile?.strongProtection == true,
            onChanged: monitor.active
                ? null
                : (value) async {
                    final profile = controller.restrictionProfile;
                    if (profile == null) return;
                    try {
                      await controller.saveRestrictionProfile(
                        profile.copyWith(strongProtection: value),
                      );
                    } catch (error) {
                      if (context.mounted) {
                        showWorkbenchSnackBar(
                          context,
                          SnackBar(content: Text('$error')),
                        );
                      }
                    }
                  },
            title: const Text('强保护'),
            subtitle: const Text('限制时段内固定活动快照，其他设备的削弱修改待时段结束后应用'),
            secondary: const SurfaceIcon(Icons.gpp_maybe_outlined),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
            ),
            leading: const SurfaceIcon(Icons.hourglass_bottom_outlined),
            title: const Text('敏感操作冷静期'),
            subtitle: const Text('固定为 5 分钟；一次性紧急恢复码可立即执行'),
          ),
          if (monitor.active && monitor.activeSnapshot?.allowBreak == true)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
              ),
              leading: const SurfaceIcon(Icons.free_breakfast_outlined),
              title: Text(
                monitor.isPaused(controller.currentTime()) ? '临时休息中' : '临时休息',
              ),
              subtitle: Text(
                monitor.activeSnapshot!.maxBreaksPerDay == 0
                    ? '今日已使用 ${monitor.breaksUsed} 次，不限次数'
                    : '今日已使用 ${monitor.breaksUsed}/${monitor.activeSnapshot!.maxBreaksPerDay} 次',
              ),
              trailing: monitor.isPaused(controller.currentTime())
                  ? TextButton(
                      onPressed: controller.resumeRestrictionNow,
                      child: const Text('立即恢复'),
                    )
                  : TextButton(
                      onPressed: controller.takeRestrictionBreak,
                      child: const Text('开始休息'),
                    ),
            ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
            ),
            leading: const SurfaceIcon(Icons.vpn_key_outlined),
            title: const Text('紧急恢复码'),
            subtitle: const Text('一次性、本机保存，生成新码会替换旧码'),
            trailing: TextButton(
              onPressed: () => _generateEmergencyCode(context, controller),
              child: const Text('生成'),
            ),
          ),
          if (pending != null)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
              ),
              leading: const SurfaceIcon(Icons.hourglass_top_outlined),
              title: const Text('冷静期进行中'),
              subtitle: Text('将在 ${_dateTime(pending)} 应用待定操作'),
              trailing: TextButton(
                onPressed: controller.cancelPendingRestrictionAction,
                child: const Text('取消'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEvents(BuildContext context) {
    return _RestrictionEvents(events: controller.restrictionEvents);
  }

  Widget _buildProtectionSummary(
    BuildContext context,
    RestrictionProfile? profile,
  ) {
    final hosts = controller.restrictionHostsStatus;
    return LogSurface(
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
            ),
            leading: SurfaceIcon(
              profile?.strongProtection == true
                  ? Icons.gpp_good_outlined
                  : Icons.gpp_maybe_outlined,
            ),
            title: const Text('强保护'),
            subtitle: Text(profile?.strongProtection == true ? '已启用' : '未启用'),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
            ),
            leading: const SurfaceIcon(Icons.power_outlined),
            title: const Text('Windows 后台行为'),
            subtitle: Text(
              '开机启动：${controller.startupEnabled ? '已开启' : '未开启'} · '
              '关闭窗口进托盘：${controller.closeToTray ? '已开启' : '未开启'}',
            ),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
            ),
            leading: SurfaceIcon(
              hosts.active
                  ? Icons.check_circle_outline
                  : Icons.cloud_off_outlined,
              color: hosts.error.isEmpty
                  ? null
                  : Theme.of(context).colorScheme.error,
            ),
            title: const Text('hosts 与系统诊断'),
            subtitle: Text(
              hosts.error.isNotEmpty
                  ? hosts.error
                  : hosts.active
                  ? 'hosts 受管区块完整'
                  : hosts.supported
                  ? '当前未启用 hosts 拦截'
                  : 'Android 不执行 Windows hosts 限制',
            ),
            trailing: TextButton(
              onPressed: () => _showSettingsHint(context),
              child: const Text('前往设置'),
            ),
          ),
        ],
      ),
    );
  }

  void _showSettingsHint(BuildContext context) {
    if (onOpenSettings != null) {
      onOpenSettings!();
      return;
    }
    showWorkbenchSnackBar(
      context,
      const SnackBar(content: Text('请在主设置的“系统行为”和“诊断与恢复”中管理。')),
    );
  }
}

/// 独立自律页；FocusHub 中的旧自律标签仍复用 [RestrictionSection]。
class RestrictionPage extends StatelessWidget {
  const RestrictionPage({
    super.key,
    required this.controller,
    this.showHeader = true,
    this.onOpenSettings,
  });

  final WorkbenchController controller;
  final bool showHeader;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final profile = controller.restrictionProfile;
    final windows = Platform.isWindows;
    return Column(
      children: [
        if (showHeader)
          PageHeader(
            title: '自律',
            subtitle: windows
                ? 'Windows 正在执行规则，Android 仅管理同步配置'
                : '规则可编辑并同步；限制仅在 Windows 执行',
            actions: [
              FilledButton.icon(
                onPressed: () =>
                    showRestrictionProfileEditor(context, controller),
                icon: const Icon(Icons.edit_outlined),
                label: Text(profile == null ? '新建规则' : '编辑规则'),
              ),
            ],
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pageCompact,
            ),
            child: Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: () =>
                    showRestrictionProfileEditor(context, controller),
                tooltip: '编辑自律规则',
                icon: const Icon(Icons.edit_outlined),
              ),
            ),
          ),
        Expanded(
          child: RestrictionSection(
            controller: controller,
            onOpenSettings: onOpenSettings,
          ),
        ),
      ],
    );
  }
}

/// 新建 / 编辑自律规则（合并页「自律」头部动作）。
Future<void> showRestrictionProfileEditor(
  BuildContext context,
  WorkbenchController controller,
) async {
  final profile = controller.restrictionProfile;
  await _editProfile(
    context,
    controller,
    profile ?? controller.createRestrictionProfile(),
  );
}

Future<void> _editProfile(
  BuildContext context,
  WorkbenchController controller,
  RestrictionProfile initial,
) async {
  final result = await showWorkbenchDialog<RestrictionProfile>(
    context: context,
    builder: (context) => _RestrictionEditor(initial: initial),
  );
  if (result == null) return;
  try {
    final executeAt = await controller.saveRestrictionProfile(result);
    if (context.mounted) {
      showWorkbenchSnackBar(
        context,
        SnackBar(
          content: Text(
            executeAt == null
                ? '规则已保存'
                : '强保护生效中，将在 ${_dateTime(executeAt)} 应用',
          ),
        ),
      );
    }
  } catch (error) {
    if (context.mounted) {
      showWorkbenchSnackBar(context, SnackBar(content: Text('$error')));
    }
  }
}

Future<void> _setPassword(
  BuildContext context,
  WorkbenchController controller,
) async {
  final current = TextEditingController();
  final next = TextEditingController();
  final confirmed = await showWorkbenchDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('设置保护密码'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (controller.restrictionSecurityState.hasPassword)
            ExternalField(
              label: '当前密码',
              child: TextField(
                controller: current,
                obscureText: true,
                decoration: const InputDecoration(),
              ),
            ),
          ExternalField(
            label: '新密码（至少 8 位）',
            child: TextField(
              controller: next,
              obscureText: true,
              decoration: const InputDecoration(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('保存'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    await controller.setRestrictionPassword(
      currentPassword: current.text,
      newPassword: next.text,
    );
    if (context.mounted) {
      showWorkbenchSnackBar(context, const SnackBar(content: Text('保护密码已更新')));
    }
  } catch (error) {
    if (context.mounted) {
      showWorkbenchSnackBar(context, SnackBar(content: Text('$error')));
    }
  }
}

Future<void> _clearPassword(
  BuildContext context,
  WorkbenchController controller,
) async {
  final password = await _credential(context, '清除保护密码');
  if (password == null) return;
  try {
    await controller.clearRestrictionPassword(password);
    if (context.mounted) {
      showWorkbenchSnackBar(context, const SnackBar(content: Text('保护密码已清除')));
    }
  } catch (error) {
    if (context.mounted) {
      showWorkbenchSnackBar(context, SnackBar(content: Text('$error')));
    }
  }
}

Future<void> _generateEmergencyCode(
  BuildContext context,
  WorkbenchController controller,
) async {
  try {
    final code = await controller.generateRestrictionEmergencyCode();
    if (context.mounted) {
      await showWorkbenchDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('紧急恢复码'),
          content: SelectableText(code),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('完成'),
            ),
          ],
        ),
      );
    }
  } catch (error) {
    if (context.mounted) {
      showWorkbenchSnackBar(context, SnackBar(content: Text('$error')));
    }
  }
}

Future<String?> _credential(BuildContext context, String title) async {
  final field = TextEditingController();
  final result = await showWorkbenchDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: ExternalField(
        label: '密码或紧急恢复码',
        child: TextField(
          controller: field,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, field.text),
          child: const Text('确认'),
        ),
      ],
    ),
  );
  field.dispose();
  return result;
}

class _RestrictionEditor extends StatefulWidget {
  const _RestrictionEditor({required this.initial});
  final RestrictionProfile initial;

  @override
  State<_RestrictionEditor> createState() => _RestrictionEditorState();
}

class _RestrictionEditorState extends State<_RestrictionEditor> {
  late final TextEditingController _title = TextEditingController(
    text: widget.initial.title,
  );
  late final TextEditingController _apps = TextEditingController(
    text: widget.initial.blockedApps.join('\n'),
  );
  late final TextEditingController _allowed = TextEditingController(
    text: widget.initial.allowedApps.join('\n'),
  );
  late final TextEditingController _appActions = TextEditingController(
    text: widget.initial.appActions.entries
        .map((entry) => '${entry.key}=${entry.value.name}')
        .join('\n'),
  );
  late final TextEditingController _keywords = TextEditingController(
    text: widget.initial.blockedTitleKeywords.join('\n'),
  );
  late final TextEditingController _keywordProcesses = TextEditingController(
    text: widget.initial.titleKeywordProcesses.join('\n'),
  );
  late final TextEditingController _websites = TextEditingController(
    text: widget.initial.blockedWebsites.join('\n'),
  );
  late RestrictionBlockMode _mode = widget.initial.blockMode;
  late RestrictionAction _action = widget.initial.defaultAction;
  late RestrictionAction _titleAction = widget.initial.titleKeywordAction;
  late bool _enabled = widget.initial.enabled;
  late bool _titleBlocking = widget.initial.titleKeywordBlocking;
  late bool _websiteBlocking = widget.initial.websiteBlocking;
  late bool _allowBreak = widget.initial.allowBreak;
  late bool _strong = widget.initial.strongProtection;
  late int _breakMinutes = widget.initial.breakMinutes;
  late int _maxBreaks = widget.initial.maxBreaksPerDay;
  late int _poll = widget.initial.pollIntervalSeconds;
  late final List<RestrictionScheduleRule> _schedules = [
    ...widget.initial.schedules,
  ];

  @override
  void dispose() {
    for (final field in [
      _title,
      _apps,
      _allowed,
      _appActions,
      _keywords,
      _keywordProcesses,
      _websites,
    ]) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    final editorContent = SingleChildScrollView(
      padding: compact
          ? const EdgeInsets.fromLTRB(16, 12, 16, 24)
          : EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionLabel(context, '规则', topPadding: false),
          ExternalField(
            label: '规则名称',
            child: TextField(
              controller: _title,
              decoration: const InputDecoration(),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
            title: const Text('启用规则'),
          ),
          ExternalField(
            label: '应用匹配模式',
            child: DropdownButtonFormField<RestrictionBlockMode>(
              isExpanded: true,
              initialValue: _mode,
              decoration: const InputDecoration(),
              items: const [
                DropdownMenuItem(
                  value: RestrictionBlockMode.blacklist,
                  child: Text('黑名单：命中后限制', overflow: TextOverflow.ellipsis),
                ),
                DropdownMenuItem(
                  value: RestrictionBlockMode.whitelist,
                  child: Text('白名单：未命中后限制', overflow: TextOverflow.ellipsis),
                ),
              ],
              onChanged: (v) => setState(() => _mode = v ?? _mode),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ExternalField(
            label: '默认动作',
            child: DropdownButtonFormField<RestrictionAction>(
              isExpanded: true,
              initialValue: _action,
              decoration: const InputDecoration(),
              items: const [
                DropdownMenuItem(
                  value: RestrictionAction.warn,
                  child: Text('提醒', overflow: TextOverflow.ellipsis),
                ),
                DropdownMenuItem(
                  value: RestrictionAction.forceClose,
                  child: Text('强制结束进程', overflow: TextOverflow.ellipsis),
                ),
              ],
              onChanged: (v) => setState(() => _action = v ?? _action),
            ),
          ),
          _sectionLabel(context, '时段'),
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    children: _schedules.isEmpty
                        ? const [TextSpan(text: '未设置时段')]
                        : [
                            TextSpan(
                              text: '${_schedules.length}',
                              style: const TextStyle(
                                fontFamily: AppFonts.numeric,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            const TextSpan(text: ' 个时段'),
                          ],
                  ),
                ),
              ),
              IconButton(
                onPressed: () async {
                  final rule = await _editSchedule(context);
                  if (rule != null) {
                    setState(() => _schedules.add(rule));
                  }
                },
                tooltip: '添加时段',
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          for (final rule in _schedules)
            ListTile(
              key: ValueKey(rule.id),
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                rule.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                _scheduleSummary(rule),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              trailing: SizedBox(
                width: 96,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: () async {
                        final edited = await _editSchedule(
                          context,
                          initial: rule,
                        );
                        if (edited != null) {
                          setState(
                            () => _schedules[_schedules.indexOf(rule)] = edited,
                          );
                        }
                      },
                      tooltip: '编辑时段',
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _schedules.remove(rule)),
                      tooltip: '删除时段',
                      style: IconButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            ),
          _sectionLabel(context, '应用'),
          ExternalField(
            label: '阻止应用',
            child: TextField(
              controller: _apps,
              maxLines: 3,
              decoration: const InputDecoration(helperText: '每行一个进程名'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ExternalField(
            label: '允许应用',
            child: TextField(
              controller: _allowed,
              maxLines: 3,
              decoration: const InputDecoration(helperText: '白名单或豁免'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ExternalField(
            label: '动作覆盖',
            child: TextField(
              controller: _appActions,
              maxLines: 3,
              decoration: const InputDecoration(
                helperText: '每行：进程名=warn 或 forceClose',
                helperMaxLines: 2,
              ),
            ),
          ),
          _sectionLabel(context, '窗口标题与网站'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _titleBlocking,
            onChanged: (v) => setState(() => _titleBlocking = v),
            title: const Text('窗口标题关键词'),
          ),
          _animatedSettings(
            context,
            visible: _titleBlocking,
            child: Column(
              children: [
                ExternalField(
                  label: '检查的进程（可选）',
                  child: TextField(
                    controller: _keywordProcesses,
                    maxLines: 2,
                    decoration: const InputDecoration(),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ExternalField(
                  label: '标题关键词',
                  child: TextField(
                    controller: _keywords,
                    maxLines: 3,
                    decoration: const InputDecoration(helperText: '每行一个'),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ExternalField(
                  label: '标题命中动作',
                  child: DropdownButtonFormField<RestrictionAction>(
                    isExpanded: true,
                    initialValue: _titleAction,
                    decoration: const InputDecoration(),
                    items: const [
                      DropdownMenuItem(
                        value: RestrictionAction.warn,
                        child: Text('提醒', overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: RestrictionAction.forceClose,
                        child: Text('强制结束进程', overflow: TextOverflow.ellipsis),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _titleAction = v ?? _titleAction),
                  ),
                ),
              ],
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _websiteBlocking,
            onChanged: (v) => setState(() => _websiteBlocking = v),
            title: const Text('网站拦截（Windows hosts）'),
          ),
          _animatedSettings(
            context,
            visible: _websiteBlocking,
            child: ExternalField(
              label: '网站域名',
              child: TextField(
                controller: _websites,
                maxLines: 3,
                decoration: const InputDecoration(helperText: '每行一个'),
              ),
            ),
          ),
          _sectionLabel(context, '休息与保护'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _allowBreak,
            onChanged: (v) => setState(() => _allowBreak = v),
            title: const Text('允许临时休息'),
          ),
          _animatedSettings(
            context,
            visible: _allowBreak,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final fields = [
                  ExternalField(
                    label: '休息分钟',
                    child: TextFormField(
                      initialValue: '$_breakMinutes',
                      decoration: const InputDecoration(),
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        fontFamily: AppFonts.numeric,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                      onChanged: (v) =>
                          _breakMinutes = int.tryParse(v) ?? _breakMinutes,
                    ),
                  ),
                  ExternalField(
                    label: '每日次数',
                    child: TextFormField(
                      initialValue: '$_maxBreaks',
                      decoration: const InputDecoration(),
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        fontFamily: AppFonts.numeric,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                      onChanged: (v) =>
                          _maxBreaks = int.tryParse(v) ?? _maxBreaks,
                    ),
                  ),
                ];
                if (constraints.maxWidth < 360) {
                  return Column(
                    children: [
                      fields.first,
                      const SizedBox(height: AppSpacing.md),
                      fields.last,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: fields.first),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: fields.last),
                  ],
                );
              },
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _strong,
            onChanged: (v) => setState(() => _strong = v),
            title: const Text('强保护'),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final fieldWidth = constraints.maxWidth > 420
                  ? 420.0
                  : constraints.maxWidth;
              return Align(
                alignment: Alignment.center,
                child: SizedBox(
                  width: fieldWidth,
                  child: ExternalField(
                    label: '检测间隔',
                    child: DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: _poll,
                      decoration: const InputDecoration(),
                      items: [1, 3, 5, 10, 30, 60]
                          .map(
                            (v) => DropdownMenuItem(
                              value: v,
                              child: Text(
                                '$v 秒',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: AppFonts.numeric,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _poll = v ?? _poll),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
    final cancelAction = TextButton(
      onPressed: () => Navigator.pop(context),
      child: const Text('取消'),
    );
    final saveAction = FilledButton(
      onPressed: () => Navigator.pop(context, _result()),
      child: const Text('保存'),
    );
    if (compact) {
      return Dialog.fullscreen(
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              tooltip: '关闭',
              icon: const Icon(Icons.close),
            ),
            title: const Text('编辑自律规则'),
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1),
            ),
          ),
          body: SafeArea(top: false, child: editorContent),
          bottomNavigationBar: SafeArea(
            top: false,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(top: BorderSide(color: context.tokens.divider)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Row(
                  children: [
                    Expanded(child: cancelAction),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: saveAction),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return AlertDialog(
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('编辑自律规则'),
          SizedBox(height: AppSpacing.sm),
          Divider(),
        ],
      ),
      content: SizedBox(width: 620, child: editorContent),
      actions: [cancelAction, saveAction],
    );
  }

  Widget _sectionLabel(
    BuildContext context,
    String text, {
    bool topPadding = true,
  }) => Padding(
    padding: EdgeInsets.only(
      top: topPadding ? AppSpacing.lg : 0,
      bottom: AppSpacing.sm,
    ),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _animatedSettings(
    BuildContext context, {
    required bool visible,
    required Widget child,
  }) => ClipRect(
    child: AnimatedSize(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : visible
          ? AppMotion.standard
          : AppMotion.exit,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      // 外置标签在展开动画中需要保留上缘空间，避免文字被 ClipRect 裁切。
      child: visible
          ? Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: child,
            )
          : const SizedBox.shrink(),
    ),
  );

  RestrictionProfile _result() => widget.initial.copyWith(
    title: _title.text.trim().isEmpty
        ? widget.initial.title
        : _title.text.trim(),
    enabled: _enabled,
    schedules: _schedules,
    blockMode: _mode,
    defaultAction: _action,
    blockedApps: _lines(_apps.text),
    allowedApps: _lines(_allowed.text),
    appActions: _actions(_appActions.text),
    titleKeywordBlocking: _titleBlocking,
    titleKeywordAction: _titleAction,
    titleKeywordProcesses: _lines(_keywordProcesses.text),
    blockedTitleKeywords: _lines(_keywords.text),
    websiteBlocking: _websiteBlocking,
    blockedWebsites: _lines(_websites.text),
    allowBreak: _allowBreak,
    breakMinutes: _breakMinutes,
    maxBreaksPerDay: _maxBreaks,
    strongProtection: _strong,
    pollIntervalSeconds: _poll,
  );

  List<String> _lines(String value) => value
      .split(RegExp(r'[\r\n,]'))
      .map((v) => v.trim())
      .where((v) => v.isNotEmpty)
      .toList();

  Map<String, RestrictionAction> _actions(String value) {
    final result = <String, RestrictionAction>{};
    for (final line in value.split(RegExp(r'[\r\n]'))) {
      final parts = line.split('=');
      if (parts.length != 2 || parts[0].trim().isEmpty) continue;
      result[parts[0].trim().toLowerCase()] = restrictionActionFromJson(
        parts[1].trim(),
      );
    }
    return result;
  }

  Future<RestrictionScheduleRule?> _editSchedule(
    BuildContext context, {
    RestrictionScheduleRule? initial,
  }) => showWorkbenchDialog<RestrictionScheduleRule>(
    context: context,
    builder: (context) => _ScheduleEditor(initial: initial),
  );
}

class _ScheduleEditor extends StatefulWidget {
  const _ScheduleEditor({this.initial});
  final RestrictionScheduleRule? initial;
  @override
  State<_ScheduleEditor> createState() => _ScheduleEditorState();
}

class _ScheduleEditorState extends State<_ScheduleEditor> {
  late final TextEditingController _label = TextEditingController(
    text: widget.initial?.label ?? '限制时段',
  );
  late final TextEditingController _start = TextEditingController(
    text: _formatMinutes(widget.initial?.startMinutes ?? 9 * 60),
  );
  late final TextEditingController _end = TextEditingController(
    text: _formatMinutes(widget.initial?.endMinutes ?? 18 * 60),
  );
  late final Set<int> _days = {...?widget.initial?.days};

  @override
  void dispose() {
    _label.dispose();
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('时段规则'),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExternalField(
            label: '名称',
            child: TextField(
              controller: _label,
              decoration: const InputDecoration(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final fields = [
                ExternalField(
                  label: '开始 HH:MM',
                  child: TextField(
                    controller: _start,
                    keyboardType: TextInputType.datetime,
                    style: const TextStyle(
                      fontFamily: AppFonts.numeric,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                    decoration: const InputDecoration(),
                  ),
                ),
                ExternalField(
                  label: '结束 HH:MM',
                  child: TextField(
                    controller: _end,
                    keyboardType: TextInputType.datetime,
                    style: const TextStyle(
                      fontFamily: AppFonts.numeric,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                    decoration: const InputDecoration(),
                  ),
                ),
              ];
              if (constraints.maxWidth < 320) {
                return Column(
                  children: [
                    fields.first,
                    const SizedBox(height: AppSpacing.md),
                    fields.last,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: fields.first),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: fields.last),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final day in List.generate(7, (i) => i + 1))
                  FilterChip(
                    label: Text(_dayLabel(day)),
                    selected: _days.contains(day),
                    onSelected: (v) =>
                        setState(() => v ? _days.add(day) : _days.remove(day)),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(onPressed: _save, child: const Text('保存')),
    ],
  );

  void _save() {
    final start = _parseMinutes(_start.text);
    final end = _parseMinutes(_end.text);
    if (start == null || end == null || start == end || _days.isEmpty) {
      showWorkbenchSnackBar(
        context,
        const SnackBar(content: Text('请输入不同的有效起止时间，并至少选择一天。')),
      );
      return;
    }
    Navigator.pop(
      context,
      RestrictionScheduleRule(
        id: widget.initial?.id ?? newRecordId(),
        label: _label.text.trim().isEmpty ? '限制时段' : _label.text.trim(),
        days: _days.toList()..sort(),
        startMinutes: start,
        endMinutes: end,
      ),
    );
  }
}

class _PlatformNotice extends StatelessWidget {
  const _PlatformNotice();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: LogSurface(
      accent: Theme.of(context).colorScheme.tertiary,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: const Row(
        children: [
          Icon(Icons.info_outline),
          SizedBox(width: 10),
          Expanded(child: Text('Android 可以查看、编辑和同步规则，实际拦截仅在 Windows 端生效。')),
        ],
      ),
    ),
  );
}

class _ExitRequestBanner extends StatelessWidget {
  const _ExitRequestBanner({required this.controller});
  final WorkbenchController controller;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: LogSurface(
      accent: Theme.of(context).colorScheme.error,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final message = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.lock_clock_outlined),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('应用关闭请求已拦截。强保护期间需要密码并进入冷静期，紧急恢复码可立即退出。'),
              ),
            ],
          );
          final action = TextButton(
            onPressed: () => _handleExitRequest(context),
            child: const Text('处理'),
          );
          if (constraints.maxWidth < 460) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                message,
                Align(alignment: Alignment.centerRight, child: action),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: message),
              action,
            ],
          );
        },
      ),
    ),
  );

  Future<void> _handleExitRequest(BuildContext context) async {
    final credential = await _askInlineCredential(context);
    if (credential == null) return;
    try {
      final at = await controller.requestRestrictionExit(credential);
      if (context.mounted) {
        showWorkbenchSnackBar(
          context,
          SnackBar(
            content: Text(at == null ? '正在退出' : '退出将在 ${_dateTime(at)} 执行'),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        showWorkbenchSnackBar(context, SnackBar(content: Text('$error')));
      }
    }
  }
}

Future<String?> _askInlineCredential(BuildContext context) async {
  final field = TextEditingController();
  final result = await showWorkbenchDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('确认退出保护'),
      content: ExternalField(
        label: '密码或紧急恢复码',
        child: TextField(
          controller: field,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, field.text),
          child: const Text('确认'),
        ),
      ],
    ),
  );
  field.dispose();
  return result;
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.width,
    required this.label,
    required this.value,
    this.color,
    this.numeric = false,
  });
  final double width;
  final String label;
  final String value;
  final Color? color;
  final bool numeric;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: context.tokens.mutedText),
        ),
        const SizedBox(height: 3),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: AnimatedSwitcher(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : AppMotion.standard,
            reverseDuration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : AppMotion.exit,
            child: Align(
              key: ValueKey(value),
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                  fontFamily: numeric ? AppFonts.numeric : null,
                  fontFeatures: numeric
                      ? const [FontFeature.tabularFigures()]
                      : null,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _RestrictionEvents extends StatefulWidget {
  const _RestrictionEvents({required this.events});
  final List<WorkspaceRecord> events;

  @override
  State<_RestrictionEvents> createState() => _RestrictionEventsState();
}

class _RestrictionEventsState extends State<_RestrictionEvents> {
  final TextEditingController _process = TextEditingController();
  String _period = 'all';
  String _reason = 'all';
  String _action = 'all';

  @override
  void dispose() {
    _process.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reasons =
        widget.events
            .map((event) => event.data['reason']?.toString() ?? '')
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final events = widget.events.where(_matches).take(50).toList();
    return LogSurface(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final processWidth = compact ? constraints.maxWidth : 180.0;
              final periodWidth = compact ? constraints.maxWidth : 150.0;
              final reasonWidth = compact ? constraints.maxWidth : 190.0;
              final actionWidth = compact ? constraints.maxWidth : 165.0;
              return Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  SizedBox(
                    width: processWidth,
                    child: ExternalField(
                      label: '进程',
                      child: TextField(
                        controller: _process,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: periodWidth,
                    child: ExternalField(
                      label: '日期',
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _period,
                        decoration: const InputDecoration(),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('全部')),
                          DropdownMenuItem(value: 'today', child: Text('今天')),
                          DropdownMenuItem(value: 'week', child: Text('近 7 天')),
                        ],
                        onChanged: (value) =>
                            setState(() => _period = value ?? 'all'),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: reasonWidth,
                    child: ExternalField(
                      label: '原因',
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _reason,
                        decoration: const InputDecoration(),
                        items: [
                          const DropdownMenuItem(
                            value: 'all',
                            child: Text('全部'),
                          ),
                          ...reasons.map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(
                                value,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _reason = value ?? 'all'),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: actionWidth,
                    child: ExternalField(
                      label: '动作',
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _action,
                        decoration: const InputDecoration(),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('全部')),
                          DropdownMenuItem(value: 'warn', child: Text('提醒')),
                          DropdownMenuItem(
                            value: 'forceClose',
                            child: Text('强制结束'),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _action = value ?? 'all'),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          if (events.isEmpty)
            const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: '暂无匹配记录',
              message: '规则触发后会记录进程、原因、动作和执行结果。',
            )
          else
            for (final event in events) _RestrictionEventTile(event: event),
        ],
      ),
    );
  }

  bool _matches(WorkspaceRecord event) {
    final query = _process.text.trim().toLowerCase();
    if (query.isNotEmpty && !event.title.toLowerCase().contains(query)) {
      return false;
    }
    if (_reason != 'all' && event.data['reason']?.toString() != _reason) {
      return false;
    }
    if (_action != 'all' && event.data['action']?.toString() != _action) {
      return false;
    }
    final at = event.scheduledFor ?? event.createdAt;
    final now = DateTime.now();
    if (_period == 'today' &&
        (at.year != now.year || at.month != now.month || at.day != now.day)) {
      return false;
    }
    if (_period == 'week' &&
        at.isBefore(now.subtract(const Duration(days: 7)))) {
      return false;
    }
    return true;
  }
}

class _RestrictionEventTile extends StatelessWidget {
  const _RestrictionEventTile({required this.event});

  final WorkspaceRecord event;

  @override
  Widget build(BuildContext context) {
    final succeeded = event.status == WorkStatus.done;
    final action = event.data['action']?.toString() ?? 'warn';
    final actionLabel = action == RestrictionAction.forceClose.name
        ? '强制结束'
        : '提醒';
    final actionPill = StatusPill(
      label: actionLabel,
      icon: action == RestrictionAction.forceClose.name
          ? Icons.block_outlined
          : Icons.notifications_none_outlined,
      color: action == RestrictionAction.forceClose.name
          ? Theme.of(context).colorScheme.error
          : Theme.of(context).colorScheme.primary,
    );
    final detail = Text(
      '${event.data['reason'] ?? '规则命中'} · ${_dateTime(event.scheduledFor ?? event.createdAt)}',
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 460;
        return ListTile(
          key: ValueKey(event.id),
          contentPadding: EdgeInsets.zero,
          leading: SurfaceIcon(
            succeeded ? Icons.check_circle_outline : Icons.error_outline,
            color: succeeded
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.error,
          ),
          title: Text(event.title),
          subtitle: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    detail,
                    const SizedBox(height: AppSpacing.sm),
                    actionPill,
                  ],
                )
              : detail,
          trailing: compact ? null : actionPill,
        );
      },
    );
  }
}

String _profileSummary(RestrictionProfile profile) =>
    '${profile.schedules.length} 个时段 · ${profile.defaultAction == RestrictionAction.warn ? '提醒' : '强制结束'} · ${profile.strongProtection ? '强保护' : '普通保护'}';
String _scheduleSummary(RestrictionScheduleRule rule) =>
    '${rule.days.map(_dayLabel).join('、')} ${_formatMinutes(rule.startMinutes)}-${_formatMinutes(rule.endMinutes)}${rule.crossesMidnight ? '（跨午夜）' : ''}';
String _formatMinutes(int value) =>
    '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';
int? _parseMinutes(String value) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value.trim());
  if (match == null) return null;
  final hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  return hour <= 23 && minute <= 59 ? hour * 60 + minute : null;
}

String _dayLabel(int day) =>
    const {1: '一', 2: '二', 3: '三', 4: '四', 5: '五', 6: '六', 7: '日'}[day] ?? '?';
String _dateTime(DateTime value) =>
    '${value.month}/${value.day} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
