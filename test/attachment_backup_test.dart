import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_workbench/core/models/attachment.dart';
import 'package:personal_workbench/core/models/workspace_record.dart';
import 'package:personal_workbench/data/app_database.dart';
import 'package:personal_workbench/data/backup_service.dart';
import 'package:personal_workbench/services/attachment_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('encrypted backup includes attachment metadata and bytes', () async {
    final service = BackupService();
    final attachment = Attachment(
      id: 'attachment-1',
      ownerRecordId: 'note-1',
      ownerKind: RecordKind.note,
      fileName: 'figure.png',
      relativePath: 'attachments/attachment-1.png',
      mimeType: 'image/png',
      sizeBytes: 3,
      sha256: 'envelope-test',
      createdAt: DateTime(2026, 8, 13),
    );

    final encrypted = await service.createEncryptedBackup(
      'correct-password',
      [WorkspaceRecord.create(kind: RecordKind.note, title: 'Note')],
      attachments: [
        BackupAttachment(
          metadata: attachment,
          bytes: Uint8List.fromList(const [1, 2, 3]),
        ),
      ],
    );
    final bundle = await service.decryptBackup(encrypted, 'correct-password');

    expect(bundle.attachments.single.metadata.fileName, 'figure.png');
    expect(bundle.attachments.single.bytes, const [1, 2, 3]);
  });

  test('attachment restore verifies bytes and rebuilds metadata', () async {
    final sourceRoot = await Directory.systemTemp.createTemp(
      'workbench-attachment-source-',
    );
    final targetRoot = await Directory.systemTemp.createTemp(
      'workbench-attachment-target-',
    );
    addTearDown(() => sourceRoot.delete(recursive: true));
    addTearDown(() => targetRoot.delete(recursive: true));
    final sourceDatabase = AppDatabase(
      factory: databaseFactoryFfi,
      overridePath: '${sourceRoot.path}${Platform.pathSeparator}source.sqlite',
    );
    final targetDatabase = AppDatabase(
      factory: databaseFactoryFfi,
      overridePath: '${targetRoot.path}${Platform.pathSeparator}target.sqlite',
    );
    addTearDown(sourceDatabase.close);
    addTearDown(targetDatabase.close);
    final sourceService = AttachmentService(
      database: sourceDatabase,
      root: sourceRoot,
    );
    final targetService = AttachmentService(
      database: targetDatabase,
      root: targetRoot,
    );
    final source = File(
      '${sourceRoot.path}${Platform.pathSeparator}source.png',
    );
    const bytes = [0x89, 0x50, 0x4e, 0x47, 4, 5, 6];
    await source.writeAsBytes(bytes);
    final owner = WorkspaceRecord.create(kind: RecordKind.note, title: 'note');
    final original = await sourceService.importImage(
      owner: owner,
      source: source,
    );

    final entries = await sourceService.createBackupEntries();
    await targetService.restoreBackupEntries(entries);

    final restored = (await targetService.forRecord(owner.id)).single;
    expect(restored.sha256, original.sha256);
    expect(await (await targetService.resolve(restored))!.readAsBytes(), bytes);
  });

  test('empty attachment restore clears old metadata and files', () async {
    final root = await Directory.systemTemp.createTemp(
      'workbench-empty-attachment-restore-',
    );
    addTearDown(() => root.delete(recursive: true));
    final database = AppDatabase(
      factory: databaseFactoryFfi,
      overridePath: '${root.path}${Platform.pathSeparator}target.sqlite',
    );
    addTearDown(database.close);
    final service = AttachmentService(database: database, root: root);
    final source = File('${root.path}${Platform.pathSeparator}old.png');
    await source.writeAsBytes(const [0x89, 0x50, 0x4e, 0x47, 1]);
    final owner = WorkspaceRecord.create(kind: RecordKind.note, title: '旧笔记');
    final oldAttachment = await service.importImage(
      owner: owner,
      source: source,
    );

    await service.restoreBackupEntries(const []);

    expect(await database.loadAttachments(), isEmpty);
    expect(await service.resolve(oldAttachment), isNull);
  });

  test('attachment files roll back when database replacement fails', () async {
    final sourceRoot = await Directory.systemTemp.createTemp(
      'workbench-rollback-source-',
    );
    final targetRoot = await Directory.systemTemp.createTemp(
      'workbench-rollback-target-',
    );
    addTearDown(() => sourceRoot.delete(recursive: true));
    addTearDown(() => targetRoot.delete(recursive: true));
    final sourceDatabase = AppDatabase(
      factory: databaseFactoryFfi,
      overridePath: '${sourceRoot.path}${Platform.pathSeparator}source.sqlite',
    );
    final targetDatabase = AppDatabase(
      factory: databaseFactoryFfi,
      overridePath: '${targetRoot.path}${Platform.pathSeparator}target.sqlite',
    );
    addTearDown(sourceDatabase.close);
    addTearDown(targetDatabase.close);
    final sourceService = AttachmentService(
      database: sourceDatabase,
      root: sourceRoot,
    );
    final targetService = AttachmentService(
      database: targetDatabase,
      root: targetRoot,
    );
    final oldSource = File(
      '${targetRoot.path}${Platform.pathSeparator}old.png',
    );
    const oldBytes = [0x89, 0x50, 0x4e, 0x47, 1];
    await oldSource.writeAsBytes(oldBytes);
    final oldOwner = WorkspaceRecord.create(
      kind: RecordKind.note,
      title: '旧笔记',
    );
    final oldAttachment = await targetService.importImage(
      owner: oldOwner,
      source: oldSource,
    );
    final newSource = File(
      '${sourceRoot.path}${Platform.pathSeparator}new.png',
    );
    await newSource.writeAsBytes(const [0x89, 0x50, 0x4e, 0x47, 2]);
    final newOwner = WorkspaceRecord.create(
      kind: RecordKind.note,
      title: '新笔记',
    );
    await sourceService.importImage(owner: newOwner, source: newSource);
    final entries = await sourceService.createBackupEntries();

    await expectLater(
      targetService.restoreBackupEntries(
        entries,
        commitDatabase: (_) async => throw StateError('database failed'),
      ),
      throwsStateError,
    );

    expect(
      (await targetDatabase.loadAttachments()).single.id,
      oldAttachment.id,
    );
    expect(
      await (await targetService.resolve(oldAttachment))!.readAsBytes(),
      oldBytes,
    );
  });
}
