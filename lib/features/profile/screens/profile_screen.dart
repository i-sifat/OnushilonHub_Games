//home/claude/OnushilonHub/lib/features/profile/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'dart:math' show pi;
import 'package:fl_chart/fl_chart.dart';
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
import '../../../core/providers/game_session_stats_provider.dart';

/// A-05: Replaced deprecated StateProvider (from legacy.dart) with a
/// Notifier. The counter increment pattern maps to a one-line [increment]
/// method — semantics are identical, legacy import is removed.
/// Backward-compatible [update] shim retained for existing call sites.
class ProfileRefreshCounterNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void increment() => state++;
  // Backward-compatible shim — matches the StateProvider.notifier.update()
  // call pattern used in ResultsScreen.
  void update(int Function(int) fn) => state = fn(state);
}

/// Incrementing counter used to force-refresh profile data after a game.
/// Replacing the old StreamController pattern (which leaked listeners).
final profileRefreshCounterProvider =
    NotifierProvider<ProfileRefreshCounterNotifier, int>(
  ProfileRefreshCounterNotifier.new,
);

final _profileStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  ref.watch(profileRefreshCounterProvider);
  return DatabaseService.instance.getProfileStats();
});

final _profileProgressProvider = FutureProvider<UserProgressModel>((ref) async {
  ref.watch(profileRefreshCounterProvider);
  return DatabaseService.instance.getUserProgress();
});

// UX-06: per-game mastery progress (mastered / total words seen per game type)
final _profileGameProgressProvider =
    FutureProvider<Map<String, Map<String, int>>>((ref) async {
  ref.watch(profileRefreshCounterProvider);
  final rows = await DatabaseService.instance.db.rawQuery('''
    SELECT game_type, status, COUNT(*) AS cnt
    FROM word_progress
    GROUP BY game_type, status
  ''');
  final result = <String, Map<String, int>>{};
  for (final row in rows) {
    final gt = row['game_type'] as String;
    final st = row['status'] as String;
    final ct = row['cnt'] as int;
    result.putIfAbsent(gt, () => {});
    result[gt]![st] = ct;
  }
  return result;
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(_profileStatsProvider);
    final progressAsync = ref.watch(_profileProgressProvider);
    final gameProgressAsync = ref.watch(_profileGameProgressProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── App Bar ──────────────────────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.screenPaddingH,
                vertical: AppTokens.space16,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Profile',
                      style: textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  IconButton(
                    icon: const Icon(Icons.settings_rounded),
                    onPressed: () =>
                        Navigator.of(context).pushNamed('/settings'),
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
                    // ── Hero Card ───────────────────────────────────────────────────────────────
                    Builder(builder: (context) {
                      final sessions = statsAsync.when(
                        data: (s) => s['totalSessions'] as int,
                        loading: () => 0,
                        error: (_, __) => 0,
                      );
                      return progressAsync.when(
                        data: (p) => _HeroCard(
                            progress: p, totalSessions: sessions),
                        loading: () => const SkeletonCard(height: 140),
                        error: (_, __) => const SizedBox(),
                      );
                    }),
                    const SizedBox(height: AppTokens.space24),

                    // ── Statistics ─────────────────────────────────────────────────────────────
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

                    // ── Game Breakdown ───────────────────────────────────────────────────────────
                    Text('Game Breakdown',
                        style: textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: AppTokens.space16),
                    statsAsync.when(
                      data: (stats) {
                        final gameStats = stats['gameStats'] as List;
                        if (gameStats.isEmpty) {
                          return _EmptyBreakdown();
                        }
                        return Column(
                          children: [
                            _GameBreakdownChart(
                                gameStats: gameStats
                                    .cast<Map<String, dynamic>>()),
                            const SizedBox(height: AppTokens.space16),
                            gameProgressAsync.when(
                              data: (counts) =>
                                  _GameProgressBars(progressCounts: counts),
                              loading: () =>
                                  const SkeletonCard(height: 220),
                              error: (_, __) => const SizedBox(),
                            ),
                          ],
                        );
                      },
                      loading: () => const SkeletonCard(height: 180),
                      error: (_, __) => const SizedBox(),
                    ),
                    const SizedBox(height: AppTokens.space24),

                    // ── 7-Day Progress (F-05) ───────────────────────────────────────────────────
                    Text('7-Day Progress',
                        style: textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: AppTokens.space16),
                    Consumer(
                      builder: (context, ref2, _) {
                        final chartAsync =
                            ref2.watch(gameSessionStatsProvider);
                        return chartAsync.when(
                          data: (stats) =>
                              _ProgressCharts(dailyStats: stats),
                          loading: () =>
                              const SkeletonCard(height: 200),
                          error: (_, __) => const SizedBox(),
                        );
                      },
                    ),
                    const SizedBox(height: AppTokens.space24),

                    // ── Saved Words ───────────────────────────────────────────────────────────
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

// ── Hero Card ──────────────────────────────────────────────────────────────────────────────

class _HeroCard extends ConsumerWidget {
  final UserProgressModel progress;
  final int totalSessions;
  const _HeroCard({required this.progress, required this.totalSessions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final name = ref.watch(userProfileProvider).name ?? '';
    final displayName = name.trim().isNotEmpty ? name.trim() : 'Learner';
    final level = LevelCalculator.levelFor(progress.totalXp);

    return Container(
      padding: const EdgeInsets.all(AppTokens.space20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.wordCardEnd],
        ),
        borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.person_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: AppTokens.space12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName,
                      style: textTheme.titleMedium?.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                  Text('Level $level',
                      style: textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.75))),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space16),
          Row(
            children: [
              _HeroStat(value: '${progress.totalXp}', label: 'XP'),
              _Divider(),
              _HeroStat(value: '${progress.streak}', label: 'Day streak'),
              _Divider(),
              _HeroStat(value: '$totalSessions', label: 'Games'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String value;
  final String label;
  const _HeroStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: textTheme.titleLarge?.copyWith(
                  color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              style: textTheme.labelSmall
                  ?.copyWith(color: Colors.white.withValues(alpha: 0.7))),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
        width: 1, height: 32, color: Colors.white.withValues(alpha: 0.25));
  }
}

// ── Overall Stats ────────────────────────────────────────────────────────────────────────

class _OverallStats extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _OverallStats({required this.stats});

  @override
  Widget build(BuildContext context) {
    final total =
        (stats['totalCorrect'] as int) + (stats['totalWrong'] as int);
    final accuracy =
        total > 0 ? (stats['totalCorrect'] as int) / total * 100 : 0.0;

    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              _MiniStat(
                label: 'Words Learned',
                value: '${stats['totalMastered']}',
                icon: Icons.menu_book_rounded,
                color: AppColors.primary,
              ),
              const SizedBox(height: AppTokens.space10),
              _MiniStat(
                label: 'Accuracy',
                value: '${accuracy.round()}%',
                icon: Icons.track_changes_rounded,
                color: Colors.orange,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppTokens.space10),
        Expanded(
          child: Column(
            children: [
              _MiniStat(
                label: 'Games Played',
                value: '${stats['totalSessions']}',
                icon: Icons.sports_esports_rounded,
                color: const Color(0xFF1565C0),
              ),
              const SizedBox(height: AppTokens.space10),
              _MiniStat(
                label: 'Questions Done',
                value:
                    '${(stats['totalCorrect'] as int) + (stats['totalWrong'] as int)}',
                icon: Icons.quiz_rounded,
                color: Colors.purple,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTokens.space12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        border:
            Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AppTokens.space10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              Text(label,
                  style: textTheme.labelSmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Game Breakdown ───────────────────────────────────────────────────────────────────────

class _EmptyBreakdown extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 80,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        border:
            Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Text('No games played yet',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: colorScheme.onSurfaceVariant)),
    );
  }
}

class _GameBreakdownChart extends StatelessWidget {
  final List<Map<String, dynamic>> gameStats;
  const _GameBreakdownChart({required this.gameStats});

  static const _colors = [
    AppColors.primary,
    Color(0xFF1565C0),
    Color(0xFFE8A020),
    Color(0xFF9C27B0),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final total = gameStats.fold<int>(
        0,
        (sum, g) =>
            sum + ((g['correct'] as int? ?? 0) + (g['wrong'] as int? ?? 0)));

    return Container(
      padding: const EdgeInsets.all(AppTokens.space20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        border:
            Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            height: 100,
            child: CustomPaint(
              painter: _DonutPainter(gameStats: gameStats, total: total),
            ),
          ),
          const SizedBox(width: AppTokens.space20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(
                gameStats.length.clamp(0, 4),
                (i) {
                  final g = gameStats[i];
                  final gt = GameType.fromString(g['game_type'] as String);
                  final count =
                      (g['correct'] as int? ?? 0) + (g['wrong'] as int? ?? 0);
                  final pct = total > 0 ? (count / total * 100).round() : 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _colors[i % _colors.length],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(gt.label,
                              style: textTheme.labelSmall,
                              overflow: TextOverflow.ellipsis),
                        ),
                        Text('$pct%',
                            style: textTheme.labelSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<Map<String, dynamic>> gameStats;
  final int total;

  static const _colors = [
    AppColors.primary,
    Color(0xFF1565C0),
    Color(0xFFE8A020),
    Color(0xFF9C27B0),
  ];

  _DonutPainter({required this.gameStats, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0) return;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = size.width / 2 - 8;
    const strokeW = 18.0;
    const gap = 0.04;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round;

    double startAngle = -1.5707963;
    for (int i = 0; i < gameStats.length.clamp(0, 4); i++) {
      final g = gameStats[i];
      final count = (g['correct'] as int? ?? 0) + (g['wrong'] as int? ?? 0);
      final sweep = (count / total) * (2 * pi) - gap;
      paint.color = _colors[i % _colors.length];
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        startAngle,
        sweep,
        false,
        paint,
      );
      startAngle += sweep + gap;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.total != total || old.gameStats != gameStats;
}

// ── Game Progress Bars (UX-06) ──────────────────────────────────────────────────────────

class _GameProgressBars extends StatelessWidget {
  final Map<String, Map<String, int>> progressCounts;

  const _GameProgressBars({required this.progressCounts});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final types = GameType.values
        .where((t) => progressCounts.containsKey(t.dbKey))
        .toList();

    if (types.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(AppTokens.space16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Mastery Progress',
              style:
                  textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppTokens.space12),
          ...types.map((type) {
            final statusMap = progressCounts[type.dbKey] ?? {};
            final mastered = statusMap['mastered'] ?? 0;
            final total =
                statusMap.values.fold(0, (s, v) => s + v);
            final fraction =
                total > 0 ? (mastered / total).clamp(0.0, 1.0) : 0.0;

            return Padding(
              padding:
                  const EdgeInsets.only(bottom: AppTokens.space12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(type.label,
                            style: textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis),
                      ),
                      Text(
                        '$mastered / $total',
                        style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTokens.space4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: fraction,
                      minHeight: 6,
                      backgroundColor: type.iconBg,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(type.iconColor),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── 7-Day Progress Charts (F-05) ────────────────────────────────────────────────────────

class _ProgressCharts extends StatelessWidget {
  final List<DailyStats> dailyStats;
  const _ProgressCharts({required this.dailyStats});

  static const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final maxXp = dailyStats.fold<int>(0, (m, s) => s.xp > m ? s.xp : m);

    return Container(
      padding: const EdgeInsets.all(AppTokens.space16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // XP Bar Chart
          Text('Daily XP',
              style:
                  textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppTokens.space12),
          SizedBox(
            height: 120,
            child: BarChart(
              BarChartData(
                maxY: (maxXp * 1.2).ceilToDouble().clamp(10, double.infinity),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= dailyStats.length)
                          return const SizedBox();
                        final dow = dailyStats[i].date.weekday - 1;
                        return Text(
                          _dayLabels[dow % 7],
                          style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(dailyStats.length, (i) {
                  final s = dailyStats[i];
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: s.xp.toDouble(),
                        color: s.hasActivity
                            ? AppColors.primary
                            : colorScheme.outlineVariant,
                        width: 20,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),

          const SizedBox(height: AppTokens.space20),

          // Accuracy Line Chart
          Text('Accuracy Trend',
              style:
                  textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppTokens.space12),
          SizedBox(
            height: 100,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 100,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        if (value % 50 != 0) return const SizedBox();
                        return Text('${value.toInt()}%',
                            style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant));
                      },
                    ),
                  ),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(dailyStats.length, (i) {
                      final s = dailyStats[i];
                      return FlSpot(i.toDouble(),
                          s.hasActivity ? (s.accuracy * 100) : 0);
                    }),
                    isCurved: true,
                    color: AppColors.reward,
                    barWidth: 2,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.reward.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Saved Words Entry ───────────────────────────────────────────────────────────────────────

class _SavedWordsEntry extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedAsync = ref.watch(savedWordsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final count = savedAsync.when(
      data: (list) => list.length,
      loading: () => 0,
      error: (_, __) => 0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Saved Words',
            style:
                textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: AppTokens.space12),
        InkWell(
          onTap: () => context.push('/saved-words'),
          borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
          child: Container(
            padding: const EdgeInsets.all(AppTokens.space16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
              border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.bookmark_rounded,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: AppTokens.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Saved Words',
                          style: textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        count == 0 ? 'No words saved yet' : '$count words saved',
                        style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
