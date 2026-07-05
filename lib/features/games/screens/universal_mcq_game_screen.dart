import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/game_config.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/game_answer_tile.dart';
import '../../../shared/widgets/game_header.dart';
import '../../../shared/widgets/game_elapsed_timer.dart';
import '../../../shared/widgets/game_load_error.dart';
import '../../../shared/widgets/game_screen_lifecycle_mixin.dart';
import '../logic/builders/mcq_question.dart';
import '../logic/game_providers.dart';
import '../logic/state/mcq_game_state.dart';

/// The single, universal screen for all MCQ-style game types.
///
/// Reads immutable [McqGameState] from `mcqGameNotifierProvider` (Task 1).
/// All gameplay mutations go through the notifier; the screen is a pure
/// rendering layer.
class UniversalMcqGameScreen extends ConsumerStatefulWidget {
  final GameConfig config;

  const UniversalMcqGameScreen({super.key, required this.config});

  @override
  ConsumerState<UniversalMcqGameScreen> createState() =>
      _UniversalMcqGameScreenState();
}

class _UniversalMcqGameScreenState
    extends ConsumerState<UniversalMcqGameScreen>
    with GameScreenLifecycleMixin {
  String? _selectedAnswer;
  int _lastIndex = -1;

  @override
  PausableGameController get pausableController =>
      ref.read(mcqGameNotifierProvider(widget.config).notifier);

  // ── Interaction ───────────────────────────────────────────────────────────

  Future<void> _selectAnswer(String answer) async {
    final notifier = ref.read(mcqGameNotifierProvider(widget.config).notifier);
    if (ref.read(mcqGameNotifierProvider(widget.config)).isAnswered) return;
    setState(() => _selectedAnswer = answer);
    await notifier.handleAnswer(answer);
  }

  Future<void> _advance() async {
    setState(() => _selectedAnswer = null);
    await ref
        .read(mcqGameNotifierProvider(widget.config).notifier)
        .nextQuestion();
  }

  Future<void> _handleExit() async {
    final shouldExit = await handleGameExitAttempt();
    if (shouldExit && mounted) context.go('/games');
  }

  AnswerState _stateFor(String option, McqGameState state) {
    if (!state.isAnswered) {
      return _selectedAnswer == option ? AnswerState.selected : AnswerState.idle;
    }
    final q = state.currentQuestion;
    if (q == null) return AnswerState.idle;
    if (option == q.correctAnswer) return AnswerState.correct;
    if (option == _selectedAnswer) return AnswerState.wrong;
    return AnswerState.idle;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = mcqGameNotifierProvider(widget.config);
    final state = ref.watch(provider);

    // Reset per-question selection when index advances.
    if (state.currentIndex != _lastIndex) {
      _lastIndex = state.currentIndex;
      _selectedAnswer = null;
    }

    // Navigate to results when the session finishes.
    ref.listen<McqGameState>(provider, (prev, next) {
      if (!(prev?.isFinished ?? false) && next.isFinished) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            final result = ref
                .read(mcqGameNotifierProvider(widget.config).notifier)
                .buildResult();
            context.go('/results', extra: result);
          }
        });
      }
    });

    final q = state.currentQuestion;
    final gameType = widget.config.gameType;
    final isSpeedRacing = gameType == GameType.speedRacing;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _handleExit();
      },
      child: Scaffold(
        appBar: GameHeader(
          title: gameType.label,
          score: state.score,
          current: state.currentIndex,
          total: state.totalQuestions,
          onClose: _handleExit,
        ),
        body: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : q == null
                ? GameLoadError(
                    error: state.initError,
                    onRetry: () => ref
                        .read(mcqGameNotifierProvider(widget.config).notifier)
                        .initialize(),
                  )
                : AnimatedSwitcher(
                    duration:
                        const Duration(milliseconds: AppTokens.durationMedium),
                    child: _McqBody(
                      key: ValueKey(state.currentIndex),
                      question: q,
                      gameType: gameType,
                      selectedAnswer: _selectedAnswer,
                      isAnswered: state.isAnswered,
                      currentIndex: state.currentIndex,
                      totalQuestions: state.totalQuestions,
                      stateFor: (opt) => _stateFor(opt, state),
                      onAnswer: _selectAnswer,
                      onAdvance: _advance,
                      timerState: isSpeedRacing ? state.timer : null,
                      elapsedDisplay:
                          isSpeedRacing ? null : state.elapsedDisplayTime,
                    ),
                  ),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _McqBody extends StatelessWidget {
  final McqQuestion question;
  final GameType gameType;
  final String? selectedAnswer;
  final bool isAnswered;
  final int currentIndex;
  final int totalQuestions;
  final AnswerState Function(String) stateFor;
  final Future<void> Function(String) onAnswer;
  final Future<void> Function() onAdvance;

  /// Non-null only for Speed Racing; other game types pass null.
  final TimerState? timerState;

  /// Pre-formatted `MM:SS` elapsed time from the shared session timer.
  /// Null for Speed Racing (which renders [TimerState] instead).
  final String? elapsedDisplay;

  const _McqBody({
    super.key,
    required this.question,
    required this.gameType,
    required this.selectedAnswer,
    required this.isAnswered,
    required this.currentIndex,
    required this.totalQuestions,
    required this.stateFor,
    required this.onAnswer,
    required this.onAdvance,
    this.timerState,
    this.elapsedDisplay,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.screenPaddingH,
        vertical: AppTokens.screenPaddingV,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (timerState != null) ...[
            _SpeedTimerBar(state: timerState!),
            const SizedBox(height: AppTokens.space20),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${currentIndex + 1} of $totalQuestions',
                style: textTheme.labelMedium
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              if (elapsedDisplay != null)
                GameElapsedTimer(display: elapsedDisplay!),
            ],
          ),
          const SizedBox(height: AppTokens.space16),
          _QuestionCard(question: question, gameType: gameType),
          const SizedBox(height: AppTokens.space24),
          Expanded(
            child: ListView.separated(
              itemCount: question.options.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppTokens.space12),
              itemBuilder: (context, i) {
                final opt = question.options[i];
                return RepaintBoundary(
                  child: GameAnswerTile(
                    label: opt,
                    state: stateFor(opt),
                    index: i,
                    labelStyle: gameType == GameType.meaningChase
                        ? textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          )
                        : null,
                    onTap: isAnswered ? null : () => onAnswer(opt),
                  ),
                );
              },
            ),
          ),
          if (isAnswered)
            Padding(
              padding: const EdgeInsets.only(top: AppTokens.space16),
              child: AppPrimaryButton(
                label: currentIndex < totalQuestions - 1
                    ? 'Next Question'
                    : 'See Results',
                icon: Icons.arrow_forward_rounded,
                onPressed: onAdvance,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Question card ─────────────────────────────────────────────────────────────

class _QuestionCard extends StatelessWidget {
  final McqQuestion question;
  final GameType gameType;

  const _QuestionCard({required this.question, required this.gameType});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final accentColor = gameType.iconColor;

    final isQuote = gameType == GameType.whoseQuote;
    final isIpa = gameType == GameType.ipaMatch;
    final isSpeed = gameType == GameType.speedRacing;

    final cardBg = isQuote
        ? colorScheme.primaryContainer
        : accentColor.withValues(alpha: 0.08);

    final cardBorder = isQuote
        ? Colors.transparent
        : accentColor.withValues(alpha: 0.20);

    final TextStyle? promptStyle = isQuote
        ? textTheme.bodyLarge?.copyWith(
            color: colorScheme.onPrimaryContainer,
            fontStyle: FontStyle.italic,
            height: 1.6,
          )
        : isIpa
            ? textTheme.displaySmall?.copyWith(
                color: accentColor,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              )
            : textTheme.headlineMedium?.copyWith(
                color: accentColor,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              );

    final subtitleColor = isQuote
        ? colorScheme.onPrimaryContainer.withValues(alpha: 0.70)
        : colorScheme.onSurface.withValues(alpha: 0.60);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        isQuote ? AppTokens.space20 : AppTokens.space24,
      ),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSpeed) ...[
            Icon(gameType.icon,
                color: accentColor.withValues(alpha: 0.5), size: 28),
            const SizedBox(height: AppTokens.space12),
          ],
          if (question.promptSubtitle.isNotEmpty) ...[
            _SubtitleBadge(
              text: question.promptSubtitle,
              isQuote: isQuote,
              accentColor: accentColor,
              subtitleColor: subtitleColor,
            ),
            const SizedBox(height: AppTokens.space12),
          ],
          Text(
            question.prompt,
            style: promptStyle,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SubtitleBadge extends StatelessWidget {
  final String text;
  final bool isQuote;
  final Color accentColor;
  final Color subtitleColor;

  const _SubtitleBadge({
    required this.text,
    required this.isQuote,
    required this.accentColor,
    required this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (isQuote) {
      return Text(
        text,
        style: textTheme.labelMedium?.copyWith(
          color: subtitleColor,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
        textAlign: TextAlign.center,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space12,
        vertical: AppTokens.space4,
      ),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
      ),
      child: Text(
        text,
        style: textTheme.labelSmall?.copyWith(
          color: accentColor,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ── Speed Timer Bar ───────────────────────────────────────────────────────────
//
// Reads an immutable [TimerState] snapshot — the parent rebuilds when the
// notifier emits a new state. There is no longer a separate ValueNotifier.

class _SpeedTimerBar extends StatelessWidget {
  final TimerState state;

  const _SpeedTimerBar({required this.state});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barColor = state.colorFor(isDark);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                child: AnimatedContainer(
                  duration:
                      const Duration(milliseconds: AppTokens.durationFast),
                  child: LinearProgressIndicator(
                    value: state.fraction,
                    minHeight: 8,
                    backgroundColor: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.4),
                    valueColor: AlwaysStoppedAnimation(barColor),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppTokens.space12),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 100),
              style: textTheme.titleMedium!.copyWith(
                color: barColor,
                fontWeight: FontWeight.w800,
              ),
              child: Text('${state.timeLeft.toStringAsFixed(1)}s'),
            ),
          ],
        ),
        if (state.isPaused) ...[
          const SizedBox(height: AppTokens.space8),
          _StatusBanner(
            icon: Icons.pause_circle_rounded,
            label: 'Timer paused — return to resume',
            color: colorScheme.secondaryContainer,
            onColor: colorScheme.onSecondaryContainer,
          ),
        ] else if (state.timedOut) ...[
          const SizedBox(height: AppTokens.space8),
          _StatusBanner(
            icon: Icons.timer_off_rounded,
            label: "Time's up!",
            color: barColor.withValues(alpha: 0.12),
            onColor: barColor,
          ),
        ],
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color onColor;

  const _StatusBanner({
    required this.icon,
    required this.label,
    required this.color,
    required this.onColor,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: AppTokens.durationFast),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space16,
          vertical: AppTokens.space8,
        ),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: AppTokens.iconSmall + 2, color: onColor),
            const SizedBox(width: AppTokens.space8),
            Text(
              label,
              style: textTheme.labelMedium?.copyWith(
                color: onColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
