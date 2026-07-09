import 'dart:math';

import '../../../../core/models/game_config.dart';
import '../../../../database/i_game_repository.dart';
import '../game_rules.dart';
import 'mcq_question.dart';
import 'mcq_question_builder.dart';

/// A-03: now accepts [IGameRepository].
class MeaningChaseBuilder extends McqQuestionBuilder {
  final IGameRepository repo;

  const MeaningChaseBuilder(this.repo);

  String _cleanMeaning(String raw) {
    final firstOnly = raw.split(',').first.trim();
    return firstOnly
        .replaceAll(RegExp(r"\s*\([A-Za-z./\s]+\)\s*$"), '')
        .trim();
  }

  @override
  Future<List<McqQuestion>> build(GameConfig config) async {
    final rng = Random();
    final count = resolveQuestionCount(config);

    final words = await repo.getEligibleWords(
      gameType: config.gameType.dbKey,
      difficulty: config.difficulty,
      limit: count,
      requiresDefinition: true,
    );
    final banglaWords = words.where((w) => w.banglaMeaning.isNotEmpty).toList();

    final pool = await repo.getEligibleWords(
      gameType: 'meaning_chase',
      difficulty: 0,
      limit: (count * GameRules.distractorOverfetchFactor).clamp(60, 300),
      requiresDefinition: true,
    );

    final built = <McqQuestion>[];
    for (final word in banglaWords) {
      final correct = _cleanMeaning(word.banglaMeaning);
      if (correct.isEmpty) continue;

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

    final sessionCorrects = built.map((q) => q.correctAnswer).toSet();
    final deduped = built.map((q) {
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

    final remaining = count - deduped.length;
    if (remaining > 0) {
      final phrases = await repo.getMeaningChasePhrases(limit: remaining * 4);
      final phraseMeanings = phrases
          .map((p) => _cleanMeaning(p['bn'] as String))
          .where((m) => m.isNotEmpty)
          .toList();
      for (final phrase in phrases) {
        if (deduped.length >= count) break;
        final correct = _cleanMeaning(phrase['bn'] as String);
        if (correct.isEmpty) continue;
        final distractors = phraseMeanings
            .where((m) => m != correct)
            .toSet()
            .toList()
          ..shuffle(rng);
        if (distractors.length < GameRules.minDistractorsRequired) continue;
        final options = [correct, ...distractors.take(3)]..shuffle(rng);
        final en = phrase['en'] as String;
        deduped.add(McqQuestion(
          prompt: en,
          promptSubtitle: 'বাংলা অর্থ বেছে নিন (প্রবচন)',
          options: options,
          correctAnswer: correct,
          questionText: '"$en" কথাটির বাংলা অর্থ কী?',
          wordId: phrase['id'] as int,
        ));
      }
    }
    return deduped;
  }
}
