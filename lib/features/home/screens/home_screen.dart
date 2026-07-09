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
          if (seeding) const _SeedingBanner(),
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
          AppTokens.screenPaddingH,
          AppTokens.space8,
          AppTokens.screenPaddingH,
          AppTokens.space8,
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

// ── Seeding Banner ─────────────────────────────────────────────────────────────

class _SeedingBanner extends StatelessWidget {
  const _SeedingBanner();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.screenPaddingH,
        vertical: AppTokens.space8,
      ),
      color: colorScheme.primaryContainer,
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppTokens.space8),
          Text(
            'Setting up vocabulary database…',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                ),
          ),
        ],
      ),
    );
  }
}

// ── App Bar ────────────────────────────────────────────────────────────────────

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
      actions: [
        // F-04: word search shortcut
        IconButton(
          icon: const Icon(Icons.search_rounded),
          onPressed: () => context.push('/search'),
          tooltip: 'Search words',
        ),
      ],
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
        horizontal: AppTokens.space12,
        vertical: AppTokens.space6,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 4),
          Text(
            value,
            style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(
              label,
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Daily Word Card ──────────────────────────────────────────────────────────

class _DailyWordCard extends ConsumerWidget {
  const _DailyWordCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyWordAsync = ref.watch(dailyWordProvider);
    final textTheme = Theme.of(context).textTheme;

    return dailyWordAsync.when(
      loading: () => const SkeletonCard(height: 200),
      error: (_, __) => const SizedBox(),
      data: (word) {
        // fix(build): dailyWordProvider returns WordRow? — guard against null
        // before accessing any properties to satisfy null safety.
        if (word == null) return const SizedBox();

        final savedAsync = ref.watch(savedWordsProvider);
        final isSaved = savedAsync.when(
          data: (list) => list.any((w) => w.word == word.word),
          loading: () => false,
          error: (_, __) => false,
        );

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: AppTokens.durationSlow),
          child: Container(
            key: ValueKey(word.word),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // UX-03: top info area taps to word detail screen
                  GestureDetector(
                    onTap: () => context.push('/word/${word.id}'),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppTokens.space20,
                        AppTokens.space20,
                        AppTokens.space20,
                        AppTokens.space16,
                      ),
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
                              const _CardIconBtn(
                                  icon: Icons.volume_up_outlined),
                              const SizedBox(width: AppTokens.space8),
                              GestureDetector(
                                onTap: () async {
                                  final notifier =
                                      ref.read(savedWordsProvider.notifier);
                                  if (isSaved) {
                                    await notifier.remove(word.word);
                                  } else {
                                    await notifier.save(
                                        word.word, word.definition);
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
                            word.synonyms.isNotEmpty
                                ? '/${word.synonyms.first}/'
                                : '',
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

                  // UX-05: Quick Game button
                  Divider(
                    color: Colors.white.withValues(alpha: 0.15),
                    height: 1,
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => context.go(
                        '/games/play/meaning_chase',
                        extra: GameConfig(
                          gameType: GameType.meaningChase,
                          questionCount: 5,
                          forcedWordIds: [word.id],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTokens.space20,
                          vertical: AppTokens.space12,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.play_circle_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: AppTokens.space8),
                            Text(
                              'Quick Game  ·  5 questions',
                              style: textTheme.labelLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Colors.white.withValues(alpha: 0.6),
                              size: 14,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Card icon button ──────────────────────────────────────────────────────────────────

class _CardIconBtn extends StatelessWidget {
  final IconData icon;
  const _CardIconBtn({super.key, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 16),
    );
  }
}

// ── Your Progress Section ────────────────────────────────────────────────────────

class _YourProgressSection extends ConsumerWidget {
  const _YourProgressSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayAsync = ref.watch(dailyGoalProvider);
    final targetAsync = ref.watch(dailyGoalTargetProvider);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final today = todayAsync.when(
        data: (n) => n, loading: () => 0, error: (_, __) => 0);
    final target = targetAsync.when(
        data: (n) => n, loading: () => 5, error: (_, __) => 5);
    final fraction = target > 0 ? (today / target).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today’s Progress',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppTokens.space12),
        Container(
          padding: const EdgeInsets.all(AppTokens.space16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
            border: Border.all(
                color: colorScheme.outlineVariant.withOpacity(0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$today / $target sessions',
                    style: textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${(fraction * 100).round()}%',
                    style: textTheme.labelLarge?.copyWith(
                      color: fraction >= 1
                          ? AppColors.correctGreen
                          : AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.space8),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 8,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    fraction >= 1 ? AppColors.correctGreen : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Your Games Section ──────────────────────────────────────────────────────

class _YourGamesSection extends ConsumerWidget {
  const _YourGamesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playedAsync = ref.watch(playedGamesProvider);
    final progressAsync = ref.watch(homeGameProgressProvider);
    final textTheme = Theme.of(context).textTheme;

    final played = playedAsync.when(
      data: (list) => list.toSet(),
      loading: () => <String>{},
      error: (_, __) => <String>{},
    );
    // fix(build): homeGameProgressProvider returns Map<String, Map<String,dynamic>>
    // (each value is {'mastered': n, 'total': n}). The old loading/error fallbacks
    // used <String, int>{} which caused Dart to widen the type to Map<String, Object>,
    // making progress[key] an Object that couldn't be assigned to int.
    final Map<String, dynamic> progress = progressAsync.when(
      data: (map) => map as Map<String, dynamic>,
      loading: () => const <String, dynamic>{},
      error: (_, __) => const <String, dynamic>{},
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Games',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppTokens.space12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: AppTokens.space8,
            mainAxisSpacing: AppTokens.space8,
            childAspectRatio: 0.9,
          ),
          itemCount: GameType.values.length,
          itemBuilder: (context, i) {
            final gt = GameType.values[i];
            // fix(build): extract mastered safely from nested map or int
            final rawVal = progress[gt.dbKey];
            final mastered = rawVal is int
                ? rawVal
                : rawVal is Map<String, dynamic>
                    ? (rawVal['mastered'] as int? ?? 0)
                    : 0;
            final hasPlayed = played.contains(gt.dbKey);
            return _GameTile(
              gameType: gt,
              mastered: mastered,
              hasPlayed: hasPlayed,
              onTap: () => context.go('/games/pre/${gt.dbKey}'),
            );
          },
        ),
      ],
    );
  }
}

class _GameTile extends StatelessWidget {
  final GameType gameType;
  final int mastered;
  final bool hasPlayed;
  final VoidCallback onTap;

  const _GameTile({
    required this.gameType,
    required this.mastered,
    required this.hasPlayed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: gameType.iconBg,
      borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.space10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(gameType.icon, color: gameType.iconColor, size: 28),
              const SizedBox(height: AppTokens.space6),
              Text(
                gameType.label,
                style: textTheme.labelSmall?.copyWith(
                  color: gameType.iconColor,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (hasPlayed && mastered > 0) ...[
                const SizedBox(height: AppTokens.space2),
                Text(
                  '$mastered \u2713',
                  style: textTheme.labelSmall?.copyWith(
                    color: gameType.iconColor.withOpacity(0.7),
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
