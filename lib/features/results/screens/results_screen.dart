import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/home/providers/home_provider.dart';
import '../../../features/profile/screens/profile_screen.dart' show profileRefreshCounterProvider;
import '../../../core/models/game_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/animated_counter.dart';

class ResultsScreen extends ConsumerStatefulWidget {
  final GameResult result;

  const ResultsScreen({super.key, required this.result});

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: AppTokens.durationSlow),
    );
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _invalidateHomeProviders(WidgetRef ref) {
    ref.invalidate(userProgressProvider);
    ref.invalidate(dailyWordProvider);
    ref.invalidate(homeGameProgressProvider);
    ref.invalidate(playedGamesProvider);
    ref.invalidate(todaySessionCountProvider);
    // Trigger profile screen data refresh.
    ref.read(profileRefreshCounterProvider.notifier).update((n) => n + 1);
  }

  String get _emoji {
    final acc = widget.result.accuracy;
    if (acc >= 0.9) return '\u{1F3C6}';
    if (acc >= 0.7) return '\u{1F3AF}';
    if (acc >= 0.5) return '\u{1F44D}';
    return '\u{1F4AA}';
  }

  String get _message {
    final acc = widget.result.accuracy;
    if (acc >= 0.9) return 'Outstanding!';
    if (acc >= 0.7) return 'Well done!';
    if (acc >= 0.5) return 'Good effort!';
    return 'Keep practicing!';
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final result = widget.result;

    // UX-01: collect unique wordIds from mistakes for Practice Mistakes button.
    final mistakeWordIds = result.mistakes
        .where((m) => m.wordId != null)
        .map((m) => m.wordId!)
        .toSet()
        .toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _invalidateHomeProviders(ref);
          context.go('/home');
        }
      },
      child: Scaffold(
        body: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.screenPaddingH,
                  vertical: AppTokens.space24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: AppTokens.space24),
                    // Trophy icon
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withOpacity(0.2),
                            blurRadius: 32,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _emoji,
                          style: const TextStyle(fontSize: 44),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTokens.space20),
                    Text(
                      _message,
                      style: textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: AppTokens.space4),
                    Text(
                      result.gameType.label,
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppTokens.space32),
                    // Score card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppTokens.space28),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withOpacity(0.8),
                          ],
                        ),
                        borderRadius:
                            BorderRadius.circular(AppTokens.radiusLarge),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Final Score',
                            style: textTheme.labelLarge?.copyWith(
                              color: Colors.white.withOpacity(0.7),
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: AppTokens.space8),
                          AnimatedCounter(
                            value: result.score,
                            duration: const Duration(milliseconds: 800),
                            style: textTheme.displayMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -2,
                            ),
                          ),
                          const SizedBox(height: AppTokens.space4),
                          if (result.bonusXp > 0) ...[
                            Text(
                              '${result.baseXp} base + ${result.bonusXp} speed bonus',
                              style: textTheme.labelSmall?.copyWith(
                                color: Colors.white.withOpacity(0.75),
                              ),
                            ),
                            const SizedBox(height: AppTokens.space2),
                          ],
                          Text(
                            'XP Earned',
                            style: textTheme.labelSmall?.copyWith(
                              color: Colors.white.withOpacity(0.75),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppTokens.space24),

                    // Stats grid
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Correct',
                            value: '${result.correctCount}',
                            icon: Icons.check_circle_rounded,
                            color: AppColors.correctGreen,
                          ),
                        ),
                        const SizedBox(width: AppTokens.space12),
                        Expanded(
                          child: _StatCard(
                            label: 'Wrong',
                            value: '${result.wrongCount}',
                            icon: Icons.cancel_rounded,
                            color: AppColors.lightError,
                          ),
                        ),
                        const SizedBox(width: AppTokens.space12),
                        Expanded(
                          child: _StatCard(
                            label: 'Accuracy',
                            value: '${(result.accuracy * 100).round()}%',
                            icon: Icons.analytics_rounded,
                            color: AppColors.reward,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTokens.space12),
                    _StatCard(
                      label: 'Time',
                      value: _formatDuration(result.elapsedSeconds),
                      icon: Icons.timer_rounded,
                      color: colorScheme.primary,
                      fullWidth: true,
                    ),

                    // Mistakes section
                    if (result.mistakes.isNotEmpty) ...[
                      const SizedBox(height: AppTokens.space32),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Review Mistakes',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTokens.space12),
                      ...result.mistakes.map((m) => Padding(
                            padding: const EdgeInsets.only(
                                bottom: AppTokens.space12),
                            child: _MistakeCard(mistake: m),
                          )),
                    ],

                    const SizedBox(height: AppTokens.space32),

                    // Actions
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          _invalidateHomeProviders(ref);
                          context.go('/games/pre/${result.gameType.dbKey}');
                        },
                        icon: const Icon(Icons.replay_rounded),
                        label: const Text('Play Again'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTokens.space12),

                    // UX-01: Practice Mistakes — only shown when mistakes carry
                    // wordIds (i.e. DB-backed game types). Routes to the same
                    // game with forcedWordIds so the session focuses on exactly
                    // the words the player got wrong.
                    if (mistakeWordIds.isNotEmpty) ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            _invalidateHomeProviders(ref);
                            final practiceConfig = GameConfig(
                              gameType: result.gameType,
                              difficulty: 1,
                              questionCount: mistakeWordIds.length,
                              forcedWordIds: mistakeWordIds,
                            );
                            context.go(
                              '/games/play/${result.gameType.dbKey}',
                              extra: practiceConfig,
                            );
                          },
                          icon: const Icon(Icons.fitness_center_rounded),
                          label: Text(
                              'Practice Mistakes (${mistakeWordIds.length})'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 56),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTokens.space12),
                    ],

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _invalidateHomeProviders(ref);
                          context.go('/home');
                        },
                        icon: const Icon(Icons.home_rounded),
                        label: const Text('Go Home'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTokens.space24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool fullWidth;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppTokens.space16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: fullWidth
          ? Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: AppTokens.space12),
                Text(
                  label,
                  style: textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  value,
                  style: textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            )
          : Column(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: AppTokens.space8),
                Text(
                  value,
                  style: textTheme.titleLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppTokens.space2),
                Text(
                  label,
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
    );
  }
}

class _MistakeCard extends StatelessWidget {
  final MistakeItem mistake;

  const _MistakeCard({required this.mistake});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final allCorrect = mistake.allCorrectAnswers;

    return Container(
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
          Text(
            mistake.question.length > 80
                ? '${mistake.question.substring(0, 80)}...'
                : mistake.question,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppTokens.space8),
          Row(
            children: [
              const Icon(Icons.cancel_rounded,
                  size: 14, color: AppColors.lightError),
              const SizedBox(width: AppTokens.space4),
              Expanded(
                child: Text(
                  'You: ${mistake.userAnswer}',
                  style: textTheme.labelMedium?.copyWith(
                    color: AppColors.lightError,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space4),
          if (allCorrect.length > 1) ...[
            Wrap(
              spacing: AppTokens.space4,
              runSpacing: AppTokens.space4,
              children: [
                Text(
                  'All correct: ',
                  style: textTheme.labelSmall?.copyWith(
                    color: AppColors.correctGreen,
                  ),
                ),
                ...allCorrect.map((a) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppTokens.space6,
                          vertical: AppTokens.space2),
                      decoration: BoxDecoration(
                        color: AppColors.correctGreen.withOpacity(0.1),
                        borderRadius:
                            BorderRadius.circular(AppTokens.radiusPill),
                      ),
                      child: Text(
                        a,
                        style: textTheme.labelSmall?.copyWith(
                          color: AppColors.correctGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )),
              ],
            ),
          ] else
            Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    size: 14, color: AppColors.correctGreen),
                const SizedBox(width: AppTokens.space4),
                Expanded(
                  child: Text(
                    'Correct: ${mistake.correctAnswer}',
                    style: textTheme.labelMedium?.copyWith(
                      color: AppColors.correctGreen,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
