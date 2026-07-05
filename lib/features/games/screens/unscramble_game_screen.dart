import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/models/game_config.dart';
import '../../../shared/widgets/game_header.dart';
import '../../../shared/widgets/game_elapsed_timer.dart';
import '../../../shared/widgets/game_load_error.dart';
import '../../../shared/widgets/game_screen_lifecycle_mixin.dart';
import '../logic/game_providers.dart';
import '../logic/state/unscramble_game_state.dart';

/// Unscramble screen.
///
/// Backed by `unscrambleGameNotifierProvider`. All gameplay state lives in
/// the immutable [UnscrambleGameState]; the screen is a pure rendering layer.
class UnscrambleGameScreen extends ConsumerStatefulWidget {
  final GameConfig config;
  const UnscrambleGameScreen({super.key, required this.config});

  @override
  ConsumerState<UnscrambleGameScreen> createState() =>
      _UnscrambleGameScreenState();
}

class _UnscrambleGameScreenState extends ConsumerState<UnscrambleGameScreen>
    with GameScreenLifecycleMixin {
  @override
  PausableGameController get pausableController =>
      ref.read(unscrambleGameNotifierProvider(widget.config).notifier);

  bool get _trackTime => widget.config.trackAnswerTime;

  void _tapTile(int index) {
    final state = ref.read(unscrambleGameNotifierProvider(widget.config));
    if (state.isAnswered) return;
    HapticFeedback.selectionClick();
    ref
        .read(unscrambleGameNotifierProvider(widget.config).notifier)
        .tapTile(index);
  }

  void _removeLast() {
    final state = ref.read(unscrambleGameNotifierProvider(widget.config));
    if (state.isAnswered || state.selectedIndices.isEmpty) return;
    HapticFeedback.lightImpact();
    ref
        .read(unscrambleGameNotifierProvider(widget.config).notifier)
        .removeLast();
  }

  void _useHint() {
    final state = ref.read(unscrambleGameNotifierProvider(widget.config));
    if (state.isAnswered || state.hintUsed) return;
    HapticFeedback.mediumImpact();
    ref
        .read(unscrambleGameNotifierProvider(widget.config).notifier)
        .useHint();
  }

  Future<void> _next() async {
    await ref
        .read(unscrambleGameNotifierProvider(widget.config).notifier)
        .nextQuestion();
  }

  Future<void> _handleExit() async {
    final shouldExit = await handleGameExitAttempt();
    if (shouldExit && mounted) context.go('/games');
  }

  @override
  Widget build(BuildContext context) {
    final provider = unscrambleGameNotifierProvider(widget.config);
    final state = ref.watch(provider);

    ref.listen<UnscrambleGameState>(provider, (prev, next) {
      if (!(prev?.isFinished ?? false) && next.isFinished) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            final result = ref.read(provider.notifier).buildResult();
            context.go('/results', extra: result);
          }
        });
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _handleExit();
      },
      child: Scaffold(
        appBar: GameHeader(
          title: 'Unscramble',
          score: state.score,
          current: state.currentIndex,
          total: state.totalQuestions,
          onClose: _handleExit,
          showProgressBar: false,
        ),
        body: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : state.currentQuestion == null
                ? GameLoadError(
                    error: state.initError,
                    onRetry: () => ref.read(provider.notifier).initialize(),
                  )
                : _buildBody(state),
      ),
    );
  }

  Widget _buildBody(UnscrambleGameState state) {
    final q = state.currentQuestion!;
    final letters = q.scrambled.split('');
    final wordLength = q.word.word.length;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: AppTokens.durationMedium),
      child: Column(
        key: ValueKey(state.currentIndex),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppTokens.screenPaddingH, 4, AppTokens.screenPaddingH, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Question ${state.currentIndex + 1} of ${state.totalQuestions}',
                  style: textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                if (_trackTime)
                  GameElapsedTimer(display: state.elapsedDisplayTime),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space6),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.screenPaddingH),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTokens.radiusPill),
              child: LinearProgressIndicator(
                value: (state.currentIndex + 1) / state.totalQuestions,
                minHeight: 4,
                backgroundColor:
                    colorScheme.outlineVariant.withValues(alpha: 0.3),
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTokens.screenPaddingH),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: AppTokens.space16),
                  Center(child: _buildScrambledTiles(letters, state)),
                  const SizedBox(height: AppTokens.space24),
                  Center(child: _buildAnswerSlots(letters, wordLength, state)),
                  const SizedBox(height: AppTokens.space8),
                  Center(
                    child: state.isAnswered
                        ? const SizedBox()
                        : OutlinedButton.icon(
                            onPressed: state.hintUsed ? null : _useHint,
                            icon: Icon(
                              state.hintUsed
                                  ? Icons.lightbulb_rounded
                                  : Icons.lightbulb_outline_rounded,
                              size: 18,
                            ),
                            label:
                                Text(state.hintUsed ? 'Hint used' : 'Hint'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: state.hintUsed
                                  ? colorScheme.onSurfaceVariant
                                  : AppColors.reward,
                              side: BorderSide(
                                color: state.hintUsed
                                    ? colorScheme.outlineVariant
                                    : AppColors.reward,
                                width: 1,
                              ),
                              minimumSize: const Size(120, 40),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    AppTokens.radiusPill),
                              ),
                            ),
                          ),
                  ),
                  if (state.isAnswered) ...[
                    const SizedBox(height: AppTokens.space20),
                    _AnswerFeedback(
                      correct: state.lastAnswerCorrect,
                      correctWord: q.word.word,
                    ),
                    if (q.banglaMeaning.isNotEmpty) ...[
                      const SizedBox(height: AppTokens.space12),
                      Center(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            ref
                                .read(unscrambleGameNotifierProvider(
                                        widget.config)
                                    .notifier)
                                .toggleMeaning();
                          },
                          icon: Icon(
                            state.meaningVisible
                                ? Icons.translate_rounded
                                : Icons.translate_outlined,
                            size: 18,
                          ),
                          label: Text(state.meaningVisible
                              ? 'Hide Meaning'
                              : 'Show Meaning'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: BorderSide(
                              color: AppColors.primary.withValues(alpha: 0.7),
                              width: 1.2,
                            ),
                            minimumSize: const Size(160, 40),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppTokens.radiusPill),
                            ),
                          ),
                        ),
                      ),
                      if (state.meaningVisible) ...[
                        const SizedBox(height: AppTokens.space12),
                        // P1: show the meaning for the word the player typed,
                        // not always the primaryWord's meaning. Falls back to
                        // primaryWord's meaning when the typed word has none.
                        Builder(builder: (_) {
                          final typed = state.playerAnswer;
                          final shownWord = typed.isNotEmpty
                              ? typed.toUpperCase()
                              : q.word.word;
                          final shownMeaning = typed.isNotEmpty
                              ? q.meaningForAnswer(typed)
                              : q.banglaMeaning;
                          return _BanglaMeaningCard(
                            word: shownWord,
                            meaning: shownMeaning,
                          );
                        }),
                      ],
                    ],
                    const SizedBox(height: AppTokens.space20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: _next,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppTokens.radiusMedium),
                          ),
                        ),
                        child: Text(
                          state.currentIndex < state.totalQuestions - 1
                              ? 'Next Question'
                              : 'See Results',
                          style: textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (!state.isAnswered) _buildKeyboard(letters, state),
        ],
      ),
    );
  }

  Widget _buildScrambledTiles(List<String> letters, UnscrambleGameState state) {
    return Wrap(
      spacing: AppTokens.space8,
      runSpacing: AppTokens.space8,
      alignment: WrapAlignment.center,
      children: List.generate(letters.length, (i) {
        final used = state.selectedIndices.contains(i);
        return _LetterTile(
          letter: letters[i],
          used: used,
          onTap: used ? null : () => _tapTile(i),
        );
      }),
    );
  }

  Widget _buildAnswerSlots(
      List<String> letters, int wordLength, UnscrambleGameState state) {
    return Wrap(
      spacing: AppTokens.space8,
      runSpacing: AppTokens.space8,
      alignment: WrapAlignment.center,
      children: List.generate(wordLength, (pos) {
        String? letter;
        if (pos < state.selectedIndices.length) {
          letter = letters[state.selectedIndices[pos]];
        }
        return _AnswerSlot(
          letter: letter,
          isCorrect: state.isAnswered ? state.lastAnswerCorrect : null,
        );
      }),
    );
  }

  Widget _buildKeyboard(List<String> letters, UnscrambleGameState state) {
    final colorScheme = Theme.of(context).colorScheme;
    final rows = _buildKeyRows(letters);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 35),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...rows.take(rows.length - 1).map((row) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: row
                          .map((info) => Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 3),
                                child: _KeyboardKey(
                                  label: info.label,
                                  index: info.index,
                                  used: info.index >= 0 &&
                                      state.selectedIndices
                                          .contains(info.index),
                                  onTap: info.index < 0
                                      ? _removeLast
                                      : () => _tapTile(info.index),
                                ),
                              ))
                          .toList(),
                    ),
                  )),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: rows.last
                    .map((info) => Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 3),
                          child: _KeyboardKey(
                            label: info.label,
                            index: info.index,
                            used: info.index >= 0 &&
                                state.selectedIndices.contains(info.index),
                            onTap: info.index < 0
                                ? _removeLast
                                : () => _tapTile(info.index),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<List<_KeyInfo>> _buildKeyRows(List<String> letters) {
    final half = (letters.length / 2).ceil();
    final row1 =
        List.generate(half, (i) => _KeyInfo(label: letters[i], index: i));
    final row2 = List.generate(letters.length - half,
        (i) => _KeyInfo(label: letters[half + i], index: half + i));
    row2.add(const _KeyInfo(label: '⌫', index: -1));
    return [row1, row2];
  }
}

class _KeyInfo {
  final String label;
  final int index;
  const _KeyInfo({required this.label, required this.index});
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

class _LetterTile extends StatelessWidget {
  final String letter;
  final bool used;
  final VoidCallback? onTap;

  const _LetterTile({
    required this.letter,
    required this.used,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 52,
        height: 56,
        decoration: BoxDecoration(
          color: used
              ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
          border: Border.all(
            color: used
                ? colorScheme.outlineVariant.withValues(alpha: 0.3)
                : colorScheme.outlineVariant.withValues(alpha: 0.7),
            width: used ? 1 : 1.5,
          ),
          boxShadow: used
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Center(
          child: Text(
            letter,
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: used
                  ? colorScheme.onSurface.withValues(alpha: 0.3)
                  : colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _AnswerSlot extends StatelessWidget {
  final String? letter;
  final bool? isCorrect;

  const _AnswerSlot({this.letter, this.isCorrect});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Color bgColor = colorScheme.surface;
    Color borderColor = colorScheme.outlineVariant.withValues(alpha: 0.5);

    if (letter != null && isCorrect == null) {
      bgColor = AppColors.primary.withValues(alpha: 0.08);
      borderColor = AppColors.primary.withValues(alpha: 0.6);
    } else if (isCorrect == true) {
      bgColor = AppColors.correctGreenLight;
      borderColor = AppColors.correctGreen.withValues(alpha: 0.5);
    } else if (isCorrect == false) {
      bgColor = AppColors.errorRedLight;
      borderColor = AppColors.errorRed.withValues(alpha: 0.5);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 44,
      height: 48,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
        border: Border.all(
          color: borderColor,
          width: 1.5,
        ),
      ),
      child: Center(
        child: Text(
          letter ?? '',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: isCorrect == true
                ? AppColors.correctGreen
                : isCorrect == false
                    ? AppColors.errorRed
                    : AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _KeyboardKey extends StatelessWidget {
  final String label;
  final int index;
  final bool used;
  final VoidCallback onTap;

  const _KeyboardKey({
    required this.label,
    required this.index,
    required this.used,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDel = index < 0;

    return Material(
      color: used
          ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
          : isDel
              ? colorScheme.surfaceContainerHighest
              : colorScheme.surface,
      borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
      child: InkWell(
        onTap: used ? null : onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
        child: Container(
          width: isDel ? 52 : 40,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
            border: Border.all(
              color: colorScheme.outlineVariant
                  .withValues(alpha: used ? 0.2 : 0.5),
            ),
            boxShadow: used
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: Center(
            child: isDel
                ? Icon(Icons.backspace_outlined,
                    size: 18,
                    color: colorScheme.onSurface.withValues(alpha: 0.7))
                : Text(
                    label,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: used
                          ? colorScheme.onSurface.withValues(alpha: 0.3)
                          : colorScheme.onSurface,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _AnswerFeedback extends StatelessWidget {
  final bool correct;
  final String correctWord;

  const _AnswerFeedback({
    required this.correct,
    required this.correctWord,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bgColor =
        correct ? AppColors.correctGreenLight : AppColors.errorRedLight;
    final fgColor = correct ? AppColors.correctGreen : AppColors.errorRed;
    final icon = correct ? Icons.check_circle_rounded : Icons.cancel_rounded;
    final title = correct ? 'Correct! 🎉' : 'Incorrect';

    return Container(
      padding: const EdgeInsets.all(AppTokens.space16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        border: Border.all(color: fgColor.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: fgColor, size: 22),
          const SizedBox(width: AppTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: textTheme.titleMedium?.copyWith(
                        color: fgColor, fontWeight: FontWeight.w700)),
                if (!correct)
                  Text('Answer: $correctWord',
                      style: textTheme.bodySmall
                          ?.copyWith(color: fgColor.withValues(alpha: 0.8))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BanglaMeaningCard extends StatelessWidget {
  final String word;
  final String meaning;

  const _BanglaMeaningCard({
    required this.word,
    required this.meaning,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space16,
          vertical: AppTokens.space14,
        ),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.25),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🇧🇩', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(
                  'Bengali Meaning',
                  style: textTheme.labelMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              word,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              meaning,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.85),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
