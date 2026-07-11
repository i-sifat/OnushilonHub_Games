// UX-03: on-demand word-detail queries.
//
// These methods complement DatabaseService without modifying it.
// They are used by WordDetailScreen and saved-words tap handlers.

import 'database_service.dart';

extension WordDetailQueries on DatabaseService {
  // ── Single-word lookup ────────────────────────────────────────────────────────

  /// Fetch a complete [WordRow] by its primary key.
  ///
  /// Mirrors the logic in [_loadWordRows] but for a single word without
  /// touching the private method.
  Future<WordRow?> getWordById(int wordId) async {
    // Word text
    final wordTexts = await db.rawQuery(
      'SELECT id, word FROM words WHERE id = ? LIMIT 1',
      [wordId],
    );
    if (wordTexts.isEmpty) return null;

    final id = wordTexts.first['id'] as int;
    final word = wordTexts.first['word'] as String;

    // Definition (first sense only) — consistent with _loadWordRows
    final defRows = await db.rawQuery('''
      SELECT pos, definition
      FROM definitions
      WHERE word_id = ? AND sense_order = 0
      LIMIT 1
    ''', [id]);

    // Synonyms (up to 10, same cap as _loadWordRows)
    final synRows = await db.rawQuery('''
      SELECT GROUP_CONCAT(synonym, '|') AS syns
      FROM (SELECT synonym FROM synonyms WHERE word_id = ? LIMIT 10)
    ''', [id]);

    // Antonyms (up to 10)
    final antRows = await db.rawQuery('''
      SELECT GROUP_CONCAT(antonym, '|') AS ants
      FROM (SELECT antonym FROM antonyms WHERE word_id = ? LIMIT 10)
    ''', [id]);

    // Bengali meaning
    final bnRows = await db.rawQuery(
      'SELECT bn FROM bengali_dictionary WHERE LOWER(en) = ? LIMIT 1',
      [word.toLowerCase()],
    );

    final def = defRows.isEmpty ? null : defRows.first;
    final synsRaw =
        synRows.isEmpty ? '' : (synRows.first['syns'] as String? ?? '');
    final antsRaw =
        antRows.isEmpty ? '' : (antRows.first['ants'] as String? ?? '');
    final syns =
        synsRaw.split('|').where((s) => s.isNotEmpty).toList();
    final ants =
        antsRaw.split('|').where((s) => s.isNotEmpty).toList();
    final rawBn = bnRows.isEmpty
        ? ''
        : (bnRows.first['bn'] as String? ?? '');
    final bn = rawBn.isEmpty ? '' : rawBn.split(',').first.trim();

    // Derive supported games from available word data — mirrors _loadWordRows.
    final hasDef = def != null && (def['definition'] as String? ?? '').isNotEmpty;
    final supportedGames = <String>[
      'unscramble',
      if (hasDef) ...['true_false', 'speed_racing', 'meaning_chase', 'definition_match'],
      if (syns.isNotEmpty) 'synonym_antonym',
    ];

    return WordRow(
      id: id,
      word: word,
      definition: def?['definition'] as String? ?? '',
      pos: def?['pos'] as String? ?? '',
      synonyms: syns,
      antonyms: ants,
      banglaMeaning: bn,
      // DB-01 removed the example JOIN from _loadWordRows.
      // Use getUsageExample(wordId) for on-demand access.
      example: '',
      // Derive difficulty from word length, matching _loadWordRows behaviour.
      difficulty: DatabaseService.difficultyForLength(word.length),
      supportedGames: supportedGames,
    );
  }

  // ── On-demand usage example (DB-01 companion) ───────────────────────────────

  /// Fetch the first usage example for [wordId], or null if none exists.
  ///
  /// DB-01 removed the LEFT JOIN from [_loadWordRows] to cut game-start
  /// overhead. This method restores access for the word-detail screen,
  /// where the extra round-trip is acceptable.
  Future<String?> getUsageExample(int wordId) async {
    final rows = await db.rawQuery('''
      SELECT ue.example
      FROM usage_examples ue
      JOIN definitions d ON d.id = ue.definition_id
      WHERE d.word_id = ?
      LIMIT 1
    ''', [wordId]);
    if (rows.isEmpty) return null;
    return rows.first['example'] as String?;
  }

  // ── IPA lookup ───────────────────────────────────────────────────────────────

  /// Fetch the IPA pronunciation string for [wordId], or null if unavailable.
  ///
  /// ipa_pronunciations stores the word as text (no word_id FK), so this
  /// joins through [words] to resolve the id → text → IPA lookup.
  Future<String?> getIpaForWord(int wordId) async {
    final rows = await db.rawQuery('''
      SELECT ip.ipa
      FROM ipa_pronunciations ip
      JOIN words w ON UPPER(w.word) = UPPER(ip.word)
      WHERE w.id = ? AND ip.locale = 'en_US'
      LIMIT 1
    ''', [wordId]);
    if (rows.isEmpty) return null;
    return rows.first['ipa'] as String?;
  }

  // ── Reverse lookup (word text → id) ───────────────────────────────────────

  /// Resolve a word string (any case) to its internal [words.id].
  ///
  /// Used by [SavedWordsScreen] and [SavedWordTile] tap handlers where
  /// only the word text is available (saved_words table stores text, not FK).
  Future<int?> getWordIdByText(String word) async {
    // Try exact match first (most words are stored UPPERCASE)
    var rows = await db.rawQuery(
      'SELECT id FROM words WHERE word = ? LIMIT 1',
      [word.toUpperCase()],
    );
    if (rows.isNotEmpty) return rows.first['id'] as int?;

    // Fallback: case-insensitive search
    rows = await db.rawQuery(
      'SELECT id FROM words WHERE UPPER(word) = UPPER(?) LIMIT 1',
      [word],
    );
    if (rows.isEmpty) return null;
    return rows.first['id'] as int?;
  }
}
