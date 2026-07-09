// F-04: word search extension on DatabaseService.
//
// Provides a case-insensitive LIKE search over the words table, JOINing the
// first definition (sense_order = 0) for each result.

import 'database_service.dart';

/// Lightweight result model for the word search screen.
class WordSearchResult {
  final int id;
  final String word;
  final String definition;
  final String pos;

  const WordSearchResult({
    required this.id,
    required this.word,
    required this.definition,
    required this.pos,
  });
}

extension WordSearchQueries on DatabaseService {
  /// Case-insensitive substring search on [words.word].
  ///
  /// Returns up to [limit] results ordered by:
  ///   1. Exact match (UPPER(word) = UPPER(query))
  ///   2. Starts-with match
  ///   3. Contains match
  ///
  /// This ordering surfaces the most relevant result at the top without
  /// requiring a full-text index.
  Future<List<WordSearchResult>> searchWords(
    String query, {
    int limit = 50,
  }) async {
    if (query.trim().isEmpty) return [];

    final pattern = '%${query.replaceAll('%', '\\%').replaceAll('_', '\\_')}%';

    final rows = await db.rawQuery(
      '''
      SELECT
        w.id,
        w.word,
        COALESCE(d.definition, '') AS definition,
        COALESCE(d.pos, '')        AS pos
      FROM words w
      LEFT JOIN definitions d
        ON d.word_id = w.id AND d.sense_order = 0
      WHERE UPPER(w.word) LIKE UPPER(?)
      ORDER BY
        CASE WHEN UPPER(w.word) = UPPER(?) THEN 0
             WHEN UPPER(w.word) LIKE UPPER(? || '%') THEN 1
             ELSE 2
        END,
        LENGTH(w.word) ASC
      LIMIT ?
      ''',
      [pattern, query, query, limit],
    );

    return rows
        .map((r) => WordSearchResult(
              id: r['id'] as int,
              word: r['word'] as String,
              definition: r['definition'] as String? ?? '',
              pos: r['pos'] as String? ?? '',
            ))
        .toList();
  }
}
