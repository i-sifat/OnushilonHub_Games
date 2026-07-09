import 'package:sqflite/sqflite.dart';

import 'database_service.dart';

/// DB-06 — Configurable daily goal.
///
/// Extends [DatabaseService] with methods to read and persist the user's
/// configured daily-goal session count.
///
/// Existing installs may not yet have the `daily_goal` column in
/// `user_progress`.  Both [getDailyGoal] and [updateDailyGoal] handle this
/// gracefully: [getDailyGoal] catches the schema error and returns the
/// default; [updateDailyGoal] runs an idempotent `ALTER TABLE` migration
/// before writing.
extension DailyGoalExtensions on DatabaseService {
  /// Returns the user's configured daily-goal (1–20, default 5).
  ///
  /// Safe on legacy installs that pre-date the `daily_goal` column —
  /// catches [DatabaseException] and returns 5.
  Future<int> getDailyGoal() async {
    try {
      final rows = await db.rawQuery(
        'SELECT daily_goal FROM user_progress WHERE id = 1',
      );
      if (rows.isEmpty) return 5;
      return (rows.first['daily_goal'] as int?) ?? 5;
    } on DatabaseException catch (_) {
      // Column does not yet exist on this install.
      return 5;
    }
  }

  /// Persists [goal] as the user's daily-goal session count.
  ///
  /// Runs an idempotent `ALTER TABLE` migration first so existing installs
  /// that pre-date DB-06 are upgraded transparently.
  Future<void> updateDailyGoal(int goal) async {
    assert(goal >= 1 && goal <= 20, 'daily_goal must be 1–20');
    // Add column if it does not yet exist (idempotent — no-op on re-run).
    try {
      await db.execute(
        'ALTER TABLE user_progress ADD COLUMN daily_goal INTEGER NOT NULL DEFAULT 5',
      );
    } on DatabaseException catch (_) {
      // Column already exists; safe to ignore.
    }
    await db.update(
      'user_progress',
      {'daily_goal': goal},
      where: 'id = 1',
    );
  }
}
