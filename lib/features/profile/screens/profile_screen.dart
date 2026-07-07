//home/claude/OnushilonHub/lib/features/profile/screens/profile_screen.dart

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

/// Incrementing counter used to force-refresh profile data after a game.
/// Replacing the old StreamController pattern (which leaked listeners).
class ProfileRefreshCounterNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void increment() => state++;
  // Backward-compatible shim — matches the StateProvider.notifier.update()
  // call pattern used in ResultsScreen while StateProvider migration is pending.
  void update(int Function(int) fn) => state = fn(state);
}

final profileRefreshCounterProvider =
    NotifierProvider<ProfileRefreshCounterNotifier, int>(
  ProfileRefreshCounterNotifier.new,
);

final _profileStatsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  ref.watch(profileRefreshCounterProvider);
  return DatabaseService.instance.getProfileStats();
});

final _profileProgressProvider =
    FutureProvider<UserProgressModel>((ref) async {
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
            // ── App Bar ──────────────────────────────────────────────────
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
                    // ── Hero Card ─────────────────────────────────────────
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
                    // ── Statistics ────────────────────────────────────────
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
                    // ── Game Breakdown ────────────────────────────────────
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
                    // ── Saved Words ───────────────────────────────────────
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

// ── Hero Card ────────────────────────────────────────────────────────────────

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
                    color: Colors.white, size: 32),
              ),
              const SizedBox(width: AppTokens.space12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppTokens.space4),
                  Text(
                    'Level $level',
                    style: textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space16),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
            child: LinearProgressIndicator(
              value: LevelCalculator.progressToNextLevel(progress.totalXp),
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: AppTokens.space8),
          // XP and sessions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${progress.totalXp} XP',
                style: textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                ),
              ),
              Text(
                '$totalSessions Sessions',
                style: textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Overall Stats ────────────────────────────────────────────────────────────

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
    final accuracy =
        totalWords > 0 ? (totalCorrect / totalWords) * 100 : 0;

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
          const Divider(),
          _StatRow(
            label: 'Total Time',
            value: '${(totalTime / 60).toStringAsFixed(1)} mins',
          ),
          const Divider(),
          _StatRow(
            label: 'Total Words',
            value: totalWords.toString(),
          ),
          const Divider(),
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.space8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: textTheme.bodyMedium),
          Text(value,
              style: textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Game Breakdown ───────────────────────────────────────────────────────────

class _GameBreakdownChart extends StatelessWidget {
  final List<Map<String, dynamic>> gameStats;

  const _GameBreakdownChart({required this.gameStats});

  @override
  Widget build(BuildContext context) {
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
        children: [
          for (final game in gameStats)
            _GameStatRow(
              gameName: game['gameName'] as String,
              count: game['count'] as int,
              totalGames: totalGames,
            ),
        ],
      ),
    );
  }
}

class _GameStatRow extends StatelessWidget {
  final String gameName;
  final int count;
  final int totalGames;

  const _GameStatRow({
    required this.gameName,
    required this.count,
    required this.totalGames,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final percentage = (count / totalGames) * 100;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.space8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(gameName, style: textTheme.bodyMedium),
          ),
          Expanded(
            flex: 2,
            child: LinearProgressIndicator(
              value: count / totalGames,
              backgroundColor: AppColors.primary.withOpacity(0.2),
              color: AppColors.primary,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '${percentage.toStringAsFixed(1)}%',
              style: textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty Breakdown ──────────────────────────────────────────────────────────

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

// ── Saved Words Entry ────────────────────────────────────────────────────────

class _SavedWordsEntry extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedWords = ref.watch(savedWordsProvider);
    final textTheme = Theme.of(context).textTheme;

    return savedWords.when(
      data: (words) {
        if (words.isEmpty) {
          return const SizedBox();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Saved Words',
                style: textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppTokens.space16),
            for (final word in words)
              Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: AppTokens.space8),
                child: Text(word, style: textTheme.bodyMedium),
              ),
          ],
        );
      },
      loading: () => const SkeletonCard(height: 100),
      error: (_, __) => const SizedBox(),
    );
  }
}
