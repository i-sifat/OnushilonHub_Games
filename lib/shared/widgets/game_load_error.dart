import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shown when a game screen fails to load its questions.
class GameLoadError extends StatelessWidget {
  final String? error;
  final VoidCallback? onRetry;

  const GameLoadError({super.key, this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // FIX: Wrap in a SizedBox with a bounded width so that OutlinedButton /
    // FilledButton are never given an infinite width constraint.  Previously,
    // the Center → Padding → Column → Row tree left the Row unconstrained,
    // causing "BoxConstraints forces an infinite width" and a cascade of
    // layout assertion failures.
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: colorScheme.error),
              const SizedBox(height: 16),
              Text(
                'Could not load game data',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(
                  error!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 24),
              // FIX: Use an intrinsically-sized Row.  Each button is wrapped
              // in a SizedBox so it has an explicit bounded width instead of
              // trying to expand infinitely.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 120,
                    child: OutlinedButton(
                      onPressed: () => context.go('/games'),
                      child: const Text('Back'),
                    ),
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 120,
                      child: FilledButton(
                        onPressed: onRetry,
                        child: const Text('Retry'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
