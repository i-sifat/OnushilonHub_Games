import 'package:sqflite/sqflite.dart';
import 'database_service.dart';

/// F-01: Spaced Repetition System (SM-2) schema migration.
///
/// Adds `next_review_at INTEGER` and `ease_factor REAL` to `word_progress`.
/// Both columns are nullable: NULL means the word has never been reviewed
/// and is treated as immediately due (eligible for any session).
///
/// Call [F01SrsMigration.run] once from [DatabaseService._ensureUserTables]
/// or on a versioned database upgrade.
extension F01SrsMigration on DatabaseService {
  /// Idempotently adds the two SM-2 columns to `word_progress`.
  Future<void> applyF01SrsMigration() async {
    try {
      await db.execute(
        'ALTER TABLE word_progress ADD COLUMN next_review_at INTEGER',
      );
    } on DatabaseException catch (_) {/* column already exists */}

    try {
      await db.execute(
        'ALTER TABLE word_progress ADD COLUMN ease_factor REAL',
      );
    } on DatabaseException catch (_) {/* column already exists */}
  }
}
