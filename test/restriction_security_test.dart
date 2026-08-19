import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_workbench/services/restriction_security_service.dart';

void main() {
  test('password hashing verifies without storing clear text', () async {
    final service = RestrictionSecurityService(random: Random(7));
    final state = await service.setPassword(
      const RestrictionSecurityState(),
      'Research-2026',
    );
    expect(state.passwordHash, isNot(contains('Research-2026')));
    expect(await service.verifyPassword(state, 'Research-2026'), isTrue);
    expect(await service.verifyPassword(state, 'wrong-value'), isFalse);
    expect(
      RestrictionSecurityState.decode(state.encode()).passwordHash,
      state.passwordHash,
    );
  });

  test('emergency code is one-time and expires', () async {
    final service = RestrictionSecurityService(random: Random(11));
    final now = DateTime(2026, 8, 19, 10);
    final generated = await service.generateEmergencyCode(
      const RestrictionSecurityState(),
      now,
    );
    expect(generated.code, hasLength(8));

    final first = await service.verifyCredential(
      generated.state,
      '*${generated.code}',
      now,
    );
    expect(first.valid, isTrue);
    expect(first.emergency, isTrue);

    final second = await service.verifyCredential(
      first.state,
      '*${generated.code}',
      now,
    );
    expect(second.valid, isFalse);

    final expired = await service.generateEmergencyCode(
      const RestrictionSecurityState(),
      now,
    );
    final expiredResult = await service.verifyCredential(
      expired.state,
      '*${expired.code}',
      now.add(const Duration(minutes: 31)),
    );
    expect(expiredResult.valid, isFalse);
  });

  test('short protection password is rejected', () async {
    final service = RestrictionSecurityService(random: Random(1));
    expect(
      () => service.setPassword(const RestrictionSecurityState(), 'short'),
      throwsA(isA<FormatException>()),
    );
  });
}
