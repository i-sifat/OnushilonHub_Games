import 'database_service.dart' show WordRow;
import 'game_data_repository.dart'
    show ResolvedSynonymAntonymQuestion, ResolvedWhoseQuoteQuestion, Era;
import '../core/models/definition_model.dart';
import '../core/models/ipa_model.dart';
import '../core/models/user_progress_model.dart';

/// Abstract data-access contract for every game builder + controller.
///
/// Builders and notifiers depend on this interface, never on the concrete
/// [GameDataRepository]. That way the data layer can be swapped (mock for
/// tests, remote-backed implementation for multiplayer, …) without touching
/// gameplay logic.
abstract class IGameRepository {
  // ── Question content ──────────────────────────────────────────────────────
  Future<List<IpaModel>> getRandomIpaEntries({required int count});
  Future<List<DefinitionModel>> getRandomDefinitionEntries(
      {required int count});

  /// DM2: Independent distractor pool for Definition Match — never cached,
  /// never mastery-filtered, always a fresh random draw from the full DB.
  Future<List<DefinitionModel>> getDefinitionDistractorPool(
      {required int limit});

  /// G-05: Independent distractor pool for Synonym Match — no mastery filter,
  /// draws from the complete synonyms vocabulary regardless of player progress.
  Future<List<DefinitionModel>> getSynonymDistractorPool(
      {required int limit});

  /// G-05: Independent distractor pool for Antonym Match — no mastery filter,
  /// draws from the complete antonyms vocabulary regardless of player progress.
  Future<List<DefinitionModel>> getAntonymDistractorPool(
      {required int limit});

  Future<List<ResolvedSynonymAntonymQuestion>> getRandomSynonymQuestions(
      {required int count});
  Future<List<ResolvedSynonymAntonymQuestion>> getRandomAntonymQuestions(
      {required int count});
  Future<List<ResolvedWhoseQuoteQuestion>> getRandomWhoseQuoteQuestions(
      {required int count, int? eraId});
  Future<List<Era>> getEras();

  // ── Word data ────────────────────────────────────────────────────────────
  Future<List<WordRow>> getEligibleWords({
    required String gameType,
    required int difficulty,
    required int limit,
    bool requiresDefinition,
    bool requiresSynonym,
    bool requiresAntonym,
  });
  Future<List<Map<String, dynamic>>> getMeaningChasePhrases(
      {required int limit});
  Future<Map<String, int?>> getWordIdsByLowercase(List<String> words);
  Future<int?> getWordIdByLowercase(String word);

  // ── Writes ────────────────────────────────────────────────────────────────
  Future<void> markWordStatus({
    required int wordId,
    required String gameType,
    required String status,
  });
  Future<void> persistSession({
    required GameSessionModel session,
    required int xpEarned,
  });

  // ── Cache ─────────────────────────────────────────────────────────────────
  void clearGameCache();
  void clearCache();
}
