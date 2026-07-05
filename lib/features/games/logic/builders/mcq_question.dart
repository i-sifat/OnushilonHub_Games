import 'package:flutter/material.dart' show Color, ValueNotifier;
import '../../../../core/theme/app_colors.dart';
import '../game_rules.dart';

/// Universal MCQ question that carries all data any game variant needs.
///
/// [prompt]         — main display text (word, IPA symbol, quote body, …)
/// [promptSubtitle] — secondary hint below the prompt (optional)
/// [options]        — the answer choices (typically 4)
/// [correctAnswer]  — which option is correct
/// [questionText]   — short label used in the mistakes log
/// [wordId]         — DB row id, non-null for DB-backed games (mastery tracking)
class McqQuestion {
  final String prompt;
  final String promptSubtitle;
  final List<String> options;
  final String correctAnswer;
  final String questionText;
  final int? wordId;

  const McqQuestion({
    required this.prompt,
    this.promptSubtitle = '',
    required this.options,
    required this.correctAnswer,
    required this.questionText,
    this.wordId,
  });
}

/// Snapshot of the Speed-Racing countdown, exposed via a dedicated
/// [ValueNotifier] so only the timer widget rebuilds on each tick instead of
/// the whole game screen.
class TimerState {
  final double timeLeft;
  final bool timedOut;
  final bool isPaused;

  const TimerState({
    required this.timeLeft,
    required this.timedOut,
    required this.isPaused,
  });

  double get fraction =>
      (timeLeft / GameRules.speedRacingTimerSeconds).clamp(0.0, 1.0);

  Color colorFor(bool isDark) {
    if (timeLeft > 6) return AppColors.primary;
    if (timeLeft > 3) return AppColors.reward;
    return isDark ? AppColors.darkError : AppColors.lightError;
  }
}
