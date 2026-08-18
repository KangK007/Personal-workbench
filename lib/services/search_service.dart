import '../core/models/workspace_record.dart';

class SearchService {
  final Map<String, _SearchIndexEntry> _index = {};

  List<WorkspaceRecord> search(
    Iterable<WorkspaceRecord> records,
    String query,
  ) {
    final terms = query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .toList(growable: false);
    if (terms.isEmpty) return const [];

    final activeKeys = <String>{};
    final matches = <WorkspaceRecord>[];
    for (final record in records) {
      if (record.isDeleted) continue;
      final key = '${record.kind.name}:${record.id}';
      activeKeys.add(key);
      final cached = _index[key];
      final text = cached != null && identical(cached.record, record)
          ? cached.text
          : _indexRecord(record);
      if (cached == null || !identical(cached.record, record)) {
        _index[key] = _SearchIndexEntry(record, text);
      }
      if (terms.every(text.contains)) matches.add(record);
    }
    _index.removeWhere((key, _) => !activeKeys.contains(key));

    matches.sort((a, b) {
      final scoreComparison = _titleScore(
        b.title,
        terms,
      ).compareTo(_titleScore(a.title, terms));
      if (scoreComparison != 0) return scoreComparison;
      if (a.favorite != b.favorite) return a.favorite ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return matches;
  }

  String _indexRecord(WorkspaceRecord record) => [
    record.title,
    record.body,
    record.tags.join(' '),
    record.kind.label,
    record.data.values.join(' '),
  ].join(' ').toLowerCase();

  int _titleScore(String title, List<String> terms) {
    final normalized = title.toLowerCase();
    return terms.fold(0, (score, term) {
      if (normalized.startsWith(term)) return score + 3;
      if (normalized.contains(term)) return score + 1;
      return score;
    });
  }
}

class _SearchIndexEntry {
  const _SearchIndexEntry(this.record, this.text);

  final WorkspaceRecord record;
  final String text;
}
