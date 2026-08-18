import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/models/attachment.dart';
import '../core/models/workspace_record.dart';

class BackupLimits {
  const BackupLimits({
    this.maxEncryptedFileBytes = 256 * 1024 * 1024,
    this.maxDecryptedBytes = 192 * 1024 * 1024,
    this.maxRecords = 50000,
    this.maxAttachments = 1000,
    this.maxSingleAttachmentBytes = 20 * 1024 * 1024,
    this.maxTotalAttachmentBytes = 128 * 1024 * 1024,
    this.maxJsonDepth = 48,
  });

  final int maxEncryptedFileBytes;
  final int maxDecryptedBytes;
  final int maxRecords;
  final int maxAttachments;
  final int maxSingleAttachmentBytes;
  final int maxTotalAttachmentBytes;
  final int maxJsonDepth;
}

class BackupAttachment {
  const BackupAttachment({required this.metadata, this.bytes});

  final Attachment metadata;
  final Uint8List? bytes;

  Map<String, dynamic> toJson() => {
    'metadata': metadata.toDatabase(),
    if (bytes != null) 'bytes': base64Encode(bytes!),
  };

  factory BackupAttachment.fromJson(Map<String, dynamic> json) {
    final metadata = Map<String, Object?>.from(json['metadata'] as Map);
    return BackupAttachment(
      metadata: Attachment.fromDatabase(metadata),
      bytes: json['bytes'] is String
          ? Uint8List.fromList(base64Decode(json['bytes'] as String))
          : null,
    );
  }
}

class BackupBundle {
  const BackupBundle({
    required this.manifest,
    required this.records,
    this.localGameState,
    this.attachments = const [],
  });

  final BackupManifest manifest;
  final List<WorkspaceRecord> records;
  final Map<String, dynamic>? localGameState;
  final List<BackupAttachment> attachments;
}

class BackupService {
  static const _format = 'personal-workbench-backup';
  static const _version = 3;
  static const _iterations = 120000;

  BackupService({this.limits = const BackupLimits()});

  final BackupLimits limits;
  final _cipher = AesGcm.with256bits();
  final _kdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: _iterations,
    bits: 256,
  );

  Future<Uint8List> createEncryptedBackup(
    String password,
    Iterable<WorkspaceRecord> records, {
    Map<String, dynamic>? localGameState,
    Iterable<BackupAttachment> attachments = const [],
  }) async {
    if (password.length < 8) {
      throw const FormatException('备份密码至少需要 8 个字符。');
    }

    final values = records.toList(growable: false);
    final attachmentValues = attachments.toList(growable: false);
    if (values.length > limits.maxRecords) {
      throw FormatException('备份记录不能超过 ${limits.maxRecords} 条。');
    }
    _validateAttachmentEntries(attachmentValues);
    final kinds = <String, int>{};
    for (final record in values) {
      kinds.update(record.kind.name, (count) => count + 1, ifAbsent: () => 1);
    }

    final manifest = BackupManifest(
      version: _version,
      createdAt: DateTime.now(),
      recordCount: values.length,
      kinds: kinds,
    );
    final clearText = utf8.encode(
      jsonEncode({
        'manifest': manifest.toJson(),
        'records': values.map((record) => record.toJson()).toList(),
        'localGameState': ?localGameState,
        'attachments': attachmentValues
            .map((attachment) => attachment.toJson())
            .toList(growable: false),
      }),
    );
    if (clearText.length > limits.maxDecryptedBytes) {
      throw const FormatException('备份解密后的数据量超过安全限制。');
    }

    final salt = _randomBytes(16);
    final secretKey = await _deriveKey(password, salt);
    final box = await _cipher.encrypt(clearText, secretKey: secretKey);
    final envelope = {
      'format': _format,
      'version': _version,
      'kdf': 'pbkdf2-hmac-sha256',
      'iterations': _iterations,
      'salt': base64Encode(salt),
      'nonce': base64Encode(box.nonce),
      'mac': base64Encode(box.mac.bytes),
      'cipherText': base64Encode(box.cipherText),
    };
    final encoded = Uint8List.fromList(utf8.encode(jsonEncode(envelope)));
    validateEncryptedSize(encoded.length);
    return encoded;
  }

  Future<BackupBundle> decryptBackup(List<int> bytes, String password) async {
    validateEncryptedSize(bytes.length);
    try {
      final envelope = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final version = (envelope['version'] as num?)?.toInt();
      if (envelope['format'] != _format ||
          version == null ||
          version < 1 ||
          version > _version) {
        throw const FormatException('不是受支持的个人工作台备份文件。');
      }

      final salt = base64Decode(envelope['salt'] as String);
      final cipherText = envelope['cipherText'];
      if (cipherText is! String ||
          cipherText.length > _maxBase64Length(limits.maxDecryptedBytes)) {
        throw const FormatException('备份解密后的数据量超过安全限制。');
      }
      final secretKey = await _deriveKey(password, salt);
      final box = SecretBox(
        base64Decode(cipherText),
        nonce: base64Decode(envelope['nonce'] as String),
        mac: Mac(base64Decode(envelope['mac'] as String)),
      );
      final clearText = await _cipher.decrypt(box, secretKey: secretKey);
      if (clearText.length > limits.maxDecryptedBytes) {
        throw const FormatException('备份解密后的数据量超过安全限制。');
      }
      _validateJsonNesting(clearText);
      final decoded = jsonDecode(utf8.decode(clearText));
      if (decoded is! Map) {
        throw const FormatException('备份内容结构无效。');
      }
      final payload = Map<String, dynamic>.from(decoded);
      final rawRecords = payload['records'];
      if (rawRecords is! List) {
        throw const FormatException('备份记录列表无效。');
      }
      if (rawRecords.length > limits.maxRecords) {
        throw FormatException('备份记录不能超过 ${limits.maxRecords} 条。');
      }
      final records = rawRecords
          .map(
            (value) => WorkspaceRecord.fromJson(
              Map<String, dynamic>.from(value as Map),
            ),
          )
          .toList(growable: false);
      final manifest = BackupManifest.fromJson(
        Map<String, dynamic>.from(payload['manifest'] as Map),
      );
      if (manifest.recordCount != records.length) {
        throw const FormatException('备份清单与实际记录数量不一致。');
      }
      final localGameState = payload['localGameState'] is Map
          ? Map<String, dynamic>.from(payload['localGameState'] as Map)
          : null;
      final rawAttachments = payload['attachments'];
      if (rawAttachments != null && rawAttachments is! List) {
        throw const FormatException('备份附件列表无效。');
      }
      final attachmentValues = rawAttachments is List
          ? rawAttachments
          : const <dynamic>[];
      _validateAttachmentPayloads(attachmentValues);
      final attachments = attachmentValues
          .map(
            (value) => BackupAttachment.fromJson(
              Map<String, dynamic>.from(value as Map),
            ),
          )
          .toList(growable: false);
      var restoredAttachmentBytes = 0;
      for (final attachment in attachments) {
        final attachmentBytes = attachment.bytes;
        if (attachmentBytes != null &&
            attachmentBytes.length != attachment.metadata.sizeBytes) {
          throw FormatException('备份附件大小不一致：${attachment.metadata.fileName}');
        }
        restoredAttachmentBytes += attachmentBytes?.length ?? 0;
        if (restoredAttachmentBytes > limits.maxTotalAttachmentBytes) {
          throw FormatException(
            '备份附件总量不能超过 '
            '${limits.maxTotalAttachmentBytes ~/ (1024 * 1024)} MiB。',
          );
        }
      }
      return BackupBundle(
        manifest: manifest,
        records: records,
        localGameState: localGameState,
        attachments: attachments,
      );
    } on SecretBoxAuthenticationError {
      throw const FormatException('密码错误，或备份文件已经损坏。');
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('无法读取备份文件，请检查文件和密码。');
    }
  }

  void validateEncryptedSize(int byteLength) {
    if (byteLength > limits.maxEncryptedFileBytes) {
      throw FormatException(
        '备份文件不能超过 ${limits.maxEncryptedFileBytes ~/ (1024 * 1024)} MiB。',
      );
    }
  }

  void _validateAttachmentPayloads(List<dynamic> values) {
    if (values.length > limits.maxAttachments) {
      throw FormatException('备份附件不能超过 ${limits.maxAttachments} 个。');
    }
    var totalBytes = 0;
    for (final value in values) {
      if (value is! Map || value['metadata'] is! Map) {
        throw const FormatException('备份附件结构无效。');
      }
      final metadata = value['metadata'] as Map;
      final size = (metadata['size_bytes'] as num?)?.toInt();
      if (size == null || size < 0 || size > limits.maxSingleAttachmentBytes) {
        throw FormatException(
          '单个备份附件不能超过 '
          '${limits.maxSingleAttachmentBytes ~/ (1024 * 1024)} MiB。',
        );
      }
      totalBytes += size;
      if (totalBytes > limits.maxTotalAttachmentBytes) {
        throw FormatException(
          '备份附件总量不能超过 '
          '${limits.maxTotalAttachmentBytes ~/ (1024 * 1024)} MiB。',
        );
      }
      final encoded = value['bytes'];
      if (encoded != null && encoded is! String) {
        throw const FormatException('备份附件内容无效。');
      }
      if (encoded is String &&
          encoded.length > _maxBase64Length(limits.maxSingleAttachmentBytes)) {
        throw const FormatException('备份附件内容超过安全限制。');
      }
    }
  }

  void _validateAttachmentEntries(List<BackupAttachment> values) {
    if (values.length > limits.maxAttachments) {
      throw FormatException('备份附件不能超过 ${limits.maxAttachments} 个。');
    }
    var totalBytes = 0;
    for (final attachment in values) {
      final size = attachment.metadata.sizeBytes;
      final bytes = attachment.bytes;
      if (size < 0 || size > limits.maxSingleAttachmentBytes) {
        throw FormatException(
          '单个备份附件不能超过 '
          '${limits.maxSingleAttachmentBytes ~/ (1024 * 1024)} MiB。',
        );
      }
      if (bytes != null && bytes.length != size) {
        throw FormatException('备份附件大小不一致：${attachment.metadata.fileName}');
      }
      totalBytes += size;
      if (totalBytes > limits.maxTotalAttachmentBytes) {
        throw FormatException(
          '备份附件总量不能超过 '
          '${limits.maxTotalAttachmentBytes ~/ (1024 * 1024)} MiB。',
        );
      }
    }
  }

  void _validateJsonNesting(List<int> bytes) {
    var depth = 0;
    var inString = false;
    var escaped = false;
    for (final byte in bytes) {
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (byte == 0x5c) {
          escaped = true;
        } else if (byte == 0x22) {
          inString = false;
        }
        continue;
      }
      if (byte == 0x22) {
        inString = true;
      } else if (byte == 0x7b || byte == 0x5b) {
        depth++;
        if (depth > limits.maxJsonDepth) {
          throw FormatException('备份 JSON 嵌套不能超过 ${limits.maxJsonDepth} 层。');
        }
      } else if (byte == 0x7d || byte == 0x5d) {
        depth--;
      }
    }
  }

  int _maxBase64Length(int decodedBytes) => ((decodedBytes + 2) ~/ 3) * 4;

  Future<File> writeDefaultBackup(Uint8List bytes) async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(root.path, 'PersonalWorkbench'));
    await directory.create(recursive: true);
    final now = DateTime.now();
    final stamp =
        '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}-'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';
    final file = File(p.join(directory.path, 'workbench-backup-$stamp.pwb'));
    return file.writeAsBytes(bytes, flush: true);
  }

  Future<File> writeJsonExport(Iterable<WorkspaceRecord> records) async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(root.path, 'PersonalWorkbench'));
    await directory.create(recursive: true);
    final file = File(
      p.join(
        directory.path,
        'workbench-export-${DateTime.now().millisecondsSinceEpoch}.json',
      ),
    );
    final encoder = const JsonEncoder.withIndent('  ');
    return file.writeAsString(
      encoder.convert(records.map((record) => record.toJson()).toList()),
      flush: true,
    );
  }

  Future<File> writeJsonExportWithLocalGameState(
    Iterable<WorkspaceRecord> records,
    Map<String, dynamic> localGameState,
  ) async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(root.path, 'PersonalWorkbench'));
    await directory.create(recursive: true);
    final file = File(
      p.join(
        directory.path,
        'workbench-export-with-game-${DateTime.now().millisecondsSinceEpoch}.json',
      ),
    );
    final encoder = const JsonEncoder.withIndent('  ');
    return file.writeAsString(
      encoder.convert({
        'records': records.map((record) => record.toJson()).toList(),
        'localGameState': localGameState,
      }),
      flush: true,
    );
  }

  Future<SecretKey> _deriveKey(String password, List<int> salt) {
    return _kdf.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
  }

  List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }
}
