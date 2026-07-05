import 'dart:math';
import '../../../../core/models/game_config.dart';
import '../../../../database/game_data_repository.dart';
import '../game_rules.dart';
import 'mcq_question.dart';
import 'mcq_question_builder.dart';

class MeaningChaseBuilder extends McqQuestionBuilder {
  final GameDataRepository repo;
  const MeaningChaseBuilder(this.repo);

  // ── MC2: POS-suffix cleaner ───────────────────────────────────────────────
  //
  // Raw Bengali meanings from the DB often carry part-of-speech annotations:
  //   "কম্পন (N)"        → "কম্পন"
  //   "শান্ত (Adj.)"     → "শান্ত"
  //   "চালানো"           → "চালানো"   (unchanged — no suffix)
  //
  // Stripping makes option labels cleaner for the player and — critically —
  // prevents the m != correct dedup filter from treating "শান্ত" and
  // "শান্ত (Adj.)" as different strings (they are semantically identical).
  String _cleanMeaning(String raw) {
    // Step 1: take only the first meaning (before the first comma).
    final firstOnly = raw.split(',').first.trim();
    // Step 2: strip trailing POS annotation like "(N)", "(Adj.)", "(v.)".
    // Pattern: optional space, open paren, letters/dots/spaces, close paren, end.
    return firstOnly
        .replaceAll(RegExp(r"\s*\([A-Za-z./\s]+\)\s*\$"), '')
        .trim();
  }

  @override
  Future<List<McqQuestion>> build(GameConfig config) async {
    final rng = Random();
    final count = resolveQuestionCount(config);

    // ── Word fetch ────────────────────────────────────────────────────────
    final words = await repo.getEligibleWords(
      gameType: config.gameType.dbKey,
      difficulty: config.difficulty,
      limit: count,
      requiresDefinition: true,
    );

    // MC1: only keep words that have a Bengali meaning.
    // Words with banglaMeaning empty would fall back to an English definition
    // as the correct answer, producing mixed-language option lists where the
    // English answer is trivially obvious.
    final banglaWords =
        words.where((w) => w.banglaMeaning.isNotEmpty).toList();

    // ── Distractor pool ───────────────────────────────────────────────────
    final pool = await repo.getEligibleWords(
      gameType: 'meaning_chase',
      difficulty: 0,
      limit: (count * GameRules.distractorOverfetchFactor).clamp(60, 300),
      requiresDefinition: true,
    );

    // ── Build word questions ──────────────────────────────────────────────
    final built = <McqQuestion>[];

    for (final word in banglaWords) {
      // MC1: always Bengali — never English fallback.
      final correct = _cleanMeaning(word.banglaMeaning);
      if (correct.isEmpty) continue;

      // MC2: clean all distractor labels the same way so the != filter
      // catches near-identical meanings that only differ by POS suffix.
      final distractors = pool
          .where((w) => w.id != word.id && w.banglaMeaning.isNotEmpty)
          .map((w) => _cleanMeaning(w.banglaMeaning))
          .where((m) => m.isNotEmpty && m != correct)
          .toSet()
          .toList()
        ..shuffle(rng);

      if (distractors.length < GameRules.minDistractorsRequired) continue;

      final options = [correct, ...distractors.take(3)]..shuffle(rng);
      built.add(McqQuestion(
        prompt: word.word,
        promptSubtitle: 'বাংলা অর্থ বেছে নিন',
        options: options,
        correctAnswer: correct,
        questionText: '"${word.word}" শব্দটির বাংলা অর্থ কী?',
        wordId: word.id,
      ));
    }

    // ── MC4: session-wide distractor dedup ───────────────────────────────
    //
    // If meaning X is the correct answer for Q3 it should never appear as a
    // distractor for Q7 — the player who just learned X would be penalised
    // for recognising it.  Collect all session correct answers and scrub them
    // from every question's option list.  If scrubbing leaves fewer than
    // minOptionCount options we keep the question unchanged (better a slight
    // collision than an unplayable question).
    final sessionCorrects = built.map((q) => q.correctAnswer).toSet();
    final deduped = built.map((q) {
      final cleanOpts = q.options
          .where((o) => o == q.correctAnswer || !sessionCorrects.contains(o))
          .toList();
      if (cleanOpts.length < GameRules.minOptionCount) return q;
      // Re-shuffle so the correct answer position is not predictable after
      // removal of some distractors.
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

    // ── Phrase fallback (MC5) ─────────────────────────────────────────────
    //
    // If the word pass produced fewer questions than requested, top up with
    // phrase questions from bengali_dictionary (is_phrase = 1).
    //
    // MC5: phrase questions get a distinct promptSubtitle so the player
    // knows they are being tested on a multi-word expression, not a single
    // vocabulary word.
    final remaining = count - deduped.length;
    if (remaining > 0) {
      final phrases =
          await repo.getMeaningChasePhrases(limit: remaining * 4);

      // MC2: clean phrase meanings the same way as word meanings.
      final phraseMeanings = phrases
          .map((p) => _cleanMeaning(p['bn'] as String))
          .where((m) => m.isNotEmpty)
          .toList();

      for (final phrase in phrases) {
        if (deduped.length >= count) break;
        final en = phrase['en'] as String;
        final correct = _cleanMeaning(phrase['bn'] as String);
        if (correct.isEmpty) continue;

        final distractors = phraseMeanings
            .where((m) => m != correct)
            .toSet()
            .toList()
          ..shuffle(rng);
        if (distractors.length < GameRules.minDistractorsRequired) continue;

        final options = [correct, ...distractors.take(3)]..shuffle(rng);
        deduped.add(McqQuestion(
          prompt: en,
          // MC5: distinct subtitle signals to player this is a phrase, not a
          // single word — sets the right expectation before they read the prompt.
          promptSubtitle: 'বাক্যাংশের বাংলা অর্থ বেছে নিন',
          options: options,
          correctAnswer: correct,
          questionText: '"$en" এর বাংলা অর্থ কী?',
          // wordId intentionally null — phrases have no word_progress tracking.
        ));
      }
    }

    return deduped;
  }
}
