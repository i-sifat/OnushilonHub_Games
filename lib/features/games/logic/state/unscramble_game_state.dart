import '../../../../core/models/game_config.dart' show MistakeItem;
import '../../../../core/models/word_model.dart';
import '../../../../core/utils/canonical_key.dart' as canonical_utils;
import 'game_session_state.dart';

/// A single Unscramble question.
///
/// As of the canonical-answer upgrade, a question is no longer tied to a
/// single "correct" word. Instead it carries:
///
///   * [scrambled]      — the letters the player must rearrange
///   * [canonicalKey]   — sorted-letters signature shared by every valid
///                        anagram (`canonicalKey('wolf') == 'flow'`)
///   * [validWords]     — lowercase list of every accepted answer
///   * [primaryWord]    — the DB row used for meaning / id (any one of the
///                        valid answers)
///
/// Validation is performed by canonical key, not string equality, so
/// "owlf" accepts both "wolf" and "flow".
class UnscrambleQuestion {
  final WordModel primaryWord;
  final String scrambled;
  final String banglaMeaning;
  final String canonicalKey;
  final List<String> validWords;

  /// P1 — Maps every valid answer (lowercase) to its own Bengali meaning.
  /// Used by the screen to show the meaning of the word the player TYPED,
  /// not just the primaryWord's meaning.
  final Map<String, String> validWordMeanings;

  const UnscrambleQuestion({
    required this.primaryWord,
    required this.scrambled,
    required this.banglaMeaning,
    required this.canonicalKey,
    required this.validWords,
    this.validWordMeanings = const {},
  });

  /// Backwards-compatible getter for code that previously accessed `.word`.
  WordModel get word => primaryWord;

  /// Display word for feedback when the player is wrong — we surface the
  /// primary DB word (the one whose meaning is shown).
  String get displayAnswer => primaryWord.word;

  /// P1 — Returns the Bengali meaning for [answer] as typed by the player.
  /// Falls back to [banglaMeaning] (primaryWord's meaning) if the typed word
  /// has no own entry in the map (e.g. it was not in the candidate pool).
  String meaningForAnswer(String answer) {
    final key = answer.toLowerCase().trim();
    final found = validWordMeanings[key];
    if (found != null && found.isNotEmpty) return found;
    return banglaMeaning;
  }

  /// True when [answer] is accepted as a correct unscramble of [scrambled].
  ///
  /// Uses canonical-key comparison so any valid anagram is accepted, even if
  /// the player's spelling differs from `primaryWord.word`.
  bool acceptsAnswer(String answer) {
    final key = canonical_utils.canonicalKey(answer);
    if (key.isEmpty) return false;
    return key == canonicalKey;
  }
}

/// Immutable state for an Unscramble session (Task 2).
class UnscrambleGameState implements GameSessionState {
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

  final List<UnscrambleQuestion> questions;

  /// Indices of scrambled-letter tiles the player has tapped, in order.
  final List<int> selectedIndices;
  final bool hintUsed;
  final bool meaningVisible;

  /// P1 — The exact string the player submitted for the current question.
  /// Used to look up the correct meaning via [UnscrambleQuestion.meaningForAnswer].
  final String playerAnswer;

  /// True when the requested question count could not be filled.
  final bool sessionTruncated;

  const UnscrambleGameState({
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
    this.selectedIndices = const [],
    this.hintUsed = false,
    this.meaningVisible = false,
    this.sessionTruncated = false,
    this.playerAnswer = '',
  });

  @override
  int get totalQuestions => questions.length;

  UnscrambleQuestion? get currentQuestion =>
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

  bool isIndexSelected(int i) => selectedIndices.contains(i);

  UnscrambleGameState copyWith({
    bool? isLoading,
    Object? initError = _sentinel,
    List<UnscrambleQuestion>? questions,
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
    List<int>? selectedIndices,
    bool? hintUsed,
    bool? meaningVisible,
    bool? sessionTruncated,
    String? playerAnswer,
  }) {
    return UnscrambleGameState(
      isLoading: isLoading ?? this.isLoading,
      initError: identical(initError, _sentinel)
          ? this.initError
          : initError as String?,
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
      selectedIndices: selectedIndices ?? this.selectedIndices,
      hintUsed: hintUsed ?? this.hintUsed,
      meaningVisible: meaningVisible ?? this.meaningVisible,
      sessionTruncated: sessionTruncated ?? this.sessionTruncated,
      playerAnswer: playerAnswer ?? this.playerAnswer,
    );
  }

  static const _sentinel = Object();
}
