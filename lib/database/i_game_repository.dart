import 'database_service.dart' show WordRow;
import 'game_data_repository.dart';
import '../core/models/definition_model.dart';
import '../core/models/ipa_model.dart';
import '../core/models/quote_model.dart';
import '../core/models/user_progress_model.dart';

/// Abstract data-access contract for every game builder + controller.
///
/// A-03: 100% of methods used by builders are now declared here so the
/// concrete [GameDataRepository] and [MockGameRepository] both satisfy
/// the interface. Builders depend on [IGameRepository], never on the
/// concrete type, enabling full testability without a real SQLite DB.
abstract class IGameRepository {
  // ── Question content ────────────────────────────────────────────────

  Future<List<IpaModel>> getRandomIpaEntries({required int count});
  Future<List<DefinitionModel>> getRandomDefinitionEntries({required int count});

  /// DM2: Independent distractor pool for Definition Match.
  Future<List<DefinitionModel>> getDefinitionDistractorPool({required int limit});

  /// G-05: Independent synonym distractor pool — no mastery filter, limit 200.
  /// Prevents advanced players from encountering a shrinking distractor pool.
  Future<List<DefinitionModel>> getSynonymDistractorPool({required int limit});

  /// G-05: Independent antonym distractor pool — no mastery filter, limit 200.
  Future<List<DefinitionModel>> getAntonymDistractorPool({required int limit});

  Future<List<ResolvedSynonymAntonymQuestion>> getRandomSynonymQuestions(
      {required int count});
  Future<List<ResolvedSynonymAntonymQuestion>> getRandomAntonymQuestions(
      {required int count});
  Future<List<ResolvedWhoseQuoteQuestion>> getRandomWhoseQuoteQuestions(
      {required int count, int? eraId});
  Future<List<Era>> getEras();

  // ── Word data ────────────────────────────────────────────────────────

  Future<List<WordRow>> getEligibleWords({
    required String gameType,
    required int difficulty,
    required int limit,
    bool requiresDefinition = false,
    bool requiresSynonym = false,
    bool requiresAntonym = false,
  });
  Future<List<Map<String, dynamic>>> getMeaningChasePhrases({required int limit});
  Future<Map<String, int>> getWordIdsByLowercase(List<String> words);
  Future<int?> getWordIdByLowercase(String word);

  // ── Writes ────────────────────────────────────────────────────────────

  Future<void> markWordStatus({
    required int wordId,
    required String gameType,
    required String status,
  });
  Future<void> persistSession({
    required GameSessionModel session,
    required int xpEarned,
  });

  // ── Cache ──────────────────────────────────────────────────────────────

  void clearGameCache();
  void clearCache();
}
