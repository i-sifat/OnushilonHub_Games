import 'package:flutter/material.dart';
import 'game_exit_dialog.dart';

/// Mixin for game screen [State] classes that need:
///   1. Intercept system/app-bar back → show exit confirmation dialog.
///   2. Pause/resume game controller on app lifecycle changes.
///
/// Apply with:
/// ```dart
/// class _MyGameScreenState extends State<MyGameScreen>
///     with GameScreenLifecycleMixin {
///   @override
///   PausableGameController? get pausableController => _ctrl;
/// }
/// ```
mixin GameScreenLifecycleMixin<T extends StatefulWidget> on State<T> {
  // ── Override this to enable pause/resume on lifecycle changes ─────────────

  /// Return the active game controller so the mixin can pause/resume it
  /// when the app goes to background. Return null to skip lifecycle handling.
  PausableGameController? get pausableController => null;

  // ── Internal observer – kept private so it doesn't pollute the API ────────
  late final _LifecycleObserver _observer;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _observer = _LifecycleObserver(onStateChange: _handleLifecycleChange);
    WidgetsBinding.instance.addObserver(_observer);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_observer);
    super.dispose();
  }

  void _handleLifecycleChange(AppLifecycleState state) {
    final ctrl = pausableController;
    if (ctrl == null) return;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        ctrl.pauseTimer();
      case AppLifecycleState.resumed:
        ctrl.resumeTimer();
      case AppLifecycleState.detached:
        break;
    }
  }

  // ── Exit Guard ────────────────────────────────────────────────────────────

  /// Show the exit confirmation dialog. Returns true if the user confirmed exit.
  Future<bool> handleGameExitAttempt() async {
    if (!mounted) return true;
    return showGameExitDialog(context);
  }
}

/// A minimal [WidgetsBindingObserver] that only forwards lifecycle state changes.
/// Using a private helper class avoids requiring the mixin user to implement
/// the full [WidgetsBindingObserver] interface.
class _LifecycleObserver extends WidgetsBindingObserver {
  final void Function(AppLifecycleState) onStateChange;

   _LifecycleObserver({required this.onStateChange});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    onStateChange(state);
  }
}

/// Interface for controllers that support pause/resume (e.g. timers).
abstract interface class PausableGameController {
  void pauseTimer();
  void resumeTimer();
}
