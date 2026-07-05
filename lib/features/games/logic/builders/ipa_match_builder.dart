import 'dart:math';

import '../../../../core/models/game_config.dart';
import '../../../../database/game_data_repository.dart';
import '../game_rules.dart';
import '../ipa/ipa_difficulty.dart';
import '../ipa/ipa_option_set_builder.dart';
import 'mcq_question.dart';
import 'mcq_question_builder.dart';

/// IPA Match question builder.
///
/// For each target word, distractors are derived from the same word's IPA
/// using [IpaOptionSetBuilder] (difficulty-aware). If same-word generation
/// underflows for a particular entry, the builder supplies other entries'
/// IPA as a fallback pool — guaranteeing every emitted question has exactly
/// [GameRules.mcqOptionCount] unique options with a single correct answer.
class IpaMatchBuilder extends McqQuestionBuilder {
  final GameDataRepository repo;
  final IpaOptionSetBuilder optionSetBuilder;

  IpaMatchBuilder(this.repo, {IpaOptionSetBuilder? optionSetBuilder})
      : optionSetBuilder = optionSetBuilder ?? IpaOptionSetBuilder();

  @override
  Future<List<McqQuestion>> build(GameConfig config) async {
    final count = resolveQuestionCount(config);
    final entries = await repo.getRandomIpaEntries(count: count + 30);
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
        // IPA1: display word in UPPERCASE to match every other game in the
        // family. IPA entries are stored lowercase in the DB; .toUpperCase()
        // here is purely presentational — the wordId lookup uses .toLowerCase()
        // so mastery tracking is unaffected.
        prompt: entry.word.toUpperCase(),
        promptSubtitle: 'Choose the correct IPA pronunciation',
        options: optionSet.options,
        correctAnswer: optionSet.correctAnswer,
        questionText: 'IPA for "${entry.word}"',
        wordId: wordIdMap[entry.word.toLowerCase()],
      ));
    }
    return out;
  }
}
