/// Legacy error names — preserved for backward compatibility.
///
/// New code should use the typed hierarchy in `game_failure.dart`
/// ([GameFailure], [RepositoryFailure], [SessionFailure], …) rather than
/// these aliases.
library;
import 'game_failure.dart';

export 'game_failure.dart';

/// Alias for [GameFailure] — kept so existing call sites keep compiling.
class GameException extends GameFailure {
  const GameException(super.message, {super.cause});
}

/// Alias for [RepositoryFailure].
class RepositoryException extends RepositoryFailure {
  const RepositoryException(super.message, {super.cause});
}

/// Alias for [GenerationFailure] with the historical name.
class InsufficientQuestionsException extends GenerationFailure {
  const InsufficientQuestionsException({
    required super.requested,
    required super.available,
  });
}
