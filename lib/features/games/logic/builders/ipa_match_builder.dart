import 'dart:math';

import '../../../../core/models/game_config.dart';
import '../../../../database/i_game_repository.dart';
import '../game_rules.dart';
import '../ipa/ipa_difficulty.dart';
import '../ipa/ipa_option_set_builder.dart';
import 'mcq_question.dart';
import 'mcq_question_builder.dart';

/// A-03: now accepts [IGameRepository].
class IpaMatchBuilder extends McqQuestionBuilder {
  final IGameRepository repo;
  final IpaOptionSetBuilder optionSetBuilder;

  IpaMatchBuilder(this.repo, {IpaOptionSetBuilder? optionSetBuilder})
      : optionSetBuilder = optionSetBuilder ?? IpaOptionSetBuilder();

  @override
  Future<List<McqQuestion>> build(GameConfig config) async {
    final count = resolveQuestionCount(config);
    final entries = await repo.getRandomIpaEntries(
        count: count + GameRules.ipaOverfetchBuffer);
    if (entries.isEmpty) return const [];

    final rng = Random();
    final pool = entries.toList()..shuffle(rng);
    final selected = pool.take(count).toList();
    final crossWordPool = pool.map((e) => e.ipa).toList();
    final wordIdMap = await repo.getWordIdsByLowercase(
      selected.map((e) => e.word).toList(),
    );

    final difficulty = IpaDifficulty.fromLegacy(config.difficulty);
    final out = <McqQuestion>[];

    for (final entry in selected) {
      final optionSet = optionSetBuilder.build(
        correctIpa: entry.ipa,
        difficulty: difficulty,
        crossWordPool: crossWordPool,
      );
      if (optionSet == null) continue;

      out.add(McqQuestion(
        prompt: entry.word.toUpperCase(),
        promptSubtitle: 'Choose the correct IPA pronunciation',
        options: optionSet.options,
        correctAnswer: optionSet.correctAnswer,
        questionText: 'IPA for "${entry.word}"',
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
