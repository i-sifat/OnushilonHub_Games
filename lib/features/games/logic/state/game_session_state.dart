import '../../../../core/models/game_config.dart' show MistakeItem;

/// Common immutable state owned by every game session (Task 2).
///
/// Concrete game states ([McqGameState], [UnscrambleGameState]) extend this
/// so the engine can share scoring / progress logic across game types.
abstract class GameSessionState {
  /// `true` while the initial question set is being loaded.
  bool get isLoading;

  /// Non-null when the initial load failed.
  String? get initError;

  /// Total questions in this session.
  int get totalQuestions;

  /// Zero-based index of the currently active question.
  int get currentIndex;

  /// `true` once the current question has been answered.
  bool get isAnswered;

  /// `true` after [nextQuestion] runs past the last question.
  bool get isFinished;

  /// Whether the last answer was correct (only meaningful when [isAnswered]).
  bool get lastAnswerCorrect;

  int get score;
  int get baseXp;
  int get bonusXp;
  int get correctCount;
  int get wrongCount;
  List<MistakeItem> get mistakes;

  /// Elapsed seconds since the session started.
  int get elapsedSeconds;

  /// Non-null when persisting the finished session failed. The UI may show
  /// a retry button without blocking navigation to the results screen.
  String? get saveError;

  double get progress =>
      totalQuestions > 0 ? currentIndex / totalQuestions : 0;

  String get elapsedDisplayTime {
    final secs = elapsedSeconds;
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
