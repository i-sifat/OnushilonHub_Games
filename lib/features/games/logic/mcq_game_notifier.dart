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
      var questions = await builder.build(config).timeout(
        GameRules.initializeTimeout,
        onTimeout: () =>
            throw const SessionFailure('Game data load timed out'),
      );
      // UX-01: Practice Mistakes — when forcedWordIds is set, keep only the
      // questions whose wordId matches. This replays exactly the words the
      // player got wrong in the previous session. Falls back to the full set
      // if none of the built questions match (e.g. asset-backed game types
      // like Whose Quote whose questions don't carry a DB wordId).
      if (config.forcedWordIds.isNotEmpty) {
        final forced = questions
            .where((q) => config.forcedWordIds.contains(q.wordId))
            .toList();
        if (forced.isNotEmpty) questions = forced;
      }
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
    _countdown?.dispose();
    state = state.copyWith(timer: freshTimerState());
    _countdown = CountdownEngine(
      duration: GameRules.speedRacingTimerSeconds.toDouble(),
      onTick: (remaining) {
        state =
            state.copyWith(timer: state.timer?.copyWith(timeLeft: remaining));
      },
      onComplete: () {
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

  // UX-01: added optional `wordId` parameter — passed from McqQuestion.wordId
  // so MistakeItem records which DB word the player got wrong, enabling the
  // Practice Mistakes button to re-queue those exact words.
  void _emitWrong(
    String question,
    String userAnswer,
    String correctAnswer, [
    List<String> allCorrectAnswers = const [],
    int? wordId,
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
          wordId: wordId,
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
        q.questionText,
        answer,
        q.correctAnswer,
        q.allCorrectAnswers,
        q.wordId, // UX-01: thread wordId into MistakeItem
      );
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
      durationSeconds: elapsed,
      playedAt: DateTime.now(),
    );
    try {
      await repo.persistSession(session: session, xpEarned: state.score);
    } catch (e, stack) {
      state = state.copyWith(saveError: 'Failed to save your progress.');
      assert(() {
        debugPrint('Session persist failed: $e\n$stack');
        return true;
      }());
    }
  }

  GameResult buildResult() {
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
  void pauseTimer() {
    _sessionTimer.pause();
    _countdown?.pause();
  }

  @override
  void resumeTimer() {
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
