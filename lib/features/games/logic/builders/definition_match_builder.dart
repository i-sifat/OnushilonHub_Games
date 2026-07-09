import 'dart:math';

import '../../../../core/models/game_config.dart';
import '../../../../database/i_game_repository.dart';
import '../game_rules.dart';
import 'mcq_question.dart';
import 'mcq_question_builder.dart';

/// A-03: now accepts [IGameRepository] so the builder can be unit-tested
/// with [MockGameRepository] without a real SQLite DB.
class DefinitionMatchBuilder extends McqQuestionBuilder {
  final IGameRepository repo;

  const DefinitionMatchBuilder(this.repo);

  @override
  Future<List<McqQuestion>> build(GameConfig config) async {
    final rng = Random();
    final count = resolveQuestionCount(config);

    final entries = await repo.getRandomDefinitionEntries(count: count);
    if (entries.isEmpty) return [];

    final distractorPool = await repo.getDefinitionDistractorPool(
        limit: GameRules.definitionDistractorPoolLimit);
    if (distractorPool.isEmpty) return [];

    final wordIdMap = await repo.getWordIdsByLowercase(
      entries.map((e) => e.word).toList(),
    );

    final out = <McqQuestion>[];
    for (final entry in entries) {
      final distractors = distractorPool
          .where((e) => e.definition != entry.definition)
          .map((e) => e.definition)
          .toSet()
          .toList()
        ..shuffle(rng);
      if (distractors.length < GameRules.minDistractorsRequired) continue;

      final options = [
        entry.definition,
        ...distractors.take(GameRules.mcqOptionCount - 1),
      ]..shuffle(rng);

      final posLabel = entry.partOfSpeech.isNotEmpty
          ? ' (${entry.partOfSpeech.toLowerCase()})'
          : '';

      out.add(McqQuestion(
        prompt: entry.word,
        promptSubtitle: 'Choose the correct definition$posLabel',
        options: options,
        correctAnswer: entry.definition,
        questionText: 'Definition of "${entry.word}"',
        wordId: wordIdMap[entry.word.toLowerCase()],
      ));
    }

    final sessionCorrects = out.map((q) => q.correctAnswer).toSet();
    return out.map((q) {
      final cleanOpts = q.options
          .where((o) => o == q.correctAnswer || !sessionCorrects.contains(o))
          .toList();
      if (cleanOpts.length < GameRules.minOptionCount) return q;
      cleanOpts.shuffle(rng);
      return McqQuestion(
        prompt: q.prompt,
        promptSubtitle: q.promptSubtitle,
        options: cleanOpts,
        correctAnswer: q.correctAnswer,
        questionText: q.questionText,
        wordId: q.wordId,
      );
    }).toList();
  }
}
