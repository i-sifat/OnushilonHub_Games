import 'dart:async';

/// Single source of truth for any countdown timer used by the game layer.
///
/// Responsibilities:
///   * start / pause / resume / stop
///   * tick at a fixed interval
///   * report remaining time
///   * fire a one-shot completion callback when time reaches zero
///   * be safe to dispose: no callbacks fire after [dispose]
///
/// Owners (e.g. [McqGameController]) construct one engine per active question
/// and call [dispose] when the question is answered or the controller is torn
/// down. The engine never reaches into game/UI state itself — it only emits
/// the current remaining time via [onTick] and a single [onComplete] when
/// the countdown elapses naturally.
class CountdownEngine {
  /// Total countdown duration in seconds.
  final double duration;

  /// Tick interval. Defaults to 100 ms which is smooth enough for an animated
  /// timer bar while keeping CPU work negligible.
  final Duration tickInterval;

  /// Fired on every tick with the new remaining time (0.0 … [duration]).
  final void Function(double remaining) onTick;

  /// Fired exactly once when remaining time reaches zero. Not fired when
  /// [stop] or [dispose] is called manually.
  final void Function() onComplete;

  double _remaining;
  Timer? _timer;
  bool _disposed = false;
  bool _completedFired = false;

  CountdownEngine({
    required this.duration,
    required this.onTick,
    required this.onComplete,
    this.tickInterval = const Duration(milliseconds: 100),
  }) : _remaining = duration;

  double get remaining => _remaining;
  bool get isRunning => _timer?.isActive == true;
  bool get isDisposed => _disposed;

  /// Resets remaining time to [duration] and starts ticking.
  void start() {
    if (_disposed) return;
    _remaining = duration;
    _completedFired = false;
    _spawnTimer();
  }

  /// Pauses ticking. [remaining] is preserved.
  void pause() {
    _timer?.cancel();
    _timer = null;
  }

  /// Resumes ticking from the current [remaining].
  void resume() {
    if (_disposed || isRunning || _remaining <= 0) return;
    _spawnTimer();
  }

  /// Stops the timer without firing [onComplete].
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }

  void _spawnTimer() {
    _timer?.cancel();
    final delta = tickInterval.inMilliseconds / 1000.0;
    _timer = Timer.periodic(tickInterval, (t) {
      if (_disposed) {
        t.cancel();
        return;
      }
      _remaining = (_remaining - delta).clamp(0.0, duration);
      onTick(_remaining);
      if (_remaining <= 0 && !_completedFired) {
        _completedFired = true;
        t.cancel();
        _timer = null;
        if (!_disposed) onComplete();
      }
    });
  }
}
