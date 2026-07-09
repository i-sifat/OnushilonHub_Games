/// F-01: SM-2 Spaced Repetition System calculator.
///
/// Implements the SuperMemo SM-2 algorithm:
///   https://www.supermemo.com/en/archives1990-2015/english/ol/sm2
///
/// Integrate into [DatabaseService._ensureUserTables] by adding
/// `next_review_at INTEGER` and `ease_factor REAL` to `word_progress`.
/// In `markWordStatus`, compute the next review interval and persist it.
class SrsCalculator {
  /// Default ease factor for new cards.
  static const double initialEaseFactor = 2.5;

  /// Minimum ease factor — prevents the interval from collapsing to zero.
  static const double minEaseFactor = 1.3;

  /// Computes the next review [DateTime] and updated ease factor for a word.
  ///
  /// [attempts]   — number of times this word has been reviewed (1-indexed).
  /// [wasCorrect] — whether the player answered correctly this time.
  /// [easeFactor] — current ease factor (EF), defaults to [initialEaseFactor].
  ///
  /// Returns a [SrsResult] with the next review date and updated EF.
  static SrsResult nextReview({
    required int attempts,
    required bool wasCorrect,
    double easeFactor = initialEaseFactor,
  }) {
    if (!wasCorrect) {
      // On failure: reset interval to 1 day, slight EF decrease.
      return SrsResult(
        nextReviewAt: DateTime.now().add(const Duration(days: 1)),
        easeFactor: (easeFactor - 0.2).clamp(minEaseFactor, double.infinity),
      );
    }

    // SM-2 interval schedule for correct responses:
    // Attempt 1 → 1 day, Attempt 2 → 6 days, Attempt N → prev * EF
    final int intervalDays;
    if (attempts <= 1) {
      intervalDays = 1;
    } else if (attempts == 2) {
      intervalDays = 6;
    } else {
      // For subsequent reviews use the previous interval * EF.
      // We approximate previous interval as 6 * EF^(attempts-2).
      intervalDays = (6 * _pow(easeFactor, attempts - 2)).round();
    }

    // EF update: EF' = EF + (0.1 - (5-q)*(0.08+(5-q)*0.02))
    // where q = 5 for a perfect answer (always correct here).
    const int q = 5;
    final newEF = easeFactor +
        (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02));

    return SrsResult(
      nextReviewAt: DateTime.now().add(Duration(days: intervalDays)),
      easeFactor: newEF.clamp(minEaseFactor, double.infinity),
    );
  }

  static double _pow(double base, int exp) {
    double result = 1;
    for (var i = 0; i < exp; i++) result *= base;
    return result;
  }
}

/// Result from [SrsCalculator.nextReview].
class SrsResult {
  final DateTime nextReviewAt;
  final double easeFactor;

  const SrsResult({required this.nextReviewAt, required this.easeFactor});
}
