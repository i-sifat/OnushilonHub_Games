// F-04: word search screen.
//
// Accessible via /search route. Runs a debounced LIKE query on the 55k-word
// DB and shows results in a scrollable list. Each result taps to the word
// detail screen (UX-03).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../database/database_service.dart';
import '../../../database/word_search_extensions.dart';

class WordSearchScreen extends StatefulWidget {
  const WordSearchScreen({super.key});

  @override
  State<WordSearchScreen> createState() => _WordSearchScreenState();
}

class _WordSearchScreenState extends State<WordSearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;

  List<WordSearchResult> _results = [];
  bool _loading = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
    _controller.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    final q = _controller.text.trim();
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q));
  }

  Future<void> _search(String query) async {
    final results =
        await DatabaseService.instance.searchWords(query, limit: 50);
    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
      _hasSearched = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          style: textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: 'Search words\u2026',
            border: InputBorder.none,
            hintStyle: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          textInputAction: TextInputAction.search,
          // fix(build): Timer.cancel() returns void — cannot chain .then().
          // Split into two sequential statements instead.
          onSubmitted: (_) {
            _debounce?.cancel();
            _search(_controller.text.trim());
          },
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => _controller.clear(),
            ),
        ],
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface,
      ),
      body: _buildBody(colorScheme, textTheme),
    );
  }

  Widget _buildBody(ColorScheme colorScheme, TextTheme textTheme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_rounded,
              size: 64,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: AppTokens.space16),
            Text(
              'Search 55,000+ words',
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppTokens.space8),
            Text(
              'Type to find definitions, synonyms, IPA and more.',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: AppTokens.space16),
            Text(
              'No results for "${_controller.text.trim()}"',
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.screenPaddingH,
        vertical: AppTokens.space12,
      ),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final r = _results[i];
        return _SearchResultTile(
          result: r,
          query: _controller.text.trim(),
          onTap: () => context.push('/word/${r.id}'),
        );
      },
    );
  }
}

// ── Result tile ────────────────────────────────────────────────────────────

class _SearchResultTile extends StatelessWidget {
  final WordSearchResult result;
  final String query;
  final VoidCallback onTap;

  const _SearchResultTile({
    required this.result,
    required this.query,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTokens.space12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Word with query highlighted
                  _HighlightedText(
                    text: result.word,
                    query: query,
                    style: textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                    highlightStyle: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  if (result.definition.isNotEmpty) ...[
                    const SizedBox(height: AppTokens.space2),
                    Text(
                      result.definition,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (result.pos.isNotEmpty) ...[
              const SizedBox(width: AppTokens.space8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.space8,
                  vertical: AppTokens.space2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius:
                      BorderRadius.circular(AppTokens.radiusPill),
                ),
                child: Text(
                  result.pos,
                  style: textTheme.labelSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Highlights [query] occurrences within [text].
class _HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle? style;
  final TextStyle? highlightStyle;

  const _HighlightedText({
    required this.text,
    required this.query,
    this.style,
    this.highlightStyle,
  });

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) return Text(text, style: style);

    final lText = text.toLowerCase();
    final lQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;

    while (true) {
      final idx = lText.indexOf(lQuery, start);
      if (idx == -1) {
        spans.add(TextSpan(text: text.substring(start), style: style));
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx), style: style));
      }
      spans.add(TextSpan(
        text: text.substring(idx, idx + query.length),
        style: highlightStyle ?? style,
      ));
      start = idx + query.length;
    }

    return Text.rich(TextSpan(children: spans));
  }
}
