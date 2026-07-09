import 'package:sqflite/sqflite.dart';
import 'database_service.dart';

/// G-12: Quote mastery tracking schema migration.
///
/// Adds the `quote_progress` table keyed on `quote_id`.
/// [getRandomWhoseQuoteQuestions] in [GameDataRepository] filters out rows
/// where `status = 'mastered'` once this table exists.
extension G12QuoteProgressMigration on DatabaseService {
  /// Creates the `quote_progress` table if it does not already exist.
  Future<void> applyG12QuoteProgressMigration() async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS quote_progress (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        quote_id   INTEGER NOT NULL UNIQUE,
        status     TEXT NOT NULL DEFAULT 'new',
        attempts   INTEGER NOT NULL DEFAULT 0,
        last_attempted INTEGER
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_qp_status ON quote_progress(status)',
    );
  }

  /// Marks a quote as mastered.
  Future<void> markQuoteMastered(int quoteId) async {
    await db.insert(
      'quote_progress',
      {
        'quote_id': quoteId,
        'status': 'mastered',
        'attempts': 1,
        'last_attempted': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
