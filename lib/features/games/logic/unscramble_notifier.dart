import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/models/game_config.dart';
import '../../../core/models/user_progress_model.dart';
import '../../../core/models/word_model.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/timer/game_timer_controller.dart';
import '../../../core/utils/canonical_key.dart';
import '../../../database/i_game_repository.dart';
import '../../../shared/widgets/game_screen_lifecycle_mixin.dart';
import 'game_failure.dart';
import 'game_rules.dart';
import 'state/unscramble_game_state.dart';

/// Riverpod-owned game logic for the Unscramble game.
///
/// Two architectural upgrades over the previous version:
///
/// 1. **Canonical-key answers** — a question is no longer locked to a single
///    DB word. Words sharing a canonical signature (sorted letters) are
///    grouped together, and any anagram of that set is accepted. So a
///    scramble of `owlf` correctly accepts both `wolf` and `flow`.
/// 2. **Reusable timer** — elapsed-time tracking is delegated to
///    [GameTimerController]; no more bespoke `Stopwatch + Timer.periodic`
///    coupling, no duplicated logic with the MCQ notifier.
class UnscrambleNotifier extends StateNotifier<UnscrambleGameState>
    implements PausableGameController {
  UnscrambleNotifier({
    required this.config,
    required this.repo,
  }) : super(const UnscrambleGameState()) {
    _timer = GameTimerController(mode: GameTimerMode.stopwatch)..start();
    _timer.snapshot.addListener(_onTimerTick);
  }

  final GameConfig config;
  final IGameRepository repo;
  late final GameTimerController _timer;

  // ── Initialisation ────────────────────────────────────────────────────────

  Future<void> initialize() async {
    state = state.copyWith(isLoading: true, initError: null);
    try {
      await _loadQuestions().timeout(
        GameRules.initializeTimeout,
        onTimeout: () =>
            throw const SessionFailure('Game data load timed out'),
      );
    } catch (e, stack) {
      state = state.copyWith(
        isLoading: false,
        initError: _humanise(e),
      );
      assert(() {
        debugPrint('UnscrambleNotifier.initialize failed: $e\n$stack');
        return true;
      }());
    }
  }

  Future<void> _loadQuestions() async {
    final requested = config.questionCount > 0
        ? config.questionCount
        : GameRules.defaultQuestionCount;
    final words = await repo.getEligibleWords(
      gameType: config.gameType.dbKey,
      difficulty: config.difficulty,
      limit: requested * GameRules.unscrambleOverfetchFactor,
    );

    final withBangla = words.where((w) => w.banglaMeaning.isNotEmpty).toList();

    final (minLen, maxLen) = GameRules
            .unscrambleLengthByDifficulty[config.difficulty] ??
        (null, null);
    final filtered = withBangla.where((w) {
      final len = w.word.length;
      if (minLen != null && len < minLen) return false;
      if (maxLen != null && len > maxLen) return false;
      return true;
    }).toList();

    final source = filtered.isNotEmpty
        ? filtered
        : withBangla.isNotEmpty
            ? withBangla
            : words;

    // ── Group by canonical key ──────────────────────────────────────────
    //
    // Every word in `source` is bucketed by `canonicalKey(word)`. All words
    // in the same bucket are anagrams of each other and form a single
    // Unscramble group, so any of them is an accepted answer.
    //
    // The grouping is built from the *candidate pool* we already loaded so
    // we never make extra DB calls and never accept words the player would
    // have no way to know are valid (i.e. words not in the user's level).
    final groupsByKey = <String, List<WordModel>>{};
    for (final w in source) {
      final key = canonicalKey(w.word);
      if (key.isEmpty) continue; // skip non-alphabetic entries defensively
      (groupsByKey[key] ??= <WordModel>[]).add(w);
    }

    final rng = Random();
    final pickedKeys = <String>{};
    final unique = <UnscrambleQuestion>[];

    for (final w in source) {
      final key = canonicalKey(w.word);
      if (key.isEmpty) continue;
      if (!pickedKeys.add(key)) continue; // already picked this anagram set

      final group = groupsByKey[key]!;

      // P2: Pick the semantically richest word as primaryWord instead of the
      // first random occurrence. This prevents obscure words (e.g. INGRES,
      // LATTEN) from becoming the primary when common words (SINGER, TALENT)
      // are in the same anagram group.
      final primary = _bestPrimary(group);

      // Build a word→meaning map for every member of this anagram group so
      // P1 can show the correct meaning for whichever word the player typed.
      final validWordMeanings = <String, String>{
        for (final entry in group)
          entry.word.toLowerCase().trim(): entry.banglaMeaning,
      };

      final validWords = validWordMeanings.keys
          .where((s) => s.isNotEmpty)
          .toList();
      if (validWords.isEmpty) continue;

      unique.add(UnscrambleQuestion(
        primaryWord: primary,
        scrambled: _scramble(primary.word, rng),
        banglaMeaning: primary.banglaMeaning,
        canonicalKey: key,
        validWords: validWords,
        validWordMeanings: validWordMeanings,
      ));
    }

    unique.shuffle(rng);
    final questions = unique.take(requested).toList();

    if (questions.isEmpty) {
      throw const GenerationFailure(
        requested: 0,
        available: 0,
        message: 'No unscramble words are available for this difficulty.',
      );
    }

    state = state.copyWith(
      isLoading: false,
      questions: questions,
      sessionTruncated: questions.length < requested,
    );
  }

  /// Scrambles [word] using Fisher-Yates with a validation loop.
  String _scramble(String word, Random rng) {
    final upper = word.toUpperCase();
    final chars = upper.split('');
    if (chars.length <= 1) return upper;

    for (int attempt = 0;
        attempt < GameRules.unscrambleMaxScrambleAttempts;
        attempt++) {
      for (int i = chars.length - 1; i > 0; i--) {
        final j = rng.nextInt(i + 1);
        final tmp = chars[i];
        chars[i] = chars[j];
        chars[j] = tmp;
      }
      final candidate = chars.join();
      if (candidate != upper) return candidate;
    }
    // Last resort: swap first two characters.
    final fallback = chars.toList();
    final tmp = fallback[0];
    fallback[0] = fallback[1];
    fallback[1] = tmp;
    return fallback.join();
  }

  /// P2 — Scores each word in an anagram group and returns the best one to
  /// use as [UnscrambleQuestion.primaryWord].
  ///
  /// Scoring (higher = better primary):
  ///   +3  has a Bengali meaning       (essential for Show Meaning button)
  ///   +3  has an English definition   (not just Bengali falling back)
  ///   +2  has synonyms                (richer vocabulary context)
  ///   -1  per 3 letters beyond 4      (shorter words are generally more common)
  ///
  /// Ties are broken by the element that appears first in the list (which is
  /// already ORDER BY RANDOM() from the DB, giving uniform tie-breaking).
  WordModel _bestPrimary(List<WordModel> group) {
    int score(WordModel w) {
      int s = 0;
      if (w.banglaMeaning.isNotEmpty) s += 3;
      // English definition is distinct from Bengali only when it's not the
      // Bengali string used as a fallback in _loadWordRows.
      if (w.definition.isNotEmpty && w.definition != w.banglaMeaning) s += 3;
      if (w.synonyms.isNotEmpty) s += 2;
      final extra = (w.word.length - 4).clamp(0, 999);
      s -= extra ~/ 3;
      return s;
    }

    return group.reduce((best, candidate) =>
        score(candidate) > score(best) ? candidate : best);
  }

  // ── Tile interaction ─────────────────────────────────────────────────────

  void tapTile(int index) {
    final q = state.currentQuestion;
    if (q == null || state.isAnswered || state.selectedIndices.contains(index)) {
      return;
    }
    final newSel = [...state.selectedIndices, index];
    state = state.copyWith(selectedIndices: newSel);

    final letters = q.scrambled.split('');
    if (newSel.length == letters.length) {
      _submitAnswer(q, letters, newSel);
    }
  }

  void removeLast() {
    if (state.isAnswered || state.selectedIndices.isEmpty) return;
    state = state.copyWith(
      selectedIndices: state.selectedIndices.sublist(
        0,
        state.selectedIndices.length - 1,
      ),
    );
  }

  void useHint() {
    final q = state.currentQuestion;
    if (q == null || state.isAnswered || state.hintUsed) return;
    final letters = q.scrambled.split('');
    // Hint uses the primary word as the spelling guide — that is the word
    // whose meaning the player will see, so it is the natural target.
    final target = q.primaryWord.word;
    final nextPos = state.selectedIndices.length;
    if (nextPos >= target.length) return;
    final targetChar = target[nextPos];

    for (int i = 0; i < letters.length; i++) {
      if (!state.selectedIndices.contains(i) &&
          letters[i].toLowerCase() == targetChar.toLowerCase()) {
        final newSel = [...state.selectedIndices, i];
        state = state.copyWith(selectedIndices: newSel, hintUsed: true);
        if (newSel.length == letters.length) {
          _submitAnswer(q, letters, newSel);
        }
        return;
      }
    }
  }

  void toggleMeaning() {
    state = state.copyWith(meaningVisible: !state.meaningVisible);
  }

  Future<void> _submitAnswer(
      UnscrambleQuestion q, List<String> letters, List<int> indices) async {
    final answer = indices.map((i) => letters[i]).join();
    await handleAnswer(answer);
  }

  Future<void> handleAnswer(String userAnswer) async {
    final q = state.currentQuestion;
    if (q == null || state.isAnswered) return;

    // Canonical match — accepts any valid anagram, not just the primary word.
    final correct = q.acceptsAnswer(userAnswer);

    if (correct) {
      HapticFeedback.mediumImpact();
      state = state.copyWith(
        isAnswered: true,
        lastAnswerCorrect: true,
        playerAnswer: userAnswer.trim(),  // P1: store for meaning lookup
        score: state.score + AppTokens.xpPerCorrect,
        baseXp: state.baseXp + AppTokens.xpPerCorrect,
        correctCount: state.correctCount + 1,
      );
    } else {
      HapticFeedback.heavyImpact();
      // P1/P3: correctAnswer lists all valid words so the review screen is
      // informative even when multiple anagrams exist.
      final allValid = q.validWords.map((w) => w.toUpperCase()).join(' / ');
      state = state.copyWith(
        isAnswered: true,
        lastAnswerCorrect: false,
        playerAnswer: userAnswer.trim(),  // P1: store for meaning lookup
        wrongCount: state.wrongCount + 1,
        mistakes: [
          ...state.mistakes,
          MistakeItem(
            question: q.scrambled,
            userAnswer: userAnswer.trim(),
            correctAnswer: allValid.isNotEmpty ? allValid : q.displayAnswer,
          ),
        ],
      );
    }
    // ignore: unawaited_futures
    repo.markWordStatus(
      wordId: q.primaryWord.id,
      gameType: config.gameType.dbKey,
      status: correct ? 'mastered' : 'mistake',
    );
  }

  Future<void> nextQuestion() async {
    if (state.currentIndex >= state.totalQuestions - 1) {
      await _finishGame();
      return;
    }
    state = state.copyWith(
      currentIndex: state.currentIndex + 1,
      isAnswered: false,
      selectedIndices: const [],
      hintUsed: false,
      meaningVisible: false,
      playerAnswer: '',  // P1: clear for next question
    );
  }

  Future<void> _finishGame() async {
    _timer.stop();
    final elapsed = _timer.value.elapsedSeconds;
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
        durationSeconds: _timer.value.elapsedSeconds,
        baseXp: state.baseXp,
        bonusXp: state.bonusXp,
        mistakes: state.mistakes,
      );

  /// Exposes the underlying timer snapshot so the screen can render the
  /// clock with a `ValueListenableBuilder` instead of rebuilding the whole
  /// notifier on every tick.
  ValueListenable<GameTimerSnapshot> get timerSnapshot => _timer.snapshot;

  // ── Pause / resume ───────────────────────────────────────────────────────

  @override
  void pauseTimer() => _timer.pause();

  @override
  void resumeTimer() {
    if (state.isFinished) return;
    _timer.resume();
  }

  void _onTimerTick() {
    final seconds = _timer.value.elapsedSeconds;
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
    _timer.snapshot.removeListener(_onTimerTick);
    _timer.dispose();
    try {
      repo.clearGameCache();
    } catch (_) {/* defensive */}
    super.dispose();
  }
}
