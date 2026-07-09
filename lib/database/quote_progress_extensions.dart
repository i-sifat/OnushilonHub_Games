import 'package:sqflite/sqflite.dart';
import 'database_service.dart';

/// G-12: Quote mastery tracking.
///
/// Extends [DatabaseService] with quote-progress management.
/// The table is created lazily on first use — no _kAssetDbVersion bump needed.
///
/// A quote is considered 'mastered' after being seen 5 times; it is then
/// excluded from future sessions until the available pool is exhausted.
extension QuoteProgressExtensions on DatabaseService {
  /// Creates the quote_progress table + index if they do not yet exist.
  /// Idempotent — safe to call on every access.
  Future<void> _ensureQuoteProgressTable() async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS quote_progress (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        quote_id     INTEGER NOT NULL UNIQUE,
        status       TEXT NOT NULL DEFAULT 'seen',
        seen_count   INTEGER NOT NULL DEFAULT 0,
        last_seen_at INTEGER
      )
    ''');
    try {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_qp_quote ON quote_progress(quote_id, status)',
      );
    } on DatabaseException catch (_) {
      // Index already exists — ignore.
    }
  }

  /// Returns the set of [quotes_data.id] values the player has mastered
  /// (seen 5+ times).
  Future<Set<int>> getMasteredQuoteIds() async {
    await _ensureQuoteProgressTable();
    final rows = await db.rawQuery(
      "SELECT quote_id FROM quote_progress WHERE status = 'mastered'",
    );
    return {for (final r in rows) r['quote_id'] as int};
  }

  /// Records a quote as shown in a session.
  /// Promotes to 'mastered' once seen 5 times.
  Future<void> recordQuoteSeen(int quoteId) async {
    await _ensureQuoteProgressTable();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.execute('''
      INSERT INTO quote_progress (quote_id, seen_count, last_seen_at)
      VALUES (?, 1, ?)
      ON CONFLICT(quote_id) DO UPDATE SET
        seen_count   = seen_count + 1,
        last_seen_at = ?,
        status       = CASE WHEN seen_count + 1 >= 5 THEN 'mastered' ELSE 'seen' END
    ''', [quoteId, now, now]);
  }

  /// Resets all quote-progress records (used by reset-all-progress flow).
  Future<void> resetQuoteProgress() async {
    await _ensureQuoteProgressTable();
    await db.delete('quote_progress');
  }
}
