import 'dart:async';

import 'package:flutter/foundation.dart';

/// Operating mode for a [GameTimerController].
enum GameTimerMode {
  /// Counts up from zero — used when we only care about elapsed playtime.
  stopwatch,

  /// Counts down from a fixed [GameTimerController.duration] toward zero.
  countdown,
}

/// Immutable snapshot of a [GameTimerController].
///
/// UI listens to this value; it never reads the underlying [Stopwatch] or
/// [Timer]. That keeps the widget tree decoupled from timer internals and
/// makes the controller trivially testable.
@immutable
class GameTimerSnapshot {
  /// Total elapsed time in milliseconds since the most recent [reset]/start.
  final int elapsedMs;

  /// Remaining milliseconds for [GameTimerMode.countdown]. Always `null` in
  /// [GameTimerMode.stopwatch] mode.
  final int? remainingMs;

  /// True while the controller is actively ticking.
  final bool isRunning;

  /// True after [pause] until [resume]/[start]/[reset].
  final bool isPaused;

  /// True once a countdown has reached zero. Latches until [reset].
  final bool isCompleted;

  const GameTimerSnapshot({
    required this.elapsedMs,
    required this.remainingMs,
    required this.isRunning,
    required this.isPaused,
    required this.isCompleted,
  });

  static const GameTimerSnapshot zero = GameTimerSnapshot(
    elapsedMs: 0,
    remainingMs: null,
    isRunning: false,
    isPaused: false,
    isCompleted: false,
  );

  int get elapsedSeconds => elapsedMs ~/ 1000;
  int? get remainingSeconds => remainingMs == null ? null : remainingMs! ~/ 1000;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameTimerSnapshot &&
          other.elapsedMs == elapsedMs &&
          other.remainingMs == remainingMs &&
          other.isRunning == isRunning &&
          other.isPaused == isPaused &&
          other.isCompleted == isCompleted;

  @override
  int get hashCode =>
      Object.hash(elapsedMs, remainingMs, isRunning, isPaused, isCompleted);
}

/// Reusable, UI-agnostic timer for game sessions.
///
/// Why a single controller:
///   * Unscramble, IPA Match, and future games all need an elapsed/remaining
///     clock with the same lifecycle (start / pause / resume / reset / stop).
///   * Duplicating `Stopwatch` + `Timer.periodic` per game leaks bugs (forgot
///     to cancel the timer, drift between widgets, untestable side effects).
///   * UI binds to a [ValueListenable] — no rebuild storms, no game-specific
///     coupling, no widget dependencies inside the controller.
///
/// Lifecycle contract:
///   * Created in a stopped state with [GameTimerSnapshot.zero].
///   * [start] (re)starts from zero and emits ticks at [tickInterval].
///   * [pause] freezes elapsed time; [resume] continues without losing it.
///   * [reset] returns to the stopped/zero state without firing onCompleted.
///   * [stop] freezes the snapshot without firing onCompleted.
///   * [dispose] cancels the timer and prevents further callbacks.
class GameTimerController {
  GameTimerController({
    this.mode = GameTimerMode.stopwatch,
    Duration? duration,
    this.tickInterval = const Duration(seconds: 1),
    this.onCompleted,
  })  : assert(
          mode == GameTimerMode.stopwatch || duration != null,
          'countdown mode requires a non-null duration',
        ),
        assert(
          duration == null || duration > Duration.zero,
          'duration must be positive',
        ),
        _duration = duration,
        _snapshot = ValueNotifier<GameTimerSnapshot>(
          mode == GameTimerMode.countdown
              ? GameTimerSnapshot(
                  elapsedMs: 0,
                  remainingMs: duration!.inMilliseconds,
                  isRunning: false,
                  isPaused: false,
                  isCompleted: false,
                )
              : GameTimerSnapshot.zero,
        );

  final GameTimerMode mode;
  final Duration tickInterval;

  /// Fired exactly once per countdown completion. Not fired on [stop] /
  /// [reset] / [dispose]. Safe to be `null`.
  final VoidCallback? onCompleted;

  final Duration? _duration;
  final ValueNotifier<GameTimerSnapshot> _snapshot;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;
  bool _disposed = false;
  bool _completedFired = false;

  /// Listenable snapshot — bind to it via `ValueListenableBuilder`.
  ValueListenable<GameTimerSnapshot> get snapshot => _snapshot;

  GameTimerSnapshot get value => _snapshot.value;

  bool get isRunning => _stopwatch.isRunning;
  bool get isPaused => value.isPaused;
  bool get isCompleted => value.isCompleted;
  bool get isDisposed => _disposed;
  Duration? get duration => _duration;

  // ── Controls ───────────────────────────────────────────────────────────

  /// Resets to zero (or full duration) and starts ticking.
  void start() {
    if (_disposed) return;
    _stopwatch
      ..reset()
      ..start();
    _completedFired = false;
    _emit(isPaused: false, isCompleted: false);
    _spawnTicker();
  }

  /// Freezes the timer while preserving elapsed time.
  void pause() {
    if (_disposed || !_stopwatch.isRunning) return;
    _stopwatch.stop();
    _cancelTicker();
    _emit(isPaused: true);
  }

  /// Resumes from a paused state.
  void resume() {
    if (_disposed || _stopwatch.isRunning || value.isCompleted) return;
    _stopwatch.start();
    _emit(isPaused: false);
    _spawnTicker();
  }

  /// Convenience pause/resume toggle. No-op when stopped or completed.
  void togglePause() {
    if (_disposed || value.isCompleted) return;
    if (_stopwatch.isRunning) {
      pause();
    } else if (value.isPaused) {
      resume();
    }
  }

  /// Stops without resetting. No completion callback is fired.
  void stop() {
    if (_disposed) return;
    _stopwatch.stop();
    _cancelTicker();
    _emit(isPaused: false);
  }

  /// Convenience start/stop toggle.
  void toggleRunning() {
    if (_disposed) return;
    if (_stopwatch.isRunning) {
      stop();
    } else {
      start();
    }
  }

  /// Returns to the initial stopped/zero state.
  void reset() {
    if (_disposed) return;
    _stopwatch
      ..stop()
      ..reset();
    _cancelTicker();
    _completedFired = false;
    _snapshot.value = mode == GameTimerMode.countdown
        ? GameTimerSnapshot(
            elapsedMs: 0,
            remainingMs: _duration!.inMilliseconds,
            isRunning: false,
            isPaused: false,
            isCompleted: false,
          )
        : GameTimerSnapshot.zero;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _stopwatch.stop();
    _cancelTicker();
    _snapshot.dispose();
  }

  // ── Internals ──────────────────────────────────────────────────────────

  void _spawnTicker() {
    _cancelTicker();
    _ticker = Timer.periodic(tickInterval, (_) => _tick());
  }

  void _cancelTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _tick() {
    if (_disposed) return;
    if (!_stopwatch.isRunning) return;

    final elapsed = _stopwatch.elapsedMilliseconds;
    if (mode == GameTimerMode.countdown) {
      final total = _duration!.inMilliseconds;
      final remaining = (total - elapsed).clamp(0, total);
      final completed = remaining == 0;
      _snapshot.value = GameTimerSnapshot(
        elapsedMs: elapsed,
        remainingMs: remaining,
        isRunning: !completed,
        isPaused: false,
        isCompleted: completed,
      );
      if (completed && !_completedFired) {
        _completedFired = true;
        _stopwatch.stop();
        _cancelTicker();
        onCompleted?.call();
      }
      return;
    }

    _snapshot.value = GameTimerSnapshot(
      elapsedMs: elapsed,
      remainingMs: null,
      isRunning: true,
      isPaused: false,
      isCompleted: false,
    );
  }

  void _emit({bool? isPaused, bool? isCompleted}) {
    final elapsed = _stopwatch.elapsedMilliseconds;
    final total = _duration?.inMilliseconds;
    _snapshot.value = GameTimerSnapshot(
      elapsedMs: elapsed,
      remainingMs: total == null ? null : (total - elapsed).clamp(0, total),
      isRunning: _stopwatch.isRunning,
      isPaused: isPaused ?? value.isPaused,
      isCompleted: isCompleted ?? value.isCompleted,
    );
  }
}
