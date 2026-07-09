import 'package:sqflite/sqflite.dart';
import 'database_service.dart';
import 'srs_calculator.dart';

/// F-01: SM-2 Spaced Repetition schema + query extensions on [DatabaseService].
///
/// Adds [next_review_at] (INTEGER, Unix ms) and [ease_factor] (REAL, default 2.5)
/// columns to the existing [word_progress] table via idempotent ALTER TABLE.
/// These columns are used by [getEligibleWordsForReview] to filter words that
/// are due for review according to the SM-2 schedule.
extension SrsExtensions on DatabaseService {
  /// Ensures the SRS columns exist on [word_progress].
  /// Safe to call repeatedly — catches [DatabaseException] if already present.
  Future<void> ensureSrsColumns() async {
    try {
      await db.execute(
        'ALTER TABLE word_progress ADD COLUMN next_review_at INTEGER',
      );
    } on DatabaseException catch (_) {}
    try {
      await db.execute(
        'ALTER TABLE word_progress ADD COLUMN ease_factor REAL NOT NULL DEFAULT 2.5',
      );
    } on DatabaseException catch (_) {}
  }

  /// Updates a word's SRS schedule after the player answers it.
  ///
  /// Calls [SrsCalculator.nextReview] to compute the new interval and
  /// persists both [next_review_at] and [ease_factor] to [word_progress].
  Future<void> updateSrsSchedule({
    required int wordId,
    required String gameType,
    required bool correct,
  }) async {
    await ensureSrsColumns();

    // Fetch current SRS state for this word+game.
    final rows = await db.rawQuery('''
      SELECT attempts, ease_factor, next_review_at
      FROM word_progress
      WHERE word_id = ? AND game_type = ?
    ''', [wordId, gameType]);

    final attempts = rows.isEmpty ? 0 : (rows.first['attempts'] as int? ?? 0);
    final currentEase = rows.isEmpty
        ? 2.5
        : (rows.first['ease_factor'] as double? ?? 2.5);

    final result = SrsCalculator.nextReview(
      attempts: attempts + 1,
      correct: correct,
      easeFactor: currentEase,
    );

    await db.execute('''
      INSERT INTO word_progress
        (word_id, game_type, status, attempts, last_attempted, next_review_at, ease_factor)
      VALUES (?, ?, ?, 1, ?, ?, ?)
      ON CONFLICT(word_id, game_type) DO UPDATE SET
        attempts       = attempts + 1,
        last_attempted = excluded.last_attempted,
        next_review_at = excluded.next_review_at,
        ease_factor    = excluded.ease_factor,
        status         = CASE
          WHEN attempts + 1 >= 10 AND excluded.ease_factor >= 2.0
            THEN 'mastered'
          ELSE status
        END
    ''', [
      wordId,
      gameType,
      correct ? 'learning' : 'new',
      DateTime.now().millisecondsSinceEpoch,
      result.nextReviewAtMs,
      result.easeFactor,
    ]);
  }

  /// Returns eligible words that are due for SRS review for [gameType].
  ///
  /// F-01: replaces the simple 'status != mastered' filter with
  /// 'next_review_at IS NULL OR next_review_at <= now()'.
  Future<List<Map<String, Object?>>> getEligibleWordsForReview({
    required String gameType,
    required int limit,
  }) async {
    await ensureSrsColumns();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    return db.rawQuery('''
      SELECT w.id, w.word
      FROM words w
      LEFT JOIN word_progress wp
        ON w.id = wp.word_id AND wp.game_type = ?
      WHERE (wp.status IS NULL OR wp.status != 'mastered')
        AND (wp.next_review_at IS NULL OR wp.next_review_at <= ?)
        AND w.word = UPPER(w.word)
      ORDER BY COALESCE(wp.next_review_at, 0) ASC
      LIMIT ?
    ''', [gameType, nowMs, limit]);
  }
}
