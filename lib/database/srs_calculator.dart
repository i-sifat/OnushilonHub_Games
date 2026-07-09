/// F-01: SM-2 Spaced Repetition System calculator.
///
/// Implements the SM-2 algorithm to compute when a word should next be
/// reviewed based on the player's answer history.
///
/// References:
///   https://www.supermemo.com/en/blog/application-of-a-computer-to-improve-the-results-obtained-in-working-with-the-supermemo-method
class SrsCalculator {
  // SM-2 constants
  static const double _minEaseFactor = 1.3;
  static const double _defaultEaseFactor = 2.5;
  static const double _easeBonus = 0.1;
  static const double _easePenalty = 0.8;

  /// Computes the next review [DateTime] and updated ease factor for a word.
  ///
  /// Parameters:
  ///   [attempts]   — total number of times the word has been tested.
  ///   [correct]    — true if the player answered correctly in this session.
  ///   [easeFactor] — current ease factor (default [_defaultEaseFactor]).
  ///
  /// Returns a [SrsResult] containing the next review date and updated ease factor.
  static SrsResult nextReview({
    required int attempts,
    required bool correct,
    double easeFactor = _defaultEaseFactor,
  }) {
    if (!correct) {
      // Wrong answer: review again in 1 day, reduce ease factor.
      final newEase = (easeFactor * _easePenalty).clamp(_minEaseFactor, 4.0);
      return SrsResult(
        nextReviewAt: DateTime.now().add(const Duration(days: 1)),
        easeFactor: newEase,
      );
    }

    // Correct answer: schedule based on attempt count + ease factor.
    final intervalDays = _computeInterval(attempts, easeFactor);
    final newEase = (easeFactor + _easeBonus).clamp(_minEaseFactor, 4.0);

    return SrsResult(
      nextReviewAt: DateTime.now().add(Duration(days: intervalDays)),
      easeFactor: newEase,
    );
  }

  /// Computes the review interval in days using the SM-2 schedule:
  ///   attempt 1 → 1 day
  ///   attempt 2 → 3 days
  ///   attempt 3+ → previous_interval × easeFactor
  static int _computeInterval(int attempts, double easeFactor) {
    if (attempts <= 1) return 1;
    if (attempts == 2) return 3;
    // SM-2: each subsequent interval grows by the ease factor.
    double interval = 3.0;
    for (int i = 2; i < attempts; i++) {
      interval *= easeFactor;
    }
    return interval.round().clamp(1, 365);
  }

  /// Returns whether a word is due for review based on its [nextReviewAt].
  static bool isDue(int? nextReviewAtMs) {
    if (nextReviewAtMs == null) return true; // Never reviewed → always due.
    final nextReview = DateTime.fromMillisecondsSinceEpoch(nextReviewAtMs);
    return DateTime.now().isAfter(nextReview);
  }
}

/// Result returned by [SrsCalculator.nextReview].
class SrsResult {
  final DateTime nextReviewAt;
  final double easeFactor;

  const SrsResult({required this.nextReviewAt, required this.easeFactor});

  /// Unix timestamp in milliseconds — for direct DB storage.
  int get nextReviewAtMs => nextReviewAt.millisecondsSinceEpoch;
}
