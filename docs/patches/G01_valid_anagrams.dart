// ============================================================
// G-01 PATCH — Show all valid anagrams after a correct answer
// Patch map ref: G-01 (HIGH · ~2 hr)
// Files to touch: unscramble_game_screen.dart
// ============================================================
//
// HOW TO INTEGRATE
// ─────────────────
// 1. Locate `_buildFeedback` in
//    lib/features/games/screens/unscramble_game_screen.dart
//
// 2. Find the `if (isCorrect)` / `Correct!` text block inside the
//    method's Column children.  After the Text('Correct!', ...) widget
//    (and before the `if (!isCorrect)` clause) add:
//
//      // G-01 ─ also-valid chips
//      if (isCorrect) ...[                   
//        const SizedBox(height: AppTokens.space12),
//        _buildAlsoValidChips(state),
//      ],
//
// 3. Add the helper method below anywhere inside
//    _UnscrambleGameScreenState (e.g. just after `_buildFeedback`).
//
// ──────────────────────────────────────────────────────────────

// ── helper method to paste into _UnscrambleGameScreenState ───

  /// G-01 — Shows chips for every valid anagram that is NOT the
  /// word the player typed.  E.g. if the player typed WOLF and
  /// FLOW / FOWL are also accepted, this renders:
  ///   Also valid:  [FLOW]  [FOWL]
  Widget _buildAlsoValidChips(UnscrambleGameState state) {
    final q = state.currentQuestion!;
    // validWords are already lowercase (set in UnscrambleNotifier)
    final answered = state.playerAnswer.toLowerCase();
    final others = q.validWords
        .where((w) => w != answered)
        .map((w) => w.toUpperCase())
        .toList();
    if (others.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.screenPaddingH),
      child: Column(
        children: [
          Text(
            'Also valid:',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppTokens.space8),
          Wrap(
            spacing: AppTokens.space8,
            runSpacing: AppTokens.space4,
            alignment: WrapAlignment.center,
            children: others
                .map(
                  (w) => Chip(
                    label: Text(
                      w,
                      style: textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                    backgroundColor: colorScheme.secondaryContainer,
                    side: BorderSide.none,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTokens.space4,
                      vertical: AppTokens.space2,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
