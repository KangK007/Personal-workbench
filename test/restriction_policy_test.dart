import 'package:flutter_test/flutter_test.dart';
import 'package:personal_workbench/core/models/restriction_models.dart';
import 'package:personal_workbench/services/restriction_policy_engine.dart';

RestrictionProfile _profile({
  RestrictionBlockMode mode = RestrictionBlockMode.blacklist,
  RestrictionAction action = RestrictionAction.forceClose,
  List<String> blockedApps = const ['steam.exe'],
  List<String> allowedApps = const ['code.exe'],
}) => RestrictionProfile(
  id: 'profile',
  title: 'Test',
  enabled: true,
  schedules: const [
    RestrictionScheduleRule(
      id: 'night',
      label: 'Night',
      days: [DateTime.monday],
      startMinutes: 22 * 60,
      endMinutes: 6 * 60,
    ),
  ],
  blockMode: mode,
  defaultAction: action,
  blockedApps: blockedApps,
  allowedApps: allowedApps,
  titleKeywordProcesses: const ['chrome.exe'],
  blockedTitleKeywords: const ['video'],
);

void main() {
  const engine = RestrictionPolicyEngine();

  test('cross-midnight rule remains active on the following day', () {
    final profile = _profile();
    expect(engine.isRestricted(profile, DateTime(2026, 8, 17, 23)), isTrue);
    expect(engine.isRestricted(profile, DateTime(2026, 8, 18, 5, 59)), isTrue);
    expect(engine.isRestricted(profile, DateTime(2026, 8, 18, 6)), isFalse);
    expect(engine.isRestricted(profile, DateTime(2026, 8, 19, 1)), isFalse);
  });

  test('next transition reports active rule end and future start', () {
    final profile = _profile();
    final ending = engine.nextTransition(profile, DateTime(2026, 8, 18, 1));
    expect(ending.kind, 'end');
    expect(ending.at, DateTime(2026, 8, 18, 6));

    final starting = engine.nextTransition(profile, DateTime(2026, 8, 17, 12));
    expect(starting.kind, 'start');
    expect(starting.at, DateTime(2026, 8, 17, 22));
  });

  test('blacklist and whitelist evaluations preserve action semantics', () {
    final blocked = engine.evaluateProcess(
      _profile(),
      const RestrictionProcessSnapshot(pid: 10, name: 'Steam.EXE'),
    );
    expect(blocked?.reasonCode, 'appBlacklist');
    expect(blocked?.action, RestrictionAction.forceClose);

    final nonAllowed = engine.evaluateProcess(
      _profile(mode: RestrictionBlockMode.whitelist),
      const RestrictionProcessSnapshot(pid: 11, name: 'music.exe'),
    );
    expect(nonAllowed?.reasonCode, 'nonWhitelist');
  });

  test(
    'title keyword detection only warns and system processes are exempt',
    () {
      final title = engine.evaluateProcess(
        _profile(),
        const RestrictionProcessSnapshot(
          pid: 20,
          name: 'chrome.exe',
          windowTitles: ['Video site'],
        ),
      );
      expect(title?.reasonCode, 'titleKeyword');
      expect(title?.action, RestrictionAction.warn);

      final system = engine.evaluateProcess(
        _profile(mode: RestrictionBlockMode.whitelist),
        const RestrictionProcessSnapshot(
          pid: 4,
          name: 'svchost.exe',
          executablePath: r'C:\Windows\System32\svchost.exe',
        ),
      );
      expect(system, isNull);
    },
  );

  test('weakening a protected profile is detected', () {
    final current = _profile().copyWith(
      strongProtection: true,
      websiteBlocking: true,
      blockedWebsites: const ['example.com'],
    );
    expect(engine.weakens(current, current.copyWith(enabled: false)), isTrue);
    expect(
      engine.weakens(
        current,
        current.copyWith(blockedApps: const ['steam.exe', 'game.exe']),
      ),
      isFalse,
    );
  });

  test('title and per-app action overrides are preserved', () {
    final profile = _profile().copyWith(
      titleKeywordAction: RestrictionAction.forceClose,
      appActions: const {'steam.exe': RestrictionAction.warn},
    );
    final title = engine.evaluateProcess(
      profile,
      const RestrictionProcessSnapshot(
        pid: 21,
        name: 'chrome.exe',
        windowTitles: ['Video site'],
      ),
    );
    final app = engine.evaluateProcess(
      profile,
      const RestrictionProcessSnapshot(pid: 22, name: 'steam.exe'),
    );
    expect(title?.action, RestrictionAction.forceClose);
    expect(app?.action, RestrictionAction.warn);
  });
}
