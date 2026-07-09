import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'database_service.dart';
import '../core/models/user_progress_model.dart';

final progressDbServiceProvider = Provider((ref) {
  return ProgressDbService(DatabaseService.instance);
});

/// Handles word_progress and user_progress DB operations.
///
/// Extracted from DatabaseService (A-01).
class ProgressDbService {
  final DatabaseService _db;

  const ProgressDbService(this._db);

  // ── Word progress ─────────────────────────────────────────────────────────

  Future<void> markWordStatus({
    required int wordId,
    required String gameType,
    required String status,
  }) async {
    await _db.db.insert(
      'word_progress',
      {
        'word_id': wordId,
        'game_type': gameType,
        'status': status,
        'attempts': 1,
        'last_attempted': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, int>> getWordProgressCounts({
    required String gameType,
  }) async {
    final rows = await _db.db.rawQuery('''
      SELECT status, COUNT(*) AS cnt
      FROM word_progress
      WHERE game_type = ?
      GROUP BY status
    ''', [gameType]);
    return {for (final r in rows) r['status'] as String: r['cnt'] as int};
  }

  Future<Map<String, Map<String, int>>> getAllGameProgressCounts() async {
    final rows = await _db.db.rawQuery('''
      SELECT game_type, status, COUNT(*) AS cnt
      FROM word_progress
      GROUP BY game_type, status
    ''');
    final result = <String, Map<String, int>>{};
    for (final r in rows) {
      final gt = r['game_type'] as String;
      final st = r['status'] as String;
      final cnt = r['cnt'] as int;
      result.putIfAbsent(gt, () => {})[st] = cnt;
    }
    return result;
  }

  // ── User progress ─────────────────────────────────────────────────────────

  Future<UserProgressModel> getUserProgress() async {
    final rows = await _db.db.query('user_progress', where: 'id = 1');
    if (rows.isEmpty) return const UserProgressModel();
    return UserProgressModel.fromDb(rows.first);
  }

  Future<void> addXp(int xp) async {
    await _db.db.rawUpdate(
      'UPDATE user_progress SET total_xp = total_xp + ? WHERE id = 1',
      [xp],
    );
  }

  Future<void> updateUserProgress(UserProgressModel model) async {
    await _db.db.update(
      'user_progress',
      model.toDb(),
      where: 'id = 1',
    );
  }

  /// Updates streak: +1 if played yesterday, resets to 1 otherwise.
  /// No-op if already updated today.
  Future<void> updateStreak() async {
    final rows = await _db.db.query(
      'user_progress',
      columns: ['streak', 'last_played_at'],
      where: 'id = 1',
    );
    if (rows.isEmpty) return;
    final row = rows.first;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastMs = row['last_played_at'] as int?;
    final lastDay = lastMs != null
        ? (DateTime.fromMillisecondsSinceEpoch(lastMs)).let(
            (d) => DateTime(d.year, d.month, d.day))
        : null;
    if (lastDay == today) return;
    final streak = row['streak'] as int;
    final yesterday = today.subtract(const Duration(days: 1));
    final newStreak = (lastDay == yesterday) ? streak + 1 : 1;
    await _db.db.update(
      'user_progress',
      {'streak': newStreak, 'last_played_at': today.millisecondsSinceEpoch},
      where: 'id = 1',
    );
  }
}

extension _Let<T> on T {
  R let<R>(R Function(T) block) => block(this);
}
