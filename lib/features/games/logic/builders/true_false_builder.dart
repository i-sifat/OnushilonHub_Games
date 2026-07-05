import 'dart:math';
import '../../../../core/models/game_config.dart';
import '../../../../database/game_data_repository.dart';
import '../game_rules.dart';
import 'mcq_question.dart';
import 'mcq_question_builder.dart';

/// Generates True/False definition questions as MCQ items with options
/// `['True', 'False']`.
///
/// Reliability guarantees:
///   * Every word used has a non-empty definition.
///   * When the question must be false, the decoy definition is taken from
///     a *different* word. If no valid decoy is available the word is
///     skipped — we never present an "incorrect definition" while marking
///     the question as true, and never make up bogus content.
class TrueFalseBuilder extends McqQuestionBuilder {
  final GameDataRepository repo;
  const TrueFalseBuilder(this.repo);

  @override
  Future<List<McqQuestion>> build(GameConfig config) async {
    final count = resolveQuestionCount(config);
    final rng = Random();

    final words = await repo.getEligibleWords(
      gameType: config.gameType.dbKey,
      difficulty: config.difficulty,
      limit: count * 2,
      requiresDefinition: true,
    );
    final pool = await repo.getEligibleWords(
      gameType: 'true_false',
      difficulty: 0,
      limit: (count * GameRules.distractorOverfetchFactor).clamp(60, 300),
      requiresDefinition: true,
    );
    if (words.isEmpty) return [];

    final out = <McqQuestion>[];
    for (final word in words) {
      if (out.length >= count) break;
      if (word.definition.isEmpty) continue;

      final presentTrue = rng.nextBool();
      String presentedDefinition;
      String correctAnswer;

      if (presentTrue) {
        presentedDefinition = word.definition;
        correctAnswer = 'True';
      } else {
        // Find a real definition belonging to another word — never invent one.
        final decoys = pool
            .where((w) =>
                w.id != word.id &&
                w.definition.isNotEmpty &&
                w.definition != word.definition)
            .toList()
          ..shuffle(rng);
        if (decoys.isEmpty) continue;
        presentedDefinition = decoys.first.definition;
        correctAnswer = 'False';
      }

      out.add(McqQuestion(
        prompt: word.word,
        promptSubtitle: presentedDefinition,
        options: const ['True', 'False'],
        correctAnswer: correctAnswer,
        questionText: '"${word.word}" — "$presentedDefinition"',
        wordId: word.id,
      ));
    }
    return out;
  }
}
