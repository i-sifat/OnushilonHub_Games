import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database_service.dart';
import 'word_db_service.dart';
import 'progress_db_service.dart';
import 'session_db_service.dart';
import '../core/models/user_progress_model.dart';

final wordRepositoryProvider = Provider((ref) {
  return WordRepository(
    ref.watch(wordDbServiceProvider),
    ref.watch(progressDbServiceProvider),
  );
});

/// Thin facade that exposes word-eligibility operations to UI/game layers.
///
/// Updated (A-01) to delegate to [WordDbService] + [ProgressDbService]
/// instead of calling [DatabaseService] domain methods directly.
class WordRepository {
  final WordDbService _words;
  final ProgressDbService _progress;

  const WordRepository(this._words, this._progress);

  Future<List<WordRow>> getEligibleWords({
    required String gameType,
    required int difficulty,
    required int limit,
    bool requiresDefinition = false,
    bool requiresSynonym = false,
    bool requiresAntonym = false,
  }) =>
      _words.getEligibleWords(
        gameType: gameType,
        difficulty: difficulty,
        limit: limit,
        requiresDefinition: requiresDefinition,
        requiresSynonym: requiresSynonym,
        requiresAntonym: requiresAntonym,
      );

  Future<WordRow?> getDailyWord() => _words.getDailyWord();

  Future<void> markMastered(int wordId, String gameType) =>
      _progress.markWordStatus(wordId: wordId, gameType: gameType, status: 'mastered');

  Future<void> markMistake(int wordId, String gameType) =>
      _progress.markWordStatus(wordId: wordId, gameType: gameType, status: 'mistake');

  Future<Map<String, int>> getProgressCounts(String gameType) =>
      _progress.getWordProgressCounts(gameType: gameType);

  Future<Map<String, Map<String, int>>> getAllProgressCounts() =>
      _progress.getAllGameProgressCounts();

  Future<int> getEligibleCount({
    required String gameType,
    required int difficulty,
  }) =>
      _words.getEligibleWordCount(gameType: gameType, difficulty: difficulty);
}

final userProgressRepositoryProvider = Provider((ref) {
  return UserProgressRepository(
    ref.watch(progressDbServiceProvider),
    ref.watch(sessionDbServiceProvider),
  );
});

/// Facade for user-progress and session operations.
///
/// Updated (A-01) to delegate to [ProgressDbService] + [SessionDbService].
class UserProgressRepository {
  final ProgressDbService _progress;
  final SessionDbService _session;

  const UserProgressRepository(this._progress, this._session);

  Future<UserProgressModel> get() => _progress.getUserProgress();

  Future<void> addXp(int xp) => _progress.addXp(xp);

  Future<void> save(UserProgressModel model) =>
      _progress.updateUserProgress(model);

  Future<void> saveSession(GameSessionModel session) =>
      _session.saveGameSession(session);

  /// Returns the [limit] most recent sessions (default 200).
  Future<List<GameSessionModel>> getSessions({
    String? gameType,
    int limit = 200,
  }) =>
      _session.getGameSessions(gameType: gameType, limit: limit);

  Future<Map<String, dynamic>> getProfileStats() =>
      _session.getProfileStats();

  Future<bool> hasPlayedGame(String gameType) =>
      _session.hasPlayedGame(gameType);
}
