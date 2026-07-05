import 'package:flutter/material.dart';
import '../../../database/database_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/level_calculator.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../providers/home_provider.dart';
import '../../../core/models/game_config.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../../core/providers/saved_words_provider.dart';
import '../../../core/providers/daily_goal_provider.dart';


class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Listen for seed completion and rebuild once done.
    DatabaseService.instance.seedReady.addListener(_onSeedReady);
  }

  void _onSeedReady() {
    DatabaseService.instance.seedReady.removeListener(_onSeedReady);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    DatabaseService.instance.seedReady.removeListener(_onSeedReady);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seeding = !DatabaseService.instance.seedComplete;
    ref.watch(playedGamesProvider);

    return Scaffold(
      body: Column(
        children: [
          if (seeding)
            const _SeedingBanner(),
          Expanded(
            child: CustomScrollView(
              slivers: _buildSlivers(context),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSlivers(BuildContext context) {
    return [
      const _HomeAppBar(),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.screenPaddingH, AppTokens.space8,
          AppTokens.screenPaddingH, AppTokens.space8,
        ),
        sliver: SliverList(
          delegate: SliverChildListDelegate([
            const _StatsRow(),
            const SizedBox(height: AppTokens.space20),
            const _DailyWordCard(),
            const SizedBox(height: AppTokens.space24),
            const _YourProgressSection(),
            const SizedBox(height: AppTokens.space24),
            const _YourGamesSection(),
            const SizedBox(height: AppTokens.space80),
          ]),
        ),
      ),
    ];
  }
}

// ── App Bar ───────────────────────────────────────────────────────────────────

class _HomeAppBar extends ConsumerWidget {
  const _HomeAppBar();

  String _getGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final name = ref.watch(userProfileProvider).name ?? '';
    final displayName = name.trim().isNotEmpty ? name.trim() : 'Learner';

    return SliverAppBar(
      floating: true,
      snap: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: colorScheme.surface,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _getGreeting(),
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            displayName,
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

// ── Stats Row ─────────────────────────────────────────────────────────────────

class _StatsRow extends ConsumerWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(userProgressProvider);

    return progressAsync.when(
      data: (p) => Row(
        children: [
          _StatPill(
            icon: Icons.local_fire_department_rounded,
            iconColor: Colors.deepOrange,
            value: '${p.streak}',
            label: 'Streak',
          ),
          const SizedBox(width: AppTokens.space8),
          _StatPill(
            icon: Icons.bolt_rounded,
            iconColor: const Color(0xFFE8A020),
            value: '${p.totalXp}',
            label: 'XP',
          ),
          const SizedBox(width: AppTokens.space8),
          _StatPill(
            icon: Icons.emoji_events_rounded,
            iconColor: const Color(0xFFE8A020),
            value: 'Level ${LevelCalculator.levelFor(p.totalXp)}',
            label: '',
          ),
        ],
      ),
      loading: () => const SkeletonCard(height: 36),
      error: (_, __) => const SizedBox(),
    );
  }

}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _StatPill({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space12, vertical: AppTokens.space6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 4),
          Text(
            value,
            style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 3),
            Text(label, style: textTheme.labelSmall),
          ],
        ],
      ),
    );
  }
}

// ── Daily Word Card ───────────────────────────────────────────────────────────

class _DailyWordCard extends ConsumerWidget {
  const _DailyWordCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wordAsync = ref.watch(dailyWordProvider);
    final textTheme = Theme.of(context).textTheme;

    return wordAsync.when(
      data: (wordData) {
        final WordRow? word = wordData;
        if (word == null) return const SizedBox();

        final isSaved = ref
            .watch(isWordSavedProvider(word.word))
            .maybeWhen(data: (v) => v, orElse: () => false);

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: AppTokens.durationSlow),
          child: Container(
            key: ValueKey(word.word),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppTokens.space20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Word of the Day',
                        style: textTheme.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                          letterSpacing: 0.2,
                        ),
                      ),
                      const Spacer(),
                      const _CardIconBtn(icon: Icons.volume_up_outlined),
                      const SizedBox(width: AppTokens.space8),
                      GestureDetector(
                        onTap: () async {
                          final notifier =
                              ref.read(savedWordsProvider.notifier);
                          if (isSaved) {
                            await notifier.remove(word.word);
                          } else {
                            await notifier.save(word.word, word.definition);
                          }
                        },
                        child: AnimatedSwitcher(
                          duration: const Duration(
                              milliseconds: AppTokens.durationFast),
                          child: _CardIconBtn(
                            key: ValueKey(isSaved),
                            icon: isSaved
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTokens.space12),
                  Text(
                    word.word,
                    style: textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: AppTokens.space4),
                  Text(
                    word.synonyms.isNotEmpty ? '/${word.synonyms.first}/' : '',
                    style: textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: AppTokens.space12),
                  Text(
                    word.definition,
                    style: textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: AppTokens.space12),
                  Text(
                    '"${word.example}"',
                    style: textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SkeletonCard(height: 220),
      error: (_, __) => const SizedBox(),
    );
  }
}

class _CardIconBtn extends StatelessWidget {
  final IconData icon;
  const _CardIconBtn({super.key, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }
}

// ── Your Progress Section ─────────────────────────────────────────────────────

class _YourProgressSection extends ConsumerWidget {
  const _YourProgressSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(todaySessionCountProvider);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your Progress',
            style:
                textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: AppTokens.space12),
        sessionsAsync.when(
          data: (done) {
            final progress = (done / kDailyGoal).clamp(0.0, 1.0);
            final clamped = done.clamp(0, kDailyGoal);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Daily goal',
                        style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant)),
                    Text('$clamped/$kDailyGoal games',
                        style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: AppTokens.space8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor:
                        colorScheme.outlineVariant.withValues(alpha: 0.3),
                    valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
              ],
            );
          },
          loading: () => const SkeletonCard(height: 40),
          error: (_, __) => const SizedBox(),
        ),
      ],
    );
  }
}

// ── Your Games Section ────────────────────────────────────────────────────────

class _YourGamesSection extends ConsumerWidget {
  const _YourGamesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playedAsync = ref.watch(playedGamesProvider);
    final progressAsync = ref.watch(homeGameProgressProvider);
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your Games',
            style:
                textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: AppTokens.space12),
        playedAsync.when(
          data: (played) {
            if (played.isEmpty) return _NoGamesPlayed();
            return progressAsync.when(
              data: (progressMap) => Column(
                children: played.map((gt) {
                  final gameEnum = GameType.fromString(gt);
                  final prog = progressMap[gt] ?? {'mastered': 0, 'total': 0};
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppTokens.space10),
                    child: _GameProgressCard(
                      gameType: gameEnum,
                      learned: prog['mastered'] ?? 0,
                      total: prog['total'] ?? 0,
                    ),
                  );
                }).toList(),
              ),
              loading: () => const SkeletonCard(),
              error: (_, __) => const SizedBox(),
            );
          },
          loading: () => const SkeletonCard(),
          error: (_, __) => const SizedBox(),
        ),
      ],
    );
  }
}

class _NoGamesPlayed extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          vertical: AppTokens.space32, horizontal: AppTokens.space20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sports_esports_outlined,
              size: 40, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: AppTokens.space12),
          Text(
            'No games played yet',
            style:
                textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppTokens.space4),
          Text(
            'Start a game and your progress will appear here.',
            style: textTheme.bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTokens.space16),
          TextButton(
            onPressed: () => GoRouter.of(context).go('/games'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.space20, vertical: AppTokens.space8),
            ),
            child: Text(
              'Start playing',
              style: textTheme.labelLarge?.copyWith(
                  color: AppColors.primary, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameProgressCard extends StatelessWidget {
  final GameType gameType;
  final int learned;
  final int total;

  const _GameProgressCard({
    required this.gameType,
    required this.learned,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppTokens.space14),
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
            child: Icon(gameType.icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: AppTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(gameType.label,
                    style: textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('$learned of $total words mastered',
                    style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          FilledButton.tonal(
            onPressed: () => context.go('/games/pre/${gameType.dbKey}'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(80, 36),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusSmall)),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Text('Continue',
                style: textTheme.labelMedium?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _SeedingBanner extends StatelessWidget {
  const _SeedingBanner();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.primaryContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Building word database — games ready shortly…',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}