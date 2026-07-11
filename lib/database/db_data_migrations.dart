import 'database_service.dart';

/// DB-03 / DB-04 / DB-05: One-shot data-enrichment migration helpers.
///
/// These are run idempotently once per install.  They do NOT modify
/// vocabulary.db itself (the asset); they operate on the opened connection.
///
/// DB-03: Promote lowercase orphan words to UPPERCASE.
///   1,149 words exist only in lowercase with no UPPERCASE counterpart.
///   Creating UPPERCASE copies makes them eligible for all games.
///
/// DB-04: Back-fill Bengali meaning gaps.
///   23,471 UPPERCASE words have no Bengali meaning.  This helper accepts a
///   caller-supplied `Map<String, String>` (word → meaning) and inserts rows.
///
/// DB-05: Insert IPA from an external source.
///   Accepts a caller-supplied `Map<String, String>` (word → IPA) and inserts
///   rows into ipa_pronunciations with locale = 'en_US', skipping duplicates.
extension DataMigrations on DatabaseService {
  // ── DB-03 ─────────────────────────────────────────────────────────────

  /// Promotes all lowercase words that have no UPPERCASE counterpart.
  /// Returns the number of rows promoted.
  Future<int> promoteOrphanLowercaseWords() async {
    // Find lowercase words with no corresponding UPPERCASE row.
    final orphans = await db.rawQuery('''
      SELECT id, word
      FROM words
      WHERE word != UPPER(word)
        AND NOT EXISTS (
          SELECT 1 FROM words w2
          WHERE w2.word = UPPER(words.word)
        )
    ''');
    if (orphans.isEmpty) return 0;

    int promoted = 0;
    await db.transaction((txn) async {
      for (final row in orphans) {
        final lower = row['word'] as String;
        final upper = lower.toUpperCase();

        // Copy the word row with UPPERCASE spelling.
        await txn.rawInsert('''
          INSERT OR IGNORE INTO words (word, difficulty)
          SELECT ?, difficulty FROM words WHERE word = ?
        ''', [upper, lower]);

        // Copy bengali_dictionary entry.
        await txn.rawInsert('''
          INSERT OR IGNORE INTO bengali_dictionary (en, bn, is_phrase)
          SELECT UPPER(en), bn, is_phrase FROM bengali_dictionary WHERE LOWER(en) = ?
        ''', [lower.toLowerCase()]);

        promoted++;
      }
    });
    return promoted;
  }

  // ── DB-04 ─────────────────────────────────────────────────────────────

  /// Back-fills Bengali meanings for words that currently have none.
  ///
  /// [meanings] maps UPPERCASE word strings to their Bengali translations.
  /// Only inserts rows where the word exists in `words` and has no current
  /// entry in `bengali_dictionary`.  Returns count of rows inserted.
  Future<int> backfillBengaliMeanings(
      Map<String, String> meanings) async {
    int inserted = 0;
    await db.transaction((txn) async {
      for (final entry in meanings.entries) {
        final word = entry.key.toUpperCase();
        final meaning = entry.value;
        if (meaning.isEmpty) continue;
        // Only insert if the word exists and has no meaning yet.
        final count = await txn.rawInsert('''
          INSERT OR IGNORE INTO bengali_dictionary (en, bn, is_phrase)
          SELECT ?, ?, 0
          WHERE EXISTS (SELECT 1 FROM words WHERE word = ?)
            AND NOT EXISTS (SELECT 1 FROM bengali_dictionary WHERE LOWER(en) = LOWER(?))
        ''', [word, meaning, word, word]);
        inserted += count;
      }
    });
    return inserted;
  }

  // ── DB-05 ─────────────────────────────────────────────────────────────

  /// Inserts IPA pronunciations from an external source (e.g. CMU dict).
  ///
  /// [ipaMap] maps word strings to their IPA transcription (e.g. "hello" →
  /// "hɛˈloʊ"). Inserts into `ipa_pronunciations` with locale = 'en_US',
  /// skipping words that already have an IPA entry. Returns count inserted.
  ///
  /// Note: ipa_pronunciations has no word_id FK — it stores the word as
  /// lowercase text directly (matching the existing seeded rows), joined
  /// against [words] only at read time via getIpaForWord's UPPER() join.
  Future<int> backfillIpaPronunciations(
      Map<String, String> ipaMap) async {
    int inserted = 0;
    await db.transaction((txn) async {
      for (final entry in ipaMap.entries) {
        final word = entry.key.toLowerCase();
        final ipa = entry.value;
        if (ipa.isEmpty) continue;
        // Only insert if the word actually exists in the vocabulary.
        final exists = await txn.rawQuery(
          'SELECT 1 FROM words WHERE UPPER(word) = UPPER(?) LIMIT 1', [word]);
        if (exists.isEmpty) continue;
        final count = await txn.rawInsert('''
          INSERT OR IGNORE INTO ipa_pronunciations (word, ipa, locale)
          VALUES (?, ?, 'en_US')
        ''', [word, ipa]);
        inserted += count;
      }
    });
    return inserted;
  }
}
