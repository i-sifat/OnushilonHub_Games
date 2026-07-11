import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/game_config.dart';
import '../../../core/providers/saved_words_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../database/database_service.dart';
import '../../../database/word_detail_extensions.dart';

class SavedWordsScreen extends ConsumerWidget {
  const SavedWordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedAsync = ref.watch(savedWordsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Saved Words',
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface,
      ),
      // UX-04: 'Practice' FAB — only shown when there are saved words.
      floatingActionButton: savedAsync.when(
        data: (words) => words.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _practiceWords(context, words),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Practice'),
              ),
        loading: () => null,
        error: (_, __) => null,
      ),
      body: savedAsync.when(
        data: (words) {
          if (words.isEmpty) {
            return const _EmptyState();
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.screenPaddingH,
              AppTokens.space16,
              AppTokens.screenPaddingH,
              AppTokens.space80, // extra bottom padding so FAB doesn't overlap last item
            ),
            itemCount: words.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppTokens.space10),
            itemBuilder: (context, i) {
              final word = words[i];
              return _SavedWordTile(
                word: word.word,
                definition: word.definition,
                onDelete: () async {
                  await ref.read(savedWordsProvider.notifier).remove(word.word);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('"${word.word}" removed from saved words'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Something went wrong')),
      ),
    );
  }

  /// UX-04: Resolves word IDs from saved words in parallel, shows a game
  /// picker sheet, then routes directly to play with forcedWordIds set.
  Future<void> _practiceWords(
      BuildContext context, List<SavedWord> words) async {
    final futures =
        words.map((w) => DatabaseService.instance.getWordIdByText(w.word));
    final results = await Future.wait(futures);
    final ids = results.whereType<int>().toList();
    if (ids.isEmpty || !context.mounted) return;

    final gameType = await showModalBottomSheet<GameType>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTokens.radiusLarge)),
      ),
      builder: (ctx) => _GamePickerSheet(wordCount: ids.length),
    );
    if (gameType == null || !context.mounted) return;

    context.go(
      '/games/play/${gameType.dbKey}',
      extra: GameConfig(
        gameType: gameType,
        forcedWordIds: ids,
        questionCount: ids.length.clamp(5, 20),
      ),
    );
  }
}

// ── Game picker bottom sheet ──────────────────────────────────────────────────

class _GamePickerSheet extends StatelessWidget {
  final int wordCount;

  const _GamePickerSheet({required this.wordCount});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    // Word-practice game types in recommended order.
    const games = [
      GameType.meaningChase,
      GameType.synonymMatch,
      GameType.antonymMatch,
      GameType.definitionMatch,
      GameType.speedRacing,
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.space24,
          AppTokens.space24,
          AppTokens.space24,
          AppTokens.space16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Practice Saved Words',
              style: textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppTokens.space4),
            Text(
              '$wordCount word${wordCount == 1 ? '' : 's'} in your list',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppTokens.space16),
            ...games.map(
              (g) => ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: g.iconBg,
                    borderRadius:
                        BorderRadius.circular(AppTokens.radiusSmall),
                  ),
                  child: Icon(g.icon, color: g.iconColor, size: 18),
                ),
                title: Text(
                  g.label,
                  style: textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(g.subtitle, style: textTheme.bodySmall),
                onTap: () => Navigator.of(context).pop(g),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Saved word tile ───────────────────────────────────────────────────────────

class _SavedWordTile extends StatelessWidget {
  final String word;
  final String definition;
  final VoidCallback onDelete;

  const _SavedWordTile({
    required this.word,
    required this.definition,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: () async {
        final id = await DatabaseService.instance.getWordIdByText(word);
        if (id != null && context.mounted) {
          context.push('/word/$id');
        }
      },
      child: Container(
        padding: const EdgeInsets.all(AppTokens.space16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.bookmark_rounded,
                  color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: AppTokens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    word,
                    style: textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppTokens.space4),
                  Text(
                    definition,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline_rounded,
                  size: 20, color: colorScheme.error),
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_border_rounded,
                size: 56, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: AppTokens.space16),
            Text(
              'No saved words yet',
              style:
                  textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppTokens.space8),
            Text(
              'Tap the bookmark icon on the Word of the Day to save words here.',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
