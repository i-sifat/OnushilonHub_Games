import 'dart:math';
import '../../../../core/models/game_config.dart';
import '../../../../database/game_data_repository.dart';
import '../game_rules.dart';
import 'mcq_question.dart';
import 'mcq_question_builder.dart';

class DefinitionMatchBuilder extends McqQuestionBuilder {
  final GameDataRepository repo;
  const DefinitionMatchBuilder(this.repo);

  @override
  Future<List<McqQuestion>> build(GameConfig config) async {
    final rng = Random();
    final count = resolveQuestionCount(config);

    // ── Question words ────────────────────────────────────────────────────
    // DM1: getRandomDefinitionEntries now always loads 2000 fresh entries
    // from the DB (never reuses a stale cache) and returns [count] of them.
    final entries = await repo.getRandomDefinitionEntries(count: count);
    if (entries.isEmpty) return [];

    // ── Independent distractor pool ───────────────────────────────────────
    // DM2: fetch a SEPARATE large pool purely for distractors.
    // Using the same pool for both questions and distractors (previous bug)
    // allowed pattern recognition: every distractor was also a correct answer
    // elsewhere in the session. Now questions and distractors are independent.
    // 200 entries gives ample variety for up to 20 questions × 3 distractors.
    final distractorPool =
        await repo.getDefinitionDistractorPool(limit: 200);
    if (distractorPool.isEmpty) return [];

    // Resolve wordIds for mastery tracking in one batch call.
    final wordIdMap = await repo.getWordIdsByLowercase(
      entries.map((e) => e.word).toList(),
    );

    // ── Build questions ───────────────────────────────────────────────────
    final out = <McqQuestion>[];

    for (final entry in entries) {
      // DM2: distractors come exclusively from the independent pool.
      // Filter out any distractor whose definition exactly matches the
      // correct answer (edge case: same definition text for different words).
      final distractors = distractorPool
          .where((e) => e.definition != entry.definition)
          .map((e) => e.definition)
          .toSet()
          .toList()
        ..shuffle(rng);

      if (distractors.length < GameRules.minDistractorsRequired) continue;

      final options = [entry.definition, ...distractors.take(3)]..shuffle(rng);

      // DM7: posLabel kept as localisation-friendly constant; the subtitle
      // follows the same pattern as other builders for easy future l10n.
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

    // ── DM4: session-wide correct-answer dedup ────────────────────────────
    // Because the distractor pool is now independent from the question pool,
    // semantic collisions are rare. But as a defensive measure — matching the
    // MC4 pattern from MeaningChaseBuilder — we scrub any distractor that
    // happens to also be a correct answer for another question in this session.
    // Falls back to the original options if scrubbing would leave < minOptionCount.
    final sessionCorrects = out.map((q) => q.correctAnswer).toSet();
    final deduped = out.map((q) {
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

    return deduped;
  }
}
