import 'dart:math';

import '../../../../core/models/game_config.dart';
import '../../../../database/i_game_repository.dart';
import '../game_rules.dart';
import 'mcq_question.dart';
import 'mcq_question_builder.dart';

/// A-03: now accepts [IGameRepository].
class TrueFalseBuilder extends McqQuestionBuilder {
  final IGameRepository repo;

  const TrueFalseBuilder(this.repo);

  static const int _maxDefLength = 120;

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
    final usedDecoys = <String>{};
    final out = <McqQuestion>[];
    for (final word in words) {
      if (out.length >= count) break;
      if (word.definition.isEmpty || word.definition.length > _maxDefLength) continue;
      final presentTrue = rng.nextBool();
      String presentedDefinition;
      String correctAnswer;
      if (presentTrue) {
        presentedDefinition = word.definition;
        correctAnswer = 'True';
      } else {
        final decoys = pool
            .where((w) =>
                w.id != word.id &&
                w.definition.isNotEmpty &&
                w.definition != word.definition &&
                w.definition.length <= _maxDefLength &&
                !usedDecoys.contains(w.definition))
            .toList()
          ..shuffle(rng);
        if (decoys.isEmpty) continue;
        presentedDefinition = decoys.first.definition;
        correctAnswer = 'False';
        usedDecoys.add(presentedDefinition);
      }
      out.add(McqQuestion(
        prompt: word.word,
        promptSubtitle: 'Is this the correct definition?',
        options: const ['True', 'False'],
        correctAnswer: correctAnswer,
        questionText: '"$presentedDefinition"',
        wordId: word.id,
        correctDefinition: presentTrue ? null : word.definition,
      ));
    }
    return out;
  }
}
