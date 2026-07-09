import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database_service.dart';
import '../core/models/user_progress_model.dart';

final wordDbServiceProvider = Provider((ref) {
  return WordDbService(DatabaseService.instance);
});

/// Handles vocabulary and word-eligibility DB queries.
///
/// Extracted from DatabaseService (A-01). Depends only on the connection
/// managed by [DatabaseService].
class WordDbService {
  final DatabaseService _db;

  const WordDbService(this._db);

  // ── Word eligibility ──────────────────────────────────────────────────────

  /// Returns a list of [WordRow]s eligible for [gameType] at [difficulty].
  Future<List<WordRow>> getEligibleWords({
    required String gameType,
    required int difficulty,
    required int limit,
    bool requiresDefinition = false,
    bool requiresSynonym = false,
    bool requiresAntonym = false,
  }) async {
    final diffClause = difficulty > 0
        ? 'AND w.difficulty = $difficulty'
        : '';
    final defClause = requiresDefinition
        ? 'AND EXISTS (SELECT 1 FROM definitions d WHERE d.word_id = w.id AND d.sense_order = 0)'
        : '';
    final synClause = requiresSynonym
        ? 'AND EXISTS (SELECT 1 FROM synonyms s WHERE s.word_id = w.id)'
        : '';
    final antClause = requiresAntonym
        ? 'AND EXISTS (SELECT 1 FROM antonyms a WHERE a.word_id = w.id)'
        : '';
    final fetchLimit = (limit * 4).clamp(limit, 2000);
    final upperClause =
        gameType == 'unscramble' ? 'AND w.word = UPPER(w.word)' : '';
    final rows = await _db.db.rawQuery('''
      SELECT w.id, w.word, wp.last_attempted
      FROM words w
      LEFT JOIN word_progress wp
        ON w.id = wp.word_id AND wp.game_type = ?
      WHERE (wp.status IS NULL OR wp.status != 'mastered')
        $upperClause
        $diffClause
        $defClause
        $synClause
        $antClause
      ORDER BY RANDOM()
      LIMIT $fetchLimit
    ''', [gameType]);
    final now = DateTime.now().millisecondsSinceEpoch;
    final sorted = rows.map((r) {
      final last = r['last_attempted'] as int?;
      return (id: r['id'] as int, priority: last == null ? 999999999 : now - last);
    }).toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));
    final ids = sorted.take(limit).map((e) => e.id).toList();
    return _loadWordRows(ids);
  }

  /// Returns the count of eligible words for [gameType] at [difficulty].
  Future<int> getEligibleWordCount({
    required String gameType,
    required int difficulty,
  }) async {
    final diffClause = difficulty > 0 ? 'AND w.difficulty = $difficulty' : '';
    final upperClause =
        gameType == 'unscramble' ? 'AND w.word = UPPER(w.word)' : '';
    return (await _db.db.rawQuery('''
      SELECT COUNT(*) AS c
      FROM words w
      LEFT JOIN word_progress wp ON w.id = wp.word_id AND wp.game_type = ?
      WHERE (wp.status IS NULL OR wp.status != 'mastered')
        $upperClause $diffClause
    ''', [gameType])).first['c'] as int? ?? 0;
  }

  /// Returns the daily featured word (highest priority unmastered word).
  Future<WordRow?> getDailyWord() async {
    final rows = await _db.db.rawQuery('''
      SELECT w.id
      FROM words w
      LEFT JOIN word_progress wp ON w.id = wp.word_id AND wp.game_type = 'daily'
      WHERE (wp.status IS NULL OR wp.status != 'mastered')
        AND w.word = UPPER(w.word)
        AND EXISTS (SELECT 1 FROM definitions d WHERE d.word_id = w.id AND d.sense_order = 0)
      ORDER BY COALESCE(wp.last_attempted, 0) ASC
      LIMIT 1
    ''');
    if (rows.isEmpty) return null;
    final result = await _loadWordRows([rows.first['id'] as int]);
    return result.isEmpty ? null : result.first;
  }

  // ── Batch word-row loading ────────────────────────────────────────────────

  Future<List<WordRow>> loadWordRows(List<int> ids) => _loadWordRows(ids);

  Future<List<WordRow>> _loadWordRows(List<int> ids) async {
    if (ids.isEmpty) return [];
    final ph = ids.map((_) => '?').join(',');
    final wordTexts = await _db.db.rawQuery(
      'SELECT id, word FROM words WHERE id IN ($ph)', ids,
    );
    final wordTextMap = {for (final r in wordTexts) r['id'] as int: r['word'] as String};

    // Definitions (first sense only)
    final defRows = await _db.db.rawQuery('''
      SELECT d.word_id, d.pos, d.definition
      FROM definitions d
      WHERE d.word_id IN ($ph) AND d.sense_order = 0
    ''', ids);
    final defMap = {for (final r in defRows) r['word_id'] as int: r};

    // Synonyms
    final synRows = await _db.db.rawQuery('''
      SELECT word_id, GROUP_CONCAT(synonym, '|') AS syns
      FROM (SELECT word_id, synonym FROM synonyms WHERE word_id IN ($ph) LIMIT 10)
      GROUP BY word_id
    ''', ids);
    final synMap = {for (final r in synRows) r['word_id'] as int: r['syns'] as String? ?? ''};

    // Antonyms
    final antRows = await _db.db.rawQuery('''
      SELECT word_id, GROUP_CONCAT(antonym, '|') AS ants
      FROM (SELECT word_id, antonym FROM antonyms WHERE word_id IN ($ph) LIMIT 10)
      GROUP BY word_id
    ''', ids);
    final antMap = {for (final r in antRows) r['word_id'] as int: r['ants'] as String? ?? ''};

    // Bengali meanings
    final words = wordTextMap.values.map((w) => w.toLowerCase()).toList();
    final bnPh = words.map((_) => '?').join(',');
    List<Map<String, Object?>> bnRows = [];
    if (words.isNotEmpty) {
      bnRows = await _db.db.rawQuery(
        'SELECT word, meaning FROM bengali_dictionary WHERE word IN ($bnPh)',
        words,
      );
    }
    final bnMap = {for (final r in bnRows) r['word'] as String: r['meaning'] as String? ?? ''};

    return ids.map((id) {
      final word = wordTextMap[id] ?? '';
      final defRow = defMap[id];
      final definition = defRow?['definition'] as String? ?? '';
      final pos = defRow?['pos'] as String? ?? '';
      final syns = (synMap[id] ?? '').split('|').where((s) => s.isNotEmpty).toList();
      final ants = (antMap[id] ?? '').split('|').where((s) => s.isNotEmpty).toList();
      final rawBn = bnMap[word.toLowerCase()] ?? '';
      final bn = rawBn.isEmpty ? '' : rawBn.split(',').first.trim();
      final len = word.length;
      final hasDef = definition.isNotEmpty;
      final supportedGames = [
        'unscramble',
        if (hasDef) ...['true_false', 'speed_racing', 'meaning_chase', 'definition_match'],
        if (syns.isNotEmpty) 'synonym_antonym',
      ];
      return WordRow(
        id: id,
        word: word,
        definition: definition,
        pos: pos,
        synonyms: syns,
        antonyms: ants,
        banglaMeaning: bn,
        example: '',
        difficulty: DatabaseService.difficultyForLength(len),
        supportedGames: supportedGames,
      );
    }).where((w) => w.word.isNotEmpty).toList();
  }

  // ── Word ID lookups ───────────────────────────────────────────────────────

  /// Returns a map of lowercase word → word_id for a list of word strings.
  Future<Map<String, int>> getWordIdsByLowercase(List<String> words) async {
    if (words.isEmpty) return {};
    final lowered = words.map((w) => w.toLowerCase()).toList();
    final ph = lowered.map((_) => '?').join(',');
    final rows = await _db.db.rawQuery(
      'SELECT id, LOWER(word) AS lw FROM words WHERE LOWER(word) IN ($ph)',
      lowered,
    );
    return {for (final r in rows) r['lw'] as String: r['id'] as int};
  }

  /// Returns the word_id for a single lowercase word, or null.
  Future<int?> getWordIdByLowercase(String word) async {
    final map = await getWordIdsByLowercase([word]);
    return map[word.toLowerCase()];
  }

  // ── Meaning Chase phrases ────────────────────────────────────────────────

  /// Returns [limit] phrase-type words with an 'en' meaning suitable for
  /// Meaning Chase. Falls back gracefully if the phrases column is absent.
  Future<List<Map<String, dynamic>>> getMeaningChasePhrases({
    required int limit,
  }) async {
    try {
      final rows = await _db.db.rawQuery('''
        SELECT b.word, b.meaning
        FROM bengali_dictionary b
        WHERE b.word LIKE '% %'
          AND LENGTH(b.meaning) > 0
        ORDER BY RANDOM()
        LIMIT ?
      ''', [limit]);
      return rows.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }
}
