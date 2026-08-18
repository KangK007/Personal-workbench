import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_workbench/core/models/attachment.dart';
import 'package:personal_workbench/core/models/game_state.dart';
import 'package:personal_workbench/core/models/workspace_record.dart';
import 'package:personal_workbench/data/backup_service.dart';

void main() {
  test('encrypted backup restores with the correct password', () async {
    final service = BackupService();
    final records = [
      WorkspaceRecord.create(
        kind: RecordKind.diary,
        title: '实验日记',
        body: '保留原始记录',
      ),
    ];

    final encrypted = await service.createEncryptedBackup(
      'correct-password',
      records,
    );
    final bundle = await service.decryptBackup(encrypted, 'correct-password');

    expect(bundle.manifest.recordCount, 1);
    expect(bundle.records.single.title, '实验日记');
  });

  test('encrypted backup rejects a wrong password', () async {
    final service = BackupService();
    final encrypted = await service.createEncryptedBackup('correct-password', [
      WorkspaceRecord.create(kind: RecordKind.note, title: '私密笔记'),
    ]);

    expect(
      service.decryptBackup(encrypted, 'wrong-password'),
      throwsA(isA<FormatException>()),
    );
  });

  test('legacy version one envelope remains readable', () async {
    final service = BackupService();
    final encrypted = await service.createEncryptedBackup('correct-password', [
      WorkspaceRecord.create(kind: RecordKind.task, title: '旧版兼容'),
    ]);
    final envelope = jsonDecode(utf8.decode(encrypted)) as Map<String, dynamic>;
    envelope['version'] = 1;

    final bundle = await service.decryptBackup(
      utf8.encode(jsonEncode(envelope)),
      'correct-password',
    );
    expect(bundle.records.single.title, '旧版兼容');
  });

  test('encrypted backup includes local game state', () async {
    final service = BackupService();
    final state = LocalGameState(
      profile: const GameProfile(points: 30),
      removedFeatureData: const {
        'pet': {'name': '墨玉'},
      },
    );
    final encrypted = await service.createEncryptedBackup(
      'correct-password',
      [WorkspaceRecord.create(kind: RecordKind.task, title: '任务')],
      localGameState: Map<String, dynamic>.from(
        jsonDecode(state.encode()) as Map,
      ),
    );

    final bundle = await service.decryptBackup(encrypted, 'correct-password');

    expect(bundle.localGameState?['profile']['points'], 30);
    // Removed pet data remains round-trippable for non-destructive migration.
    expect(bundle.localGameState?['pet']['name'], '墨玉');
  });

  test('oversized encrypted backups are rejected before parsing', () async {
    final service = BackupService(
      limits: const BackupLimits(maxEncryptedFileBytes: 4),
    );

    await expectLater(
      service.decryptBackup(const [1, 2, 3, 4, 5], 'correct-password'),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('备份文件不能超过'),
        ),
      ),
    );
  });

  test('backup record count is limited after decryption', () async {
    final encrypted = await BackupService().createEncryptedBackup(
      'correct-password',
      [WorkspaceRecord.create(kind: RecordKind.task, title: '超限记录')],
    );
    final constrained = BackupService(
      limits: const BackupLimits(maxRecords: 0),
    );

    await expectLater(
      constrained.decryptBackup(encrypted, 'correct-password'),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('备份记录不能超过'),
        ),
      ),
    );
  });

  test('backup attachment total is limited after decryption', () async {
    final attachment = Attachment(
      id: 'attachment-limit',
      ownerRecordId: 'note-limit',
      ownerKind: RecordKind.note,
      fileName: 'limit.png',
      relativePath: 'attachments/attachment-limit.png',
      mimeType: 'image/png',
      sizeBytes: 3,
      sha256: 'limit',
      createdAt: DateTime(2026, 8, 15),
    );
    final encrypted = await BackupService().createEncryptedBackup(
      'correct-password',
      [WorkspaceRecord.create(kind: RecordKind.note, title: '附件限制')],
      attachments: [
        BackupAttachment(
          metadata: attachment,
          bytes: Uint8List.fromList(const [1, 2, 3]),
        ),
      ],
    );
    final constrained = BackupService(
      limits: const BackupLimits(maxTotalAttachmentBytes: 2),
    );

    await expectLater(
      constrained.decryptBackup(encrypted, 'correct-password'),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('备份附件总量不能超过'),
        ),
      ),
    );
  });

  test('backup JSON depth is limited after decryption', () async {
    final encrypted = await BackupService().createEncryptedBackup(
      'correct-password',
      [WorkspaceRecord.create(kind: RecordKind.task, title: '嵌套限制')],
    );
    final constrained = BackupService(
      limits: const BackupLimits(maxJsonDepth: 1),
    );

    await expectLater(
      constrained.decryptBackup(encrypted, 'correct-password'),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('备份 JSON 嵌套不能超过'),
        ),
      ),
    );
  });
}
