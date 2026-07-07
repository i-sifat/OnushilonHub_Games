import 'package:flutter/material.dart';
import 'dart:math' show pi;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/game_config.dart';
import '../../../core/models/user_progress_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/level_calculator.dart';
import '../../../database/database_service.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../core/providers/saved_words_provider.dart';

/// A-05: Replaced deprecated StateProvider (from legacy.dart) with a
/// Notifier. The counter increment pattern maps to a one-line [increment]
/// method — semantics are identical, legacy import is removed.
class _ProfileRefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void increment() => state++;
}

/// Incrementing counter used to force-refresh profile data after a game.
/// Replacing the old StreamController pattern (which leaked listeners).
final profileRefreshCounterProvider =
    NotifierProvider<_ProfileRefreshNotifier, int>(
  _ProfileRefreshNotifier.new,
);

final _profileStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  ref.watch(profileRefreshCounterProvider);
  return DatabaseService.instance.getProfileStats();
});

final _profileProgressProvider = FutureProvider<UserProgressModel>((ref) async {
  ref.watch(profileRefreshCounterProvider);
  return DatabaseService.instance.getUserProgress();
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(_profileStatsProvider);
    final progressAsync = ref.watch(_profileProgressProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── App Bar ──────────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.screenPaddingH,
                vertical: AppTokens.space12,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Profile',
                      style: textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  IconButton(
                    icon: const Icon(Icons.settings_rounded),
                    onPressed: () => context.push('/settings'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.screenPaddingH,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Hero Card ───────────────────────────────────────────────────
                    Builder(builder: (context) {
                      final sessions = statsAsync.when(
                        data: (s) => s['totalSessions'] as int,
                        loading: () => 0,
                        error: (_, __) => 0,
                      );
                      return progressAsync.when(
                        data: (p) =>
                            _HeroCard(progress: p, totalSessions: sessions),
                        loading: () => const SkeletonCard(height: 140),
                        error: (_, __) => const SizedBox(),
                      );
                    }),
                    const SizedBox(height: AppTokens.space24),
                    // ── Statistics ────────────────────────────────────────────────
                    Text('Statistics',
                        style: textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: AppTokens.space16),
                    statsAsync.when(
                      data: (stats) => _OverallStats(stats: stats),
                      loading: () => const SkeletonCard(height: 120),
                      error: (_, __) => const SizedBox(),
                    ),
                    const SizedBox(height: AppTokens.space24),
                    // ── Game Breakdown ────────────────────────────────────────────
                    Text('Game Breakdown',
                        style: textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: AppTokens.space16),
                    statsAsync.when(
                      data: (stats) {
                        final gameStats =
                            stats['gameStats'] as List<Map<String, dynamic>>;
                        if (gameStats.isEmpty) {
                          return _EmptyBreakdown();
                        }
                        return _GameBreakdownChart(gameStats: gameStats);
                      },
                      loading: () => const SkeletonCard(height: 180),
                      error: (_, __) => const SizedBox(),
                    ),
                    const SizedBox(height: AppTokens.space24),
                    // ── Saved Words ───────────────────────────────────────────────
                    _SavedWordsEntry(),
                    const SizedBox(height: AppTokens.space80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hero Card ────────────────────────────────────────────────────────────────────────────────
class _HeroCard extends ConsumerWidget {
  final UserProgressModel progress;
  final int totalSessions;

  const _HeroCard({required this.progress, required this.totalSessions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final name = ref.watch(userProfileProvider).name ?? '';
    final displayName =
        name.trim().isNotEmpty ? name.trim() : 'Learner';
    final level = LevelCalculator.levelFor(progress.totalXp);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
      ),
      padding: const EdgeInsets.all(AppTokens.space16),
      child: Column(
        children: [
          // Avatar row
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_rounded,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: AppTokens.space12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName,
                      style: textTheme.titleMedium
                          ?.copyWith(color: Colors.white)),
                  Text('Level $level',
                      style: textTheme.bodyMedium
                          ?.copyWith(color: Colors.white70)),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space16),
          // Progress bar
          LinearProgressIndicator(
            value: LevelCalculator.progressToNextLevel(progress.totalXp),
            backgroundColor: Colors.white.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
          const SizedBox(height: AppTokens.space8),
          Text('${progress.totalXp} XP',
              style: textTheme.bodyMedium?.copyWith(color: Colors.white70)),
          const SizedBox(height: AppTokens.space8),
          Text('$totalSessions Sessions',
              style: textTheme.bodyMedium?.copyWith(color: Colors.white70)),
        ],
      ),
    );
  }
}

// ── Overall Stats ─────────────────────────────────────────────────────────────────────────────
class _OverallStats extends StatelessWidget {
  final Map<String, dynamic> stats;

  const _OverallStats({required this.stats});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final totalSessions = stats['totalSessions'] as int;
    final totalTime = stats['totalTime'] as int;
    final totalWords = stats['totalWords'] as int;
    final totalCorrect = stats['totalCorrect'] as int;

    final accuracy = totalWords > 0 ? (totalCorrect / totalWords) * 100 : 0;

    return Container(
      padding: const EdgeInsets.all(AppTokens.space16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _StatRow(
            label: 'Total Sessions',
            value: totalSessions.toString(),
          ),
          const SizedBox(height: AppTokens.space12),
          _StatRow(
            label: 'Total Time',
            value: '${(totalTime / 60).toStringAsFixed(1)} mins',
          ),
          const SizedBox(height: AppTokens.space12),
          _StatRow(
            label: 'Total Words',
            value: totalWords.toString(),
          ),
          const SizedBox(height: AppTokens.space12),
          _StatRow(
            label: 'Accuracy',
            value: '${accuracy.toStringAsFixed(1)}%',
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: textTheme.bodyMedium),
        Text(value,
            style: textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _GameBreakdownChart extends StatelessWidget {
  final List<Map<String, dynamic>> gameStats;

  const _GameBreakdownChart({required this.gameStats});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final totalGames =
        gameStats.fold<int>(0, (sum, item) => sum + (item['count'] as int));

    return Container(
      padding: const EdgeInsets.all(AppTokens.space16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: gameStats.map((game) {
          final gameName = game['gameName'] as String;
          final count = game['count'] as int;
          final percentage = (count / totalGames) * 100;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTokens.space8),
            child: Row(
              children: [
                Expanded(
                  child: Text(gameName, style: textTheme.bodyMedium),
                ),
                Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _EmptyBreakdown extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppTokens.space16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          'No game data available',
          style: textTheme.bodyMedium
              ?.copyWith(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _SavedWordsEntry extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedWords = ref.watch(savedWordsProvider);

    return GestureDetector(
      onTap: () => context.push('/saved-words'),
      child: Container(
        padding: const EdgeInsets.all(AppTokens.space16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.bookmark_rounded, color: AppColors.primary),
            const SizedBox(width: AppTokens.space12),
            Expanded(
              child: Text(
                'Saved Words',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '${savedWords.length}',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
