import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/models/workspace_record.dart';
import '../data/app_database.dart';

class SyncResult {
  const SyncResult({
    required this.uploaded,
    required this.downloaded,
    required this.conflicts,
  });

  final int uploaded;
  final int downloaded;
  final int conflicts;
}

class SyncException implements Exception {
  const SyncException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

abstract interface class WorkspaceSyncRemote {
  String get userId;

  Future<void> upsert(List<Map<String, dynamic>> rows);

  Future<void> delete(List<Map<String, dynamic>> keys);

  Future<List<Map<String, dynamic>>> fetchPage({
    required int offset,
    required int limit,
  });
}

class SupabaseSyncService {
  SupabaseSyncService(this.client) : _remote = null, _pageSize = 500;

  SupabaseSyncService.withRemote(
    WorkspaceSyncRemote remote, {
    int pageSize = 500,
  }) : client = null,
       _remote = remote,
       _pageSize = pageSize;

  final SupabaseClient? client;
  final WorkspaceSyncRemote? _remote;
  final int _pageSize;

  bool get configured => client != null || _remote != null;
  User? get currentUser => client?.auth.currentUser;
  bool get cloudWriteReady => _remote != null || currentUser != null;

  Future<void> deleteRecords(Iterable<WorkspaceRecord> records) async {
    final remote = _remote ?? _remoteForClient();
    final keys = records
        .map(
          (record) => <String, dynamic>{
            'id': record.id,
            'kind': record.kind.name,
          },
        )
        .toList(growable: false);
    if (keys.isNotEmpty) await remote.delete(keys);
  }

  Future<void> signIn(String email, String password) async {
    final value = client;
    if (value == null) throw StateError('云同步尚未配置。');
    await value.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUp(String email, String password) async {
    final value = client;
    if (value == null) throw StateError('云同步尚未配置。');
    await value.auth.signUp(email: email, password: password);
  }

  Future<void> signOut() async {
    final value = client;
    if (value == null) throw StateError('云同步尚未配置。');
    await value.auth.signOut();
  }

  Future<SyncResult> sync(AppDatabase database) async {
    try {
      final remote = _remote ?? _remoteForClient();
      final dirty = await database.loadDirtyRecords();
      final local = await database.loadRecords();
      final localByKey = {
        for (final record in local) _recordKey(record): record,
      };
      final blockedUploads = <String>{};
      var downloaded = 0;
      var conflicts = 0;
      var offset = 0;

      while (true) {
        final rows = await remote.fetchPage(offset: offset, limit: _pageSize);
        for (final row in rows) {
          final payload = row['payload'];
          if (payload is! Map) {
            throw const FormatException('云端记录格式无效。');
          }
          final remoteRecord = WorkspaceRecord.fromJson(
            Map<String, dynamic>.from(payload),
          ).copyWith(syncState: SyncState.clean, touch: false);
          final key = _recordKey(remoteRecord);
          final current = localByKey[key];
          if (current == null) {
            await database.saveRecord(remoteRecord, markDirty: false);
            localByKey[key] = remoteRecord;
            downloaded++;
            continue;
          }
          if (!remoteRecord.updatedAt.isAfter(current.updatedAt)) continue;

          if (current.syncState == SyncState.dirty) {
            await database.saveRecord(current.asConflictCopy());
            blockedUploads.add(key);
            conflicts++;
          }
          await database.saveRecord(remoteRecord, markDirty: false);
          localByKey[key] = remoteRecord;
          downloaded++;
        }
        if (rows.length < _pageSize) break;
        offset += rows.length;
      }

      final uploads = dirty
          .where((record) => !blockedUploads.contains(_recordKey(record)))
          .toList(growable: false);
      if (uploads.isNotEmpty) {
        await remote.upsert(
          uploads.map((record) => _toRemoteRow(record, remote.userId)).toList(),
        );
        await database.markClean(uploads);
      }

      return SyncResult(
        uploaded: uploads.length,
        downloaded: downloaded,
        conflicts: conflicts,
      );
    } on StateError {
      rethrow;
    } on SyncException {
      rethrow;
    } catch (error) {
      throw SyncException('同步失败，请检查网络连接后重试。', error);
    }
  }

  WorkspaceSyncRemote _remoteForClient() {
    final value = client;
    final user = value?.auth.currentUser;
    if (value == null || user == null) {
      throw StateError('请先登录后再同步。');
    }
    return _SupabaseWorkspaceSyncRemote(value, user.id);
  }

  static String _recordKey(WorkspaceRecord record) =>
      '${record.kind.name}:${record.id}';

  static Map<String, dynamic> _toRemoteRow(
    WorkspaceRecord record,
    String userId,
  ) => {
    'user_id': userId,
    'id': record.id,
    'kind': record.kind.name,
    'payload': record.toJson(),
    'updated_at': record.updatedAt.toUtc().toIso8601String(),
    'deleted_at': record.deletedAt?.toUtc().toIso8601String(),
  };
}

class _SupabaseWorkspaceSyncRemote implements WorkspaceSyncRemote {
  const _SupabaseWorkspaceSyncRemote(this.client, this.userId);

  final SupabaseClient client;
  @override
  final String userId;

  @override
  Future<void> upsert(List<Map<String, dynamic>> rows) async {
    await client
        .from('workspace_records')
        .upsert(rows, onConflict: 'user_id,id,kind');
  }

  @override
  Future<void> delete(List<Map<String, dynamic>> keys) async {
    for (final key in keys) {
      await client
          .from('workspace_records')
          .delete()
          .eq('user_id', userId)
          .eq('id', key['id'] as String)
          .eq('kind', key['kind'] as String);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPage({
    required int offset,
    required int limit,
  }) async {
    final rows = await client
        .from('workspace_records')
        .select('id,kind,payload,updated_at,deleted_at')
        .eq('user_id', userId)
        .order('updated_at')
        .range(offset, offset + limit - 1);
    return List<Map<String, dynamic>>.from(rows);
  }
}
