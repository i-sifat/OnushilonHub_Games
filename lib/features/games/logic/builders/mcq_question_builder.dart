import '../../../../core/models/game_config.dart';
import '../../../../database/game_data_repository.dart';
import '../game_rules.dart';
import 'mcq_question.dart';

/// Strategy interface — every MCQ-style game type has its own builder.
///
/// Builders are *pure* with respect to gameplay state: they receive a config,
/// pull data from the repository, and return a ready-to-play list of
/// [McqQuestion]. They never touch controllers, timers, scoring, or DB
/// services directly.
abstract class McqQuestionBuilder {
  const McqQuestionBuilder();
  Future<List<McqQuestion>> build(GameConfig config);
}

/// Resolves a [GameType] to its concrete builder.
///
/// Constructed once via Riverpod (see [questionBuilderFactoryProvider]).
class McqQuestionBuilderFactory {
  final Map<GameType, McqQuestionBuilder> _builders;

  const McqQuestionBuilderFactory(this._builders);

  /// Returns the builder for [type]. Throws [StateError] for an unknown type
  /// — that indicates a programming error, not a runtime data issue.
  McqQuestionBuilder get(GameType type) {
    final b = _builders[type];
    if (b == null) {
      throw StateError('No McqQuestionBuilder registered for $type');
    }
    return b;
  }

  bool supports(GameType type) => _builders.containsKey(type);
}

/// Helper used by every builder for resolving the effective question count.
int resolveQuestionCount(GameConfig config) =>
    config.questionCount > 0 ? config.questionCount : GameRules.defaultQuestionCount;

/// Common typedef to keep builder constructor signatures short.
typedef RepoRef = GameDataRepository;
