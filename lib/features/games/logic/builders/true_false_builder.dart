import 'dart:math';

import '../../../../core/models/game_config.dart';
import '../../../../database/game_data_repository.dart';
import '../game_rules.dart';
import 'mcq_question.dart';
import 'mcq_question_builder.dart';

/// Generates True/False definition questions as MCQ items with options
/// ['True', 'False'].
///
/// Reliability guarantees:
/// * Every word used has a non-empty definition.
/// * When the question must be false, the decoy definition is taken from
///   a *different* word. If no valid decoy is available the word is
///   skipped — we never present an "incorrect definition" while marking
///   the question as true, and never make up bogus content.
/// * TF1: Each decoy definition is used at most ONCE per session so the
///   player cannot learn patterns ("I saw this fake def already in Q2").
/// * TF2: Definitions exceeding [GameRules.maxDefinitionLength] chars are
///   excluded to prevent tile overflow.
/// * G-09: Exactly count~/2 True questions and count~/2 False questions
///   per session — pre-allocated slots prevent pattern-winning strategies.
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
      limit: count * GameRules.trueFalseWordOverfetch,
      requiresDefinition: true,
    );
    final pool = await repo.getEligibleWords(
      gameType: 'true_false',
      difficulty: 0,
      limit: (count * GameRules.distractorOverfetchFactor)
          .clamp(GameRules.distractorPoolMin, GameRules.distractorPoolMax),
      requiresDefinition: true,
    );
    if (words.isEmpty) return [];

    // G-09: Pre-allocate exactly count~/2 True slots, shuffled.
    // Guarantees a 50/50 split regardless of rng luck.
    final trueSlots = List.generate(count, (i) => i < count ~/ 2)
      ..shuffle(rng);

    // TF1: track which decoy definitions have already been used this session
    // so the same fake definition never appears twice as a False prompt.
    final usedDecoys = <String>{};
    final out = <McqQuestion>[];

    for (final word in words) {
      if (out.length >= count) break;

      // TF2: skip words with definitions too long for the UI tile.
      if (word.definition.isEmpty ||
          word.definition.length > GameRules.maxDefinitionLength) {
        continue;
      }

      final presentTrue = trueSlots[out.length];
      String presentedDefinition;
      String correctAnswer;

      if (presentTrue) {
        presentedDefinition = word.definition;
        correctAnswer = 'True';
      } else {
        // Find a real definition belonging to another word — never invent one.
        // TF1: also exclude definitions already used as decoys this session.
        final decoys = pool
            .where((w) =>
                w.id != word.id &&
                w.definition.isNotEmpty &&
                w.definition != word.definition &&
                w.definition.length <= GameRules.maxDefinitionLength &&
                // TF2
                !usedDecoys.contains(w.definition)) // TF1
            .toList()
          ..shuffle(rng);
        if (decoys.isEmpty) continue;
        presentedDefinition = decoys.first.definition;
        correctAnswer = 'False';
        usedDecoys.add(presentedDefinition); // TF1: mark as used
      }

      out.add(McqQuestion(
        prompt: word.word,
        promptSubtitle: presentedDefinition,
        options: const ['True', 'False'],
        correctAnswer: correctAnswer,
        questionText: '"\${word.word}" — "$presentedDefinition"',
        wordId: word.id,
      ));
    }

    return out;
  }
}
