// ============================================================================
// game_exit_dialog.dart
//
// Thin convenience wrapper around AppDialogs.showGameExit so existing call
// sites (GameScreenLifecycleMixin and any direct callers) keep working
// without leaking AppDialogs into game-level code.
//
// The actual dialog UI and copy live in:
//   - lib/core/dialogs/confirmation_config.dart  (ConfirmationConfig.gameExit)
//   - lib/shared/widgets/app_dialogs.dart        (generic dialog shell)
// ============================================================================

import 'package:flutter/material.dart';

import 'app_dialogs.dart';

/// Shows the GAME exit confirmation dialog (NOT the app-exit dialog).
/// Returns `true` if the user confirmed leaving the game, `false` otherwise.
Future<bool> showGameExitDialog(BuildContext context) {
  return AppDialogs.showGameExit(context);
}
