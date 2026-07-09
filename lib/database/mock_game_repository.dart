import '../core/models/definition_model.dart';
import '../core/models/ipa_model.dart';
import '../core/models/quote_model.dart';
import '../core/models/user_progress_model.dart';
import 'database_service.dart' show WordRow;
import 'game_data_repository.dart';
import 'i_game_repository.dart';

/// A-03: In-memory mock implementing [IGameRepository].
///
/// Suitable for unit tests and widget tests. Every method returns an empty
/// list / no-op by default. Tests can override individual methods by
/// extending this class.
class MockGameRepository implements IGameRepository {
  @override
  Future<List<IpaModel>> getRandomIpaEntries({required int count}) async => [];

  @override
  Future<List<DefinitionModel>> getRandomDefinitionEntries({required int count}) async => [];

  @override
  Future<List<DefinitionModel>> getDefinitionDistractorPool({required int limit}) async => [];

  @override
  Future<List<DefinitionModel>> getSynonymDistractorPool({required int limit}) async => [];

  @override
  Future<List<DefinitionModel>> getAntonymDistractorPool({required int limit}) async => [];

  @override
  Future<List<ResolvedSynonymAntonymQuestion>> getRandomSynonymQuestions({required int count}) async => [];

  @override
  Future<List<ResolvedSynonymAntonymQuestion>> getRandomAntonymQuestions({required int count}) async => [];

  @override
  Future<List<ResolvedWhoseQuoteQuestion>> getRandomWhoseQuoteQuestions({required int count, int? eraId}) async => [];

  @override
  Future<List<Era>> getEras() async => [];

  @override
  Future<List<WordRow>> getEligibleWords({
    required String gameType,
    required int difficulty,
    required int limit,
    bool requiresDefinition = false,
    bool requiresSynonym = false,
    bool requiresAntonym = false,
  }) async => [];

  @override
  Future<List<Map<String, dynamic>>> getMeaningChasePhrases({required int limit}) async => [];

  @override
  Future<Map<String, int>> getWordIdsByLowercase(List<String> words) async => {};

  @override
  Future<int?> getWordIdByLowercase(String word) async => null;

  @override
  Future<void> markWordStatus({
    required int wordId,
    required String gameType,
    required String status,
  }) async {}

  @override
  Future<void> persistSession({
    required GameSessionModel session,
    required int xpEarned,
  }) async {}

  @override
  void clearGameCache() {}

  @override
  void clearCache() {}
}
