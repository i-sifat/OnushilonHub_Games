import 'package:flutter/material.dart' show Color, ValueNotifier;

import '../../../../core/theme/app_colors.dart';
import '../game_rules.dart';

/// Universal MCQ question that carries all data any game variant needs.
///
/// [prompt] — main display text (word, IPA symbol, quote body, …)
/// [promptSubtitle] — secondary hint below the prompt (optional)
/// [options] — the answer choices (typically 4)
/// [correctAnswer] — which option is correct
/// [allCorrectAnswers] — all valid answers (e.g. every synonym for a word);
///   used in mistake review to show the full picture. Empty for question types
///   that have a single correct answer.
/// [questionText] — short label used in the mistakes log
/// [wordId] — DB row id, non-null for DB-backed games (mastery tracking)
/// [correctDefinition] — for True/False games: the actual correct definition
///   of the word. Populated only when a decoy definition is presented
///   ([correctAnswer] == 'False'). Shown in the feedback panel after the
///   player answers so they always learn the real meaning.
class McqQuestion {
  final String prompt;
  final String promptSubtitle;
  final List<String> options;
  final String correctAnswer;
  final List<String> allCorrectAnswers;
  final String questionText;
  final int? wordId;
  final String? correctDefinition;

  const McqQuestion({
    required this.prompt,
    this.promptSubtitle = '',
    required this.options,
    required this.correctAnswer,
    this.allCorrectAnswers = const [],
    required this.questionText,
    this.wordId,
    this.correctDefinition,
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
