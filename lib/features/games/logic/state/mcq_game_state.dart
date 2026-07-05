import '../../../../core/models/game_config.dart' show MistakeItem;
import '../builders/mcq_question.dart';
import '../game_rules.dart';
import 'game_session_state.dart';

/// Immutable state for any MCQ-style game (Task 2).
///
/// Owned by `McqGameNotifier`; screens read it via `ref.watch` and never
/// mutate it directly.
class McqGameState implements GameSessionState {
  @override
  final bool isLoading;
  @override
  final String? initError;
  @override
  final int currentIndex;
  @override
  final bool isAnswered;
  @override
  final bool isFinished;
  @override
  final bool lastAnswerCorrect;
  @override
  final int score;
  @override
  final int baseXp;
  @override
  final int bonusXp;
  @override
  final int correctCount;
  @override
  final int wrongCount;
  @override
  final List<MistakeItem> mistakes;
  @override
  final int elapsedSeconds;
  @override
  final String? saveError;

  /// The full question list. Empty until [isLoading] flips to false.
  final List<McqQuestion> questions;

  /// Speed-Racing countdown snapshot. Null for other MCQ game types.
  final TimerState? timer;

  const McqGameState({
    this.isLoading = true,
    this.initError,
    this.questions = const [],
    this.currentIndex = 0,
    this.isAnswered = false,
    this.isFinished = false,
    this.lastAnswerCorrect = false,
    this.score = 0,
    this.baseXp = 0,
    this.bonusXp = 0,
    this.correctCount = 0,
    this.wrongCount = 0,
    this.mistakes = const [],
    this.elapsedSeconds = 0,
    this.saveError,
    this.timer,
  });

  @override
  int get totalQuestions => questions.length;

  McqQuestion? get currentQuestion =>
      questions.isNotEmpty && currentIndex < questions.length
          ? questions[currentIndex]
          : null;

  @override
  double get progress =>
      totalQuestions > 0 ? currentIndex / totalQuestions : 0;

  @override
  String get elapsedDisplayTime {
    final m = elapsedSeconds ~/ 60;
    final s = elapsedSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  McqGameState copyWith({
    bool? isLoading,
    Object? initError = _sentinel,
    List<McqQuestion>? questions,
    int? currentIndex,
    bool? isAnswered,
    bool? isFinished,
    bool? lastAnswerCorrect,
    int? score,
    int? baseXp,
    int? bonusXp,
    int? correctCount,
    int? wrongCount,
    List<MistakeItem>? mistakes,
    int? elapsedSeconds,
    Object? saveError = _sentinel,
    Object? timer = _sentinel,
  }) {
    return McqGameState(
      isLoading: isLoading ?? this.isLoading,
      initError:
          identical(initError, _sentinel) ? this.initError : initError as String?,
      questions: questions ?? this.questions,
      currentIndex: currentIndex ?? this.currentIndex,
      isAnswered: isAnswered ?? this.isAnswered,
      isFinished: isFinished ?? this.isFinished,
      lastAnswerCorrect: lastAnswerCorrect ?? this.lastAnswerCorrect,
      score: score ?? this.score,
      baseXp: baseXp ?? this.baseXp,
      bonusXp: bonusXp ?? this.bonusXp,
      correctCount: correctCount ?? this.correctCount,
      wrongCount: wrongCount ?? this.wrongCount,
      mistakes: mistakes ?? this.mistakes,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      saveError: identical(saveError, _sentinel)
          ? this.saveError
          : saveError as String?,
      timer: identical(timer, _sentinel) ? this.timer : timer as TimerState?,
    );
  }

  static const _sentinel = Object();
}

/// Default timer snapshot when a Speed-Racing session starts a new question.
TimerState freshTimerState() => const TimerState(
      timeLeft: GameRules.speedRacingTimerSeconds,
      timedOut: false,
      isPaused: false,
    );
