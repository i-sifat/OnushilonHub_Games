import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/models/game_config.dart';
import '../../../database/database_service.dart';
import '../../../shared/widgets/loading_skeleton.dart';

// autoDispose so it refreshes each time the games tab is visited, but disposes
// when navigating away — prevents stale "continue playing" data.
final _continueGameProvider = FutureProvider.autoDispose<String?>((ref) async {
  return DatabaseService.instance.getMostRecentGameType();
});

// Game types shown in the hub — order determines display order.
// Icon, color, and subtitle data live on the GameType enum itself,
// so adding a new game type propagates everywhere with no extra duplication.
const _hubGameTypes = [
  GameType.unscramble,
  GameType.meaningChase,
  GameType.synonymMatch,
  GameType.antonymMatch,
  GameType.trueFalse,
  GameType.speedRacing,
  GameType.whoseQuote,
  GameType.ipaMatch,
  GameType.definitionMatch,
];

// ── Screen ─────────────────────────────────────────────────────────────────────
// Uses Column + Expanded instead of CustomScrollView to guarantee no scrolling.
// _ContinueBanner is isolated so it's the only widget that rebuilds when
// _continueGameProvider resolves — the game list stays completely inert.

class GamesHubScreen extends StatelessWidget {
  const GamesHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── AppBar ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.screenPaddingH,
                AppTokens.space16,
                AppTokens.screenPaddingH,
                AppTokens.space8,
              ),
              child: Text(
                'Games',
                style: textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),

            // ── Continue playing banner (isolated consumer) ─────────────
            const Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: AppTokens.screenPaddingH),
              child: _ContinueBanner(),
            ),

            // ── All Games header ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.screenPaddingH,
                AppTokens.space16,
                AppTokens.screenPaddingH,
                AppTokens.space10,
              ),
              child: Text(
                'All Games',
                style: textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),

            // ── Game list — Expanded so it fills remaining space ─────────
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.screenPaddingH),
                itemCount: _hubGameTypes.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppTokens.space8),
                itemBuilder: (context, i) =>
                    _GameRow(gameType: _hubGameTypes[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Continue banner — the ONLY widget that watches _continueGameProvider ──────
// Isolated so resolving the future never touches the game list rows.

class _ContinueBanner extends ConsumerWidget {
  const _ContinueBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final continueAsync = ref.watch(_continueGameProvider);
    return continueAsync.when(
      data: (gameType) {
        if (gameType == null) return const SizedBox.shrink();
        final gt = GameType.fromString(gameType);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Continue playing',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppTokens.space10),
            _ContinueCard(gameType: gt),
          ],
        );
      },
      loading: () => const SkeletonCard(height: 72),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

// ── Continue playing card ─────────────────────────────────────────────────────
// Uses icon/color from GameType enum — no more hardcoded shuffle icon.

class _ContinueCard extends StatelessWidget {
  final GameType gameType;
  const _ContinueCard({required this.gameType});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final route = '/games/pre/${gameType.dbKey}';

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space16, vertical: AppTokens.space12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        border:
            Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: gameType.iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(gameType.icon, color: gameType.iconColor, size: 22),
          ),
          const SizedBox(width: AppTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(gameType.label,
                    style: textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Text(gameType.subtitle,
                    style: textTheme.bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          FilledButton(
            onPressed: () => context.go(route),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(90, 38),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusSmall)),
              textStyle:
                  textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}

// ── Individual game row ───────────────────────────────────────────────────────
// StatelessWidget — zero state, zero unnecessary rebuilds.

class _GameRow extends StatelessWidget {
  final GameType gameType;
  const _GameRow({required this.gameType});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final route = '/games/pre/${gameType.dbKey}';

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        onTap: () => context.go(route),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.space16, vertical: AppTokens.space14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
            border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: gameType.iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(gameType.icon, color: gameType.iconColor, size: 22),
              ),
              const SizedBox(width: AppTokens.space14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(gameType.label,
                        style: textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(gameType.subtitle,
                        style: textTheme.bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: colorScheme.onSurfaceVariant, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
