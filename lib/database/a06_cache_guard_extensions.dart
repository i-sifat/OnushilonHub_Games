import 'dart:async';
import 'game_data_repository.dart';

/// A-06: Cache concurrency guard helpers.
///
/// The mutable [List?] caches in [GameDataRepository] are not concurrency-safe:
/// if two async [build] calls fire simultaneously (e.g. user taps Start twice
/// quickly) both find null and trigger a double-load.
///
/// Solution pattern (Completer-based mutex):
///
/// ```dart
/// Completer<void>? _ipaLoad;
///
/// Future<void> _guardedLoadIpa(int limit) async {
///   if (_ipaCache != null) return;          // fast path
///   if (_ipaLoad != null) {                 // another load is in flight
///     await _ipaLoad!.future;
///     return;
///   }
///   _ipaLoad = Completer();
///   try {
///     await _loadIpaFromDb(limit);
///     _ipaLoad!.complete();
///   } catch (e, st) {
///     _ipaLoad!.completeError(e, st);
///     rethrow;
///   } finally {
///     _ipaLoad = null;
///   }
/// }
/// ```
///
/// Apply the same pattern for [_definitionCache], [_synonymCache],
/// [_antonymCache], and [_richQuoteCache] in [GameDataRepository].
///
/// This file provides a [ConcurrentLoadGuard] utility class that encapsulates
/// the completer pattern, ready to be used inline in [GameDataRepository].
class ConcurrentLoadGuard<T> {
  Completer<T>? _completer;

  /// Returns true if a load is currently in progress.
  bool get isLoading => _completer != null && !_completer!.isCompleted;

  /// Awaits the in-flight load if one exists; otherwise returns immediately.
  Future<void> awaitIfLoading() async {
    if (isLoading) await _completer!.future;
  }

  /// Runs [loader] exactly once, returning the result.
  /// Concurrent calls wait on the same [Completer] instead of triggering
  /// duplicate loads.
  Future<T> run(Future<T> Function() loader) async {
    if (_completer != null) return _completer!.future;
    _completer = Completer<T>();
    try {
      final result = await loader();
      _completer!.complete(result);
      return result;
    } catch (e, st) {
      _completer!.completeError(e, st);
      rethrow;
    } finally {
      _completer = null;
    }
  }
}
