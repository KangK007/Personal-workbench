import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

class RestrictionEmergencyCode {
  const RestrictionEmergencyCode({
    required this.hash,
    required this.salt,
    required this.createdAt,
    required this.expiresAt,
    this.used = false,
  });

  factory RestrictionEmergencyCode.fromJson(Map<String, dynamic> json) {
    return RestrictionEmergencyCode(
      hash: json['hash']?.toString() ?? '',
      salt: json['salt']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      expiresAt:
          DateTime.tryParse(json['expiresAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      used: json['used'] == true,
    );
  }

  final String hash;
  final String salt;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool used;

  RestrictionEmergencyCode copyWith({bool? used}) => RestrictionEmergencyCode(
    hash: hash,
    salt: salt,
    createdAt: createdAt,
    expiresAt: expiresAt,
    used: used ?? this.used,
  );

  Map<String, dynamic> toJson() => {
    'hash': hash,
    'salt': salt,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'used': used,
  };
}

class RestrictionSecurityState {
  const RestrictionSecurityState({
    this.passwordHash = '',
    this.emergencyCodes = const [],
  });

  factory RestrictionSecurityState.decode(String? value) {
    if (value == null || value.isEmpty) return const RestrictionSecurityState();
    try {
      final json = jsonDecode(value) as Map<String, dynamic>;
      return RestrictionSecurityState(
        passwordHash: json['passwordHash']?.toString() ?? '',
        emergencyCodes: (json['emergencyCodes'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map(
              (item) => RestrictionEmergencyCode.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList(growable: false),
      );
    } catch (_) {
      return const RestrictionSecurityState();
    }
  }

  final String passwordHash;
  final List<RestrictionEmergencyCode> emergencyCodes;

  bool get hasPassword => passwordHash.isNotEmpty;

  int activeEmergencyCodeCount(DateTime now) => emergencyCodes
      .where((entry) => !entry.used && now.isBefore(entry.expiresAt))
      .length;

  RestrictionSecurityState copyWith({
    String? passwordHash,
    List<RestrictionEmergencyCode>? emergencyCodes,
  }) => RestrictionSecurityState(
    passwordHash: passwordHash ?? this.passwordHash,
    emergencyCodes: emergencyCodes ?? this.emergencyCodes,
  );

  String encode() => jsonEncode({
    'version': 1,
    'passwordHash': passwordHash,
    'emergencyCodes': emergencyCodes.map((entry) => entry.toJson()).toList(),
  });
}

class RestrictionCredentialResult {
  const RestrictionCredentialResult({
    required this.valid,
    required this.state,
    this.emergency = false,
  });

  final bool valid;
  final bool emergency;
  final RestrictionSecurityState state;
}

class RestrictionSecurityService {
  RestrictionSecurityService({Random? random})
    : _random = random ?? Random.secure();

  static const iterations = 260000;
  static const cooldown = Duration(minutes: 5);
  static const emergencyLifetime = Duration(minutes: 30);

  final Random _random;
  final Pbkdf2 _kdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations,
    bits: 256,
  );

  Future<RestrictionSecurityState> setPassword(
    RestrictionSecurityState state,
    String password,
  ) async {
    if (password.length < 8) {
      throw const FormatException('保护密码至少需要 8 个字符。');
    }
    final salt = _randomHex(16);
    final digest = await _passwordDigest(password, salt);
    return state.copyWith(
      passwordHash: 'pbkdf2_sha256\$$iterations\$$salt\$$digest',
    );
  }

  Future<bool> verifyPassword(
    RestrictionSecurityState state,
    String password,
  ) async {
    if (!state.hasPassword) return password.isEmpty;
    final parts = state.passwordHash.split(r'$');
    if (parts.length != 4 || parts[0] != 'pbkdf2_sha256') return false;
    final parsedIterations = int.tryParse(parts[1]);
    if (parsedIterations != iterations) return false;
    final digest = await _passwordDigest(password, parts[2]);
    return _constantTimeEquals(digest, parts[3]);
  }

  Future<({String code, RestrictionSecurityState state})> generateEmergencyCode(
    RestrictionSecurityState state,
    DateTime now,
  ) async {
    final code = List.generate(8, (_) => _random.nextInt(10)).join();
    final salt = _randomHex(8);
    final hash = await _tokenDigest(code, salt);
    final active = state.emergencyCodes
        .where((entry) => !entry.used && now.isBefore(entry.expiresAt))
        .toList();
    active.add(
      RestrictionEmergencyCode(
        hash: hash,
        salt: salt,
        createdAt: now,
        expiresAt: now.add(emergencyLifetime),
      ),
    );
    return (code: code, state: state.copyWith(emergencyCodes: active));
  }

  Future<RestrictionCredentialResult> verifyCredential(
    RestrictionSecurityState state,
    String credential,
    DateTime now,
  ) async {
    final normalizedCredential = credential.trim();
    final isEmergencyCode =
        (normalizedCredential.startsWith('*') &&
            normalizedCredential.length == 9) ||
        RegExp(r'^\d{8}$').hasMatch(normalizedCredential);
    if (isEmergencyCode) {
      final code = normalizedCredential.startsWith('*')
          ? normalizedCredential.substring(1)
          : normalizedCredential;
      final updated = <RestrictionEmergencyCode>[];
      var matched = false;
      for (final entry in state.emergencyCodes) {
        var current = entry;
        if (!current.used && !now.isBefore(current.expiresAt)) {
          current = current.copyWith(used: true);
        } else if (!matched && !current.used) {
          final digest = await _tokenDigest(code, current.salt);
          if (_constantTimeEquals(digest, current.hash)) {
            matched = true;
            current = current.copyWith(used: true);
          }
        }
        updated.add(current);
      }
      return RestrictionCredentialResult(
        valid: matched,
        emergency: matched,
        state: state.copyWith(emergencyCodes: updated),
      );
    }
    return RestrictionCredentialResult(
      valid: await verifyPassword(state, credential),
      state: state,
    );
  }

  Future<String> _passwordDigest(String password, String salt) async {
    final key = await _kdf.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: utf8.encode(salt),
    );
    return _hex(await key.extractBytes());
  }

  Future<String> _tokenDigest(String code, String salt) async {
    final digest = await Sha256().hash(utf8.encode('$code$salt'));
    return _hex(digest.bytes);
  }

  bool _constantTimeEquals(String left, String right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var index = 0; index < left.length; index++) {
      difference |= left.codeUnitAt(index) ^ right.codeUnitAt(index);
    }
    return difference == 0;
  }

  String _randomHex(int bytes) =>
      _hex(List<int>.generate(bytes, (_) => _random.nextInt(256)));

  String _hex(Iterable<int> bytes) =>
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}
