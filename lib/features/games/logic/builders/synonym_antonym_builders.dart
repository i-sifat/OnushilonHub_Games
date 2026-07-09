import 'dart:math';

import '../../../../core/models/game_config.dart';
import '../../../../database/i_game_repository.dart';
import '../game_rules.dart';
import 'mcq_question.dart';
import 'mcq_question_builder.dart';

/// A-03: now accepts [IGameRepository].
/// G-05: independent (non-mastery-filtered) distractor pool prevents advanced
/// players from encountering a shrinking set of synonym/antonym distractors.
class SynonymAntonymBuilder extends McqQuestionBuilder {
  final IGameRepository repo;
  final bool isAntonym;

  const SynonymAntonymBuilder(this.repo, {required this.isAntonym});

  @override
  Future<List<McqQuestion>> build(GameConfig config) async {
    final rng = Random();
    final count = resolveQuestionCount(config);
    final rel = isAntonym ? 'antonym' : 'synonym';

    final resolved = isAntonym
        ? await repo.getRandomAntonymQuestions(count: count)
        : await repo.getRandomSynonymQuestions(count: count);
    if (resolved.isEmpty) return [];

    // G-05: fetch an independent (non-mastery-filtered) distractor pool so
    // advanced players who have mastered many words still get a full set of
    // plausible wrong options. Mirrors the getDefinitionDistractorPool
    // pattern used by DefinitionMatchBuilder (DM2).
    final distractorPool = isAntonym
        ? await repo.getAntonymDistractorPool(
            limit: GameRules.definitionDistractorPoolLimit)
        : await repo.getSynonymDistractorPool(
            limit: GameRules.definitionDistractorPoolLimit);

    final wordIdMap = await repo
        .getWordIdsByLowercase(resolved.map((q) => q.word).toList());

    // Session-wide correct-answer set — mirrors SA2: prevents a correct answer
    // from one question appearing as a distractor for another.
    final sessionCorrects = resolved.map((q) => q.correctAnswer).toSet();

    final out = <McqQuestion>[];
    for (final q in resolved) {
      // Build distractors from the independent pool (using the word field).
      // Exclude: the correct answer, all valid syn/ant for this word,
      //          and session-wide correct answers.
      final distractors = distractorPool
          .map((e) => e.word)
          .where((w) =>
              w != q.correctAnswer &&
              !q.allCorrect.contains(w) &&
              !sessionCorrects.contains(w))
          .toSet()
          .toList()
        ..shuffle(rng);

      // Fallback to pre-resolved options if independent pool is too thin
      // (e.g. pool entries all filtered out as valid answers).
      final options = distractors.length >= GameRules.minDistractorsRequired
          ? ([
              q.correctAnswer,
              ...distractors.take(GameRules.mcqOptionCount - 1),
            ]..shuffle(rng))
          : q.options;

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
