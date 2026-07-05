import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database_service.dart';
import '../core/models/user_progress_model.dart';

final wordRepositoryProvider = Provider<WordRepository>((ref) {
  return WordRepository(DatabaseService.instance);
});

class WordRepository {
  final DatabaseService _db;

  WordRepository(this._db);

  Future<List<WordRow>> getEligibleWords({
    required String gameType,
    required int difficulty,
    required int limit,
    bool requiresDefinition = false,
    bool requiresSynonym = false,
    bool requiresAntonym = false,
  }) {
    return _db.getEligibleWords(
      gameType: gameType,
      difficulty: difficulty,
      limit: limit,
      requiresDefinition: requiresDefinition,
      requiresSynonym: requiresSynonym,
      requiresAntonym: requiresAntonym,
    );
  }

  Future<WordRow?> getDailyWord() => _db.getDailyWord();

  Future<void> markMastered(int wordId, String gameType) =>
      _db.markWordStatus(wordId: wordId, gameType: gameType, status: 'mastered');

  Future<void> markMistake(int wordId, String gameType) =>
      _db.markWordStatus(wordId: wordId, gameType: gameType, status: 'mistake');

  Future<Map<String, int>> getProgressCounts(String gameType) =>
      _db.getWordProgressCounts(gameType: gameType);

  Future<Map<String, Map<String, int>>> getAllProgressCounts() =>
      _db.getAllGameProgressCounts();

  Future<int> getEligibleCount({
    required String gameType,
    required int difficulty,
  }) =>
      _db.getEligibleWordCount(gameType: gameType, difficulty: difficulty);
}

final userProgressRepositoryProvider = Provider<UserProgressRepository>((ref) {
  return UserProgressRepository(DatabaseService.instance);
});

class UserProgressRepository {
  final DatabaseService _db;

  UserProgressRepository(this._db);

  Future<UserProgressModel> get() => _db.getUserProgress();

  Future<void> addXp(int xp) => _db.addXp(xp);

  Future<void> save(UserProgressModel model) => _db.updateUserProgress(model);

  Future<void> saveSession(GameSessionModel session) =>
      _db.saveGameSession(session);

  /// Returns the [limit] most recent sessions (default 200).
  Future<List<GameSessionModel>> getSessions({
    String? gameType,
    int limit = 200,
  }) =>
      _db.getGameSessions(gameType: gameType, limit: limit);

  Future<Map<String, dynamic>> getProfileStats() => _db.getProfileStats();

  Future<bool> hasPlayedGame(String gameType) => _db.hasPlayedGame(gameType);
}
