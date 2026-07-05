import 'dart:math';
import '../../../../core/models/game_config.dart';
import '../../../../database/game_data_repository.dart';
import '../game_rules.dart';
import 'mcq_question.dart';
import 'mcq_question_builder.dart';

class SpeedRacingBuilder extends McqQuestionBuilder {
  final GameDataRepository repo;
  const SpeedRacingBuilder(this.repo);

  @override
  Future<List<McqQuestion>> build(GameConfig config) async {
    final count = resolveQuestionCount(config);

    final words = await repo.getEligibleWords(
      gameType: config.gameType.dbKey,
      difficulty: config.difficulty,
      limit: count,
      requiresDefinition: true,
    );
    final pool = await repo.getEligibleWords(
      gameType: 'speed_racing',
      difficulty: 0,
      limit: (count * GameRules.distractorOverfetchFactor).clamp(60, 300),
      requiresDefinition: true,
    );
    final rng = Random();

    return words
        .map((word) {
          final correct = word.definition;
          if (correct.isEmpty) return null;

          final distractors = pool
              .where((w) => w.id != word.id)
              .map((w) => w.definition)
              .where((d) => d.isNotEmpty && d != correct)
              .toSet()
              .toList()
            ..shuffle(rng);
          if (distractors.length < GameRules.minDistractorsRequired) return null;

          final options = [correct, ...distractors.take(3)]..shuffle(rng);
          return McqQuestion(
            prompt: word.word,
            promptSubtitle: 'What does this mean?',
            options: options,
            correctAnswer: correct,
            questionText: 'Meaning of "${word.word}"',
            wordId: word.id,
          );
        })
        .whereType<McqQuestion>()
        .toList();
  }
}
