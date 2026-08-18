import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_workbench/core/models/workspace_record.dart';
import 'package:personal_workbench/data/app_database.dart';
import 'package:personal_workbench/services/attachment_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('image attachments are copied, hashed, resolved, and deleted', () async {
    final root = await Directory.systemTemp.createTemp('workbench-attachment-');
    addTearDown(() => root.delete(recursive: true));
    final database = AppDatabase(
      factory: databaseFactoryFfi,
      overridePath: '${root.path}${Platform.pathSeparator}test.sqlite',
    );
    addTearDown(database.close);
    final service = AttachmentService(database: database, root: root);
    final source = File('${root.path}${Platform.pathSeparator}source.png');
    await source.writeAsBytes(const [0x89, 0x50, 0x4e, 0x47, 1, 2, 3]);
    final owner = WorkspaceRecord.create(kind: RecordKind.note, title: 'note');

    final attachment = await service.importImage(owner: owner, source: source);

    expect(attachment.sizeBytes, 7);
    expect(attachment.sha256, hasLength(64));
    expect(await service.forRecord(owner.id), hasLength(1));
    expect(await service.resolve(attachment), isNotNull);
    await service.delete(attachment);
    expect(await service.forRecord(owner.id), isEmpty);
    expect(await service.resolve(attachment), isNull);
  });

  test('image attachments above 20 MB are rejected before copying', () async {
    final root = await Directory.systemTemp.createTemp('workbench-limit-');
    addTearDown(() => root.delete(recursive: true));
    final database = AppDatabase(
      factory: databaseFactoryFfi,
      overridePath: '${root.path}${Platform.pathSeparator}test.sqlite',
    );
    addTearDown(database.close);
    final source = File('${root.path}${Platform.pathSeparator}large.png');
    await source.openWrite().close();
    await source.open(mode: FileMode.write).then((file) async {
      await file.truncate(AttachmentService.maxImageBytes + 1);
      await file.close();
    });
    final service = AttachmentService(database: database, root: root);
    final owner = WorkspaceRecord.create(kind: RecordKind.note, title: 'note');

    await expectLater(
      service.importImage(owner: owner, source: source),
      throwsFormatException,
    );
    expect(await service.forRecord(owner.id), isEmpty);
  });

  test('record cleanup removes all attachment files and metadata', () async {
    final root = await Directory.systemTemp.createTemp('workbench-cleanup-');
    addTearDown(() => root.delete(recursive: true));
    final database = AppDatabase(
      factory: databaseFactoryFfi,
      overridePath: '${root.path}${Platform.pathSeparator}test.sqlite',
    );
    addTearDown(database.close);
    final service = AttachmentService(database: database, root: root);
    final owner = WorkspaceRecord.create(kind: RecordKind.note, title: 'note');
    final sources = <File>[];
    for (var index = 0; index < 2; index++) {
      final source = File(
        '${root.path}${Platform.pathSeparator}source-$index.png',
      );
      await source.writeAsBytes([0x89, 0x50, 0x4e, 0x47, index]);
      sources.add(source);
      await service.importImage(owner: owner, source: source);
    }
    final attachments = await service.forRecord(owner.id);

    expect(await service.deleteForRecord(owner.id), 2);
    expect(await service.forRecord(owner.id), isEmpty);
    for (final attachment in attachments) {
      expect(await service.resolve(attachment), isNull);
    }
  });
}
