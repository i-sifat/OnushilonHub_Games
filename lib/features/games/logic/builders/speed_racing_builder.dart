import 'dart:math';

import '../../../../core/models/game_config.dart';
import '../../../../database/i_game_repository.dart';
import '../game_rules.dart';
import 'mcq_question.dart';
import 'mcq_question_builder.dart';

/// A-03: now accepts [IGameRepository].
class SpeedRacingBuilder extends McqQuestionBuilder {
  final IGameRepository repo;

  const SpeedRacingBuilder(this.repo);

  static const int _maxDefLength = 120;

  @override
  Future<List<McqQuestion>> build(GameConfig config) async {
    final count = resolveQuestionCount(config);
    final words = await repo.getEligibleWords(
      gameType: config.gameType.dbKey,
      difficulty: config.difficulty,
      limit: (count * GameRules.speedRacingOverfetchFactor),
      requiresDefinition: true,
    );
    final pool = await repo.getEligibleWords(
      gameType: 'speed_racing',
      difficulty: 0,
      limit: (count * GameRules.distractorOverfetchFactor)
          .clamp(GameRules.distractorPoolMin, GameRules.distractorPoolMax),
      requiresDefinition: true,
    );
    final rng = Random();
    final sessionCorrects = <String>{};
    final out = <McqQuestion>[];
    for (final word in words) {
      final correct = word.definition;
      if (correct.isEmpty || correct.length > _maxDefLength) continue;
      final distractors = pool
          .where((w) => w.id != word.id)
          .map((w) => w.definition)
          .where((d) => d.isNotEmpty && d != correct && d.length <= _maxDefLength)
          .toSet()
          .toList()
        ..shuffle(rng);
      if (distractors.length < GameRules.minDistractorsRequired) continue;
      final cleanDistractors = distractors.where((d) => !sessionCorrects.contains(d)).toList();
      final useDistractors = cleanDistractors.length >= GameRules.minDistractorsRequired
          ? cleanDistractors
          : distractors;
      final options = [correct, ...useDistractors.take(GameRules.mcqOptionCount - 1)]..shuffle(rng);
      sessionCorrects.add(correct);
      out.add(McqQuestion(
        prompt: word.word,
        promptSubtitle: 'What does this mean?',
        options: options,
        correctAnswer: correct,
        questionText: 'Meaning of "${word.word}"',
        wordId: word.id,
      ));
      if (out.length >= count) break;
    }
    return out;
  }
}
