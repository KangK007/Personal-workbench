import 'package:flutter_test/flutter_test.dart';
import 'package:personal_workbench/core/models/restriction_models.dart';
import 'package:personal_workbench/services/restriction_defaults.dart';

void main() {
  test('defaults mirror the sanitized SelfControl rule baseline', () {
    final profile = RestrictionDefaults.create();

    expect(profile.enabled, isFalse);
    expect(profile.sourceImportId, RestrictionDefaults.sourceId);
    expect(profile.schedules, hasLength(2));
    expect(profile.schedules.first.startMinutes, 540);
    expect(profile.schedules.first.endMinutes, 1080);
    expect(profile.schedules.last.startMinutes, 540);
    expect(profile.schedules.last.endMinutes, 1320);
    expect(profile.defaultAction, RestrictionAction.forceClose);
    expect(profile.titleKeywordAction, RestrictionAction.warn);
    expect(profile.blockedApps, hasLength(74));
    expect(profile.titleKeywordProcesses, hasLength(9));
    expect(profile.blockedTitleKeywords, hasLength(24));
    expect(profile.blockedWebsites, hasLength(33));
    expect(profile.websiteBlocking, isFalse);
    expect(profile.allowBreak, isTrue);
    expect(profile.breakMinutes, 15);
    expect(profile.maxBreaksPerDay, 3);
  });

  test('mergeMissing preserves user settings and is idempotent', () {
    final existing = RestrictionDefaults.create(id: 'existing').copyWith(
      enabled: true,
      schedules: const [],
      websiteBlocking: true,
      blockedApps: const ['custom.exe'],
    );
    final merged = RestrictionDefaults.mergeMissing(existing);
    final repeated = RestrictionDefaults.mergeMissing(merged);

    expect(merged.enabled, isTrue);
    expect(merged.schedules, isEmpty);
    expect(merged.websiteBlocking, isTrue);
    expect(merged.blockedApps.first, 'custom.exe');
    expect(merged.blockedApps.toSet().length, merged.blockedApps.length);
    expect(repeated.toData(), merged.toData());
  });
}
