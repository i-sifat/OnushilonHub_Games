import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';

/// Canonical elapsed-time display for game sessions.
///
/// Extracted from the Unscramble screen so every game that uses the shared
/// [GameTimerController] renders the clock with identical placement,
/// spacing, typography, icon, and color. UI-only — no controller coupling,
/// no rebuild on its own; the caller decides when to feed in a new value.
///
/// Pass [display] in `MM:SS` form (the canonical
/// `GameSessionState.elapsedDisplayTime` already produces this).
class GameElapsedTimer extends StatelessWidget {
  final String display;

  const GameElapsedTimer({super.key, required this.display});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.timer_outlined,
          size: 14,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppTokens.space4),
        Text(
          display,
          style: textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
