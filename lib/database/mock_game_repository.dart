import '../core/models/definition_model.dart';
import '../core/models/ipa_model.dart';
import '../core/models/quote_model.dart';
import '../core/models/user_progress_model.dart';
import 'database_service.dart' show WordRow;
import 'game_data_repository.dart'
    show ResolvedSynonymAntonymQuestion, ResolvedWhoseQuoteQuestion;
import 'i_game_repository.dart';

/// A-03: In-memory [IGameRepository] for unit tests and widget previews.
///
/// Returns minimal but structurally valid data for every method so builders
/// can exercise their full logic without needing a real SQLite database.
class MockGameRepository implements IGameRepository {
  // ── IPA ──────────────────────────────────────────────────────────────────
  @override
  Future<List<IpaModel>> getRandomIpaEntries({required int count}) async {
    return List.generate(count,
        (i) => IpaModel.fromEntry('WORD${i + 1}', '/w\u025c\u02d0d ${i + 1}/'));
  }

  // ── Definitions ──────────────────────────────────────────────────────────
  @override
  Future<List<DefinitionModel>> getRandomDefinitionEntries(
      {required int count}) async {
    return List.generate(
        count,
        (i) => DefinitionModel(
              word: 'WORD${i + 1}',
              partOfSpeech: 'noun',
              definition: 'Mock definition of word ${i + 1}.',
            ));
  }

  @override
  Future<List<DefinitionModel>> getDefinitionDistractorPool(
      {required int limit}) async {
    return List.generate(
        limit,
        (i) => DefinitionModel(
              word: 'DISTRACTOR${i + 1}',
              partOfSpeech: 'noun',
              definition: 'Mock distractor definition ${i + 1}.',
            ));
  }

  // ── G-05: Distractor pools (return DefinitionModel) ─────────────────────
  @override
  Future<List<DefinitionModel>> getSynonymDistractorPool(
      {required int limit}) async {
    return List.generate(
        limit,
        (i) => DefinitionModel(
              word: 'SYN_DISTRACTOR${i + 1}',
              partOfSpeech: '',
              definition: 'Mock synonym distractor ${i + 1}.',
            ));
  }

  @override
  Future<List<DefinitionModel>> getAntonymDistractorPool(
      {required int limit}) async {
    return List.generate(
        limit,
        (i) => DefinitionModel(
              word: 'ANT_DISTRACTOR${i + 1}',
              partOfSpeech: '',
              definition: 'Mock antonym distractor ${i + 1}.',
            ));
  }

  // ── Synonyms / Antonyms ───────────────────────────────────────────────────
  @override
  Future<List<ResolvedSynonymAntonymQuestion>> getRandomSynonymQuestions(
      {required int count}) async {
    return List.generate(
        count,
        (i) => ResolvedSynonymAntonymQuestion(
              word: 'WORD${i + 1}',
              correctAnswer: 'happy',
              options: const ['happy', 'sad', 'angry', 'calm'],
              allCorrect: const ['happy', 'glad', 'joyful'],
            ));
  }

  @override
  Future<List<ResolvedSynonymAntonymQuestion>> getRandomAntonymQuestions(
      {required int count}) async {
    return List.generate(
        count,
        (i) => ResolvedSynonymAntonymQuestion(
              word: 'WORD${i + 1}',
              correctAnswer: 'sad',
              options: const ['sad', 'happy', 'angry', 'calm'],
              allCorrect: const ['sad', 'unhappy'],
            ));
  }

  // ── Quotes ────────────────────────────────────────────────────────────────
  @override
  Future<List<ResolvedWhoseQuoteQuestion>> getRandomWhoseQuoteQuestions({
    required int count,
    int? eraId,
  }) async {
    return List.generate(
        count,
        (i) => ResolvedWhoseQuoteQuestion(
              quoteText: 'To be or not to be. (${i + 1})',
              correctAuthor: 'Shakespeare',
              eraName: 'Elizabethan',
              options: const ['Shakespeare', 'Dickens', 'Austen', 'Orwell'],
            ));
  }

  @override
  Future<List<QuoteEraModel>> getEras() async {
    return [
      QuoteEraModel(
        id: 1,
        name: 'Elizabethan',
        slug: 'elizabethan',
        startYear: 1558,
        endYear: 1603,
        description: 'Mock era',
        keyFeatures: const [],
        tags: const [],
      ),
      QuoteEraModel(
        id: 2,
        name: 'Victorian',
        slug: 'victorian',
        startYear: 1837,
        endYear: 1901,
        description: 'Mock era',
        keyFeatures: const [],
        tags: const [],
      ),
      QuoteEraModel(
        id: 3,
        name: 'Modern',
        slug: 'modern',
        startYear: 1900,
        description: 'Mock era',
        keyFeatures: const [],
        tags: const [],
      ),
    ];
  }

  // ── Word eligibility ──────────────────────────────────────────────────────
  @override
  Future<List<WordRow>> getEligibleWords({
    required String gameType,
    required int difficulty,
    required int limit,
    bool requiresDefinition = false,
    bool requiresSynonym = false,
    bool requiresAntonym = false,
  }) async {
    return List.generate(
        limit,
        (i) => WordRow(
              id: i + 1,
              word: 'WORD${i + 1}',
              definition: 'Mock definition ${i + 1}.',
              pos: 'noun',
              synonyms: const ['mock_syn_a', 'mock_syn_b', 'mock_syn_c'],
              antonyms: const ['mock_ant_a', 'mock_ant_b', 'mock_ant_c'],
              banglaMeaning: 'mock_bn_${i + 1}',
              example: '',
              difficulty: difficulty > 0 ? difficulty : 1,
              supportedGames: [
                gameType,
                'meaning_chase',
                'true_false',
                'speed_racing',
                'definition_match',
                'synonym_match',
                'antonym_match',
              ],
            ));
  }

  @override
  Future<List<Map<String, dynamic>>> getMeaningChasePhrases(
      {required int limit}) async {
    return List.generate(limit,
        (i) => {'en': 'PHRASE${i + 1}', 'bn': 'mock_bn_${i + 1}', 'id': i + 1});
  }

  @override
  Future<Map<String, int?>> getWordIdsByLowercase(List<String> words) async {
    return {
      for (int i = 0; i < words.length; i++) words[i].toLowerCase(): i + 1
    };
  }

  @override
  Future<int?> getWordIdByLowercase(String word) async {
    return word.hashCode.abs() % 50000 + 1;
  }

  // ── Writes ────────────────────────────────────────────────────────────────
  @override
  Future<void> markWordStatus({
    required int wordId,
    required String gameType,
    required String status,
  }) async {
    // No-op in mock
  }

  @override
  Future<void> persistSession({
    required GameSessionModel session,
    required int xpEarned,
  }) async {
    // No-op in mock
  }

  // ── Cache ─────────────────────────────────────────────────────────────────
  @override
  void clearGameCache() {}

  @override
  void clearCache() {}
}
