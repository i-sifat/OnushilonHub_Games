import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/game_config.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/game_header.dart';
import '../../../shared/widgets/game_elapsed_timer.dart';
import '../../../shared/widgets/game_load_error.dart';
import '../../../shared/widgets/game_screen_lifecycle_mixin.dart';
import '../logic/game_providers.dart';
import '../logic/state/mcq_game_state.dart';

/// True / False screen.
///
/// Backed by `mcqGameNotifierProvider` with a `TrueFalseBuilder`. The unique
/// two-button UI is the only thing that lives here.
class TrueFalseGameScreen extends ConsumerStatefulWidget {
  final GameConfig config;

  const TrueFalseGameScreen({super.key, required this.config});

  @override
  ConsumerState createState() => _TrueFalseGameScreenState();
}

class _TrueFalseGameScreenState extends ConsumerState
    with GameScreenLifecycleMixin {
  String? _selectedAnswer;
  int _lastIndex = -1;

  @override
  PausableGameController get pausableController =>
      ref.read(mcqGameNotifierProvider(widget.config).notifier);

  Future _answer(String choice) async {
    final state = ref.read(mcqGameNotifierProvider(widget.config));
    if (state.isAnswered) return;
    setState(() => _selectedAnswer = choice);
    await ref
        .read(mcqGameNotifierProvider(widget.config).notifier)
        .handleAnswer(choice);
  }

  Future _handleExit() async {
    final shouldExit = await handleGameExitAttempt();
    if (shouldExit && mounted) context.go('/games');
  }

  @override
  Widget build(BuildContext context) {
    final provider = mcqGameNotifierProvider(widget.config);
    final state = ref.watch(provider);

    if (state.currentIndex != _lastIndex) {
      _lastIndex = state.currentIndex;
      _selectedAnswer = null;
    }

    ref.listen(provider, (prev, next) {
      if (!(prev?.isFinished ?? false) && next.isFinished) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            final result = ref.read(provider.notifier).buildResult();
            context.go('/results', extra: result);
          }
        });
      }
    });

    final q = state.currentQuestion;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _handleExit();
      },
      child: Scaffold(
        appBar: GameHeader(
          title: 'True or False',
          score: state.score,
          current: state.currentIndex,
          total: state.totalQuestions,
          onClose: _handleExit,
        ),
        body: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : (q == null)
                ? GameLoadError(
                    error: state.initError,
                    onRetry: () =>
                        ref.read(provider.notifier).initialize(),
                  )
                : AnimatedSwitcher(
                    duration: const Duration(
                        milliseconds: AppTokens.durationMedium),
                    child: Padding(
                      key: ValueKey(state.currentIndex),
                      padding: const EdgeInsets.all(
                          AppTokens.screenPaddingH),
                      child: Column(
                        children: [
                          const SizedBox(height: AppTokens.space8),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Question ${state.currentIndex + 1} of ${state.totalQuestions}',
                                style: textTheme.labelMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              GameElapsedTimer(
                                  display: state.elapsedDisplayTime),
                            ],
                          ),
                          const SizedBox(height: AppTokens.space16),
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(
                                  AppTokens.space28),
                              decoration: BoxDecoration(
                                color: colorScheme.surface,
                                borderRadius: BorderRadius.circular(
                                    AppTokens.radiusLarge),
                                border: Border.all(
                                  color: colorScheme.outlineVariant
                                      .withAlpha(0.5),
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppTokens.space12,
                                      vertical: AppTokens.space4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(
                                          AppTokens.radiusPill),
                                    ),
                                    child: Text(
                                      q.prompt,
                                      style: textTheme.titleMedium
                                          ?.copyWith(
                                        color: colorScheme
                                            .onPrimaryContainer,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(
                                      height: AppTokens.space24),
                                  Text(
                                    'Read the definition below carefully:',
                                    style: textTheme.labelMedium
                                        ?.copyWith(
                                      color: colorScheme
                                          .onSurfaceVariant,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(
                                      height: AppTokens.space16),
                                  Text(
                                    '"${q.promptSubtitle}"',
                                    style: textTheme.bodyLarge?.copyWith(
                                      height: 1.6,
                                      fontStyle: FontStyle.italic,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(
                                      height: AppTokens.space24),
                                  Text(
                                    'Is this definition correct?',
                                    style: textTheme.titleMedium
                                        ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: AppTokens.space24),
                          if (!state.isAnswered)
                            Row(
                              children: [
                                Expanded(
                                  child: _TFButton(
                                    label: 'True ✓',
                                    color: Colors.green,
                                    onTap: () => _answer('True'),
                                  ),
                                ),
                                const SizedBox(
                                    width: AppTokens.space16),
                                Expanded(
                                  child: _TFButton(
                                    label: 'False ✗',
                                    color: Colors.red,
                                    onTap: () => _answer('False'),
                                  ),
                                ),
                              ],
                            ),
                          if (state.isAnswered) ...[
                            if (q.correctDefinition != null &&
                                q.correctDefinition!.isNotEmpty) ...[
                              _CorrectDefinitionReveal(
                                word: q.prompt,
                                definition: q.correctDefinition!,
                              ),
                              const SizedBox(height: AppTokens.space16),
                            ],
                            AppButton(
                              label: 'Next',
                              onTap: () => ref
                                  .read(provider.notifier)
                                  .nextQuestion(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }
}

class _TFButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _TFButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: label,
      color: color,
      onTap: onTap,
    );
  }
}

/// Feedback panel shown after the player answers a False question.
/// Reveals the actual correct definition of the word so the player
/// always walks away knowing what the word really means.
class _CorrectDefinitionReveal extends StatelessWidget {
  final String word;
  final String definition;

  const _CorrectDefinitionReveal({
    required this.word,
    required this.definition,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTokens.space16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
        border: Border.all(
          color: Colors.green.withOpacity(0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: Colors.green,
                size: 16,
              ),
              const SizedBox(width: AppTokens.space8),
              Expanded(
                child: Text(
                  'Correct definition of "$word"',
                  style: textTheme.labelMedium?.copyWith(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space8),
          Text(
            definition,
            style: textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}
