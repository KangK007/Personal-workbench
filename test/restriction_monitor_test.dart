import 'package:flutter_test/flutter_test.dart';
import 'package:personal_workbench/core/models/restriction_models.dart';
import 'package:personal_workbench/services/restriction_monitor.dart';
import 'package:personal_workbench/services/windows_activity_service.dart';

class _FakeActivity extends WindowsActivityService {
  bool guard = false;
  int applyCount = 0;
  int clearCount = 0;
  List<String> domains = [];

  @override
  bool get supported => true;

  @override
  Future<bool> bridgeAvailable() async => true;

  @override
  Future<List<RestrictionProcessSnapshot>> processSnapshot() async => const [];

  @override
  Future<bool> applyHostsPolicy(Iterable<String> values) async {
    applyCount++;
    domains = values.toList();
    return true;
  }

  @override
  Future<bool> clearHostsPolicy() async {
    clearCount++;
    domains = [];
    return true;
  }

  @override
  Future<void> setExitGuard(bool enabled) async => guard = enabled;
}

RestrictionProfile _profile({
  bool strong = true,
  bool enabled = true,
  List<String> websites = const ['example.com'],
}) => RestrictionProfile(
  id: 'profile',
  title: '限制',
  enabled: enabled,
  strongProtection: strong,
  websiteBlocking: true,
  blockedWebsites: websites,
  schedules: const [
    RestrictionScheduleRule(
      id: 'rule',
      label: '全天',
      days: [DateTime.wednesday],
      startMinutes: 0,
      endMinutes: 1439,
    ),
  ],
);

void main() {
  test('strong protection keeps the active snapshot across remote weakening', () async {
    final activity = _FakeActivity();
    var profile = _profile();
    final monitor = RestrictionMonitor(
      activityService: activity,
      profileProvider: () => profile,
      onEvent: (_, _) async {},
      onStateChanged: (_) async {},
      now: () => DateTime(2026, 8, 19, 10),
    );
    addTearDown(monitor.dispose);

    await monitor.start();
    expect(monitor.state.activeSnapshot?.strongProtection, isTrue);
    profile = _profile(strong: false, enabled: false, websites: const []);
    await monitor.poll();

    expect(monitor.state.active, isTrue);
    expect(monitor.state.activeSnapshot?.enabled, isTrue);
    expect(activity.domains, ['example.com']);
  });

  test('website changes refresh hosts while a normal profile is active', () async {
    final activity = _FakeActivity();
    var profile = _profile(strong: false);
    final monitor = RestrictionMonitor(
      activityService: activity,
      profileProvider: () => profile,
      onEvent: (_, _) async {},
      onStateChanged: (_) async {},
      now: () => DateTime(2026, 8, 19, 10),
    );
    addTearDown(monitor.dispose);

    await monitor.start();
    profile = _profile(strong: false, websites: const ['updated.example']);
    await monitor.poll();

    expect(activity.applyCount, 2);
    expect(activity.domains, ['updated.example']);
  });
}
