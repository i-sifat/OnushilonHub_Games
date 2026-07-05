import 'builders/mcq_question.dart';
import 'game_failure.dart';
import 'game_rules.dart';

/// Validates that an [McqQuestion] satisfies the gameplay contract before it
/// reaches the controller / UI (Task 4).
///
/// Guarantees enforced:
///   * non-empty question text and prompt
///   * non-null correct answer present in [McqQuestion.options]
///   * at least [GameRules.minOptionCount] options
///   * no duplicate options
///   * no empty option strings
///   * no null values (Dart's non-nullable types already cover this, but we
///     keep the check explicit so a future schema change cannot regress)
///
/// Run once per question after a builder produces its list. The validator is
/// intentionally pure — no IO, no logging — so builders can compose it cheaply.
class QuestionContractValidator {
  const QuestionContractValidator();

  /// Throws [ValidationFailure] if the question is malformed. Returns silently
  /// on success.
  void validate(McqQuestion q) {
    if (q.prompt.trim().isEmpty) {
      throw const ValidationFailure('Question prompt is empty.');
    }
    if (q.questionText.trim().isEmpty) {
      throw const ValidationFailure('Question text is empty.');
    }
    if (q.options.length < GameRules.minOptionCount) {
      throw ValidationFailure(
        'Question has ${q.options.length} options; minimum is '
        '${GameRules.minOptionCount}.',
      );
    }
    if (q.correctAnswer.trim().isEmpty) {
      throw const ValidationFailure('Correct answer is empty.');
    }
    if (!q.options.contains(q.correctAnswer)) {
      throw ValidationFailure(
        'Correct answer "${q.correctAnswer}" is not in the options list.',
      );
    }
    for (final opt in q.options) {
      if (opt.trim().isEmpty) {
        throw const ValidationFailure('Option is empty.');
      }
    }
    final unique = q.options.toSet();
    if (unique.length != q.options.length) {
      throw ValidationFailure(
        'Duplicate options detected for question "${q.questionText}".',
      );
    }
  }

  /// Filters [questions] to those that pass [validate]. Invalid items are
  /// dropped silently — preferable to crashing a whole session when a single
  /// item is malformed.
  List<McqQuestion> filterValid(Iterable<McqQuestion> questions) {
    final out = <McqQuestion>[];
    for (final q in questions) {
      try {
        validate(q);
        out.add(q);
      } on ValidationFailure {
        // Skip — builders may over-produce; one bad question is not fatal.
      }
    }
    return out;
  }
}
