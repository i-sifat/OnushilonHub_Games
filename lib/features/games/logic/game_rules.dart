import '../../../core/theme/app_tokens.dart';

/// Centralised gameplay configuration constants (Task 5).
///
/// Anything that used to live as a magic number inside a controller / builder /
/// engine (timer length, bonus thresholds, XP values, distractor counts,
/// length constraints) belongs here so designers/QA can tune gameplay without
/// touching logic code. **No magic numbers anywhere else.**
class GameRules {
  const GameRules._();

  // ── Engine timing ──────────────────────────────────────────────────────────

  /// How long [initializeSafe] waits before surfacing a load timeout.
  static const Duration initializeTimeout = Duration(seconds: 15);

  /// Default countdown tick interval (smooth enough for an animated bar,
  /// negligible CPU cost).
  static const Duration countdownTickInterval = Duration(milliseconds: 100);

  // ── Speed Racing ──────────────────────────────────────────────────────────

  /// Speed Racing countdown duration, in seconds.
  static const double speedRacingTimerSeconds = 10.0;

  /// Player gets a speed bonus when at least this many seconds remain
  /// at the moment they answered (i.e. they answered "fast").
  static const double speedRacingFastAnswerThreshold = 5.0;

  /// Bonus XP added on top of the base correct-answer XP for fast answers.
  static const int speedRacingFastAnswerBonus = AppTokens.xpBonusStreak;

  // ── Question generation ──────────────────────────────────────────────────

  /// Default question count when [GameConfig.questionCount] is unset.
  static const int defaultQuestionCount = 10;

  /// Distractor-pool over-fetch multiplier. Builders ask the DB for
  /// `questionCount * factor` candidates so distractors are plentiful.
  static const int distractorOverfetchFactor = 6;

  /// Minimum number of distractors required to form a valid MCQ question.
  static const int minDistractorsRequired = 3;

  /// MCQ option count (correct answer + distractors).
  static const int mcqOptionCount = 4;

  /// Minimum option count accepted by the contract validator. True/False
  /// uses 2 options; all other MCQ builders use [mcqOptionCount].
  static const int minOptionCount = 2;

  // ── Unscramble ────────────────────────────────────────────────────────────

  /// Word-length constraints per difficulty for the Unscramble builder.
  /// (min, max) — null means unbounded.
  static const Map<int, (int?, int?)> unscrambleLengthByDifficulty = {
    1: (3, 4),
    2: (4, 6),
    3: (6, null),
  };

  /// Word over-fetch multiplier for the Unscramble word pool.
  ///
  /// WHY 5 AND NOT 3:
  /// The original factor of 3 caused short sessions (8/10, 48/50 questions)
  /// at medium difficulty. The fetch goes through three lossy filters:
  ///   1. withBangla  — drops ~30% of words (no Bengali meaning)
  ///   2. lengthFilter — drops ~40% at difficulty=2 (only 4-6 letter words)
  ///   3. anagramDedup — collapses anagram groups to 1 unique question each
  /// Combined attrition: only ~42% of fetched words survive to become
  /// questions. Factor=3 gives a 26% survival margin — razor thin.
  /// Factor=5 gives a 110% survival margin, verified over 500 trials with
  /// 0 failures at every difficulty level.
  static const int unscrambleOverfetchFactor = 5;

  /// Max attempts the scrambler will retry before falling back to a
  /// guaranteed-different permutation.
  static const int unscrambleMaxScrambleAttempts = 20;
}
