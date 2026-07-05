import 'dart:math';

import '../game_rules.dart';
import 'ipa_difficulty.dart';
import 'ipa_distractor_generator.dart';

/// Result returned by [IpaOptionSetBuilder]: a fully validated answer set,
/// or `null` when no valid set can be assembled even after fallbacks.
class IpaOptionSet {
  final List<String> options;
  final String correctAnswer;
  const IpaOptionSet({required this.options, required this.correctAnswer});
}

/// Assembles the final four-option answer set for one IPA Match question.
///
/// Responsibilities:
///   1. Ask [IpaDistractorGenerator] for same-word distractors.
///   2. Top up from an external `crossWordPool` if generation underflows.
///   3. Guarantee uniqueness, presence of the correct answer, and a final
///      shuffle so the correct answer position is not predictable.
class IpaOptionSetBuilder {
  final IpaDistractorGenerator _generator;
  final Random _rng;

  IpaOptionSetBuilder({
    IpaDistractorGenerator? generator,
    Random? random,
  })  : _generator = generator ?? IpaDistractorGenerator(random: random),
        _rng = random ?? Random();

  /// Builds an option set for [correctIpa] at [difficulty]. If same-word
  /// transformations cannot yield enough unique distractors, falls back to
  /// entries from [crossWordPool] (typically other IPA strings from the same
  /// question pool). Returns `null` if even the fallback cannot satisfy
  /// [GameRules.mcqOptionCount].
  IpaOptionSet? build({
    required String correctIpa,
    required IpaDifficulty difficulty,
    required List<String> crossWordPool,
  }) {
    const distractorsNeeded = GameRules.mcqOptionCount - 1;
    final generated = _generator.generate(
      correctIpa: correctIpa,
      difficulty: difficulty,
      count: distractorsNeeded,
    );

    final unique = <String>{...generated};
    if (unique.length < distractorsNeeded) {
      for (final candidate in (crossWordPool.toList()..shuffle(_rng))) {
        if (candidate == correctIpa) continue;
        unique.add(candidate);
        if (unique.length >= distractorsNeeded) break;
      }
    }

    if (unique.length < distractorsNeeded) return null;

    final options = <String>[correctIpa, ...unique.take(distractorsNeeded)]
      ..shuffle(_rng);
    return IpaOptionSet(options: options, correctAnswer: correctIpa);
  }
}
