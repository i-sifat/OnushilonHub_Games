import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/models/game_config.dart';
import '../../../core/models/user_progress_model.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/timer/game_timer_controller.dart';
import '../../../database/i_game_repository.dart';
import '../../../shared/widgets/game_screen_lifecycle_mixin.dart';
import 'builders/mcq_question.dart';
import 'builders/mcq_question_builder.dart';
import 'countdown_engine.dart';
import 'game_failure.dart';
import 'game_rules.dart';
import 'state/mcq_game_state.dart';

/// Riverpod-owned game logic for every MCQ-style game (Task 1).
///
/// The notifier owns:
///   * the immutable [McqGameState] (single source of truth)
///   * an elapsed-time [GameTimerController] (session-level clock,
///     shared with every other game)
///   * the optional Speed-Racing [CountdownEngine] (per-question clock)
///
/// All public methods are pure transitions: read [state], compute the next
/// state, emit it via `state = ...`. Screens depend on the state, never on
/// internals.
class McqGameNotifier extends StateNotifier<McqGameState>
    implements PausableGameController {
  McqGameNotifier({
    required this.config,
    required this.repo,
    required this.builderFactory,
  }) : super(McqGameState(
          timer: config.gameType == GameType.speedRacing
              ? freshTimerState()
              : null,
        )) {
    _sessionTimer = GameTimerController(mode: GameTimerMode.stopwatch)..start();
    _sessionTimer.snapshot.addListener(_onSessionTick);
  }

  final GameConfig config;
  final IGameRepository repo;
  final McqQuestionBuilderFactory builderFactory;

  late final GameTimerController _sessionTimer;
  CountdownEngine? _countdown;

  bool get isSpeedRacing => config.gameType == GameType.speedRacing;

  // ── Initialisation ────────────────────────────────────────────────────────

  /// Loads questions with a timeout, surfacing failures via
  /// [McqGameState.initError] instead of throwing.
  Future<void> initialize() async {
    state = state.copyWith(isLoading: true, initError: null);
    try {
      final builder = builderFactory.get(config.gameType);
      final questions = await builder.build(config).timeout(
            GameRules.initializeTimeout,
            onTimeout: () =>
                throw const SessionFailure('Game data load timed out'),
          );
      state = state.copyWith(
        isLoading: false,
        questions: questions,
      );
      if (isSpeedRacing && questions.isNotEmpty) _startCountdown();
    } catch (e, stack) {
      state = state.copyWith(
        isLoading: false,
        initError: _humanise(e),
      );
      assert(() {
        debugPrint('McqGameNotifier.initialize failed: $e\n$stack');
        return true;
      }());
    }
  }

  // ── Answer handling ──────────────────────────────────────────────────────

  Future<void> handleAnswer(String answer) async {
    final q = state.currentQuestion;
    if (q == null || state.isAnswered) return;

    _countdown?.stop();
    final isCorrect = answer == q.correctAnswer;
    final remaining = state.timer?.timeLeft ?? 0;

    if (isCorrect) {
      _emitCorrect(q.questionText, q.correctAnswer);
      if (isSpeedRacing &&
          remaining >= GameRules.speedRacingFastAnswerThreshold) {
        _addSpeedBonus(GameRules.speedRacingFastAnswerBonus);
      }
    } else {
      _emitWrong(q.questionText, answer, q.correctAnswer);
    }

    if (q.wordId != null) {
      // Fire-and-forget — failure is non-fatal for gameplay.
      // ignore: unawaited_futures
      repo.markWordStatus(
        wordId: q.wordId!,
        gameType: config.gameType.dbKey,
        status: isCorrect ? 'mastered' : 'mistake',
      );
    }
  }

  void _emitCorrect(String question, String correctAnswer) {
    HapticFeedback.mediumImpact();
    state = state.copyWith(
      isAnswered: true,
      lastAnswerCorrect: true,
      score: state.score + AppTokens.xpPerCorrect,
      baseXp: state.baseXp + AppTokens.xpPerCorrect,
      correctCount: state.correctCount + 1,
    );
  }

  void _emitWrong(String question, String userAnswer, String correctAnswer) {
    HapticFeedback.heavyImpact();
    state = state.copyWith(
      isAnswered: true,
      lastAnswerCorrect: false,
      wrongCount: state.wrongCount + 1,
      mistakes: [
        ...state.mistakes,
        MistakeItem(
          question: question,
          userAnswer: userAnswer,
          correctAnswer: correctAnswer,
        ),
      ],
    );
  }

  void _addSpeedBonus(int bonus) {
    state = state.copyWith(
      score: state.score + bonus,
      bonusXp: state.bonusXp + bonus,
    );
  }

  Future<void> nextQuestion() async {
    _countdown?.stop();
    if (state.currentIndex >= state.totalQuestions - 1) {
      await _finishGame();
      return;
    }
    state = state.copyWith(
      currentIndex: state.currentIndex + 1,
      isAnswered: false,
      timer: isSpeedRacing ? freshTimerState() : null,
    );
    if (isSpeedRacing && !state.isFinished) _startCountdown();
  }

  Future<void> _finishGame() async {
    _sessionTimer.stop();
    final elapsed = _sessionTimer.value.elapsedSeconds;
    state = state.copyWith(
      isFinished: true,
      elapsedSeconds: elapsed,
    );

    final session = GameSessionModel(
      gameType: config.gameType.dbKey,
      score: state.score,
      correctCount: state.correctCount,
      wrongCount: state.wrongCount,
      durationSeconds: elapsed,
      playedAt: DateTime.now(),
    );

    try {
      await repo.persistSession(session: session, xpEarned: state.score);
    } on GameFailure catch (e) {
      state = state.copyWith(saveError: e.message);
    } catch (e, stack) {
      state = state.copyWith(saveError: 'Failed to save your progress.');
      assert(() {
        debugPrint('Session persist failed: $e\n$stack');
        return true;
      }());
    }
  }

  GameResult buildResult() => GameResult(
        gameType: config.gameType,
        score: state.score,
        correctCount: state.correctCount,
        wrongCount: state.wrongCount,
        durationSeconds: _sessionTimer.value.elapsedSeconds,
        baseXp: state.baseXp,
        bonusXp: state.bonusXp,
        mistakes: state.mistakes,
      );

  // ── Countdown lifecycle (Speed Racing) ───────────────────────────────────

  void _startCountdown() {
    _countdown?.dispose();
    state = state.copyWith(timer: freshTimerState());
    _countdown = CountdownEngine(
      duration: GameRules.speedRacingTimerSeconds,
      onTick: (remaining) {
        if (state.isAnswered) {
          _countdown?.stop();
          return;
        }
        state = state.copyWith(
          timer: TimerState(
            timeLeft: remaining,
            timedOut: false,
            isPaused: state.timer?.isPaused ?? false,
          ),
        );
      },
      onComplete: () {
        if (state.isAnswered) return;
        state = state.copyWith(
          timer: const TimerState(
            timeLeft: 0,
            timedOut: true,
            isPaused: false,
          ),
        );
        final q = state.currentQuestion;
        if (q != null) {
          _emitWrong(q.questionText, 'Time out', q.correctAnswer);
        }
      },
    )..start();
  }

  // ── Lifecycle (pause/resume) ─────────────────────────────────────────────

  @override
  void pauseTimer() {
    _sessionTimer.pause();
    if (!isSpeedRacing) return;
    if (state.isAnswered || state.isFinished) return;
    if (state.timer?.isPaused == true) return;
    _countdown?.pause();
    final t = state.timer;
    if (t != null) {
      state = state.copyWith(
        timer: TimerState(
          timeLeft: t.timeLeft,
          timedOut: t.timedOut,
          isPaused: true,
        ),
      );
    }
  }

  @override
  void resumeTimer() {
    if (!state.isFinished) _sessionTimer.resume();
    if (!isSpeedRacing) return;
    if (state.isAnswered || state.isFinished) return;
    if (state.timer?.isPaused != true) return;
    final t = state.timer!;
    state = state.copyWith(
      timer: TimerState(
        timeLeft: t.timeLeft,
        timedOut: t.timedOut,
        isPaused: false,
      ),
    );
    _countdown?.resume();
  }

  void _onSessionTick() {
    final seconds = _sessionTimer.value.elapsedSeconds;
    if (seconds != state.elapsedSeconds) {
      state = state.copyWith(elapsedSeconds: seconds);
    }
  }

  String _humanise(Object e) {
    if (e is GameFailure) return e.message;
    if (e is TimeoutException) {
      return 'The game took too long to load. Please try again.';
    }
    return 'Could not load the game. Please try again.';
  }

  @override
  void dispose() {
    _countdown?.dispose();
    _countdown = null;
    _sessionTimer.snapshot.removeListener(_onSessionTick);
    _sessionTimer.dispose();
    try {
      repo.clearGameCache();
    } catch (_) {/* defensive: never let cache cleanup mask a real error */}
    super.dispose();
  }
}
