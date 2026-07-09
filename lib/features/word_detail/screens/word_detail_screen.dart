import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../database/database_service.dart';
import '../../../database/word_detail_extensions.dart';
import '../../../core/providers/saved_words_provider.dart';

// ── Providers ────────────────────────────────────────────────────────

/// Loads the full WordRow for a given word ID.
final _wordDetailProvider =
    FutureProvider.family<WordRow?, int>((ref, wordId) {
  return DatabaseService.instance.getWordById(wordId);
});

/// Loads the usage example for a word ID (on-demand, DB-01 companion).
final _usageExampleProvider =
    FutureProvider.family<String?, int>((ref, wordId) {
  return DatabaseService.instance.getUsageExample(wordId);
});

/// Loads the IPA pronunciation string for a word ID.
final _ipaProvider =
    FutureProvider.family<String?, int>((ref, wordId) {
  return DatabaseService.instance.getIpaForWord(wordId);
});

// ── Screen ──────────────────────────────────────────────────────────────

/// Word detail screen. Route: /word/:wordId
///
/// Shows: word, IPA, POS, full definition, usage example, synonyms,
/// antonyms, Bengali meaning, Save/Unsave toggle.
class WordDetailScreen extends ConsumerWidget {
  final int wordId;

  const WordDetailScreen({super.key, required this.wordId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wordAsync = ref.watch(_wordDetailProvider(wordId));
    final ipaAsync = ref.watch(_ipaProvider(wordId));
    final usageAsync = ref.watch(_usageExampleProvider(wordId));
    final savedWordsAsync = ref.watch(savedWordsProvider);

    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          // Save / Unsave toggle
          wordAsync.when(
            data: (word) {
              if (word == null) return const SizedBox();
              final saved = savedWordsAsync.maybeWhen(
                data: (list) => list.any((sw) => sw.word == word.word),
                orElse: () => false,
              );
              return IconButton(
                icon: Icon(
                  saved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_outline_rounded,
                  color: saved ? AppColors.primary : null,
                ),
                tooltip: saved ? 'Unsave word' : 'Save word',
                onPressed: () async {
                  final notifier = ref.read(savedWordsProvider.notifier);
                  if (saved) {
                    // fix(build): SavedWordsNotifier uses remove(), not unsaveWord()
                    await notifier.remove(word.word);
                  } else {
                    // fix(build): SavedWordsNotifier uses save(), not saveWord()
                    await notifier.save(word.word, word.definition);
                  }
                },
              );
            },
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),
        ],
      ),
      body: wordAsync.when(
        data: (word) {
          if (word == null) {
            return Center(
              child: Text('Word not found.',
                  style: textTheme.bodyLarge
                      ?.copyWith(color: colorScheme.onSurfaceVariant)),
            );
          }

          return ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.screenPaddingH,
              vertical: AppTokens.space24,
            ),
            children: [
              // ── Word Heading ──────────────────────────────────────
              Text(
                word.word,
                style: textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),

              // ── IPA ───────────────────────────────────────────
              ipaAsync.when(
                data: (ipa) {
                  if (ipa == null || ipa.isEmpty) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: AppTokens.space4),
                    child: Text(
                      '/$ipa/',
                      style: textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  );
                },
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
              ),

              const SizedBox(height: AppTokens.space24),

              // ── POS + Definition ───────────────────────────────
              if (word.pos.isNotEmpty || word.definition.isNotEmpty)
                _SectionCard(
                  children: [
                    if (word.pos.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppTokens.space8,
                            vertical: AppTokens.space2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius:
                              BorderRadius.circular(AppTokens.radiusPill),
                        ),
                        child: Text(
                          word.pos.toUpperCase(),
                          style: textTheme.labelSmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTokens.space8),
                    ],
                    if (word.definition.isNotEmpty)
                      Text(word.definition, style: textTheme.bodyLarge),
                  ],
                ),

              const SizedBox(height: AppTokens.space16),

              // ── Bengali Meaning ────────────────────────────────
              if (word.banglaMeaning.isNotEmpty)
                _SectionCard(
                  label: '\u09AC\u09BE\u0982\u09B2\u09BE \u0985\u09B0\u09CD\u09A5',
                  children: [
                    Text(word.banglaMeaning,
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        )),
                  ],
                ),

              if (word.banglaMeaning.isNotEmpty)
                const SizedBox(height: AppTokens.space16),

              // ── Usage Example ─────────────────────────────────
              usageAsync.when(
                data: (example) {
                  if (example == null || example.isEmpty) {
                    return const SizedBox();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionCard(
                        label: 'Usage Example',
                        children: [
                          Text(
                            '\u201C$example\u201D',
                            style: textTheme.bodyLarge?.copyWith(
                              fontStyle: FontStyle.italic,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTokens.space16),
                    ],
                  );
                },
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
              ),

              // ── Synonyms ──────────────────────────────────────
              if (word.synonyms.isNotEmpty) ...[
                _WordChipsSection(
                  label: 'Synonyms',
                  words: word.synonyms,
                  onTap: (w) => _navigateToWord(context, ref, w),
                ),
                const SizedBox(height: AppTokens.space16),
              ],

              // ── Antonyms ──────────────────────────────────────
              if (word.antonyms.isNotEmpty) ...[
                _WordChipsSection(
                  label: 'Antonyms',
                  words: word.antonyms,
                  onTap: (w) => _navigateToWord(context, ref, w),
                ),
                const SizedBox(height: AppTokens.space16),
              ],

              const SizedBox(height: AppTokens.space48),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTokens.screenPaddingH),
            child: Text('Failed to load word: $err',
                style: textTheme.bodyMedium),
          ),
        ),
      ),
    );
  }

  /// Tap handler for synonym/antonym chips — looks up wordId from word text
  /// and pushes the word detail screen for that word.
  Future<void> _navigateToWord(
      BuildContext context, WidgetRef ref, String word) async {
    final id =
        await DatabaseService.instance.getWordIdByText(word);
    if (id != null && context.mounted) {
      context.push('/word/$id');
    }
  }
}

// ── Supporting Widgets ──────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String? label;
  final List<Widget> children;

  const _SectionCard({this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
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
          if (label != null) ...[
            Text(
              label!,
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTokens.space8),
          ],
          ...children,
        ],
      ),
    );
  }
}

class _WordChipsSection extends StatelessWidget {
  final String label;
  final List<String> words;
  final void Function(String word) onTap;

  const _WordChipsSection({
    required this.label,
    required this.words,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return _SectionCard(
      label: label,
      children: [
        Wrap(
          spacing: AppTokens.space8,
          runSpacing: AppTokens.space8,
          children: words
              .map(
                (w) => InkWell(
                  onTap: () => onTap(w),
                  borderRadius:
                      BorderRadius.circular(AppTokens.radiusPill),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppTokens.space12,
                        vertical: AppTokens.space4),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer,
                      borderRadius:
                          BorderRadius.circular(AppTokens.radiusPill),
                    ),
                    child: Text(
                      w,
                      style: textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
