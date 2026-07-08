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

class McqGameNotifier extends StateNotifier<McqGameState>
    implements PausableGameController {
  McqGameNotifier({
    required this.config,
    required this.repo,
    required this.builderFactory,
  }) : super(
          McqGameState(
            timer: config.gameType == GameType.speedRacing
                ? freshTimerState()
                : null,
          ),
        ) {
    _sessionTimer =
        GameTimerController(mode: GameTimerMode.stopwatch)..start();
    _sessionTimer.snapshot.addListener(_onSessionTick);
  }

  final GameConfig config;
  final IGameRepository repo;
  final McqQuestionBuilderFactory builderFactory;

  late final GameTimerController _sessionTimer;
  CountdownEngine? _countdown;

  bool get isSpeedRacing => config.gameType == GameType.speedRacing;

  void _onSessionTick() {
    final elapsed = _sessionTimer.value.elapsedSeconds;
    state = state.copyWith(elapsedSeconds: elapsed);
  }

  void _addSpeedBonus(int bonus) {
    state = state.copyWith(
      score: state.score + bonus,
      bonusXp: state.bonusXp + bonus,
    );
  }

  String _humanise(Object error) {
    if (error is SessionFailure) return error.message;
    return 'An unexpected error occurred';
  }

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

  void _startCountdown() {
    _countdown = CountdownEngine(
      duration: GameRules.speedRacingQuestionDuration,
      onTick: (remaining) {
        state =
            state.copyWith(timer: state.timer?.copyWith(timeLeft: remaining));
      },
      onFinish: () {
        handleAnswer('');
      },
    )..start();
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

  void _emitWrong(
    String question,
    String userAnswer,
    String correctAnswer, [
    List<String> allCorrectAnswers = const [],
  ]) {
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
          allCorrectAnswers: allCorrectAnswers,
        ),
      ],
    );
  }

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
      _emitWrong(
          q.questionText, answer, q.correctAnswer, q.allCorrectAnswers);
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
      duration: elapsed,
      mistakes: state.mistakes,
    );
    await repo.saveSession(session);
  }

  GameResult toResult() {
    return GameResult(
      gameType: config.gameType,
      score: state.score,
      baseXp: state.baseXp,
      bonusXp: state.bonusXp,
      correctCount: state.correctCount,
      wrongCount: state.wrongCount,
      elapsedSeconds: state.elapsedSeconds,
      mistakes: state.mistakes,
    );
  }

  @override
  void pause() {
    _sessionTimer.pause();
    _countdown?.pause();
  }

  @override
  void resume() {
    _sessionTimer.resume();
    _countdown?.resume();
  }

  @override
  void dispose() {
    _sessionTimer.dispose();
    _countdown?.dispose();
    super.dispose();
  }
}
