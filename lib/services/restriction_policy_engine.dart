import 'dart:io';

import '../core/models/restriction_models.dart';

class RestrictionPolicyEngine {
  const RestrictionPolicyEngine();

  static const _systemProcessNames = {
    'system',
    'system idle process',
    'registry',
    'wininit.exe',
    'winlogon.exe',
    'services.exe',
    'lsass.exe',
    'csrss.exe',
    'smss.exe',
    'svchost.exe',
    'dwm.exe',
    'explorer.exe',
    'taskhostw.exe',
    'sihost.exe',
    'runtimebroker.exe',
    'searchhost.exe',
    'startmenuexperiencehost.exe',
    'textinputhost.exe',
    'securityhealthservice.exe',
    'msmpeng.exe',
    'personal_workbench.exe',
  };

  RestrictionScheduleRule? activeRule(
    RestrictionProfile profile,
    DateTime now,
  ) {
    final minute = now.hour * 60 + now.minute;
    for (final rule in profile.schedules) {
      if (!rule.enabled || rule.days.isEmpty) continue;
      if (!rule.crossesMidnight) {
        if (rule.days.contains(now.weekday) &&
            minute >= rule.startMinutes &&
            minute < rule.endMinutes) {
          return rule;
        }
        continue;
      }
      final previousWeekday = now.weekday == DateTime.monday
          ? DateTime.sunday
          : now.weekday - 1;
      if ((rule.days.contains(now.weekday) && minute >= rule.startMinutes) ||
          (rule.days.contains(previousWeekday) && minute < rule.endMinutes)) {
        return rule;
      }
    }
    return null;
  }

  bool isRestricted(RestrictionProfile profile, DateTime now) =>
      profile.enabled && activeRule(profile, now) != null;

  RestrictionTransition nextTransition(
    RestrictionProfile profile,
    DateTime now,
  ) {
    if (!profile.enabled) {
      return const RestrictionTransition(kind: 'none', at: null, label: '');
    }
    final day = DateTime(now.year, now.month, now.day);
    final candidates = <({DateTime at, String kind, String label})>[];
    for (var offset = -1; offset <= 7; offset++) {
      final base = day.add(Duration(days: offset));
      for (final rule in profile.schedules) {
        if (!rule.enabled || !rule.days.contains(base.weekday)) continue;
        final start = base.add(Duration(minutes: rule.startMinutes));
        var end = base.add(Duration(minutes: rule.endMinutes));
        if (rule.crossesMidnight) end = end.add(const Duration(days: 1));
        if (!now.isBefore(start) && now.isBefore(end)) {
          candidates.add((at: end, kind: 'end', label: rule.label));
        } else if (start.isAfter(now)) {
          candidates.add((at: start, kind: 'start', label: rule.label));
        }
      }
    }
    candidates.sort((a, b) => a.at.compareTo(b.at));
    if (candidates.isEmpty) {
      return const RestrictionTransition(kind: 'none', at: null, label: '');
    }
    final next = candidates.first;
    return RestrictionTransition(
      kind: next.kind,
      at: next.at,
      label: next.label,
    );
  }

  RestrictionViolation? evaluateProcess(
    RestrictionProfile profile,
    RestrictionProcessSnapshot process,
  ) {
    final name = _processName(process.name);
    if (name.isEmpty || _isSystemProcess(name, process.executablePath)) {
      return null;
    }

    final action = profile.appActions[name] ?? profile.defaultAction;
    if (profile.blockMode == RestrictionBlockMode.whitelist) {
      if (!profile.allowedApps.contains(name)) {
        return RestrictionViolation(
          process: process,
          action: action,
          reasonCode: 'nonWhitelist',
          reason: '非白名单进程',
          matched: name,
        );
      }
    } else if (profile.blockedApps.contains(name)) {
      return RestrictionViolation(
        process: process,
        action: action,
        reasonCode: 'appBlacklist',
        reason: '应用黑名单',
        matched: name,
      );
    }

    if (!profile.titleKeywordBlocking) return null;
    if (profile.titleKeywordProcesses.isNotEmpty &&
        !profile.titleKeywordProcesses.contains(name)) {
      return null;
    }
    for (final title in process.windowTitles) {
      final normalizedTitle = title.toLowerCase();
      for (final keyword in profile.blockedTitleKeywords) {
        if (normalizedTitle.contains(keyword)) {
          return RestrictionViolation(
            process: process,
            action: profile.titleKeywordAction,
            reasonCode: 'titleKeyword',
            reason: '窗口标题关键词',
            matched: keyword,
          );
        }
      }
    }
    return null;
  }

  bool weakens(RestrictionProfile current, RestrictionProfile candidate) {
    if (current.enabled && !candidate.enabled) return true;
    if (current.strongProtection && !candidate.strongProtection) return true;
    if (current.defaultAction == RestrictionAction.forceClose &&
        candidate.defaultAction == RestrictionAction.warn) {
      return true;
    }
    if (current.titleKeywordAction == RestrictionAction.forceClose &&
        candidate.titleKeywordAction == RestrictionAction.warn) {
      return true;
    }
    if (current.titleKeywordBlocking && !candidate.titleKeywordBlocking) {
      return true;
    }
    if (current.websiteBlocking && !candidate.websiteBlocking) return true;
    if (current.blockMode != candidate.blockMode) return true;
    if (current.blockMode == RestrictionBlockMode.blacklist &&
        !candidate.blockedApps.toSet().containsAll(current.blockedApps)) {
      return true;
    }
    if (current.blockMode == RestrictionBlockMode.whitelist &&
        !current.allowedApps.toSet().containsAll(candidate.allowedApps)) {
      return true;
    }
    if (!candidate.blockedWebsites.toSet().containsAll(
      current.blockedWebsites,
    )) {
      return true;
    }
    if (!candidate.blockedTitleKeywords.toSet().containsAll(
      current.blockedTitleKeywords,
    )) {
      return true;
    }
    return candidate.schedules.length < current.schedules.length;
  }

  bool _isSystemProcess(String name, String executablePath) {
    if (_systemProcessNames.contains(name)) return true;
    final path = executablePath.trim().toLowerCase().replaceAll('/', r'\');
    return path.startsWith(r'c:\windows\') || path.contains(r'\windows\');
  }

  String _processName(String value) {
    final normalized = value.trim().replaceAll('/', Platform.pathSeparator);
    return normalized.split(RegExp(r'[\\/]')).last.toLowerCase();
  }
}
