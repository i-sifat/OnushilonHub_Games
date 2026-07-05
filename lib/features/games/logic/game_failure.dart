/// Unified failure hierarchy for the game layer (Task 8).
///
/// Every error surfaced from a builder, repository, controller or engine
/// extends [GameFailure] so callers can pattern-match on category instead of
/// catching generic [Exception]s. No code should `throw Exception(...)` —
/// pick the most specific subtype.
abstract class GameFailure implements Exception {
  final String message;
  final Object? cause;
  const GameFailure(this.message, {this.cause});

  @override
  String toString() => '$runtimeType: $message';
}

/// Data-source failure (DB unavailable, asset missing, malformed JSON, …).
class RepositoryFailure extends GameFailure {
  const RepositoryFailure(super.message, {super.cause});
}

/// Bundled asset could not be loaded / decoded.
class AssetFailure extends GameFailure {
  const AssetFailure(super.message, {super.cause});
}

/// Persisting / loading the current game session failed.
class SessionFailure extends GameFailure {
  const SessionFailure(super.message, {super.cause});
}

/// A generated question failed contract validation.
class ValidationFailure extends GameFailure {
  const ValidationFailure(super.message, {super.cause});
}

/// A builder could not generate enough valid questions to satisfy the
/// requested count.
class GenerationFailure extends GameFailure {
  final int requested;
  final int available;
  const GenerationFailure({
    required this.requested,
    required this.available,
    String? message,
  }) : super(message ??
            'Insufficient questions: requested $requested, only $available available.');
}
