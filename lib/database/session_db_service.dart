import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'database_service.dart';
import '../core/models/user_progress_model.dart';

final sessionDbServiceProvider = Provider((ref) {
  return SessionDbService(DatabaseService.instance);
});

/// Handles game_sessions, saved_words, and daily-stats DB operations.
///
/// Extracted from DatabaseService (A-01).
class SessionDbService {
  final DatabaseService _db;

  const SessionDbService(this._db);

  // ── Game sessions ─────────────────────────────────────────────────────────

  Future<void> saveGameSession(GameSessionModel session) async {
    await _db.db.insert('game_sessions', session.toDb());
  }

  Future<List<GameSessionModel>> getGameSessions({
    String? gameType,
    int limit = 200,
  }) async {
    final where = gameType != null ? 'WHERE game_type = ?' : '';
    final args = gameType != null ? [gameType] : <Object?>[];
    final rows = await _db.db.rawQuery(
      'SELECT * FROM game_sessions $where ORDER BY played_at DESC LIMIT $limit',
      args,
    );
    return rows.map(GameSessionModel.fromDb).toList();
  }

  Future<bool> hasPlayedGame(String gameType) async {
    final count = Sqflite.firstIntValue(await _db.db.rawQuery(
      'SELECT COUNT(*) FROM game_sessions WHERE game_type = ?',
      [gameType],
    )) ?? 0;
    return count > 0;
  }

  Future<int> getTodaySessionCount() async {
    final start = DateTime.now().let((n) =>
        DateTime(n.year, n.month, n.day).millisecondsSinceEpoch);
    return Sqflite.firstIntValue(await _db.db.rawQuery(
      'SELECT COUNT(*) FROM game_sessions WHERE played_at >= ?',
      [start],
    )) ?? 0;
  }

  // ── Profile stats ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getProfileStats() async {
    final totalSessions = Sqflite.firstIntValue(await _db.db.rawQuery(
      'SELECT COUNT(*) FROM game_sessions',
    )) ?? 0;
    final totalCorrect = Sqflite.firstIntValue(await _db.db.rawQuery(
      'SELECT SUM(correct_count) FROM game_sessions',
    )) ?? 0;
    final totalWrong = Sqflite.firstIntValue(await _db.db.rawQuery(
      'SELECT SUM(wrong_count) FROM game_sessions',
    )) ?? 0;
    final totalMastered = Sqflite.firstIntValue(await _db.db.rawQuery(
      "SELECT COUNT(*) FROM word_progress WHERE status = 'mastered'",
    )) ?? 0;
    final gameStats = await _db.db.rawQuery('''
      SELECT game_type,
             COUNT(*) as sessions,
             SUM(correct_count) as correct,
             SUM(wrong_count) as wrong,
             SUM(score) as total_score,
             AVG(score) as avg_score
      FROM game_sessions
      GROUP BY game_type
      ORDER BY total_score DESC
    ''');
    return {
      'totalSessions': totalSessions,
      'totalCorrect': totalCorrect,
      'totalWrong': totalWrong,
      'totalMastered': totalMastered,
      'gameStats': gameStats,
    };
  }

  // ── Played game types ─────────────────────────────────────────────────────

  Future<Set<String>> getPlayedGameTypes() async {
    final rows =
        await _db.db.rawQuery('SELECT DISTINCT game_type FROM game_sessions');
    return rows.map((r) => r['game_type'] as String).toSet();
  }

  // ── Saved words ───────────────────────────────────────────────────────────

  Future<void> saveWord(String word, String definition) async {
    await _db.db.insert(
      'saved_words',
      {
        'word': word,
        'definition': definition,
        'saved_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> removeWord(String word) async {
    await _db.db.delete('saved_words', where: 'word = ?', whereArgs: [word]);
  }

  Future<bool> isWordSaved(String word) async {
    final count = Sqflite.firstIntValue(await _db.db.rawQuery(
      'SELECT COUNT(*) FROM saved_words WHERE word = ?',
      [word],
    )) ?? 0;
    return count > 0;
  }

  Future<List<Map<String, Object?>>> getSavedWords() {
    return _db.db.query('saved_words', orderBy: 'saved_at DESC');
  }
}

extension _Let<T> on T {
  R let<R>(R Function(T) block) => block(this);
}
