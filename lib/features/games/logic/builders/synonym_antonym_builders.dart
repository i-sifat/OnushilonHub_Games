import 'dart:math';

import '../../../../core/models/game_config.dart';
import '../../../../database/i_game_repository.dart';
import '../game_rules.dart';
import 'mcq_question.dart';
import 'mcq_question_builder.dart';

/// Builds synonym OR antonym questions. Discriminated by [isAntonym] so the
/// same code path produces both, with no duplication.
///
/// A-03: Builder now depends on [IGameRepository], not the concrete
/// [GameDataRepository], making it unit-testable via [MockGameRepository].
///
/// G-05: Uses independent distractor pools (no mastery filter) for wrong-answer
/// options, preventing advanced players from seeing a shrinking distractor set
/// as they master more words.
class SynonymAntonymBuilder extends McqQuestionBuilder {
  final IGameRepository repo;
  final bool isAntonym;

  const SynonymAntonymBuilder(this.repo, {required this.isAntonym});

  @override
  Future<List<McqQuestion>> build(GameConfig config) async {
    final rng = Random();
    final count = resolveQuestionCount(config);
    final rel = isAntonym ? 'antonym' : 'synonym';

    // Fetch questions (word + correct answer + all valid answers).
    final resolved = isAntonym
        ? await repo.getRandomAntonymQuestions(count: count)
        : await repo.getRandomSynonymQuestions(count: count);

    if (resolved.isEmpty) return [];

    // G-05: Fetch independent distractor pool — no mastery filter.
    // This ensures advanced players who've mastered many words still
    // get full, plausible MCQ options.
    final distractorPool = isAntonym
        ? await repo.getAntonymDistractorPool(limit: 200)
        : await repo.getSynonymDistractorPool(limit: 200);

    // Extract word strings from DefinitionModel pool for comparison.
    final poolWords = distractorPool.map((d) => d.word).toList();

    // Resolve wordIds in a single batch call for mastery tracking.
    final wordIdMap = await repo
        .getWordIdsByLowercase(resolved.map((q) => q.word).toList());

    // Session-wide correct answers — prevents a correct answer for one question
    // from appearing as a distractor in another (SA2 dedup pattern).
    final sessionCorrects = resolved.expand((q) => q.allCorrect).toSet();

    final out = <McqQuestion>[];
    for (final q in resolved) {
      // Filter pool: exclude all correct answers for this word and any
      // session-correct to prevent cross-question leakage.
      final validDistractors = poolWords
          .where((w) =>
              !q.allCorrect.contains(w) && !sessionCorrects.contains(w))
          .toList()
        ..shuffle(rng);

      List<String> options;
      if (validDistractors.length >= GameRules.minDistractorsRequired) {
        // G-05: Use independent pool distractors.
        options = [
          q.correctAnswer,
          ...validDistractors.take(GameRules.mcqOptionCount - 1),
        ]..shuffle(rng);
      } else {
        // Fallback: use pre-built options from the question object.
        options = q.options.isNotEmpty
            ? q.options
            : [q.correctAnswer, ...validDistractors];
      }

      out.add(McqQuestion(
        prompt: q.word,
        promptSubtitle: 'Choose the $rel',
        options: options,
        correctAnswer: q.correctAnswer,
        allCorrectAnswers: q.allCorrect,
        questionText: 'What is a $rel of "${q.word}"?',
        wordId: wordIdMap[q.word.toLowerCase()],
      ));
    }

    return out;
  }
}

class SynonymMatchBuilder extends SynonymAntonymBuilder {
  const SynonymMatchBuilder(super.repo) : super(isAntonym: false);
}

class AntonymMatchBuilder extends SynonymAntonymBuilder {
  const AntonymMatchBuilder(super.repo) : super(isAntonym: true);
}
