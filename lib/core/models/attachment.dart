import 'package:path/path.dart' as p;

import 'workspace_record.dart';

class Attachment {
  const Attachment({
    required this.id,
    required this.ownerRecordId,
    required this.ownerKind,
    required this.fileName,
    required this.relativePath,
    required this.mimeType,
    required this.sizeBytes,
    required this.sha256,
    required this.createdAt,
  });

  final String id;
  final String ownerRecordId;
  final RecordKind ownerKind;
  final String fileName;
  final String relativePath;
  final String mimeType;
  final int sizeBytes;
  final String sha256;
  final DateTime createdAt;

  String get markdownLabel => p.basenameWithoutExtension(fileName);

  Map<String, Object?> toDatabase() => {
    'id': id,
    'owner_record_id': ownerRecordId,
    'owner_kind': ownerKind.name,
    'file_name': fileName,
    'relative_path': relativePath,
    'mime_type': mimeType,
    'size_bytes': sizeBytes,
    'sha256': sha256,
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  factory Attachment.fromDatabase(Map<String, Object?> row) => Attachment(
    id: row['id'] as String,
    ownerRecordId: row['owner_record_id'] as String,
    ownerKind: RecordKind.values.firstWhere(
      (kind) => kind.name == row['owner_kind'],
      orElse: () => RecordKind.note,
    ),
    fileName: row['file_name'] as String,
    relativePath: row['relative_path'] as String,
    mimeType: row['mime_type'] as String,
    sizeBytes: (row['size_bytes'] as num).toInt(),
    sha256: row['sha256'] as String,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      (row['created_at'] as num).toInt(),
    ),
  );
}
