import 'dart:io';

import 'package:file_picker/file_picker.dart';
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
  const RestrictionSection({super.key, required this.controller});

  final WorkbenchController controller;

  @override
  Widget build(BuildContext context) {
    final profile = controller.restrictionProfile;
    final monitor = controller.restrictionMonitorState;
    final windows = Platform.isWindows;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 132),
      children: [
        if (controller.restrictionExitRequested)
          _ExitRequestBanner(controller: controller),
        if (!windows)
          const _PlatformNotice(),
        _buildOverview(context, profile, monitor),
        const SectionHeading(title: '规则'),
        _buildProfileCard(context, profile),
        const SectionHeading(title: '保护设置'),
        _buildSecurityCard(context, monitor, profile),
        const SectionHeading(title: '日志与统计'),
        _buildEvents(context),
        const SectionHeading(title: '诊断与恢复'),
        _buildDiagnostics(context, profile),
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
    final statusColor = monitor.active &&
            !monitor.isPaused(controller.currentTime())
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
      child: Wrap(
        spacing: 24,
        runSpacing: 18,
        children: [
          _Metric(label: '当前状态', value: status, color: statusColor),
          _Metric(
            label: '当前规则',
            value: monitor.activeSnapshot?.title ?? profile?.title ?? '未配置',
          ),
          _Metric(
            label: '下一次切换',
            value: next?.at == null ? '暂无计划' : _dateTime(next!.at!),
          ),
          _Metric(
            label: '今日拦截',
            value: '${controller.todayRestrictionEventCount} 次',
          ),
          _Metric(
            label: 'hosts',
            value: controller.restrictionHostsStatus.active ? '已生效' : '未生效',
            color: controller.restrictionHostsStatus.error.isEmpty
                ? null
                : Theme.of(context).colorScheme.error,
          ),
        ],
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
            contentPadding: EdgeInsets.zero,
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
            secondary: Icon(
              profile.enabled ? Icons.shield : Icons.shield_outlined,
            ),
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule_outlined),
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
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.apps_outlined),
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
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.public_outlined),
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
            contentPadding: EdgeInsets.zero,
            value: security.hasPassword,
            onChanged: (value) =>
                value ? _setPassword(context, controller) : _clearPassword(context, controller),
            title: const Text('保护密码'),
            subtitle: Text(
              security.hasPassword
                  ? '敏感修改需要密码并进入 5 分钟冷静期'
                  : '未设置本机保护密码',
            ),
            secondary: const Icon(Icons.lock_outline),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
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
            secondary: const Icon(Icons.gpp_maybe_outlined),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.hourglass_bottom_outlined),
            title: const Text('敏感操作冷静期'),
            subtitle: const Text('固定为 5 分钟；一次性紧急恢复码可立即执行'),
          ),
          if (Platform.isWindows)
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: controller.startupEnabled,
              onChanged: controller.setStartupEnabled,
              title: const Text('开机启动'),
              secondary: const Icon(Icons.power_outlined),
            ),
          if (Platform.isWindows)
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: controller.closeToTray,
              onChanged: controller.setCloseToTray,
              title: const Text('关闭窗口时进入托盘'),
              secondary: const Icon(Icons.minimize_outlined),
            ),
          if (monitor.active && monitor.activeSnapshot?.allowBreak == true)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.free_breakfast_outlined),
              title: Text(
                monitor.isPaused(controller.currentTime())
                    ? '临时休息中'
                    : '临时休息',
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
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.vpn_key_outlined),
            title: const Text('紧急恢复码'),
            subtitle: const Text('一次性、本机保存，生成新码会替换旧码'),
            trailing: TextButton(
              onPressed: () => _generateEmergencyCode(context, controller),
              child: const Text('生成'),
            ),
          ),
          if (pending != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.hourglass_top_outlined),
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

  Widget _buildDiagnostics(
    BuildContext context,
    RestrictionProfile? profile,
  ) {
    final hosts = controller.restrictionHostsStatus;
    return LogSurface(
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              hosts.administrator
                  ? Icons.admin_panel_settings_outlined
                  : Icons.person_outline,
            ),
            title: const Text('管理员权限'),
            subtitle: Text(
              hosts.supported
                  ? (hosts.administrator
                      ? '已具备'
                      : '未具备，写入 hosts 时可能需要 UAC')
                  : '当前平台不支持 Windows 原生限制',
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              hosts.active ? Icons.check_circle_outline : Icons.cloud_off_outlined,
            ),
            title: const Text('hosts 健康状态'),
            subtitle: Text(
              hosts.error.isNotEmpty
                  ? hosts.error
                  : hosts.externallyModified
                      ? '检测到受管区块缺失或被外部修改'
                      : hosts.active
                          ? '受管区块完整'
                          : '未发现活动受管区块',
            ),
            trailing: Wrap(
              spacing: 4,
              children: [
                IconButton(
                  onPressed: controller.refreshRestrictionHostsStatus,
                  tooltip: '重新检查',
                  icon: const Icon(Icons.refresh),
                ),
                if (profile?.websiteBlocking == true)
                  IconButton(
                    onPressed: controller.repairRestrictionHosts,
                    tooltip: '修复 hosts',
                    icon: const Icon(Icons.build_outlined),
                  ),
                if (hosts.active)
                  IconButton(
                    onPressed: controller.clearRestrictionHosts,
                    tooltip: '清理 hosts',
                    icon: const Icon(Icons.cleaning_services_outlined),
                  ),
              ],
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.power_settings_new_outlined),
            title: const Text('异常退出恢复'),
            subtitle: Text(
              controller.restrictionRecoveredAfterAbnormalExit
                  ? '检测到上次异常退出，活动限制已恢复'
                  : '未发现异常退出',
            ),
          ),
        ],
      ),
    );
  }
}

/// 旧版独立自律页。
///
/// @Deprecated：已并入「专注」页（FocusHubPage 的「自律」Tab），
/// 保留此类仅用于兼容既有测试与过渡期深链。
@Deprecated('已并入专注页（FocusHubPage 的「自律」Tab），请使用 RestrictionSection')
class RestrictionPage extends StatelessWidget {
  const RestrictionPage({
    super.key,
    required this.controller,
    this.showHeader = true,
  });

  final WorkbenchController controller;
  final bool showHeader;

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
              OutlinedButton.icon(
                onPressed: () => showRestrictionImportDialog(context, controller),
                icon: const Icon(Icons.file_upload_outlined),
                label: const Text('导入 SelfControl'),
              ),
              FilledButton.icon(
                onPressed: () => showRestrictionProfileEditor(context, controller),
                icon: const Icon(Icons.edit_outlined),
                label: Text(profile == null ? '新建规则' : '编辑规则'),
              ),
            ],
          )
        else
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              onPressed: () => showRestrictionProfileEditor(context, controller),
              tooltip: '编辑自律规则',
              icon: const Icon(Icons.edit_outlined),
            ),
          ),
        Expanded(child: RestrictionSection(controller: controller)),
      ],
    );
  }
}

/// 导入 SelfControl 数据（合并页「自律」头部动作）。
Future<void> showRestrictionImportDialog(
  BuildContext context,
  WorkbenchController controller,
) async {
  final directory = await FilePicker.getDirectoryPath(
    dialogTitle: '选择 SelfControl 来源目录',
  );
  if (directory == null || !context.mounted) return;
  try {
    final preview = await controller.previewSelfControlImport(directory);
    if (!context.mounted) return;
    final choice = await showWorkbenchDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入预览'),
        content: SingleChildScrollView(
          child: Text(
            '规则：${preview.profile.schedules.length} 个时段\n结构化事件：${preview.eventCount}\n习惯：${preview.habitCount}，打卡：${preview.habitLogCount}\n专注记录：${preview.focusSessionCount}\n文本日志：${preview.blockLog == null ? '无' : '作为只读附件保存'}\n\n导入会先创建当前数据库备份，规则默认不启用。',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 0),
            child: const Text('取消'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, 1),
            child: const Text('导入但不启用'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 2),
            child: const Text('导入并启用'),
          ),
        ],
      ),
    );
    if (choice == null || choice == 0) return;
    final enable = choice == 2;
    final backup = await controller.importSelfControl(
      preview,
      enableProfile: enable,
    );
    if (context.mounted) {
      showWorkbenchSnackBar(
        context,
        SnackBar(
          content: Text(
            enable
                ? '导入完成并已启用，备份已保存：${backup.path}'
                : '导入完成，备份已保存：${backup.path}；规则保持停用。',
          ),
        ),
      );
    }
  } catch (error) {
    if (context.mounted) {
      showWorkbenchSnackBar(context, SnackBar(content: Text('导入失败：$error')));
    }
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
            TextField(
              controller: current,
              obscureText: true,
              decoration: const InputDecoration(labelText: '当前密码'),
            ),
          TextField(
            controller: next,
            obscureText: true,
            decoration: const InputDecoration(labelText: '新密码（至少 8 位）'),
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
      content: TextField(
        controller: field,
        obscureText: true,
        autofocus: true,
        decoration: const InputDecoration(labelText: '密码或紧急恢复码'),
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
    return AlertDialog(
      title: const Text('编辑自律规则'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: '规则名称'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
                title: const Text('启用规则'),
              ),
              DropdownButtonFormField<RestrictionBlockMode>(
                initialValue: _mode,
                decoration: const InputDecoration(labelText: '应用匹配模式'),
                items: const [
                  DropdownMenuItem(
                    value: RestrictionBlockMode.blacklist,
                    child: Text('黑名单：命中后限制'),
                  ),
                  DropdownMenuItem(
                    value: RestrictionBlockMode.whitelist,
                    child: Text('白名单：未命中后限制'),
                  ),
                ],
                onChanged: (v) => setState(() => _mode = v ?? _mode),
              ),
              DropdownButtonFormField<RestrictionAction>(
                initialValue: _action,
                decoration: const InputDecoration(labelText: '默认动作'),
                items: const [
                  DropdownMenuItem(
                    value: RestrictionAction.warn,
                    child: Text('提醒'),
                  ),
                  DropdownMenuItem(
                    value: RestrictionAction.forceClose,
                    child: Text('强制结束进程'),
                  ),
                ],
                onChanged: (v) => setState(() => _action = v ?? _action),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('时段'),
                  const Spacer(),
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
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(_scheduleSummary(rule)),
                  subtitle: Text(rule.label),
                  trailing: Wrap(
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
                        onPressed: () =>
                            setState(() => _schedules.remove(rule)),
                        tooltip: '删除时段',
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              TextField(
                controller: _apps,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '阻止应用（每行一个进程名）'),
              ),
              TextField(
                controller: _allowed,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '允许应用（白名单或豁免）'),
              ),
              TextField(
                controller: _appActions,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '动作覆盖（每行：进程名=warn 或 forceClose）',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _titleBlocking,
                onChanged: (v) => setState(() => _titleBlocking = v),
                title: const Text('窗口标题关键词'),
              ),
              if (_titleBlocking) ...[
                TextField(
                  controller: _keywordProcesses,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: '检查的进程（可选）'),
                ),
                TextField(
                  controller: _keywords,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: '标题关键词（每行一个）'),
                ),
              ],
              if (_titleBlocking)
                DropdownButtonFormField<RestrictionAction>(
                  initialValue: _titleAction,
                  decoration: const InputDecoration(labelText: '标题命中动作'),
                  items: const [
                    DropdownMenuItem(
                      value: RestrictionAction.warn,
                      child: Text('提醒'),
                    ),
                    DropdownMenuItem(
                      value: RestrictionAction.forceClose,
                      child: Text('强制结束进程'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _titleAction = v ?? _titleAction),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _websiteBlocking,
                onChanged: (v) => setState(() => _websiteBlocking = v),
                title: const Text('网站拦截（Windows hosts）'),
              ),
              if (_websiteBlocking)
                TextField(
                  controller: _websites,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: '网站域名（每行一个）'),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _allowBreak,
                onChanged: (v) => setState(() => _allowBreak = v),
                title: const Text('允许临时休息'),
              ),
              if (_allowBreak)
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: '$_breakMinutes',
                        decoration: const InputDecoration(labelText: '休息分钟'),
                        keyboardType: TextInputType.number,
                        onChanged: (v) =>
                            _breakMinutes = int.tryParse(v) ?? _breakMinutes,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        initialValue: '$_maxBreaks',
                        decoration: const InputDecoration(labelText: '每日次数'),
                        keyboardType: TextInputType.number,
                        onChanged: (v) =>
                            _maxBreaks = int.tryParse(v) ?? _maxBreaks,
                      ),
                    ),
                  ],
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _strong,
                onChanged: (v) => setState(() => _strong = v),
                title: const Text('强保护'),
              ),
              DropdownButtonFormField<int>(
                initialValue: _poll,
                decoration: const InputDecoration(labelText: '检测间隔'),
                items: [1, 3, 5, 10, 30, 60]
                    .map(
                      (v) => DropdownMenuItem(value: v, child: Text('$v 秒')),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _poll = v ?? _poll),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _result()),
          child: const Text('保存'),
        ),
      ],
    );
  }

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
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _label,
          decoration: const InputDecoration(labelText: '名称'),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _start,
                decoration: const InputDecoration(labelText: '开始 HH:MM'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _end,
                decoration: const InputDecoration(labelText: '结束 HH:MM'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
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
      ],
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
      child: const Row(
        children: [
          Icon(Icons.info_outline),
          SizedBox(width: 10),
          Expanded(
            child: Text('Android 可以查看、编辑和同步规则，实际拦截仅在 Windows 端生效。'),
          ),
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
      child: Row(
        children: [
          const Icon(Icons.lock_clock_outlined),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '应用关闭请求已拦截。强保护期间需要密码并进入冷静期，紧急恢复码可立即退出。',
            ),
          ),
          TextButton(
            onPressed: () async {
              final credential = await _askInlineCredential(context);
              if (credential == null) return;
              try {
                final at = await controller.requestRestrictionExit(credential);
                if (context.mounted) {
                  showWorkbenchSnackBar(
                    context,
                    SnackBar(
                      content: Text(
                        at == null ? '正在退出' : '退出将在 ${_dateTime(at)} 执行',
                      ),
                    ),
                  );
                }
              } catch (error) {
                if (context.mounted) {
                  showWorkbenchSnackBar(context, SnackBar(content: Text('$error')));
                }
              }
            },
            child: const Text('处理'),
          ),
        ],
      ),
    ),
  );
}

Future<String?> _askInlineCredential(BuildContext context) async {
  final field = TextEditingController();
  final result = await showWorkbenchDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('确认退出保护'),
      content: TextField(
        controller: field,
        obscureText: true,
        autofocus: true,
        decoration: const InputDecoration(labelText: '密码或紧急恢复码'),
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
  const _Metric({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 150,
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
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
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
    final reasons = widget.events
        .map((event) => event.data['reason']?.toString() ?? '')
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final events = widget.events.where(_matches).take(50).toList();
    return LogSurface(
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 180,
                child: TextField(
                  controller: _process,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: '进程',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _period,
                  decoration: const InputDecoration(labelText: '日期'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('全部')),
                    DropdownMenuItem(value: 'today', child: Text('今天')),
                    DropdownMenuItem(value: 'week', child: Text('近 7 天')),
                  ],
                  onChanged: (value) => setState(() => _period = value ?? 'all'),
                ),
              ),
              SizedBox(
                width: 190,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _reason,
                  decoration: const InputDecoration(labelText: '原因'),
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('全部')),
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
                  onChanged: (value) => setState(() => _reason = value ?? 'all'),
                ),
              ),
              SizedBox(
                width: 165,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _action,
                  decoration: const InputDecoration(labelText: '动作'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('全部')),
                    DropdownMenuItem(value: 'warn', child: Text('提醒')),
                    DropdownMenuItem(value: 'forceClose', child: Text('强制结束')),
                  ],
                  onChanged: (value) => setState(() => _action = value ?? 'all'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (events.isEmpty)
            const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: '暂无匹配记录',
              message: '规则触发后会记录进程、原因、动作和执行结果。',
            )
          else
            for (final event in events)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  event.status == WorkStatus.done
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                ),
                title: Text(event.title),
                subtitle: Text(
                  '${event.data['reason'] ?? '规则命中'} · ${_dateTime(event.scheduledFor ?? event.createdAt)}',
                ),
                trailing: Text(event.data['action']?.toString() ?? 'warn'),
              ),
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
    if (_period == 'week' && at.isBefore(now.subtract(const Duration(days: 7)))) {
      return false;
    }
    return true;
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
    const {1: '一', 2: '二', 3: '三', 4: '四', 5: '五', 6: '六', 7: '日'}[day] ??
    '?';
String _dateTime(DateTime value) =>
    '${value.month}/${value.day} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
