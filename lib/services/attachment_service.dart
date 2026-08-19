import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/models/attachment.dart';
import '../core/models/workspace_record.dart';
import '../data/app_database.dart';
import '../data/backup_service.dart';

class AttachmentService {
  AttachmentService({required this.database, Directory? root}) : _root = root;

  static const maxImageBytes = 20 * 1024 * 1024;
  static const _mimeTypes = {
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.gif': 'image/gif',
    '.webp': 'image/webp',
    '.bmp': 'image/bmp',
  };

  final AppDatabase database;
  final Directory? _root;

  Future<Attachment> importImage({
    required WorkspaceRecord owner,
    required File source,
  }) async {
    final extension = p.extension(source.path).toLowerCase();
    final mimeType = _mimeTypes[extension];
    if (mimeType == null) {
      throw const FormatException('仅支持 PNG、JPEG、GIF、WebP 和 BMP 图片。');
    }
    final size = await source.length();
    if (size > maxImageBytes) {
      throw const FormatException('单张图片不能超过 20 MB。');
    }

    final root = _root ?? await getApplicationSupportDirectory();
    final directory = Directory(p.join(root.path, 'attachments'));
    await directory.create(recursive: true);
    final id = newRecordId();
    final relativePath = p.join('attachments', '$id$extension');
    final target = File(p.join(root.path, relativePath));
    await source.copy(target.path);

    try {
      final digest = await Sha256().hash(await target.readAsBytes());
      final attachment = Attachment(
        id: id,
        ownerRecordId: owner.id,
        ownerKind: owner.kind,
        fileName: p.basename(source.path),
        relativePath: relativePath,
        mimeType: mimeType,
        sizeBytes: size,
        sha256: digest.bytes
            .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
            .join(),
        createdAt: DateTime.now(),
      );
      await database.saveAttachment(attachment);
      return attachment;
    } catch (_) {
      if (await target.exists()) await target.delete();
      rethrow;
    }
  }

  Future<List<Attachment>> forRecord(String recordId) {
    return database.loadAttachments(ownerRecordId: recordId);
  }

  Future<int> totalBytes() => database.attachmentBytes();

  Future<List<BackupAttachment>> createBackupEntries() async {
    final entries = <BackupAttachment>[];
    for (final attachment in await database.loadAttachments()) {
      final file = await resolve(attachment);
      if (file == null) {
        entries.add(BackupAttachment(metadata: attachment));
        continue;
      }
      final bytes = await file.readAsBytes();
      if (bytes.length != attachment.sizeBytes ||
          await _sha256(bytes) != attachment.sha256) {
        throw FormatException('附件校验失败：${attachment.fileName}');
      }
      entries.add(BackupAttachment(metadata: attachment, bytes: bytes));
    }
    return entries;
  }

  Future<void> restoreBackupEntries(
    Iterable<BackupAttachment> entries, {
    Future<void> Function(List<Attachment> attachments)? commitDatabase,
  }) async {
    final root = _root ?? await getApplicationSupportDirectory();
    await root.create(recursive: true);
    final liveDirectory = Directory(p.join(root.path, 'attachments'));
    final restoreId = newRecordId();
    final stagingDirectory = Directory(
      p.join(root.path, '.attachments-restore-$restoreId'),
    );
    final rollbackDirectory = Directory(
      p.join(root.path, '.attachments-rollback-$restoreId'),
    );
    await stagingDirectory.create(recursive: true);
    final restored = <Attachment>[];
    final attachmentIds = <String>{};

    try {
      for (final entry in entries) {
        final source = entry.metadata;
        final extension = p.extension(source.fileName).toLowerCase();
        if (_mimeTypes[extension] != source.mimeType) {
          throw FormatException('附件类型不匹配：${source.fileName}');
        }
        if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(source.id) ||
            !attachmentIds.add(source.id)) {
          throw FormatException('附件标识无效或重复：${source.fileName}');
        }
        if (source.sizeBytes < 0 || source.sizeBytes > maxImageBytes) {
          throw FormatException('附件大小无效：${source.fileName}');
        }
        final bytes = entry.bytes;
        if (bytes != null &&
            (bytes.length != source.sizeBytes ||
                await _sha256(bytes) != source.sha256)) {
          throw FormatException('附件内容校验失败：${source.fileName}');
        }
        final relativePath = p.join('attachments', '${source.id}$extension');
        final attachment = Attachment(
          id: source.id,
          ownerRecordId: source.ownerRecordId,
          ownerKind: source.ownerKind,
          fileName: source.fileName,
          relativePath: relativePath,
          mimeType: source.mimeType,
          sizeBytes: source.sizeBytes,
          sha256: source.sha256,
          createdAt: source.createdAt,
        );
        if (bytes != null) {
          await File(
            p.join(stagingDirectory.path, '${source.id}$extension'),
          ).writeAsBytes(bytes, flush: true);
        }
        restored.add(attachment);
      }

      final hadLiveDirectory = await liveDirectory.exists();
      if (hadLiveDirectory) {
        await liveDirectory.rename(rollbackDirectory.path);
      }
      try {
        await stagingDirectory.rename(liveDirectory.path);
      } catch (_) {
        if (hadLiveDirectory && await rollbackDirectory.exists()) {
          await rollbackDirectory.rename(liveDirectory.path);
        }
        rethrow;
      }

      try {
        if (commitDatabase == null) {
          await database.replaceAttachments(restored);
        } else {
          await commitDatabase(restored);
        }
      } catch (_) {
        if (await liveDirectory.exists()) {
          await liveDirectory.delete(recursive: true);
        }
        if (hadLiveDirectory && await rollbackDirectory.exists()) {
          await rollbackDirectory.rename(liveDirectory.path);
        }
        rethrow;
      }

      if (await rollbackDirectory.exists()) {
        await rollbackDirectory.delete(recursive: true);
      }
    } finally {
      if (await stagingDirectory.exists()) {
        await stagingDirectory.delete(recursive: true);
      }
    }
  }

  Future<File?> resolve(Attachment attachment) async {
    final root = _root ?? await getApplicationSupportDirectory();
    final file = File(p.join(root.path, attachment.relativePath));
    return await file.exists() ? file : null;
  }

  Future<void> delete(Attachment attachment) async {
    final file = await resolve(attachment);
    await database.deleteAttachment(attachment.id);
    if (file != null && await file.exists()) await file.delete();
  }

  Future<int> deleteForRecord(String recordId) async {
    final attachments = await forRecord(recordId);
    for (final attachment in attachments) {
      await delete(attachment);
    }
    return attachments.length;
  }

  Future<void> deleteForRecordsAtomically(
    Iterable<WorkspaceRecord> records, {
    required Future<void> Function() commitDatabase,
  }) async {
    final keys = records
        .map((record) => '${record.kind.name}:${record.id}')
        .toSet();
    final attachments = (await database.loadAttachments()).where(
      (attachment) => keys.contains(
        '${attachment.ownerKind.name}:${attachment.ownerRecordId}',
      ),
    );
    if (attachments.isEmpty) {
      await commitDatabase();
      return;
    }

    final root = _root ?? await getApplicationSupportDirectory();
    final quarantine = Directory(
      p.join(root.path, '.attachments-delete-${newRecordId()}'),
    );
    await quarantine.create(recursive: true);
    final moved = <({File source, File target})>[];
    try {
      for (final attachment in attachments) {
        final source = File(p.join(root.path, attachment.relativePath));
        if (!await source.exists()) continue;
        final target = File(p.join(quarantine.path, p.basename(source.path)));
        await source.rename(target.path);
        moved.add((source: source, target: target));
      }
      await commitDatabase();
      if (await quarantine.exists()) {
        try {
          await quarantine.delete(recursive: true);
        } catch (_) {
          // The database commit is authoritative; a quarantined file can be
          // cleaned up later without restoring an orphaned live attachment.
        }
      }
    } catch (_) {
      for (final item in moved.reversed) {
        if (await item.target.exists()) {
          await item.target.rename(item.source.path);
        }
      }
      if (await quarantine.exists()) {
        await quarantine.delete(recursive: true);
      }
      rethrow;
    }
  }

  Future<String> _sha256(List<int> bytes) async {
    final digest = await Sha256().hash(bytes);
    return digest.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}
