import '../core/models/restriction_models.dart';

/// Sanitized rules extracted from the original SelfControl configuration.
/// Runtime state, credentials, paths and event history are intentionally omitted.
abstract final class RestrictionDefaults {
  static const sourceId = 'selfcontrol-default-v1';

  static RestrictionProfile create({String? id}) {
    return RestrictionProfile(
      id: id ?? 'restriction-profile-default',
      title: '自律规则',
      enabled: false,
      schedules: [
        RestrictionScheduleRule(
          id: 'selfcontrol-weekdays',
          label: '工作日',
          days: [
            DateTime.monday,
            DateTime.tuesday,
            DateTime.wednesday,
            DateTime.thursday,
            DateTime.friday,
          ],
          startMinutes: 9 * 60,
          endMinutes: 18 * 60,
        ),
        RestrictionScheduleRule(
          id: 'selfcontrol-weekend',
          label: '周末',
          days: [DateTime.saturday, DateTime.sunday],
          startMinutes: 9 * 60,
          endMinutes: 22 * 60,
        ),
      ],
      blockMode: RestrictionBlockMode.blacklist,
      defaultAction: RestrictionAction.forceClose,
      blockedApps: _blockedApps,
      allowedApps: const [],
      titleKeywordBlocking: true,
      titleKeywordAction: RestrictionAction.warn,
      titleKeywordProcesses: _titleKeywordProcesses,
      blockedTitleKeywords: _blockedTitleKeywords,
      websiteBlocking: false,
      blockedWebsites: _blockedWebsites,
      pollIntervalSeconds: 3,
      allowBreak: true,
      breakMinutes: 15,
      maxBreaksPerDay: 3,
      strongProtection: false,
      sourceImportId: sourceId,
    );
  }

  /// Merges only missing list entries and preserves user-owned settings.
  static RestrictionProfile mergeMissing(RestrictionProfile existing) {
    final defaults = create(id: existing.id);
    return existing.copyWith(
      blockedApps: _merge(existing.blockedApps, defaults.blockedApps),
      allowedApps: _merge(existing.allowedApps, defaults.allowedApps),
      titleKeywordProcesses: _merge(
        existing.titleKeywordProcesses,
        defaults.titleKeywordProcesses,
      ),
      blockedTitleKeywords: _merge(
        existing.blockedTitleKeywords,
        defaults.blockedTitleKeywords,
      ),
      blockedWebsites: _merge(
        existing.blockedWebsites,
        defaults.blockedWebsites,
      ),
      sourceImportId: existing.sourceImportId ?? sourceId,
    );
  }

  static List<String> _merge(
    Iterable<String> current,
    Iterable<String> defaults,
  ) {
    final result = <String>[];
    final seen = <String>{};
    for (final value in [...current, ...defaults]) {
      final normalized = value.trim().toLowerCase();
      if (normalized.isNotEmpty && seen.add(normalized)) result.add(normalized);
    }
    return result;
  }

  static const _titleKeywordProcesses = [
    'chrome.exe',
    'msedge.exe',
    'firefox.exe',
    'brave.exe',
    'opera.exe',
    'vivaldi.exe',
    'qqbrowser.exe',
    '360se.exe',
    'iexplore.exe',
  ];

  static const _blockedTitleKeywords = [
    'bilibili',
    '哔哩哔哩',
    'youtube',
    'twitch',
    'douyin',
    '抖音',
    'kuaishou',
    '快手',
    'weibo',
    '微博',
    'reddit',
    'twitter',
    'x.com',
    'netflix',
    '爱奇艺',
    'iqiyi',
    '优酷',
    'youku',
    '斗鱼',
    'douyu',
    '虎牙',
    'huya',
    'nga',
    '贴吧',
  ];

  static const _blockedWebsites = [
    'bilibili.com',
    'www.bilibili.com',
    'douyu.com',
    'www.douyu.com',
    'huya.com',
    'www.huya.com',
    'douyin.com',
    'www.douyin.com',
    'kuaishou.com',
    'www.kuaishou.com',
    'weibo.com',
    'www.weibo.com',
    'zhihu.com',
    'www.zhihu.com',
    'tieba.baidu.com',
    'bbs.nga.cn',
    'nga.cn',
    'reddit.com',
    'www.reddit.com',
    'twitter.com',
    'x.com',
    'youtube.com',
    'www.youtube.com',
    'twitch.tv',
    'www.twitch.tv',
    'netflix.com',
    'www.netflix.com',
    'iqiyi.com',
    'www.iqiyi.com',
    'youku.com',
    'www.youku.com',
    'qq.com',
    'www.qq.com',
  ];

  static const _blockedApps = [
    'among us.exe',
    'apex.exe',
    'battle.net.exe',
    'battlefield.exe',
    'blackdesert.exe',
    'blizzardbrowser.exe',
    'bluestacks.exe',
    'cs2.exe',
    'csgo.exe',
    'darksouls.exe',
    'diablo iii.exe',
    'diablo iv.exe',
    'dota.exe',
    'dota2.exe',
    'douyin.exe',
    'eadesktop.exe',
    'elden ring.exe',
    'epicgameslauncher.exe',
    'fallguys.exe',
    'fifa.exe',
    'fifa23.exe',
    'fortnite.exe',
    'fortniteclient-win64-shipping.exe',
    'fortnitelauncher.exe',
    'galaxyclient.exe',
    'galaxyclientservice.exe',
    'genshinimpact.exe',
    'goggalaxy.exe',
    'hearthstone.exe',
    'heroes of the storm.exe',
    'honkai.exe',
    'kuaishou.exe',
    'ldplayer.exe',
    'leagueclient.exe',
    'leagueclientux.exe',
    'leidian.exe',
    'lostark.exe',
    'madden.exe',
    'minecraft.exe',
    'minecraftlauncher.exe',
    'mumu.exe',
    'mumuplayer.exe',
    'nba2k.exe',
    'need for speed.exe',
    'new world.exe',
    'nox.exe',
    'origin.exe',
    'overwatch.exe',
    'pathofexile.exe',
    'poe.exe',
    'pubg.exe',
    'r5apex.exe',
    'riotclient.exe',
    'riotclientservices.exe',
    'rocketleague.exe',
    'sekiro.exe',
    'starcraft ii.exe',
    'stardew valley.exe',
    'starrail.exe',
    'steam.exe',
    'steamwebhelper.exe',
    'terraria.exe',
    'tgp_daemon.exe',
    'tslgame.exe',
    'ubisoftconnect.exe',
    'valorant-win64-shipping.exe',
    'valorant.exe',
    'warframe.exe',
    'warframe.x64.exe',
    'wegame.exe',
    'wow.exe',
    'wowclassic.exe',
    'yuanshen.exe',
    'zzz.exe',
  ];
}
