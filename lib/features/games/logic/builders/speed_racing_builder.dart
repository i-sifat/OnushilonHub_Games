import 'dart:math';
import '../../../../core/models/game_config.dart';
import '../../../../database/game_data_repository.dart';
import '../game_rules.dart';
import 'mcq_question.dart';
import 'mcq_question_builder.dart';

class SpeedRacingBuilder extends McqQuestionBuilder {
  final GameDataRepository repo;
  const SpeedRacingBuilder(this.repo);

  // SR1: maximum definition length for MCQ tiles.
  // Definitions >120 chars overflow option tiles on small screens.
  // Same cap applied in Definition Match (DM3).
  static const int _maxDefLength = 120;

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

    // SR2: session-wide dedup — prevents a correct answer from Q3 appearing
    // as a distractor in Q7, which would penalise players for recognising it.
    final sessionCorrects = <String>{};

    final out = <McqQuestion>[];

    for (final word in words) {
      // SR1: skip words whose definition exceeds the tile length cap —
      // same filter as DM3 in Definition Match.
      final correct = word.definition;
      if (correct.isEmpty || correct.length > _maxDefLength) continue;

      final distractors = pool
          .where((w) => w.id != word.id)
          .map((w) => w.definition)
          .where((d) =>
              d.isNotEmpty &&
              d != correct &&
              d.length <= _maxDefLength)  // SR1: cap distractors too
          .toSet()
          .toList()
        ..shuffle(rng);

      if (distractors.length < GameRules.minDistractorsRequired) continue;

      // SR2: remove distractors that are correct answers elsewhere in session
      final cleanDistractors = distractors
          .where((d) => !sessionCorrects.contains(d))
          .toList();

      final useDistractors =
          cleanDistractors.length >= GameRules.minDistractorsRequired
              ? cleanDistractors
              : distractors; // fallback if dedup left too few

      final options = [correct, ...useDistractors.take(3)]..shuffle(rng);
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
