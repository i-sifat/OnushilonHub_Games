import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/home/providers/home_provider.dart';
import '../../../features/profile/screens/profile_screen.dart'
    show profileRefreshCounterProvider;
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
    // Trigger profile screen data refresh (replaces the old StreamController approach).
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
                    const SizedBox(height: AppTokens.space32),
                    // Stats
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _StatCard(
                          label: 'Correct',
                          value: result.correctCount.toString(),
                          color: AppColors.success,
                        ),
                        _StatCard(
                          label: 'Wrong',
                          value: result.wrongCount.toString(),
                          color: AppColors.error,
                        ),
                        _StatCard(
                          label: 'Accuracy',
                          value:
                              '${(result.accuracy * 100).toStringAsFixed(1)}%',
                        ),
                      ],
                    ),
                    // Mistakes list
                    if (result.mistakes.isNotEmpty) ...[
                      const SizedBox(height: AppTokens.space32),
                      Text(
                        'Review your mistakes',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppTokens.space12),
                      for (final mistake in result.mistakes)
                        Padding(
                          padding: const EdgeInsets.only(
                              bottom: AppTokens.space12),
                          child: MistakeItemWidget(mistake: mistake),
                        ),
                    ],
                    const SizedBox(height: AppTokens.space32),
                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            _invalidateHomeProviders(ref);
                            context.go('/home');
                          },
                          child: const Text('Home'),
                        ),
                        const SizedBox(width: AppTokens.space16),
                        ElevatedButton(
                          onPressed: () {
                            _invalidateHomeProviders(ref);
                            context.go('/play');
                          },
                          child: const Text('Play Again'),
                        ),
                      ],
                    ),
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
  final Color? color;

  const _StatCard({
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Text(
          label,
          style: textTheme.labelLarge?.copyWith(
            color: color ?? colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppTokens.space4),
        Text(
          value,
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: color ?? colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class MistakeItemWidget extends StatelessWidget {
  final MistakeItem mistake;

  const MistakeItemWidget({super.key, required this.mistake});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final allCorrect = mistake.allCorrectAnswers;
    final showAllCorrect = allCorrect.length > 1;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.space8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            mistake.question,
            style: textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTokens.space4),
          Text.rich(
            TextSpan(
              text: 'Your answer: ',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              children: [
                TextSpan(
                  text: mistake.userAnswer,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space2),
          if (showAllCorrect) ...[
            Text(
              'All correct answers:',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppTokens.space4),
            Wrap(
              spacing: AppTokens.space8,
              runSpacing: AppTokens.space4,
              children: allCorrect
                  .map(
                    (ans) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTokens.space8,
                        vertical: AppTokens.space2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.12),
                        borderRadius:
                            BorderRadius.circular(AppTokens.radiusMedium),
                      ),
                      child: Text(
                        ans,
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ] else
            Text.rich(
              TextSpan(
                text: 'Correct answer: ',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                children: [
                  TextSpan(
                    text: mistake.correctAnswer,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
