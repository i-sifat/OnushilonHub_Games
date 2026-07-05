import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/game_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../database/word_repository.dart';
import '../../../database/database_service.dart';

// ── Label helpers ─────────────────────────────────────────────────────────────

String _diffLabel(int d) {
  switch (d) {
    case 1:
      return 'Easy';
    case 2:
      return 'Medium';
    case 3:
      return 'Hard';
    default:
      return 'Easy';
  }
}

String _countLabel(int c) => '$c';

const _questionCounts = [10, 20, 30, 40, 50];
const _difficulties = [1, 2, 3];

// ── Riverpod Providers ────────────────────────────────────────────────────────

/// Eligible count — re-evaluated only when filter params change.
final _eligibleCountProvider =
    FutureProvider.family<int, _EligibleQuery>((ref, q) async {
  // Wait for background seed to finish before querying word counts.
  await DatabaseService.instance.ensureSeedComplete();
  // Asset-backed games have a very large pool; return a sentinel count
  // so the Start button is always enabled (actual sampling happens at runtime).
  // whoseQuote now uses McqGameController + GameDataRepository (asset-backed),
  // not the old DB-seeded QuoteRepository.
  if (q.gameType == GameType.ipaMatch ||
      q.gameType == GameType.definitionMatch ||
      q.gameType == GameType.whoseQuote) {
    return 999;
  }
  final repo = ref.read(wordRepositoryProvider);
  return repo.getEligibleCount(
    gameType: q.gameType.dbKey,
    difficulty: q.difficulty,
  );
});

// ── Query value object (equality-safe for Riverpod family cache) ──────────────

class _EligibleQuery {
  final GameType gameType;
  final int difficulty;

  const _EligibleQuery(this.gameType, this.difficulty);

  @override
  bool operator ==(Object other) =>
      other is _EligibleQuery &&
      other.gameType == gameType &&
      other.difficulty == difficulty;

  @override
  int get hashCode => Object.hash(gameType, difficulty);
}

// ── Screen ────────────────────────────────────────────────────────────────────

class PreGameScreen extends ConsumerStatefulWidget {
  final String gameType;

  const PreGameScreen({super.key, required this.gameType});

  @override
  ConsumerState<PreGameScreen> createState() => _PreGameScreenState();
}

class _PreGameScreenState extends ConsumerState<PreGameScreen> {
  late GameType _gameType;

  // ValueNotifiers allow surgical chip rebuilds with zero setState overhead.
  final _difficulty = ValueNotifier<int>(1);
  final _questionCount = ValueNotifier<int>(10);
  final _trackAnswerTime = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _gameType = GameType.fromString(widget.gameType);
  }

  @override
  void dispose() {
    _difficulty.dispose();
    _questionCount.dispose();
    _trackAnswerTime.dispose();
    super.dispose();
  }

  void _startGame() {
    final config = GameConfig(
      gameType: _gameType,
      difficulty: _difficulty.value,
      questionCount: _questionCount.value,
      trackAnswerTime: _gameType == GameType.unscramble ? _trackAnswerTime.value : false,
    );
    context.go('/games/play/${_gameType.dbKey}', extra: config);
  }

  // Build the eligible-count query from current notifier values.
  _EligibleQuery _buildQuery() => _EligibleQuery(
        _gameType,
        _difficulty.value,
      );

  int get _xpEstimate {
    final multiplier = _difficulty.value;
    return (_questionCount.value * AppTokens.xpPerCorrect) * multiplier;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/games');
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_gameType.label),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => context.go('/games'),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.screenPaddingH,
            vertical: AppTokens.space16,
          ),
          children: [
            // ── XP balance card (reference image top card) ────────────────
            _EligibleInfoCard(
              difficultyNotifier: _difficulty,
              questionCountNotifier: _questionCount,
              buildQuery: _buildQuery,
              xpEstimateGetter: () => _xpEstimate,
            ),
            const SizedBox(height: AppTokens.space28),

            // ── Difficulty chips ──────────────────────────────────────────
            Text('Difficulty',
                style: textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0.2)),
            const SizedBox(height: AppTokens.space10),
            ValueListenableBuilder<int>(
              valueListenable: _difficulty,
              builder: (_, selected, __) => _ChipRow(
                items: _difficulties,
                selected: selected,
                labelOf: (d) => _diffLabel(d),
                onSelect: (d) => _difficulty.value = d,
              ),
            ),
            const SizedBox(height: AppTokens.space24),

            // ── Question count chips ──────────────────────────────────────
            Text('Questions',
                style: textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0.2)),
            const SizedBox(height: AppTokens.space10),
            ValueListenableBuilder<int>(
              valueListenable: _questionCount,
              builder: (_, selected, __) => _ChipRow(
                items: _questionCounts,
                selected: selected,
                labelOf: (c) => _countLabel(c),
                onSelect: (c) => _questionCount.value = c,
              ),
            ),

            // ── Unscramble: Track Answer Time toggle ──────────────────────
            if (_gameType == GameType.unscramble) ...[
              const SizedBox(height: AppTokens.space24),
              ValueListenableBuilder<bool>(
                valueListenable: _trackAnswerTime,
                builder: (_, value, __) => _ToggleRow(
                  label: 'Track Answer Time',
                  description: 'Show a timer for each question',
                  icon: Icons.timer_outlined,
                  value: value,
                  onChanged: (v) => _trackAnswerTime.value = v,
                ),
              ),
            ],


            // ── Info rows (Questions / Time / Rewards) ────────────────────
            const SizedBox(height: AppTokens.space28),
            _InfoRows(
              questionCountNotifier: _questionCount,
              difficultyNotifier: _difficulty,
            ),

            const SizedBox(height: AppTokens.space32),

            // ── Start button ──────────────────────────────────────────────
            _StartButton(
              gameType: _gameType,
              difficultyNotifier: _difficulty,
              buildQuery: _buildQuery,
              onStart: _startGame,
            ),
            const SizedBox(height: AppTokens.space24),
          ],
        ),
      ),
    );
  }
}

// ── Info card — isolated consumer, only rebuilds when eligible count changes ───
//
// Pattern: ValueListenableBuilder captures notifier values → passes them to a
// Consumer so ref.watch is always called from a proper build() context, never
// from inside an AnimatedBuilder callback (which caused Riverpod instability
// and visible rebuilds / chip-selection hiccups).

class _EligibleInfoCard extends StatelessWidget {
  final ValueNotifier<int> difficultyNotifier;
  final ValueNotifier<int> questionCountNotifier;
  final _EligibleQuery Function() buildQuery;
  final int Function() xpEstimateGetter;

  const _EligibleInfoCard({
    required this.difficultyNotifier,
    required this.questionCountNotifier,
    required this.buildQuery,
    required this.xpEstimateGetter,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        difficultyNotifier,
        questionCountNotifier,
      ]),
      builder: (_, __) => _EligibleInfoCardInner(
        query: buildQuery(),
        xpEstimate: xpEstimateGetter(),
      ),
    );
  }
}

/// Inner widget: ref.watch is called directly in build() — Riverpod-safe.
class _EligibleInfoCardInner extends ConsumerWidget {
  final _EligibleQuery query;
  final int xpEstimate;

  const _EligibleInfoCardInner({
    required this.query,
    required this.xpEstimate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eligibleAsync = ref.watch(_eligibleCountProvider(query));
    return eligibleAsync.when(
      skipLoadingOnReload: true,
      data: (count) => _InfoCard(count: count, xpEstimate: xpEstimate),
      loading: () => _InfoCard(count: 0, xpEstimate: xpEstimate),
      error: (__, ___) => const SizedBox(),
    );
  }
}

// ── Start button — isolated consumer ─────────────────────────────────────────

// ── Info rows: Questions / Rewards ─────────────────────

class _InfoRows extends StatelessWidget {
  final ValueNotifier<int> questionCountNotifier;
  final ValueNotifier<int> difficultyNotifier;
  const _InfoRows({
    required this.questionCountNotifier,
    required this.difficultyNotifier,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: Listenable.merge([questionCountNotifier, difficultyNotifier]),
      builder: (context, _) {
        final count = questionCountNotifier.value;
        final diff = difficultyNotifier.value;
        final displayCount = '$count';
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
            border:
                Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Column(
            children: [
              _InfoRow(
                icon: Icons.bar_chart_rounded,
                label: 'Difficulty',
                value: _diffLabel(diff),
              ),
              Divider(
                  height: 1,
                  indent: 52,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
              _InfoRow(
                icon: Icons.format_list_numbered_rounded,
                label: 'Questions',
                value: displayCount,
              ),
              Divider(
                  height: 1,
                  indent: 52,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
              _InfoRow(
                icon: Icons.card_giftcard_rounded,
                label: 'Rewards',
                value: '${int.parse(displayCount) * AppTokens.xpPerCorrect * diff} XP',
                valueBold: true,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool valueBold;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueBold = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space16, vertical: AppTokens.space14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: AppTokens.space16),
          Expanded(
            child: Text(label,
                style: textTheme.bodyMedium
                    ?.copyWith(color: colorScheme.onSurfaceVariant)),
          ),
          Text(
            value,
            style: valueBold
                ? textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)
                : textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ── Start Game button ─────────────────────────────────────────────────────────
//
// Same fix as _EligibleInfoCard: ValueListenableBuilder → _StartButtonInner
// (ConsumerWidget) so ref.watch is always in a proper build() context.

class _StartButton extends StatelessWidget {
  final GameType gameType;
  final ValueNotifier<int> difficultyNotifier;
  final _EligibleQuery Function() buildQuery;
  final VoidCallback onStart;

  const _StartButton({
    required this.gameType,
    required this.difficultyNotifier,
    required this.buildQuery,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: difficultyNotifier,
      builder: (_, __) => _StartButtonInner(
        query: buildQuery(),
        onStart: onStart,
      ),
    );
  }
}

class _StartButtonInner extends ConsumerWidget {
  final _EligibleQuery query;
  final VoidCallback onStart;

  const _StartButtonInner({required this.query, required this.onStart});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eligibleAsync = ref.watch(_eligibleCountProvider(query));
    return eligibleAsync.when(
      skipLoadingOnReload: true,
      data: (count) => SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton(
          onPressed: count > 0 ? onStart : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor:
                AppColors.primary.withValues(alpha: 0.4),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
            ),
          ),
          child: Text(
            count > 0 ? 'Start Game' : 'No eligible items',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
      ),
      loading: () => SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton(
          onPressed: null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
            ),
          ),
          child: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white),
          ),
        ),
      ),
      error: (__, ___) => const SizedBox(),
    );
  }
}

// ── Generic chip row for int-typed filter lists (difficulty, count) ───────────

class _ChipRow<T> extends StatelessWidget {
  final List<T> items;
  final T selected;
  final String Function(T) labelOf;
  final void Function(T) onSelect;

  const _ChipRow({
    required this.items,
    required this.selected,
    required this.labelOf,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppTokens.space8,
      runSpacing: AppTokens.space8,
      children: items
          .map((item) => _SelectChip(
                label: labelOf(item),
                selected: item == selected,
                onTap: () => onSelect(item),
              ))
          .toList(growable: false),
    );
  }
}

// ── Info card ─────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final int count;
  final int xpEstimate;

  const _InfoCard({required this.count, required this.xpEstimate});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Matches reference: "Your XP balance / 1,250 XP" card with star icon
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space16,
        vertical: AppTokens.space14,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your XP balance',
                    style: textTheme.bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant)),
                const SizedBox(height: AppTokens.space4),
                Text('$xpEstimate XP',
                    style: textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                Text(count >= 999 ? 'Large question pool' : '$count questions available',
                    style: textTheme.bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.reward.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.star_rounded,
                color: AppColors.reward, size: 26),
          ),
        ],
      ),
    );
  }
}

// ── Toggle row ────────────────────────────────────────────────────────────────

class _ToggleRow extends StatelessWidget {
  final String label;
  final String description;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    required this.description,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space16, vertical: AppTokens.space12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: AppTokens.space16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                Text(description,
                    style: textTheme.bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

// ── Select chip — premium tactile style ──────────────────────────────────────
//
// Uses a plain Container instead of AnimatedContainer: the AnimatedContainer
// triggers a layout pass on every tap which was causing visible frame drops.
// The InkWell splash provides sufficient tactile feedback without layout cost.

class _SelectChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SelectChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        border: Border.all(
          color: selected
              ? AppColors.primary
              : colorScheme.outlineVariant.withValues(alpha: 0.6),
          width: selected ? 1.5 : 1.0,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
          onTap: () {
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.space16,
              vertical: AppTokens.space10,
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : colorScheme.onSurface,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
